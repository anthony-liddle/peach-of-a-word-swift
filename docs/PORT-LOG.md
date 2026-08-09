# Port log

Feeds `docs/REPORT.md`. Record honestly, including the parts that go badly —
the friction is half the answer.

Two kinds of row, and they are **not** the same kind of evidence. The writer's
column is the implementing agent reporting on itself. The reader's column is
Antoine reporting on reading the diff. "Was Swift awkward for the agent" is a
fact about the agent; "was Swift legible and interesting to Antoine" is the
question this experiment exists to answer.

## Reading list

When a task introduces a Swift concept with no TypeScript equivalent, it gets a
link here — the Swift book, the API reference, or the evolution proposal,
whichever actually explains it, not whichever is nearest. Inline comments say
what the code does; these say where to go to understand why the language works
that way. By Task 16 this section should stand on its own as a reading list.

Every link is checked for a 200 before it goes in.

### Task 1

| Concept | Why it has no TypeScript analogue | Link |
|---|---|---|
| `#filePath` | A compile-time magic literal. TS's `import.meta.url` is resolved at runtime by the module loader; this is substituted by the compiler into the binary. | [Swift book: Literal Expression](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Literal-Expression) · [SE-0274](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0274-magic-file.md) (why `#filePath` and `#file` differ) |
| `InlineArray<26, Int8>` | A fixed-size array stored *in* the struct rather than behind a heap pointer. TS has no stack/heap distinction to expose. Used in Task 3. | [SE-0453: InlineArray, a fixed-size array](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md) · [API reference](https://developer.apple.com/documentation/swift/inlinearray) |
| Availability gating | `InlineArray` is macOS 26+, which is what forces this package's platform floor. TS has no notion of an API existing only on some deployment targets. | [Swift book: `@available`](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#available) |
| `mutating func` | Marks a method that changes a value type. TS objects are all references, so there is nothing to mark. Load-bearing in Tasks 10 and 14. | [Swift book: Modifying Value Types from Within Instance Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/#Modifying-Value-Types-from-Within-Instance-Methods) · [Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/) |
| Swift Testing | Not XCTest. `@Test`, `@Suite`, `#expect`, and `arguments:` for parameterised cases. | [Swift Testing documentation](https://developer.apple.com/documentation/testing) |

## Writer's column — the agent's experience of writing it

**On "elapsed":** wall-clock between commits includes time spent waiting on
review, so it overstates working time. The figures below are agent-active time,
which is an estimate, not a measurement. Treat the *relative* costs across tasks
as the real signal and the absolute numbers as soft. Task 16 must say this
plainly rather than quoting the totals as if they were stopwatch readings.

| Task | Elapsed (agent-active, est.) | Awkward to write | Pleasant to write |
|---|---|---|---|
| 1. Scaffolding | ~20 min, of which maybe 4 was Swift | Nothing in the Swift itself. The time went to verifying the snapshot rather than writing code — and to the `wc -l` off-by-one, which was a real (small) prediction miss. | `InlineArray` forcing `swift-tools-version: 6.2` was already known from the planning spike, so the package built first try. Swift Testing's `arguments:` turned five near-identical count assertions into one parameterised test. |

## Reader's column — Antoine's experience of reading it

The column the experiment turns on. Filled in at each checkpoint, from the
prompt, not from memory. "Looked up" means: something in the diff that could not
be understood without going elsewhere.

| Task | Made sense? | Looked up | Held interest? |
|---|---|---|---|
| 1. Scaffolding | Yes — "getting it", wants more time sitting with it, but nothing opaque. | Nothing. Comments carried it. **But**: asked for documentation links from here on, so that the log doubles as a reading list. Acted on — see Reading list above, backfilled for Task 1. | Neutral. It is scaffolding; the engine starts in Task 2. Curious about Task 2. |

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
