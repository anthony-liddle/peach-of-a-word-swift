#!/bin/bash
# Run the transfer page's checks a simulator can run, UITests/TransferFromTheWebPage.swift:
# checks 3, 4 and 6 of the moving-to-the-app build report's phone checks.
#
#   DEVICE=<simulator UDID> tools/transfer-checks/run.sh <web checkout>
#
# 1. Builds the web checkout's pages (pnpm build), which must include the
#    transfer page.
# 2. Serves them on this Mac at http://localhost:$PORT (5480 unless set), with
#    tools/transfer-checks/server.mjs. The simulator shares this Mac's network,
#    so its Safari reaches them with no Vercel sign-in.
# 3. Runs check 4's computer half in a desktop browser, desktop.mjs, which
#    prints the address the page offers.
# 4. Runs the UI tests on DEVICE, a simulator nobody else has booted, with both
#    addresses handed to them as TRANSFER_PAGE and TRANSFER_ADDRESS (xcodebuild
#    passes TEST_RUNNER_-prefixed variables to the test runner).
set -euo pipefail

WEB="${1:?usage: DEVICE=<udid> tools/transfer-checks/run.sh <web checkout>}"
DEVICE="${DEVICE:?set DEVICE to a simulator UDID nobody else booted}"
PORT="${PORT:-5480}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

(cd "$WEB" && pnpm build >/dev/null)
test -f "$WEB/dist/transfer.html" || { echo "no transfer.html in $WEB/dist" >&2; exit 1; }

node "$HERE/server.mjs" "$WEB/dist" "$PORT" &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true' EXIT
for _ in $(seq 1 50); do
  curl -sf -o /dev/null "http://localhost:$PORT/transfer" && break
  sleep 0.2
done

ADDRESS="$(node "$HERE/desktop.mjs" "http://localhost:$PORT" 7)"
echo "the desktop browser offered: $ADDRESS"

cd "$ROOT"
xcodegen generate --spec project.yml >/dev/null
TEST_RUNNER_TRANSFER_PAGE="http://localhost:$PORT" \
TEST_RUNNER_TRANSFER_ADDRESS="$ADDRESS" \
  xcodebuild test -project PeachOfAWord.xcodeproj -scheme PeachOfAWordUITests \
    -destination "id=$DEVICE" \
    -only-testing:PeachOfAWordUITests/TransferFromTheWebPage
