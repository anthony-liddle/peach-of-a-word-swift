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

---

# Part three: tile tapping

2026-08-09. The largest piece of SwiftUI work so far, and the first that is
genuinely new rather than a port of logic. The engine did not move: `validateGuess`
still takes a `String`. Everything that produces that string changed.

## The model, and the detail that matters

Read from `src/ui/Game.tsx` and `src/ui/useGame.ts`. The state shape is:

```
Tile { id, letter }        // id is an index into the sorted rack
tiles: [Tile]              // id to letter
rackOrder: [Int]           // ids in display order, all Shuffle touches
composing: [Int]           // ids placed, in placement order
composedWord = composing.map { tiles[$0].letter }.joined()
```

**Composition is a list of tile IDs, never letters.** This is what makes
duplicate letters work. Today's rack is `motorway`, which has two separate `o`
tiles; tapping one must consume that specific tile and leave the other
available. A letter-keyed model would consume both or lose track.

Ported as-is, not simplified. Two things fell out of it for free:

- **Shuffle cannot disturb a composition in progress.** `rackOrder` and
  `composing` refer to each other only by id, so reordering the display cannot
  touch what is on the stick. That correctness is structural rather than
  arranged.
- **The "already placed" test is the same derivation as the web.**
  `composing.contains(id)` per tile per render, which is O(8) and free.

Actions ported: `addTile`, `addLetter`, `removeLast`, `clear`, `shuffleRack`,
`submit`. The web version clears the stick on every submit outcome, valid or
not, and that is copied.

## 1. How does SwiftUI handle the tile state?

**The same derivation works unchanged. SwiftUI did not want it shaped
differently.**

`isPlaced(id)` is computed on every render exactly as React computes
`composing.includes(id)`. No memoisation, no explicit diffing, no dependency
declarations. `@Observable` tracks that the rack read `composing`, so tapping
one tile re-renders the rack and nothing else.

One genuine difference, and it is the SwiftUI analogue of React's `key`:

```swift
ForEach(model.rackOrder, id: \.self) { id in ... }
```

Identity has to be the tile id, not the array position. Using the position
would make Shuffle look like eight letters changing in place rather than eight
tiles moving. Same rule as React keys, same failure mode if you get it wrong.

The one thing I would change: `model.tiles.first(where: { $0.id == id })` is a
linear lookup inside a loop. At eight tiles it is irrelevant, and a dictionary
would be the right shape if the rack ever grew.

## 2. Did the `@Observable` class hold up?

**Yes, and it is still not a reducer.**

`GameModel` went from about 219 lines to about 300, absorbing six new actions.
Each action is one to three lines that mutate state directly. A reducer would
add an action enum plus a switch and buy nothing at this size.

**The honest limit, and it is the same one as before.** This still has one mode,
no persistence, and no undo. The web reducer exists partly because Daily and
Endless each hold their own slice and switching modes must not disturb the
other. That is the pressure that would actually justify the shape, and it is not
here yet. So the finding is "not required at this size", not "never required".

What did become visible: as the number of actions grew, the value of the actions
being *methods* rather than dispatched cases is that each one is individually
callable and testable. The launch-argument test hooks call `addTile` and
`addLetter` directly, which a reducer would make marginally more awkward.

## 3. How did layout feel compared to CSS?

**Better than expected, and it was the cheapest part of the work again.**

The rack is one line of intent:

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: 10)])
```

That is the direct equivalent of CSS `repeat(auto-fit, minmax(...))`, and it
does the same job with less ceremony. **At `accessibility-extra-large` the grid
reflowed from four columns to three by itself**, verified with
`simctl ui <device> content_size accessibility-extra-large`. That was free, and
it is the part of the web version's text-size work that did not need doing again.

Two places CSS was nicer:

- **`aspect-ratio: 3 / 4` has no clean equivalent** that cooperates with an
  adaptive grid. I used a scaled `minHeight` instead, which is close but not the
  same idea.
- **The hard offset shadow.** CSS writes `0 5px 0 <colour>` and means it.
  SwiftUI needs `.shadow(color:, radius: 0, x: 0, y: 5)`, where `radius: 0` is
  the non-obvious part; the default blur makes it look wrong immediately.

## 4. Did you open Xcode previews?

**No. This remains the single biggest unexamined part of the whole experiment.**

Everything here was built, installed and verified from the terminal, as in part
two. `#Preview` is present on `ContentView` and compiles as part of the build,
so it is at least valid, but the canvas was never opened and this report has
nothing to say about whether it helps.

That is now a conspicuous gap rather than an incidental one. Previews are
plausibly the main authoring loop for real SwiftUI work, and every estimate in
this report about how long a full rebuild would take is made without knowing
what that loop feels like.

## What was verified, and what was not

**Verified headlessly**, on the iOS 26.4 Simulator:

- `-tapWords motorway,root,tram,moray` composes each word through the tile path
  (letter to specific unused tile id) and submits. All four validated, score 28
  of 65, identical to the earlier typed run. **`motorway` and `root` each need
  two distinct `o` tiles, so duplicate handling is confirmed.**
- `-tapTiles 0,1,2,1` places rack positions 0, 1 and 2 and **correctly ignores
  the repeated 1**: three letters land on the stick, not four. Placed tiles
  render sunk (faded, no shadow) while the rest stand proud.
- Dynamic Type reflow, above.

**Not verified programmatically: an actual finger tap.** Driving the Simulator
with AppleScript failed with error `-25204` (accessibility permissions), the
same class of failure that blocked typing into the text field in part two. So
the tile *actions* are proven and the Button *gesture* is not. It needs a human
with the app in front of them, which is why the build went to the phone.

