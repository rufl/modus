#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d /tmp/modus_manual_validator.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/logs"

cat >"$tmp/logs/session.csv" <<'CSV'
Timestamp,TestName,Duration,Result,Notes
2026-08-04T12:00:00,showcase_route,4.00,pass,Observed the maintained route

# Session Summary
session_name,validator_fixture
total_duration,9999.00
total_tests,1
passed,1
failed,0
skipped,0
incomplete,0
total_test_time,4.00
avg_test_duration,4.00
min_test_duration,4.00
max_test_duration,4.00
overhead_time,9995.00
metadata_tester,Fixture Reviewer
metadata_os,Linux
metadata_renderer,gl_compatibility
metadata_resolution,1280x720
metadata_input_devices,keyboard_mouse
metadata_scene,main_menu_to_showcase
metadata_build_identity,0.9.5-beta+fixture
CSV

set +e
"$root/tools/validate_manual_evidence.sh" --logs "$tmp/logs" --report "$tmp/blocked.md" --min-hours 0.002 --strict >/dev/null
blocked=$?
"$root/tools/validate_manual_evidence.sh" --logs "$tmp/logs" --report "$tmp/pass.md" --min-hours 0.001 --strict >/dev/null
passed=$?
sed -i '/metadata_tester/d' "$tmp/logs/session.csv"
"$root/tools/validate_manual_evidence.sh" --logs "$tmp/logs" --report "$tmp/fail.md" --min-hours 0.001 --strict >/dev/null
metadata_failed=$?
set -e

[[ "$blocked" -eq 127 ]]
[[ "$passed" -eq 0 ]]
[[ "$metadata_failed" -eq 1 ]]
grep -Fq -- '- Validated test seconds: 4.00' "$tmp/pass.md"
grep -Fq -- '- Total session hours including recorder overhead: 2.78' "$tmp/pass.md"
printf 'Manual evidence validator self-check passed.\n'
