// RUN: %target-run-simple-swift
// REQUIRES: executable_test

import Swift
import StdlibUnittest

let suite = "Diffing"

TestSuite(suite).test("Diffing empty collections") {
    let a = [Int]()
    let b = [Int]()
    let diff = b.shortestEditScript(from: a)

    expectEqual(diff, a.shortestEditScript(from: a))
    expectTrue(diff.isEmpty)
}

TestSuite(suite).test("Basic diffing algorithm validators") {
    let expectedChanges: [(
        source: [String],
        target: [String],
        changes: [OrderedCollectionDifference<String>.Change],
        line: UInt
    )] = [
        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         changes: [],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Presents",
             "New Years", "Champagne"],
         changes: [
            .remove(offset: 5, element: "Lights", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel", "Gelt",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         changes: [
             .insert(offset: 3, element: "Gelt", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Presents", "Tree", "Lights",
             "New Years", "Champagne"],
         changes: [
             .remove(offset: 6, element: "Presents", associatedWith: 4),
             .insert(offset: 4, element: "Presents", associatedWith: 6)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Lights", "Presents", "Tree",
             "New Years", "Champagne"],
         changes: [
             .remove(offset: 4, element: "Tree", associatedWith: 6),
             .insert(offset: 6, element: "Tree", associatedWith: 4)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights",
             "New Years", "Champagne"],
         changes: [
             .remove(offset: 6, element: "Presents", associatedWith: 3),
             .insert(offset: 3, element: "Presents", associatedWith: 6)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights",
             "New Years", "Champagne", "Presents"],
         changes: [
             .remove(offset: 6, element: "Presents", associatedWith: 8),
             .insert(offset: 8, element: "Presents", associatedWith: 6)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         changes: [
             .remove(offset: 2, element: "Dreidel", associatedWith: nil),
             .remove(offset: 1, element: "Menorah", associatedWith: nil),
             .remove(offset: 0, element: "Hannukah", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         changes: [
             .insert(offset: 7, element: "New Years", associatedWith: nil),
             .insert(offset: 8, element: "Champagne", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["New Years", "Champagne",
             "Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents"],
         changes: [
             .remove(offset: 8, element: "Champagne", associatedWith: 1),
             .remove(offset: 7, element: "New Years", associatedWith: 0),
             .insert(offset: 0, element: "New Years", associatedWith: 7),
             .insert(offset: 1, element: "Champagne", associatedWith: 8)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne",
             "Hannukah", "Menorah", "Dreidel"],
         changes: [
             .remove(offset: 2, element: "Dreidel", associatedWith: 8),
             .remove(offset: 1, element: "Menorah", associatedWith: 7),
             .remove(offset: 0, element: "Hannukah", associatedWith: 6),
             .insert(offset: 6, element: "Hannukah", associatedWith: 0),
             .insert(offset: 7, element: "Menorah", associatedWith: 1),
             .insert(offset: 8, element: "Dreidel", associatedWith: 2)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights",
             "New Years", "Champagne"],
         target:
            ["Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         changes: [
             .remove(offset: 3, element: "Presents", associatedWith: 3),
             .remove(offset: 2, element: "Dreidel", associatedWith: nil),
             .remove(offset: 1, element: "Menorah", associatedWith: nil),
             .remove(offset: 0, element: "Hannukah", associatedWith: nil),
             .insert(offset: 3, element: "Presents", associatedWith: 3)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Presents",
             "New Years", "Champagne", "Lights"],
         changes: [
             .remove(offset: 5, element: "Lights", associatedWith: 8),
             .insert(offset: 6, element: "New Years", associatedWith: nil),
             .insert(offset: 7, element: "Champagne", associatedWith: nil),
             .insert(offset: 8, element: "Lights", associatedWith: 5)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years"],
         changes: [
             .remove(offset: 8, element: "Champagne", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne", "Presents"],
         target:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne", "Presents"],
         changes: [],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne", "Presents"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights",
             "New Years", "Champagne", "Presents"],
         changes: [
             .remove(offset: 7, element: "Presents", associatedWith: nil),
             .remove(offset: 3, element: "Presents", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights",
             "New Years", "Champagne", "Presents"],
         target:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne", "Presents"],
         changes: [
             .insert(offset: 3, element: "Presents", associatedWith: nil),
             .insert(offset: 7, element: "Presents", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah", "Dreidel", "Presents",
             "Xmas", "Tree", "Lights",
             "New Years", "Champagne", "Presents"],
         target:
            ["Hannukah", "Menorah", "Dreidel",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne", "Presents"],
         changes: [
             .remove(offset: 3, element: "Presents", associatedWith: 6),
             .insert(offset: 6, element: "Presents", associatedWith: 3)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne",
             "Hannukah", "Dreidel"],
         target:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne",
             "Hannukah", "Dreidel"],
         changes: [],
         line: #line),

        (source:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne",
             "Hannukah", "Dreidel"],
         target:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         changes: [
             .remove(offset: 9, element: "Dreidel", associatedWith: nil),
             .remove(offset: 8, element: "Hannukah", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne"],
         target:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne",
             "Hannukah", "Dreidel"],
         changes: [
             .insert(offset: 8, element: "Hannukah", associatedWith: nil),
             .insert(offset: 9, element: "Dreidel", associatedWith: nil)
         ],
         line: #line),

        (source:
            ["Hannukah", "Menorah",
             "Xmas", "Tree", "Lights", "Presents",
             "New Years", "Champagne",
             "Hannukah", "Dreidel"],
         target:
            ["Xmas", "Tree", "Lights", "Presents",
             "Hannukah", "Menorah",
             "New Years", "Champagne",
             "Hannukah", "Dreidel"],
         changes: [
             .remove(offset: 1, element: "Menorah", associatedWith: 5),
             .remove(offset: 0, element: "Hannukah", associatedWith: 4),
             .insert(offset: 4, element: "Hannukah", associatedWith: 0),
             .insert(offset: 5, element: "Menorah", associatedWith: 1)
         ],
         line: #line),
    ]

    for (source, target, expected, line) in expectedChanges {
        let actual = target.shortestEditScript(from: source).inferringMoves()
        expectEqual(actual, OrderedCollectionDifference(expected), "failed test at line \(line)")
    }
}

TestSuite(suite).test("Empty diffs have sane behaviour") {
    guard let diff = OrderedCollectionDifference<String>([]) else {
        expectUnreachable()
        return
    }
    expectEqual(0, diff.insertions.count)
    expectEqual(0, diff.removals.count)
    expectEqual(true, diff.isEmpty)

    var c = 0
    diff.forEach({ _ in c += 1 })
    expectEqual(0, c)
}

TestSuite(suite).test("Happy path tests for the change validator") {
    // Base case: one insert and one remove with legal offsets
    expectNotNil(OrderedCollectionDifference<Int>.init([
        .insert(offset: 0, element: 0, associatedWith: nil),
        .remove(offset: 0, element: 0, associatedWith: nil)
    ]))

    // Code coverage:
    // • non-first change .remove has legal associated offset
    // • non-first change .insert has legal associated offset
    expectNotNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 1, element: 0, associatedWith: 0),
        .remove(offset: 0, element: 0, associatedWith: 1),
        .insert(offset: 0, element: 0, associatedWith: 1),
        .insert(offset: 1, element: 0, associatedWith: 0)
    ]))
}

TestSuite(suite).test("Exhaustive edge case tests for the change validator") {
    // Base case: two inserts sharing the same offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .insert(offset: 0, element: 0, associatedWith: nil),
        .insert(offset: 0, element: 0, associatedWith: nil)
    ]))

    // Base case: two removes sharing the same offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 0, element: 0, associatedWith: nil),
        .remove(offset: 0, element: 0, associatedWith: nil)
    ]))

    // Base case: illegal insertion offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .insert(offset: -1, element: 0, associatedWith: nil)
    ]))

    // Base case: illegal remove offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: -1, element: 0, associatedWith: nil)
    ]))

    // Base case: two inserts sharing same associated offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .insert(offset: 0, element: 0, associatedWith: 0),
        .insert(offset: 1, element: 0, associatedWith: 0)
    ]))

    // Base case: two removes sharing same associated offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 0, element: 0, associatedWith: 0),
        .remove(offset: 1, element: 0, associatedWith: 0)
    ]))

    // Base case: insert with illegal associated offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .insert(offset: 0, element: 0, associatedWith: -1)
    ]))

    // Base case: remove with illegal associated offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 1, element: 0, associatedWith: -1)
    ]))

    // Code coverage: non-first change has illegal offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 0, element: 0, associatedWith: nil),
        .insert(offset: -1, element: 0, associatedWith: nil)
    ]))

    // Code coverage: non-first change has illegal associated offset
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 0, element: 0, associatedWith: nil),
        .insert(offset: 0, element: 0, associatedWith: -1)
    ]))
}

