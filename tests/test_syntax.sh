#!/bin/bash
# Catches the cheapest class of regression: shell-script syntax errors.
# Runs `bash -n` over every shell script in the repo.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "test_syntax.sh"

# Every shell script we ship — extend this list when new ones land.
SCRIPTS=(
    "$REPO_ROOT/install.sh"
    "$REPO_ROOT/uninstall.sh"
    "$REPO_ROOT/stickyaudio"
    "$REPO_ROOT/hotkey-pause-scripts/stickyaudio-toggle.sh"
)

for script in "${SCRIPTS[@]}"; do
    rel="${script#$REPO_ROOT/}"
    start_test "syntax: $rel"
    if [ ! -f "$script" ]; then
        fail_test "missing file"
        continue
    fi
    if err="$(bash -n "$script" 2>&1)"; then
        pass_test
    else
        fail_test "$err"
    fi
done

# The CLI install block must remain extractable — both markers present and
# bash-parseable on their own.
start_test "marker: CLI_INSTALL_BLOCK markers present and balanced"
start="$(grep -c '^# CLI_INSTALL_BLOCK_START$' "$REPO_ROOT/install.sh" || true)"
end="$(grep -c '^# CLI_INSTALL_BLOCK_END$' "$REPO_ROOT/install.sh" || true)"
if [ "$start" = "1" ] && [ "$end" = "1" ]; then
    block="$(awk '/# CLI_INSTALL_BLOCK_START/,/# CLI_INSTALL_BLOCK_END/' "$REPO_ROOT/install.sh")"
    if printf '%s' "$block" | bash -n 2>/dev/null; then
        pass_test
    else
        fail_test "extracted block does not parse"
    fi
else
    fail_test "expected exactly 1 START and 1 END marker (got $start / $end)"
fi

echo "  $TESTS_PASSED passed, $TESTS_FAILED failed"
exit "$TESTS_FAILED"
