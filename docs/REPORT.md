# The Swift engine experiment: report

2026-08-09. Written from `docs/PORT-LOG.md` and `docs/MEASUREMENTS.md`.

## What was actually done

The pure engine of Peach of a Word, ported from TypeScript to Swift, tests
first. 32 Swift files — 16 in `Sources/PeachEngine`, 1 benchmark, 15 test files
— carrying 84 tests in 18 suites, all passing. Package builds and tests clean on
Swift 6.3.3 / macOS 26.

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

> **Superseded, and deliberately not deleted.** The inline version was later
> dropped so the deployment floor could fall from iOS 26 to iOS 17, since
> `InlineArray` was the only thing gating it. The measurement above is still
> true and is still the most interesting result in the port; it is simply no
> longer what ships. See "The deployment floor: decided, and taken" below.

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
| TestFlight internal testing | Low, **with a caveat** | Up to 100 internal testers, and internal testing does **not** require Beta App Review. But internal testers **must be members of your App Store Connect team**, holding an Account Holder, Admin, App Manager, Developer, or Marketing role. So this is adding Bea as a team member, not sending her a link. |
| TestFlight external testing | Moderate | Up to 10,000 testers, invited by email or public link, and **no team membership required**. But builds **are** sent for Beta App Review, and an internal group must exist first. |
| Ad hoc distribution | Fiddly | Included in the $99 membership. Needs her device's UDID registered up front, and hands a non-technical recipient an `.ipa` to install. No review, but the worst experience of the three. |

**Correction to an earlier draft of this report.** It claimed internal TestFlight
meant "no Apple review stands between a working build and her phone" and left it
there. True about the review, incomplete about the setup: internal testing
requires making Bea an App Store Connect user. That is a modest step — she needs
an Apple Account and accepts an invite — but it is worth knowing that an App
Store Connect role grants real access to the developer account. **Marketing** is
the most limited role that can still be an internal tester, and is the one to
use if the point is simply "let her play the game".

**So the near bar is: $99, an App Store Connect record, adding Bea to the team
in a limited role, and a build that runs.** No App Review, no public listing, no
privacy policy. Still a genuinely low bar — just one step longer than stated
before.