This is worth naming as a pattern rather than an incident: **across three
sessions, every attempt to drive iOS UI from the terminal has failed, and each
time the workaround was a launch argument.** Whatever else Xcode adds, it owns
UI interaction testing. A real project would reach for XCUITest here.

## Owed

- **Fonts.** The cute theme is Fredoka for display and Nunito for body. This
  uses the system font with `.rounded` design, which reads as the same family of
  shape and cost nothing. Bundling the real faces is a later pass, as the brief
  allowed.
- **The found list** is a plain scrolling column with no heading, no rarity
  colour, and no tap targets. Out of scope here and it shows.

---

# Part four: matching the web's cute theme

2026-08-09. A visual pass on the play surface only. No behaviour changes.

## What changed

All values read from `src/index.css` under `[data-theme='cute']` and expressed in
SwiftUI rather than ported as CSS.

- **Tiles** are now `aspect-ratio: 3 / 4`, 18pt radius, 1pt `--tile-edge` border,
  with a **hard peach slab** beneath. Glyphs are much larger (54pt base, Fredoka
  SemiBold, lowercase). Placed tiles sit at `opacity: 0.32` with no slab, which
  is the web's value.
- **Controls flipped**: the primary pair (Delete, then Pick word) is now on top,
  the utility pair (Shuffle, Clear) beneath. Pick word is about twice Delete's
  width.
- **Buttons** are uppercase with 0.14em tracking. Pick word is an accent fill
  when live and a **white pill with a rule border** when not, rather than the
  washed-out pink that read as broken.
- **The masthead** is three lines: pink tracked kicker, the wordmark with
  **"Peach" in pink oblique**, and the "Pick the peaches" subline between two
  hairline rules.
- **Fonts are bundled**: Fredoka and Nunito, both variable, from the Google Fonts
  repository under the OFL, with licences beside them in `App/Fonts`.
- **Fixed a real bug**: the placeholder rendered twice, once in the compose well
  and again in the message line. The message line is now the feedback slot only,
  blank when there is nothing to say, with its height reserved so feedback never
  shifts the layout.
- **The score line** kept the tier name: "First Sprout · 19 points". The glossary
  is out of scope, so it lives under the masthead for now. The name was kept
  rather than the line dropped because the rank name is the part that gets
  reacted to, where a bare point count is not.

## Three things SwiftUI would not do

**1. It will not synthesize an italic.** Fredoka has no italic face. A browser
fakes one by slanting the upright, which is how the web gets its pink italic
"Peach". Both `Text.italic()` and `Font.italic()` were tried and **neither
changed a single glyph**: with no italic face there is nothing to select, and
SwiftUI does not invent one.

The fix was to apply the shear by hand through CoreText, which is what the
browser is doing anyway:

```swift
var shear = CGAffineTransform(a: 1, b: 0, c: 0.18, d: 1, tx: 0, ty: 0)
let upright = CTFontCreateWithName("Fredoka-SemiBold" as CFString, scaled, nil)
return Font(CTFontCreateCopyWithAttributes(upright, scaled, &shear, nil))
```

The cost: a `CTFont`-backed `Font` has no `relativeTo:`, so Dynamic Type has to
be applied to the point size manually with `UIFontMetrics`, and the view needs to
read `dynamicTypeSize` so it recomputes.

**2. `.shadow()` always blurs.** CSS `box-shadow: 0 5px 0 <colour>` is a flat
slab with no blur and no spread. `radius: 0` gets close and still renders a soft
edge. The faithful version is an offset copy of the same shape drawn behind,
which is a two-line view modifier and looks exactly right.

**3. Bundled fonts need declaring twice.** Copying the files in is not enough;
without `UIAppFonts` in Info.plist they ship inside the app and are never
registered, and `Font.custom` silently falls back to the system face with no
warning. Also, variable fonts are looked up by the PostScript name of a **named
instance** ("Fredoka-SemiBold"), not by family plus weight.

## A regression I caused and caught

The first attempt sized each tile's glyph from a `GeometryReader`, to track the
web's viewport-relative `clamp(1.75rem, 16vw, 5rem)`.

**At `accessibility-extra-large` this broke badly**: glyphs overflowed their
tiles, tiles overlapped each other, and the masthead was pushed off the top of
the screen. A `GeometryReader` consumes all offered space rather than reporting
an intrinsic size, so the font was computed against a box the tile never
actually received.

Two fixes: size the glyph with `@ScaledMetric` (which tracks Dynamic Type without
depending on layout at all) plus `minimumScaleFactor` as a backstop, and wrap the
play surface in a `ScrollView`, since at accessibility sizes the rack alone is
taller than the screen.

Worth recording because the brief said explicitly not to regress this, and the
only reason it was caught is that the check was actually run rather than assumed.
Both text sizes were re-verified after the fix.

## Did you open Xcode previews?

**Yes. Answered at last, and the answer is that they work well.**

An earlier draft of this section said "attempted, partially, and still not
usefully answered". That was true when written and is now superseded. It is kept
below in outline because how it failed is itself the finding.

### What it took to get there

1. Option-Command-Return to toggle the canvas did nothing.
2. Menu automation **does** work where the keystroke appeared not to. Enumerated
   Xcode's Editor menu and clicked "Canvas" directly. The canvas opened.
3. It opened **paused**. Option-Command-P resumed it, and this time the keystroke
   did land, so the earlier failure was almost certainly the editor not having
   focus rather than keystrokes being blocked outright. The window also had to be
   enlarged first: at its original size every Editor menu item was disabled.
4. First render took roughly two to three minutes from resume.

### What the canvas actually does

It rendered the **whole real app**, not a static mock: the bundled Fredoka
wordmark, the tiles, the controls, and the rack showing today's actual
`motorway` letters. That means the preview ran the `@Observable` model, the
detached background task, and the ~200 ms read of five word lists out of the app
bundle. Nothing had to be stubbed for it.

