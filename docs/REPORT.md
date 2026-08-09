# The Swift engine experiment: report

2026-08-09. Written from `docs/PORT-LOG.md` and `docs/MEASUREMENTS.md`.

## What was actually done

The pure engine of Peach of a Word, ported from TypeScript to Swift, tests
first. 16 source files, 84 tests in 18 suites, all passing. Package builds and
tests clean on Swift 6.3.3 / macOS 26.

Everything the brief listed is ported: the scoring curve, rarity classification,
`computeTier`, completion, the calendar lookup with both epochs intact,
`createPuzzle` with the size-15 floor, and `createEndlessSource`. Plus the two
risk areas: date-boundary tests against a generated TypeScript oracle, and
release-mode load measurements.

**The question changed partway through**, and this report follows the new one.
It started as "does Antoine enjoy writing Swift, and how fast is he". After
Task 2 it became "what does working on a native Swift project look like, and
could I ship something". Tasks 3–15 were therefore skimmed rather than read
closely, **by explicit choice**. That matters for what this report can and
cannot claim, and it is flagged again where it bites.

## One thing that must not be misread

**The engine is the easy half.** It was chosen precisely because it is pure,
framework-free, and already fully specified by an existing test suite — the
conditions under which a new language is least painful. It ported in a handful
of hours with almost no friction.

**That is weak evidence about shipping an app.** It says the domain logic
transfers cleanly. It says almost nothing about SwiftUI, about state management
in a real UI, or about the App Store. Anyone reading "the engine took a few
hours" as "the app is a few weekends" is reading it wrong.

The one hard number in this whole run that bears directly on shipping is the
dictionary load time. Weight it above the elapsed times.

## Timing, honestly

Wall-clock between commits includes review time, so it overstates working time.
The figures below are agent-active estimates, not stopwatch readings. **Treat
the relative costs as the signal and the absolute numbers as soft.**

| Task | Est. | Note |
|---|---|---|
| 1. Scaffolding + data snapshot | ~20 min | Only ~4 min was Swift. The rest was verifying the snapshot — which paid for itself, see Findings. |
| 2. Config, `Rung`, scoring | ~8 min | Pure functions over integers. Zero friction. |
| 3. Formability, both shapes | ~10 min | |
| 4. Types + classification | ~10 min | |
| 5. `createPuzzle` + list sources | ~12 min | |
| 6–7. `computeTier`, `isComplete` | ~15 min | |
| 8–9. `validateGuess`, eligibility | ~12 min | One compile error, see below. |
| 10. Shuffle + calendar | ~10 min | PRNG matched Node first try — because it was spiked during planning. |
| 11–13. Oracle, `dayIndex`, daily | ~25 min | Largest engine task. |
| 14. `EndlessSource` | ~12 min | |
| 15. Measurements | ~20 min | |
| **Engine total** | **~2.5 h** | Excluding planning and this report. |

**Where the time did not go:** debugging. Across the whole port there was one
genuine compile error (a `String.UnicodeScalarView` construction in
`normalizeGuess`) and one wrong expectation (word counts off by one, because the
data files lack trailing newlines). Nothing else failed twice.

**Why that is not as impressive as it sounds.** Roughly an hour of spiking
happened *during planning* — verifying `InlineArray`, the PRNG port, and
`dayIndex` against Node before any plan text was written. That work is real and
is not in the table. The port went smoothly partly because the three things
that could have gone wrong had already been checked.

## Swift concepts that came up

**Optionals.** Barely an issue. `TierStanding.next` is a genuine `Optional`
where TypeScript had `| null`, and the compiler stopping you from reading
`.index` off it without handling nil is straightforwardly better. No fights.

**Value versus reference semantics.** The most interesting thing in the port,
and the only place a design decision had a measurable consequence. See
`EndlessSource` and the letter-counts measurement below.

**Protocols against interfaces.** Near-identical in shape. The one real
difference: Swift conformance is *declared*, TypeScript interfaces are
*structural*. That cost nothing here because the port controls both sides.

