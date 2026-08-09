# Swift Engine Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the pure engine of the Peach of a Word web game to a standalone Swift package, test-first, to find out whether writing Swift is enjoyable and how fast it goes.

**Architecture:** A single SPM library target `PeachEngine` whose files mirror the web repo's `src/engine/*.ts` one-to-one, plus an executable target `PeachBench` for release-mode measurements. The engine talks to word lists only through two protocols, so tests use tiny in-memory lists and the benchmark uses the real 430k-word snapshot. A generated JSON oracle from the original TypeScript pins the date and PRNG behaviour so cross-language agreement is measured, not assumed.

**Tech Stack:** Swift 6.3.3, SwiftPM (`swift-tools-version: 6.2`), Swift Testing (`import Testing`), Foundation (`Calendar`/`TimeZone` only), Node.js (throwaway oracle generator only).

## Global Constraints

Every task's requirements implicitly include this section.

- **Timebox: a couple of focused sessions.** If it runs long, STOP and write the report (Task 16). An honest "this took twice as long, here is why" is a better result than a finished port. The report is the deliverable, not the code.
- **No SwiftUI, no view code, no app target, no persistence, no audio, no theming, no share, no widgets, no data pipeline.**
- **Clear beats clever.** Antoine has never written Swift and is reading this to learn. When an unfamiliar Swift idiom appears for the first time, explain it in a brief `//` comment at the point of use.
- **Never modify `~/Development/peach-of-a-word`.** It is read-only reference and stays canonical.
- **`swift-tools-version: 6.2`, `platforms: [.macOS(.v26)]`.** Both are forced by `InlineArray` (Task 3), which is macOS 26+ and needs PackageDescription 6.2. Verified: tools-version 6.0 fails with `'v26' is unavailable`.
- **Swift Testing, not XCTest.** `import Testing`, `@Suite`, `@Test`, `#expect`. `init` replaces `beforeEach`.
- **Conventional commit messages, written by hand.** Types: feat, fix, docs, style, refactor, test, chore, build, ci, perf, revert. No commitlint, husky, Biome, or dependabot — those are Node conventions and do not apply here.
- **Commit after every task.** Frequent commits.
- **Keep a running log** at `docs/PORT-LOG.md` (created in Task 1): append a dated line per task with elapsed time, what was awkward, and what was pleasant. Task 16 is written from this log, so do not skip it — reconstructing timings from memory at the end is exactly the failure this experiment is trying to avoid.
- **Data snapshot is frozen.** Source commit `475edfc687b6bdce2a1186a80c801ae90bda3e57`, taken 2026-08-09.

## Naming decisions locked here

The TypeScript `Dictionary` interface **cannot** keep its name: Swift's standard library owns `Dictionary`. It becomes `ValidationDictionary`. (Log this — it is report material for the "Swift friction" section.)

Public API surface, referenced across tasks:

| Symbol | Signature | Task |
|---|---|---|
| `minWordLength`, `sourceWordLength`, `minSetSize` | `Int` | 2 |
| `Rung` | `enum Rung: String, Sendable, CaseIterable` | 2 |
| `Rung.bonus` | `var bonus: Int` | 2 |
| `scoreForLength` | `(Int) -> Int` | 2 |
| `scoreWord` | `(String) -> Int` | 2 |
| `findScore` | `(String, rung: Rung) -> Int` | 2 |
| `TierDef`, `tiers` | `struct`, `[TierDef]` | 2 |
| `EpochDate`, `dailyEpoch`, `storageEpoch`, `streakTierIndex` | `struct`, `EpochDate`, `EpochDate`, `Int` | 2 |
| `LetterCounts` | `struct` (InlineArray-backed) | 3 |
| `letterCountsArray`, `canFormArray` | `(String) -> [Int8]`, `([Int8], String) -> Bool` | 3 |
| `formableFrom` | `(rack: String, words: some Sequence<String>) -> [String]` | 3 |
| `WordSource` | `protocol { func formableWords(rack: String) -> [String] }` | 4 |
| `ValidationDictionary` | `protocol: WordSource { func has(_: String) -> Bool }` | 4 |
| `Puzzle` | `struct` | 4 |
| `classifyWord` | `(String, in: Puzzle) -> Rung` | 4 |
| `ListWordSource`, `ListDictionary` | `struct` | 5 |
| `createPuzzle` | `(sourceWord:dictionary:commonPool:beyond70Pool:beyond95Pool:) -> Puzzle` | 5 |
| `TierStanding`, `NextRank` | `struct` | 6 |
| `computeTier` | `(found: Set<String>, puzzle: Puzzle) -> TierStanding` | 6 |
| `isComplete` | `(TierStanding) -> Bool` | 7 |
| `GuessResult` | `enum` with associated values | 8 |
| `normalizeGuess`, `validateGuess` | `(String) -> String`, `(String, puzzle:found:) -> GuessResult` | 8 |
| `sourceSetSize`, `isEligibleSource`, `eligibleSourceWords` | see Task 9 | 9 |
| `seededPermutation` | `(Int, seed: UInt32) -> [Int]` | 10 |
| `generateCalendar` | `(eligible:existing:seed:) -> [String]` | 10 |
| `EngineError` | `enum: Error` | 11 |
| `dayIndex` | `(Date, epoch: EpochDate, timeZone: TimeZone) -> Int` | 12 |
| `dailySourceWord` | `(calendar:date:epoch:timeZone:) throws -> String` | 13 |
| `RandomSource`, `Mulberry32` | `protocol` with `mutating func next() -> Double`, conforming `struct` | 10 |
| `EndlessSource` | `struct EndlessSource<R: RandomSource>` + `mutating func next() -> String` | 14 |

---

### Task 1: Package scaffolding and the frozen data snapshot

**Files:**
- Create: `Package.swift`
- Create: `Sources/PeachEngine/PeachEngine.swift`
- Create: `Sources/PeachBench/main.swift`
- Create: `Tests/PeachEngineTests/SmokeTests.swift`
- Create: `Data/` (7 copied files)
- Create: `README.md`, `SNAPSHOT.md`, `LICENSE`, `docs/PORT-LOG.md`
- Modify: `.gitignore` (already has `.build/`, `.swiftpm/`, `xcuserdata/`, `.DS_Store`)

**Interfaces:**
- Consumes: nothing.
- Produces: a package that builds and tests clean; `Data/` at repo root; `docs/PORT-LOG.md` for every later task to append to.

- [ ] **Step 1: Start the clock**

Note the wall-clock start time. Every task appends elapsed time to `docs/PORT-LOG.md`; the report depends on these numbers being real rather than reconstructed.

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version: 6.2
import PackageDescription

// tools-version 6.2 and macOS 26 are both forced by InlineArray (Sources/
// PeachEngine/Formability.swift), which is macOS 26+. Tools-version 6.0 fails
// with "'v26' is unavailable".
let package = Package(
    name: "PeachEngine",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PeachEngine", targets: ["PeachEngine"]),
        .executable(name: "peach-bench", targets: ["PeachBench"]),
    ],
    targets: [
        .target(name: "PeachEngine"),
        .executableTarget(name: "PeachBench", dependencies: ["PeachEngine"]),
        .testTarget(name: "PeachEngineTests", dependencies: ["PeachEngine"]),
    ]
)
```

- [ ] **Step 3: Write the repo-path helper**

The 8MB snapshot is deliberately NOT an SPM resource — resources get copied into
the test bundle on every build. Tests and the benchmark reach it by a path
relative to their own source file instead.

`Sources/PeachEngine/PeachEngine.swift`:

```swift
import Foundation

/// Absolute path to the repository root, derived from this file's own location
/// at compile time.
///
/// `#filePath` is a Swift magic literal: the compiler substitutes the path of
/// the source file it appears in. TypeScript's nearest equivalent is
/// `import.meta.url`. Used so the 8MB data snapshot can live at the repo root
/// instead of being copied into every build's resource bundle.
public let repositoryRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Sources/PeachEngine
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // repo root

/// Directory holding the frozen data snapshot. See SNAPSHOT.md.
public let dataDirectory: URL = repositoryRoot.appendingPathComponent("Data")

/// Read a newline-delimited word list, trimming blanks. Used by the benchmark
/// and by any test that wants the real lists rather than a fixture.
public func readWordList(_ name: String) throws -> [String] {
    let text = try String(contentsOf: dataDirectory.appendingPathComponent(name), encoding: .utf8)
    return text.split(separator: "\n").compactMap {
        let w = $0.trimmingCharacters(in: .whitespaces)
        return w.isEmpty ? nil : w
    }
}
```

- [ ] **Step 4: Write a placeholder benchmark entry point**

`Sources/PeachBench/main.swift`:

```swift
import PeachEngine

// Filled in by Task 15. Present from Task 1 so the executable target builds.
print("peach-bench: measurements land here in Task 15.")
```

- [ ] **Step 5: Copy the data snapshot**

```bash
mkdir -p Data
SRC=~/Development/peach-of-a-word/public/data
cp "$SRC/enable.txt" "$SRC/scowl95-additions.txt" "$SRC/common-pool.txt" \
   "$SRC/beyond-size-70.txt" "$SRC/beyond-size-95.txt" \
   "$SRC/daily-calendar.json" "$SRC/meta.json" Data/
ls -la Data && du -sh Data
```

Expected: 7 files, roughly 8.0M total.

- [ ] **Step 6: Write the smoke test**

`Tests/PeachEngineTests/SmokeTests.swift`:

```swift
import Foundation
import Testing
@testable import PeachEngine

@Suite("package smoke")
struct SmokeTests {
    @Test("the frozen data snapshot is present and the expected size")
    func snapshotPresent() throws {
        // Counts are `wc -l` of the snapshot files, which is one less than
        // meta.json's counts where a file has no trailing newline. Asserting on
        // what actually parses, not on what meta.json claims.
        #expect(try readWordList("enable.txt").count == 172_561)
        #expect(try readWordList("scowl95-additions.txt").count == 254_727)
        #expect(try readWordList("common-pool.txt").count == 10_878)
        #expect(try readWordList("beyond-size-70.txt").count == 315_921)
        #expect(try readWordList("beyond-size-95.txt").count == 5_388)
    }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `swift test`
Expected: PASS, 1 test. If a count differs, the snapshot copied wrong — recopy rather than editing the expectation.

- [ ] **Step 8: Write `SNAPSHOT.md`**

```markdown
# Data snapshot

Copied from `~/Development/peach-of-a-word`, which stays canonical. These files
are frozen: they are never synced, only re-snapshotted deliberately.

- Source commit: `475edfc687b6bdce2a1186a80c801ae90bda3e57` (475edfc)
- Snapshot taken: 2026-08-09
- Data generated at (from `meta.json`): 2026-06-24T15:11:59.569Z

If the Swift side ever disagrees with the web, the first question is whether the
data drifted or the logic did. The SHA answers that in seconds.

## Included (7 files, ~8MB)

`enable.txt`, `scowl95-additions.txt`, `common-pool.txt`, `beyond-size-70.txt`,
`beyond-size-95.txt`, `daily-calendar.json`, `meta.json`

## Excluded, by decision

- `defs/` — 795 directories of Wiktionary reveal content. The reveal is out of
  scope for this port.
- `source-pool.json` — the eligibility tests build their own synthetic pools, so
  the real source pool earns no weight here.

Neither is an oversight.
```

- [ ] **Step 9: Write `README.md`**

```markdown
# peach-of-a-word-swift

An experiment, deliberately timeboxed. Not a product, not a v2.

It ports the pure engine of [Peach of a Word](https://github.com/anthonyliddle/peach-of-a-word)
— scoring, rarity classification, the tier ladder, completion, the daily
calendar lookup, and puzzle construction — from TypeScript to Swift, to find out
two things: whether writing Swift is enjoyable, and how fast that actually goes.
The engine was chosen because it is pure, framework-free, and fully unit-tested,
so its existing test suite is an executable spec. That makes this an exercise in
learning one thing (Swift) rather than two.

**The web repo stays canonical.** Nothing here feeds back into it. The word
lists in `Data/` are a frozen snapshot, not a sync — see [SNAPSHOT.md](SNAPSHOT.md)
for the date and source commit.

No UI, no persistence, no audio, no theming, no data pipeline. Those are the
rewrite half and are explicitly out of scope.

The result of the experiment is [docs/REPORT.md](docs/REPORT.md).

## Running it

```bash
swift test                              # the ported suite
swift run -c release peach-bench        # dictionary load + letter-count timings
```

Release mode matters for the benchmark: debug Swift string and collection work
is often around 10x slower, and a debug number would argue for a different
storage format on a lie.

## Licence

MIT. See [LICENSE](LICENSE).
```

- [ ] **Step 10: Write `LICENSE` (MIT, copyright Anthony Liddle) and start the log**

`docs/PORT-LOG.md`:

```markdown
# Port log

One line per task. Feeds docs/REPORT.md. Record honestly, including the parts
that went badly — the friction is half the answer.

| Task | Elapsed | Awkward | Pleasant |
|---|---|---|---|
| 1. Scaffolding | | | |
```

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "chore: scaffold the Swift package and freeze the data snapshot"
```

---

### Task 2: Config, Rung, and the scoring curve

Ports `src/engine/config.ts` and `src/engine/scoring.ts`. Test source: `src/engine/scoring.test.ts`.

**Files:**
- Create: `Sources/PeachEngine/Config.swift`
- Create: `Sources/PeachEngine/Scoring.swift`
- Create: `Tests/PeachEngineTests/ScoringTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `minWordLength`, `sourceWordLength`, `minSetSize`, `Rung`, `Rung.bonus`, `scoreForLength`, `scoreWord`, `findScore`, `TierDef`, `tiers`, `EpochDate`, `dailyEpoch`, `storageEpoch`, `streakTierIndex`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/ScoringTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("scoreWord")
struct ScoreWordTests {
    // `arguments:` runs the test body once per tuple, each reported separately.
    // It is the Swift Testing answer to a hand-rolled loop of expectations.
    @Test("follows the GDD curve: 3=1, 4=3, 5=5, 6=7, 7=11, 8=15",
          arguments: [("cat", 1), ("cats", 3), ("scale", 5),
                      ("scaled", 7), ("scalene", 11), ("serenade", 15)])
    func curve(word: String, points: Int) {
        #expect(scoreWord(word) == points)
    }

    @Test("scores below the minimum length as zero")
    func belowMinimum() {
        #expect(scoreWord("at") == 0)
        #expect(scoreWord("") == 0)
    }

