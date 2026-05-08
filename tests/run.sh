#!/bin/bash
# Test runner: executes every tests/test_*.sh and reports pass/fail.
# Exits non-zero if any suite failed.
#
# Usage: bash tests/run.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -t 1 ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=""; GREEN=""; BOLD=""; NC=""
fi

failed_suites=0
total_suites=0

printf "%bRunning stickyAudio test suites%b\n\n" "$BOLD" "$NC"

for suite in "$SCRIPT_DIR"/test_*.sh; do
    [ -f "$suite" ] || continue
    total_suites=$((total_suites + 1))
    if ! bash "$suite"; then
        failed_suites=$((failed_suites + 1))
    fi
    echo
done

if [ "$failed_suites" -eq 0 ]; then
    printf "%b✓ all %d suite(s) passed%b\n" "$GREEN" "$total_suites" "$NC"
    exit 0
else
    printf "%b✗ %d of %d suite(s) failed%b\n" "$RED" "$failed_suites" "$total_suites" "$NC"
    exit 1
fi
