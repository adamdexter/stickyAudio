#!/bin/bash
# The wake script and polling daemon don't exist as files in this repo —
# install.sh generates them from quoted heredocs (WAKE_EOF / DAEMON_EOF).
# This suite extracts them and tests:
#   - both parse (bash -n)
#   - the wake script's end-to-end behavior against a stubbed
#     SwitchAudioSource (exact-match device check, switch, logging)
#   - the daemon's load_config sanitizes a hostile/broken POLL_INTERVAL
#     (a bad value would otherwise spin the loop at 100% CPU)
#   - escape_for_config round-trips hostile device names through the
#     sourced config file without executing anything

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SANDBOX="$(mktemp -d /tmp/stickyaudio-gen-test.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

echo "test_generated_scripts.sh"

# Pull a quoted heredoc body out of install.sh by its delimiter name.
extract_heredoc() {
    awk "/<< '$1'\$/,/^$1\$/" "$INSTALL_SH" | sed '1d;$d'
}

WAKE_SCRIPT="$SANDBOX/set-audio-output.sh"
DAEMON_SCRIPT="$SANDBOX/stickyaudio-daemon.sh"
extract_heredoc WAKE_EOF > "$WAKE_SCRIPT"
extract_heredoc DAEMON_EOF > "$DAEMON_SCRIPT"

# ── syntax ─────────────────────────────────────────────────────────────────
start_test "wake script extracted non-empty"
if [ -s "$WAKE_SCRIPT" ]; then pass_test; else fail_test "heredoc markers changed?"; fi

start_test "daemon script extracted non-empty"
if [ -s "$DAEMON_SCRIPT" ]; then pass_test; else fail_test "heredoc markers changed?"; fi

start_test "wake script parses (bash -n)"
if err="$(bash -n "$WAKE_SCRIPT" 2>&1)"; then pass_test; else fail_test "$err"; fi

start_test "daemon script parses (bash -n)"
if err="$(bash -n "$DAEMON_SCRIPT" 2>&1)"; then pass_test; else fail_test "$err"; fi

# ── wake script behavior (stubbed SwitchAudioSource) ──────────────────────
FAKE_HOME="$SANDBOX/home"
CONF_DIR="$FAKE_HOME/.config/audio-wake-fix"
mkdir -p "$CONF_DIR"
STUB_BIN="$SANDBOX/bin"
STUB_STATE="$SANDBOX/sas-state"
mkdir -p "$STUB_BIN"

# Stub: -a lists devices, -c prints current output, -s records the switch.
cat > "$STUB_BIN/SwitchAudioSource" << STUB_EOF
#!/bin/bash
case "\$1" in
    -a) printf 'Stub Speakers\nTest Jack Device\nTest Jack Device (eqMac)\n' ;;
    -c) if [ -f "$STUB_STATE" ]; then cat "$STUB_STATE"; else echo "Stub Speakers"; fi ;;
    -s) printf '%s' "\$2" > "$STUB_STATE" ;;
esac
STUB_EOF
chmod +x "$STUB_BIN/SwitchAudioSource"

cat > "$CONF_DIR/config" << 'CONF_EOF'
DEVICE="Test Jack Device"
BUILTIN_SPEAKER="Stub Speakers"
WAKE_SETTLE_DELAY=0
CONF_EOF

HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" bash "$WAKE_SCRIPT" >/dev/null 2>&1

start_test "wake: switches to the configured device"
assert_equals "$(cat "$STUB_STATE" 2>/dev/null)" "Test Jack Device"

start_test "wake: logs the successful switch"
log_content="$(cat "$CONF_DIR/audio-wake.log" 2>/dev/null || true)"
assert_contains "$log_content" "Output is now: Test Jack Device"

# Device absent → must not switch, must log the skip (and the retry loop
# must terminate).
rm -f "$STUB_STATE" "$CONF_DIR/audio-wake.log"
cat > "$CONF_DIR/config" << 'CONF_EOF'
DEVICE="Unplugged Device"
WAKE_SETTLE_DELAY=0
WAKE_MAX_ATTEMPTS=1
CONF_EOF

HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" bash "$WAKE_SCRIPT" >/dev/null 2>&1

start_test "wake: does not switch when device is unavailable"
if [ ! -f "$STUB_STATE" ]; then pass_test; else fail_test "switched to '$(cat "$STUB_STATE")'"; fi

start_test "wake: logs the skip when device is unavailable"
log_content="$(cat "$CONF_DIR/audio-wake.log" 2>/dev/null || true)"
assert_contains "$log_content" "not detected"

# ── daemon load_config sanitization ───────────────────────────────────────
# Extract just the load_config function and exercise it directly.
daemon_load_config="$(awk '/^load_config\(\)/,/^}/' "$DAEMON_SCRIPT")"

check_poll_interval() {
    local raw="$1"
    printf 'DEVICE="D"\nBUILTIN_SPEAKER="B"\nPOLL_INTERVAL=%s\n' "$raw" > "$SANDBOX/dconfig"
    (
        # Read by the eval'd load_config, not directly here.
        # shellcheck disable=SC2034
        CONFIG_FILE="$SANDBOX/dconfig"
        eval "$daemon_load_config"
        load_config
        printf '%s' "$POLL_INTERVAL"
    )
}

start_test "daemon: keeps a valid POLL_INTERVAL"
assert_equals "$(check_poll_interval '"7"')" "7"

start_test "daemon: non-numeric POLL_INTERVAL falls back to 10"
assert_equals "$(check_poll_interval '"fast; rm -rf /"')" "10"

start_test "daemon: zero POLL_INTERVAL falls back to 10 (no busy-spin)"
assert_equals "$(check_poll_interval '0')" "10"

# ── escape_for_config round-trip ───────────────────────────────────────────
# A device name full of shell metacharacters must survive being written to
# the sourced config file unchanged — and must execute nothing.
esc_fn="$(awk '/^escape_for_config\(\)/,/^}/' "$INSTALL_SH")"

start_test "escape_for_config function extracted from install.sh"
if [ -n "$esc_fn" ]; then pass_test; else fail_test "function moved or renamed?"; fi

eval "$esc_fn"
CANARY="$SANDBOX/pwned"
NASTY='Evil "Device" $(touch '"$CANARY"') `touch '"$CANARY"'` \ $HOME end'
ESCAPED="$(escape_for_config "$NASTY")"
printf 'DEVICE="%s"\n' "$ESCAPED" > "$SANDBOX/nasty-config"

DEVICE=""
# shellcheck disable=SC1090
source "$SANDBOX/nasty-config"

start_test "escape_for_config: hostile name round-trips exactly"
assert_equals "$DEVICE" "$NASTY"

start_test "escape_for_config: no command execution while sourcing"
if [ ! -e "$CANARY" ]; then pass_test; else fail_test "canary file was created — escaping is broken"; fi

echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
