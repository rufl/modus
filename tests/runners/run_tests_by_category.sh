#!/usr/bin/env bash
# MODUS Test Suite Runner - Batched Execution
# Runs tests in categories to avoid timeouts and provide better reporting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

source "$SCRIPT_DIR/headless_common.sh"

report_path="docs/AUTOMATED_TEST_LANES_REPORT.md"
log_dir="${MODUS_TEST_LANE_LOG_DIR:-}"
runner_args=()
reuse_logs=0

usage() {
    cat <<'USAGE'
Usage: tests/runners/run_tests_by_category.sh [--report PATH] [--log-dir DIR] [--reuse-logs] [--include-gui-required]

Runs the default headless GUT suite in durable lanes and writes a markdown
summary report for Phase 0 triage.

Options:
  --report PATH              Report output path. Default: docs/AUTOMATED_TEST_LANES_REPORT.md
  --log-dir DIR              Directory for per-lane logs. Default: /tmp/modus_test_lanes_<timestamp>
  --reuse-logs               Regenerate the report from complete logs in --log-dir without rerunning Godot.
  --include-gui-required     Include tests listed in the GUI-required manifest.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --report)
            report_path="${2:-}"
            if [[ -z "$report_path" ]]; then
                printf 'Missing value for --report\n' >&2
                exit 64
            fi
            shift 2
            ;;
        --log-dir)
            log_dir="${2:-}"
            if [[ -z "$log_dir" ]]; then
                printf 'Missing value for --log-dir\n' >&2
                exit 64
            fi
            shift 2
            ;;
        --include-gui-required)
            runner_args+=("$1")
            shift
            ;;
        --reuse-logs)
            reuse_logs=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

modus_parse_headless_args "${runner_args[@]}"

if ! godot_bin="$(modus_find_godot_bin)"; then
    exit 127
fi

if [[ "$reuse_logs" -eq 0 ]]; then
    modus_import_project "$godot_bin"
elif [[ -z "$log_dir" || ! -d "$log_dir" ]]; then
    printf '%s\n' '--reuse-logs requires an existing --log-dir.' >&2
    exit 64
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
if [[ -z "$log_dir" ]]; then
    log_dir="/tmp/modus_test_lanes_${timestamp}"
fi
mkdir -p "$log_dir"

echo "======================================================================"
echo "  MODUS TEST SUITE - Batched Execution"
echo "======================================================================"
echo ""
echo "  Report: ${report_path}"
echo "  Logs:   ${log_dir}"
echo ""

# Initialize result tracking
unit_result=0
integration_result=0
property_result=0
benchmark_result=0

lane_names=()
lane_statuses=()
lane_selected=()
lane_skipped=()
lane_tests=()
lane_passing=()
lane_failing=()
lane_risky=()
lane_logs=()
lane_notes=()

append_lane() {
    lane_names+=("$1")
    lane_statuses+=("$2")
    lane_selected+=("$3")
    lane_skipped+=("$4")
    lane_tests+=("$5")
    lane_passing+=("$6")
    lane_failing+=("$7")
    lane_risky+=("$8")
    lane_logs+=("$9")
    lane_notes+=("${10}")
}

parse_metric() {
    local log_file="$1"
    local label="$2"
    if [[ ! -f "$log_file" ]]; then
        printf '%s\n' '-'
        return
    fi
    awk -v label="$label" '
        $0 ~ "^[[:space:]]*" label "[[:space:]]+" { value = $NF }
        END {
            if (value == "") {
                print "-"
            } else {
                print value
            }
        }
    ' "$log_file"
}