**Error handling.** `enum EngineError: Error` plus `throws` is a clear
improvement on `throw new Error(...)`, where the thrown value is `unknown` and
the message is the only signal. `#expect(throws: EngineError.emptyCalendar)`
asserts on the specific case, not on a string.

**Collection APIs.** Mostly a pleasure. `Set` algebra (`subtracting`, `union`)
made `createPuzzle`'s band partitioning read better than the TypeScript's
`[...set].filter(...)` spread-and-filter dance.

## What TypeScript made easier

- **`Dictionary` was not an available name.** Swift's standard library owns it,
  so the `Dictionary` protocol became `ValidationDictionary`. A rename is
  trivial; needing one at all is a small tax structural typing never charges.
- **`InlineArray` forced the whole package to macOS 26** and
  `swift-tools-version: 6.2`. Availability gating is a Swift-ism with no
  TypeScript analogue: an API can exist in the language but not on your
  deployment target. Discovering this cost a compile-fail-and-retry cycle during
  planning.
- **Array indexing traps rather than returning `undefined`.** `tiers[index + 1]`
  needed an explicit bounds check. The TypeScript relied on the out-of-range
  read producing `undefined` and the `?:` handling it. Swift's behaviour is
  safer and more verbose.
- **Wrapping arithmetic must be requested by name.** `&*` and `&+`. Plain `*`
  traps on overflow. Correct, and one more thing to know before porting a PRNG.
- **`normalizeGuess` needed a `String.UnicodeScalarView` round-trip** to filter
  characters — the only genuine compile error in the run. TypeScript's
  `.replace(/[^a-z]/g, '')` is one obvious call; the Swift is three type
  conversions deep for the same job.
- **The generic parameter on `EndlessSource<R: RandomSource>` is viral.** Every
  test helper that touches it has to name the concrete type. TypeScript's
  closure needed no type parameter at all.

## What Swift made cleaner

- **`GuessResult` as an enum with associated values.** `score` does not exist
  except inside a `case .valid` binding. In TypeScript the same union needs
  narrowing by `kind`, and the narrowing is checked only where you remember to
  ask. This is the shape that stopped the daily share leaking the answer in the
  web version, and here the compiler enforces it rather than a convention.
- **`case 8...` made an untested branch visible.** The TypeScript wrote
  `SCORE_BY_LENGTH[length] ?? (length > 8 ? 15 : 0)` — a fallback tucked into an
  expression, never tested. As a range pattern it sits in the switch as a peer
  of `case 3`, and leaving it untested felt like an omission rather than an
  oversight. **The language changed what looked incomplete.**
- **`switch` as an expression** removed six `return`s from the scoring curve.
- **`Puzzle` as a struct.** `readonly` and `ReadonlySet` are compile-time-only
  in TypeScript and vanish at runtime; value semantics hold all the way down.
- **1-based months.** `DateComponents` matches the epoch constants, so the
  TypeScript's `epoch.month - 1` at every call site simply disappears. One fewer
  off-by-one to get wrong.
- **A worry that did not materialise.** The plan expected Foundation's
  `dateComponents([.day], from:to:)` one-liner to diverge from the faithful
  UTC-re-anchoring port on midnight-DST-transition zones. It was hunted across
  Santiago, Beirut, Havana, Amman, Chatham, and Lord Howe — **no divergence
  anywhere**. There is now a test asserting both agree across all 22 oracle
  cases. Foundation's calendar arithmetic is robust enough that the TypeScript's
  defensive trick is unnecessary in Swift. The faithful port was kept anyway,
  because it mirrors the original.

## Where Swift's strictness cost time without buying safety

Required section, because without it this report can only conclude in one
direction.

- **`inout` ceremony in the `EndlessSource` tests.** Every helper that advances
  the source needs `inout`, and every holder needs `var`. This is the direct
  price of choosing value semantics. It bought a real property — a copy is an
  independent stream — that the *game* does not need. Nothing in Peach of a Word
  ever copies an endless source. The teaching value was high; the safety value
  was zero.
