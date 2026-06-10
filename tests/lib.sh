#!/bin/bash
# Shared test helpers — sourced by every test_*.sh script.

if [ -t 1 ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; NC=$'\033[0m'
else
    RED=""; GREEN=""; NC=""
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

start_test() {
    CURRENT_TEST="$1"
    printf "  • %s ... " "$CURRENT_TEST"
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "%bPASS%b\n" "$GREEN" "$NC"
}

fail_test() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "%bFAIL%b\n" "$RED" "$NC"
    if [ -n "$1" ]; then
        printf "      %s\n" "$1"
    fi
}

assert_equals() {
    if [ "$1" = "$2" ]; then
        pass_test
    else
        fail_test "expected: $2 / got: $1"
    fi
}

assert_contains() {
    if printf '%s' "$1" | grep -qF "$2"; then
        pass_test
    else
        fail_test "expected output to contain: $2"
    fi
}

assert_file_exists() {
    if [ -e "$1" ]; then
        pass_test
    else
        fail_test "expected file to exist: $1"
    fi
}

assert_executable() {
    if [ -x "$1" ]; then
        pass_test
    else
        fail_test "expected file to be executable: $1"
    fi
}

assert_symlink() {
    if [ -L "$1" ]; then
        pass_test
    else
        fail_test "expected file to be a symlink: $1"
    fi
}

# Extract the marked CLI install block from install.sh as a runnable script.
# Tests can pre-set CLI_INSTALL_DIR in the environment to sandbox the install.
extract_cli_block() {
    awk '/# CLI_INSTALL_BLOCK_START/,/# CLI_INSTALL_BLOCK_END/' "$INSTALL_SH"
}

# Tests must not hit the network (CI and offline dev runs). The install
# block's download fallback shells out to `curl -o <target>`, so we shadow
# curl with a stub that "downloads" the repo's own copy of the CLI. Write
# failures (e.g. unwritable target) still propagate as a non-zero exit,
# exactly like real curl.
make_curl_stub() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/curl" << STUB_EOF
#!/bin/bash
out=""
while [ \$# -gt 0 ]; do
    if [ "\$1" = "-o" ] && [ \$# -ge 2 ]; then
        out="\$2"
        shift
    fi
    shift
done
[ -n "\$out" ] || exit 2
exec cp "$REPO_ROOT/stickyaudio" "\$out"
STUB_EOF
    chmod +x "$bin_dir/curl"
}

# Run the CLI install block in a clean subshell with the given working dir
# and CLI_INSTALL_DIR. Captures stdout+stderr.
run_cli_block() {
    local cwd="$1"
    local install_dir="$2"
    local block stub_bin
    block="$(extract_cli_block)"
    stub_bin="$cwd/.stub-bin"
    make_curl_stub "$stub_bin"
    (cd "$cwd" && PATH="$stub_bin:$PATH" CLI_INSTALL_DIR="$install_dir" bash -c "$block") 2>&1
}
