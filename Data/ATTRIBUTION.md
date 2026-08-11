# Word list attribution

**This file covers the word lists in this directory, not the app.** The app's own
licence is MIT and lives at the repository root. These lists are not the app's to
licence: they come from upstream sources with their own terms, reproduced below.

A `LICENSE` file sat here until 2026-08-11 carrying the repository's MIT text. It
was a copy of the app's licence, placed inside the data directory, where it read
as though it granted MIT terms over word lists nobody here owns. It did not and
could not. This file replaces it.

It also sits here rather than only at the repository root because `Data/` is
bundled into the app as a folder reference, so the notice now travels inside
every copy of the lists rather than staying behind in the repository. SCOWL asks
for exactly that. See the root `ATTRIBUTION.md` for the fuller record, and
`SNAPSHOT.md` for the snapshot date and source commit.

## ENABLE (`enable.txt`)

ENABLE (Enhanced North American Benchmark LExicon). **Public domain.** No
restrictions apply and none are claimed here.

## SCOWL (`scowl95-additions.txt`, `common-pool.txt`, `beyond-size-70.txt`, `beyond-size-95.txt`)

Derived from SCOWL (Spell Checker Oriented Word Lists), compiled by Kevin
Atkinson, version 2020.12.07 (classic v1).

> The collective work is Copyright 2000-2020 by Kevin Atkinson as well as any
> of the copyrights mentioned below:
>
> Copyright 2000-2020 by Kevin Atkinson
>
> Permission to use, copy, modify, distribute and sell these word lists, the
> associated scripts, the output created from the scripts, and its documentation
> for any purpose is hereby granted without fee, provided that the above
> copyright notice appears in all copies and that both that copyright notice and
> this permission notice appear in supporting documentation. Kevin Atkinson
> makes no representations about the suitability of this array for any purpose.
> It is provided "as is" without express or implied warranty.

The full SCOWL readme and the per-source copyrights are at
<http://wordlist.aspell.net/>.

## Not shipped here

**No Wiktionary content is in this directory.** The web version credits
Wiktionary for definitions and etymologies under CC BY-SA 4.0, and ships them in
`defs/` and `source-pool.json`. This app ships neither: the source-word card
names the word without defining it. Crediting a source that is not used would be
worse than saying nothing, which is the same reasoning `App/Colophon.swift`
gives for leaving the Wiktionary line out of the in-app credit.

If definitions ever land here, this file and the colophon both need the CC BY-SA
line, and share-alike terms will apply to the definition text.

## Derived files

`daily-calendar.json` and `meta.json` are derived from the lists above rather
than taken from any upstream source. The calendar is an ordering of eligible
source words; `meta.json` records counts and this attribution.
