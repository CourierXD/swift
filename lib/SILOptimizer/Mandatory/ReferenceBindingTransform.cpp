//===--- ReferenceBindingTransform.cpp ------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "sil-reference-binding-transform"

#include "swift/AST/DiagnosticsSIL.h"
#include "swift/Basic/Defer.h"
#include "swift/SIL/BasicBlockDatastructures.h"
#include "swift/SIL/FieldSensitivePrunedLiveness.h"
#include "swift/SIL/PrunedLiveness.h"
#include "swift/SIL/SILBuilder.h"
#include "swift/SILOptimizer/PassManager/Transforms.h"

using namespace swift;

static llvm::cl::opt<bool> SilentlyEmitDiagnostics(
    "sil-reference-binding-diagnostics-silently-emit-diagnostics",
    llvm::cl::desc(
        "For testing purposes, emit the diagnostic silently so we can "
        "filecheck the result of emitting an error from the move checkers"),
    llvm::cl::init(false));

//===----------------------------------------------------------------------===//
//                          MARK: Diagnosis Helpers
//===----------------------------------------------------------------------===//

template <typename... T, typename... U>
static void diagnose(SILInstruction *inst, Diag<T...> diag, U &&...args) {
  // If we asked to actually emit diagnostics, skip it. This lets us when
  // testing to write FileCheck tests for tests without an error along side
  // other tests where we want to use -verify.
  if (SilentlyEmitDiagnostics)
    return;

  // See if the consuming use is an owned moveonly_to_copyable whose only
  // user is a return. In that case, use the return loc instead. We do this
  // b/c it is illegal to put a return value location on a non-return value
  // instruction... so we have to hack around this slightly.
  auto loc = inst->getLoc();
  if (auto *mtc = dyn_cast<MoveOnlyWrapperToCopyableValueInst>(inst)) {
    if (auto *ri = mtc->getSingleUserOfType<ReturnInst>()) {
      loc = ri->getLoc();
    }
  }

  auto &context = inst->getModule().getASTContext();
  context.Diags.diagnose(loc.getSourceLoc(), diag, std::forward<U>(args)...);
}

//===----------------------------------------------------------------------===//
//                         MARK: Gather Address Uses
//===----------------------------------------------------------------------===//

namespace {

struct ValidateAllUsesWithinLiveness : public AccessUseVisitor {
  SSAPrunedLiveness &liveness;
  SILInstruction *markInst;
  SILInstruction *initInst;
  bool emittedDiagnostic = false;

  ValidateAllUsesWithinLiveness(SSAPrunedLiveness &gatherUsesLiveness,
                                SILInstruction *markInst,
                                SILInstruction *initInst)
      : AccessUseVisitor(AccessUseType::Overlapping,
                         NestedAccessType::IgnoreAccessBegin),
        liveness(gatherUsesLiveness), markInst(markInst), initInst(initInst) {}

  bool visitUse(Operand *op, AccessUseType useTy) override {
    auto *user = op->getUser();

    // Skip our initInst which is going to be within the lifetime.
    if (user == initInst)
      return true;

    // Skip end_access. We care about the end_access uses.
    if (isa<EndAccessInst>(user))
      return true;

    if (liveness.isWithinBoundary(user)) {
      diagnose(op->getUser(),
               diag::sil_referencebinding_src_used_within_inout_scope);
      diagnose(markInst, diag::sil_referencebinding_inout_binding_here);
      emittedDiagnostic = true;
    }

    return true;
  }
};

} // end anonymous namespace

//===----------------------------------------------------------------------===//
//                              MARK: Transform
//===----------------------------------------------------------------------===//

