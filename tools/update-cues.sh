#!/bin/bash
#
# Update Data/peach.cues.json, the game's sounds, from a pinned commit of the
# web game, or check it.
#
#   tools/update-cues.sh <web commit>   fetch the cue file at that commit, check
#                                        it against the pin, and write the copy
#   tools/update-cues.sh --check         verify the committed copy, no network,
#                                        no writes
#
# The cue file is the web game's `src/audio/peach.cues.json`, written there by
# `scripts/build-sound-cues.ts`: 34 cues, one for each sound the game makes.
# The web is its source of truth, so both games play the same sounds from one
# document, and this app holds a copy, the way it holds orchard's word lists.
#
# ---------------------------------------------------------------------------
# WHY A COMMIT AND A HASH, NOT A RELEASE.
#
# `tools/update-lexicon.sh` pins orchard by release, because orchard publishes
# releases. The web repository publishes none, so the pin is a commit of it and
# the file's SHA-256 at that commit. The commit says where the file came from;
# the hash is what is checked, here and in CI. A commit is immutable where a
# release asset is not, but a raw URL is still a download, so the bytes are
# checked before they are written, and a mismatch is a refusal, not a warning.
#
# WHY IT MUST ALSO EQUAL SOUNDSCAPE'S CONFORMANCE COPY.
#
# Soundscape, the package that plays these, holds its Swift renders to
# Chromium's and WebKit's on its own copy of this file,
# `conformance/cues/cases/peach-of-a-word.json`. That copy is the document the
# player is proved against. A cue file that differs from it would play sounds
# nobody has compared with the browsers, so the update refuses unless the web's
# file and the conformance copy at the package's pinned version are the same
# bytes. Moving either pin is then a decision about both.
# ---------------------------------------------------------------------------
#
# Update the pin deliberately, WEB_COMMIT and CUES_SHA256 together, never to
# silence a failure. The same argument as the XcodeGen and lexicon pins.

set -euo pipefail

# The commit of `anthony-liddle/peach-of-a-word` the copy was taken from: the
# commit that last changed the file, #147 on 2026-10-07, "the game's sounds on
# Soundscape, held to the old engine in three browsers". It is on `main`.
WEB_COMMIT="442ceb43282ddc96b7333cf428f917cabb2682ba"
CUES_SHA256="b66a60d767bd4fc804945a1f78d0d2acfa60a2168be279ffb848b388445f615f"

# The Soundscape version whose conformance copy CUES_SHA256 equals. --check
# reads Package.resolved and fails if the app has moved to another version
# without anyone checking the cue file against that version's copy.
SOUNDSCAPE_VERSION="0.2.0"

WEB_REPO="anthony-liddle/peach-of-a-word"
WEB_PATH="src/audio/peach.cues.json"
SOUNDSCAPE_REPO="anthony-liddle/soundscape"
CONFORMANCE_PATH="conformance/cues/cases/peach-of-a-word.json"

say() { echo "[cues] $*"; }
fail() { echo "[cues] ERROR: $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COPY="$REPO_ROOT/Data/peach.cues.json"
RESOLVED="$REPO_ROOT/PeachOfAWord.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

hash_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

# The Soundscape version Package.resolved pins, or nothing.
resolved_soundscape_version() {
  [ -f "$RESOLVED" ] || return 0
  grep -A8 '"identity" : "soundscape"' "$RESOLVED" \
    | sed -n 's/.*"version" : "\(.*\)".*/\1/p' | head -1
}

# ---------------------------------------------------------------------------
# --check: offline, no writes. This is the CI job.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
  say "checking Data/peach.cues.json against $WEB_REPO@${WEB_COMMIT:0:7}"
  [ -f "$COPY" ] || fail "no Data/peach.cues.json. Run tools/update-cues.sh $WEB_COMMIT."
  actual="$(hash_of "$COPY")"
  if [ "$actual" != "$CUES_SHA256" ]; then
    fail "Data/peach.cues.json does not match the pin.
    committed $actual
    pinned    $CUES_SHA256
  Either run tools/update-cues.sh $WEB_COMMIT, or work out why it diverged. Do
  not edit the pinned hash to make this pass."
  fi
  say "ok: $actual"

  resolved="$(resolved_soundscape_version)"
  [ -n "$resolved" ] || fail "no Soundscape pin in $RESOLVED"
  if [ "$resolved" != "$SOUNDSCAPE_VERSION" ]; then
    fail "Package.resolved pins Soundscape $resolved, and the cue file was checked
  against $SOUNDSCAPE_VERSION's conformance copy. Run tools/update-cues.sh
  $WEB_COMMIT to compare it with $resolved's, then move SOUNDSCAPE_VERSION."
  fi
  say "ok: Soundscape $resolved, the version the cue file was checked against."
  exit 0
fi

# ---------------------------------------------------------------------------
# Update.
# ---------------------------------------------------------------------------
COMMIT="${1:-}"
[[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]] \
  || fail "usage: tools/update-cues.sh <web commit>, a full 40-character SHA, or --check"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# curl rather than gh: both repositories are public, so a raw URL needs no
# auth. -f so an HTTP error is a failure rather than a file full of error page.
say "fetching $WEB_PATH at $WEB_REPO@${COMMIT:0:7}"
curl -fsSL -o "$WORK/web.json" \
  "https://raw.githubusercontent.com/$WEB_REPO/$COMMIT/$WEB_PATH" \
  || fail "could not fetch $WEB_PATH at $COMMIT"

actual="$(hash_of "$WORK/web.json")"
if [ "$actual" != "$CUES_SHA256" ]; then
  fail "$WEB_PATH at ${COMMIT:0:7} does not match the pin, so nothing was written.
    fetched $actual
    pinned  $CUES_SHA256
  If the web's cues changed on purpose, set WEB_COMMIT and CUES_SHA256 in this
  script to this commit and this hash, together, and run it again."
fi
say "matches the pin: $actual"
[ "$COMMIT" = "$WEB_COMMIT" ] \
  || say "note: the file is the pinned one, but WEB_COMMIT names ${WEB_COMMIT:0:7}, not ${COMMIT:0:7}."

version="$(resolved_soundscape_version)"
[ -n "$version" ] || fail "no Soundscape pin in $RESOLVED"
say "fetching Soundscape $version's conformance copy"
curl -fsSL -o "$WORK/conformance.json" \
  "https://raw.githubusercontent.com/$SOUNDSCAPE_REPO/$version/$CONFORMANCE_PATH" \
  || fail "could not fetch $CONFORMANCE_PATH at Soundscape $version"
conformance="$(hash_of "$WORK/conformance.json")"
if [ "$conformance" != "$actual" ]; then
  fail "the web's cue file is not Soundscape $version's conformance copy, so
  nothing was written.
    web          $actual
    conformance  $conformance
  The renderer is held to the browsers on the conformance copy. Move the web pin
  and the package together, to a pair whose files agree."
fi
[ "$version" = "$SOUNDSCAPE_VERSION" ] \
  || say "note: Package.resolved pins Soundscape $version; set SOUNDSCAPE_VERSION to it."
say "equals Soundscape $version's conformance copy"

cp "$WORK/web.json" "$COPY"
say "wrote Data/peach.cues.json. Review the diff: an empty one means the copy
    already matched."
