# Data snapshot

Copied from `~/Development/peach-of-a-word`, which stays canonical. These files
are frozen: they are never synced, only re-snapshotted deliberately.

- Source commit: `475edfc687b6bdce2a1186a80c801ae90bda3e57` (475edfc)
- Snapshot taken: 2026-08-09
- Data generated at, per `meta.json`: 2026-06-24T15:11:59.569Z

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

## `meta.json` does not describe these files

Recorded here because it is a trap, not a footnote.

| Count | `meta.json` says | Actually ships | Drift |
|---|---|---|---|
| enable | 172,727 | 172,562 | −165 |
| common | 10,861 | 10,879 | +18 |
| beyond70 | 318,691 | 315,922 | −2,769 |
| beyond95 | 5,399 | 5,389 | −10 |
| **boundary** | **430,172** | **427,290** | **−2,882** |

`meta.json` was generated 2026-06-24. The lists were re-baked 2026-08-03 with
the curated dictionary patch applied, and nothing regenerated the metadata, so
its counts describe a build that no longer ships. The widely-quoted "430,000
words" figure comes from `meta.json.counts.boundary`.

`Tests/PeachEngineTests/SmokeTests.swift` pins this divergence so it cannot
quietly resolve itself. Not fixed here, because the web repo is out of scope for this
experiment.

## Excluded, by decision

- `defs/`: 795 directories of Wiktionary reveal content. The reveal is out of
  scope for this port.
- `source-pool.json`: the eligibility tests build their own synthetic pools, so
  the real source pool earns no weight here.

Neither is an oversight.
