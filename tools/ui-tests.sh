#!/bin/bash
#
# Run UI tests on this machine: the smoke set, named classes, or all of them.
#
#   tools/ui-tests.sh smoke                  the smoke set, about five minutes
#   tools/ui-tests.sh smoke TapTheWell ...   the smoke set and the classes named
#   tools/ui-tests.sh only TapTheWell ...    just the classes named
#   tools/ui-tests.sh all                    every class, in one sequence
#
#   DEVICE='iPhone SE (3rd generation)' tools/ui-tests.sh smoke
#
# ---------------------------------------------------------------------------
# WHEN TO RUN WHAT, from CONTRIBUTING.md.
#
# Before a push: the classes the change touches, plus the smoke set. CI runs
# every class on every code change, in parallel, and is the source of truth for
# the suite. `all`, on an SE and on a Pro Max, is for a build about to go to
# App Review: in October 2026 that pair took 90 to 100 minutes.
#
# The smoke set is `.github/ui-tests/smoke.txt`, beside the lists CI reads.
#
# ---------------------------------------------------------------------------
# HOW.
#
# The project is regenerated first if it went stale (`tools/xcodeproj.sh`),
# built once for testing into .build/ui-tests, and then run with
# `test-without-building`, which is what CI's shards do. The result bundle is
# .build/ui-tests/last.xcresult.
#
# Package resolution is off, as it is in CI: a resolution here would rewrite
# Package.resolved, which Xcode Cloud builds from.
#
# DEVICE is a simulator name, and the newest runtime that has it is used.
# Default: the iPhone 17 Pro, the phone CI's runner has.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
DEVICE=${DEVICE:-iPhone 17 Pro}
DD="$ROOT/.build/ui-tests"
MODE=${1:-}
[ $# -gt 0 ] && shift

case "$MODE" in
  smoke) CLASSES="$(python3 .github/ui-tests/plan.py classes smoke.txt) $*" ;;
  only)
    [ $# -gt 0 ] || { echo "only: name at least one class" >&2; exit 2; }
    CLASSES="$*" ;;
  all) CLASSES="" ;;
  *)
    sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2 ;;
esac

tools/xcodeproj.sh >/dev/null
xcodebuild build-for-testing \
  -project PeachOfAWord.xcodeproj \
  -scheme PeachOfAWordUITests \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -disableAutomaticPackageResolution \
  -derivedDataPath "$DD" \
  -quiet

ONLY=()
for class in $CLASSES; do ONLY+=("-only-testing:PeachOfAWordUITests/$class"); done
rm -rf "$DD/last.xcresult"
echo "running ${CLASSES:-every class} on $DEVICE"
xcodebuild test-without-building \
  -xctestrun "$(ls "$DD"/Build/Products/*.xctestrun | head -1)" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  ${ONLY[@]+"${ONLY[@]}"} \
  -resultBundlePath "$DD/last.xcresult"
