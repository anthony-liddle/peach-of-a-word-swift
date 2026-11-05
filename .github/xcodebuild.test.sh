#!/bin/bash
#
# `.github/xcodebuild.sh` against a stand-in xcodebuild, for each way a run can
# end.
#
#   .github/xcodebuild.test.sh
#
# The retry only runs when a runner's xcodebuild misses its simulator, which
# can't be made to happen, so this is what keeps it working between misses:
# a miss runs once more, over its own result bundle, and nothing else runs
# twice. The stand-in prints the miss on stderr, as xcodebuild does, and
# refuses a result bundle that already exists, as xcodebuild does.
set -euo pipefail

HELPER="$(cd "$(dirname "$0")" && pwd)/xcodebuild.sh"
WORK=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcodebuild-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
export WORK
mkdir "$WORK/bin"

# Call N takes outcome N from $OUTCOMES.
cat > "$WORK/bin/xcodebuild" <<'EOF'
#!/bin/bash
n=$(( $(cat "$WORK/calls" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$WORK/calls"
prev=
for arg in "$@"; do
  if [ "$prev" = -resultBundlePath ]; then
    if [ -e "$arg" ]; then
      echo "xcodebuild: error: Existing file at -resultBundlePath \"$arg\"" >&2
      exit 64
    fi
    mkdir -p "$arg"
  fi
  prev=$arg
done
outcomes=($OUTCOMES)
case "${outcomes[$((n - 1))]}" in
  pass) echo "** TEST EXECUTE SUCCEEDED **"; exit 0 ;;
  miss) echo "xcodebuild: error: Unable to find a device matching the provided destination specifier:" >&2; exit 70 ;;
  test) echo "** TEST EXECUTE FAILED **"; exit 65 ;;
  other) echo "xcodebuild: error: Unable to read the project." >&2; exit 70 ;;
esac
EOF
printf '#!/bin/bash\necho "    iPhone 17 (0000) (Booted)"\n' > "$WORK/bin/xcrun"
printf '#!/bin/bash\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/xcodebuild" "$WORK/bin/xcrun" "$WORK/bin/sleep"

failed=0

# check NAME OUTCOMES EXIT CALLS [no-bundle]: xcodebuild was run CALLS times,
# the helper exited EXIT, and it warned once for each run after the first.
check() {
  local args=(test-without-building -destination id=0000)
  [ "${5:-}" = no-bundle ] || args+=(-resultBundlePath "$WORK/run.xcresult")
  rm -rf "$WORK/calls" "$WORK/run.xcresult"
  local status=0
  OUTCOMES=$2 PATH="$WORK/bin:$PATH" "$HELPER" "${args[@]}" > "$WORK/out" 2>&1 || status=$?
  local calls warnings
  calls=$(cat "$WORK/calls")
  warnings=$(grep -c '^::warning' "$WORK/out" || true)
  if [ "$status" = "$3" ] && [ "$calls" = "$4" ] && [ "$warnings" = $(( $4 - 1 )) ]; then
    echo "ok: $1"
  else
    echo "FAILED: $1: exit $status after $calls runs and $warnings warnings, wanted exit $3 after $4"
    sed 's/^::/  ::/' "$WORK/out"
    failed=1
  fi
}

check "a pass runs once" "pass" 0 1
check "a miss runs once more, over its own result bundle, and passes" "miss pass" 0 2
check "a miss with no result bundle runs once more" "miss pass" 0 2 no-bundle
check "a miss twice fails, after two runs" "miss miss" 70 2
check "a miss, then a failing test, fails as the test" "miss test" 65 2
check "a failing test is not run again" "test pass" 65 1
check "another error that exits 70 is not run again" "other pass" 70 1

exit "$failed"