### The loop, measured

The number that matters, measured rather than estimated:

| | |
|---|---|
| Edit to updated pixels, **preview canvas** | **about 3 seconds** |
| Edit to updated pixels, **build and run to simulator** | about 40 seconds |

The test: change `glyphSize` from 54 to 30, poll screenshots of the canvas
region, and compare hashes until it changed. Three seconds, and the render was
correct rather than an error state. The rack even reshuffled, so it re-ran the
whole app rather than patching a view.

**That is more than a tenfold difference, and the edit was made from outside
Xcode with `sed`.** The canvas picked up a file change from a completely
different process. Nothing about this loop requires editing inside Xcode, which
matters for an agent: the fast path is available without driving the editor.

### What this changes

The previous three sessions each estimated a full SwiftUI rebuild without knowing
this. Those estimates were made on a 40 second loop and should be read as
pessimistic on the visual work specifically. Layout and styling are exactly the
tasks a 3 second loop transforms, and they are the bulk of what remains.

It does not change the estimates for logic, which the terminal loop already
served well.

### The honest caveat

Getting here needed a human twice: once to grant screen recording so the canvas
could be seen at all, and the whole path depended on menu automation working
where it easily might not have. **An agent cannot currently discover this loop
unaided**, and on three prior sessions it did not. That is worth more than the
3 seconds as a finding about what working on a native project is actually like.

## Owed

- ~~**Xcode previews**~~ **Done.** Working, measured at about 3 seconds per
  iteration, and usable from outside Xcode.
- **The kicker wraps to two lines** at phone width. The web wraps here too, so
  this may be faithful rather than wrong, but it was not compared side by side
  against a real screenshot.
- **Nunito is bundled but barely used.** Most body text is Nunito Regular or
  SemiBold; the web's exact weight mapping per element was not matched.
- The found list is still a bare column: no rarity colour, no headings, no taps.

---

# Part five: persistence

2026-08-09. The first thing that makes the app usable rather than a demo.

## What the web version does, before writing anything

`src/persistence/storage.ts`, read first:

- **One key**, `eight-letters/v1`, holding **one JSON blob**. Shape:
  `{version: 1, days: {[dayIndex]: {sourceWord, found[]}}, streak: {count, lastClearedDayIndex}, endless}`.
- **Pruned to 14 days** on every write, so storage never grows without bound.
- **Reads fail safe.** A parse error or a version mismatch returns an empty
  state rather than throwing. Writes are wrapped too, so a mid-session quota
  failure loses the session's progress rather than crashing play.
- **A stored day is matched by source word, not just by index.**
  `loadDayProgress(dayIndex, sourceWord)` returns the words only if the stored
  `sourceWord` matches. If the calendar is regenerated and a date now serves a
  different puzzle, yesterday's finds are discarded rather than misattributed.
- **Writes are keyed on durable state.** The `useEffect` depends on `found`, not
  on `composing`, with the comment saying exactly why: it "keeps tile taps,
  backspace, clear, and shuffle off the synchronous disk-write path". That is
  the per-tap lag bug, already fixed there.
- **The endless guard** is `stored && data.sourceEntry(stored.sourceWord)`:
  rehydrate only a word the shipped data still knows, so the reveal cannot break.
  Endless is out of scope here, but the daily uses the same shape of guard.

## Decisions

### UserDefaults, not a file in Documents

The whole persisted blob is one JSON value holding at most fourteen days. A
generous day is about 50 found words averaging 8 characters, so roughly 600
bytes; fourteen of those plus a streak is **under 10 KB**. Even a year kept
unpruned would be a few hundred KB.

That is comfortably what `UserDefaults` is for, and it brings atomic writes, no
file coordination, no directory creation, and no partial-write window for free.
A file would be the right answer if the history were unbounded or large enough
to want streaming. Choosing it now would mean hand-writing crash-safe file
replacement for no benefit.

It is worth revisiting if found history is ever kept forever rather than pruned.

### The day does not roll over while the app is open

Matching the web, which builds its daily slice once and never regenerates.
Swapping the rack under someone's fingers at midnight, discarding whatever they
had part-composed, would be worse than showing yesterday's puzzle until they next
open the app.

**The subtlety that needed guarding:** the day index is captured once at load and
used for every save. It is deliberately *not* recomputed at write time. If
midnight passes mid-session, the board on screen is still yesterday's, and its
words must be saved under yesterday's key rather than leaking into today.

### Versioning

A `version` field is written and checked. A blob from a **newer** version starts
clean, because this build cannot know what it means and guessing would corrupt
it. A future incompatible format should take a **new key** rather than
overwriting this one, which is why the key is `peach-of-a-word/v1`.

The part that actually protects the streak is **lenient decoding**. Swift's
synthesised `Codable` is strict: one missing field throws, and a thrown decode
here means the whole blob is discarded, streak included. So `PersistedState` has
a hand-written `init(from:)` where every field is `decodeIfPresent` with a
default. Adding a field in a future version, or shipping one malformed key,
cannot now cost Bea her streak. There are tests for both.

### Seeding a played board: `-seedBoard`

Two specs, because they answer different questions:

- `-seedBoard almost` gives every set word but one, plus a third of each off-page
  rung. Verified: 71 words, top rank, list scrolls. This is the state the tier
  meter is most worth judging against.
- `-seedBoard 24` gives roughly that many words spread across the four bands in
  proportion to their sizes, so the rarity mix looks like real play rather than
  one colour repeated.

**Deterministic on purpose.** Bands are sorted and picks are strided, so two
screenshots of the same spec are comparable. Random picks would make every visual
diff noisy.

**It writes through `foundDidChange`**, the same path a real find takes, so
seeding exercises persistence rather than bypassing it. That makes it a live
check of the thing it sits next to, and means it cannot become a second way of
writing saved state that drifts from the first.