- **`try!` in test helpers.** `OracleFixture.shared` force-unwraps twice.
  Correct behaviour (a missing oracle should fail loudly), but it is Swift
  making you write an explicit escape hatch to get TypeScript's default.
- **Availability gating on `InlineArray`** pinned the package to macOS 26 for a
  26-byte array. Defensible for an experiment, plainly disproportionate as a
  deployment constraint.
- **The `_isDebugAssertConfiguration()` ternary warned** "will never be
  executed", because the condition folds at compile time. Correct, useless, and
  needed a rewrite into if/else to silence.
- **Two `Calendar` types in scope.** `Foundation.Calendar` had to be spelled out
  in `Daily.swift` because this package has its own `Calendar.swift`. Trivial,
  but a papercut structural typing never produces.

None of these is serious. Collectively they are the texture of the language:
Swift asks for a small explicit statement in a lot of places where TypeScript
assumes. Whether that reads as rigour or as nagging is a taste question this
report cannot settle.

## Bugs the port surfaced in the web repo

Four, of which two were found *by porting* rather than by reading. None fixed —
the web repo is out of scope for this experiment. Each deserves its own change.

### 1. Completion is computed twice, in the UI, and one copy is unguarded

- `src/ui/share/shareResult.ts:56` — `tier.setTotal > 0 && tier.setFound >= tier.setTotal`
- `src/ui/useGame.ts:602` — `setFound + (rung === 'set' ? 1 : 0) >= setTotal`, **no `> 0` guard**

Found by asking "where does `isComplete` live so I can port it" and discovering
the answer was "nowhere, it is inlined twice". They cannot diverge today only
because `minSetSize = 15` guarantees `setTotal >= 15` — an invariant enforced in
a third file entirely. Three files conspiring to keep a fourth correct. This is
the same shape as the share-points mismatch (360 against 267).

The Swift side has one `isComplete`, with a test for the `setTotal == 0` case
the web's second call site would get wrong.

### 2. `meta.json` no longer describes the shipped word lists

Found in Task 1, by asserting on the snapshot instead of trusting it.

| Count | `meta.json` | Actually ships | Drift |
|---|---|---|---|
| enable | 172,727 | 172,562 | −165 |
| common | 10,861 | 10,879 | +18 |
| beyond70 | 318,691 | 315,922 | −2,769 |
| beyond95 | 5,399 | 5,389 | −10 |
| **boundary** | **430,172** | **427,290** | **−2,882** |

`meta.json` was generated 2026-06-24; the lists were re-baked 2026-08-03 with
the dictionary patch applied, and nothing regenerated the metadata. **The
"430,000 words" figure in the experiment brief traces to this stale field.**
0.7% off — small enough that nobody catches it by eye. Pinned by a test in
`SmokeTests.swift`.

### 3. The `reachableScore` doc comment contradicts the implementation

`src/engine/types.ts` claims "every findable word scored by length plus its
rarity bonus". `src/engine/puzzle.ts` computes `bandScore(commonWords, 'set')` —
set points, no bonuses. No test catches it, because `tiers.test.ts` hand-builds
its fixture. The Swift port sides with the implementation and has a test
(`par == 22` on the shared fixture) pinning it.

### 4. `eligibility.ts`'s "never reimplement the set rules elsewhere"

Not a bug — the fossil of one. The warning survives into the Swift port because
it records exactly the failure mode of finding #1.

Also noted, cosmetic: none of the five shipped word lists ends in a trailing
newline, so `wc -l` under-reports every one of them by one.

## Risk 1: date handling

**Result: the Swift `dayIndex` matches the TypeScript exactly on every instant
tested — 22 cases across 8 time zones.**

`Fixtures/oracle.json` is generated by `tools/generate-oracle.mjs`, which runs
the TypeScript `dayIndex` verbatim under each zone's `TZ` and records the
answers. Coverage: US DST forward (the 23-hour day) and back (the repeated
01:30), midnight either side, the epoch day, UTC ±0, Kiritimati (+14), Apia,
Kolkata (+5:30), Chatham (+12:45), Santiago and Lord Howe (midnight
transitions).

