#!/bin/bash
#
# xcodebuild, run once more if it found no simulator at all.
#
#   .github/xcodebuild.sh <xcodebuild arguments>
#
# Every xcodebuild in CI that names a simulator runs through this: the build
# and the run in `checkout-less-tests`, the build in `ui-build`, the warm-up in
# `ui-tests/simulator.sh`, and the runs in the shards and `ui-tests-off-utc`.
# The two builds for `generic/platform=iOS Simulator`, in `test` and
# `build-oldest-sdk`, look up no device, so they call xcodebuild directly.
#
# **The fault.** On GitHub's macOS runners, xcodebuild sometimes waits about 60
# seconds for its simulator, then lists none at all and exits 70 with "Unable
# to find a device matching the provided destination specifier". It did that
# three times on 4 and 5 November 2026, on images 20261026 and 20261102, in
# `checkout-less-tests` and `ui-tests-off-utc`, asked by name and by UDID. The
# simulator was there each time. In `ui-tests-off-utc` it had been found by
# UDID, booted and used for the warm-up, and the next xcodebuild on the same
# UDID saw nothing. It is xcodebuild's own device lookup that misses, so asking
# `simctl` first, as the workflow does, can't prevent it.
#
# **That failure only, and once.** A retry needs exit 70 and that line both. A
# failing test (65), a build error, or the same miss a second time fails the
# step as it would have without this. A retry leaves a warning on the run and
# prints what `simctl` lists at that moment, so the first time it happens shows
# whether a second attempt on the same runner gets past it.
#
# The first attempt creates the result bundle before it looks for the device,
# and xcodebuild won't write over one ("Existing file at -resultBundlePath",
# exit 64), so the retry removes it first.
#
# `.github/xcodebuild.test.sh` runs this against a stand-in xcodebuild, in the
# `test` job. Bash 3.2, which is what macOS has.
set -uo pipefail

MISS="Unable to find a device matching the provided destination specifier"

BUNDLE=
prev=
for arg in "$@"; do
  if [ "$prev" = -resultBundlePath ]; then BUNDLE=$arg; fi
  prev=$arg
done

LOG=$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcodebuild.XXXXXX") || exit 1
trap 'rm -f "$LOG"' EXIT

xcodebuild "$@" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
if [ "$status" -ne 70 ] || ! grep -qF "$MISS" "$LOG"; then
  exit "$status"
fi

echo "::warning title=xcodebuild found no simulator::xcodebuild found no device for its destination, so it runs once more. simctl's list at that moment is in the log."
echo "simctl lists:"
xcrun simctl list devices available || true
sleep 10
if [ -n "$BUNDLE" ]; then rm -rf "$BUNDLE"; fi
echo "running xcodebuild once more"
xcodebuild "$@"
