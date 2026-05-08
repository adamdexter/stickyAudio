#!/bin/bash
# Tests the CLI install block in install.sh.
# Reproduces the bug from the user report: `curl ... | bash` left
# `stickyaudio: command not found` because the local-file branch was the
# only install path.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SANDBOX="$(mktemp -d /tmp/stickyaudio-test.XXXXXX)"
trap 'chmod -R u+w "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT

INSTALL_DIR="$SANDBOX/install_dir"
CHECKOUT_DIR="$SANDBOX/checkout"
ELSEWHERE_DIR="$SANDBOX/elsewhere"
mkdir -p "$INSTALL_DIR" "$CHECKOUT_DIR" "$ELSEWHERE_DIR"

echo "test_install_cli.sh"

# ── Test 1: curl-pipe scenario (the reported bug) ─────────────────────────
# Run the block from a directory with no `stickyaudio` next to it. The
# local-file branch must miss, and the remote-download branch must succeed.
rm -f "$INSTALL_DIR/stickyaudio"
output="$(run_cli_block "$ELSEWHERE_DIR" "$INSTALL_DIR")"

start_test "curl-pipe: success message mentions download"
assert_contains "$output" "(downloaded)"

start_test "curl-pipe: file landed at target"
assert_file_exists "$INSTALL_DIR/stickyaudio"

start_test "curl-pipe: file is executable"
assert_executable "$INSTALL_DIR/stickyaudio"

start_test "curl-pipe: file is the real stickyaudio script"
header="$(head -3 "$INSTALL_DIR/stickyaudio" 2>/dev/null || true)"
assert_contains "$header" "stickyaudio - CLI"

# ── Test 2: git checkout → symlink ────────────────────────────────────────
# Source dir has a .git/ — the install should symlink so `git pull` updates
# the CLI in place.
cp "$REPO_ROOT/stickyaudio" "$CHECKOUT_DIR/stickyaudio"
mkdir -p "$CHECKOUT_DIR/.git"
rm -f "$INSTALL_DIR/stickyaudio"
output="$(run_cli_block "$CHECKOUT_DIR" "$INSTALL_DIR")"

start_test "git-checkout: success message mentions symlink"
assert_contains "$output" "(symlinked from checkout)"

start_test "git-checkout: target is a symlink"
assert_symlink "$INSTALL_DIR/stickyaudio"

start_test "git-checkout: symlink points to the checkout"
target="$(readlink "$INSTALL_DIR/stickyaudio" 2>/dev/null || true)"
assert_equals "$target" "$CHECKOUT_DIR/stickyaudio"

# ── Test 2b: extracted tarball (no .git/) → copy ──────────────────────────
# Reproduces the install-curl.sh path: install.sh runs from a temp directory
# that gets deleted after the install. Symlinking would leave a dangling
# pointer — the script must COPY instead. This is the actual root cause of
# the user's `command not found: stickyaudio` report.
TARBALL_DIR="$SANDBOX/tarball"
mkdir -p "$TARBALL_DIR"
cp "$REPO_ROOT/stickyaudio" "$TARBALL_DIR/stickyaudio"
# No .git/ here — simulates `tar -xz` of a GitHub source archive.
rm -f "$INSTALL_DIR/stickyaudio"
output="$(run_cli_block "$TARBALL_DIR" "$INSTALL_DIR")"

start_test "tarball: success message mentions copy"
assert_contains "$output" "(copied)"

start_test "tarball: target is a real file (not a symlink)"
if [ -L "$INSTALL_DIR/stickyaudio" ]; then
    fail_test "expected a regular file, got a symlink — would dangle when tarball dir is cleaned up"
else
    assert_file_exists "$INSTALL_DIR/stickyaudio"
fi

start_test "tarball: copied file survives source-dir removal"
rm -rf "$TARBALL_DIR"
if [ -x "$INSTALL_DIR/stickyaudio" ] && head -1 "$INSTALL_DIR/stickyaudio" | grep -q '^#!/bin/bash'; then
    pass_test
else
    fail_test "CLI no longer runnable after source dir was removed"
fi

# ── Test 2c: dangling symlink at destination (reporter's machine state) ───
# A user hit by the v2.0 install-curl bug has /opt/homebrew/bin/stickyaudio
# pointing into a tmpdir that's already been deleted. Re-running the
# installer must overwrite that dangling symlink, not fail because cp/curl
# can't follow it.
DANGLING_TARGET="$INSTALL_DIR/stickyaudio"
ln -sf "/tmp/this-tmpdir-was-already-deleted/stickyaudio" "$DANGLING_TARGET"

# Curl-pipe path (no source file → remote download must overwrite dangler)
output="$(run_cli_block "$ELSEWHERE_DIR" "$INSTALL_DIR")"

start_test "dangling-symlink: install succeeds via download path"
assert_contains "$output" "(downloaded)"

start_test "dangling-symlink: target is now a real file, not a dangler"
if [ -L "$DANGLING_TARGET" ]; then
    fail_test "still a symlink"
elif [ ! -f "$DANGLING_TARGET" ]; then
    fail_test "target missing"
else
    pass_test
fi

# ── Test 3: both paths fail (loud-error guarantee) ────────────────────────
# Clear the install dir and make it read-only. Both symlink and download
# must fail; the script must print the manual recovery command.
chmod +w "$INSTALL_DIR"
rm -f "$INSTALL_DIR/stickyaudio"
chmod -w "$INSTALL_DIR"
output="$(run_cli_block "$ELSEWHERE_DIR" "$INSTALL_DIR" || true)"
chmod +w "$INSTALL_DIR"

start_test "both-fail: error header printed"
assert_contains "$output" "Could not install"

start_test "both-fail: manual recovery command printed"
assert_contains "$output" "sudo curl -fsSL"

start_test "both-fail: no false success message"
if printf '%s' "$output" | grep -qF "✓ Installed"; then
    fail_test "loud-error path leaked a success message"
else
    pass_test
fi

echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
