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

Reference: <https://developer.apple.com/documentation/xcode/including-notes-for-testers-with-a-beta-release-of-your-app>