Previews do not receive launch arguments, so `ContentView` also takes a
`debugSeed` and an injectable store. There are now three previews: empty, mid
game, and near completion, all on in-memory storage so the canvas never touches
real saved progress.

## Verification

All three checks the brief asked for, plus one it did not.

| Check | Result |
|---|---|
| Find words, force-quit, relaunch | `found:4` before, `found:4` after |
| Same, **on the iPhone by hand** | Confirmed: words still there after a swipe-away |
| Only yesterday stored, launch today | `{"storageDay":220,"found":0,"streak":5}` |
| Eight tile taps | `saves:0` |
| One real find | `saves:1` |
| Three more finds | `saves:3`, streak 5 to 6 |

The later-date check was done by planting yesterday's state directly into the
app's preference plist rather than moving the clock, since `simctl` cannot set
the simulator's date. Today started empty and the streak survived, which is the
behaviour under test either way.

**The write count needed inventing.** The obvious probe, the plist modification
time, is useless: `cfprefsd` batches `UserDefaults` writes to disk, so the mtime
stayed flat even across runs that demonstrably persisted. Counting the calls at
the point they are made is what actually shows that taps do not write.

## Two things I got wrong on the way

**A grep-based check of the Release binary gave a false negative.** Searching for
`seedBoard` in the Release build returned zero, which looked like proof it had
been compiled out. But the same search also returned zero for `tapWords`, which
is not gated and demonstrably works. The behavioural test is the real evidence:
in a Release build `-tapWords` worked and `-seedBoard` did nothing.

**That exposed an inconsistency worth fixing.** The older `-guesses`,
`-tapWords` and `-tapTiles` hooks predate this work and were never gated at all,
so a shipping build carried three ways to inject found words. They are all now
inside `#if DEBUG` alongside the new one. Verified behaviourally: a Release build
passed both `-tapWords` and `-seedBoard` starts empty at "First Sprout, 0 points".

This is slightly beyond the brief, which only required the seeding to be
debug-only. It is flagged rather than folded in silently.

## Owed

- **Endless persistence**, when endless exists. The guard to copy is the web's
  `data.sourceEntry(stored.sourceWord)` check.
- **The streak is stored and read but never displayed.** The toolbar is out of
  scope, so nothing on screen shows it. It is exposed on the model and covered by
  tests.
- **No write-failure path.** The web wraps its write in a try/catch for quota
  errors. `UserDefaults.set` does not throw, so there is nothing to catch, but
  that also means a failure would be silent.

---

# Part six: the found list, the tier meter, and fitting the screen

2026-08-09.

## A screen, not a page

The framing that shaped the layout work, and it is the right one. A page may be
arrived at from anywhere, so it can afford a masthead announcing what it is. An
app is already open, already named on the home screen, already the thing that
was tapped. The kicker was not merely unnecessary, it was evidence of having
ported a page.

What changed:

- **The kicker is gone.**
- **The wordmark shrank** from 34pt to 22pt, keeping "Peach" in pink oblique
  because that is the identifying mark.
- **The tiles got shorter** by capping the rack at 310pt rather than letting it
  span the full width. They keep the 3:4 ratio, so narrower is the only way to
  make them shorter. That took roughly a fifth off the height.
- **The controls got bigger**: 56pt for the primary pair, 46pt for the utility
  pair, against a flat 44pt before. They are the most-used targets on the screen
  and were previously the smallest.

**The layout is now bottom-weighted**, which was offered as a proposal and is
worth taking. The controls are pinned to the bottom in comfortable thumb reach,
the found list takes the loose middle and scrolls, and the well and rack sit
above it. Pages are top-weighted because they are read; phones are
bottom-weighted because they are held.

The alternative tried first was the obvious one: keep the source order (well,
rack, controls, then list) and simply let the list scroll beneath. It works, but
it wastes the best real estate on the phone. Putting the list between the rack
and the controls costs nothing, because the list is the part being read rather
than acted on, and it buys both thumb reach and the room the bigger buttons
needed.

**The rack and controls now fit without scrolling**, with the list scrolling
between them.

At accessibility text sizes none of that fits, so the whole screen falls back to
a single scroll view. Both paths are verified, because this has been regressed
once already by assuming rather than checking.

## The tier meter

Everything is read off `TierStanding`. Nothing is recomputed.

The rank label in the display font with the bold points total on the same
baseline-aligned row, a 12pt rounded track with a 1px ink border, and beneath it
the percentage plus either the next rank or, at the top, "Top rank. The full set
is the peak."

**The two-tone fill is the part that matters** and it works: set points in the
on-page pink, off-page points in the discovery purple, as two segments of one
bar. On a realistic board it reads at a glance where the score came from, which
is the whole point of it.

**The streak now has a home.** It has been stored and read since persistence
landed but nothing displayed it, because the toolbar was scoped out. It sits at
the right of the percentage row as a flame and a count.

## The found list

Grouped by length, longest first, each group headed by the length and an "X of Y"
of the **set** words of that length. Off-page finds appear in the group and are
never counted in that denominator.

Chips rather than rows, wrapping in a flow layout. **SwiftUI has no wrapping
stack**, so this is the one piece of layout that had to be written by hand
rather than expressed: a `Layout` conformance, about 40 lines, against the web's
one line of `flex-wrap: wrap`. That is the largest single gap between the two
platforms found so far in the view layer.

Each word carries its mark and colour, and colour is never the only signal. The
cute theme marks by glyph, so these are hearts, stars, sparkles and gems rather
than the base theme's drawn squares and daggers, since cute is what v1 ships.
The source word gets a peach.

Off-page finds show their points inline. Set words do not: the group's "X of Y"
already accounts for them, and a number on every chip would bury the ones that
earned extra.

