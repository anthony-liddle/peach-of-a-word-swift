#!/bin/bash
#
# Boot the runner's first iPhone simulator, optionally move its time zone, and
# launch the built app on it once, before any test's clock starts.
#
#   .github/ui-tests/simulator.sh <Build/Products dir> [zone]
#
# Writes UDID=<the simulator> to $GITHUB_ENV for the steps after it.
#
# **The warm-up launch is the point.** A freshly booted simulator's first
# launch twice missed XCUITest's 60 seconds ("Timed out while launching
# application via Xcode"), on 22 and 27 October 2026, while every later launch
# in the same run took 2 to 3 seconds. Each shard boots its own simulator, so
# each would have that first launch. Paid here, it happens outside every
# test's timeout, and a slow one costs time rather than a red run.
#
# The simulator is resolved rather than named, for the reason the workflow
# gives: a name is a guess about a machine image that changes without notice.
set -euo pipefail

PRODUCTS=${1:?usage: simulator.sh <Build/Products dir> [zone]}
ZONE=${2:-}
APP=com.anthonyliddle.peachofaword

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

# Installed, launched and left to settle, then closed, after the zone so the
# warm-up runs in it too. `-resetProgress 1` leaves the app as a fresh install
# would, which is how every test that cares about its starting state opens it.
# The tests install their own copy over this one.
start=$(date +%s)
xcrun simctl install "$UDID" "$PRODUCTS/Debug-iphonesimulator/PeachOfAWord.app"
installed=$(date +%s)
xcrun simctl launch "$UDID" "$APP" -resetProgress 1 >/dev/null
launched=$(date +%s)
sleep 10
xcrun simctl terminate "$UDID" "$APP" 2>/dev/null || true
echo "warm-up: installed in $(( installed - start ))s, launched in $(( launched - installed ))s"
