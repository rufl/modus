#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d /tmp/modus_retained_logs.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

check_log() {
    local name="$1" expected="$2" status="$3" fixture="$4"
    local dir="$tmp/$name" result=0
    mkdir -p "$dir"
    for lane in unit integration property; do
        printf '%s\n' "$fixture" >"$dir/$lane.log"
    done
    if [[ "$name" == missing ]]; then
        rm "$dir/unit.log"
    fi
    GODOT_BIN="$(command -v true)" bash "$root/tests/runners/run_tests_by_category.sh" \
        --reuse-logs --log-dir "$dir" --report "$dir/report.md" >"$dir/output.log" 2>&1 || result=$?
    if [[ "$result" -ne "$expected" ]] || ! grep -Fq "| Unit | $status |" "$dir/report.md"; then
        cat "$dir/output.log" "$dir/report.md"
        printf 'FAILED retained log case: %s (exit %s, expected %s)\n' "$name" "$result" "$expected" >&2
        exit 1
    fi
    if [[ "$expected" -eq 0 ]]; then
        grep -Fq '**Overall Status:** PASS' "$dir/report.md"
    else
        grep -Fq '**Overall Status:** FAIL' "$dir/report.md"
    fi
}

# Failures must dominate both a success banner and a successful wrapper exit.
check_log failed 1 FAIL $'Tests 2\nPassing Tests 1\nFailing Tests 1\n---- All tests passed! ----'
check_log truncated 1 BLOCKED '---- All tests passed! ----'
check_log mismatched 1 BLOCKED $'Tests 2\nPassing Tests 1'
check_log malformed 1 BLOCKED $'Tests unknown\nPassing Tests 1\nFailing Tests 0'
check_log missing 1 BLOCKED $'Tests 2\nPassing Tests 2'
check_log empty_selection 1 FAIL $'Tests 0\nPassing Tests 0'
check_log pending 0 PASS $'Tests 2\nPassing Tests 1\nFailing Tests 0\nRisky/Pending 1'
check_log assertion 1 FAIL $'[Failed] an assertion\nTests 2\nPassing Tests 2'
# Real GUT passing summaries omit the zero failing count and may omit a banner.
check_log passed 0 PASS $'Tests 2\nPassing Tests 2'
printf 'Retained test-log regressions passed (9 cases).\n'
