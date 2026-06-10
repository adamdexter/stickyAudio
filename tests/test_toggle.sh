#!/bin/bash
# Behavioral tests for the hotkey toggle script (used by the Shortcuts,
# Automator, and Alfred integrations). Runs with HOME pointed at a sandbox.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SANDBOX="$(mktemp -d /tmp/stickyaudio-toggle-test.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

TOGGLE="$REPO_ROOT/hotkey-pause-scripts/stickyaudio-toggle.sh"
PAUSE_FILE="$SANDBOX/.config/audio-wake-fix/paused"

run_toggle() {
    HOME="$SANDBOX" bash "$TOGGLE" 2>&1
}

echo "test_toggle.sh"

# First run must work even before the config dir exists (fresh machine,
# hotkey set up before the installer ran).
start_test "first toggle pauses (creates dir + pause file)"
output="$(run_toggle)"
if [ "$(cat "$PAUSE_FILE" 2>/dev/null)" = "indefinite" ]; then
    pass_test
else
    fail_test "pause file: $(cat "$PAUSE_FILE" 2>/dev/null || echo '<missing>')"
fi

start_test "first toggle reports Paused"
assert_contains "$output" "Paused"

start_test "second toggle resumes (removes pause file)"
output="$(run_toggle)"
if [ ! -f "$PAUSE_FILE" ]; then pass_test; else fail_test "pause file still present"; fi

start_test "second toggle reports Resumed"
assert_contains "$output" "Resumed"

echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
