# peach-of-a-word-swift

A native iOS version of [Peach of a Word](https://github.com/anthony-liddle/peach-of-a-word),
a daily word game. Make words from eight letters, then find the source word they
all came from.

One puzzle a day, shared by everyone playing. Tap letters to build a word, find
the common words the rack can spell to climb the tier ladder, and find the
eight-letter source word itself for the game's other moment. Progress and streak
survive a force quit, the day rolls over at local midnight, and a finished day
can be shared as a spoiler-free block of squares.

Built in SwiftUI on top of `PeachEngine`, a pure Swift package holding scoring,
rarity classification, the tier ladder, completion, the daily calendar lookup and
puzzle construction. The engine has no UI, no I/O and no framework dependencies,
which is why it carries 102 tests and the app carries none.

**The web repo stays canonical.** Nothing here feeds back into it. The word lists
in `Data/` are a frozen snapshot, not a sync. See [SNAPSHOT.md](SNAPSHOT.md) for
the date, the source commit, and one way the upstream metadata has already
drifted from the files it describes.

<img src="docs/images/app.png" alt="A mid-game board: the tier meter partway to Ripening, eight letter tiles, and the found list showing set words and off-page finds" width="320">

## Running it

Requires Swift 6.0+ and Xcode. The package targets **macOS 14 and iOS 17**. The
iOS floor comes from the app's use of `@Observable` and `ContentUnavailableView`,
not from the engine.

```bash
# XcodeGen is required. The .xcodeproj is generated and is not in the repo.
brew install xcodegen                   # or: mint install yonaskolb/XcodeGen

# The app.
xcodegen generate
xcodebuild -project PeachOfAWord.xcodeproj -scheme PeachOfAWord \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

swift test                              # the engine suite, 102 tests
swift run -c release peach-bench        # dictionary load + letter-count timings
```

**`PeachOfAWord.xcodeproj` is not in the repository.** It is generated from
`project.yml`, so a fresh clone has no project in it and `xcodegen generate` is
the first thing to run. Opening the folder in Xcode before that will not work.

It was committed for a while, so the repo would open without the tool. That
made the spec and the project two sources of truth for the same thing: change
`project.yml`, forget to regenerate, and the build quietly uses the stale
project. Xcode Cloud regenerates it on every build through
`ci_scripts/ci_post_clone.sh`, which left no reason to keep carrying the second
copy.

The consequence for anyone working here: project settings are **not** editable
through Xcode's UI. Anything set there is discarded by the next
`xcodegen generate`, and now there is no committed file to notice the loss in.
Change `project.yml` instead. Source files under `App/` and `Sources/` are
unaffected, and so is opening, editing and running the app once the project
exists.

`ci_post_clone.sh` also sets the build number from `CI_BUILD_NUMBER`. Local
builds keep the number committed in `project.yml`.

Release mode matters for the benchmark. Debug Swift string and collection work is
often around 10x slower, and a debug number would argue for a different storage
format on a lie.

Debug builds take launch arguments that drive the game without typing into the
simulator, including `-guesses word1,word2` to submit words at startup and
`-dayOffset N` to move the calendar. All of them are behind `#if DEBUG` and are
unreachable in a release build.

## How it started

This began as a deliberately timeboxed experiment: port the engine from
TypeScript to Swift, tests first, and find out whether writing Swift was
enjoyable and how fast it actually went. It was explicitly not a product. That
framing is now out of date, because it shipped and is being played daily.

The experiment record is kept rather than rewritten:

- **[docs/REPORT.md](docs/REPORT.md)** is the result, including what the port
  cost, where Swift's strictness paid for itself and where it did not, four bugs
  the port surfaced in the web repo, and what stood between a working engine and
  a shipped app.
- **[docs/PORT-LOG.md](docs/PORT-LOG.md)** is the running log, and doubles as a
  reading list of Swift and SwiftUI concepts with no TypeScript equivalent.
- **[docs/MEASUREMENTS.md](docs/MEASUREMENTS.md)** holds the timings, including
  the dictionary load on a real phone and why the deployment floor moved.

Those documents describe the repository as it was at the end of the port, when
there was no UI, no persistence and no theming. They are a record of how it went,
not a description of what is here now.

## Attribution

The word lists are ENABLE (public domain) and SCOWL, and the typefaces are
Fredoka and Nunito under the SIL Open Font License. SCOWL and the OFL both
require their notices travel with the files, so those notices are reproduced in
[ATTRIBUTION.md](ATTRIBUTION.md) and in `App/Fonts/`.

## Licence

MIT. See [LICENSE](LICENSE). This covers the code in this repository, not the
bundled word lists or fonts, which carry their own terms.