static bool runTransform(SILFunction *fn) {
  bool madeChange = false;

  StackList<MarkUnresolvedReferenceBindingInst *> targets(fn);
  for (auto &block : *fn) {
    for (auto &ii : block) {
      if (auto *murbi = dyn_cast<MarkUnresolvedReferenceBindingInst>(&ii))
        targets.push_back(murbi);
    }
  }

  bool emittedError = false;
  while (!targets.empty()) {
    auto *mark = targets.pop_back_val();
    SWIFT_DEFER {
      mark->replaceAllUsesWith(mark->getOperand());
      mark->eraseFromParent();
      madeChange = true;
    };

    // We rely on the following semantics to find our initialization:
    //
    // 1. SILGen always initializes values completely.
    // 2. Boxes always have operations guarded /except/ for their
    //    initialization.
    // 3. We force inout to always be initialized once.
    //
    // Thus to find our initialization, we need to find a project_box use of our
    // target that directly initializes the value.
    CopyAddrInst *initInst = nullptr;
    for (auto *use : mark->getUses()) {
      if (auto *pbi = dyn_cast<ProjectBoxInst>(use->getUser())) {
        for (auto *use : pbi->getUses()) {
          if (auto *cai = dyn_cast<CopyAddrInst>(use->getUser())) {
            if (cai->getDest() == pbi) {
              if (initInst || !cai->isInitializationOfDest() ||
                  cai->isTakeOfSrc()) {
                emittedError = true;
                diagnose(mark, diag::sil_referencebinding_unknown_pattern);
                break;
              }
              assert(!initInst && "Init twice?!");
              assert(!cai->isTakeOfSrc());
              initInst = cai;
              continue;
            }
          }
        }

        if (emittedError)
          break;
      }
    }

    if (emittedError)
      continue;
    assert(initInst && "Failed to find single initialization");

    // Ok, we have our initialization. Now gather our destroys of our value and
    // initialize an SSAPrunedLiveness, using our initInst as our def.
    SmallVector<SILBasicBlock *, 8> discoveredBlocks;
    SSAPrunedLiveness liveness(&discoveredBlocks);
    StackList<DestroyValueInst *> destroyValueInst(fn);
    liveness.initializeDef(mark);
    for (auto *consume : mark->getConsumingUses()) {
      // Make sure that the destroy_value is not within the boundary.
      auto *dai = dyn_cast<DestroyValueInst>(consume->getUser());
      if (!dai) {
        emittedError = true;
        diagnose(mark, diag::sil_referencebinding_unknown_pattern);
        break;
      }

      liveness.updateForUse(dai, true /*is lifetime ending*/);
      destroyValueInst.push_back(dai);
    }
    if (emittedError)
      continue;

    // Now make sure that our source address doesn't have any uses within the
    // lifetime of our box. Or emit an error.
    auto accessPathWithBase = AccessPathWithBase::compute(initInst->getSrc());
    assert(accessPathWithBase.base);

    // Then search up for a single begin_access from src to find our
    // begin_access we need to fix. We know that it will always be directly on
    // the type since we only allow for inout today to be on decl_ref expr. This
    // will change in the future. Once we find that begin_access, we need to
    // convert it to a modify and expand it.
    auto *bai = cast<BeginAccessInst>(initInst->getSrc());
    assert(bai->getAccessKind() == SILAccessKind::Read);
    StackList<SILInstruction *> endAccesses(fn);
    for (auto *eai : bai->getEndAccesses())
      endAccesses.push_back(eai);

    {
      ValidateAllUsesWithinLiveness initGatherer(liveness, mark, initInst);
      if (!visitAccessPathBaseUses(initGatherer, accessPathWithBase, fn)) {
        emittedError = true;
        diagnose(mark, diag::sil_referencebinding_unknown_pattern);
      }
      emittedError |= initGatherer.emittedDiagnostic;
    }
    if (emittedError)
      continue;

    initInst->setIsTakeOfSrc(IsTake);
    bai->setAccessKind(SILAccessKind::Modify);
    madeChange = true;

    while (!endAccesses.empty())
      endAccesses.pop_back_val()->eraseFromParent();

    {
      while (!destroyValueInst.empty()) {
        auto *consume = destroyValueInst.pop_back_val();
        SILBuilderWithScope builder(consume);
        auto *pbi = builder.createProjectBox(consume->getLoc(), mark, 0);
        builder.createCopyAddr(consume->getLoc(), pbi, initInst->getSrc(),
                               IsTake, IsInitialization);
        builder.createEndAccess(consume->getLoc(), bai, false /*aborted*/);
        builder.createDeallocBox(consume->getLoc(), mark);
        consume->eraseFromParent();
      }
    }
  }

  return madeChange;
}

//===----------------------------------------------------------------------===//
//                         MARK: Top Level Entrypoint
//===----------------------------------------------------------------------===//

namespace {

struct ReferenceBindingTransformPass : SILFunctionTransform {
  void run() override {
    auto *fn = getFunction();

    // Only run this if the reference binding feature is enabled.
    if (!fn->getASTContext().LangOpts.hasFeature(Feature::ReferenceBindings))
      return;

    if (runTransform(fn)) {
      invalidateAnalysis(SILAnalysis::Instructions);
    }
  }
};

} // namespace

SILTransform *swift::createReferenceBindingTransform() {
  return new ReferenceBindingTransformPass();
}
