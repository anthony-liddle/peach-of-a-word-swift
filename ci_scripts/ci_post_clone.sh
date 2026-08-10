#!/bin/bash
#
# Xcode Cloud post-clone step.
#
# Apple runs `ci_scripts/ci_post_clone.sh` automatically after cloning, from a
# directory named `ci_scripts` sitting beside the .xcodeproj. Two details from
# the docs that fail silently if got wrong, so both are handled explicitly
# below: the script must be committed executable or Xcode Cloud runs it as
# `zsh $filename` regardless of the shebang, and it runs with **ci_scripts as
# the working directory**, not the repository root.
#
# What it does:
#
#   1. Regenerates PeachOfAWord.xcodeproj from project.yml.
#   2. Sets the build number from CI_BUILD_NUMBER.
#
# Step 1 is not an optimisation. The .xcodeproj is not in the repository, so a
# fresh clone has no project to build and this script is the only thing that
# creates one. It was committed for a while, which made it a second source of
# truth: change project.yml, forget to regenerate, and Cloud builds the stale
# project without complaining. Regenerating here is what made dropping it safe.
#
# Nothing here runs locally. A local `xcodebuild archive` sees an unmodified
# project.yml and the committed build number.

set -euo pipefail

# Pinned. An unpinned tool that rewrites the project on every build is the same
# class of problem this script exists to remove: a newer XcodeGen could emit a
# different project than the one reviewed, and nobody would be told.
XCODEGEN_VERSION="2.46.0"

# SHA-256 of that release's xcodegen.zip, checked before anything is unpacked
# or run.
#
# A version tag is not an integrity guarantee. A GitHub release asset can be
# replaced in place without the tag changing, so pinning only the version means
# every build downloads and executes whatever currently sits at that URL. This
# script runs with the repository checked out and the signing chain available,
# so "whatever currently sits at that URL" is not a risk worth carrying for the
# sake of four megabytes.
#
# Trust-on-first-use: the value below was taken from the bytes GitHub served on
# 2026-08-09, confirmed identical across two independent fetches. It does not
# prove the release was honest that day. It does guarantee that every build
# from now on runs the same binary as the one reviewed, and that a later
# substitution fails the build loudly instead of executing.
#
# Update deliberately, together with XCODEGEN_VERSION, never to silence a
# failure:
#   curl -fsSL .../<version>/xcodegen.zip | shasum -a 256
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

# CI_BUILD_NUMBER is per-workflow and starts at 1. Builds 1 and 2 were uploaded
# by hand before Xcode Cloud existed, and App Store Connect permanently reserves
# every build number it accepts, so an unoffset first Cloud build would be
# rejected as a duplicate. 100 clears those two with room, and makes a
# Cloud-built number obvious on sight.
BUILD_NUMBER_OFFSET=100

say() { echo "[ci_post_clone] $*"; }
fail() { echo "[ci_post_clone] ERROR: $*" >&2; exit 1; }

# Xcode Cloud sets the working directory to ci_scripts. The fallback keeps the
# script runnable by hand from anywhere, which is how it gets tested.
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT" || fail "cannot enter repository root: $REPO_ROOT"
say "repository root: $(pwd)"
[ -f project.yml ] || fail "no project.yml at $(pwd); wrong directory"

# ---------------------------------------------------------------------------
# XcodeGen
# ---------------------------------------------------------------------------
#
# The prebuilt release rather than Homebrew. Xcode Cloud bills against 25
# compute hours a month and this runs on every single build, so the difference
# is worth caring about: the zip is 4MB and unpacks in well under a second,
# where `brew install xcodegen` is tens of seconds at best and needs Homebrew
# present at all. No install step, no PATH surgery, nothing left behind.

TOOLS_DIR="$(pwd)/.ci-tools"
XCODEGEN="$TOOLS_DIR/xcodegen/bin/xcodegen"

say "fetching XcodeGen $XCODEGEN_VERSION"
rm -rf "$TOOLS_DIR"
mkdir -p "$TOOLS_DIR"
# -f so an HTTP error is a failure rather than a zip full of error page.
curl -fsSL \
  -o "$TOOLS_DIR/xcodegen.zip" \
  "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" \
  || fail "could not download XcodeGen $XCODEGEN_VERSION"

