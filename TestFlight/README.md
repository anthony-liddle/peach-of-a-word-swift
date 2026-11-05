# TestFlight release notes

Xcode Cloud reads tester-facing release notes from **`WhatToTest.<LOCALE>.txt`**
in a folder named `TestFlight`, which has to sit in the same directory as the
Xcode project. Both of those are Apple's requirements, not conventions: the
folder name, the file name and the locale suffix are all matched literally, and
a file in the wrong place is ignored without any error.

One file per locale. `WhatToTest.en-US.txt` is the only one here. Adding, say,
German means adding `WhatToTest.de-DE.txt` beside it, not editing this one. The
accepted locale codes are the ones in Apple's `BetaBuildLocalizationCreateRequest`.

The contents are shown to testers verbatim in TestFlight, under "What to Test",
which is why the explanation you are reading is in this file rather than in that
one. Anything written there is read by a person deciding what to try, so it is
prose rather than a changelog.

It is picked up per build, from the commit that build was made from. Updating
the notes means editing the file and pushing, in the same commit as the change
they describe.

## What the note says

Bea and the other testers read it, and every merge to `main` is a build they
install. So the note is written for that build, by the pull request that makes
it (Antoine, 5 November 2026):

- **One or two plain sentences, written for this build:** what's new that a
  tester could notice, or, when nothing is, something like "Small fixes."
  Never carried over from an earlier build: a note that's still true is still
  the last build's note.
- **Never a changelog,** and never anything a tester can't see.
- **Never names a surprise:** no costume, no holiday, no future word.

`PlayerWordsTests` holds the note to the same words as the game's: no em dash,
and none of the words `Voice/AI Tells.md` bans.

Reference: <https://developer.apple.com/documentation/xcode/including-notes-for-testers-with-a-beta-release-of-your-app>
