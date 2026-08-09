# Design: Porting the Peach of a Word engine to Swift

Date: 2026-08-09
Status: approved

## What this is

A timeboxed experiment, not a product. It answers two questions:

1. Does Antoine enjoy writing Swift?
2. How fast is Antoine at it, actually?

Everything below serves those two questions. A finished port that answers
neither is a failure; an unfinished port with an honest report is a success.

The engine of the web game is pure, framework-free, and fully unit-tested, so
the domain is already solved and written down. The existing test suite is an
executable spec. That makes this an exercise in learning one thing (Swift)
rather than two (Swift and the problem), which is why most first projects in a
new language stall.

**Method: port the tests first, then write Swift until they pass.** A fuzzy
rewrite becomes a mechanical exercise with an oracle.

## Source material

Web repo: `~/Development/peach-of-a-word`, read-only. It stays canonical.

- Snapshot commit: `475edfc687b6bdce2a1186a80c801ae90bda3e57`
- Snapshot date: 2026-08-09
- Data generated at (from `meta.json`): 2026-06-24T15:11:59.569Z

Recorded in `SNAPSHOT.md`. The SHA matters more than the date: if the Swift
side ever disagrees with the web, the first question is whether the data
drifted or the logic did, and a SHA answers that in seconds.

Copy data in; never reference across repos. If the two drift later, that is
itself information about whether the port is worth continuing.

## Package shape

A pure Swift package. No SwiftUI, no app target, no Xcode project beyond what
SPM generates.

```
Package.swift          swift-tools-version 6.0, platforms [.macOS(.v14)]
Sources/PeachEngine/   the library
Tests/PeachEngineTests/
Fixtures/              oracle.json (generated), see below
Data/                  the dated snapshot, 7 files
tools/                 the throwaway oracle generator (Node)
```

### Swift Testing, not XCTest

Swift Testing ships with the 6.3.3 toolchain. `@Test` with `arguments:` maps
onto vitest's `describe`/`it` shape far more directly than `XCTestCase`
subclasses do, `#expect` reads like `expect`, and there is no
`XCTAssertEqual`-family memorisation tax. `init` replaces `beforeEach`.
Reported as a decision with reasoning, per the brief.

## What gets ported

In this order. The first six are the brief's list; endless is committed but
sequenced last so a blown timebox still leaves a complete picture of the core.

1. **The scoring curve.** `scoreForLength` (3=1, 4=3, 5=5, 6=7, 7=11, 8=15)
   and `findScore` (length plus rarity bonus: uncommon 1, rare 2, mythic 4;
   set words carry no bonus).
2. **Rarity classification.** `classifyWord`. Uncommon is in SCOWL 70 but not
   the common pool; rare is in 95 but not 70; mythic is valid but beyond 95.
3. **`computeTier`.** Score over par, six named ranks, top rank at 0.80 of par.
   Par is `reachableScore` = the common-set points, not every findable word.
   This is the single most load-bearing decision in the model.
4. **Completion.** A word count, not a points threshold: every common word the
   rack can spell. Sits above the named ladder. See the deviation below.
5. **Calendar lookup.** `dayIndex` and `dailySourceWord`, with the two-epoch
   split intact: `STORAGE_EPOCH` fixed at 2026-01-01, `DAILY_EPOCH` movable at
   2026-06-23. Getting this wrong silently re-dates puzzles.
6. **`createPuzzle`** and `MIN_SET_SIZE = 15` (`sourceSetSize`,
   `isEligibleSource`, `eligibleSourceWords`).
7. **`createEndlessSource`.** Committed, sequenced last.

Supporting pieces that come along because the above need them: `formability`,
`shuffle` (`seededPermutation`), `validate` (`validateGuess`,
`normalizeGuess`), `generateCalendar`, and the list-backed `WordSource` /
`Dictionary` implementations.

### Type mapping

| TypeScript | Swift | Note |
|---|---|---|
| `interface WordSource` | `protocol WordSource` | near-verbatim |
| `interface Dictionary extends WordSource` | `protocol Dictionary: WordSource` | protocol inheritance |
| `interface Puzzle` (readonly fields) | `struct Puzzle` (`let`) | value semantics for free |
| `interface TierStanding` | `struct TierStanding` | |
| `type Rung = 'set' \| ...` | `enum Rung: String, CaseIterable` | |
| `type GuessResult = {kind:'valid', ...} \| ...` | `enum GuessResult` with associated values | the discriminated union, compiler-enforced |
| `ReadonlySet<string>` | `Set<String>` (a `let`) | |
| `Int8Array(26)` letter counts | `[Int8]` of 26, or a fixed-size struct | decide during implementation; note which and why |
| `createEndlessSource` returning a closure | `struct` + `mutating func` **or** `final class` | the interesting decision; see below |

