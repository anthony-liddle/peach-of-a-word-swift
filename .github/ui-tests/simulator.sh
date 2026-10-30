#!/bin/bash
#
# Boot the runner's first iPhone simulator, optionally move its time zone, and
# launch the app on it once through XCUITest, before any counted test.
#
#   .github/ui-tests/simulator.sh <Build/Products dir> [zone]
#
# Writes UDID=<the simulator> to $GITHUB_ENV for the steps after it.
#
# **The warm-up is the point.** A freshly booted simulator's first launch under
# XCUITest has missed its 60 seconds ("Timed out while launching application
# via Xcode"): on 22 and 27 October 2026 in the single job, and on 29 October
# in a shard. Every later launch in a run takes 2 to 3 seconds, and each shard
# boots its own simulator, so each would have that first launch.
#
# **Through XCUITest, because a plain launch did not warm it.** The first
# version installed and launched the app with `simctl`. On 29 October its
# launch took 7 seconds, and the shard's first test still timed out launching
# the app, so what is cold is XCUITest's path to the app, not the app. Now one
# short test runs in a session of its own (`plan.py warm-up` names it), its
# result set aside: its launch pays whatever is cold, and if that takes past
# 60 seconds, the miss is the warm-up's, not a counted test's. It fails this
# step only if it ran nothing, which would mean the class was renamed and the
# warm-up had quietly stopped warming.
#
# The simulator is resolved rather than named, for the reason the workflow
# gives: a name is a guess about a machine image that changes without notice.
# UDID in the environment overrides it, to try this on a chosen simulator.
set -euo pipefail

PRODUCTS=${1:?usage: simulator.sh <Build/Products dir> [zone]}
ZONE=${2:-}
PLAN="$(dirname "$0")/plan.py"

UDID=${UDID:-$(xcrun simctl list devices available \
  | awk -F'[()]' '/^ *iPhone/ {print $2; exit}')}
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
# including apps XCUITest launches. Before the warm-up, so it runs in the zone.
if [ -n "$ZONE" ]; then
  xcrun simctl spawn "$UDID" launchctl setenv TZ "$ZONE"
  echo "simulator zone $ZONE"
fi

WARM="${RUNNER_TEMP:-/tmp}/ui-test-warm-up.xcresult"
rm -rf "$WARM"
start=$(date +%s)
xcodebuild test-without-building \
  -xctestrun "$(ls "$PRODUCTS"/*.xctestrun | head -1)" \
  -destination "id=$UDID" \
  -only-testing:"PeachOfAWordUITests/$(python3 "$PLAN" warm-up)" \
  -resultBundlePath "$WARM" > "$WARM.log" 2>&1 \
  || { echo "the warm-up's test did not pass, which counts for nothing:"
       grep -E ": error: " "$WARM.log" | cut -c1-300 | head -3; }
echo "warm-up session took $(( $(date +%s) - start ))s"
python3 "$PLAN" warmed "$WARM"
