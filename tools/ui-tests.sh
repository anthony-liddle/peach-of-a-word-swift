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
# DEVICE is a simulator's name, or its UDID. A name is looked up here, on the
# newest runtime that has it, and passed on by UDID: `name=` alone makes
# xcodebuild assume the newest runtime, and fails if the device is on an older
# one, as the iPhone 17 Pro is on a machine with iOS 27. Default: the iPhone
# 17 Pro, the phone CI's runner has. A missing one can be made, for example
# the SE:
#
#   xcrun simctl create 'iPhone SE (3rd generation)' \
#     com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation \
#     com.apple.CoreSimulator.SimRuntime.iOS-27-0
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

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
want = sys.argv[1]
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    version = [int(n) for n in re.findall(r"\d+", runtime.rsplit(".", 1)[-1])]
    for d in devices:
        if want in (d["name"], d["udid"]):
            found.append((version, d["udid"]))
print(max(found)[1] if found else "")
' "$DEVICE")
if [ -z "$UDID" ]; then
  echo "no available simulator named $DEVICE; these are:" >&2
  xcrun simctl list devices available | grep -E "^--|^ +" >&2
  exit 2
fi

tools/xcodeproj.sh >/dev/null
xcodebuild build-for-testing \
  -project PeachOfAWord.xcodeproj \
  -scheme PeachOfAWordUITests \
  -destination "id=$UDID" \
  -disableAutomaticPackageResolution \
  -derivedDataPath "$DD" \
  -quiet

ONLY=()
for class in $CLASSES; do ONLY+=("-only-testing:PeachOfAWordUITests/$class"); done
rm -rf "$DD/last.xcresult"
echo "running ${CLASSES:-every class} on $DEVICE ($UDID)"
xcodebuild test-without-building \
  -xctestrun "$(ls "$DD"/Build/Products/*.xctestrun | head -1)" \
  -destination "id=$UDID" \
  ${ONLY[@]+"${ONLY[@]}"} \
  -resultBundlePath "$DD/last.xcresult"