**Scope cut, as the plan permitted.** The oracle covers `dayIndex` **only**. The
PRNG paths (`seededPermutation`, `cycleOrder`, `seedForCycle`) are pinned by
Node-verified values hardcoded in the Swift tests instead. The contingency
condition had fired: the deliverable had moved to the shipping question, and the
oracle generator was the one task that was Node infrastructure rather than
Swift. This is weaker in exactly one respect — the hardcoded values do not
regenerate if the TypeScript changes — and no weaker at all for catching a wrong
port today, which is the actual risk.

The two PRNG hazards both landed correctly, and both would have been silent
failures:

- `mulberry32` uses `Math.imul` — a 32-bit wrapping multiply. Ports to `&*`
  on `UInt32`.
- `seedForCycle` uses `cycle * 0x9e3779b1 >>> 0` — a **Double** multiply then a
  mod-2³² coercion, *not* a wrapping multiply. Porting it as `&*` would look
  right and produce different numbers. It needs `Int64` widening first.

**The deviation that made this testable:** `dayIndex` takes an injectable
`TimeZone`. JavaScript's `Date` carries local-calendar accessors; Swift's `Date`
is a bare instant with none. Reaching for `Calendar.current` would have made
every test above unwritable and the suite dependent on the machine's settings.

## Risk 2: dictionary loading

Full detail in `docs/MEASUREMENTS.md`. The headline, release mode, M3 Pro:

| | |
|---|---|
| Full cold load: 5 lists + the 427,290-word validation `Set` | **186 ms** |
| Building the `Set` alone | **11.8 ms** |
| `createPuzzle` end-to-end on a real rack | **44 ms** |

**No sorted binary file or SQLite is needed.** 186 ms of launch work is
noticeable but absorbed by a launch screen, and deferring the two rarity-band
lists (not needed to render a rack) takes the blocking portion to about 110 ms.

The instructive part is *where* the time goes. The hash set is essentially free
at 11.8 ms; ~173 ms of the 186 is reading and splitting UTF-8 into 427,290
individually allocated `String`s. So the optimisation with the best return is a
packed binary blob searched in place — **not** a database, which would add a
dependency to fix the part that was already fast.

**Caveat, stated plainly: this is a Mac number.** An iPhone has a comparable
single core and fast storage, so the same work is plausibly within 1.5–2×, but
that is an inference. Nothing here ran on a phone. Also unmeasured: memory
footprint, which on a constrained device may matter more than the milliseconds.

### The value-semantics measurement

The two letter-count representations, one full pass over 427,290 words:

| | Release |
|---|---|
| `InlineArray<26, Int8>`, no allocation | **16.7 ms** |
| `[Int8]`, heap allocation per word | **41.6 ms** |

**2.5×.** The heap version is the literal translation of the TypeScript's
`Int8Array(26)`. Swift's default — a fixed-size value type — is the fast one,
and the faithful translation is the slow one.

Absolute stakes are small (25 ms, once per puzzle). The point is the direction:
the idiomatic choice and the fast choice coincided.

One more number worth keeping: `LetterCounts` runs **417.9 ms in debug against
16.7 ms in release — a 25× penalty.** Swift's abstractions are free only after
the optimiser. Any benchmark run under `swift test` would have been off by an
order of magnitude and would have argued for a database on a lie.

---

# What stands between this and a shipped app

The engine is the half that ports cleanly. Everything hard is downstream.

**Two bars, routinely conflated, very far apart:**

- **Onto Bea's phone.** TestFlight internal testing, or a direct Xcode install.
  **No App Store review at all.**
- **Into the App Store.** Public listing, full review, age rating, privacy
  disclosures, ongoing maintenance.

Facts below were verified against Apple's and Creative Commons' own pages on
2026-08-09, not recalled. Where something could not be settled that way it is
marked **uncertain**.

## The near bar: onto Bea's phone

