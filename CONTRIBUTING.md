# Contributing

## Setup

XcodeGen is required. The `.xcodeproj` is generated from `project.yml` and is
not committed, so a fresh clone has no project in it.

```bash
brew install xcodegen                   # or: mint install yonaskolb/XcodeGen
git clone git@github.com:anthony-liddle/peach-of-a-word-swift.git
cd peach-of-a-word-swift
xcodegen generate
open PeachOfAWord.xcodeproj
```

**Xcode 26 or newer** to build the app. The package targets macOS 14 and iOS 17,
which is the deployment floor and a separate thing from the SDK it compiles
against: `App/Feel.swift` calls UIKit's feedback generators from nonisolated
functions, and those APIs are `@MainActor` in the iOS 18 SDK and `nonisolated`
from the iOS 26 SDK. On Xcode 16.4 the app target does not compile. The app
still runs on iOS 17.

The engine has no such constraint. `swift test` passes on Swift 6.1, so
`Sources/` and `Tests/` can be worked on with an older toolchain.

## The one rule that will catch you out

**Project settings are not editable through Xcode's UI.** Anything changed in
the target editor is discarded the next time `xcodegen generate` runs, and there
is no committed project file in which to notice it went missing. Edit
`project.yml`.

Source files under `App/` and `Sources/` are normal, and so is everything else
about working in Xcode once the project exists.

## Before opening a pull request

```bash
swift test                              # the engine suite
xcodegen generate
xcodebuild -project PeachOfAWord.xcodeproj -scheme PeachOfAWord \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' build
```

CI runs exactly these, on macOS. It also runs `ci_scripts/ci_post_clone.sh`,
the same script Xcode Cloud uses, so a change that breaks the Xcode Cloud
delivery path fails on the pull request rather than on the way to TestFlight.

## Commits

Conventional Commits: `type(scope): description`. Types: `feat`, `fix`, `docs`,
`style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `revert`.

Written by hand. There is no commitlint and no husky here, deliberately.

Branches: `type/kebab-case-description`, for example `fix/rack-layout` or
`feat/endless-mode`.

**No em dashes**, in code, comments, commit messages or documentation.

## Code style

Match the surrounding code. This repository comments more heavily than most,
and specifically comments *why*: several files carry the reasoning for a
decision that looks odd without it. If you change one of those decisions, change
the comment with it. A stale rationale is worse than none.

## Two things that are not obvious

**The web repo is canonical and read-only from here.** This app is a port of
[peach-of-a-word](https://github.com/anthony-liddle/peach-of-a-word). Nothing in
this repository feeds back into it. If you find a bug that exists in both, it
gets reported there, not fixed from here. `docs/REPORT.md` lists five found that
way.

**User-facing strings use the cute vocabulary.** The web has two themes; this app
ships only the peach one. Letterpress vocabulary (type, case, set, rack, press)
must not appear in a string a player can read. `AppVocabularyTests` enforces it
by scanning `App/*.swift`, and it exists because the same mistake was made three
times.

## Word data

`Data/` is a frozen snapshot, not a sync. See [SNAPSHOT.md](SNAPSHOT.md) before
changing anything in it, and [ATTRIBUTION.md](ATTRIBUTION.md) for the terms the
lists carry.

## Reporting a bug in the game

Use the issue templates. If the puzzle is still today's, please avoid posting
the source word: the daily is the same board for everyone.