Sources: [Apple Developer Program comparison](https://developer.apple.com/support/compare-memberships/) ·
[TestFlight](https://developer.apple.com/testflight/) ·
[Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/) ·
[Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

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
- **On-device performance.** Was true when written. A later session measured
  an iPhone 13: 362 ms warm, 403 ms cold. Still one device, one generation.
- **SwiftUI.** Entirely untouched.
- **The CC BY-SA position.** Flagged as uncertain, not resolved.
- **The effort estimates in the shipping table.** The least reliable numbers
  here. They are a shape, not a schedule.

---

# Part two: the smallest possible SwiftUI app

2026-08-09, same day. Written after the engine report above, whose verdict asked
for exactly this.

Note on style: this section avoids em dashes, per the build prompt. The engine
sections above predate that instruction and were left as they were, since
retrofitting them was not asked for and would have eaten the timebox.

## What was built

An iOS app target in this repo, depending on the existing `PeachEngine`
library. It launches, loads today's daily from the shipped calendar, shows the
eight rack letters, accepts typed guesses through `validateGuess`, lists found
words newest first, and shows score and rank from `computeTier`.

Verified end to end in the iOS 26.4 Simulator on an iPhone 17 Pro. Today's rack
is `AMOORTWY`, which is **motorway**, day 47 of the calendar. Seven guesses
submitted through a launch argument produced exactly the right outcomes:
`motorway`, `tram`, `root` and `moray` accepted, `zzz` rejected as not a word,
`ay` rejected as too short, and a repeated `motorway` rejected as already found.
`moray` was graded **uncommon** at 6 points, which is 5 for length plus the
1 point rarity bonus. Score 28 of 65, rank 3 of 5.

Three files, 358 lines of app code: `GameModel.swift` at 219, `ContentView.swift`
at 124, `PeachMinimalApp.swift` at 15. The built app bundle is 8.4 MB, almost
all of it the word lists.

Kept out, as specified: theming, audio, animation, persistence, endless mode,
sharing, the reveal, definitions, the rarity ladder display, completion,
widgets, icons.

## 1. What does state management look like?

**The reducer did not survive, and did not need to.**

`useGame.ts` is roughly 600 lines. The SwiftUI equivalent is a 219 line
`@Observable final class GameModel` holding three pieces of state (`phase`,
`puzzle`, `found`), one bound text property, and a `submit()` method. There is
no action type, no dispatch, no switch over action kinds, and no reducer
function.

The reason is not that SwiftUI is more powerful. It is that most of what a React
reducer exists to do is unnecessary here:

- **Nothing needs to serialise state transitions into values.** React reducers
  exist partly because you cannot mutate state in place. `@Observable` lets you
  write `found.insert(word, at: 0)` and the view updates. The action type was
  scaffolding for an immutability constraint that Swift does not impose.
- **Dependency tracking is automatic.** `@Observable` tracks which properties a
  view actually read and re-renders only for those. There is no dependency array
  to declare and therefore no dependency array to get wrong.
- **Derived state stays derived.** `standing` is a computed property calling
  `computeTier` on every access. In the web version the equivalent had to be
  memoised or recomputed deliberately, and the engine report documents two
  places where a second copy of a derived fact drifted from the first. Here the
  cheapest thing to write is also the correct thing.

**The honest caveat.** This app has three pieces of state. `useGame.ts` has
persistence, two themes, endless mode, a share, a completion celebration, a
streak, and dev preview hooks. A reducer earns its keep at that size in a way it
cannot at this one, so this finding is real but small: it says the reducer shape
is not *required* by SwiftUI, not that it would be wrong at full scale.

What I would say with more confidence: the parts of `useGame.ts` that are
*bookkeeping about React* would disappear, and the parts that are *game rules*
are already in `PeachEngine` and would not need writing at all.

## 2. How does the engine package feel to consume from a UI?

**Mostly very well, with one real gap that the engine port created and this
found.**

What held up:

- **`Sendable` paid off in the place it was designed for.** The dictionary load
  runs on a detached background task and returns a `Puzzle` across the actor
  boundary to the main actor. That compiles only because `Puzzle` is `Sendable`,
  which was declared months before there was a UI. Swift 6 would have rejected
  it otherwise.
- **`GuessResult` as an enum with associated values is exactly right at the UI
  boundary.** `submit()` is a four case exhaustive switch that produces feedback.
  Adding a case to the engine would fail to compile here rather than silently
  falling through to a default.
- **The protocol boundary meant no adapter layer.** `ListDictionary` and
  `ListWordSource` were built for tests and worked unchanged in the app.
- **Injecting `TimeZone` into `dayIndex` was vindicated.** The app passes
  `.current`, which is the app's decision to make. Had the engine reached for
  `Calendar.current` internally, this would have been invisible rather than
  chosen.

**The gap: `readWordList` did not survive contact with an app bundle.**

The engine locates its data through `dataDirectory`, derived from `#filePath`,
which bakes in the absolute path of the repo on the machine that compiled it.
That is correct for tests and the benchmark, which run from the source tree. It
is wrong for an app, which has no repo.

**And it fails in the worst possible way.** The iOS Simulator shares the Mac
filesystem, so the baked path still resolves there. A naive app would have
worked perfectly in the simulator and failed on the first real device. The fix
was one default argument (`readWordList(_:in:)` defaulting to the old
behaviour), so all 84 engine tests pass untouched and the app passes
`Bundle.main.resourceURL`.

This is worth stating plainly because the engine report claimed the package was
"designed for this, with protocols at the boundary". That was true of the *word
sources* and false of the *data loading*, and only building an app surfaced the
difference.

**One more change the engine port did not anticipate:** the package declared
`platforms: [.macOS(.v26)]` only, so no iOS target could depend on it at all.

## 3. Where did the time actually go?

About two and a quarter hours, inside the half day budget.

| | |
|---|---|
| Project setup: discovering the tooling gap, XcodeGen, the two package changes | ~35 min |
| Writing the model and the views | ~40 min |
| Verifying it actually works, headlessly | ~25 min |
| Measurement, including finding a bug in my own timing code | ~30 min |
| Writing this section | ~25 min |

**Layout was not the cost.** This is the finding I least expected. SwiftUI
layout for a rack, a text field, a feedback line and a list took well under half
an hour and needed no iteration. `VStack`, `HStack`, `List`, and default system
styling produced something legible on the first build.

**The cost was tooling and verification**, which is to say the parts that are
not SwiftUI at all. Roughly an hour of the two and a quarter went to getting an
app target to exist and to proving it worked without a human touching the
screen.

That said, the layout here is trivial. A rack of eight tappable letter tiles
with selection state, a progress bar, and a themed word grid would be real work,
and nothing here tested it.

## 4. What did Xcode add?

**The single most surprising finding of this session: you cannot create an iOS
app target from the terminal with stock tooling.**

SwiftPM builds libraries, executables and test targets. It cannot produce an app
bundle. There is no `xcodebuild -create-project`. So an app means an
`.xcodeproj`, and producing one without opening Xcode means either hand-writing
the pbxproj format or generating it. I installed XcodeGen (`brew install
xcodegen`), wrote a 52 line `project.yml`, and committed both that and the
generated project so the repo opens without the tool.

This is a real fact about what working on a native project looks like. The
engine half of this experiment ran entirely from a terminal with `swift test`.
The app half needed a third party code generator on day one to avoid a GUI.

**What was better than expected:**

- The build, install, launch and screenshot loop is fully scriptable and fast.
  `xcodebuild build`, `simctl install`, `simctl launch`, `simctl io screenshot`.
  It worked first try and never broke.
- The simulator is genuinely quick to boot and reliable.
- Release and Debug configurations are one flag apart, which made the 3.8x
  performance gap easy to measure.

**What was worse:**

- **There is no supported way to type into a SwiftUI text field from the command
  line.** `simctl` has no keyboard input. Driving the Simulator through
  AppleScript required the field to be focused first and silently did nothing. I
  added a `-guesses word1,word2` launch argument, read via `UserDefaults`, which
  is a standard trick but is still test-only code in the app to work around a
  tooling gap.
- `simctl launch --console-pty` did not reliably capture `print`. I ended up
  writing the measurement to a file in the app container and reading it with
  `simctl get_app_container`.
- **Previews were not evaluated at all.** `#Preview` is in the code and is
  presumably the main authoring loop for real SwiftUI work, but it requires the
  Xcode GUI. Everything above was done headlessly, so this report has nothing to
  say about what is probably the most important part of the SwiftUI experience.
  That is a genuine hole.

## 5. The dictionary load, on a phone

**Answered, after the fact.** This section originally said "not answered", and
the simulator numbers below stand as written. A later session ran the app on
Anthony's iPhone 13 over USB, so there is now a real device figure.

| | iPhone 13 (A15, 2021) | iOS 26.4 Simulator (M3 Pro) |
|---|---|---|
| Warm | **362 ms** | 300 ms |
| Cold, fresh install | **403 ms** | 300 ms |

Warm is the median of five runs with a tight spread. **The phone is about 1.2x
the simulator, not the 1.5x to 2x guessed below.** Cold and warm genuinely
differ on device by about 40 ms, which the simulator did not show and which this
report explicitly flagged as unsettled. Both corrections are small and neither
changes the conclusion: **ship the plain word lists.** Full detail in
`docs/MEASUREMENTS.md`.

The original text follows, because the reasoning about why a simulator number is
not a device number was correct and is worth keeping.

---

**Not answered. What was measured is a simulator number, and a simulator number
is a Mac number wearing iOS frameworks.**

The iOS Simulator runs native arm64 on the host CPU. It does not model a phone's
processor, storage, memory pressure, or thermal behaviour. These figures are
useful for the Debug versus Release comparison and useless as a device estimate.

Measured in the iOS 26.4 Simulator on an iPhone 17 Pro, timing the whole of
`buildTodaysPuzzle` (five word lists, the validation `Set`, the calendar JSON,
and `createPuzzle`):

| Build | Cold, fresh install | Warm |
|---|---|---|
| **Release** | 262 ms | 258, 266, 260 ms |
| **Debug** | 996 ms | 975, 985, 989 ms |

**Release is what matters: about 260 ms.** For comparison, the Mac release
benchmark measured 186 ms for the lists and Set, plus 44 ms for `createPuzzle`,
so roughly 230 ms of equivalent work. The simulator figure is about 13% higher,
which is consistent with it being the same CPU doing the same work.

Two things worth carrying forward:

- **Debug is 3.8x slower than Release here.** Consistent with the engine
  report's finding, and another reminder that a number taken from a debug build
  is not a number.
- **Cold and warm were indistinguishable.** The engine report flagged that its
  measurements had a warm file cache and that "a genuine first launch after
  install will be slower". On this evidence, in the simulator, it is not. That
  does not settle the question on a device, where storage is genuinely different
  hardware.

The load runs on a detached background task, so the UI shows a spinner rather
than blocking. At 260 ms that spinner is barely perceptible.

**An anomaly I could not explain, recorded rather than smoothed over.** The very
first launch reported 79 ms in a Debug build. Every subsequent Debug run,
including deliberately cold ones after uninstall and reinstall, reported 975 to
996 ms. I could not reproduce the 79 ms figure and have no mechanism to offer.
It is not the timing bug described below, since that only affected durations of
a second or more. Treat the table above as the reliable data and the 79 ms as
unexplained.

**A bug in my own measurement, found by disbelief.** My first timing code scaled
the whole seconds and sub second components of a `Duration` inconsistently, so
any duration of a second or more was silently underreported. I noticed because a
set of numbers looked implausibly flat, not because a test caught it. It is
fixed, and the values in the table were re-measured afterwards. Worth recording
because it is the second time in this project that a measurement, rather than
the code being measured, was the thing that was wrong.

## The deployment floor: decided, and taken

The engine report called the macOS 26 platform floor "defensible for an
experiment, plainly disproportionate as a deployment constraint" and left it
there. Adding an iOS target made it concrete and testable, so I tested it, and
then took the change.

`InlineArray` was the **only** thing gating the floor. `LetterCounts` is now
backed by a plain `[Int8]`, `Package.swift` declares
`.macOS(.v14), .iOS(.v17)`, and `swift-tools-version` dropped from 6.2 to 6.0.
All 84 tests pass. The app was installed and run on an **iOS 17.5** simulator,
so the floor drop is verified rather than assumed.

| | Before | After |
|---|---|---|
| Platform floor | macOS 26 / iOS 26 | **macOS 14 / iOS 17** |
| One formability pass | 16.7 ms | 44.4 ms |
| `createPuzzle` | 44 ms | 94 ms |
| App cold start, iOS 26.4 Simulator, Release | 260 ms | **300 ms** |

**One correction to the earlier estimate, and it matters.** This report and the
brief that followed it both quoted the cost as "25 ms on a once-per-puzzle
operation", taken from the single-pass delta. The measured cost is larger:
`createPuzzle` makes four passes over the word lists, so it pays the penalty
about 1.75 times over. The real figures are **+50 ms on `createPuzzle`** and
**+40 ms on app cold start**.

The trade still holds comfortably. 40 ms behind a loading indicator, once per
puzzle, against nine years of device support. But the number that was used to
justify the decision was too low by half, and it was too low because a
single-pass benchmark was quietly treated as if it described a four-pass
operation. Recorded because it is the same failure shape this project keeps
finding: a measurement that is true in the place it was taken and misleading in
the place it is quoted.

**The 2.5x finding stands and is kept** in `docs/MEASUREMENTS.md`. Swift's
default value type was the fast option and the literal translation of the
TypeScript `Int8Array(26)` was the slow one. That is still the most interesting
result in the port. It was given up because a deployment floor is worth more
than 40 ms, not because it was wrong.

**On collapsing the two implementations.** The library previously carried
`letterCountsArray` and `canFormArray` alongside `LetterCounts`, purely so the
two representations could be measured against each other. With `LetterCounts`
now `[Int8]`-backed, keeping them would mean shipping two identical
implementations of one fact with nothing forcing them to agree, which is the
exact bug shape this project has found five times in the web repo. They are
deleted. The agreement test survives: a naive reference implementation moved
into `FormabilityTests.swift`, where being a duplicate is the point rather than
a liability. Test count is unchanged at 84.

## Accessibility, for free and not for free

Recorded because the brief asked what SwiftUI gives without effort.

**Free:** every control is a real accessibility element. The text field, the
Submit button, the list rows and the navigation title are all reachable by
VoiceOver with sensible labels and traits, with no code. Dynamic Type works,
because the text uses semantic styles (`.title2`, `.subheadline`, `.callout`)
rather than fixed sizes. Increased contrast and bold text follow the system.
This is a genuinely large amount of behaviour for nothing.

**Not free:** the rack read as eight unrelated letters, because it is eight
separate `Text` views. One modifier fixed it:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Rack letters: \(model.rackLetters.joined(separator: ", "))")
```

That is the only accessibility code in the app. The pattern seems to be that
SwiftUI gets controls right automatically and gets *groupings* wrong until you
tell it what a group means.

## Verdict: ordinary work, or a wall?

**Ordinary work. Clearly.** Nothing in this session looked like a research
problem or a fight with the framework.

The evidence for that:

- The layout, which I expected to be the expensive part, was the cheapest.
- The state model came out at a third the size of the web version's, without
  needing a reducer.
- The engine package dropped in with one small change, and the one problem it
  did have (`#filePath`) was found immediately and fixed in one line.
- Nothing needed a second attempt except my own measurement code.

**What this does not license.** This app has three pieces of state and no visual
design. A full rebuild means tappable rack tiles with selection, a two colour
progress bar, two complete themes, animation, confetti, audio, persistence,
endless mode, a share card, and a completion celebration. That is a lot of work
and some of it (theming and animation especially) is the kind that expands to
fill available time. "Ordinary" means predictable, not small.

**The honest shape of the estimate**, and it is a shape rather than a schedule:
the game rules are done and tested. The state layer looks like a day, not a week.
The view layer is where the real time goes, and I would guess several focused
sessions to something playable and more beyond that to something that looks as
considered as the web version does.

**Two things to fix before any of that**, both cheap and both found here:

1. ~~Drop `InlineArray` and lower the platform floor to iOS 17.~~ **Done.** It
   cost 40 ms on app cold start rather than the 25 ms estimated here, and the
   app now builds and runs on an iOS 17.5 simulator. See "The deployment floor:
   decided, and taken" below.
2. Move the word lists into the package properly, or at least make the
   bundle-relative path the default rather than the `#filePath` one. The current
   default is a trap that passes in the simulator and fails on a device.

**And one gap in this report worth naming**: everything here was done headlessly
from a terminal. Xcode previews, which are probably the central authoring
experience for SwiftUI, were never opened. If SwiftUI has a frustrating side, the
preview loop is the most likely place for it to live, and this session did not
look there.