TestSuite(suite).test("Enumeration order is safe") {
    let safelyOrderedChanges: [OrderedCollectionDifference<Int>.Change] = [
        .remove(offset: 2, element: 0, associatedWith: nil),
        .remove(offset: 1, element: 0, associatedWith: 0),
        .remove(offset: 0, element: 0, associatedWith: 1),
        .insert(offset: 0, element: 0, associatedWith: 1),
        .insert(offset: 1, element: 0, associatedWith: 0),
        .insert(offset: 2, element: 0, associatedWith: nil),
    ]
    let diff = OrderedCollectionDifference<Int>.init(safelyOrderedChanges)!
    var enumerationOrderedChanges = [OrderedCollectionDifference<Int>.Change]()
    diff.forEach { c in
        enumerationOrderedChanges.append(c)
    }
    expectEqual(safelyOrderedChanges, enumerationOrderedChanges)
}

TestSuite(suite).test("Change validator rejects bad associations") {
    // .remove(1) → .insert(1)
    //     ↑            ↓
    // .insert(0) ← .remove(0)
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 1, element: 0, associatedWith: 1),
        .remove(offset: 0, element: 0, associatedWith: 0),
        .insert(offset: 0, element: 0, associatedWith: 1),
        .insert(offset: 1, element: 0, associatedWith: 0)
    ]))

    // Coverage: duplicate remove offsets both with assocs
    expectNil(OrderedCollectionDifference<Int>.init([
        .remove(offset: 0, element: 0, associatedWith: 1),
        .remove(offset: 0, element: 0, associatedWith: 0),
    ]))

    // Coverage: duplicate insert assocs
    expectNil(OrderedCollectionDifference<Int>.init([
        .insert(offset: 0, element: 0, associatedWith: 1),
        .insert(offset: 1, element: 0, associatedWith: 1),
    ]))
}

