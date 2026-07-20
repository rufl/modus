# MODUS Test Suite

> **Documentation status: maintained reference.** Current outcomes are reported by `docs/AUTOMATED_TEST_LANES_REPORT.md` and `docs/PRODUCTION_READINESS_REPORT.md`; this page documents inventory and execution only.

## Current boundary

The repository has substantial green GUT coverage. The July 19 complete filtered Godot 4.7 aggregate passes 1431/1431 tests with 20,362 assertions and no risky/pending tests or GUT orphans in 1770.186 seconds under a 2400-second evidence ceiling. The latest category packet also passes Unit 1056/1056 with zero orphans, Integration 200/200, and Property 175/175. Automated green status does not replace manual, release-version, or distribution-clearance evidence.

The current source inventory records:

- 70 unit test scripts;
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
```

Set `GODOT_BIN=/path/to/godot` when needed. The runners isolate Godot HOME, cache, and configuration directories under `/tmp` unless their `MODUS_GODOT_*` environment variables are overridden.

The production-readiness wrapper bounds the aggregate run to 900 seconds by default. The July 18 complete run required an evidence-derived 2400-second ceiling because the category packet had already established that the property lane alone exceeds 900 seconds. Set `MODUS_GODOT_SUITE_TIMEOUT_SECONDS` to another positive integer only when the evidence environment justifies a different ceiling.

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