| Item | Effort | Notes |
|---|---|---|
| Apple Developer Program | **$99/year** + enrolment time | Verified on Apple's comparison page. A free Apple Account can already do on-device testing, but provisioning profiles and App IDs **expire after 7 days** and you are capped at 3 devices — fine for poking at something, useless for "Bea has the game on her phone". |
| TestFlight internal testing | Low | **Up to 100 internal testers, and internal testing does NOT require Beta App Review.** This is the key fact. Bea as an internal tester means no Apple review stands between a working build and her phone. |
| TestFlight external testing | Moderate | Up to 10,000 testers, but builds **are** sent for Beta App Review. Not needed to reach one person. |

**So the near bar is: $99, an App Store Connect record, and a build that runs.**
No review, no listing, no privacy policy. That is a genuinely low bar, and it is
the one that matters for the actual goal.

## The work between here and a build that runs

Ordered by size. These are estimates for someone learning as they go, and they
are the least reliable numbers in this report.

| Area | Effort | Carries over? |
|---|---|---|
| **SwiftUI rebuild** | **Largest item by a wide margin.** Multiple sessions, not one. | `useGame.ts` is ~600 lines and is *reducer-shaped* — the state transitions port. The views do not. Every component, layout, animation, and the confetti is new work. Treat "the engine took 2.5 hours" as saying nothing about this. |
| Two-theme system | Moderate | `themeCopy.ts` is data and ports directly. The CSS does not; SwiftUI styling is a rewrite. |
| Persistence | Small — half a session | `storage.ts` → `UserDefaults` or a JSON file. The `storageEpoch` day-key scheme is **already ported** and tested here. |
| Audio | Small to moderate | The web repo already has an `AudioEngine` protocol with `WebAudioEngine` behind it, so the seam exists. A new `AVFoundation` implementation slots in. Good architecture paying off. |
| Dictionary loading | **Already decided** | 186 ms, ship the plain lists. See above. Do re-measure on device. |
| App icons and launch assets | Small | Existing 512/192/maskable PNGs are the wrong set; modern Xcode wants a single 1024×1024 and generates the rest. Re-export, not redesign. |
| Provisioning and signing | Small | Xcode automatic signing handles the common path. |
| **Out of scope, permanently** | — | The data pipeline stays in the web repo. The Swift side only ever consumes baked output. This is already how the port is structured. |

## The far bar: App Store review

None of these looks like a wall, but two need real attention.

**4.2 Minimum functionality — not a concern.** The guideline targets web
clippings and link collections. A native word game with its own UI, offline
dictionary, and local state is exactly what it asks for. Being a port of a
website is not itself a problem; being a *wrapper around* one would be.

**1.1 Objectionable content, and the age rating — needs attention, is work.**
The app ships a 427,290-word dictionary. It will contain words the age-rating
questionnaire asks about, and words that would be unwelcome on screen. The web
repo already has a curated slur denylist with a 223-line test suite, and the
patch is baked into the shipped lists — so **the mitigation already exists and
already ships**. What is new: honestly answering App Store Connect's rating
questionnaire, and deciding whether "profanity appears in a dictionary the app
validates against but never displays unprompted" needs disclosure. Work, not a
blocker, but do not answer that questionnaire carelessly.

**5.2 Intellectual property — mostly already handled.** ENABLE is public domain.
SCOWL's licence permits use with the copyright notice reproduced. The web repo's
`ATTRIBUTION.md` and in-app colophon already do this. Port the colophon.

**5.1 Privacy policy — small but mandatory.** Every app needs a privacy policy
URL in App Store Connect, even one that collects nothing. A fully offline game
can declare "no data collected", but the URL is still required. Half an hour,
easy to be blindsided by.

**Wiktionary and CC BY-SA 4.0 — the one item worth real care.**

State the question precisely rather than answering it from memory:

The `defs/` bundles are short definitions derived from Wiktionary — modified
(truncated, part-of-speech prefixed), which likely makes them **Adapted
Material** under CC BY-SA 4.0 §1.1. That triggers ShareAlike: the definitions
themselves must be re-licensed CC BY-SA. **That does not infect the app's
source code** — ShareAlike attaches to the adapted content, not to a program
that displays it.