    // No TypeScript counterpart: the `length > 8 -> 15` branch is untested
    // there. A Swift switch with `case 8...` makes it explicit, so test it.
    @Test("caps at the 8-letter score for anything longer")
    func aboveSourceLength() {
        #expect(scoreForLength(9) == 15)
        #expect(scoreForLength(20) == 15)
    }
}

@Suite("findScore")
struct FindScoreTests {
    @Test("adds the rarity bonus on top of the length curve, none for a set word")
    func bonuses() {
        #expect(findScore("cat", rung: .set) == 1)
        #expect(findScore("serenade", rung: .set) == 15)
        #expect(findScore("cat", rung: .uncommon) == 1 + 1)
        #expect(findScore("scale", rung: .rare) == 5 + 2)
        #expect(findScore("scaled", rung: .mythic) == 7 + 4)
    }
}

@Suite("the tier ladder")
struct TierLadderTests {
    @Test("has six ranks with the top at 0.80 of par")
    func ladder() {
        #expect(tiers.count == 6)
        #expect(tiers.map(\.threshold) == [0, 0.08, 0.22, 0.4, 0.6, 0.8])
        #expect(tiers.last?.threshold == 0.8)
    }

    @Test("keeps the storage epoch fixed and separate from the daily epoch")
    func epochs() {
        // STORAGE_EPOCH never moves, even when DAILY_EPOCH is re-anchored by a
        // calendar regeneration. Persisted day keys depend on it.
        #expect(storageEpoch == EpochDate(year: 2026, month: 1, day: 1))
        #expect(dailyEpoch == EpochDate(year: 2026, month: 6, day: 23))
        #expect(storageEpoch != dailyEpoch)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'scoreWord' in scope` and similar.

- [ ] **Step 3: Write `Config.swift`**

```swift
/// Game rules. Numbers the GDD flags as tunable live here as named constants,
/// not scattered literals: the scoring curve, the tier ladder, the epochs.
///
/// These are top-level constants rather than members of an enum namespace,
/// deliberately: it is the closest Swift shape to the TypeScript module of
/// exported consts this is ported from, which keeps the two readable side by
/// side. In Swift 6 a global `let` must be immutable and `Sendable`; every type
/// here satisfies that.

/// Minimum playable word length, honoring the original game.
public let minWordLength = 3

/// The source word is always exactly 8 letters.
public let sourceWordLength = 8

/// Minimum set size for a source word to headline a puzzle. Crown-inclusive.
/// A daily under this floor felt thin, so sub-floor words stay real words found
/// inside other racks but never headline a day.
public let minSetSize = 15

/// Where a found word sits relative to the set. The set is the goal and carries
/// no rarity label; everything off the page is graded on the three-rung ladder.
///
/// A Swift `enum` with a raw value. Unlike the TypeScript string-union it ports
/// (`'set' | 'uncommon' | 'rare' | 'mythic'`), a `switch` over it is checked for
/// exhaustiveness by the compiler — adding a rung later breaks every site that
/// needs updating, rather than silently falling through.
public enum Rung: String, Sendable, CaseIterable {
    case set, uncommon, rare, mythic
}

extension Rung {
    /// DRAFT, TUNABLE. The rarity bonus added on top of the length score for an
    /// off-page find. A set word is the on-page baseline and carries no bonus.
    /// These pay for discovery but stay modest, because the ladder denominator
    /// is the set points — a small, stable scale.
    public var bonus: Int {
        switch self {
        case .set: 0
        case .uncommon: 1
        case .rare: 2
        case .mythic: 4
        }
    }
}

/// Score for a word of the given length. 0 below the minimum length.
///
/// `case 8...` is a one-sided range pattern: eight letters or more. The
/// TypeScript this ports used a lookup object plus a `?? (length > 8 ? 15 : 0)`
/// fallback, where the above-8 branch was never tested. Here it is a visible
/// case, and it has a test.
public func scoreForLength(_ length: Int) -> Int {
    switch length {
    case 3: 1
    case 4: 3
    case 5: 5
    case 6: 7
    case 7: 11
    case 8...: 15
    default: 0
    }
}

/// A rung on the named points ladder. Names are theme-skinned in the UI, which
/// this port does not include.
public struct TierDef: Sendable, Equatable {
    /// Theme-neutral id; the displayed name is a per-theme skin over the index.
    public let id: String
    /// Fraction of the rack's reachable score needed to reach this rank (0 to 1).
    public let threshold: Double

    public init(id: String, threshold: Double) {
        self.id = id
        self.threshold = threshold
    }
}

/// The named ladder: six ranks by score as a fraction of the rack's reachable
/// score, low to high. DRAFT, TUNABLE. The top named rank sits at 0.80, not
/// 1.00: finding everything is the completion peak, which sits above this whole
/// ladder. There is no source-word gate on the named ranks.
public let tiers: [TierDef] = [
    TierDef(id: "tier-0", threshold: 0),
    TierDef(id: "tier-1", threshold: 0.08),
    TierDef(id: "tier-2", threshold: 0.22),
    TierDef(id: "tier-3", threshold: 0.4),
    TierDef(id: "tier-4", threshold: 0.6),
    TierDef(id: "tier-5", threshold: 0.8),
]

/// A calendar date with no time and no zone: the anchor for a day index.
public struct EpochDate: Sendable, Equatable {
    public let year: Int
    /// 1 to 12. Note this differs from Foundation's and JavaScript's 0-based
    /// month in `Date`, and matches `DateComponents`, which is also 1-based.
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

/// Day one of the daily sequence (local calendar date). The day index is the
/// number of whole calendar days from this date. Tunable: a calendar
/// regeneration may re-anchor it.
public let dailyEpoch = EpochDate(year: 2026, month: 6, day: 23)

/// Fixed origin for the per-day storage and streak key. This NEVER moves, even
/// when `dailyEpoch` is re-anchored. The crown for a date is selected from the
/// movable `dailyEpoch`, but progress and streak are keyed by days since this
/// fixed origin, so re-anchoring cannot shift the day keys and a streak
/// survives a regeneration with no migration.
public let storageEpoch = EpochDate(year: 2026, month: 1, day: 1)

/// Named-ladder rank a daily must reach to count toward the streak. Index 3 is
/// the 0.40 rung. Tied to the ladder, so revisit if `tiers` changes.
public let streakTierIndex = 3
```

- [ ] **Step 4: Write `Scoring.swift`**

```swift
/// Points for a single word, by its length alone (no rarity bonus).
public func scoreWord(_ word: String) -> Int {
    scoreForLength(word.count)
}

/// Points for a found word: its length score plus the rarity bonus for its rung.
///
/// This is the single scoring path for everything the player earns, so the
/// score, the bar, the glossary, the share, and the reachable total all agree.
/// A set word gets no bonus (the on-page baseline); off-page rungs pay more.
public func findScore(_ word: String, rung: Rung) -> Int {
    scoreForLength(word.count) + rung.bonus
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, all scoring tests.

- [ ] **Step 6: Log and commit**

Append a row to `docs/PORT-LOG.md`. Then:

```bash
git add -A
git commit -m "feat: port the scoring curve, rarity bonuses, and game config"
```

---

### Task 3: Formability, in two shapes

Ports `src/engine/formability.ts`. Test source: `src/engine/formability.test.ts`.

Two implementations of letter counting, deliberately. `letterCountsArray` is the literal translation of the TypeScript `Int8Array(26)` — a heap-allocated buffer per word. `LetterCounts` is a fixed-size value type that lives on the stack. `formableFrom` calls one of them once per candidate word across 430k words, so this is the one place in the port where a value-versus-reference choice has a number attached to it. Task 15 measures the difference.

**Files:**
- Create: `Sources/PeachEngine/Formability.swift`
- Create: `Tests/PeachEngineTests/FormabilityTests.swift`

**Interfaces:**
- Consumes: `minWordLength` (Task 2).
- Produces: `LetterCounts` (with `init(_ word: String)` and `canForm(_ need: LetterCounts) -> Bool`), `letterCountsArray(_:) -> [Int8]`, `canFormArray(_:_:) -> Bool`, `formableFrom(rack:words:) -> [String]`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/FormabilityTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("canForm")
struct CanFormTests {
    // `let` properties on a @Suite struct replace vitest's module-level consts.
    // Swift Testing creates a fresh instance per test, so this is also the
    // `beforeEach` replacement: no shared mutable state between tests.
    let rack = LetterCounts("serenade")  // s e r e n a d e -> three e's

    @Test("forms a word using available tiles")
    func forms() {
        #expect(rack.canForm(LetterCounts("sneer")))
        #expect(rack.canForm(LetterCounts("eased")))
    }

    @Test("respects tile multiplicity")
    func multiplicity() {
        #expect(!LetterCounts("eeen").canForm(LetterCounts("eeee")))
        #expect(rack.canForm(LetterCounts("eee")))
    }

    @Test("rejects words needing a letter not in the rack")
    func missingLetter() {
        #expect(!rack.canForm(LetterCounts("zebra")))
    }

    // The array-backed variant must agree with the inline one everywhere. If
    // these ever disagree, the Task 15 measurement is comparing two different
    // functions rather than two representations of the same one.
    @Test("the array-backed variant agrees with the inline one",
          arguments: ["sneer", "eased", "zebra", "eee", "eeee", "serenade", "ad"])
    func variantsAgree(word: String) {
        #expect(rack.canForm(LetterCounts(word))
                == canFormArray(letterCountsArray("serenade"), word))
    }
}

@Suite("formableFrom")
struct FormableFromTests {
    @Test("keeps formable words of length 3 and up, in input order")
    func filters() {
        let words = ["ad", "sea", "sneer", "zebra", "serene"]
        // "ad" is too short; "zebra" needs a z. "serene" needs three e's, and
        // "serenade" has exactly three.
        #expect(formableFrom(rack: "serenade", words: words) == ["sea", "sneer", "serene"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'LetterCounts' in scope`.

- [ ] **Step 3: Write `Formability.swift`**

```swift
/// Count of each letter a-z, held inline as a fixed-size value type.
///
/// `InlineArray<26, Int8>` is a fixed-size array stored *in* the struct rather
/// than in a separately allocated heap buffer, so constructing one allocates
/// nothing. Swift's ordinary `Array` cannot do this: it is a reference to a
/// heap buffer with copy-on-write semantics, which is what `letterCountsArray`
/// below deliberately uses so the two can be compared. TypeScript's
/// `Int8Array(26)` is always the heap-allocated shape.
///
/// Requires macOS 26, which is why Package.swift pins that platform.
public struct LetterCounts: Sendable {
    private var counts: InlineArray<26, Int8> = .init(repeating: 0)

    /// Non-letters and non-ASCII bytes are ignored, matching the TypeScript.
    public init(_ word: String) {
        // Iterating `.utf8` rather than `Character` is both faster and closer
        // to the original's `charCodeAt`. Swift's `Character` is a grapheme
        // cluster, which is the right default for text but the wrong unit here.
        for byte in word.utf8 where byte >= 97 && byte <= 122 {
            counts[Int(byte) - 97] += 1
        }
    }

    /// True if a word needing `need` can be spelled from this rack, each tile
    /// used at most once.
    public func canForm(_ need: LetterCounts) -> Bool {
        for i in 0..<26 where need.counts[i] > counts[i] {
            return false
        }
        return true
    }
}

/// The literal translation of the TypeScript `Int8Array(26)`: a heap-allocated
/// buffer per call. Kept alongside `LetterCounts` only so Task 15 can measure
/// what the allocation costs across the 430k-word boundary list.
public func letterCountsArray(_ word: String) -> [Int8] {
    var counts = [Int8](repeating: 0, count: 26)
    for byte in word.utf8 where byte >= 97 && byte <= 122 {
        counts[Int(byte) - 97] += 1
    }
    return counts
}

/// `canForm` over the array-backed representation. Must agree with
/// `LetterCounts.canForm` on every input; there is a test that says so.
public func canFormArray(_ rackCounts: [Int8], _ word: String) -> Bool {
    let need = letterCountsArray(word)
    for i in 0..<26 where need[i] > rackCounts[i] {
        return false
    }
    return true
}

/// Filter a word list to those formable from the rack, length >= the minimum.
/// The rack's letter counts are computed once for the whole pass.
///
/// `some Sequence<String>` is an opaque parameter type: the caller may pass an
/// Array, a Set, or anything else that iterates Strings, and the compiler
/// specialises for the concrete type. It is the Swift answer to TypeScript's
/// `Iterable<string>`, but resolved at compile time rather than at runtime.
public func formableFrom(rack: String, words: some Sequence<String>) -> [String] {
    let rackCounts = LetterCounts(rack)
    var out: [String] = []
    for word in words where word.count >= minWordLength && rackCounts.canForm(LetterCounts(word)) {
        out.append(word)
    }
    return out
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Log and commit**

```bash
git add -A
git commit -m "feat: port formability with inline and heap letter-count shapes"
```

---

### Task 4: Core types and rarity classification

Ports the `Puzzle` half of `src/engine/types.ts` and all of `src/engine/classify.ts`. Test source: `src/engine/classify.test.ts`.

**Files:**
- Create: `Sources/PeachEngine/Types.swift`
- Create: `Sources/PeachEngine/Classify.swift`
- Create: `Tests/PeachEngineTests/ClassifyTests.swift`

**Interfaces:**
- Consumes: `Rung` (Task 2).
- Produces: `protocol WordSource`, `protocol ValidationDictionary`, `struct Puzzle` (memberwise init with all eight fields), `classifyWord(_:in:) -> Rung`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/ClassifyTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("classifyWord")
struct ClassifyTests {
    // Hand-placed bands so the precedence is exercised directly. The four sets
    // are disjoint, as createPuzzle guarantees: a word lands in exactly one.
    let puzzle = Puzzle(
        sourceWord: "national",
        letters: "ailnnoat",
        validationWords: ["national", "nation", "ulna", "talon", "anti"],
        commonWords: ["national", "nation"],
        uncommonWords: ["ulna"],   // in SCOWL 70, not the set
        rareWords: ["talon"],      // in SCOWL 95, not 70
        mythicWords: ["anti"],     // beyond SCOWL 95
        reachableScore: 0
    )

    @Test("classifies a set word as set")
    func setWord() {
        #expect(classifyWord("nation", in: puzzle) == .set)
    }

    @Test("classifies the source word as set, like any other set word")
    func sourceWord() {
        #expect(classifyWord("national", in: puzzle) == .set)
    }

    @Test("classifies a size-70-not-set word as uncommon")
    func uncommon() {
        #expect(classifyWord("ulna", in: puzzle) == .uncommon)
    }

    @Test("classifies a size-95-not-70 word as rare")
    func rare() {
        #expect(classifyWord("talon", in: puzzle) == .rare)
    }

    @Test("classifies an ENABLE-beyond-95 word as mythic")
    func mythic() {
        #expect(classifyWord("anti", in: puzzle) == .mythic)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'Puzzle' in scope`.

- [ ] **Step 3: Write `Types.swift`**

```swift
/// A source of words formable from a rack. Backed by a baked word list.
///
/// A Swift `protocol` is the near-exact analogue of the TypeScript `interface`
/// this ports. The difference that matters: a Swift type must *declare* that it
/// conforms, whereas TypeScript interfaces are structural — anything with a
/// matching shape satisfies them implicitly.
public protocol WordSource {
    /// All words in this source, length >= the minimum, formable from the rack.
    func formableWords(rack: String) -> [String]
}

/// The validation dictionary (ENABLE). Adds single-word membership.
///
/// Named `ValidationDictionary`, not `Dictionary`: Swift's standard library
/// already owns that name. This is the first of several places where the port
/// could not keep the TypeScript's naming.
public protocol ValidationDictionary: WordSource {
    /// True if the word is in the dictionary (ignores formability).
    func has(_ word: String) -> Bool
}

/// A fully resolved puzzle: a source word and everything derived from it.
///
/// A `struct`, so it has value semantics: passing one to a function hands over
/// an independent copy, and there is no way for a caller to mutate a Puzzle
/// another part of the program is holding. The TypeScript approximated this
/// with `readonly` fields and `ReadonlySet`, which the compiler enforces but
/// which vanish at runtime.
public struct Puzzle: Sendable, Equatable {
    /// The 8-letter answer.
    public let sourceWord: String
    /// The 8 rack letters, sorted for a stable canonical form.
    public let letters: String
    /// Every ENABLE word formable from the rack (the full validation set).
    public let validationWords: Set<String>
    /// Every set word formable from the rack. The completion denominator, by count.
    public let commonWords: Set<String>
    /// Off-page finds in SCOWL size 70 but not in the set. The first rung.
    public let uncommonWords: Set<String>
    /// Off-page finds in SCOWL size 95 but not in size 70. The second rung.
    public let rareWords: Set<String>
    /// Off-page finds valid in ENABLE but beyond SCOWL size 95. The top rung.
    public let mythicWords: Set<String>
    /// Par: the total SET points available on this rack — every common word
    /// scored by length, source word included, with no rarity bonuses. The
    /// denominator the named points ladder runs against.
    ///
    /// This is the single most load-bearing decision in the model. Note that
    /// the TypeScript's doc comment on this field claims something different
    /// ("every findable word scored by length plus its rarity bonus") and is
    /// stale; `puzzle.ts` computes set points only. No TypeScript test catches
    /// the divergence, because `tiers.test.ts` hand-builds its fixture.
    public let reachableScore: Int

    public init(
        sourceWord: String,
        letters: String,
        validationWords: Set<String>,
        commonWords: Set<String>,
        uncommonWords: Set<String>,
        rareWords: Set<String>,
        mythicWords: Set<String>,
        reachableScore: Int
    ) {
        self.sourceWord = sourceWord
        self.letters = letters
        self.validationWords = validationWords
        self.commonWords = commonWords
        self.uncommonWords = uncommonWords
        self.rareWords = rareWords
        self.mythicWords = mythicWords
        self.reachableScore = reachableScore
    }
}
```

- [ ] **Step 4: Write `Classify.swift`**

```swift
/// Classify a found word by precedence: in the set, else the first rarity rung
/// it falls in.
///
///   set  >  uncommon (SCOWL 70)  >  rare (SCOWL 95)  >  mythic (beyond 95)
///
/// The puzzle's four bands are disjoint, so the order is belt and braces rather
/// than strictly required, but it states the model plainly. Only ever called on
/// a valid found word, which is in exactly one band.
public func classifyWord(_ word: String, in puzzle: Puzzle) -> Rung {
    if puzzle.commonWords.contains(word) { return .set }
    if puzzle.uncommonWords.contains(word) { return .uncommon }
    if puzzle.rareWords.contains(word) { return .rare }
    return .mythic
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Log and commit**

```bash
git add -A
git commit -m "feat: port the core puzzle types and rarity classification"
```

---

### Task 5: List-backed sources and createPuzzle

Ports `src/data/listSource.ts` and `src/engine/puzzle.ts`. Test source: the `createPuzzle` half of `src/engine/puzzle.test.ts`.

**Files:**
- Create: `Sources/PeachEngine/ListSource.swift`
- Create: `Sources/PeachEngine/PuzzleBuilder.swift`
- Create: `Tests/PeachEngineTests/PuzzleFixture.swift`
- Create: `Tests/PeachEngineTests/PuzzleTests.swift`

**Interfaces:**
- Consumes: `WordSource`, `ValidationDictionary`, `Puzzle` (Task 4); `formableFrom` (Task 3); `findScore` (Task 2).
- Produces: `ListWordSource`, `ListDictionary`, `createPuzzle(sourceWord:dictionary:commonPool:beyond70Pool:beyond95Pool:) -> Puzzle`, and a shared test fixture `serenadePuzzle` reused by Task 8.

- [ ] **Step 1: Write the shared fixture**

`Tests/PeachEngineTests/PuzzleFixture.swift`:

```swift
@testable import PeachEngine

// The web repo's puzzle.test.ts fixture, shared between PuzzleTests and
// ValidateTests so both grade against the same rack.
enum Fixture {
    static let enable = [
        "serenade", "sneer", "eased", "sea", "near", "dean", "sane",
        "zebra",  // not formable from serenade (needs z, b)
        "ad",     // too short
    ]
    static let common = ["sea", "near", "dean", "serenade"]
    // 'sneer' is in size 70      -> uncommon (not beyond 70)
    // 'eased' is beyond 70, in 95 -> rare
    // 'sane'  is beyond 95        -> mythic
    static let beyond70 = ["eased", "sane"]
    static let beyond95 = ["sane"]

    static let puzzle = createPuzzle(
        sourceWord: "serenade",
        dictionary: ListDictionary(enable),
        commonPool: ListWordSource(common),
        beyond70Pool: ListWordSource(beyond70),
        beyond95Pool: ListWordSource(beyond95)
    )
}
```

- [ ] **Step 2: Write the failing tests**

`Tests/PeachEngineTests/PuzzleTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("createPuzzle")
struct CreatePuzzleTests {
    let puzzle = Fixture.puzzle

    @Test("derives the rack as the sorted source letters")
    func rack() {
        #expect(puzzle.letters == "adeeenrs")
    }

    @Test("collects the formable ENABLE words as the validation set")
    func validation() {
        #expect(puzzle.validationWords
                == ["serenade", "sneer", "eased", "sea", "near", "dean", "sane"])
    }

    @Test("collects the formable set words as the completion denominator")
    func common() {
        #expect(puzzle.commonWords == Set(Fixture.common))
    }

    @Test("partitions the off-page finds into the three rarity rungs")
    func rungs() {
        #expect(puzzle.uncommonWords == ["sneer"])
        #expect(puzzle.rareWords == ["eased"])
        #expect(puzzle.mythicWords == ["sane"])
    }

    @Test("keeps the four bands disjoint and covering the whole validation set")
    func partition() {
        let union = puzzle.commonWords
            .union(puzzle.uncommonWords)
            .union(puzzle.rareWords)
            .union(puzzle.mythicWords)
        #expect(union == puzzle.validationWords)
        let sizes = puzzle.commonWords.count + puzzle.uncommonWords.count
            + puzzle.rareWords.count + puzzle.mythicWords.count
        #expect(sizes == puzzle.validationWords.count)  // no overlap
    }

    // Par is the SET points, not every findable word. This is the assertion
    // that pins the decision the TypeScript's stale doc comment contradicts.
    @Test("scores par from the set points alone, with no rarity bonuses")
    func par() {
        // sea 1 + near 3 + dean 3 + serenade 15 = 22
        #expect(puzzle.reachableScore == 22)
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'createPuzzle' in scope`.

- [ ] **Step 4: Write `ListSource.swift`**

```swift
/// A `WordSource` backed by an in-memory word list.
///
/// The engine talks only to the `WordSource` / `ValidationDictionary`
/// protocols, so this list-backed form (used for the baked assets and for
/// tests) can be swapped for a sorted binary file or SQLite later without the
/// engine noticing.
public struct ListWordSource: WordSource {
    private let words: [String]

    public init(_ words: some Sequence<String>) {
        self.words = Array(words)
    }

    public func formableWords(rack: String) -> [String] {
        formableFrom(rack: rack, words: words)
    }
}

/// A `ValidationDictionary` (a `WordSource` plus membership) backed by a list.
public struct ListDictionary: ValidationDictionary {
    private let words: Set<String>

    public init(_ words: some Sequence<String>) {
        self.words = Set(words)
    }

    public func has(_ word: String) -> Bool {
        words.contains(word)
    }

    // Iterating a Set, so the returned order is unspecified. Every caller feeds
    // the result straight into a Set, so order never escapes.
    public func formableWords(rack: String) -> [String] {
        formableFrom(rack: rack, words: words)
    }
}
```

- [ ] **Step 5: Write `PuzzleBuilder.swift`**

```swift
/// Sort a word's letters for a stable canonical rack form.
private func sortLetters(_ word: String) -> String {
    String(word.sorted())
}

/// Summed find score for a band of words at a known rung.
private func bandScore(_ words: some Sequence<String>, rung: Rung) -> Int {
    words.reduce(0) { $0 + findScore($1, rung: rung) }
}

/// Build a full puzzle from a source word.
///
/// - `validationWords`: every ENABLE word formable from the rack.
/// - `commonWords`: every set word formable from the rack, intersected with the
///   validation set so the completion denominator is always achievable.
/// - the rarity ladder: every formable validation word outside the set, graded
///   by SCOWL membership. The two rarity pools carry the words BEYOND a SCOWL
///   size band (the compact complement: ENABLE minus the band), so:
///     - uncommon = in size 70 (not beyond 70), and not in the set
///     - rare     = beyond size 70 but in size 95 (not beyond 95)
///     - mythic   = beyond size 95
///   The four bands are disjoint and together partition the validation set.
public func createPuzzle(
    sourceWord: String,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> Puzzle {
    let validationWords = Set(dictionary.formableWords(rack: sourceWord))
    // The source word is in ENABLE and formable from itself, so it is
    // guaranteed present; assert nothing, just rely on the formable set.
    let commonWords = Set(commonPool.formableWords(rack: sourceWord)
        .filter { validationWords.contains($0) })
    let beyond70 = Set(beyond70Pool.formableWords(rack: sourceWord)
        .filter { validationWords.contains($0) })
    let beyond95 = Set(beyond95Pool.formableWords(rack: sourceWord)
        .filter { validationWords.contains($0) })

    // In size 70 (not beyond it) and not a set word.
    let uncommonWords = validationWords.subtracting(beyond70).subtracting(commonWords)
    // Beyond 70 but within 95. Set words live in size 70, so none leak in here.
    let rareWords = beyond70.subtracting(beyond95)
    // Beyond 95. Set words never reach this far.
    let mythicWords = beyond95

    // Par: the set points — every common word at length, source word included,
    // no rarity bonuses. The named ladder runs against this. Off-page finds
    // still earn their points into the score, so they climb faster and overflow
    // the bar past the top named rank, but they are NOT part of the
    // denominator. Using the huge off-page tail as the ceiling would make the
    // ladder unclimbable; set points are the stable, per-rack-consistent scale.
    let reachableScore = bandScore(commonWords, rung: .set)

    return Puzzle(
        sourceWord: sourceWord,
        letters: sortLetters(sourceWord),
        validationWords: validationWords,
        commonWords: commonWords,
        uncommonWords: uncommonWords,
        rareWords: rareWords,
        mythicWords: mythicWords,
        reachableScore: reachableScore
    )
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 7: Log and commit**

```bash
git add -A
git commit -m "feat: port createPuzzle and the list-backed word sources"
```

---

### Task 6: computeTier

Ports `src/engine/tiers.ts` and the `TierStanding` half of `src/engine/types.ts`. Test source: `src/engine/tiers.test.ts`.

**Files:**
- Create: `Sources/PeachEngine/Tiers.swift`
- Create: `Tests/PeachEngineTests/TierTests.swift`

**Interfaces:**
- Consumes: `tiers`, `findScore` (Task 2); `Puzzle` (Task 4); `classifyWord` (Task 4).
- Produces: `struct NextRank`, `struct TierStanding`, `computeTier(found:puzzle:) -> TierStanding`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/TierTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("computeTier (named points ladder, set-points denominator)")
struct TierTests {
    // Synthetic words chosen by length so the scores are easy to reason about.
    // Lengths: 3=1, 4=3, 5=5, 6=7, 7=11, 8=15; off-page adds uncommon +1 /
    // rare +2 / mythic +4.
    static let source = "srcsrcsr"                                    // 8 letters, set, 15
    static let set = [source, "aaaa", "bbbb", "ccccc", "ddddd", "eee"] // 15+3+3+5+5+1 = 32
    static let uncommon = ["ffffff"]                                   // 7 + 1 = 8
    static let rare = ["ggggggg"]                                      // 11 + 2 = 13
    static let mythic = ["hhhhhhhh"]                                   // 15 + 4 = 19

    let puzzle = Puzzle(
        sourceWord: source,
        letters: "srcsrcsr",
        validationWords: Set(set + uncommon + rare + mythic),
        commonWords: Set(set),
        uncommonWords: Set(uncommon),
        rareWords: Set(rare),
        mythicWords: Set(mythic),
        reachableScore: 32
    )

    @Test("runs against the set points, not the huge off-page tail")
    func denominator() {
        #expect(puzzle.reachableScore == 32)
    }

    @Test("starts at the first rank with nothing found")
    func empty() {
        let t = computeTier(found: [], puzzle: puzzle)
        #expect(t.index == 0)
        #expect(t.score == 0)
        #expect(t.fraction == 0)
        #expect(t.setFound == 0)
        #expect(t.setTotal == 6)
        #expect(t.next == NextRank(index: 1, threshold: 0.08))
    }

    @Test("lets an off-page find climb the ladder (rarity pays more)")
    func offPageClimbs() {
        // The mythic word is 19 of 32 (~0.59): past the 0.40 rung, on points alone.
        let t = computeTier(found: Set(Self.mythic), puzzle: puzzle)
        #expect(t.score == 19)
        #expect(abs(t.fraction - 19.0 / 32.0) < 1e-12)
        #expect(t.index == 3)
    }

    @Test("splits points into set and off-page for the two-color bar")
    func split() {
        let t = computeTier(found: ["ccccc", "hhhhhhhh"], puzzle: puzzle)
        #expect(t.setPoints == 5)
        #expect(t.offPagePoints == 19)
        #expect(t.score == 24)
    }

    @Test("counts set words for the completion celebration, separate from the rank")
    func setCounting() {
        let t = computeTier(found: [Self.source, "aaaa", "hhhhhhhh"], puzzle: puzzle)
        #expect(t.setFound == 2)  // source and aaaa are set words; hhhhhhhh is not
        #expect(t.setTotal == 6)
    }

    // The whole reason for this model: the old set gate walled a player at
    // "21 of 23" even with rare finds and the source word. Under points,
    // off-page finds carry past unfound set words to the TOP named rank.
    @Test("reaches the top named rank with set words unfound (the 21 of 23 guard)")
    func topWithUnfoundSet() {
        let found: Set<String> = Set(
            [Self.source, "bbbb", "ccccc", "ddddd"] + Self.uncommon + Self.rare + Self.mythic
        )
        let t = computeTier(found: found, puzzle: puzzle)
        #expect(t.setFound == 4)  // 2 of 6 set words still unfound
        #expect(t.index == 5)     // top named rank, not walled below it
        #expect(t.isTop)
        #expect(t.next == nil)
    }

    @Test("keeps the top named rank below full completion, with points overflowing")
    func overflow() {
        // 0.80 * 32 = 25.6. source + ddddd + ccccc + bbbb = 28 of 32.
        let nearTop = computeTier(found: [Self.source, "ddddd", "ccccc", "bbbb"], puzzle: puzzle)
        #expect(nearTop.setFound < nearTop.setTotal)
        #expect(nearTop.index == 5)

        // Off-page points overflow past 1.0 but unlock no higher named rank.
        let everything = computeTier(found: puzzle.validationWords, puzzle: puzzle)
        #expect(everything.fraction > 1)
        #expect(everything.index == 5)
        #expect(everything.isTop)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'computeTier' in scope`.

- [ ] **Step 3: Write `Tiers.swift`**

```swift
/// The next rank up, and the fraction needed to reach it.
public struct NextRank: Sendable, Equatable {
    public let index: Int
    public let threshold: Double

    public init(index: Int, threshold: Double) {
        self.index = index
        self.threshold = threshold
    }
}

/// A computed standing on the named points ladder.
///
/// The rank is score as a fraction of the rack's reachable score, so every find
/// (set or off-page) moves it up and rarity pays more. Theme-neutral: the
/// displayed rank name is skinned over `index` in the UI, which this port does
/// not include. `setFound`/`setTotal` are carried for the completion
/// celebration, never to grade the ladder.
public struct TierStanding: Sendable, Equatable {
    /// Index into the named ladder (0 to 5).
    public let index: Int
    public let id: String
    /// Points earned so far: length scores plus rarity bonuses.
    public let score: Int
    /// Par: total set points available on the rack (the denominator).
    public let reachable: Int
    /// score / reachable, 0 to 1 — and above 1 once off-page points overflow.
    public let fraction: Double
    /// Points from set (on-page) finds, for the two-color bar.
    public let setPoints: Int
    /// Points from off-page finds, for the two-color bar.
    public let offPagePoints: Int
    /// Set words found. Feeds `isComplete`, not the rank.
    public let setFound: Int
    /// Total set words. Feeds `isComplete`, not the rank.
    public let setTotal: Int
    /// The next rank, or nil at the top named rank.
    ///
    /// A genuine Optional, unlike the TypeScript's `| null`: the compiler will
    /// not let a caller read `.index` off it without handling the nil case.
    public let next: NextRank?
    /// True once the top named rank is reached (below full completion).
    public let isTop: Bool
}

/// Compute the standing on the named points ladder.
///
/// The rank is score (length plus rarity bonuses) as a fraction of par. There
/// is no set gate and no source-word gate: the old set-fraction goal that
/// walled a player at "X of Y" is gone. `setFound` and `setTotal` are still
/// tallied, but only for completion, never to grade the ladder.
public func computeTier(found: Set<String>, puzzle: Puzzle) -> TierStanding {
    var score = 0
    var setPoints = 0
    var offPagePoints = 0
    var setFound = 0

    for word in found {
        let rung = classifyWord(word, in: puzzle)
        let points = findScore(word, rung: rung)
        score += points
        if rung == .set {
            setPoints += points
            setFound += 1
        } else {
            offPagePoints += points
        }
    }

    let reachable = puzzle.reachableScore
    let fraction = reachable > 0 ? Double(score) / Double(reachable) : 0

    // Highest rank whose threshold the fraction meets.
    var index = 0
    for i in tiers.indices where fraction >= tiers[i].threshold {
        index = i
    }

    // `tiers[index + 1]` would trap on the last rank. Swift arrays do not
    // return undefined for an out-of-bounds read the way JavaScript does — they
    // crash — so the bound is checked explicitly and turned into an Optional.
    let next = index + 1 < tiers.count
        ? NextRank(index: index + 1, threshold: tiers[index + 1].threshold)
        : nil

    return TierStanding(
        index: index,
        id: tiers[index].id,
        score: score,
        reachable: reachable,
        fraction: fraction,
        setPoints: setPoints,
        offPagePoints: offPagePoints,
        setFound: setFound,
        setTotal: puzzle.commonWords.count,
        next: next,
        isTop: index == tiers.count - 1
    )
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Log and commit**

```bash
git add -A
git commit -m "feat: port computeTier and the named points ladder"
```

---

### Task 7: Completion — the first deliberate deviation

No TypeScript engine counterpart. In the web repo, completion is computed in the UI, twice:

- `src/ui/share/shareResult.ts:56` — `tier.setTotal > 0 && tier.setFound >= tier.setTotal`
- `src/ui/useGame.ts:602` — `active.tier.setFound + (result.rung === 'set' ? 1 : 0) >= active.tier.setTotal`, with **no** `setTotal > 0` guard

They cannot diverge today only because `minSetSize = 15` guarantees `setTotal >= 15`. Two computations of the same fact, agreeing by an invariant enforced in a third file. The Swift side gets exactly one.

**Do not fix the web repo.** It is out of scope; the finding goes in the report and gets its own change.

**Files:**
- Create: `Sources/PeachEngine/Completion.swift`
- Create: `Tests/PeachEngineTests/CompletionTests.swift`

**Interfaces:**
- Consumes: `TierStanding` (Task 6).
- Produces: `isComplete(_ standing: TierStanding) -> Bool`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/CompletionTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("isComplete")
struct CompletionTests {
    /// A standing with only the two fields completion reads. The rest are
    /// filled with values that must not influence the answer.
    func standing(setFound: Int, setTotal: Int, score: Int = 0) -> TierStanding {
        TierStanding(
            index: 0, id: "tier-0", score: score, reachable: 100,
            fraction: 0, setPoints: 0, offPagePoints: 0,
            setFound: setFound, setTotal: setTotal,
            next: nil, isTop: false
        )
    }

    @Test("is a word count, not a points threshold")
    func wordCount() {
        // A huge score with set words unfound is not completion.
        #expect(!isComplete(standing(setFound: 20, setTotal: 23, score: 9_999)))
        // Every set word found is completion, whatever the score.
        #expect(isComplete(standing(setFound: 23, setTotal: 23, score: 0)))
    }

    @Test("treats finding more than the set as complete")
    func overshoot() {
        // Defensive: `>=`, matching both web call sites.
        #expect(isComplete(standing(setFound: 24, setTotal: 23)))
    }

    // The guard useGame.ts:602 is missing. An empty set is not "complete"; it
    // is a rack that should never have shipped. minSetSize = 15 means this
    // cannot happen today, which is exactly why the two web call sites agree by
    // accident rather than by construction.
    @Test("an empty set is never complete")
    func emptySet() {
        #expect(!isComplete(standing(setFound: 0, setTotal: 0)))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'isComplete' in scope`.

- [ ] **Step 3: Write `Completion.swift`**

```swift
/// True once every set word the rack can spell has been found.
///
/// Completion is a WORD COUNT, not a points threshold, and it sits ABOVE the
/// named ladder: a player can hold the top named rank (0.80 of par) with set
/// words still unfound, and only this returns true when the page is clear.
///
/// This function does not exist in the TypeScript engine. There, the same rule
/// is inlined at two UI call sites — `share/shareResult.ts` and `useGame.ts` —
/// and only one of them guards `setTotal > 0`. They agree today solely because
/// `minSetSize = 15` makes an empty set impossible, which is an invariant
/// enforced in a third file entirely. One function, one rule, one test.
public func isComplete(_ standing: TierStanding) -> Bool {
    standing.setTotal > 0 && standing.setFound >= standing.setTotal
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Log the finding and commit**

Append to `docs/PORT-LOG.md` under a "Findings" heading: the two web call sites, the missing guard, and that porting is what surfaced it.

```bash
git add -A
git commit -m "feat: move completion into the engine as a single isComplete"
```

---

### Task 8: GuessResult and validateGuess

Ports `src/engine/validate.ts` and the `GuessResult` half of `src/engine/types.ts`. Test source: the `validateGuess` half of `src/engine/puzzle.test.ts`.

**Files:**
- Create: `Sources/PeachEngine/Validate.swift`
- Create: `Tests/PeachEngineTests/ValidateTests.swift`

**Interfaces:**
- Consumes: `Puzzle` (Task 4), `classifyWord` (Task 4), `findScore` and `minWordLength` (Task 2), `Fixture.puzzle` (Task 5).
- Produces: `enum GuessResult`, `normalizeGuess(_:) -> String`, `validateGuess(_:puzzle:found:) -> GuessResult`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/ValidateTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("validateGuess")
struct ValidateTests {
    let puzzle = Fixture.puzzle
    let empty: Set<String> = []

    @Test("accepts a set word with the set rung")
    func setWord() {
        #expect(validateGuess("sea", puzzle: puzzle, found: empty)
                == .valid(word: "sea", score: 1, rung: .set, isSourceWord: false))
    }

    @Test("grades off-page words by rung",
          arguments: [("sneer", Rung.uncommon), ("eased", .rare), ("sane", .mythic)])
    func offPage(word: String, expected: Rung) {
        guard case .valid(_, _, let rung, _) = validateGuess(word, puzzle: puzzle, found: empty) else {
            Issue.record("expected \(word) to be valid")
            return
        }
        #expect(rung == expected)
    }

    @Test("flags the source word, still a set word")
    func sourceWord() {
        #expect(validateGuess("serenade", puzzle: puzzle, found: empty)
                == .valid(word: "serenade", score: 15, rung: .set, isSourceWord: true))
    }

    @Test("rejects words below the minimum length")
    func tooShort() {
        #expect(validateGuess("ad", puzzle: puzzle, found: empty) == .tooShort)
    }

    @Test("rejects a non-word and an unformable word the same way")
    func notAWord() {
        #expect(validateGuess("zebra", puzzle: puzzle, found: empty) == .notAWord)
        #expect(validateGuess("xyz", puzzle: puzzle, found: empty) == .notAWord)
    }

    @Test("rejects a word already found")
    func alreadyFound() {
        #expect(validateGuess("sea", puzzle: puzzle, found: ["sea"]) == .alreadyFound)
    }

    @Test("normalizes case and stray characters")
    func normalizes() {
        #expect(normalizeGuess(" SeA! ") == "sea")
        #expect(validateGuess(" SeA! ", puzzle: puzzle, found: empty)
                == .valid(word: "sea", score: 1, rung: .set, isSourceWord: false))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'validateGuess' in scope`.

- [ ] **Step 3: Write `Validate.swift`**

```swift
/// Why a guess was accepted or rejected.
///
/// A Swift enum with associated values: the discriminated union the TypeScript
/// approximates with a `kind` field. The difference is enforcement. In
/// TypeScript, reading `.score` off a result requires narrowing by `kind`
/// first, and the narrowing is a convention the compiler checks only where you
/// remember to ask. Here, `score` does not exist except inside a `case .valid`
/// binding — there is nothing to read on a `.tooShort`. The same shape is what
/// stopped the daily share from leaking the answer in the web version: a union
/// where the source word simply is not a field on the daily case.
public enum GuessResult: Sendable, Equatable {
    case valid(word: String, score: Int, rung: Rung, isSourceWord: Bool)
    case tooShort
    case notAWord
    case alreadyFound
}

/// Normalize raw input to the canonical form used everywhere: lowercase a-z.
public func normalizeGuess(_ input: String) -> String {
    // The TypeScript used `.toLowerCase().replace(/[^a-z]/g, '')`. Filtering
    // over `unicodeScalars` avoids pulling in a regex for a one-line character
    // test, and keeps it to ASCII, which is all the word lists contain.
    String(input.lowercased().unicodeScalars.filter { $0 >= "a" && $0 <= "z" }
        .map(Character.init))
}

/// Validate a guess against a resolved puzzle and the set already found.
///
/// A guess is valid when it is 3+ letters, formable from the rack, and in
/// ENABLE. The puzzle's `validationWords` already encodes all three (it is the
/// formable ENABLE set), so membership there is the single source of truth.
public func validateGuess(
    _ input: String,
    puzzle: Puzzle,
    found: Set<String>
) -> GuessResult {
    let word = normalizeGuess(input)

    if word.count < minWordLength { return .tooShort }
    if !puzzle.validationWords.contains(word) { return .notAWord }
    if found.contains(word) { return .alreadyFound }

    let rung = classifyWord(word, in: puzzle)
    return .valid(
        word: word,
        score: findScore(word, rung: rung),
        rung: rung,
        isSourceWord: word == puzzle.sourceWord
    )
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Log and commit**

```bash
git add -A
git commit -m "feat: port validateGuess with GuessResult as a Swift enum"
```

---

### Task 9: Eligibility and the set-size floor

Ports `src/engine/eligibility.ts`. Test source: `src/engine/eligibility.test.ts`.

**Files:**
- Create: `Sources/PeachEngine/Eligibility.swift`
- Create: `Tests/PeachEngineTests/EligibilityTests.swift`

**Interfaces:**
- Consumes: `createPuzzle` (Task 5), `minSetSize` (Task 2), `ListWordSource`/`ListDictionary` (Task 5).
- Produces: `sourceSetSize(_:dictionary:commonPool:beyond70Pool:beyond95Pool:) -> Int`, `isEligibleSource(...) -> Bool`, `eligibleSourceWords(_:dictionary:commonPool:beyond70Pool:beyond95Pool:) -> [String]`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/EligibilityTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("eligibility")
struct EligibilityTests {
    /// Distinct strings formable from `rack` (each letter used at most once),
    /// length 3, used to build synthetic pools with a known set size.
    func formableTriples(_ rack: String, count: Int) -> [String] {
        let letters = Array(rack)
        var out: [String] = []
        for i in 0..<letters.count {
            for j in (i + 1)..<letters.count {
                for k in (j + 1)..<letters.count {
                    out.append(String([letters[i], letters[j], letters[k]]))
                    if out.count == count { return out }
                }
            }
        }
        fatalError("rack too small for requested count")
    }

    let rack = "abcdefgh"
    let empty = ListWordSource([])

    @Test("counts the set the game would build (crown-inclusive)")
    func setSize() {
        let words = formableTriples(rack, count: minSetSize)
        #expect(sourceSetSize(rack,
                              dictionary: ListDictionary(words),
                              commonPool: ListWordSource(words),
                              beyond70Pool: empty,
                              beyond95Pool: empty) == minSetSize)
    }

    @Test("is eligible at the floor and ineligible one below it",
          arguments: [(15, true), (14, false)])
    func floor(size: Int, expected: Bool) {
        let words = formableTriples(rack, count: size)
        #expect(isEligibleSource(rack,
                                 dictionary: ListDictionary(words),
                                 commonPool: ListWordSource(words),
                                 beyond70Pool: empty,
                                 beyond95Pool: empty) == expected)
    }

    @Test("keeps only candidates whose set clears the floor, in input order")
    func filters() {
        // Disjoint letter sets: 'abcdefgh' forms 15 set words, 'ijklmnop' 14.
        let rich = formableTriples("abcdefgh", count: 15)
        let thin = formableTriples("ijklmnop", count: 14)
        let all = rich + thin
        #expect(eligibleSourceWords(["abcdefgh", "ijklmnop"],
                                    dictionary: ListDictionary(all),
                                    commonPool: ListWordSource(all),
                                    beyond70Pool: empty,
                                    beyond95Pool: empty) == ["abcdefgh"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'sourceSetSize' in scope`.

- [ ] **Step 3: Write `Eligibility.swift`**

```swift
/// Set size for a source word, computed through the engine's own `createPuzzle`
/// so it matches the live game exactly.
///
/// This is `commonWords.count`: the completion denominator the "X of Y" counter
/// shows, crown-inclusive (the source word is itself a set word for any common
/// crown). Reused by the calendar generator and the eligibility floor.
///
/// NEVER reimplement the set rules elsewhere. The comment survives the port
/// because it is the fossil of a real bug: two computations of the same fact
/// that agreed by coincidence until they didn't.
public func sourceSetSize(
    _ word: String,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> Int {
    createPuzzle(
        sourceWord: word,
        dictionary: dictionary,
        commonPool: commonPool,
        beyond70Pool: beyond70Pool,
        beyond95Pool: beyond95Pool
    ).commonWords.count
}

/// True when a source word's set clears `minSetSize` (crown-inclusive).
public func isEligibleSource(
    _ word: String,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> Bool {
    sourceSetSize(word,
                  dictionary: dictionary,
                  commonPool: commonPool,
                  beyond70Pool: beyond70Pool,
                  beyond95Pool: beyond95Pool) >= minSetSize
}

/// The candidates whose set clears the floor, input order preserved.
public func eligibleSourceWords(
    _ candidates: some Sequence<String>,
    dictionary: some ValidationDictionary,
    commonPool: some WordSource,
    beyond70Pool: some WordSource,
    beyond95Pool: some WordSource
) -> [String] {
    candidates.filter {
        isEligibleSource($0,
                         dictionary: dictionary,
                         commonPool: commonPool,
                         beyond70Pool: beyond70Pool,
                         beyond95Pool: beyond95Pool)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Log and commit**

```bash
git add -A
git commit -m "feat: port the source-word eligibility floor"
```

---

### Task 10: seededPermutation and generateCalendar

Ports `src/engine/shuffle.ts` and `src/engine/calendar.ts`. Test sources: `src/engine/shuffle.test.ts`, `src/engine/calendar.test.ts`.

The PRNG port is the one place where a plausible-looking translation silently produces different numbers. `mulberry32` uses `Math.imul` — int32 wrapping multiply — which maps to Swift's `&*` on `UInt32`. Task 11's oracle pins it; the expected values below were verified against Node before this plan was written.

**Files:**
- Create: `Sources/PeachEngine/Shuffle.swift`
- Create: `Sources/PeachEngine/Calendar.swift`
- Create: `Tests/PeachEngineTests/ShuffleTests.swift`
- Create: `Tests/PeachEngineTests/CalendarTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `seededPermutation(_ n: Int, seed: UInt32) -> [Int]`, `calendarSeed: UInt32`, `generateCalendar(eligible:existing:seed:) -> [String]`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/ShuffleTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("seededPermutation")
struct ShuffleTests {
    @Test("is a true permutation of [0, n)")
    func isPermutation() {
        #expect(seededPermutation(50, seed: 123).sorted() == Array(0..<50))
    }

    @Test("is deterministic for a given n and seed")
    func deterministic() {
        #expect(seededPermutation(20, seed: 7) == seededPermutation(20, seed: 7))
    }

    @Test("differs across seeds")
    func seedSensitive() {
        #expect(seededPermutation(20, seed: 1) != seededPermutation(20, seed: 2))
    }

    // Bit-for-bit agreement with the TypeScript mulberry32. These values came
    // out of Node, not out of this implementation, so they catch a Swift port
    // that is internally consistent but wrong. Task 11 generalises this into a
    // generated fixture; these three stay as a fast tripwire either way.
    @Test("matches the JavaScript mulberry32 stream exactly")
    func matchesJavaScript() {
        #expect(seededPermutation(20, seed: 7)
                == [9, 19, 7, 4, 5, 10, 12, 16, 18, 2, 15, 13, 3, 14, 6, 8, 11, 17, 1, 0])
        #expect(Array(seededPermutation(50, seed: 123).prefix(10))
                == [33, 30, 36, 18, 28, 5, 26, 48, 9, 34])
        #expect(seededPermutation(5, seed: calendarSeed) == [4, 3, 0, 2, 1])
    }
}
```

`Tests/PeachEngineTests/CalendarTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("generateCalendar")
struct CalendarTests {
    let eligible = ["alpha", "bravo", "charlie", "delta", "echo"]

    @Test("first run contains exactly the eligible words, none extra")
    func exact() {
        #expect(generateCalendar(eligible: eligible, existing: []).sorted() == eligible.sorted())
    }

    @Test("does not march alphabetically (the seeded shuffle)")
    func shuffled() {
        #expect(generateCalendar(eligible: eligible, existing: []) != eligible.sorted())
    }

    @Test("is deterministic: same inputs yield an identical calendar")
    func deterministic() {
        #expect(generateCalendar(eligible: eligible, existing: [])
                == generateCalendar(eligible: eligible, existing: []))
    }

    // The freeze. This is the load-bearing invariant: a new eligible word lands
    // at the end and every existing position is untouched. A failure here
    // re-dates every day after the change and breaks the promise that a given
    // day is a fixed puzzle.
    @Test("appends new eligible words to the end and never moves an existing one")
    func appendOnly() {
        let existing = generateCalendar(eligible: eligible, existing: [])
        let grown = generateCalendar(eligible: eligible + ["foxtrot", "golf"], existing: existing)

        #expect(Array(grown.prefix(existing.count)) == existing)
        #expect(grown.dropFirst(existing.count).sorted() == ["foxtrot", "golf"])
        #expect(grown.count == existing.count + 2)
    }

    @Test("never reorders or removes when nothing new is eligible")
    func stable() {
        let existing = generateCalendar(eligible: eligible, existing: [])
        #expect(generateCalendar(eligible: eligible, existing: existing) == existing)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'seededPermutation' in scope`.

- [ ] **Step 3: Write `Shuffle.swift`**

```swift
/// Deterministic, seeded shuffling. Shared by the daily cycle reshuffle and the
/// calendar generator so both draw the same stream from the same seed.

/// A source of uniform values in [0, 1).
///
/// `mutating func` rather than a `() -> Double` closure, deliberately: a
/// closure would capture its state by reference, so anything holding one would
/// share a cursor with everything else holding a copy. As a protocol with a
/// mutating requirement, the state lives in the conforming value, and copying
/// the holder forks the stream. Task 14 depends on this.
public protocol RandomSource {
    mutating func next() -> Double
}

/// Deterministic PRNG. Same seed, same stream.
///
/// A faithful port of the JavaScript `mulberry32`, which is written in terms of
/// `Math.imul` — a 32-bit wrapping multiply — and `>>> 0`, an unsigned 32-bit
/// coercion. Swift's `&*` and `&+` are the wrapping operators; the plain `*`
/// and `+` would trap on overflow instead of wrapping, which is Swift being
/// strict about something JavaScript silently does. Doing the arithmetic in
/// `UInt32` makes the `>>> 0` coercions unnecessary: the type already is that.
///
/// A `struct` with a `mutating func`, not a closure over a captured variable:
/// the state is visible in the type, and a copy of the generator is genuinely
/// independent of the original.
public struct Mulberry32: RandomSource {
    private var a: UInt32

    public init(seed: UInt32) {
        a = seed
    }

    /// The next value in [0, 1).
    public mutating func next() -> Double {
        a = a &+ 0x6d2b_79f5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = ((t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t)
        return Double(t ^ (t >> 14)) / 4_294_967_296.0
    }
}

/// A fresh seeded Fisher-Yates permutation of [0, n). Pure in n and seed.
public func seededPermutation(_ n: Int, seed: UInt32) -> [Int] {
    var rng = Mulberry32(seed: seed)
    var order = Array(0..<n)
    var i = n - 1
    while i > 0 {
        let j = Int(rng.next() * Double(i + 1))
        order.swapAt(i, j)
        i -= 1
    }
    return order
}
```

- [ ] **Step 4: Write `Calendar.swift`**

```swift
/// Fixed seed for the one-time establishment shuffle and for ordering appended
/// words. A constant so generation is fully deterministic across runs.
public let calendarSeed: UInt32 = 0x5e1e_c7ed

/// Build the daily calendar from the current eligible source words and the
/// existing committed calendar.
///
/// APPEND-ONLY INVARIANT (load-bearing, do not break):
///   The daily calendar is append-only. Never reorder it, never remove from it.
///   New words go on the end. Removing or reordering an entry re-dates every
///   day after it and breaks the promise that a given day is a fixed puzzle.
///
/// First run (existing empty): every eligible word in a deterministic seeded
/// shuffle, so consecutive days do not march alphabetically. Every later run:
/// existing entries keep their position and order untouched, and any eligible
/// word not already present is appended to the end in a deterministic order.
public func generateCalendar(
    eligible: [String],
    existing: [String],
    seed: UInt32 = calendarSeed
) -> [String] {
    let present = Set(existing)
    // Sort for a stable base so the seeded shuffle is independent of input order.
    let sorted = eligible.sorted()
    let shuffled = seededPermutation(sorted.count, seed: seed).map { sorted[$0] }
    return existing + shuffled.filter { !present.contains($0) }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS. If `matchesJavaScript` fails, the PRNG port is wrong — fix the port, never the expected values.

- [ ] **Step 6: Log and commit**

```bash
git add -A
git commit -m "feat: port the seeded shuffle and append-only calendar generator"
```

---

### Task 11: The TypeScript oracle

No web counterpart — this is new infrastructure. It turns "does Swift match the web?" from a judgement into a measurement.

**If this task starts eating the session, cut it to `dayIndex` only** and rely on the hardcoded PRNG values already in Task 10 for `seededPermutation`. `dayIndex` is where the real divergence risk lives; the PRNG is deterministic and already spot-checked. **Say in the report if that cut is made.**

**Files:**
- Create: `tools/generate-oracle.mjs`
- Create: `Fixtures/oracle.json` (generated, committed)
- Create: `Tests/PeachEngineTests/Oracle.swift`

**Interfaces:**
- Consumes: `repositoryRoot` (Task 1).
- Produces: `Fixtures/oracle.json`; `Oracle.load()` returning decoded `OracleFixture` for Tasks 12 and 13.

- [ ] **Step 1: Write the generator**

`tools/generate-oracle.mjs`. It reimplements the three TypeScript functions inline rather than importing from the web repo, so this repo stays standalone and the web repo stays untouched.

```javascript
// Generates Fixtures/oracle.json: the TypeScript engine's answers, so the Swift
// port can be checked against them rather than against a reading of the source.
//
// Run: node tools/generate-oracle.mjs
//
// The three functions below are copied verbatim from the web repo at commit
// 475edfc (src/engine/daily.ts and src/engine/shuffle.ts). Copied, not
// imported: this repo does not depend on that one.
import { writeFileSync, mkdirSync } from 'node:fs';

function dayIndex(date, epoch) {
  const today = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  const start = Date.UTC(epoch.year, epoch.month - 1, epoch.day);
  return Math.floor((today - start) / 86_400_000);
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
}

function seededPermutation(n, seed) {
  const rng = mulberry32(seed);
  const order = Array.from({ length: n }, (_, i) => i);
  for (let i = n - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [order[i], order[j]] = [order[j], order[i]];
  }
  return order;
}

function seedForCycle(cycle) {
  return (cycle * 0x9e3779b1) >>> 0;
}

function cycleOrder(cycle, n) {
  if (cycle === 0) return Array.from({ length: n }, (_, i) => i);
  const order = seededPermutation(n, seedForCycle(cycle));
  if (n < 2) return order;
  const prevLast = cycleOrder(cycle - 1, n)[n - 1];
  if (order[0] === prevLast) [order[0], order[1]] = [order[1], order[0]];
  return order;
}

const EPOCH = { year: 2026, month: 1, day: 1 };

// dayIndex takes a JS Date and reads its LOCAL components, so each case must be
// generated with process.env.TZ set to that case's zone. Node reads TZ once, so
// the script re-execs itself per zone rather than looping. See runAll below.
const ZONE_CASES = {
  'America/Los_Angeles': [
    // Around DST forward: 2026-03-08 02:00 PST -> 03:00 PDT.
    '2026-03-07T23:59:00-08:00', '2026-03-08T00:00:00-08:00',
    '2026-03-08T01:59:00-08:00', '2026-03-08T03:00:00-07:00',
    '2026-03-08T23:59:00-07:00',
    // Around DST back: 2026-11-01 02:00 PDT -> 01:00 PST (01:30 happens twice).
    '2026-11-01T00:30:00-07:00', '2026-11-01T01:30:00-08:00',
    '2026-11-01T23:59:00-08:00',
    // Epoch day, and the daily epoch.
    '2026-01-01T00:00:00-08:00', '2026-06-23T12:00:00-07:00',
  ],
  // Far from UTC in both directions, plus a midnight-transition zone and a
  // half-hour offset, because those are where naive day arithmetic breaks.
  'Pacific/Kiritimati': ['2026-09-05T12:00:00Z', '2026-09-05T10:30:00Z'],
  'Pacific/Apia': ['2026-09-05T12:00:00Z'],
  'Asia/Kolkata': ['2026-09-05T12:00:00Z', '2026-09-05T18:35:00Z'],
  'America/Santiago': ['2026-09-06T02:30:00Z', '2026-09-06T04:30:00Z'],
  'Australia/Lord_Howe': ['2026-04-05T15:30:00Z'],
  'UTC': ['2026-01-01T00:00:00Z', '2026-01-01T23:59:59Z', '2025-12-31T23:59:59Z'],
};

function runZone(zone) {
  return ZONE_CASES[zone].map((iso) => ({
    zone,
    instant: iso,
    dayIndex: dayIndex(new Date(iso), EPOCH),
  }));
}

if (process.argv[2] === '--zone') {
  process.stdout.write(JSON.stringify(runZone(process.argv[3])));
} else {
  const { execFileSync } = await import('node:child_process');
  const dayIndexCases = Object.keys(ZONE_CASES).flatMap((zone) =>
    JSON.parse(
      execFileSync(process.execPath, [process.argv[1], '--zone', zone], {
        env: { ...process.env, TZ: zone },
        encoding: 'utf8',
      }),
    ),
  );

  const permutations = [
    [20, 7], [50, 123], [5, 0x5e1ec7ed], [626, 0x5e1ec7ed], [1, 42], [2, 42],
  ].map(([n, seed]) => ({ n, seed, order: seededPermutation(n, seed) }));

  const cycleOrders = [
    [0, 5], [1, 5], [2, 5], [3, 5], [1, 626], [2, 626], [1, 1], [1, 2],
  ].map(([cycle, n]) => ({ cycle, n, order: cycleOrder(cycle, n) }));

  const seedsForCycle = [1, 2, 3, 1000].map((cycle) => ({
    cycle,
    seed: seedForCycle(cycle),
  }));

  mkdirSync('Fixtures', { recursive: true });
  writeFileSync(
    'Fixtures/oracle.json',
    JSON.stringify(
      {
        note: 'Generated by tools/generate-oracle.mjs from the TypeScript engine at web commit 475edfc. Do not hand-edit.',
        epoch: EPOCH,
        dayIndexCases,
        permutations,
        cycleOrders,
        seedsForCycle,
      },
      null,
      2,
    ) + '\n',
  );
  console.log(`wrote Fixtures/oracle.json: ${dayIndexCases.length} date cases, ${permutations.length} permutations, ${cycleOrders.length} cycle orders`);
}
```

- [ ] **Step 2: Run the generator**

```bash
node tools/generate-oracle.mjs
```

Expected: `wrote Fixtures/oracle.json: 22 date cases, 6 permutations, 8 cycle orders`. Spot-check the file: the `America/Los_Angeles` entries should read 65, 66, 66, 66, 66 for the five March instants.

- [ ] **Step 3: Write the oracle loader**

`Tests/PeachEngineTests/Oracle.swift`:

```swift
import Foundation
@testable import PeachEngine

/// The TypeScript engine's answers, generated by tools/generate-oracle.mjs.
///
/// `Codable` is Swift's built-in JSON mapping: conforming a struct to it
/// generates the decoder from the stored properties, so there is no
/// hand-written parsing and a shape mismatch is a decode error rather than an
/// undefined at some later line. TypeScript's `JSON.parse` returns `any`.
struct OracleFixture: Codable {
    struct DayIndexCase: Codable {
        let zone: String
        let instant: String
        let dayIndex: Int
    }
    struct Permutation: Codable {
        let n: Int
        let seed: UInt32
        let order: [Int]
    }
    struct CycleOrderCase: Codable {
        let cycle: Int
        let n: Int
        let order: [Int]
    }
    struct SeedForCycleCase: Codable {
        let cycle: Int
        let seed: UInt32
    }

    let epoch: Epoch
    struct Epoch: Codable {
        let year: Int
        let month: Int
        let day: Int
    }
    let dayIndexCases: [DayIndexCase]
    let permutations: [Permutation]
    let cycleOrders: [CycleOrderCase]
    let seedsForCycle: [SeedForCycleCase]

    var epochDate: EpochDate {
        EpochDate(year: epoch.year, month: epoch.month, day: epoch.day)
    }

    static let shared: OracleFixture = {
        let url = repositoryRoot
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("oracle.json")
        // Force-unwrapping in a test helper is deliberate: a missing or
        // malformed oracle should fail loudly and immediately, not degrade into
        // a suite that silently checks nothing.
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(OracleFixture.self, from: data)
    }()
}
```

- [ ] **Step 4: Write and run the permutation cross-check**

Append to `Tests/PeachEngineTests/ShuffleTests.swift`:

```swift
@Suite("seededPermutation against the TypeScript oracle")
struct ShuffleOracleTests {
    @Test("reproduces every generated permutation exactly")
    func matchesOracle() {
        for c in OracleFixture.shared.permutations {
            #expect(seededPermutation(c.n, seed: c.seed) == c.order,
                    "n=\(c.n) seed=\(c.seed)")
        }
    }
}
```

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: generate a TypeScript oracle for date and PRNG behaviour"
```

---

### Task 12: dayIndex and the date-boundary tests

Ports the `dayIndex` half of `src/engine/daily.ts`. Test sources: `src/engine/daily.test.ts` plus the new boundary tests the brief asks for.

The second deliberate deviation: **`dayIndex` takes an injectable `TimeZone`.** JavaScript's `Date` carries local-calendar accessors; Swift's `Date` is a bare instant with none. Reaching for `Calendar.current` would make these tests unwritable and the suite dependent on the machine's clock settings.

**Files:**
- Create: `Sources/PeachEngine/Daily.swift`
- Create: `Tests/PeachEngineTests/DayIndexTests.swift`

**Interfaces:**
- Consumes: `EpochDate`, `dailyEpoch`, `storageEpoch` (Task 2); `OracleFixture` (Task 11).
- Produces: `enum EngineError: Error`, `dayIndex(_ date: Date, epoch: EpochDate, timeZone: TimeZone) -> Int`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/DayIndexTests.swift`:

```swift
import Foundation
import Testing
@testable import PeachEngine

@Suite("dayIndex")
struct DayIndexTests {
    let epoch = EpochDate(year: 2026, month: 1, day: 1)
    let la = TimeZone(identifier: "America/Los_Angeles")!

    /// Build a Date from local calendar components in a given zone. The Swift
    /// equivalent of JavaScript's `new Date(y, m, d, h, min)`, which silently
    /// uses the machine's zone — the thing this port refuses to do.
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0,
              zone: TimeZone) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: DateComponents(year: y, month: m, day: d,
                                             hour: h, minute: min))!
    }

    @Test("is zero on the epoch date")
    func epochDay() {
        #expect(dayIndex(date(2026, 1, 1, 9, 30, zone: la), epoch: epoch, timeZone: la) == 0)
    }

    @Test("counts whole calendar days forward")
    func forward() {
        #expect(dayIndex(date(2026, 1, 2, zone: la), epoch: epoch, timeZone: la) == 1)
        #expect(dayIndex(date(2026, 2, 1, zone: la), epoch: epoch, timeZone: la) == 31)
    }

    @Test("ignores the time of day (local-midnight rollover)")
    func midnightRollover() {
        let early = dayIndex(date(2026, 1, 10, 0, 1, zone: la), epoch: epoch, timeZone: la)
        let late = dayIndex(date(2026, 1, 10, 23, 59, zone: la), epoch: epoch, timeZone: la)
        #expect(early == late)
    }

    @Test("does not drift across a daylight-saving boundary, in either direction")
    func dstBothWays() {
        // Forward: US DST begins 2026-03-08, a 23-hour day.
        let beforeSpring = dayIndex(date(2026, 3, 7, zone: la), epoch: epoch, timeZone: la)
        let afterSpring = dayIndex(date(2026, 3, 9, zone: la), epoch: epoch, timeZone: la)
        #expect(afterSpring - beforeSpring == 2)

        // Back: US DST ends 2026-11-01, a 25-hour day.
        let beforeFall = dayIndex(date(2026, 10, 31, zone: la), epoch: epoch, timeZone: la)
        let afterFall = dayIndex(date(2026, 11, 2, zone: la), epoch: epoch, timeZone: la)
        #expect(afterFall - beforeFall == 2)
    }

    @Test("gives the same instant different day indices in different zones")
    func zoneMatters() {
        // 2026-09-05 12:00 UTC is already the 6th in Kiritimati (+14) and still
        // the 5th in Kolkata (+5:30). The daily is a function of the LOCAL date,
        // so these must differ. If dayIndex used Calendar.current this test
        // would pass or fail depending on the machine.
        let instant = Date(timeIntervalSince1970: 1_788_609_600)  // 2026-09-05T12:00:00Z
        let kiritimati = dayIndex(instant, epoch: epoch,
                                  timeZone: TimeZone(identifier: "Pacific/Kiritimati")!)
        let kolkata = dayIndex(instant, epoch: epoch,
                               timeZone: TimeZone(identifier: "Asia/Kolkata")!)
        #expect(kiritimati == kolkata + 1)
    }

    @Test("matches the TypeScript engine on every generated instant")
    func matchesOracle() {
        let oracle = OracleFixture.shared
        let formatter = ISO8601DateFormatter()
        for c in oracle.dayIndexCases {
            let instant = formatter.date(from: c.instant)!
            let zone = TimeZone(identifier: c.zone)!
            #expect(dayIndex(instant, epoch: oracle.epochDate, timeZone: zone) == c.dayIndex,
                    "\(c.zone) \(c.instant)")
        }
    }

    @Test("keeps the storage epoch and the daily epoch on different indices")
    func twoEpochs() {
        // The whole point of the split: re-anchoring the calendar must not move
        // the persisted day keys.
        let d = date(2026, 8, 9, zone: la)
        #expect(dayIndex(d, epoch: storageEpoch, timeZone: la) == 220)
        #expect(dayIndex(d, epoch: dailyEpoch, timeZone: la) == 47)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'dayIndex' in scope`.

- [ ] **Step 3: Write `Daily.swift`**

```swift
import Foundation

/// Failures the engine can raise. A Swift `enum` conforming to `Error` is the
/// idiomatic shape: a `throws` function's failures are a closed set the caller
/// can switch over exhaustively, rather than TypeScript's `throw new Error(...)`
/// where the thrown value is `unknown` and its message is the only signal.
public enum EngineError: Error, Equatable {
    case emptyCalendar
}

/// Whole calendar days from the epoch to the given local date.
///
/// Built from the calendar Y/M/D components, never from
/// `(now - epoch) / dayMs`. Dividing an elapsed interval drifts across
/// daylight-saving boundaries and would make the daily differ on reload. This
/// is rollover at local midnight in `timeZone`.
///
/// The `timeZone` parameter is a deliberate deviation from the TypeScript,
/// which reads `date.getFullYear()` and friends and so silently uses the
/// machine's zone. Swift's `Date` is a bare instant with no local accessors at
/// all, so the zone has to come from somewhere; making it a parameter rather
/// than reaching for `Calendar.current` is what lets the DST and
/// far-from-UTC tests exist and keeps the suite independent of the machine.
public func dayIndex(
    _ date: Date,
    epoch: EpochDate = dailyEpoch,
    timeZone: TimeZone
) -> Int {
    var local = Foundation.Calendar(identifier: .gregorian)
    local.timeZone = timeZone
    let components = local.dateComponents([.year, .month, .day], from: date)

    var utc = Foundation.Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!

    // Re-anchoring both dates in UTC is the port of the TypeScript's
    // `Date.UTC(...)` trick: it strips the zone from both sides so the
    // subtraction counts calendar days rather than elapsed hours.
    let today = utc.date(from: DateComponents(year: components.year,
                                              month: components.month,
                                              day: components.day))!
    let start = utc.date(from: DateComponents(year: epoch.year,
                                              month: epoch.month,
                                              day: epoch.day))!
    let days = (today.timeIntervalSince1970 - start.timeIntervalSince1970) / 86_400
    return Int(days.rounded(.down))
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, including `matchesOracle` across all 22 generated instants.

- [ ] **Step 5: Record the "faithful vs one-liner" comparison**

The tempting Swift one-liner is
`cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: date)).day!`.
Spot-check it against the faithful version on the oracle cases and note the
result in `docs/PORT-LOG.md`. If it never diverges, that is itself a reportable
finding: Foundation's calendar arithmetic is robust enough that the TypeScript's
defensive UTC re-anchoring is unnecessary in Swift. Do not switch to it — the
faithful port stays — but record what was learned.

- [ ] **Step 6: Log and commit**

```bash
git add -A
git commit -m "feat: port dayIndex with an injectable time zone and boundary tests"
```

---

### Task 13: dailySourceWord and the cycle order

Ports the `dailySourceWord` / `cycleOrder` half of `src/engine/daily.ts`. Test source: the `dailySourceWord` block of `src/engine/daily.test.ts`.

`seedForCycle` is the second PRNG hazard: `cycle * 0x9e3779b1 >>> 0` is a **Double** multiply followed by a mod-2³² coercion, not a wrapping 32-bit multiply. Porting it as `&*` on `UInt32` would silently diverge. The correct port widens to `Int64` first.

**Files:**
- Modify: `Sources/PeachEngine/Daily.swift`
- Create: `Tests/PeachEngineTests/DailySourceWordTests.swift`

**Interfaces:**
- Consumes: `dayIndex` (Task 12), `seededPermutation` (Task 10), `EngineError` (Task 12), `OracleFixture` (Task 11).
- Produces: `dailySourceWord(calendar:date:epoch:timeZone:) throws -> String`; internal `seedForCycle(_:)` and `cycleOrder(cycle:n:)` exposed to tests via `@testable`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/DailySourceWordTests.swift`:

```swift
import Foundation
import Testing
@testable import PeachEngine

@Suite("dailySourceWord")
struct DailySourceWordTests {
    let calendar = ["alpha", "bravo", "charlie", "delta", "echo"]
    let epoch = EpochDate(year: 2026, month: 1, day: 1)
    let utc = TimeZone(identifier: "UTC")!

    /// Day `n` of the sequence, as a Date at noon UTC.
    func day(_ n: Int) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        return cal.date(byAdding: .day, value: n, to: start)!
    }

    func word(on n: Int) throws -> String {
        try dailySourceWord(calendar: calendar, date: day(n), epoch: epoch, timeZone: utc)
    }

    @Test("is deterministic for a given date")
    func deterministic() throws {
        #expect(try word(on: 166) == (try word(on: 166)))
    }

    @Test("maps the first cycle to the frozen calendar order")
    func firstCycle() throws {
        #expect(try (0..<calendar.count).map { try word(on: $0) } == calendar)
    }

    @Test("yields a fixed first-cycle word, unaffected by appending words after it")
    func frozen() throws {
        #expect(try word(on: 2) == "charlie")
        let appended = calendar + ["foxtrot", "golf"]
        #expect(try dailySourceWord(calendar: appended, date: day(2), epoch: epoch, timeZone: utc)
                == "charlie")
    }

    @Test("reshuffles into a new pass after exhaustion")
    func reshuffles() throws {
        let n = calendar.count
        let firstPass = try (0..<n).map { try word(on: $0) }
        let secondPass = try (0..<n).map { try word(on: n + $0) }
        #expect(secondPass.sorted() == calendar.sorted())
        #expect(secondPass != firstPass)
    }

    @Test("does not repeat a word across a cycle boundary")
    func boundary() throws {
        let n = calendar.count
        #expect(try word(on: n) != (try word(on: n - 1)))
        #expect(try word(on: 2 * n) != (try word(on: 2 * n - 1)))
    }

    @Test("floors pre-epoch dates at day zero rather than reading backwards")
    func preEpoch() throws {
        #expect(try word(on: -5) == calendar[0])
    }

    @Test("throws on an empty calendar")
    func empty() {
        #expect(throws: EngineError.emptyCalendar) {
            try dailySourceWord(calendar: [], date: day(0), epoch: epoch, timeZone: utc)
        }
    }

    // seedForCycle is a Double multiply then a mod-2^32 coercion in JavaScript,
    // NOT a wrapping 32-bit multiply. Porting it as &* would silently diverge.
    @Test("matches the TypeScript seedForCycle and cycleOrder exactly")
    func matchesOracle() {
        let oracle = OracleFixture.shared
        for c in oracle.seedsForCycle {
            #expect(seedForCycle(c.cycle) == c.seed, "cycle=\(c.cycle)")
        }
        for c in oracle.cycleOrders {
            #expect(cycleOrder(cycle: c.cycle, n: c.n) == c.order, "cycle=\(c.cycle) n=\(c.n)")
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'dailySourceWord' in scope`.

- [ ] **Step 3: Append to `Daily.swift`**

```swift
/// A well-distributed seed for a reshuffled cycle. Cycle 0 never reaches here.
///
/// The TypeScript is `(cycle * 0x9e3779b1) >>> 0`. That is a DOUBLE multiply
/// followed by a mod-2^32 coercion — NOT a wrapping 32-bit multiply. Writing
/// `UInt32(cycle) &* 0x9e37_79b1` here would look right and produce different
/// numbers. Widening to Int64 first reproduces the JavaScript exactly, because
/// the product stays well inside Double's 53-bit exact range for any cycle this
/// will ever see.
func seedForCycle(_ cycle: Int) -> UInt32 {
    UInt32(truncatingIfNeeded: Int64(cycle) * 0x9e37_79b1)
}

/// The index order for a cycle over a calendar of n words.
///
/// Cycle 0 is the committed calendar order itself (identity), so the first pass
/// plays the frozen sequence exactly as generated. Every later cycle is a fresh
/// deterministic permutation, and its first word is forced to differ from the
/// previous cycle's last word so no word repeats across a cycle boundary.
func cycleOrder(cycle: Int, n: Int) -> [Int] {
    if cycle == 0 { return Array(0..<n) }
    var order = seededPermutation(n, seed: seedForCycle(cycle))
    if n < 2 { return order }
    // Recursive, exactly as the TypeScript is. Fine for the cycle depths this
    // sees (one per full pass through a 626-word calendar, so roughly one every
    // 20 months) and it keeps the port readable next to the original.
    let previousLast = cycleOrder(cycle: cycle - 1, n: n)[n - 1]
    if order[0] == previousLast {
        order.swapAt(0, 1)
    }
    return order
}

/// The source word for a given day, read from the frozen daily calendar.
///
/// The day index splits into a cycle and a position. The first cycle is the
/// calendar in its committed order; once exhausted, each later cycle is a fresh
/// deterministic shuffle, so the sequence never repeats a word within a pass and
/// never repeats across a pass boundary. Appending words to the calendar leaves
/// every first-cycle day fixed, which is the whole point of the freeze.
///
/// `throws` rather than the TypeScript's bare `throw new Error(...)`: the
/// caller is forced by the compiler to write `try`, so an empty calendar cannot
/// be ignored by accident.
public func dailySourceWord(
    calendar: [String],
    date: Date,
    epoch: EpochDate = dailyEpoch,
    timeZone: TimeZone
) throws -> String {
    guard !calendar.isEmpty else { throw EngineError.emptyCalendar }

    // Guard against pre-epoch dates by flooring at cycle/position 0.
    let safeIndex = max(0, dayIndex(date, epoch: epoch, timeZone: timeZone))
    let n = calendar.count
    let cycle = safeIndex / n
    let position = safeIndex % n
    return calendar[cycleOrder(cycle: cycle, n: n)[position]]
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS. If `matchesOracle` fails on `seedForCycle`, the `&*` mistake was made — fix the port, not the fixture.

- [ ] **Step 5: Add a real-calendar sanity check**

Append to `Tests/PeachEngineTests/DailySourceWordTests.swift`:

```swift
@Suite("dailySourceWord against the shipped calendar")
struct ShippedCalendarTests {
    struct CalendarFile: Codable { let words: [String] }

