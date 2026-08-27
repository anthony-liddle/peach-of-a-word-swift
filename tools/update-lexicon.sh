#!/bin/bash
#
# Update Data/'s word lists from a pinned orchard release, or check them.
#
#   tools/update-lexicon.sh            fetch the pinned release and write the lists
#   tools/update-lexicon.sh --check    verify the committed lists, no network, no writes
#
# Shell rather than Node deliberately. This repo already has exactly one script
# that fetches a pinned artifact and verifies it before use, ci_post_clone.sh,
# and this is the same job with the same hazards. Matching it means one idiom to
# learn rather than two, and no toolchain the Swift side does not already need.
#
# ---------------------------------------------------------------------------
# WHY THE LISTS STAY COMMITTED.
#
# The obvious design has ci_post_clone.sh fetch the lexicon on every Cloud
# build. Rejected for two reasons. Xcode Cloud bills against 25 compute hours a
# month and that script already argues, in detail, for a 4MB download over a
# Homebrew install on exactly those grounds; adding an 8MB fetch to every build
# spends the same budget for nothing, since the words change a few times a year.
# And a build that fetches is a build that fails when GitHub does.
#
# So the copy stays committed and this script updates it deliberately. The cost
# of a committed copy is that it can drift from the release it claims to be,
# which is what --check exists for. CI runs it, so drift becomes a failing job
# rather than a discovery six weeks later. That failure mode is not theoretical
# here: meta.json described a build that no longer shipped, for six weeks, with
# the numbers quoted into a published essay. See docs/PORT-LOG.md.
# ---------------------------------------------------------------------------
#
# INTEGRITY. Two levels, because they answer different questions. The archive's
# SHA-256 is checked before anything is unpacked, since an archive is untrusted
# input until its hash matches and tar acts on the archive's own contents. Each
# file's SHA-256 is checked after, because tar is not reproducible across
# platforms, so "are these the reviewed words" cannot be derived from "is this
# the reviewed archive".
#
# A version tag is not an integrity guarantee: a GitHub release asset can be
# replaced in place without the tag moving. Same argument as the XcodeGen pin.
# Update the pins deliberately, together, never to silence a failure.

set -euo pipefail

REPO="anthony-liddle/orchard"
# Bumping this couples to three literals in
# Tests/PeachEngineTests/ShippedDefinitionsTests.swift: the corpus row count,
# the spaced-hyphen count, and the exact text pinned for each known defect.
# They are literals on purpose, so a release that changes the corpus makes
# somebody look at the numbers rather than inherit them. Expect those tests to
# fail on a bump; read the diff before editing them, and never loosen one to
# make a bump quiet.
VERSION="v1.5.0"

