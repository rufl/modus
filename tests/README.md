# MODUS Test Suite

> **Documentation status: maintained reference.** Current outcomes are reported by `docs/AUTOMATED_TEST_LANES_REPORT.md` and `docs/PRODUCTION_READINESS_REPORT.md`; this page documents inventory and execution only.

## Current boundary

The repository has substantial green GUT coverage. The August 4 complete filtered Godot 4.7 aggregate passes 1440/1440 tests with 20,475 assertions and no risky/pending tests or GUT orphans in 702.76 seconds under a bounded 3600-second run. The August 1 Unit lane passes 1056/1056 with 16,419 assertions and Property passes 175/175 with 2,804 assertions; July 19 Integration 200/200 is retained. Current focused proof includes UI 26/26 with 109 assertions, manual recorder/timer 2/2 with 21 assertions, localization 27/27, mod/save UI packet 72/72 with 298 assertions, and reference/shader integrity 22/22. Automated recorder tests do not replace human observations, release-version proof, or distribution clearance.

The current source inventory records:

- 71 unit test scripts;
- 18 integration test scripts;
- 29 property test scripts;
- 2 GUI-required integration entries excluded from the default headless selection;
- benchmark and manual tooling outside the default GUT selection.

Run `bash tools/check_headless_runner_manifest.sh` to validate runner discovery and exclusions.

## Maintained commands

```bash
# Default unit + integration + property selection
./tests/runners/run_all_tests_headless.sh

# Durable per-category execution and generated triage report
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md

# Include the two GUI-required files; a suitable display/editor environment may be needed
./tests/runners/run_all_tests_headless.sh --include-gui-required

# Controlled player-visible framework-loop smoke
tools/run_showcase_golden_demo_smoke.sh --strict

# Normal-window human review with direct CSV evidence export
tools/run_manual_showcase_session.sh --tester NAME --input DEVICES

# Deterministic validator semantics (metadata, overhead, strict exits)
tests/runners/test_manual_evidence_validator.sh
```

Set `GODOT_BIN=/path/to/godot` when needed. The runners isolate Godot HOME, cache, and configuration directories under `/tmp` unless their `MODUS_GODOT_*` environment variables are overridden.

The production-readiness wrapper defaults to a 2400-second aggregate ceiling. The August 4 refresh used an explicit 3600-second bound and completed in 702.76 seconds. Set `MODUS_GODOT_SUITE_TIMEOUT_SECONDS` to another positive integer only when the evidence environment justifies a different ceiling.

## Layout

| Path | Role |
| --- | --- |
| `tests/unit/` | Unit and narrow subsystem contracts |
| `tests/integration/` | Multi-component and scene contracts |
| `tests/property/` | Generated/high-iteration properties |
| `tests/benchmarks/` | Synthetic or headless benchmark code; not GPU rendering proof |
| `tests/manual/` | Tools used while collecting human/runtime evidence |
| `tests/mocks/`, `tests/fixtures/` | Shared test support |
| `tests/runners/` | Maintained shell runners plus older/specialized GDScript runners |
| `tests/docs/` | Manual evidence and test-boundary documentation |

## Writing and interpreting tests

- Prefer `ModusGutTestBase` or the existing specialized base for the lane being changed.
- Add explicit types and `-> void` return annotations in touched GDScript tests.
- Register test-owned nodes with GUT cleanup helpers; avoid mixed manual and deferred teardown.
- Consume intentional warnings/errors explicitly so diagnostics do not become false failures.
- A focused pass closes only that focused contract.
- Pending/skipped tests, incomplete summaries, timeouts, and orphan reports remain evidence gaps.
- Headless benchmark numbers are not production rendering claims.

## Evidence chain

1. Run the narrowest relevant file or directory.
2. Run the corresponding category when practical.
3. Regenerate `docs/AUTOMATED_TEST_LANES_REPORT.md` for durable lane results.
4. Use `tools/validate_production_readiness.sh --run-godot-tests --strict` only when attempting a new full readiness baseline.
5. Keep manual, multiplayer, Steam, editor-UI, and hardware proof separate from model/structure tests.