    @Test("reads the frozen 626-word calendar and serves day zero")
    func shipped() throws {
        let url = dataDirectory.appendingPathComponent("daily-calendar.json")
        let file = try JSONDecoder().decode(CalendarFile.self, from: try Data(contentsOf: url))
        #expect(file.words.count == 626)
        #expect(file.words.first == "mnemonic")

        var cal = Foundation.Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        cal.timeZone = utc
        let epochDay = cal.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        #expect(try dailySourceWord(calendar: file.words, date: epochDay,
                                    epoch: dailyEpoch, timeZone: utc) == "mnemonic")
    }
}
```

Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Log and commit**

```bash
git add -A
git commit -m "feat: port the daily calendar lookup and cycle ordering"
```

---

### Task 14: EndlessSource

Ports `createEndlessSource` from `src/engine/daily.ts`. Test source: the `createEndlessSource` block of `src/engine/daily.test.ts` (13 tests).

Sequenced last among the engine tasks, deliberately: it is outside the brief's six items, so a blown timebox still leaves a complete picture of the core.

This is the most interesting shape decision in the port. In TypeScript it is a closure capturing a mutable cursor. Swift offers two idiomatic answers with genuinely different semantics:

- a `struct` with `mutating func next()` — value semantics, so a copy is an independent stream, and every holder must declare it `var`;
- a `final class` with `func next()` — reference semantics, matching the closure's behaviour exactly, since two references share one cursor.

The plan uses the **struct**, because value semantics are Swift's default and the surprise of "a copy is a separate stream" is the thing worth feeling.

**The randomness has to be generic for that to be true.** A `rng: @escaping () -> Double` parameter would smuggle reference semantics back in: a closure captures its state by reference, so a copy of the struct would share the caller's generator and the two streams would diverge the moment either crossed a pass boundary. That is why Task 10 defines `RandomSource` as a protocol with a `mutating` requirement, and why `EndlessSource` is generic over it and stores it as a `var`. This is subtle and easy to get wrong — the whole reason it is spelled out here rather than left to the executor.

**Write down in `docs/PORT-LOG.md` how the value-semantics constraint actually felt**: the generic parameter, the `var` on every declaration, and whether a `final class` would have been the more honest translation.

**Files:**
- Create: `Sources/PeachEngine/EndlessSource.swift`
- Modify: `Sources/PeachEngine/Shuffle.swift` (nothing to change — `RandomSource` and `Mulberry32` already land in Task 10)
- Create: `Tests/PeachEngineTests/EndlessSourceTests.swift`

**Interfaces:**
- Consumes: `seededPermutation` and `RandomSource` (Task 10), `EngineError` (Task 12).
- Produces: `struct EndlessSource<R: RandomSource>` with `init(calendar:exclude:previous:rng:) throws` and `mutating func next() -> String`.

- [ ] **Step 1: Write the failing tests**

`Tests/PeachEngineTests/EndlessSourceTests.swift`:

```swift
import Testing
@testable import PeachEngine