# ---------------------------------------------------------------------------
# THE ARCHIVES THIS REPOSITORY TAKES FROM A RELEASE.
#
# One row per release asset, four fields separated by `|`:
#
#   archive | archive-sha256 | directory inside the archive | files
#
# and `files` is a comma-separated list of `name:sha256`, exactly as the
# release's checksums.txt publishes them.
#
# **Why two delimiters rather than one.** The obvious form nests colons all the
# way down, and it cannot be parsed by the `${row%%:*}` / `${row##*:}` pair this
# script already uses to pull a name and a hash apart, because those take the
# first and last colon of the whole row. Splitting the outer fields on `|` keeps
# the inner `name:sha256` in exactly the shape those two expansions already
# read, so the parsing below is the parsing that was here before, wrapped in one
# more loop. Bash has no nested arrays; this is the cheapest honest stand-in.
#
# One VERSION for every row, deliberately. Both assets are cut from the same
# orchard tag, so a per-archive version would be a knob describing a situation
# that does not exist. If etymology ever releases on its own cadence, this is
# where that changes, and the change is a fifth field.
#
# **The definitions row rides on the licensing act the etymology row took, and
# adds no new question.** Same corpus, same upstream, same CC BY-SA 4.0, same
# obligation already discharged in `Data/ATTRIBUTION.md`. What it adds is
# 1.45 MiB to a directory that ships 8.36 MB, an 18 percent increase, for the
# 24,892 short glosses behind the tappable found-word chips.
#
# **The web's 793 per-rack shards are deliberately not taken.** They exist so a
# browser fetches 4 KB rather than 1.5 MB, which is a property of HTTP and not
# of the corpus. An app has already shipped the whole binary before it opens, so
# the shards would buy nothing and cost 793 files in the bundle. One file, read
# once at launch into a dictionary, is the shape `etymology.tsv` already uses.
#
# **The etymology row is the licensing act, and it has been taken.** The corpus
# is Wiktionary text under CC BY-SA 4.0. 799 entries covering 615 of the 626
# calendar crowns: the other eleven have no usable English etymology on
# Wiktionary and are skipped on purpose, so their reveal card is quiet. It was listed here on 2026-08-14, on Antoine's decision, after the
# option space was established as: Wiktionary or no etymology at all. See
# `Definitions Source Decision.md`. Shipping it obliges the attribution in
# `Data/ATTRIBUTION.md`, which travels inside the bundle, and that obligation is
# discharged in the same change rather than owed after it.
#
# **On the two hashes moving differently.** v1.2.0 changed lexicon.tar.gz's
# archive hash and none of its five file hashes, because tar is not reproducible
# across packings and the words did not change. That is the expected shape of a
# release that only repacked. If a file hash ever needs editing on such a
# release, something is wrong; do not edit it to make a check pass.
# ---------------------------------------------------------------------------
ARCHIVES=(
  "lexicon.tar.gz|e386779b6dd533298ec64c56bb52fcef6200c2566cd51a38012ab186655816f6|lexicon|enable.txt:3be67be18b42d1903911f16f008c2cf7754cef4dfce2bcff448e8d7f94854a6b,scowl95-additions.txt:a636a359b0d0fd8de1db338c24893f87d09978eaaa3eff81c4eb7e370426f173,common-pool.txt:10fa33188c8de4fc0d047f0993165365e12d6e739e1072a1275ee94c1fab928f,beyond-size-70.txt:556c91aa84c6aaad7ab80d6b942fc1349acd6304624089acb1e575991f83c171,beyond-size-95.txt:3bf2bd8af9952e76bb1621b93c75710e47e61fd707444637e391138f45f1eef9"
  "etymology.tar.gz|14e00abbffc358bfd3ab1e763551c840d330f30eaa0e7401ccdd31ffb27c5fb6|etymology|etymology.tsv:d51a4dc38a1cf73d50549b2d176da74db91852b711a4a93348ecd6e02bd44ea0"
  "definitions.tar.gz|6578f0e91534b31b44c6b177b2a3df79dece03433d2e16ffde626f2b03ec3ef4|definitions|definitions.tsv:4297d44de6fb478b8fb94a1b66b04692889e4af3f6008ca25cb2fca8f3c9728a"
)

# Split one ARCHIVES row into the four globals the loops below read.
read_archive_row() {
  IFS='|' read -r ROW_ARCHIVE ROW_SHA256 ROW_DIR ROW_FILES <<< "$1"
  [ -n "$ROW_ARCHIVE" ] && [ -n "$ROW_SHA256" ] && [ -n "$ROW_DIR" ] && [ -n "$ROW_FILES" ] \
    || fail "malformed ARCHIVES row: $1"
  # The comma-separated file list, as an array of name:sha256 pairs.
  IFS=',' read -r -a ROW_FILE_LIST <<< "$ROW_FILES"
}

