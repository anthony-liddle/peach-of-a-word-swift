# Data snapshot

Copied from `~/Development/peach-of-a-word`, which stays canonical. These files
are frozen: they are never synced, only re-snapshotted deliberately.

- Source commit: `c1c33a62fadcc4dbf8297e5fdd1a79a1bdce52e4` (c1c33a6)
- Snapshot taken: 2026-08-11
- Previous snapshot: `475edfc`, 2026-08-09

`meta.json` no longer carries a `generatedAt`. It was dropped upstream because a
timestamp that changes on every bake changes the content-hashed data URL on every
bake, and because a fresh timestamp on a stale file is what made the drift below
invisible for six weeks. The source commit above is the provenance record now.

If the Swift side ever disagrees with the web, the first question is whether the
data drifted or the logic did. The SHA answers that in seconds.

All five word lists are byte-identical to source (verified by md5 at copy time).

## Included (7 files, 7.8MB)

| File | Words |
|---|---|
| `enable.txt` | 172,562 |
| `scowl95-additions.txt` | 254,728 |
| `common-pool.txt` | 10,879 |
| `beyond-size-70.txt` | 315,922 |
| `beyond-size-95.txt` | 5,389 |
| `daily-calendar.json` | 626 source words |
| `meta.json` | n/a |

The validation dictionary is `enable.txt` unioned with `scowl95-additions.txt`:
**427,290 words**, disjoint by construction.

None of the lists ends in a trailing newline, so `wc -l` reports one fewer than
the file contains. The counts above are the parsed counts.

## `meta.json` now describes these files. It did not until 2026-08-11

Kept rather than deleted, because the numbers below were quoted in several
places and anyone who met them needs to know they were wrong and are now right.

| Count | Was, until 2026-08-11 | Ships now | Was out by |
|---|---|---|---|
| enable | 172,727 | 172,562 | −165 |
| scowl95Additions | 257,445 | 254,728 | −2,717 |
| common | 10,861 | 10,879 | +18 |
| beyond70 | 318,691 | 315,922 | −2,769 |
| beyond95 | 5,399 | 5,389 | −10 |
| **boundary** | **430,172** | **427,290** | **−2,882** |
| sourcePool | 707 | 793 | +86 |
| definitionsCovered | 23,555 | 24,833 | +1,278 |

`meta.json` was generated 2026-06-24. The lists were re-baked 2026-08-03 with
the curated dictionary patch applied, and nothing regenerated the metadata, so
its counts described a build that no longer shipped. The widely quoted "430,000
words" figure came from `meta.json.counts.boundary` and was wrong.

Fixed upstream in `c1c33a6`: `pnpm data:bake` now rewrites `meta.json` from the
artifacts it produces, and `src/data/meta.test.ts` asserts every count against
the committed file it describes. Two fields were dropped there, `generatedAt`
and `definitionUnion`; see `scripts/lib/meta.ts` in the web repo for why.

`SmokeTests.metaJSONMatchesShippedLists` now asserts the agreement rather than
the divergence. It was inverted rather than deleted so this repo keeps an
opinion about a file it ships: the web-side test cannot see a snapshot that was
copied wrong, and a partial re-snapshot with the lists updated and the metadata
forgotten is the exact shape of the original bug.

## Excluded, by decision

- `defs/`: 795 directories of Wiktionary reveal content. The reveal is out of
  scope for this port.
- `source-pool.json`: the eligibility tests build their own synthetic pools, so
  the real source pool earns no weight here.

Neither is an oversight.