**The "also found" divider** appears only on groups carrying both, exactly as the
web has it.

**The summary line never puts a denominator on a rarity rung.** "15 of 27 words"
for completion, then bare tallies: "5 Uncommon, 3 Rare, 1 Mythic". Advertising
how many off-page words exist would turn open-ended discovery into a grind.

Words are real buttons with accessible labels and 44pt targets. The definition
reveal is out of scope, so a tap does nothing yet, and it can drop in later
without restructuring.

## Did you use the preview canvas?

**Yes, and then I stopped using it, for a reason worth recording.**

The canvas worked exactly as it did last session. All three previews (empty, mid
game, near completion) appeared as tabs, `debugSeed` populated the board without
launch arguments, and the re-render was the ~3 seconds measured before. For
laying out the screen it was clearly the right tool, and the first pass at the
new layout was judged in it.

**The problem was not the canvas, it was seeing it.** Reading it requires
capturing the desktop, and `screencapture` kept returning other windows despite
the frontmost check passing immediately beforehand. Twice it captured unrelated
applications rather than Xcode. I deleted those captures and stopped, because
grabbing whatever happens to be on someone's screen is not a reasonable way to
verify a layout, and no amount of retry logic makes it one.

So the second half of this work was verified with `simctl io screenshot`, which
only ever contains the app. That loop is about 40 seconds against the canvas's 3,
and the difference was felt: the seeding-realism fix and the truncation fix each
cost a full rebuild where the canvas would have shown them immediately.

**The honest summary for an agent doing visual work:** the canvas is the right
tool and is genuinely fast, but an agent cannot reliably *see* it, because the
only route is a desktop screenshot and that is neither targeted nor safe. A
human at the machine has the canvas for free. This is the sharpest version yet
of the pattern noted in parts three and four: **Xcode owns the interactive
surface**, and the gap is not capability but observation.

## Two things caught by looking

**The first seeding spread was unrealistic.** `-seedBoard 24` allocated words in
proportion to band size, and the rare band is enormous, so it produced a board
with four set words against twenty off-page. No player has ever had that board.
Reweighted to 62% set words with the remainder favouring uncommon over rare over
mythic, which gives 15 of 27 set plus a scattering of off-page: a board that
looks played.

That matters beyond the seeding. The two-tone bar looked broken on the first
board (a sliver of pink against a wall of purple) and looked right on the second.
The bar was fine; the fixture was lying.

**The tier caption truncated at accessibility sizes.** "Top rank. The full..."
with the sentence lost. Fixed by letting it wrap to two lines rather than
scaling and truncating. Caught only because the accessibility size was actually
checked rather than assumed, which is now three sessions running where that
check has found something.

## Owed

- **The definition reveal**, which the chips are already built for.
- **The per-length grid** showing uncracked lengths, and the expandable rarity
  panels. Both out of scope here.
- **A group with only off-page finds** reads "0 of 2" above chips with no
  divider, because the web's rule is "only when a group has both". Faithful, but
  the count and the chips beneath still describe different populations in that
  one case. Worth revisiting against real play.

---

# Part seven: layout and polish batch

2026-08-09. Punch list items 1, 2, 3, 4, 10 and 11.

## 1. Tiles at full width. The lever was a capped tile height.

The rack was previously capped at 310pt purely to make the tiles shorter,
because with a fixed 3:4 ratio narrowing was the only lever available.

**The lever used instead: the tile height is a scaled constant and the tile
fills its column.** Width comes back, height does not follow it.

The cost, stated plainly: the tiles are no longer exactly 3:4. At full width on
a 402pt phone a column is about 85pt, so a 102pt tile is roughly 5:6. The web's
are 79x105 on its narrower phone width, so this is a slightly squarer tile on a
larger screen. The brief allows that trade and it is the one worth making,
because the rack now reads as the same column as the compose well above it.

**One thing this broke, and it was only visible by looking.** Removing the width
cap let a fifth column fit, and the rack split 5 and 3. The adaptive minimum is
now 78pt, sized so exactly four columns fit at full phone width, and it still
reflows at accessibility sizes where the scaled minimum outgrows four.

## 2. Padding below the tiles

The uniform 12pt VStack gap was doing four different jobs. Replaced with
explicit per-element padding, which also made item 11 possible.

## 3. Chip row spacing

Two changes, because the gap was only half the problem.

The `FlowLayout` row gap went from 6pt to 2pt, matching the web's asymmetric
`gap: 0.3rem 0.75rem` (small row gap, larger column gap). But the bigger cause
was the **chip height**: at a 44pt minimum the box was more than twice the
height of its text, so rows sat far apart no matter how small the gap.

Chips are now 38pt. **That is a deliberate trade against the 44pt guideline**
and is flagged rather than buried: the chips are wide, the smallest dimension is
what the guideline is really about, and the row pitch closed by a quarter.

## 4. The delete glyph

It was a backspace character set in a body font, which renders far smaller than
the words beside it. It is now an SF Symbol at 26pt, sized as an icon. The web
makes `.btn--delete` a size larger than its siblings for the same reason; an
icon is that intent expressed the native way.

## 10. The scroll boundary. The fix was a fade.

Both options were available: start the scroll region below the rack, or fade the
content at the boundary.

**The fade wins, and the other option would not have worked.** The scroll region
already starts below the rack. The slicing was the ScrollView's own edge
clipping its content, not the rack overlapping it, so moving things would have
changed nothing. A fade is also the native treatment and it keeps the signal
that there is more above, which a hard edge with nothing cut off would lose.

**The first attempt was wrong in an instructive way.** A gradient sized as a
fraction of the scroll height dimmed the summary line while it was fully in
view, because at rest the first row sits inside the fade band. Fixed by padding
the scrolled content by 16pt and keeping the fade band smaller than that, so at
rest the fade falls entirely inside the padding and only bites once content
actually moves under it.

