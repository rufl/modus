#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d "$root/docs/publication-check.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT
cd "$root"
# Exercise staged publication without changing the real index or existing files.
export GIT_INDEX_FILE="$fixture/index"
git read-tree HEAD
relative="${fixture#"$root/"}"
printf 'historical.md\ngenerated.md\n' >"$fixture/.gitignore"
printf '**Documentation status: historical snapshot.**\n' >"$fixture/historical.md"
printf '**Overall Status:** PASS\n' >"$fixture/generated.md"

check() {
    local expected="$1" name="$2" result=0
    bash tools/check_documentation_truth.sh >"$fixture/output.log" 2>&1 || result=$?
    if [[ "$result" -ne "$expected" ]]; then
        cat "$fixture/output.log"
        printf 'FAIL: %s (exit %s, expected %s)\n' "$name" "$result" "$expected" >&2
        exit 1
    fi
}

check 0 'local-only artifacts do not affect publication'
git add -f -- "$relative/historical.md"
check 1 'force-added historical material is rejected'
git update-index --force-remove -- "$relative/historical.md"
git add -f -- "$relative/generated.md"
check 1 'force-added generated evidence is rejected'
git update-index --force-remove -- "$relative/generated.md"
printf '**Documentation status: maintained reference.**\n\n[Local history](historical.md)\n' >"$fixture/reference.md"
git add -f -- "$relative/reference.md"
check 1 'existing local-only files cannot satisfy published links'
printf '**Documentation status: maintained reference.**\n\n[Published guide](../../README.md)\n' >"$fixture/reference.md"
check 0 'relative links to tracked files remain valid'
printf 'Documentation publication regressions passed (5 cases).\n'
