// RUN: %empty-directory(%t)

// >> first try when no library evolution is specified
// RUN: %target-swift-frontend -enable-experimental-move-only -emit-module -o %t/SorryModule.swiftmodule %S/Inputs/forget_module_defining.swift %S/Inputs/forget_module_adjacent.swift
// RUN: %target-typecheck-verify-swift -enable-experimental-move-only -I %t

// >> now again with library evolution; we expect the same result.
// RUN: %target-swift-frontend -enable-library-evolution -enable-experimental-move-only -emit-module -o %t/SorryModule.swiftmodule %S/Inputs/forget_module_defining.swift %S/Inputs/forget_module_adjacent.swift
// RUN: %target-typecheck-verify-swift -enable-experimental-move-only -I %t

// "Sorry" is meaningless
import SorryModule

extension Regular {
  __consuming func delete() {
    _forget self // expected-error {{can only 'forget' from the same module defining type 'Regular'}}
  }
}

extension Frozen {
  __consuming func delete() {
    _forget self // expected-error {{can only 'forget' from the same module defining type 'Frozen'}}
  }
}
