# Port log

Feeds `docs/REPORT.md`. Record honestly, including the parts that go badly —
the friction is half the answer.

Two kinds of row, and they are **not** the same kind of evidence. The writer's
column is the implementing agent reporting on itself. The reader's column is
Antoine reporting on reading the diff. "Was Swift awkward for the agent" is a
fact about the agent; "was Swift legible and interesting to Antoine" is the
question this experiment exists to answer.

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
| 1. Scaffolding | | | |

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
