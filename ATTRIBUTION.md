# Attribution

This app is built on public and openly licensed word data. Credit where it is
due.

**The notice that ships is `Data/ATTRIBUTION.md`.** This file is the fuller
record and lives in the repository; that one sits inside the folder reference
bundled into the app, so SCOWL's notice travels with the copy of the word lists
rather than staying behind here. Keep the two in step when either changes.

This file is adapted from the web repo's `ATTRIBUTION.md` rather than copied.
The two ship the same word lists but different typefaces, and this one ships no
definitions at all, so three of the four sections below differ.

## ENABLE word list (validation)

The validation dictionary is ENABLE (Enhanced North American Benchmark
LExicon). ENABLE is in the public domain and is the standard list for hobby
word games. No restrictions apply.

Shipped as `Data/enable.txt`.

## SCOWL (common pool and source words)

The common-word pool and the eight-letter source words are derived from SCOWL
(Spell Checker Oriented Word Lists), compiled by Kevin Atkinson.

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

The full SCOWL readme and the per-source copyrights are available at
<http://wordlist.aspell.net/>.

Shipped as `Data/scowl95-additions.txt`, `Data/common-pool.txt`,
`Data/beyond-size-70.txt` and `Data/beyond-size-95.txt`. These are a frozen
committed copy of a pinned orchard release; see `tools/update-lexicon.sh` for
the version and its checksums.

## Wiktionary (definitions and etymologies)

The source-word reveal shows a short definition and an etymology, from the
English Wiktionary, licensed **CC BY-SA 4.0**. The corpus ships as
`Data/etymology.tsv`: 820 entries covering all 626 calendar crowns, taken from a
pinned orchard release. See `tools/update-lexicon.sh` for the version and its
checksums.

That licence is share-alike, so the derivative use is released under the same
terms and the attribution is visible in the app rather than only in a file like
this one. Two places carry it: the reveal card, underneath the content, and the
colophon at the foot of the found list.

**What this section used to say.** Until 2026-08-14 it read "Nothing in this
repository is derived from Wiktionary, and no definition text ships in the app",
and recorded that the card named the word and never defined it as a deliberate
constraint rather than an omission. It is rewritten rather than deleted because
the constraint was real and the reason it lifted is worth keeping: etymology has
no permissive source. Every open etymology dataset is a Wiktionary derivative
and inherits CC BY-SA, so the choice was this licence or no etymology at all.
The tappable per-word definitions the web also ships are still not here; that is
a larger corpus and a separate decision.

- Source: <https://en.wiktionary.org/>
- Licence: <https://creativecommons.org/licenses/by-sa/4.0/>

## Fonts

Set in **Fredoka** and **Nunito**, both under the SIL Open Font License 1.1.
The web repo uses Fraunces and Spectral for its letterpress theme; this app
ships only the cute theme, so it ships only that theme's two faces.

- Fredoka: Copyright 2016 The Fredoka Project Authors
  (<https://github.com/hafontia/Fredoka-One>)
- Nunito: Copyright 2014 The Nunito Project Authors
  (<https://github.com/googlefonts/nunito>)

Unlike the web version, which fetches fonts at build time, this repository
**redistributes the font binaries** in `App/Fonts/`. The OFL requires its text
and copyright notice travel with them, so the full licence for each is committed
alongside: [`App/Fonts/OFL-Fredoka.txt`](App/Fonts/OFL-Fredoka.txt) and
[`App/Fonts/OFL-Nunito.txt`](App/Fonts/OFL-Nunito.txt).

## In the app

There is a colophon in the game itself, at the foot of the found list: "Words
from ENABLE and SCOWL." and "Set in Fredoka and Nunito." A file in a repository
satisfies SCOWL's notice requirement but says nothing to the person actually
playing, and the web set the bar with an in-app credit.

Since 2026-08-14 it carries a third line crediting Wiktionary, because the
reveal now ships definitions and etymologies. It read "no Wiktionary line,
because no definitions ship" before that, on the grounds that crediting a source
that is not used would be worse than saying nothing. The line and the content
landed together, which is the only order that is ever correct.
