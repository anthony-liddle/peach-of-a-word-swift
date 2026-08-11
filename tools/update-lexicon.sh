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
# here: SNAPSHOT.md documents meta.json describing a build that no longer
# shipped, for six weeks, with the numbers quoted into a published essay.
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
VERSION="v1.0.2"
ARCHIVE="lexicon.tar.gz"
ARCHIVE_SHA256="65cd01f592fb83d22d2c4228743f985f144ce55cec8e55386c600365826a204b"

# sha256 per file, as published in the release's checksums.txt.
FILES=(
  "enable.txt:689618c5348c28738ae3453575518e459bc0804c0f3cc3ad8c4af6b2441ea4e0"
  "scowl95-additions.txt:dbc6347327b3237b2a5ebb22f55227b193be386d882da1863add2d1353233b7c"
  "common-pool.txt:560c246b7a078889b5b4a84df67f8f9bc833e778c28259ee36950603fc3db361"
  "beyond-size-70.txt:4af0676fdd320c86889e5fc06a2bff4b06a5052e16d3442e60000dc9fa0ba285"
  "beyond-size-95.txt:8b4a39ab5b62739ffe4d8408117e3d4fe8f2e8ae271fb0deaae1666eaca5e257"
)

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
  for entry in "${FILES[@]}"; do
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
# gh rather than curl because orchard is private. On a public repo this becomes
# a plain https download with no auth.
gh release download "$VERSION" --repo "$REPO" --pattern "$ARCHIVE" --dir "$WORK" \
  || fail "could not download $ARCHIVE from $REPO $VERSION"

actual_sha="$(hash_of "$WORK/$ARCHIVE")"
if [ "$actual_sha" != "$ARCHIVE_SHA256" ]; then
  fail "archive checksum mismatch, refusing to unpack.
    expected $ARCHIVE_SHA256
    actual   $actual_sha
  The asset at that tag is not the reviewed one. Do not update the pinned hash
  to make this pass without establishing why it changed."
fi
say "archive checksum verified"

tar -xzf "$WORK/$ARCHIVE" -C "$WORK" || fail "could not unpack $ARCHIVE"
UNPACKED="$WORK/lexicon"

for entry in "${FILES[@]}"; do
  name="${entry%%:*}"
  expected="${entry##*:}"
  actual="$(hash_of "$UNPACKED/$name")"
  [ "$actual" = "$expected" ] || fail "$name checksum mismatch after unpacking.
    expected $expected
    actual   $actual"
  cp "$UNPACKED/$name" "$DATA_DIR/$name"
  echo "  wrote  $name"
done

# meta.json's list counts are recomputed from what was just written.
#
# This step was missing from the first version of this script, and its absence
# reintroduced the exact defect SNAPSHOT.md documents: meta.json describing a
# build that no longer ships. Previously meta.json travelled with the lists as
# one snapshot, so copying the lists copied the counts. Now this script writes
# the lists and nothing else does, so the obligation moved here with them.
#
# Caught by SmokeTests.metaJSONMatchesShippedLists on the round-trip test, which
# is the test that was inverted rather than deleted precisely so it would keep
# having an opinion about this file.
#
# Only the six list counts change. sourcePool and definitionsCovered describe
# the crown pool and the definition bundles, neither of which this app ships,
# and they are carried through untouched rather than invented.
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
