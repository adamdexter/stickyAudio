#!/bin/bash
# Behavioral tests for the stickyaudio CLI. Runs with HOME pointed at a
# sandbox so no real config or pause state is touched, and only exercises
# commands that don't need SwitchAudioSource (pause/resume/help/dispatch).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SANDBOX="$(mktemp -d /tmp/stickyaudio-cli-test.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

CLI="$REPO_ROOT/stickyaudio"
PAUSE_FILE="$SANDBOX/.config/audio-wake-fix/paused"

run_cli() {
    HOME="$SANDBOX" bash "$CLI" "$@" 2>&1
}

echo "test_cli.sh"

# ── help / dispatch ────────────────────────────────────────────────────────
start_test "help exits 0"
if run_cli help >/dev/null; then pass_test; else fail_test "non-zero exit"; fi

start_test "no args prints usage and exits 0"
output="$(run_cli)" && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$output" | grep -qF "Usage:"; then
    pass_test
else
    fail_test "rc=$rc"
fi

start_test "unknown command exits non-zero"
if run_cli bogus-command >/dev/null; then
    fail_test "expected non-zero exit"
else
    pass_test
fi

# ── pause / resume ─────────────────────────────────────────────────────────
start_test "pause (indefinite) creates pause file even when config dir is missing"
output="$(run_cli pause)" && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$PAUSE_FILE" 2>/dev/null)" = "indefinite" ]; then
    pass_test
else
    fail_test "rc=$rc, pause file: $(cat "$PAUSE_FILE" 2>/dev/null || echo '<missing>')"
fi

start_test "resume removes pause file"
run_cli resume >/dev/null
if [ ! -f "$PAUSE_FILE" ]; then pass_test; else fail_test "pause file still present"; fi

start_test "pause 5 writes a numeric epoch timestamp"
run_cli pause 5 >/dev/null
content="$(cat "$PAUSE_FILE" 2>/dev/null || true)"
if printf '%s' "$content" | grep -qE '^[0-9]+$'; then
    pass_test
else
    fail_test "expected epoch seconds, got: '$content'"
fi
run_cli resume >/dev/null

start_test "pause rejects non-numeric minutes"
output="$(run_cli pause 'abc')" && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$output" | grep -qF "Invalid minutes"; then
    pass_test
else
    fail_test "rc=$rc, output: $output"
fi

start_test "pause rejects arithmetic-injection payloads"
output="$(run_cli pause 'x[$(touch /tmp/pwned)]')" && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && [ ! -f "$PAUSE_FILE" ]; then
    pass_test
else
    fail_test "rc=$rc — payload was not rejected"
fi

# ── log argument validation ────────────────────────────────────────────────
start_test "log rejects non-numeric line count"
output="$(run_cli log notanumber)" && rc=0 || rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$output" | grep -qF "Invalid line count"; then
    pass_test
else
    fail_test "rc=$rc, output: $output"
fi

echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