# Verified before unpacking, not after. An archive is untrusted input until its
# hash matches, and unzip acts on the archive's own contents.
actual_sha="$(shasum -a 256 "$TOOLS_DIR/xcodegen.zip" | cut -d' ' -f1)"
if [ "$actual_sha" != "$XCODEGEN_SHA256" ]; then
  fail "XcodeGen $XCODEGEN_VERSION checksum mismatch, refusing to run it
    expected $XCODEGEN_SHA256
    actual   $actual_sha
  The release asset at that URL is not the reviewed one. Do not update the
  pinned hash to make this pass without establishing why it changed."
fi
say "checksum verified"

unzip -q "$TOOLS_DIR/xcodegen.zip" -d "$TOOLS_DIR" || fail "could not unpack XcodeGen"
[ -x "$XCODEGEN" ] || fail "XcodeGen binary missing at $XCODEGEN"
say "using $("$XCODEGEN" --version)"

# ---------------------------------------------------------------------------
# Build number
# ---------------------------------------------------------------------------
#
# Edited into project.yml *before* generating, so XcodeGen stays the only thing
# that writes the project. Patching the generated pbxproj afterwards would work
# and would be a second writer, which is the shape of the bug being fixed.
#
# This propagates to the bundle only because Info.plist reads
# $(CURRENT_PROJECT_VERSION) rather than carrying a literal. That was fixed in
# 722e74b; before it, setting the build setting changed nothing in the app.

EXPECTED_BUILD_NUMBER=""
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  EXPECTED_BUILD_NUMBER=$((CI_BUILD_NUMBER + BUILD_NUMBER_OFFSET))
  say "CI_BUILD_NUMBER=$CI_BUILD_NUMBER, +$BUILD_NUMBER_OFFSET -> $EXPECTED_BUILD_NUMBER"

  # A sed that matches nothing exits 0. Left unchecked, renaming or rewrapping
  # this line in project.yml would silently pin every Cloud build to whatever
  # literal is committed, which is precisely the drift 722e74b was about. So
  # the match is counted first and the result asserted at the end.
  matches=$(grep -c '^\([[:space:]]*\)CURRENT_PROJECT_VERSION:' project.yml || true)
  [ "$matches" -eq 1 ] \
    || fail "expected exactly 1 CURRENT_PROJECT_VERSION line in project.yml, found $matches"

  sed -i '' \
    -E "s|^([[:space:]]*)CURRENT_PROJECT_VERSION:.*|\1CURRENT_PROJECT_VERSION: \"${EXPECTED_BUILD_NUMBER}\"|" \
    project.yml
  say "project.yml: $(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | tr -s ' ')"
else
  say "no CI_BUILD_NUMBER; leaving the committed build number alone"
fi

# ---------------------------------------------------------------------------
# Generate, and prove it
# ---------------------------------------------------------------------------

say "generating PeachOfAWord.xcodeproj"
"$XCODEGEN" generate --spec project.yml || fail "xcodegen generate failed"

PBXPROJ="PeachOfAWord.xcodeproj/project.pbxproj"
[ -f "$PBXPROJ" ] || fail "no project generated at $PBXPROJ"

# Assert the settings that matter actually landed. Everything above can succeed
# and still produce a project that builds the wrong thing, so the check is on
# the artefact rather than on the exit codes that made it.
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.anthonyliddle.peachofaword;' "$PBXPROJ" \
  || fail "generated project has the wrong bundle identifier"

if [ -n "$EXPECTED_BUILD_NUMBER" ]; then
  grep -q "CURRENT_PROJECT_VERSION = ${EXPECTED_BUILD_NUMBER};" "$PBXPROJ" \
    || fail "generated project does not carry build number $EXPECTED_BUILD_NUMBER"
  say "build number $EXPECTED_BUILD_NUMBER confirmed in the generated project"
fi

# One quirk worth knowing if this project is ever diffed against a locally
# generated one: XcodeGen names the local package group after the checkout
# directory, so it reads `repository` here and `peach-of-a-word-swift` on a
# normal clone. A display name in the Packages group, nothing that gets built.
# It was the reason the project could never be committed reproducibly.
say "done"