say() { echo "[lexicon] $*"; }
fail() { echo "[lexicon] ERROR: $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$REPO_ROOT/Data"
[ -d "$DATA_DIR" ] || fail "no Data directory at $DATA_DIR"

hash_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

# ---------------------------------------------------------------------------
# --check: offline, no writes. This is the CI job.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
  say "checking committed lists against $VERSION"
  bad=0
  for row in "${ARCHIVES[@]}"; do
    read_archive_row "$row"
    for entry in "${ROW_FILE_LIST[@]}"; do
      name="${entry%%:*}"
      expected="${entry##*:}"
      path="$DATA_DIR/$name"
      if [ ! -f "$path" ]; then
        echo "  MISSING  $name"; bad=$((bad + 1)); continue
      fi
      actual="$(hash_of "$path")"
      if [ "$actual" = "$expected" ]; then
        echo "  ok       $name"
      else
        echo "  MISMATCH $name"
        echo "    committed $actual"
        echo "    $VERSION   $expected"
        bad=$((bad + 1))
      fi
    done
  done
  [ "$bad" -eq 0 ] || fail "$bad committed list(s) do not match $VERSION. Either
    run tools/update-lexicon.sh, or work out why they diverged. Do not edit the
    pinned hashes to make this pass."
  say "committed lists match $VERSION."
  exit 0
fi

# ---------------------------------------------------------------------------
# Update.
# ---------------------------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "fetching $REPO $VERSION"

for row in "${ARCHIVES[@]}"; do
  read_archive_row "$row"

  # gh rather than curl because orchard is private. On a public repo this
  # becomes a plain https download with no auth.
  gh release download "$VERSION" --repo "$REPO" --pattern "$ROW_ARCHIVE" --dir "$WORK" \
    || fail "could not download $ROW_ARCHIVE from $REPO $VERSION"

  actual_sha="$(hash_of "$WORK/$ROW_ARCHIVE")"
  if [ "$actual_sha" != "$ROW_SHA256" ]; then
    fail "archive checksum mismatch on $ROW_ARCHIVE, refusing to unpack.
    expected $ROW_SHA256
    actual   $actual_sha
  The asset at that tag is not the reviewed one. Do not update the pinned hash
  to make this pass without establishing why it changed."
  fi
  say "archive checksum verified: $ROW_ARCHIVE"

  tar -xzf "$WORK/$ROW_ARCHIVE" -C "$WORK" || fail "could not unpack $ROW_ARCHIVE"
  UNPACKED="$WORK/$ROW_DIR"

  for entry in "${ROW_FILE_LIST[@]}"; do
    name="${entry%%:*}"
    expected="${entry##*:}"
    actual="$(hash_of "$UNPACKED/$name")"
    [ "$actual" = "$expected" ] || fail "$name checksum mismatch after unpacking.
    expected $expected
    actual   $actual"
    cp "$UNPACKED/$name" "$DATA_DIR/$name"
    echo "  wrote  $name"
  done
done

# meta.json's list counts are recomputed from what was just written.
#
# This step was missing from the first version of this script, and its absence
# reintroduced the exact defect recorded in docs/PORT-LOG.md: meta.json
# describing a build that no longer ships. Previously meta.json travelled with the lists as
# one snapshot, so copying the lists copied the counts. Now this script writes
# the lists and nothing else does, so the obligation moved here with them.
#
# Caught by SmokeTests.metaJSONMatchesShippedLists on the round-trip test, which
# is the test that was inverted rather than deleted precisely so it would keep
# having an opinion about this file.
#
# Only the six list counts change. sourcePool and definitionsCovered are carried
# through untouched rather than invented, and the reason has now narrowed to
# nothing: this app ships both of the things they count. sourcePool counts the
# 793 crown candidates, and this app ships etymology for 820 words including all
# 626 the calendar can deal. definitionsCovered counts the definition corpus,
# which as of this change ships here too.
#
# **definitionsCovered says 24833 and the file it counts has 24,892 rows.** It is
# carried through anyway, and not because the discrepancy is acceptable on its
# own terms. meta.json has to stay byte-identical with the web's serialiseMeta
# output, so correcting it here would be a one-repo edit to a two-repo file and
# the next --check would be comparing this repo against a number only this repo
# believes. The stale figure is the web's to move. Recorded rather than fixed,
# and recorded rather than left for someone to trip over: the count in this file
# is not a number to reason from, and the corpus itself is the thing to count.
#
# No key is added for that coverage, deliberately. meta.json has to stay
# byte-identical with the web's serialiseMeta output, so a new key here is a
# change to the other repository as well, and nothing reads it: the coverage
# claim is asserted by ShippedSourceEntriesTests against the corpus itself,
# which cannot go stale the way a recorded number can.
say "recomputing meta.json list counts"
python3 - "$DATA_DIR" <<'PYEOF'
import json, sys, pathlib
data = pathlib.Path(sys.argv[1])
def count(name):
    return len([w for w in (data / name).read_text().split("\n") if w.strip()])
meta_path = data / "meta.json"
meta = json.loads(meta_path.read_text())
enable = count("enable.txt")
additions = count("scowl95-additions.txt")
meta["counts"].update({
    "enable": enable,
    "scowl95Additions": additions,
    "boundary": enable + additions,
    "common": count("common-pool.txt"),
    "beyond70": count("beyond-size-70.txt"),
    "beyond95": count("beyond-size-95.txt"),
})
# No trailing newline: the web's serialiseMeta writes
# JSON.stringify(meta, null, 2) and nothing after it, and these two files
# must stay byte-identical.
meta_path.write_text(json.dumps(meta, indent=2))
print(f"  meta.json rewritten: {enable + additions:,} boundary words")
PYEOF

# Data/ATTRIBUTION.md is this repo's own, written to carry the SCOWL notice
# inside the app bundle, and is not overwritten from the archive. The archive
# carries its own copy for consumers that have none.
#
# daily-calendar.json and meta.json are game data and are not in the archive.

say "updated to $VERSION. Review the diff: an empty one means the committed
    lists already matched."
