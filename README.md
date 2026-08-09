# peach-of-a-word-swift

An experiment, deliberately timeboxed. Not a product, not a v2.

It ports the pure engine of Peach of a Word — scoring, rarity classification,
the tier ladder, completion, the daily calendar lookup, and puzzle construction
— from TypeScript to Swift, to find out two things: whether writing Swift is
enjoyable, and how fast that actually goes. The engine was chosen because it is
pure, framework-free, and fully unit-tested, so its existing test suite is an
executable spec. That makes this an exercise in learning one thing (Swift)
rather than two.

**The web repo stays canonical.** Nothing here feeds back into it. The word
lists in `Data/` are a frozen snapshot, not a sync — see [SNAPSHOT.md](SNAPSHOT.md)
for the date, the source commit, and one way the upstream metadata has already
drifted from the files it describes.

No UI, no persistence, no audio, no theming, no data pipeline. Those are the
rewrite half and are explicitly out of scope.

The result of the experiment is [docs/REPORT.md](docs/REPORT.md), written from
[docs/PORT-LOG.md](docs/PORT-LOG.md).

## Running it

```bash
swift test                              # the ported suite
swift run -c release peach-bench        # dictionary load + letter-count timings
```

Release mode matters for the benchmark: debug Swift string and collection work
is often around 10x slower, and a debug number would argue for a different
storage format on a lie.

Requires Swift 6.2+ and macOS 26, both forced by `InlineArray`.

## Licence

MIT. See [LICENSE](LICENSE).