classify_log() {
    local log_file="$1"
    local status="$2"
    local notes=()

    if [[ "$status" == "PASS" ]]; then
        notes+=("green lane")
    else
        if grep -Eiq 'ENet|socket|permission|Operation not permitted|address already in use|network' "$log_file"; then
            notes+=("environment/network signatures present")
        fi
        if grep -Eiq 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Trying to assign' "$log_file"; then
            notes+=("script/runtime errors present")
        fi
        if grep -Fq '[Failed]' "$log_file"; then
            notes+=("assertion failures present")
        fi
        if grep -Eiq 'Risky/Pending|pending|risky' "$log_file"; then
            notes+=("risky/pending tests present")
        fi
    fi

    if [[ "${#notes[@]}" -eq 0 ]]; then
        notes+=("failed without a recognized lane signature")
    fi

    local joined="${notes[0]}"
    local i
    for ((i = 1; i < ${#notes[@]}; i++)); do
        joined+=", ${notes[$i]}"
    done
    printf '%s' "$joined"
}

# Function to run tests and capture results
run_test_category() {
    local category=$1
    shift
    local dirs=("$@")
    local slug
    local log_file
    local status
    local selected_count
    local skipped_count
    local tests_count
    local passing_count
    local failing_count
    local risky_count
    local note

    echo "----------------------------------------------------------------------"
    echo "  Running ${category} Tests"
    echo "----------------------------------------------------------------------"
    modus_collect_gut_tests "${dirs[@]}"
    modus_print_headless_selection
    selected_count="$MODUS_HEADLESS_INCLUDED_COUNT"
    skipped_count="$MODUS_HEADLESS_SKIPPED_COUNT"
    slug="$(printf '%s' "$category" | tr '[:upper:] ' '[:lower:]_')"
    log_file="${log_dir}/${slug}.log"

    local result
    if [[ "$reuse_logs" -eq 1 ]]; then
        result=0
        if [[ ! -f "$log_file" ]]; then
            result=125
        fi
    else
        set +e
        modus_run_godot "$godot_bin" --headless -s addons/gut/gut_cmdln.gd "${MODUS_GUT_TEST_ARGS[@]}" 2>&1 | tee "$log_file"
        result=$?
        set -e
    fi

    tests_count="$(parse_metric "$log_file" "Tests")"
    passing_count="$(parse_metric "$log_file" "Passing Tests")"
    failing_count="$(parse_metric "$log_file" "Failing Tests")"
    risky_count="$(parse_metric "$log_file" "Risky/Pending")"

    # GUT omits zero failures. Preserve the existing pending-test policy,
    # but infer zero only when passing plus pending accounts for every test.
    if [[ "$tests_count" =~ ^[0-9]+$ && "$passing_count" =~ ^[0-9]+$ \
        && ( "$risky_count" == "-" || "$risky_count" =~ ^[0-9]+$ ) \
        && "$failing_count" == "-" ]]; then
        local pending_count="${risky_count/-/0}"
        if (( 10#$tests_count == 10#$passing_count + 10#$pending_count )); then
            failing_count="0"
        fi
    fi

    if [[ ! "$tests_count" =~ ^[0-9]+$ || ! "$passing_count" =~ ^[0-9]+$ \
        || ! "$failing_count" =~ ^[0-9]+$ \
        || ( "$risky_count" != "-" && ! "$risky_count" =~ ^[0-9]+$ ) ]]; then
        status="BLOCKED"
        result=125
        note="lane log ended without a complete numeric GUT summary; do not treat wrapper exit as green"
    else
        status="FAIL"
        if [[ "$result" -eq 0 ]]; then
            local pending_count="${risky_count/-/0}"
            if (( 10#$tests_count > 0 \
                && 10#$passing_count + 10#$pending_count == 10#$tests_count \
                && 10#$failing_count == 0 )) \
                && ! grep -Fq '[Failed]' "$log_file"; then
                status="PASS"
            else
                result=1
            fi
        fi
        note="$(classify_log "$log_file" "$status")"
    fi
    append_lane "$category" "$status" "$selected_count" "$skipped_count" "$tests_count" "$passing_count" "$failing_count" "$risky_count" "$log_file" "$note"

    return $result
}

count_gui_manifest_entries() {
    if [[ ! -f "$MODUS_HEADLESS_GUI_REQUIRED_MANIFEST" ]]; then
        printf '0'
        return
    fi
    grep -Ev '^[[:space:]]*(#|$)' "$MODUS_HEADLESS_GUI_REQUIRED_MANIFEST" | wc -l | tr -d ' '
}

write_report() {
    local overall_status="PASS"
    local gui_required_count
    local report_date
    local i

    for status in "${lane_statuses[@]}"; do
        if [[ "$status" != "PASS" && "$status" != "SKIPPED" ]]; then
            overall_status="FAIL"
        fi
    done

    gui_required_count="$(count_gui_manifest_entries)"
    report_date="$(date +%Y-%m-%d)"
    mkdir -p "$(dirname "$report_path")"

    {
        printf '# MODUS Automated Test Lanes Report\n\n'
        printf '**Generated:** %s\n' "$report_date"
        printf '**Overall Status:** %s\n' "$overall_status"
        printf '**Godot Binary:** `%s`\n' "$godot_bin"
        printf '**Detailed Logs:** `%s`\n\n' "$log_dir"

        printf '## Scope\n\n'
        printf 'This report splits the headless GUT suite into durable triage lanes. It does not replace the full-suite readiness gate; it makes the failing baseline actionable by separating category failures, GUI-required skips, benchmark deferral, and log-derived failure signatures.\n\n'

        printf '## Lane Summary\n\n'
        printf '| Lane | Status | Selected files | GUI-required skipped | Tests | Passing | Failing | Risky/Pending | Log |\n'
        printf '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |\n'
        for i in "${!lane_names[@]}"; do
            printf '| %s | %s | %s | %s | %s | %s | %s | %s | `%s` |\n' \
                "${lane_names[$i]}" "${lane_statuses[$i]}" "${lane_selected[$i]}" "${lane_skipped[$i]}" \
                "${lane_tests[$i]}" "${lane_passing[$i]}" "${lane_failing[$i]}" "${lane_risky[$i]}" "${lane_logs[$i]}"
        done

        printf '\n## Triage Notes\n\n'
        printf '| Lane | Notes |\n'
        printf '| --- | --- |\n'
        for i in "${!lane_names[@]}"; do
            printf '| %s | %s |\n' "${lane_names[$i]}" "${lane_notes[$i]}"
        done

        printf '\n## Durable Failure Lanes\n\n'
        printf '| Lane Type | Current Handling |\n'
        printf '| --- | --- |\n'
        printf '| Product or stale-test failures | Inspect failed Unit, Integration, and Property lanes by assertion/runtime signature before expanding features. |\n'
        printf '| Environment or sandbox network limits | Log notes flag ENet/socket/permission signatures when present; do not count those as gameplay proof failures without local runtime reproduction. |\n'
        printf '| GUI-required headless cases | %s manifest entries are skipped by default through `%s`; rerun with `--include-gui-required` only in a GUI-capable environment. |\n' "$gui_required_count" "$MODUS_HEADLESS_GUI_REQUIRED_MANIFEST"
        printf '| Deferred benchmark lane | Benchmark tests remain skipped by this headless lane runner; performance evidence must come from `tools/validate_performance_evidence.sh` and imported logs. |\n'

        printf '\n## Required Follow-Up\n\n'
        if [[ "$overall_status" == "PASS" ]]; then
            printf '%s\n' '- All selected automated lanes passed. Rerun the full production-readiness gate to refresh the official suite boundary.'
        else
            printf '%s\n' '- Triage failing lane logs and split failures into product bugs, stale tests, environment/network blockers, GUI-required cases, or deferred benchmark/manual work.'
            printf '%s\n' '- Keep `docs/PRODUCTION_READINESS_REPORT.md` on NOT READY until `tools/validate_production_readiness.sh --run-godot-tests --strict` records a green full-suite boundary.'
        fi
    } > "$report_path"
}

# Run Unit Tests
echo ""
run_test_category "Unit" tests/unit || unit_result=$?

# Run Integration Tests
echo ""
run_test_category "Integration" tests/integration || integration_result=$?

# Run Property Tests
echo ""
run_test_category "Property" tests/property || property_result=$?

# Run Benchmark Tests (1 file) - Optional
echo ""
echo "----------------------------------------------------------------------"
echo "  Skipping Benchmark Tests (requires GUI mode)"
echo "----------------------------------------------------------------------"
benchmark_result=0
append_lane "Benchmark" "SKIPPED" "0" "0" "-" "-" "-" "-" "-" "deferred; requires GUI/performance evidence lane"

write_report

# Calculate totals
echo ""
echo "======================================================================"
echo "  TEST RESULTS SUMMARY"
echo "======================================================================"
echo ""
echo "  Unit Tests:        $([ $unit_result -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "  Integration Tests: $([ $integration_result -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "  Property Tests:    $([ $property_result -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "  Benchmark Tests:   SKIPPED"
echo "  Report:            ${report_path}"
echo ""
echo "======================================================================"

# Determine overall result
if [ $unit_result -eq 0 ] && [ $integration_result -eq 0 ] && [ $property_result -eq 0 ]; then
    echo "  SUCCESS: All selected test categories passed"
    echo "======================================================================"
    echo ""
    exit 0
else
    echo "  FAILURE: Some selected test categories failed"
    echo "======================================================================"
    echo ""
    exit 1
fi