Verified in the scrolled state, not just at rest. `simctl` cannot perform a
gesture, so a debug-only `-scrollBottom` flag anchors the list to its bottom.
That is the only state the bug appears in and there was no other headless way to
see it.

## 11. Feedback has a permanent home

It now sits **directly under the compose well**, which is the thing it reports
on, and it never moves.

It previously sat between the rack and the list, immediately above the summary
line, so the two read as one slot alternating between a count and a message.
They are different things: the summary describes the board, the feedback
describes the last submission.

The web puts feedback below the controls. That was rejected here because this
layout is bottom-weighted: the controls are at the screen edge, so feedback
below them would sit against the home indicator, easy to miss and awkward to
reach visually. Under the well is where the eye already is when a word is
submitted. The slot reserves its height either way, so nothing shifts.

## On observation

**No desktop capture this session.** Every screenshot came from `simctl`, which
only ever contains the app.

The canvas was not used, which cost roughly six rebuild cycles at about 40
seconds each against 3 in the canvas. That is the honest price of the constraint
and it is worth stating rather than pretending the loops are equivalent.

**Where the canvas would have helped most**, if you want to point it at
something: the fade band. It took three passes to get right (too subtle, then
dimming content in view, then correct) and each pass was a full rebuild. It is
exactly the kind of continuous-value tuning a live canvas is for.

## Owed

- **A group with only off-page finds** still reads "0 of 2" above chips with no
  divider. Unchanged from last pass and still faithful to the web, but the count
  and the chips describe different populations in that one case.
- The 38pt chip height, if it turns out to be uncomfortable in hand.

## Regression: the rack split 3, 3, 2

Caught on the device, not in the simulator, and the diagnosis was right.

**Cause.** `.adaptive(minimum:)` asks "how many fit", and the minimum was a
`@ScaledMetric` value. Above the default text size that minimum inflates, so on
a 390pt phone a fourth column stopped fitting. It also had the inversion
backwards: the tile height was a fixed constant and the width was derived from
it, so each tile demanded a width the container could not supply four of.

**Fix, both halves.**

*Fixed columns, not adaptive.* The rack is always exactly eight tiles.
`.adaptive` is for collections of unknown size, and it negotiated wrong. It is
now `Array(repeating: GridItem(.flexible()), count: columnCount)` with
`columnCount` of four, or three at accessibility sizes. **4+4 and 3+3+2 are the
only two shapes this can produce**; 3, 3, 2 at normal sizes is unrepresentable.
The web makes the same choice deliberately: four on phone, eight on desktop,
never negotiated. Adaptive stays for the found-word chips, where the count
genuinely varies.

*Width drives, height follows.* The tile takes its width from the fixed column
and derives height through the 3:4 ratio. `maxTileHeight` is now an upper bound
only, and it is scaled so it does not clamp the tiles exactly when Dynamic Type
means them to grow.

The accessibility reflow to three columns is preserved and is now an **explicit
response to Dynamic Type** rather than an accident of available width.

**Verified** at three text sizes on a 402pt phone, and on a **375pt iPhone SE at
the largest non-accessibility size**, which is narrower than the iPhone 13 this
was reported on and is therefore the worst case. Four columns hold in all of
them. Also confirmed on device.

## Where the summary line lives

It is the first child of `FoundListView`, inside the scroll region, so it scrolls
with the list and belongs to it structurally.

**It reads as belonging, now.** On a board with one word it sits directly beneath
the rack with the length group under it and empty space below, which is right.

The "floating directly above the controls" was a **symptom of the 3, 3, 2
regression**, not a separate problem: a three-row rack squeezed the scroll region
into a thin band just above the controls, and the summary was the only thing in
it. With 4+4 restored the band is full height and the summary sits at the top of
it.

One honest caveat, not changed: because it scrolls, it leaves the screen as you
scroll down, while what it describes (the whole board) does not change. Pinning
it as a static header above the scroll region would make it a persistent status
line. That is a real option and a different design, so it is flagged rather than
taken.

## Found while verifying, not fixed

**On a 375pt phone at the largest non-accessibility text size, the found list is
squeezed to about 27pt**, which is effectively nothing. The rack and controls
fit, which is what was asked, but the list between them does not get usable room.

This is a property of the fixed "screen mode" layout rather than anything the
rack change introduced: the fallback to a single scrolling view triggers only at
accessibility sizes, and XXXL is not one. Lowering that threshold would fix it
but changes layout on every device at that size and needs its own verification
pass, so it is reported rather than folded into a rack fix.

Unlikely to bite on a 390pt iPhone 13 at normal text. Worth deciding on before
v1.

---

# Part eight: feel

2026-08-09. Punch list items 5, 6, 8 and the motion section, done together
because they are one question: what it feels like to play.

## The source-word celebration

Built first, because it is the beat the game is about and everything else here
is polish.

Finding the source word now shows a sheet: the peach, **"You found the Peach of
a Word!"** (the cute-theme line from web PR #76, the one Bea reacted to), the
word large, the kicker **"The peach every word grew from"**, the points, and a
Keep playing button. The feedback line under the compose well carries the same
message.

**A sheet, not an overlay.** Sheets drag to dismiss, which is what a phone
does; the web's full-screen overlay is a web pattern. It opens at a medium
detent so the board stays visible behind it, because on most days this fires in
the opening seconds: the source word is what gets cracked on sight, and play
continues straight after. It is a moment, not a gate.

**No definition is faked.** iOS ships none pending the WordNet decision, so
there is none on the card.

