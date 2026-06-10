#!/bin/bash
# Reproduces the user-reported bug from 2026-06: piping install-curl.sh
# through bash left install.sh reading from the exhausted curl pipe, so
# the AUDIO_DEVICE prompt instantly EOF'd and the user's typed answer
# leaked into zsh ("zsh: missing end of string" from the literal parens
# in "LG TV SSCR2 (eqMac)").
#
# Strategy: we can't run the real install-curl.sh in CI (it talks to
# github.com and runs a system installer). Instead we re-execute the
# tail of install-curl.sh — the part that runs install.sh — against a
# stub install.sh that records what its stdin actually is. If the
# wrapper forgot to redirect stdin, the stub sees a closed pipe and the
# test fails.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SANDBOX="$(mktemp -d /tmp/stickyaudio-curl-test.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

echo "test_curl_install.sh"

# Stub install.sh: records what's on its stdin. If stdin is a closed
# pipe, `read` returns non-zero and we record FAIL. If stdin is a tty
# (or anything readable), we record OK with the first line.
cat > "$SANDBOX/install.sh" << 'STUB_EOF'
#!/bin/bash
if IFS= read -r line; then
    printf 'stub: read OK: %s\n' "$line" > "$SANDBOX_OUT/stub.out"
else
    printf 'stub: read FAIL (stdin EOF or closed)\n' > "$SANDBOX_OUT/stub.out"
fi
STUB_EOF
chmod +x "$SANDBOX/install.sh"

# Extract the "Run the real installer" block from install-curl.sh and run
# it from the sandbox (so `./install.sh` resolves to our stub). This
# exercises the exact code path the curl-pipe flow hits.
INSTALL_CURL="$REPO_ROOT/install-curl.sh"
runner_block="$(awk '/^# Run the real installer/,/^fi$/' "$INSTALL_CURL")"

start_test "extracted runner block is non-empty"
if [ -n "$runner_block" ]; then
    pass_test
else
    fail_test "could not extract 'Run the real installer' block from install-curl.sh — markers changed?"
    echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
    exit "$TESTS_FAILED"
fi

# ── Test 1: closed-pipe stdin (the reported bug) ──────────────────────────
# Run the block with stdin closed (`</dev/null`) — same observable state
# as an exhausted curl pipe. The stub's `read` should still succeed
# because the wrapper reattaches stdin to /dev/tty. In a real terminal
# /dev/tty would feed the user's answer; in CI /dev/tty echoes nothing
# but is still a readable fd whose `read` returns successfully on EOF
# only if its fd was closed — so we feed a canned line through /dev/tty
# is impossible. Instead, we substitute: replace `/dev/tty` in the block
# with a regular file we control, and verify the block reads from THAT
# file rather than from the closed pipe.
FAKE_TTY="$SANDBOX/fake_tty"
printf 'user-typed-device-name\n' > "$FAKE_TTY"

patched_block="${runner_block//\/dev\/tty/$FAKE_TTY}"
SANDBOX_OUT="$SANDBOX"
export SANDBOX_OUT

(
    cd "$SANDBOX"
    bash -c "$patched_block" </dev/null
) > "$SANDBOX/runner.out" 2>&1

start_test "closed-pipe scenario: stub read succeeds (wrapper reattaches stdin)"
if [ -f "$SANDBOX/stub.out" ] && grep -q "^stub: read OK:" "$SANDBOX/stub.out"; then
    pass_test
else
    fail_test "$(cat "$SANDBOX/stub.out" 2>/dev/null || echo 'stub never ran')"
fi

start_test "closed-pipe scenario: stub reads the user-supplied value (not curl pipe)"
if [ -f "$SANDBOX/stub.out" ] && grep -q "user-typed-device-name" "$SANDBOX/stub.out"; then
    pass_test
else
    fail_test "stub did not read the substituted /dev/tty contents — wrapper may have forgotten to redirect"
fi

# ── Test 2: no-tty fallback (unattended CI) ───────────────────────────────
# When /dev/tty doesn't exist, the wrapper must still invoke install.sh —
# just with inherited stdin. Verify by patching /dev/tty to a path that
# doesn't exist and feeding the pipe a real line.
rm -f "$SANDBOX/stub.out"
MISSING_TTY="$SANDBOX/nonexistent_tty"
patched_block="${runner_block//\/dev\/tty/$MISSING_TTY}"

(
    cd "$SANDBOX"
    printf 'from-stdin\n' | bash -c "$patched_block"
) > "$SANDBOX/runner.out" 2>&1

start_test "no-tty fallback: install.sh still runs"
if [ -f "$SANDBOX/stub.out" ]; then
    pass_test
else
    fail_test "stub never ran when /dev/tty was missing"
fi

start_test "no-tty fallback: stub reads from inherited stdin"
if [ -f "$SANDBOX/stub.out" ] && grep -q "from-stdin" "$SANDBOX/stub.out"; then
    pass_test
else
    fail_test "stub did not read the piped value — fallback path may be broken"
fi

echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
