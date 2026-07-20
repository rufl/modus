#!/usr/bin/env bash
set -euo pipefail

report_path="docs/RELEASE_READINESS_REPORT.md"
target_version="1.0.0"
strict=0

usage() {
  cat <<'USAGE'
Usage: tools/validate_release_readiness.sh [--report PATH] [--target-version VERSION] [--strict]

Validates release-version readiness from source-controlled docs. This is a
source-audit gate only; it does not prove runtime, manual, test, or performance
readiness.

Options:
  --report PATH             Report output path. Default: docs/RELEASE_READINESS_REPORT.md
  --target-version VERSION  Release version expected for production readiness. Default: 1.0.0
  --strict                  Exit nonzero for blocked or failed release status.
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
    --target-version)
      target_version="${2:-}"
      if [[ -z "$target_version" ]]; then
        printf 'Missing value for --target-version\n' >&2
        exit 64
      fi
      shift 2
      ;;
    --strict)
      strict=1
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

generated_date="$(date +%Y-%m-%d)"

current_files=(
  "README.md"
  "docs/CURRENT_STATUS.md"
  "docs/ROADMAP.md"
  "ROADMAP.md"
)

release_docs=(
  "docs/RELEASE_NOTES.md"
  "docs/CHANGELOG.md"
)

required_files=(
  "${current_files[@]}"
  "${release_docs[@]}"
)

missing_files=()
for path in "${required_files[@]}"; do
  if [[ ! -e "$path" ]]; then
    missing_files+=("$path")
  fi
done

count_pattern() {
  local pattern="$1"
  local path="$2"
  awk -v pattern="$pattern" '$0 ~ pattern { count += 1 } END { print count + 0 }' "$path"
}

beta_pattern='0[.]9[.]5-beta|NOT 1[.]0[.]0|pre-alpha validation|Pre-Alpha Quality'
target_pattern="${target_version//./[.]}"
release_claim_pattern='Production Release|production-ready|Ready for Early Access Release|Current Version:[*][*] 1[.]0[.]0'

current_beta_signals=0
current_target_signals=0
release_claim_signals=0

for path in "${current_files[@]}"; do
  if [[ -e "$path" ]]; then
    count="$(count_pattern "$beta_pattern" "$path")"
    current_beta_signals=$((current_beta_signals + count))
    count="$(count_pattern "$target_pattern" "$path")"
    current_target_signals=$((current_target_signals + count))
  fi
done

for path in "${release_docs[@]}"; do
  if [[ -e "$path" ]]; then
    count="$(count_pattern "$release_claim_pattern" "$path")"
    release_claim_signals=$((release_claim_signals + count))
  fi
done

status="BLOCKED"
status_note=""

if [[ "${#missing_files[@]}" -gt 0 ]]; then
  status="FAIL"
  status_note="Required release-readiness source files are missing."
elif [[ "$current_beta_signals" -gt 0 ]]; then
  status="BLOCKED"
  status_note="Current-facing docs still identify MODUS as beta/pre-alpha or explicitly not ${target_version}."
elif [[ "$current_target_signals" -eq 0 ]]; then
  status="BLOCKED"
  status_note="Current-facing docs do not identify ${target_version} as the current release version."
elif [[ "$release_claim_signals" -eq 0 ]]; then
  status="BLOCKED"
  status_note="Release documentation does not contain production release notes for ${target_version}."
else
  status="PASS"
  status_note="Current-facing docs identify ${target_version} without beta/pre-alpha blockers."
fi

mkdir -p "$(dirname "$report_path")"
{
  printf '# MODUS Release Readiness Report\n\n'
  printf '**Generated:** %s\n' "$generated_date"
  printf '**Overall Status:** %s\n' "$status"
  printf '**Target Version:** %s\n\n' "$target_version"

  printf '## Scope\n\n'
  printf 'This report validates release-version source truth only. It does not prove automated tests, runtime behavior, manual gameplay, benchmark evidence, packaging, or store readiness.\n\n'

  printf '## Result\n\n'
  printf '%s\n' "- Status: ${status}"
  printf '%s\n' "- Note: ${status_note}"
  printf '%s\n' "- Current beta/pre-alpha blocker signals: ${current_beta_signals}"
  printf '%s\n' "- Current target-version signals: ${current_target_signals}"
  printf '%s\n\n' "- Release-doc production claim signals: ${release_claim_signals}"

  printf '## Current-Facing Version Signals\n\n'
  printf '| File | Beta/pre-alpha blockers | Target-version mentions |\n'
  printf '| --- | ---: | ---: |\n'
  for path in "${current_files[@]}"; do
    if [[ -e "$path" ]]; then
      printf '| `%s` | %s | %s |\n' "$path" "$(count_pattern "$beta_pattern" "$path")" "$(count_pattern "$target_pattern" "$path")"
    else
      printf '| `%s` | missing | missing |\n' "$path"
    fi
  done

  printf '\n## Release Documentation Signals\n\n'
  printf '| File | Production-release claim signals |\n'
  printf '| --- | ---: |\n'
  for path in "${release_docs[@]}"; do
    if [[ -e "$path" ]]; then
      printf '| `%s` | %s |\n' "$path" "$(count_pattern "$release_claim_pattern" "$path")"
    else
      printf '| `%s` | missing |\n' "$path"
    fi
  done

  printf '\n## Required Follow-Up\n\n'
  if [[ "$status" == "PASS" ]]; then
    printf '%s\n' '- No release-version blockers were detected by this validator.'
  else
    printf '%s\n' "- Keep current-facing docs on beta/pre-alpha wording until the proof lanes are actually complete."
    printf '%s\n' '- This version-only validator does not decide test, runtime, manual, performance, packaging, or store gates; use `docs/PRODUCTION_READINESS_REPORT.md` for their current states.'
    printf '%s\n' "- Update stale release notes and changelog wording only when ${target_version} is genuinely ready."
  fi
} > "$report_path"

printf 'Release readiness report written to %s\n' "$report_path"
printf 'Overall status: %s\n' "$status"

if [[ "$strict" -eq 1 && "$status" != "PASS" ]]; then
  if [[ "$status" == "BLOCKED" ]]; then
    exit 127
  fi
  exit 1
fi