**It did read thin without one**, and this is worth being direct about: a
message, a word, a kicker and a number is not much for the game's biggest beat.
So the card now also says **"27 words grew from it"**. That is not filler: it is
`commonWords.count`, which the engine already computes, and it finishes the
sentence the kicker starts. If real reveal content ever lands, this line should
give way to it.

**Does not re-fire on relaunch.** The celebration is set in `resolve` only, so a
restored board does not re-celebrate a word found yesterday. Verified.

## The peach

**Ported as a path, not exported as an asset.** The transcription is from
`public/favicon-cute.svg`, which is generated from `PEACH_MARK_PATHS` and is the
same shape as the favicon, the OG card and the home-screen icons, so this is the
game's mark rather than a second peach that looks nearly right.

Path over asset because it is only eight primitives in a 100x100 box, so the
transcription was cheap, and vector stays crisp at both the 13pt chip mark and
the 96pt card without shipping raster sizes or adding an asset catalogue to a
generated project.

SVG is relative-cubic heavy and SwiftUI has no smooth-curve command, so each
`S` and `s` segment has its first control point written out as the reflection of
the previous one. That is the only fiddly part and it is commented in place.

The face is dropped below card size: it turns to mud at 13pt, and the silhouette
alone still reads as a peach. It appears in the found list, on the card, and on
the splash.

## Press feedback

**Tiles press down onto their slab.** The web does `translateY(3px)` while the
shadow collapses from `0 5px 0` to `0 1px 0`; here the slab shortens as the tile
descends onto it, so the two move together and the tile travels rather than
merely shifting. Implemented as a `ButtonStyle`, so the pressed state comes from
the button and no gesture handling is written.

The `--bounce` easing (`cubic-bezier(0.34, 1.56, 0.64, 1)`) is ported as intent
rather than as values: a SwiftUI spring is the direct equivalent and a better
tool for an overshoot.

**Haptics, as a gradient rather than as a list of generators:**

| Event | Feel |
|---|---|
| Tile press | Light impact. The most frequent tap in the app, so the lightest. |
| Valid find | Success notification. |
| Rejection | Rigid impact at 0.55 intensity. |
| Source word | Heavy impact, then a medium one 120 ms later. |

Two deliberate choices. **The rejection is softer than the find, not harsher**:
a wrong guess in a word game is ordinary, not a failure worth punishing, and
`.warning` was tried and felt like being told off. **The source word is a double
beat** rather than a `.success`, because `.success` is what an ordinary find
already gets and the hierarchy has to be felt without a screenshot to explain
it.

**Reduce Motion suppresses animation and keeps haptics.** They are separate
accommodations: someone who finds motion nauseating still wants to feel the tap.

## Taken and skipped from the stretch list

**Taken:** the tier bar now fills rather than jumping, via a settle spring on the
score.

**Skipped, both because they fought:**

- **The tile travelling from rack to well** via `matchedGeometryEffect`. The
  effect needs matched identities on both sides, but a placed tile is not
  removed from the rack, it is disabled in place and dimmed. Making it travel
  means restructuring the rack so a placed tile genuinely leaves, which changes
  the id-based composition model the whole thing rests on. Not worth it for
  motion.
- **A settle on the chip joining the list.** The chips live in a hand-written
  `Layout`, which has no insertion transition of its own, and the list rebuilds
  wholesale on each find. Doable, but it is a rewrite of the layout rather than
  an animation.

Both are real wins if revisited deliberately. Neither is a five-minute add,
which is what the brief allowed for.

## Two clarity fixes

**The streak** said "flame, 6" and nothing said streak. It now says "6 days"
next to the flame.

**The splash** said "Loading the dictionary". It now carries the peach and the
kicker, "A game about finding words in words", which is where that line belongs
now it is off the play screen, and it is where the load hides anyway.

## Verification

Dynamic Type on the card **found a real problem**, which is now three passes
running. At the largest accessibility size both the celebration line and the
kicker truncated to one line with an ellipsis, because a sheet detent is a fixed
height and the stack compressed into it. **Truncating the one line Bea reacted
to is the worst possible outcome for this card.** Fixed by making the card
scrollable, offering a large detent as well as medium, and giving the wrapping
text `fixedSize` so it claims the height it needs.

Also verified: the celebration end to end, no re-fire on relaunch, the peach at
mark and card size, and Reduce Motion.

**Not verified by me: the haptics.** The simulator has none, and there is no way
to feel a spring through a screenshot. The gradient above is a designed
intention, not a measured result, and it is the one part of this pass that needs
a hand on the phone.

## Chip rhythm: sized from text, target from hit area

The 38pt chip was the cause, not the gap. It gave roughly 30pt of box around
20pt of text, so wrapped rows read as separate lines however small the gap got.

Chips are now **24pt of layout height**, matching the web's `min-height: 24px`,
with a 5pt row gap, matching its `0.3rem`. The tap target comes from hit-area
expansion instead: pad the frame, claim the padded bounds with `contentShape`,
then collapse the layout back with negative padding. The touch region is about
44pt; the row costs 24.

**The justification is in the code, not just here**, so it does not later read
as a quietly lowered standard. 44pt is Apple's figure for standalone controls.
WCAG 2.5.8 sets 24 by 24 and carves out an explicit exception for inline targets
constrained by the line height of surrounding text, which is exactly what these
are: words in a flowing paragraph, not buttons in a row.

## Replaying the celebration

Two debug flags, both `#if DEBUG` with the rest.

- `-resetProgress 1` wipes today's saved words so the board starts empty and the
  source word can be found for real.
- `-replaySource 1` clears the day and then plays the source word **through the
  ordinary path**: composed tile by tile and submitted. The haptic, the feedback
  line, the card and the save all happen exactly as in play, rather than the
  card being poked directly into view. That matters, because what needs testing
  is the beat, not the sheet.

## The source-word haptic: a crescendo

