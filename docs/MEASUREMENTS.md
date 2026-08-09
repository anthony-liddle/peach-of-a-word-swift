# Measurements

Two numbers the experiment brief asked for, plus a third that turned out to
matter more than either.

**Machine:** Apple M3 Pro, 11 cores, 18 GB RAM, macOS 26.6 (25G72),
Swift 6.3.3.
**Method:** `swift build -c release --product peach-bench`, run three times,
median reported. Debug figures from `swift run peach-bench`.
**Reproduce:** `swift run -c release peach-bench`

Sections 1 to 3 are **macOS** numbers. Real device figures, measured on an
iPhone 13, are in "On a real device" near the end. See also "What this does not
measure".

> **Two configurations appear in this document.** The engine was first built
> with `LetterCounts` backed by `InlineArray`, which required iOS 26 and
> macOS 26. That was later dropped for a plain `[Int8]` so the deployment floor
> could fall to iOS 17. Numbers are labelled **inline (historical)** or
> **shipped** throughout. The historical numbers are kept deliberately: they are
> still true, and section 2 is the most interesting result in the port.
>
> Re-measured after the swap with all simulators shut down, median of five runs.

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
| Full load, inline (historical) | 186 ms | 381 ms |
| Full load, shipped | **198 ms** | (not re-run) |

This block does no formability work, so the representation swap should not
affect it. The 12 ms difference is run-to-run variation and machine state, not a
regression. Recorded rather than smoothed so the two configurations are directly
comparable.

### What this decides

The brief asked whether a sorted binary file or SQLite would be needed. **On
this evidence, no.**

About 200 ms of list loading at launch is noticeable but not broken, comparable
to a single modest network request and well inside what a launch screen absorbs.
Moving it off the main thread, or deferring the two rarity-band lists until after
first paint (they are not needed to render the rack), would take the blocking
portion to roughly 110 ms without changing the storage format at all.

The surprise is *where* the time goes. Building a 427k-entry hash set costs
**11.8 ms**, essentially free. Almost all the cost is reading and splitting
text. So the optimisation with the best return is not a database, it is not
parsing 8 MB of UTF-8 into 427,290 individually allocated `String`s. A packed
binary blob searched in place would attack the right problem; SQLite would add a
dependency to fix the part that was already fast.

**Conclusion: ship the plain lists. Revisit only if launch time becomes a real
complaint, and if it does, reach for a packed format rather than a database.**

## 2. Letter counts: inline value type vs heap array

**The most interesting result in the port, and the one that was deliberately
given up.**

One full formability pass over all 427,290 words, with the two representations
of `LetterCounts`. Both produce the same 239 formable words, so this is a
comparison of two encodings of one function, not of two functions.

| Representation | Release | Debug |
|---|---|---|
| `InlineArray<26, Int8>`, no allocation (**inline, historical**) | **16.7 ms** | 417.9 ms |
| `[Int8]`, heap-allocated buffer per word (**shipped**) | **44.4 ms** | (not re-run) |
| **Delta** | **2.7x / +27.7 ms** | |

The heap version is the literal translation of the TypeScript's `Int8Array(26)`.
The inline version removes 427,290 heap allocations from a single pass. Swift's
default value type was the fast option and the faithful translation was the slow
one, which is the finding worth keeping.

**The inline version was dropped anyway.** `InlineArray` requires iOS 26 and
macOS 26 and was the only API in the package that did, so it alone set the
deployment floor. See "The deployment floor" below.

The debug figure is the outlier of the whole project: **417.9 ms against 16.7 ms
in release, a 25x penalty.** Swift's abstractions are free only after the
optimiser has been at them. Any benchmark run under `swift test`, which is a
debug build, would have been off by an order of magnitude.

(The earlier version of this table recorded 41.6 ms for the `[Int8]` variant,
measured through a separate `canFormArray` helper. The 44.4 ms figure is the
same representation measured through `LetterCounts` itself after the swap, with
simulators shut down. The small difference is measurement conditions, not a
change in the code.)

## 3. End-to-end `createPuzzle` on a real rack

| | Release |
|---|---|
| `createPuzzle("serenade")`, **inline (historical)** | **44 ms** |
| `createPuzzle("serenade")`, **shipped** | **94 ms** |

Result either way: 239 validation words, 35 set words, 62 uncommon, 130 rare,
12 mythic, par 111.

**Note the cost is larger here than the single-pass delta suggests, and this
correction matters.** `createPuzzle` makes four passes over the word lists
(validation, common, beyond-70, beyond-95), so it pays the representation
penalty roughly 1.75 times over rather than once. The real cost of dropping
`InlineArray` is about **50 ms on `createPuzzle`**, not the 25 ms that a
single-pass reading implies.