`createEndlessSource` is deliberately left open. In TypeScript it is a closure
capturing a mutable cursor. Swift offers two idiomatic answers with genuinely
different semantics, and finding out how each feels to write is closer to the
point of this experiment than picking one in advance. Whichever is chosen, the
report explains the choice and what the other would have cost.

## Two deliberate deviations from the TypeScript

Both are reported, not silently applied.

### 1. `isComplete` moves into the engine

Completion is not in `src/engine/` in the web repo. It is computed in the UI,
twice:

- `src/ui/share/shareResult.ts:56` — `tier.setTotal > 0 && tier.setFound >= tier.setTotal`
- `src/ui/useGame.ts:602` — `active.tier.setFound + (result.rung === 'set' ? 1 : 0) >= active.tier.setTotal`

Two computations of the same fact. The second has no `setTotal > 0` guard. They
cannot diverge today only because `MIN_SET_SIZE = 15` means `setTotal` is never
zero — so they agree by an invariant enforced somewhere else entirely. That is
precisely the pattern that produced the share points mismatch (360 against
267).

The Swift side gets exactly one `isComplete(_:in:)` in the engine.

**The web repo is not fixed as part of this experiment.** It is out of scope,
the repos stay independent, and the finding is noted in the report so it can
get its own change.

### 2. `dayIndex` takes an injectable `TimeZone`

JavaScript's `Date` carries local-calendar accessors (`getFullYear`,
`getMonth`, `getDate`). Swift's `Date` is a bare instant with none. Reaching
for `Calendar.current` inside `dayIndex` would make the brief's required tests
— a timezone well away from UTC, DST transitions in both directions —
unwritable, and would make the suite depend on the machine's clock settings.

Signature takes the zone as a parameter from the first line of Swift.

**Port the structure faithfully, do not "improve" it.** The TS is
`Date.UTC(localY, localM, localD)` minus `Date.UTC(epochY, epochM, epochD)`,
over 86_400_000, floored. It deliberately avoids `(now - epoch) / dayMs`,
which drifts across DST. The faithful Swift port extracts Y/M/D via the
*injected* zone, then diffs those components in a UTC calendar.
`calendar.dateComponents([.day], from:to:)` on two `Date`s is the tempting
one-liner and diverges on exactly the cases being tested (midnight-transition
zones, historically skipped calendar dates). Which one the DST tests actually
discriminate gets verified, not assumed.

## The oracle fixture

The brief asks whether the Swift result matches the web for the same instant.
That is a measurement, not a judgement, so it gets generated rather than
eyeballed.

A throwaway Node script in `tools/`, writing into **this** repo and never
touching the web repo, emits `Fixtures/oracle.json`:

- `dayIndex(instant, timeZone)` across DST boundaries in both directions, at
  midnight, and in a zone well away from UTC.
- `seededPermutation(n, seed)` tables.
- `cycleOrder(cycle, n)` tables.

Swift tests assert against the fixture. This turns both named risks from
"a check" into "a claim with evidence behind it".

### The PRNG hazard

The two random paths use *different* JavaScript number semantics and must not
be unified:

- `mulberry32` uses `Math.imul` — int32 wrapping multiply. Ports to pure
  `UInt32` with `&+` / `&*` / `^` / `>>`.
- `seedForCycle` uses `cycle * 0x9e3779b1 >>> 0` — a **Double** multiply, then
  mod 2³². Porting this as `&*` would silently diverge.

Both get confirmed against the oracle rather than trusted.

## The data snapshot

Seven files into `Data/`, roughly 8 MB, committed once and frozen:

`enable.txt`, `scowl95-additions.txt`, `common-pool.txt`,
`beyond-size-70.txt`, `beyond-size-95.txt`, `daily-calendar.json`,
`meta.json`.

Deliberately excluded, and said so in the report so a later reader knows it was
a decision rather than an oversight:

- `defs/` — 795 directories of Wiktionary reveal content. Out of scope.
- `source-pool.json` — the eligibility tests build their own synthetic pools.

## Testing

The web engine's test files are the specification. Port the assertions, not
just the function signatures. Roughly:

| Web test file | Assertions | Notes |
|---|---|---|
| `scoring.test.ts` | 2 blocks | curve plus rarity bonuses |
| `classify.test.ts` | 5 | hand-built puzzle fixture |
| `tiers.test.ts` | 7 | includes the "21 of 23" guard |
| `formability.test.ts` | 4 | |
| `shuffle.test.ts` | 3 | plus oracle cross-check |
| `calendar.test.ts` | 5 | the append-only freeze invariant |
| `puzzle.test.ts` | ~14 | `createPuzzle` and `validateGuess` |
| `eligibility.test.ts` | 4 | the size-15 floor, at and one below |
| `daily.test.ts` | ~20 | `dayIndex`, `dailySourceWord`, endless |

