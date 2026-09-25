#!/bin/bash
#
# Regenerate PeachOfAWord.xcodeproj from project.yml, and say whether it had
# gone stale.
#
#   tools/xcodeproj.sh            regenerate, and report whether it was stale
#   tools/xcodeproj.sh --check    the same, but exit non-zero if it WAS stale
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS.
#
# The .xcodeproj is generated and is not in the repository. ci_post_clone.sh
# regenerates it on every Xcode Cloud build, and its own comment explains why
# that mattered: the project was committed for a while, which made it a second
# source of truth, and "change project.yml, forget to regenerate, and Cloud
# builds the stale project without complaining". Regenerating in CI is what
# made dropping it safe.
#
# That same comment ends with the gap this script closes: "Nothing here runs
# locally." CI was made safe. A working copy never was. Nothing regenerates the
# project on checkout, on pull, or on a branch switch, so a working copy can
# carry a project that disagrees with project.yml for as long as nobody looks.
#
# WHAT THAT LOOKS LIKE WHEN IT BITES, because it does not look like staleness.
# On 2026-09-24 the UI tests could not be run at all:
#
#   error: Build input file cannot be found:
#     UITests/CreditProbe.swift (in target 'PeachOfAWordUITests')
#   ** TEST FAILED **
#
# CreditProbe.swift had been deleted. project.yml had never heard of it. Only
# the stale local project still listed it. The message names a missing source
# file, which sends you looking for a deleted file or a bad merge, and says
# nothing about the project being out of date. Meanwhile CI was green on the
# same commit, which is the most misleading possible pair of signals: the thing
# on your machine is broken and the thing everyone else sees is fine.
#
# A SCRIPT RATHER THAN A LINE IN THE README. A README line is read once, by
# whoever is setting up, and then never again, which is precisely wrong for a
# failure that arrives weeks later on an ordinary pull. This is one word to run
# and safe to run habitually.
#
# It cannot be made automatic without a git hook, and this repository has no
# hook infrastructure, so what it buys is that the fix is cheap and obvious
# rather than that it is unavoidable. Run it when a build fails oddly, and
# after any pull that touched project.yml or added or deleted a source file.
# ---------------------------------------------------------------------------

set -euo pipefail

fail() { echo "[xcodeproj] ERROR: $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

[ -f project.yml ] || fail "no project.yml at $REPO_ROOT"

command -v xcodegen >/dev/null 2>&1 \
  || fail "xcodegen is not installed. brew install xcodegen"

# The version CI pins, read from ci_post_clone.sh rather than written twice.
# A newer XcodeGen can emit a different project from the one CI builds, which
# would make a local build and a Cloud build disagree for a reason neither
# reports. Warn rather than refuse: a mismatch is usually harmless and being
# unable to work is worse than being told.
PINNED="$(sed -n 's/^XCODEGEN_VERSION="\(.*\)"$/\1/p' ci_scripts/ci_post_clone.sh)"
LOCAL="$(xcodegen --version 2>/dev/null | sed -n 's/^Version: //p')"
if [ -n "$PINNED" ] && [ -n "$LOCAL" ] && [ "$PINNED" != "$LOCAL" ]; then
  echo "[xcodeproj] warning: local xcodegen $LOCAL, CI pins $PINNED."
  echo "[xcodeproj]          A different XcodeGen can emit a different project."
fi

PBXPROJ="PeachOfAWord.xcodeproj/project.pbxproj"
BEFORE=""
[ -f "$PBXPROJ" ] && BEFORE="$(shasum -a 256 "$PBXPROJ" | awk '{print $1}')"

# Regenerated in place, always, even under --check.
#
# A read-only check is not available: XcodeGen resolves paths against the
# directory it writes into, so generating a copy elsewhere to compare against
# would differ for reasons that are not staleness. Regenerating in place is
# idempotent when the project is already current, which is what makes
# comparing the hash before and after a true answer rather than a guess.
xcodegen generate --quiet

AFTER="$(shasum -a 256 "$PBXPROJ" | awk '{print $1}')"

if [ -z "$BEFORE" ]; then
  echo "[xcodeproj] no project was present. Generated one from project.yml."
  exit 0
fi

if [ "$BEFORE" = "$AFTER" ]; then
  echo "[xcodeproj] already current: project.yml and the project agree."
  exit 0
fi

echo "[xcodeproj] THE PROJECT WAS STALE and has been regenerated."
echo "[xcodeproj] Anything that failed to build before this is worth retrying."
[ "$CHECK_ONLY" = "1" ] && exit 1
exit 0
