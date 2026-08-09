# Port log

Feeds `docs/REPORT.md`. Record honestly, including the parts that go badly —
the friction is half the answer.

Two kinds of row, and they are **not** the same kind of evidence. The writer's
column is the implementing agent reporting on itself. The reader's column is
Antoine reporting on reading the diff. "Was Swift awkward for the agent" is a
fact about the agent; "was Swift legible to Antoine" is a different fact.

**The experiment's question changed after Task 2**, from "can I write Swift" to
"could I ship a native app". The reader's column was the centre of the original
question and is largely empty for the second — deliberately. See the note above
that column, and the appendix of `REPORT.md`.

## Reading list

When a task introduces a Swift concept with no TypeScript equivalent, it gets a
link here — the Swift book, the API reference, or the evolution proposal,
whichever actually explains it, not whichever is nearest. Inline comments say
what the code does; these say where to go to understand why the language works
that way.

Complete as of Task 16: the three tables below cover every Swift concept the
port used that has no TypeScript equivalent, and stand on their own as a reading
list. Every link was checked for a 200 before it went in.

### Task 1

| Concept | Why it has no TypeScript analogue | Link |
|---|---|---|
| `#filePath` | A compile-time magic literal. TS's `import.meta.url` is resolved at runtime by the module loader; this is substituted by the compiler into the binary. | [Swift book: Literal Expression](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Literal-Expression) · [SE-0274](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0274-magic-file.md) (why `#filePath` and `#file` differ) |
| `InlineArray<26, Int8>` | A fixed-size array stored *in* the struct rather than behind a heap pointer. TS has no stack/heap distinction to expose. Used in Task 3. | [SE-0453: InlineArray, a fixed-size array](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md) · [API reference](https://developer.apple.com/documentation/swift/inlinearray) |
| Availability gating | `InlineArray` is macOS 26+, which is what forces this package's platform floor. TS has no notion of an API existing only on some deployment targets. | [Swift book: `@available`](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#available) |
| `mutating func` | Marks a method that changes a value type. TS objects are all references, so there is nothing to mark. Load-bearing in Tasks 10 and 14. | [Swift book: Modifying Value Types from Within Instance Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/#Modifying-Value-Types-from-Within-Instance-Methods) · [Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/) |
| Swift Testing | Not XCTest. `@Test`, `@Suite`, `#expect`, and `arguments:` for parameterised cases. | [Swift Testing documentation](https://developer.apple.com/documentation/testing) |

### Task 2

| Concept | Why it has no TypeScript analogue | Link |
|---|---|---|
| `enum Rung: String` | TS models this as a string union (`'set' \| 'uncommon' \| ...`), which is structural — any matching string literal is one. A Swift enum is a distinct nominal type, and a `switch` over it is checked for exhaustiveness. | [Swift book: Enumerations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/) |
| `extension Rung { ... }` | Adding members to a type after the fact, including to types you do not own. TS has declaration merging, but it cannot add methods with bodies. | [Swift book: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/) |
| `switch` as an expression | `case 3: 1` with no `return`. The whole `switch` evaluates to a value. TS needs a lookup object or an IIFE. | [SE-0380: `if` and `switch` expressions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0380-if-switch-expressions.md) |
| `case 8...` | A one-sided range *pattern*, not a comparison. This is the branch the TypeScript left untested. | [Swift book: Patterns](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/) |
| `map(\.threshold)` | A key path used as a function. TS writes `.map(t => t.threshold)`; the key path is a first-class value that can be stored and passed. | [KeyPath reference](https://developer.apple.com/documentation/swift/keypath) |
| `Sendable`, and why globals must be `let` | Swift 6 requires global state to be immutable and safe to share across concurrency domains. TS has no equivalent because it has no compiler-enforced concurrency model. | [Sendable reference](https://developer.apple.com/documentation/swift/sendable) · [Swift book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) |

### Tasks 3–15

| Concept | Why it has no TypeScript analogue | Link |
|---|---|---|
| `some Sequence<String>` | An opaque parameter type. The caller may pass an Array or a Set and the compiler specialises for the concrete type — resolved at compile time, where TS's `Iterable<string>` is a runtime protocol. | [Swift book: Opaque and Boxed Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/) |
| `&*`, `&+` — wrapping operators | Plain `*` **traps** on overflow. JS silently wraps at 32 bits via `Math.imul`. Porting a PRNG without these is silently wrong. | [Swift book: Advanced Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/) |
| `enum EngineError: Error` + `throws` | A closed set of failures the caller can switch over. TS's `throw` produces `unknown`; the message is the only signal. | [Swift book: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/) |
| `Codable` | Conforming a struct generates its JSON decoder from the stored properties. A shape mismatch is a decode error, not an `undefined` surfacing three lines later. `JSON.parse` returns `any`. | [Codable reference](https://developer.apple.com/documentation/swift/codable) |
| `Calendar` / `TimeZone` | Swift's `Date` is a **bare instant** with no local accessors at all — no `getFullYear()`. All calendar arithmetic goes through an explicit `Calendar` carrying an explicit `TimeZone`. This is the single biggest shape difference in the port. | [Calendar](https://developer.apple.com/documentation/foundation/calendar) · [TimeZone](https://developer.apple.com/documentation/foundation/timezone) |
| `inout` | Explicit pass-by-reference for a value type, so a helper can advance the caller's copy. TS objects are references already, so nothing needs marking. | [Swift book: Functions (In-Out Parameters)](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/) |
| Generic constraints (`<R: RandomSource>`) | Load-bearing in `EndlessSource`: storing the generator as a constrained generic rather than a closure is what preserves value semantics. Also the source of the "viral generic" friction. | [Swift book: Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/) |
| `ContinuousClock` | A monotonic clock that cannot go backwards if the system clock is adjusted mid-measurement. `Date.now()` can. | [ContinuousClock reference](https://developer.apple.com/documentation/swift/continuousclock) |

### Part two: the SwiftUI app

| Concept | Why it has no TypeScript analogue | Link |
|---|---|---|
| `@Observable` | A macro that rewrites a class so SwiftUI re-renders when a property changes. Tracking is automatic and per-property: a view only re-renders for properties it actually read. React makes you declare dependencies; this infers them. | [Observation framework](https://developer.apple.com/documentation/observation) · [`@Observable`](https://developer.apple.com/documentation/observation/observable()) · [Migrating from ObservableObject](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro) |
| `@State` | Not `useState`. It owns a value across re-renders, closer to a ref, and with `@Observable` it is also the subscription. A plain `let` compiles and silently never updates. | [State](https://developer.apple.com/documentation/swiftui/state) · [Managing model data](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app) |
| `@MainActor` and `nonisolated` | Compile-time thread affinity. `@MainActor` on the model makes background mutation impossible by construction; `nonisolated` is the explicit opt-out for the file loading. JS has one thread and needs neither. | [MainActor](https://developer.apple.com/documentation/swift/mainactor) · [Strict concurrency](https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency) |
| `.task { }` | Runs an async job when a view appears, cancelled automatically on disappear. Roughly `useEffect` with an empty dependency array, minus the cleanup return. | [View](https://developer.apple.com/documentation/swiftui/view) |
| `@main struct App` | Replaces the AppDelegate lifecycle entirely. No main.swift, no UIApplicationMain, no storyboard. | [App protocol](https://developer.apple.com/documentation/swiftui/app) |
| XcodeGen | Not Swift, but load-bearing: SwiftPM cannot produce an app bundle and there is no `xcodebuild -create`, so an app target means an `.xcodeproj`. Generating it from a small YAML file beats hand-writing pbxproj. | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

## Writer's column — the agent's experience of writing it

**On "elapsed":** wall-clock between commits includes time spent waiting on
review, so it overstates working time. The figures below are agent-active time,
which is an estimate, not a measurement. Treat the *relative* costs across tasks
as the real signal and the absolute numbers as soft. Task 16 must say this
plainly rather than quoting the totals as if they were stopwatch readings.

| Task | Elapsed (agent-active, est.) | Awkward to write | Pleasant to write |
|---|---|---|---|
| 1. Scaffolding | ~20 min, of which maybe 4 was Swift | Nothing in the Swift itself. The time went to verifying the snapshot rather than writing code — and to the `wc -l` off-by-one, which was a real (small) prediction miss. | `InlineArray` forcing `swift-tools-version: 6.2` was already known from the planning spike, so the package built first try. Swift Testing's `arguments:` turned five near-identical count assertions into one parameterised test. |
| 2. Config, `Rung`, scoring | ~8 min, nearly all Swift | Honestly nothing. This is the easiest possible task: pure functions over integers, no state, no concurrency, no Foundation. If Swift were going to feel hostile it would not be here. Worth saying so plainly rather than manufacturing friction. | `case 8...` is the standout. The TypeScript wrote `SCORE_BY_LENGTH[length] ?? (length > 8 ? 15 : 0)` — a lookup with a fallback expression — and never tested the fallback. As a `switch` the above-8 case is *visibly a case*, and writing it made not testing it feel like an omission. The language nudged toward the test. `switch`-as-expression also removed six `return`s. |
| 3. Formability, both shapes | ~10 min | Nothing. `InlineArray` was already de-risked in planning. | Writing the two representations side by side made the value/reference distinction concrete before the measurement existed to prove it. |
| 4. Types + classification | ~10 min | `Dictionary` is taken by the stdlib → `ValidationDictionary`. Trivial rename, but a tax structural typing never charges. | `Set` algebra reads better than the TS spread-and-filter. |
| 5. `createPuzzle` + list sources | ~12 min | Nothing. | `subtracting`/`union` replaced `[...set].filter(...)` in three places. |
| 6–7. `computeTier`, `isComplete` | ~15 min | `tiers[index + 1]` traps rather than returning `undefined`, so the bound needed an explicit check. Safer, more verbose. | Writing `isComplete` as one function after finding it inlined twice in the web UI. The whole deviation took four lines. |
| 8–9. `validateGuess`, eligibility | ~12 min | **The one genuine compile error of the run**: `normalizeGuess` needed a `String.UnicodeScalarView` round-trip to filter characters. TS's `.replace(/[^a-z]/g,'')` is one call; the Swift is three type conversions deep. | `GuessResult` as an enum with associated values. `score` simply does not exist on a `.tooShort`. |
| 10. Shuffle + calendar | ~10 min | `&*` vs `*` — wrapping must be asked for by name. Known from planning, so no cost here; would have been a trap otherwise. | PRNG matched Node bit-for-bit first try. |
| 11–13. Oracle, `dayIndex`, daily | ~25 min | Largest engine task. Two `Calendar` types in scope (`Foundation.Calendar` vs this package's `Calendar.swift`) needed disambiguating. Shell cwd drift cost one failed run. | The oracle. 22 instants, 8 zones, exact match. Also: the `dateComponents` one-liner was expected to diverge on midnight-transition zones and **did not** — there is now a test asserting both agree. |
| 14. `EndlessSource` | ~12 min | `inout` on every helper, `var` on every holder, and a viral generic parameter — all the price of value semantics, for a property the game never uses. | The generic `RandomSource` making a copy a genuine fork. Nearly shipped a closure-based version that would have quietly shared state. |
| 15. Measurements | ~20 min | My own `grep -v "^\["` ate the `[Int8]` result line on the first run. Self-inflicted. | 2.5× inline-vs-heap, and the 25× debug/release gap on `LetterCounts` — the strongest possible argument for release-mode benchmarking. |
| **App: project setup** | ~35 min | Discovering that an app target cannot be made from the terminal at all, then installing XcodeGen. Also two package changes the engine port did not anticipate: an iOS platform floor, and a directory parameter on `readWordList` because `#filePath` does not survive into an app bundle. | Built, installed and launched in the simulator on the first attempt after generation. |
| **App: model and views** | ~40 min | Almost nothing. The largest surprise was how little there was: 219 lines of model, 124 of view. | `@Observable` needing no dependency declarations. The exhaustive `switch` over `GuessResult` in `submit()` is the engine port's enum paying off in the place it was designed for. |
| **App: verification** | ~25 min | No supported way to type into a SwiftUI text field from the terminal. AppleScript needed the field focused and did nothing. Added a `-guesses` launch argument instead. Also lost time to `--console-pty` not capturing `print`. | The launch-argument trick via `UserDefaults` is genuinely tidy. |
| **App: measurement** | ~30 min | **Found a bug in my own timing code**: the whole-seconds and sub-second components were scaled inconsistently, so anything at or above one second was silently underreported. Caught by disbelieving a flat set of numbers, not by a test. | Getting a decided answer on the iOS 26 floor: `InlineArray` is the only thing gating it, and dropping it builds clean at iOS 17 with all 84 tests passing. |

## Reader's column — Antoine's experience of reading it

Filled in at each checkpoint, from the prompt, not from memory. "Looked up"
means: something in the diff that could not be understood without going
elsewhere.

**This column stops being the centre of the experiment after Task 2.** At that
point the question shifted from "can I write Swift myself" to "what does working
on a native Swift project look like, and could I ship something". Tasks 3
through 15 were therefore **skimmed rather than read closely, by explicit
choice** — not because attention lapsed. Recorded here so the report cannot
quietly claim legibility evidence it never gathered.

| Task | Made sense? | Looked up | Held interest? |
|---|---|---|---|
| 1. Scaffolding | Yes — "getting it", wants more time sitting with it, but nothing opaque. | Nothing. Comments carried it. **But**: asked for documentation links from here on, so that the log doubles as a reading list. Acted on — see Reading list above, backfilled for Task 1. | Neutral. It is scaffolding; the engine starts in Task 2. Curious about Task 2. |
| 2. Config, `Rung`, scoring | — | — | Not recorded: the question shifted before this checkpoint was answered. |
| 3–15 | **Not gathered.** Skimmed by explicit choice. | — | — |

## Findings

Things the port surfaced about the web repo. Feeds the report.

### 1. `meta.json` no longer describes the shipped word lists

Found in Task 1, by asserting on the snapshot rather than trusting it.

`meta.json` was generated 2026-06-24. The lists were re-baked 2026-08-03 with
the curated dictionary patch applied, and nothing regenerated the metadata. The
boundary count it reports is 430,172; the files actually contain 427,290 —
a 2,882-word drift, small enough that nobody would notice by eye.

The "430,000 words" figure in the experiment brief traces to this stale field.

This is the same shape as the completion duplication: two records of one fact,
with nothing forcing them to agree. Pinned by a test in
`Tests/PeachEngineTests/SmokeTests.swift` so it cannot quietly resolve. Not
fixed — the web repo is out of scope.

### 2. None of the shipped lists ends in a trailing newline

Minor, but it means `wc -l` under-reports every list by one, and any tooling
that counts lines rather than parsed entries inherits the same off-by-one.