New tests with no web counterpart:

- **Date boundaries.** Midnight either side, DST forward and back, a zone well
  away from UTC. Asserted against `oracle.json`.
- **Completion.** `isComplete`, including the `setTotal == 0` case the web's
  `useGame.ts` path does not guard.
- **`scoreForLength` above 8.** The `length > 8 → 15` branch is untested in
  TypeScript. A Swift `switch` with `case 8...` makes it explicit.

## The dictionary load measurement

430,172 words (from `meta.json`: enable 172,727 + scowl95Additions 257,445).
The brief asks for a number, not a solution.

Load `enable.txt` + `scowl95-additions.txt`, time it, report it. Measured in
**release** mode, not under `swift test` — debug Swift string and collection
work is often around 10× slower, and a debug number would argue for SQLite on a
lie. That number decides whether a sorted binary file or SQLite is needed later.

Do not solve the problem here. Just measure it.

## Explicitly out of scope

- SwiftUI, any view code, any app target.
- Persistence, audio, theming, the share, widgets.
- The data pipeline. Vendoring, Wiktionary acquisition, sense selection, and
  calendar generation stay in the web repo permanently. The Swift side only
  ever consumes baked output.
- Fixing the web repo's completion duplication.
- Making it pretty or idiomatic-at-all-costs. Clear beats clever, especially
  since Antoine is reading this to learn. Unfamiliar Swift idioms get a brief
  explanation in a comment as they appear.

## Repo scaffolding

Minimal, deliberately. CI exists to catch what you did not run, and in a
timeboxed solo experiment the tests are running constantly anyway. It earns its
place when there are collaborators or when you stop looking, and neither is
true yet. Add it if this graduates to a real port.

- `git init`, default branch `main`
- MIT LICENSE, copyright Anthony Liddle
- `.gitignore` — Swift, not Node: `.build/`, `.swiftpm/`, `xcuserdata/`
- `README.md` — one short paragraph saying this is a timeboxed experiment
  porting the Peach of a Word engine to find out whether Swift is worth
  continuing with, a pointer to the web repo as canonical, and the snapshot
  date and SHA. In three months the first question anyone asks is whether this
  was a commitment or a probe; the README should answer it.
- `SNAPSHOT.md` — snapshot date, source SHA, `meta.json` generation date, and
  what was excluded.
- Conventional commit messages written by hand. No commitlint, no husky, no
  Biome, no dependabot — the global Node conventions do not apply to a Swift
  package and the tooling is not worth installing for this.

## Timebox and the report

Aim for a couple of focused sessions. **If it runs long, stop and report rather
than pushing through.** An honest "the engine took twice as long as expected
and here is why" is a more useful result than a finished port, because it
answers the question the experiment exists to answer.

The report is a deliverable, not an afterthought. It covers:

- Roughly how long it took, and which parts were slow.
- Which Swift concepts came up and which were awkward coming from TypeScript.
  Optionals, value versus reference semantics, protocols against interfaces,
  error handling, and the collection APIs are the likely ones.
- What TypeScript expressed easily that Swift made harder, and what Swift made
  cleaner. Both directions are informative.
- Where a Swift type system would have caught a bug the TypeScript shipped.
  Material already in hand:
  - The completion duplication above — found *by porting*, because
    reimplementing in a language with different defaults surfaces assumptions
    the original never had to state.
  - The stale `reachableScore` doc comment in `engine/types.ts`, which claims
    "every findable word scored by length plus its rarity bonus" while
    `puzzle.ts` computes `bandScore(commonWords, 'set')` — set points, no
    bonuses. No test catches it, because `tiers.test.ts` hand-builds its
    fixture.
  - The `eligibility.ts` comment "never reimplement the set rules elsewhere" —
    the fossil of an earlier two-computations-agreeing-by-coincidence bug.
  - The share result, which could leak the daily answer until a discriminated
    union made it a compile error (`shareResult.ts`: `DailyShareResult` has no
    source-word affordance at all; `EndlessShareResult` has `showSourceWord`).
- Whether the Swift `dayIndex` matches the web for the same instant, per the
  oracle.
- The dictionary load number, in release mode.
- An honest read on whether continuing to a full port is worth it.

## Done looks like

A standalone Swift package where the ported test suite passes against a ported
engine, with the date-boundary tests written and asserted against the oracle,
the dictionary load time measured in release mode, and a written report.