The heavy-then-medium pair did read as two taps. It is now a CoreHaptics
pattern: a continuous rumble whose intensity curve climbs for about a third of a
second, deliberately slow at first and steepening, resolving into a single sharp
transient at the peak. One gesture that builds.

**CoreHaptics was not a session sink**, so it did not need approximating: about
70 lines including the engine lifecycle. Worth knowing for next time: the engine
gets stopped by the system on interruption (a call, backgrounding), so it needs
a reset handler and a restart on each play, or it silently dies after the first
phone call. It falls back to the old two-beat pattern where CoreHaptics is
unavailable, which is every simulator and any device without a Taptic Engine.

**No confetti**, and the hierarchy is the reason rather than the effort:
completion is far rarer and is the actual peak, while the source word is usually
cracked in the opening seconds. Spending the biggest visual gesture on the
common event would leave nothing for the rare one. So the escalation is felt and
not seen, which is what the crescendo is for.

**On the governing accommodation.** Correct that Reduce Motion is not it. There
is no public API to read the system haptics setting, and there does not need to
be: both `UIFeedbackGenerator` and `CHHapticEngine` are silenced by the system
when it is off. Honouring it requires nothing except not trying to work around
it. Reduce Motion continues to suppress animation only.

## What I still cannot verify

Two things, both needing a hand on the phone:

- **The crescendo.** No simulator has haptics, and the fallback path is what
  runs there, so nothing about the pattern has been felt.
- **The expanded chip target.** The `contentShape` plus negative padding trick
  is standard, and the layout is visibly correct, but whether a 24pt chip with a
  44pt hit region is comfortable to tap is a finger question.

---

# Part nine: the peak, and a haptic that was quietly a quarter strength

2026-08-09. Punch list item 13, plus two fixes.

## The completion celebration

The rarest thing in the game was the least marked thing in it. Now:

- **The crown card**: the crowned peach, "Peachy Keen Supreme" (the cute skin of
  the web's `CROWN_NAMES`), and "Every common word the rack can spell, found."
- **Confetti**: peaches, hearts, stars and sparkles in the cute palette, the
  same vocabulary the rarity marks use. **This is the only place it appears**,
  which is the hierarchy holding: completion is rare and gets the biggest visual
  gesture, the source word is common and escalates by feel instead.
- **The biggest haptic in the app.**

**It does not end anything.** The off-page ladder is still open, the board stays
live behind the sheet, and the button says "Keep playing" rather than "Done".
Verified: no re-fire on relaunch, and dismissing returns to a playable board.

**Where both moments can land on one submit** (finding the source word last,
which also completes the set), **completion wins and the peach card is dropped
rather than queued.** Two sheets in a row would turn the biggest moment in the
game into paperwork.

## The haptic was a quarter strength, and that was a bug

"It reads as slightly more than a letter tap" was exactly right, and the cause
was not taste.

`hapticIntensityControl` is a **multiplier on the event's base intensity**, not
an absolute value. The base was set to 0.25 and the curve climbed to 1.0, so the
effective peak was 0.25 x 1.0. The crescendo really did top out barely above a
tile tap. The base is now 1.0 and the curve does the shaping.

Worth recording as a class of mistake: the code looked like it ramped to full
intensity, the parameter names read as if it did, and nothing failed. Only
feeling it on hardware surfaced it, which is the second time this project has
found a bug that no test could have caught.

**The four levels**, each unmistakably above the one below:

| Level | Feel |
|---|---|
| Tile tap | Light impact at 0.45 |
| Ordinary find | Success notification |
| Source word | CoreHaptics: 0.5 s crescendo, 0.08 to 1.0, one sharp hit at the top |
| Completion | CoreHaptics: 0.78 s build, then three accelerating hits and a final harder one, 1.1 s total |

Completion is made larger than the source word by **duration and event count
rather than by raw intensity**, because the source word is already a
full-intensity crescendo and there is nowhere above 1.0 to go.

## Two fixes

**The tier caption wrapped and pushed the layout down mid-play.** Both fixes
applied, as asked: the top-rank string is now just "Top rank" (the completion
card explains the peak properly, so that sentence does not need to live in the
caption permanently), and the row has a **reserved single-line height**, scaled
with Dynamic Type but fixed at any given size. Shortening fixed today's string;
the reserved height fixes the class, so no future wording can move the board
under a thumb.

**"toy, 1 points".** Fixed, and the class closed with it. Six strings were each
pluralising by hand and only some remembered. Every counted noun now goes
through one `counted(_:_:)` helper, **including the ones that cannot currently be
one**, because "cannot currently be one" is the assumption that rots. There are
no hand-rolled plurals left in the app.

## A bug in my own confetti, found by looking

The first version never appeared. `pieces` and `falling = true` were set in the
same `onAppear`, so the views were created already in their final state: there
was nothing to animate from, and forty-two pieces sat off the bottom of the
screen from the first frame. Setting `falling` one runloop tick later fixes it.

Confetti is confined to the sheet's bounds rather than the whole screen, because
sheet content clips. At a medium detent that is still most of the lower screen
and it reads clearly. Moving it above the sheet would mean not using a sheet.

## Testing the hierarchy

`-seedBoard hierarchy` seeds every set word except the source word and one
other, so a single session reaches both remaining beats: find the source word
for level three, then the last set word for level four, with tile taps and
ordinary finds on the way.

The phone currently has a **Debug** build so the flags work. The dictionary load
is roughly 4x slower than Release, so the splash lingers; say the word and the
Release build goes back.

## What I still cannot verify

The haptics, again. The simulator has none, so the four-level gradient remains a
designed intention. The difference this time is that one specific bug in it has
been found and fixed, so the thing being judged is a pattern that actually
reaches full intensity rather than one that never did.
