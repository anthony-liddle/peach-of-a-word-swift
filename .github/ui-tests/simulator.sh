#!/bin/bash
#
# Boot the runner's first iPhone simulator, and optionally move its time zone,
# before any test's clock starts.
#
#   .github/ui-tests/simulator.sh <Build/Products dir> [zone]
#
# Writes UDID=<the simulator> to $GITHUB_ENV for the steps after it.
#
# The simulator is resolved rather than named, for the reason the workflow
# gives: a name is a guess about a machine image that changes without notice.
set -euo pipefail

PRODUCTS=${1:?usage: simulator.sh <Build/Products dir> [zone]}
ZONE=${2:-}

UDID=$(xcrun simctl list devices available \
  | awk -F'[()]' '/^ *iPhone/ {print $2; exit}')
if [ -z "$UDID" ]; then
  echo "no iPhone simulator available on this runner" >&2
  xcrun simctl list devices available >&2
  exit 1
fi
echo "using simulator $UDID"
echo "UDID=$UDID" >> "${GITHUB_ENV:-/dev/null}"

# `boot` returns before the simulator is usable; `bootstatus -b` waits until it
# is. Already booted is not an error.
start=$(date +%s)
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
echo "booted in $(( $(date +%s) - start ))s"

# `launchctl setenv` inside the simulator, because a job-level `TZ` does not
# reach a simulator process. Both the app and the test runner inherit it,
# including apps XCUITest launches.
if [ -n "$ZONE" ]; then
  xcrun simctl spawn "$UDID" launchctl setenv TZ "$ZONE"
  echo "simulator zone $ZONE"
fi
[ -d "$PRODUCTS/Debug-iphonesimulator/PeachOfAWord.app" ] \
  || { echo "no app in $PRODUCTS" >&2; exit 1; }