It still runs once per puzzle, not per guess. Guessing is an O(1) `Set` lookup
against `validationWords` and is unmeasurable here. 94 ms on a one-off operation
that happens behind a loading indicator needs no attention.

## The deployment floor

The decision this document exists to support, recorded with its cost.

| | Inline (historical) | Shipped |
|---|---|---|
| `LetterCounts` backing | `InlineArray<26, Int8>` | `[Int8]` |
| Platform floor | macOS 26 / iOS 26 | **macOS 14 / iOS 17** |
| `swift-tools-version` | 6.2 | 6.0 |
| One formability pass | 16.7 ms | 44.4 ms |
| `createPuzzle` | 44 ms | 94 ms |
| App cold start, iOS 26.4 Simulator, Release | 260 ms | **300 ms** |
| App cold start, iOS 17.5 Simulator, Release | not buildable | **404 ms** |

| App cold start, iPhone 13, Release | not buildable | **403 ms** |

The iOS 17.5 simulator figure is a single run and should be treated as soft. It
is included because it is evidence that the lower floor actually works, and
because the older simulator runtime being meaningfully slower on identical host
hardware is worth knowing.

The iPhone 13 row is a real device, and is the load-bearing one. The app was
installed and launched on hardware that **cannot be excluded by this floor**,
which is the entire point of the change.

`InlineArray` was verified to be the only thing gating the floor: nothing else
in the package or the app requires anything above iOS 17. The app's own floor is
set by `@Observable` and `ContentUnavailableView`, both iOS 17, so the engine
alone would go lower still.

**Total cost of the change: about 40 ms on app cold start**, behind a loading
indicator, on an operation that runs once per puzzle. **Total benefit: nine
years of device support.** An iOS 26 minimum in mid 2026 would exclude most
devices in use, quite possibly including the one phone this game is being built
for, which would defeat the point of building it.

Verified by installing and running the app on an **iOS 17.5** simulator
(iPhone 15 Pro), not merely by building against the lower floor.

## On a real device

**Measured 2026-08-09 on Anthony's iPhone 13 (A15, 2021), Release build,
installed and launched over USB with `devicectl`.** This is the number every
earlier version of this document said it did not have.

Timing the whole of `buildTodaysPuzzle`: five word lists, the validation `Set`,
the calendar JSON, and `createPuzzle`.

| | iPhone 13 | iOS 26.4 Simulator (M3 Pro) | Ratio |
|---|---|---|---|
| Warm | **362 ms** | 300 ms | 1.21x |
| Cold, fresh install | **403 ms** | 300 ms | 1.34x |

Warm is the median of five runs (354.7, 356.7, 361.7, 361.9, 367.3), which is a
tight spread. Cold is two runs (400.1, 406.9), each after a full uninstall and
reinstall.

**Two things this settles.**

First, **the phone is only about 1.2x slower than the simulator**, not the
1.5x to 2x this document previously guessed. The guess was conservative in the
right direction, but it was a guess, and now it is not.

Second, **cold and warm genuinely differ on device**, by about 40 ms or 11%.
This document previously reported that they were indistinguishable in the
simulator and cautioned that this "does not settle the question on a device,
where storage is genuinely different hardware". That caution was correct. The
effect is real, small, and does not change anything.

**The conclusion holds, now on evidence rather than inference: ship the plain
word lists.** 362 ms warm and 403 ms cold, on a five-year-old phone, behind a
loading indicator, on work that happens once per puzzle. No sorted binary
format, no SQLite.

## What this does not measure

Stated plainly, because these numbers will be used to make a shipping decision.

- **Sections 1 to 3 are macOS on an M3 Pro.** They are the right numbers for
  comparing configurations against each other and the wrong ones for predicting
  a phone. "On a real device" above now carries the device figures, and the
  real ratio turned out to be about 1.2x rather than the 1.5x to 2x guessed
  here originally.
- **One device, one generation.** The iPhone 13 is a 2021 A15. Anything older
  than that, and anything memory constrained, remains unmeasured.
- **First launch after an App Store download** is still unmeasured. The device
  cold figure above follows a `devicectl` install over USB, which is not the
  same path as an App Store install and its decompression.
- **No memory figure.** 427,290 Swift `String`s plus a `Set` is not free in RAM,
  and on a memory-constrained phone that may matter more than the 186 ms. Not
  measured.
- **`beyond-size-70.txt` is the largest single cost** (72 ms) and is needed only
  to classify rarity, not to validate a guess or draw a rack. That is the
  obvious first thing to defer, and it was not tested here.