// Full-coverage test for OrderedCollectionDifference.Change.==()
TestSuite(suite).test("Exhaustive testing for equatable conformance") {
    // Differs by type:
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 0, associatedWith: 0)
    )

    // Differs by type in the other direction:
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 0, associatedWith: 0)
    )

    // Insert differs by offset
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.insert(offset: 1, element: 0, associatedWith: 0)
    )

    // Insert differs by element
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 1, associatedWith: 0)
    )

    // Insert differs by association
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.insert(offset: 0, element: 0, associatedWith: 1)
    )

    // Remove differs by offset
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.remove(offset: 1, element: 0, associatedWith: 0)
    )

    // Remove differs by element
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 1, associatedWith: 0)
    )

    // Remove differs by association
    expectNotEqual(
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 0, associatedWith: 0),
        OrderedCollectionDifference<Int>.Change.remove(offset: 0, element: 0, associatedWith: 1)
    )
}

TestSuite(suite).test("Compile-time test of hashable conformance") {
    let _ = Set<OrderedCollectionDifference<String>>();
}

TestSuite(suite).test("Move inference") {
    let n = OrderedCollectionDifference<String>.init([
        .insert(offset: 3, element: "Sike", associatedWith: nil),
        .insert(offset: 4, element: "Sike", associatedWith: nil),
        .insert(offset: 2, element: "Hello", associatedWith: nil),
        .remove(offset: 6, element: "Hello", associatedWith: nil),
        .remove(offset: 8, element: "Goodbye", associatedWith: nil),
        .remove(offset: 9, element: "Sike", associatedWith: nil),
    ])
    let w = OrderedCollectionDifference<String>.init([
        .insert(offset: 3, element: "Sike", associatedWith: nil),
        .insert(offset: 4, element: "Sike", associatedWith: nil),
        .insert(offset: 2, element: "Hello", associatedWith: 6),
        .remove(offset: 6, element: "Hello", associatedWith: 2),
        .remove(offset: 8, element: "Goodbye", associatedWith: nil),
        .remove(offset: 9, element: "Sike", associatedWith: nil),
    ])
    expectEqual(w, n?.inferringMoves())
}

