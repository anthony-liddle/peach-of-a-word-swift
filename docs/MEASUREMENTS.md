# Measurements

Two numbers the experiment brief asked for, plus a third that turned out to
matter more than either.

**Machine:** Apple M3 Pro, 11 cores, 18 GB RAM, macOS 26.6 (25G72),
Swift 6.3.3.
**Method:** `swift build -c release --product peach-bench`, run three times,
median reported. Debug figures from `swift run peach-bench`.
**Reproduce:** `swift run -c release peach-bench`

Every figure below is a **macOS** number. See "What this does not measure".

## 1. Dictionary load

The validation dictionary is `enable.txt` unioned with `scowl95-additions.txt`:
**427,290 words**. (Not 430,172 — that figure comes from a stale `meta.json`.
See `SNAPSHOT.md`.)

| Step | Release | Debug | Debug penalty |
|---|---|---|---|
| read `enable.txt` (172,562 words) | 37.6 ms | 105.7 ms | 2.8× |
| read `scowl95-additions.txt` (254,728) | 59.3 ms | 109.6 ms | 1.8× |
| union the two into one array | 0.8 ms | 0.9 ms | — |
| build `Set<String>` over 427,290 words | **11.8 ms** | 56.2 ms | 4.8× |
| read `common-pool.txt` (10,879) | 2.3 ms | 5.0 ms | 2.2× |
| read `beyond-size-70.txt` (315,922) | 72.3 ms | 133.6 ms | 1.8× |
| read `beyond-size-95.txt` (5,389) | 1.2 ms | 3.0 ms | 2.5× |

**Cold start, all five lists plus the validation `Set`, as one measurement:**

| | Release | Debug |
|---|---|---|
| Full load | **186 ms** | 381 ms |

### What this decides

The brief asked whether a sorted binary file or SQLite would be needed. **On
this evidence, no.**

186 ms of synchronous work at launch is noticeable but not broken — comparable
to a single modest network request, and well inside what a launch screen
absorbs. Moving it off the main thread, or deferring the two rarity-band lists
until after first paint (they are not needed to render the rack), would take the
blocking portion to roughly 110 ms without changing the storage format at all.

The surprise is *where* the time goes. Building a 427k-entry hash set costs
**11.8 ms** — essentially free. Almost all the cost is reading and splitting
text: 173 ms of the 186. So the optimisation with the best return is not a
database, it is not parsing 8 MB of UTF-8 into 427,290 individually allocated
`String`s. A packed binary blob searched in place would attack the right
problem; SQLite would add a dependency to fix the part that was already fast.

**Conclusion: ship the plain lists. Revisit only if launch time becomes a real
complaint, and if it does, reach for a packed format rather than a database.**

## 2. Letter counts: inline value type vs heap array

One full formability pass over all 427,290 words, twice, with the two
representations described in `Sources/PeachEngine/Formability.swift`. Both
produce the same 239 formable words — there is a test that enforces it, so this
is a comparison of two encodings of one function, not of two functions.

| Representation | Release | Debug |
|---|---|---|
| `LetterCounts` — `InlineArray<26, Int8>`, no allocation | **16.7 ms** | 417.9 ms |
| `[Int8]` — heap-allocated buffer per word | **41.6 ms** | (not run) |
| **Delta** | **2.5× / +24.9 ms** | |

The heap version is the literal translation of the TypeScript's `Int8Array(26)`.
Choosing Swift's default value semantics instead — a fixed-size array stored
inline in the struct — removes 427,290 heap allocations from a single pass and
runs 2.5× faster.

Worth noting how small the absolute stake is: 25 ms, once, on a full-dictionary
scan the app performs when building a puzzle, not per keystroke. The interesting
part is not the saving, it is that the language's default was also the fast
option, and the TypeScript-faithful translation was the slow one.

The debug figure for `LetterCounts` is the outlier of the whole run: **417.9 ms
against 16.7 ms in release, a 25× penalty.** Swift's abstractions are free only
after the optimiser has been at them. Any benchmark run under `swift test`, which
is a debug build, would have been off by an order of magnitude — this is the
single strongest argument for the plan's insistence on release-mode measurement.

## 3. End-to-end `createPuzzle` on a real rack

| | Release |
|---|---|
| `createPuzzle("serenade")` over the full lists | **44 ms** |

Result: 239 validation words, 35 set words, 62 uncommon, 130 rare, 12 mythic,
par 111.

This is four full passes over the word lists (validation, common, beyond-70,
beyond-95) plus the set algebra. It runs once per puzzle, not per guess —
guessing is a `Set` lookup against `validationWords`, which is O(1) and
unmeasurable here.

44 ms is comfortably inside a frame budget for a one-off operation and needs no
attention.

## What this does not measure

Stated plainly, because these numbers will be used to make a shipping decision.

- **Every figure is macOS on an M3 Pro.** An iPhone has a comparable single-core
  CPU and fast storage, so the same work is plausibly within ~1.5–2× — but that
  is an inference, not a measurement. **Nothing here has been run on a phone.**
  Before committing to the plain-list format for a shipped app, run this
  benchmark on the oldest device actually being targeted.
- **File cache is warm.** These runs read the same 8 MB repeatedly. A genuine
  first-launch-after-install read from cold storage will be slower.
- **No memory figure.** 427,290 Swift `String`s plus a `Set` is not free in RAM,
  and on a memory-constrained phone that may matter more than the 186 ms. Not
  measured.
- **`beyond-size-70.txt` is the largest single cost** (72 ms) and is needed only
  to classify rarity, not to validate a guess or draw a rack. That is the
  obvious first thing to defer, and it was not tested here.