@Suite("EndlessSource")
struct EndlessSourceTests {
    // The calendar holds only eligible words; a sub-floor word is never in it.
    let calendar = ["alpha", "bravo", "charlie", "delta", "echo"]

    /// A deterministic stand-in for a random source, so every draw is
    /// reproducible. A struct conforming to RandomSource, so a copy of the
    /// EndlessSource holding it forks this too.
    struct TestRNG: RandomSource {
        private var a: UInt32
        init(seed: UInt32 = 1) { a = seed }
        mutating func next() -> Double {
            a = a &* 1_664_525 &+ 1_013_904_223
            return Double(a) / 4_294_967_296.0
        }
    }

    /// Build a source wired to a seeded test RNG.
    func source(seed: UInt32 = 1, exclude: String? = nil,
                previous: String? = nil,
                calendar: [String]? = nil) throws -> EndlessSource<TestRNG> {
        try EndlessSource(calendar: calendar ?? self.calendar,
                          exclude: exclude, previous: previous,
                          rng: TestRNG(seed: seed))
    }

    // `inout` is Swift's explicit pass-by-reference marker, needed because
    // `next()` is mutating and this helper has to advance the caller's copy
    // rather than a local one. Part of the cost of the value-semantics choice.
    func draw(_ s: inout EndlessSource<TestRNG>, _ count: Int) -> [String] {
        (0..<count).map { _ in s.next() }
    }