TestSuite(suite).test("Three way diff demo code") {
    let base = "Is\nit\ntime\nalready?"
    let theirs = "Hi\nthere\nis\nit\ntime\nalready?"
    let mine = "Is\nit\nreview\ntime\nalready?"
    
    // Split the contents of the sources into lines
    let baseLines = base.components(separatedBy: "\n")
    let theirLines = theirs.components(separatedBy: "\n")
    let myLines = mine.components(separatedBy: "\n")
    
    // Create a difference from base to theirs
    let diff = theirLines.shortestEditScript(from:baseLines)
    
    // Apply it to mine, if possible
    guard let patchedLines = myLines.applying(diff) else {
        print("Merge conflict applying patch, manual merge required")
        return
    }
    
    // Reassemble the result
    let patched = patchedLines.joined(separator: "\n")
    expectEqual(patched, "Hi\nthere\nis\nit\nreview\ntime\nalready?")
    // print(patched)
}

TestSuite(suite).test("Diff reversal demo code") {
    let diff = OrderedCollectionDifference<Int>([])!
    let reversed = OrderedCollectionDifference<Int>(
        diff.map({(change) -> OrderedCollectionDifference<Int>.Change in
            switch change {
            case .insert(offset: let o, element: let e, associatedWith: let a):
                return .remove(offset: o, element: e, associatedWith: a)
            case .remove(offset: let o, element: let e, associatedWith: let a):
                return .insert(offset: o, element: e, associatedWith: a)
            }
        })
    )!
    // print(reversed)
}

TestSuite(suite).test("Naive application by enumeration") {
    let base = "Is\nit\ntime\nalready?"
    let theirs = "Hi\nthere\nis\nit\ntime\nalready?"
    
    // Split the contents of the sources into lines
    var arr = base.components(separatedBy: "\n")
    let theirLines = theirs.components(separatedBy: "\n")
    
    // Create a difference from base to theirs
    let diff = theirLines.shortestEditScript(from:arr)
    
    for c in diff {
        switch c {
        case .remove(offset: let o, element: _, associatedWith: _):
            arr.remove(at: o)
        case .insert(offset: let o, element: let e, associatedWith: _):
            arr.insert(e, at: o)
        }
    }
    
    expectEqual(arr, theirLines)
}

TestSuite(suite).test("Fast applicator boundary conditions") {
    let a = [1, 2, 3, 4, 5, 6, 7, 8]
    for removeMiddle in [false, true] {
    for insertMiddle in [false, true] {
    for removeLast in [false, true] {
    for insertLast in [false, true] {
    for removeFirst in [false, true] {
    for insertFirst in [false, true] {
        var b = a

        // Prepare b
        if removeMiddle { b.remove(at: 4) }
        if insertMiddle { b.insert(10, at: 4) }
        if removeLast   { b.removeLast() }
        if insertLast   { b.append(11) }
        if removeFirst  { b.removeFirst() }
        if insertFirst  { b.insert(12, at: 0) }

        // Generate diff
        let diff = b.shortestEditScript(from: a)

        // Validate application
        expectEqual(b, a.applying(diff)!)
    }}}}}}
}

TestSuite(suite).test("Fast applicator fuzzer") {
    func makeArray() -> [UInt32] {
        var arr = [UInt32]()
        for _ in 0..<arc4random_uniform(10) {
            arr.append(arc4random_uniform(20))
        }
        return arr
    }
    for _ in 0..<1000 {
        let a = makeArray()
        let b = makeArray()
        let d = b.shortestEditScript(from: a)
        expectEqual(b, a.applying(d)!)
        if self.testRun!.failureCount > 0 {
            print("""
                // repro:
                let a = \(a)
                let b = \(b)
                let d = b.shortestEditScript(from: a)
                expectEqual(b, a.applying(d))
            """)
            break
        }
    }
}

runAllTests()
