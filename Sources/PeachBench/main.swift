import Foundation
import PeachEngine

/// Wall-clock milliseconds for a block.
///
/// `ContinuousClock` is Swift's monotonic clock: unlike `Date()`, it cannot go
/// backwards if the system clock is adjusted mid-measurement.
@discardableResult
func time<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
    let clock = ContinuousClock()
    var result: T!
    let elapsed = try clock.measure { result = try body() }
    let seconds = Double(elapsed.components.seconds)
        + Double(elapsed.components.attoseconds) / 1e18
    let ms = (seconds * 10_000).rounded() / 10
    print(label.padding(toLength: 54, withPad: " ", startingAt: 0) + "\(ms) ms")
    return result
}

// `_isDebugAssertConfiguration()` folds to a constant at compile time, so a
// ternary on it warns "will never be executed" on the dead branch. An if/else
// on two separate statements says the same thing without the noise.
if _isDebugAssertConfiguration() {
    print("peach-bench — build: DEBUG (numbers are not decision-grade)")
} else {
    print("peach-bench — build: RELEASE")
}
print("")

print("=== Dictionary load ===")
// The boundary list is enable + the SCOWL 95 additions, exactly as the web's
// loadGameData unions them. This is the number that decides whether a sorted
// binary file or SQLite is needed for a real app.
let enable = time("read enable.txt") { try! readWordList("enable.txt") }
let additions = time("read scowl95-additions.txt") { try! readWordList("scowl95-additions.txt") }
let boundary = time("union into the validation list") { enable + additions }
let boundarySet = time("build Set<String> over the boundary list") { Set(boundary) }
print("  boundary words: \(boundary.count), unique: \(boundarySet.count)")
print("")

let common = time("read common-pool.txt") { try! readWordList("common-pool.txt") }
let beyond70 = time("read beyond-size-70.txt") { try! readWordList("beyond-size-70.txt") }
let beyond95 = time("read beyond-size-95.txt") { try! readWordList("beyond-size-95.txt") }
print("")

print("=== Letter counts: one full formability pass ===")
// This used to measure InlineArray against [Int8] side by side. LetterCounts is
// now [Int8]-backed on both sides of that comparison, so there is nothing left
// to compare: the inline version was dropped to lower the deployment floor from
// iOS 26 to iOS 17. The historical 2.5x figure is preserved in
// docs/MEASUREMENTS.md, which is the right place for a number that no longer
// describes the shipped code.
let rack = "serenade"
let hits = time("LetterCounts over the boundary list") { () -> Int in
    let rackCounts = LetterCounts(rack)
    var found = 0
    for word in boundary where word.count >= 3 && rackCounts.canForm(LetterCounts(word)) {
        found += 1
    }
    return found
}
print("  formable words: \(hits)")
print("")

print("=== End-to-end createPuzzle on a real rack ===")
let puzzle = time("createPuzzle(\"serenade\") over the full lists") {
    createPuzzle(
        sourceWord: rack,
        dictionary: ListDictionary(boundary),
        commonPool: ListWordSource(common),
        beyond70Pool: ListWordSource(beyond70),
        beyond95Pool: ListWordSource(beyond95)
    )
}
print("  validation \(puzzle.validationWords.count), set \(puzzle.commonWords.count), "
      + "uncommon \(puzzle.uncommonWords.count), rare \(puzzle.rareWords.count), "
      + "mythic \(puzzle.mythicWords.count), par \(puzzle.reachableScore)")
print("")

print("=== Cold-start budget: what an app actually pays before first paint ===")
// Everything above, from nothing, as a single measurement — the honest figure
// for "how long is the launch screen up if this happens synchronously".
time("full load: 5 lists + validation Set, from cold") {
    let e = try! readWordList("enable.txt")
    let a = try! readWordList("scowl95-additions.txt")
    _ = Set(e + a)
    _ = try! readWordList("common-pool.txt")
    _ = try! readWordList("beyond-size-70.txt")
    _ = try! readWordList("beyond-size-95.txt")
}