    @Test("only ever draws a word from the calendar (never a sub-floor word)")
    func staysInPool() throws {
        var s = try source()
        let pool = Set(calendar)
        for word in draw(&s, 200) { #expect(pool.contains(word)) }
    }

    @Test("yields every word exactly once across a full pass")
    func fullPass() throws {
        var s = try source()
        #expect(draw(&s, calendar.count).sorted() == calendar.sorted())
    }

    @Test("never repeats a word before the pool is exhausted")
    func noEarlyRepeat() throws {
        var s = try source(seed: 7)
        for _ in 0..<4 {
            #expect(Set(draw(&s, calendar.count)).count == calendar.count)
        }
    }

    @Test("does not repeat the previous word across a pass boundary",
          arguments: UInt32(1)...UInt32(25))
    func passBoundary(seed: UInt32) throws {
        var s = try source(seed: seed)
        let drawn = draw(&s, calendar.count + 1)
        #expect(drawn[calendar.count] != drawn[calendar.count - 1])
    }

    @Test("never draws the excluded daily word")
    func excluded() throws {
        var s = try source(seed: 3, exclude: "charlie")
        for word in draw(&s, 200) { #expect(word != "charlie") }
    }

    @Test("yields every remaining word exactly once per pass when one is excluded")
    func excludedPass() throws {
        var s = try source(seed: 3, exclude: "charlie")
        let remaining = calendar.filter { $0 != "charlie" }
        #expect(draw(&s, remaining.count).sorted() == remaining.sorted())
    }

    @Test("does not open with the word already on screen",
          arguments: UInt32(1)...UInt32(25))
    func notPrevious(seed: UInt32) throws {
        var s = try source(seed: seed, previous: "delta")
        #expect(s.next() != "delta")
    }

    @Test("is deterministic and reproducible for a given rng")
    func reproducible() throws {
        var a = try source(seed: 9)
        var b = try source(seed: 9)
        #expect(draw(&a, 17) == draw(&b, 17))
    }

    @Test("reshuffles rather than replaying the same order every pass")
    func reshuffles() throws {
        var s = try source(seed: 4)
        let first = draw(&s, calendar.count)
        #expect(draw(&s, calendar.count) != first)
    }

    @Test("falls back to the whole calendar when the exclusion would empty it")
    func fallback() throws {
        var s = try source(exclude: "alpha", calendar: ["alpha"])
        #expect(s.next() == "alpha")
    }

    @Test("throws on an empty calendar")
    func emptyCalendar() {
        #expect(throws: EngineError.emptyCalendar) {
            _ = try EndlessSource(calendar: [], exclude: nil, previous: nil,
                                  rng: TestRNG())
        }
    }

    // No TypeScript counterpart, and the whole reason for choosing a struct: in
    // TypeScript the source is a closure, so handing it to two callers hands
    // them one shared cursor. Here a copy is an independent stream.
    //
    // The draws deliberately cross a pass boundary. Staying inside one pass
    // would prove nothing: both copies would just be reading the same
    // already-computed `order` at the same position. Only a reshuffle calls
    // `rng.next()`, so only crossing the boundary shows whether the generator
    // forked with the copy or is still shared. It is exactly the assertion that
    // fails if `rng` is a captured closure instead of a stored RandomSource.
    @Test("a copy is an independent stream, across a pass boundary")
    func valueSemantics() throws {
        var a = try source(seed: 11)
        _ = draw(&a, 3)       // mid-pass, cursor at 3 of 5
        var b = a             // a copy, not a reference
        #expect(draw(&a, 8) == draw(&b, 8))  // 8 draws: two reshuffles each
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL — `cannot find 'EndlessSource' in scope`.

- [ ] **Step 3: Write `EndlessSource.swift`**

```swift
/// A source of endless words that draws without replacement.
///
/// Each pass is a fresh shuffle of the pool, handed out one word at a time, so
/// no word repeats until the pool is exhausted. Reaching the end reshuffles,
/// and the first word of the new pass is forced to differ from the last of the
/// old — the same boundary rule the daily cycle uses. The pool is the eligible
/// daily calendar minus the excluded word, so a sub-floor word can never
/// headline endless and endless can never serve the day's daily rack.
///
/// The daily's `cycleOrder` is deliberately not reused: its cycle 0 is the
/// identity permutation, so endless would replay the committed calendar order,
/// which is precisely the daily's own sequence. Both share `seededPermutation`
/// and the boundary rule; only the ordering of the first pass differs.
///
/// SHAPE NOTE. The TypeScript is a function returning a closure that captures a
/// mutable cursor. Two idiomatic Swift translations exist:
///
///   - this `struct` with a `mutating func`, which has VALUE semantics: a copy
///     is an independent stream, and every holder must declare it `var`;
///   - a `final class`, which has REFERENCE semantics and matches the closure
///     exactly, since two references share one cursor.
///
/// The struct is used here because value semantics are Swift's default and the
/// surprise — that handing a copy to someone else does not share the cursor —
/// is the thing worth understanding early. The cost is real: `var` on every
/// declaration, `inout` to pass it to a helper, a generic parameter that
/// spreads to every type that mentions this one, and no way to share one stream
/// between two owners without deliberately wrapping it.
///
/// The generic `R: RandomSource` is load-bearing, not decoration. A
/// `rng: @escaping () -> Double` parameter would look simpler and would quietly
/// destroy the value semantics: a closure captures its state by reference, so
/// two copies of this struct would share one generator and diverge as soon as
/// either crossed a pass boundary. Storing the generator as a `var` of a
/// protocol type with a `mutating` requirement is what makes a copy a genuine
/// fork.
public struct EndlessSource<R: RandomSource> {
    private let pool: [String]
    private var order: [Int] = []
    private var position: Int
    private var last: String?
    private var rng: R

    /// - Parameters:
    ///   - calendar: the eligible words to draw from.
    ///   - exclude: a word this source must never draw, in practice today's
    ///     daily word.
    ///   - previous: the word already on screen, so the very first draw differs
    ///     from it.
    ///   - rng: the randomness. Advanced once per pass, to seed that pass's
    ///     shuffle. Injectable so tests are reproducible.
    public init(
        calendar: [String],
        exclude: String? = nil,
        previous: String? = nil,
        rng: R
    ) throws {
        guard !calendar.isEmpty else { throw EngineError.emptyCalendar }
        let remaining = calendar.filter { $0 != exclude }
        // A calendar of only the excluded word still has to deal something.
        pool = remaining.isEmpty ? calendar : remaining
        position = pool.count  // Out of range, so the first draw shuffles.
        last = previous
        self.rng = rng
    }

    /// The next word. `mutating` because it advances the cursor; that keyword is
    /// how Swift marks a method that changes a value type, and it is why callers
    /// must hold this in a `var`.
    public mutating func next() -> String {
        let n = pool.count
        if position >= n {
            // Clamped before scaling: `UInt32(1.0 * 4_294_967_296)` overflows
            // and TRAPS. Mulberry32 cannot return 1.0, but an injected
            // RandomSource can, and a crash inside a library is a worse failure
            // than a wrapped seed.
            let unit = min(max(rng.next(), 0), 0.999_999_999_9)
            order = seededPermutation(n, seed: UInt32(unit * 4_294_967_296.0))
            if n > 1 && pool[order[0]] == last {
                order.swapAt(0, 1)
            }
            position = 0
        }
        let word = pool[order[position]]
        position += 1
        last = word
        return word
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, all 13 ported tests plus the value-semantics one.

- [ ] **Step 5: Record the shape decision**

Write the struct-versus-class reasoning into `docs/PORT-LOG.md`: which was chosen, what the other would have cost, and how it actually felt to write. This is the single most useful entry in the log for someone coming from TypeScript.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: port the endless word source as a value type"
```

---

### Task 15: The measurements

No web counterpart. Two numbers the brief asks for, both in release mode.

**Files:**
- Modify: `Sources/PeachBench/main.swift`
- Create: `docs/MEASUREMENTS.md`

**Interfaces:**
- Consumes: `readWordList` (Task 1), `LetterCounts` and `letterCountsArray`/`canFormArray` (Task 3), `createPuzzle` and the list sources (Task 5).
- Produces: `docs/MEASUREMENTS.md` for Task 16 to quote.

- [ ] **Step 1: Write the benchmark**

`Sources/PeachBench/main.swift`:

```swift
import Foundation
import PeachEngine

/// Wall-clock seconds for a block. `ContinuousClock` is Swift's monotonic clock:
/// unlike `Date()`, it cannot go backwards if the system clock is adjusted.
func time<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
    let clock = ContinuousClock()
    var result: T!
    let elapsed = try clock.measure { result = try body() }
    let seconds = Double(elapsed.components.seconds)
        + Double(elapsed.components.attoseconds) / 1e18
    let ms = (seconds * 1000 * 10).rounded() / 10
    print(label.padding(toLength: 52, withPad: " ", startingAt: 0) + "\(ms) ms")
    return result
}

print("peach-bench — release mode: \(!_isDebugAssertConfiguration())")
print("")
print("=== Dictionary load ===")

// The 430k-word boundary list is enable + the SCOWL 95 additions, exactly as
// the web's loadGameData unions them. This is the number that decides whether a
// sorted binary file or SQLite is needed for a real app.
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

print("=== Letter counts: inline value type vs heap array ===")
print("One full formability pass over the boundary list, both ways.")

let rack = "serenade"
let inlineHits = time("LetterCounts (InlineArray, no allocation)") { () -> Int in
    let rackCounts = LetterCounts(rack)
    var hits = 0
    for word in boundary where word.count >= 3 && rackCounts.canForm(LetterCounts(word)) {
        hits += 1
    }
    return hits
}
let arrayHits = time("[Int8] (heap allocation per word)") { () -> Int in
    let rackCounts = letterCountsArray(rack)
    var hits = 0
    for word in boundary where word.count >= 3 && canFormArray(rackCounts, word) {
        hits += 1
    }
    return hits
}
precondition(inlineHits == arrayHits, "the two shapes disagree — they are not the same function")
print("  formable words: \(inlineHits)")
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
```

- [ ] **Step 2: Run it in debug first, to see the difference**

```bash
swift run peach-bench
```

Expected: it works, and the numbers are large. Note them — the debug-versus-release gap is itself worth reporting.

- [ ] **Step 3: Run it in release**

```bash
swift run -c release peach-bench
```

Expected: `release mode: true` and substantially smaller numbers. Run it three times and take the median; first runs pay a cold file-cache cost.

- [ ] **Step 4: Write `docs/MEASUREMENTS.md`**

Record, with the machine (chip, RAM, macOS version) named at the top:

- Time to read and parse each list.
- Time to build the `Set<String>` over the 430k-word boundary list.
- The debug-versus-release ratio for the same work.
- The `LetterCounts` versus `[Int8]` delta, as both an absolute figure and a ratio.
- End-to-end `createPuzzle` time on a real rack.
- A one-paragraph read on whether a sorted binary file or SQLite is needed for a real app, based on the release number alone.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "perf: measure dictionary load and the letter-count representations"
```

---

### Task 16: The report

The actual deliverable. Written from `docs/PORT-LOG.md` and `docs/MEASUREMENTS.md`.

**Write this even if earlier tasks are incomplete.** An honest "I got through nine of sixteen tasks and here is what I learned" answers the experiment's question; a finished port with no report does not.

**Files:**
- Create: `docs/REPORT.md`
- Modify: `README.md` (link the report — the link is already written in Task 1)

**Interfaces:**
- Consumes: `docs/PORT-LOG.md`, `docs/MEASUREMENTS.md`.
- Produces: `docs/REPORT.md`.

- [ ] **Step 1: Write the timing section**

From the log, not from memory: roughly how long the whole thing took, and which tasks were slow. Call out any task that took more than twice its expected time and say why.

- [ ] **Step 2: Write "Swift concepts that came up"**

Cover at least: Optionals, value versus reference semantics, protocols against interfaces, error handling, and the collection APIs. For each, say whether it was awkward coming from TypeScript, and be specific — a sentence about a concrete moment beats a paragraph of generality.

- [ ] **Step 3: Write "what TypeScript made easier"**

Candidates observed while planning; confirm or correct each from actual experience:

- Structural typing. Swift needs an explicit `: WordSource` conformance where TypeScript accepts any matching shape.
- `Dictionary` was not an available name — Swift's standard library owns it.
- `InlineArray` forced `swift-tools-version: 6.2` and a macOS 26 platform floor. An availability annotation is a Swift-ism TypeScript has no analogue for.
- Array indexing traps rather than returning `undefined`, so `tiers[index + 1]` needed an explicit bounds check.
- `&*` versus `*`: wrapping arithmetic must be asked for by name.

- [ ] **Step 4: Write "what Swift made cleaner"**

Candidates; confirm or correct each:

- `GuessResult` as an enum with associated values: `score` does not exist on a `.tooShort`, so there is nothing to read by mistake.
- `TierStanding.next` as a real Optional rather than `| null`.
- `case 8...` making the untested above-8 scoring branch visible.
- `Puzzle` as a struct: `readonly` and `ReadonlySet` are compile-time-only in TypeScript, whereas value semantics hold at runtime.
- Exhaustive `switch` over `Rung`.
- If the `dateComponents` one-liner never diverged from the faithful port (Task 12 Step 5), note that Foundation's calendar arithmetic made the TypeScript's defensive UTC re-anchoring unnecessary.

- [ ] **Step 5: Write "where Swift's strictness cost time without buying safety"**

**This section is required.** Without it the report can only conclude in one direction, and the real question is whether Antoine *wants* to write Swift. Look for: Optional unwrapping on things that cannot be nil, exhaustive switches over enums that will never grow, `var`/`inout` ceremony forced by `EndlessSource`'s value semantics, `try!` in test helpers, availability annotations, compiler fights over something TypeScript waved through. Be honest about which of these protected nothing.

- [ ] **Step 6: Write "bugs a Swift type system would have caught"**

Four are already in hand from planning; add anything found while porting:

1. **Completion computed twice, in the UI.** `shareResult.ts:56` guards `setTotal > 0`; `useGame.ts:602` does not. They agree only because `minSetSize = 15` — an invariant enforced in a third file. Found *by porting*, because the port had to ask where the function lived. Not fixed here; it gets its own change in the web repo.
2. **The stale `reachableScore` doc comment** in `engine/types.ts`, claiming "every findable word scored by length plus its rarity bonus" while `puzzle.ts` computes set points only. No test catches it, because `tiers.test.ts` hand-builds its fixture.
3. **`eligibility.ts`'s "never reimplement the set rules elsewhere"** — the fossil of an earlier two-computations-agreeing-by-coincidence bug.
4. **The share result** that could leak the daily answer until a discriminated union made it a compile error.

- [ ] **Step 7: Write the risk findings**

- **Date handling.** Whether Swift matched the web for the same instant, per the oracle, across how many cases and which zones. Say if the oracle was cut down to `dayIndex` only.
- **Dictionary loading.** The release-mode number, and what it implies for a real app.

- [ ] **Step 8: Write the verdict**

One honest paragraph: is continuing to a full port worth it? Separate "was this enjoyable" from "was this fast" — they can point in opposite directions, and both matter.

- [ ] **Step 9: Verify everything passes, then commit**

```bash
swift test 2>&1 | tail -5
swift run -c release peach-bench > /dev/null && echo "bench ok"
git add -A
git commit -m "docs: report the results of the Swift engine port experiment"
```

Do not claim the suite passes without running it and reading the output.

---

## Self-review notes

**Spec coverage.** Scoring curve → Task 2. Rarity classification → Task 4. `computeTier` → Task 6. Completion → Task 7. Calendar lookup with both epochs → Tasks 2, 12, 13. `createPuzzle` and the size-15 floor → Tasks 5, 9. `createEndlessSource` → Task 14. Swift Testing → all test tasks. `dayIndex` with injectable `TimeZone` → Task 12. Oracle → Task 11 (with the documented cut-down). Both letter-count shapes measured → Tasks 3, 15. Data snapshot, 7 files, SHA recorded → Task 1. Release-mode load timing → Task 15. Report with both directions of friction → Task 16. Minimal scaffolding, Swift `.gitignore`, README framing → Task 1.

**Verified before writing, not assumed:** `InlineArray` compiles on this toolchain and forces `swift-tools-version: 6.2` + `.macOS(.v26)`; the `Mulberry32` port reproduces Node's `seededPermutation(20, 7)`, `(50, 123)`, and `(5, 0x5e1ec7ed)` exactly; `seedForCycle` via `Int64` reproduces Node's `[2654435761, 1013904226, 3668339987, 145972072]`; the `dayIndex` port matches Node on all ten `America/Los_Angeles` DST instants; Swift Testing's `arguments:` works in a package built this way; `EndlessSource<R: RandomSource>` genuinely forks on copy across a pass boundary, and the `static let` fixtures (`Fixture.puzzle`, `OracleFixture.shared`) initialize without a Swift 6 concurrency complaint.

**Checked and found not to be a problem:** the `cal.dateComponents([.day], from: startOfDay, to: startOfDay)` one-liner was hunted for divergence from the faithful `dayIndex` port across `America/Santiago`, `Asia/Beirut`, `America/Havana`, and `Asia/Amman` — all midnight-DST-transition zones — and never diverged. Task 12 keeps the faithful port anyway (it mirrors the TypeScript) but records the finding rather than re-investigating.

**Hand-derived values, since confirmed against Node:** Task 12's `twoEpochs`
(220 and 47), the `zoneMatters` instant (`1788609600` = 2026-09-05T12:00:00Z),
Task 5's par of 22, and the shipped calendar's 626 words with `mnemonic` first.

**Known soft spot.** Task 1's word-list counts come from `wc -l` and are one
lower than `meta.json` where a file lacks a trailing newline. If Step 7 of Task 1
fails on a count, verify the copy before touching the expectation. Task 13's
`firstCycle` ordering and `word(on: -5)` were reasoned from the ported logic
rather than generated; if either fails, recompute from the TypeScript before
changing the implementation.