The sharper issue is §3(b)(3), verified verbatim today:

> "You may not offer or impose any additional or different terms or conditions
> on, or apply any Effective Technological Measures to, Adapted Material that
> restrict exercise of the rights granted under the Adapter's License You
> apply."

App Store apps are distributed with Apple's DRM. Whether that constitutes
applying Effective Technological Measures to bundled CC BY-SA content is the
same shape of question that removed GPL apps from the App Store years ago.

**Assessment: low practical risk, unresolved in theory, and cheaply mitigable.**

- *Practical:* Wikimedia's own apps distribute CC BY-SA content through the App
  Store routinely. This is common, established practice.
- *Theoretical:* **uncertain.** I could not settle it from primary sources, and
  this report should not pretend otherwise. If certainty matters, it is a
  question for someone who does licensing for a living.
- *Mitigation, and it is nearly free:* **this port already excludes `defs/`.**
  Ship v1 without the tappable definitions and the reveal text, or fetch them at
  runtime rather than bundling them, and the question does not arise. The
  definitions are a nice-to-have, not the game.

**Nothing here is a blocker.** The closest thing to one is the Apple Developer
Program, which is a $99 gate rather than an obstacle, and enrolment timing —
identity verification can add days, so start it before it is on the critical
path.

---

# Verdict

Three questions, three answers. They do not all point the same way.

### 1. Could a native Peach of a Word get onto Bea's phone?

**Yes, and the barrier is lower than it looks.** TestFlight internal testing
needs no Apple review, and the engine — the part that carries all the game's
actual rules — already exists, is tested, and is fast enough to ship as-is. What
stands between here and there is the SwiftUI rebuild, and that is ordinary work
with a known shape, not a research problem.

The honest caveat: the SwiftUI rebuild is several times the size of everything
done so far, and nothing in this experiment tested it.

### 2. Could it reach the App Store?

**Probably yes, with two things to handle deliberately.** The age-rating
questionnaire deserves a careful answer given the dictionary, and the CC BY-SA
question deserves either advice or the free mitigation of not shipping the
definitions in v1. Everything else — minimum functionality, attribution, privacy
policy, signing — is routine.

This is a lower-confidence "yes" than the first, because it depends on Apple's
judgement rather than on work being done.

### 3. Was the engine port fast, and what does that predict?

**Fast: about 2.5 hours of active work for 16 files and 84 tests, with one
compile error and one wrong expectation.** But an hour of de-risking happened
during planning and is not in that figure, and — the important part — **the
engine is the easy half by construction.** It is pure logic with an existing
test suite acting as an executable spec.

What it genuinely predicts: the *domain* transfers cleanly, Swift did not fight
back, and the 186 ms load number removes the storage-format question entirely.
What it does not predict: anything about SwiftUI.

### Is continuing worth it?

**Yes, but change what gets built next.** Not more engine — the engine is done,
and porting more pure logic will keep producing the same easy answer. The next
experiment should be the *smallest possible SwiftUI app on top of this package*:
one rack, a text field, a found-words list, no theming, no audio, no
persistence. Half a day, maybe.

That would test the half this experiment deliberately did not, and it is the
half the shipping decision actually turns on. Running it before committing to a
full port is the cheap version of finding out.

---

## Appendix: what this report is not evidence for

- **Legibility.** Tasks 3–15 were skimmed rather than read closely, by choice.
  The Swift may or may not be readable to someone learning; this run did not
  test that after Task 2, and the verdict above deliberately leans on shipping
  evidence rather than on legibility evidence that was not gathered.
- **On-device performance.** Every number is macOS on an M3 Pro.
- **SwiftUI.** Entirely untouched.
- **The CC BY-SA position.** Flagged as uncertain, not resolved.
- **The effort estimates in the shipping table.** The least reliable numbers
  here. They are a shape, not a schedule.
