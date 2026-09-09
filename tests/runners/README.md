# MODUS Test Runners

> **Documentation status: maintained reference.** This page describes runner behavior. Published dated outcomes are consolidated in [Current Status](../../docs/CURRENT_STATUS.md); generated reports describe individual local invocations.

## Maintained shell runners

### Full default selection

```bash
./tests/runners/run_all_tests_headless.sh
```

The runner:

- discovers GUT files below `tests/unit`, `tests/integration`, and `tests/property`;
- omits entries in `headless_gui_required_tests.txt` by default;
- imports the project before running GUT;
- uses isolated writable Godot runtime directories;
- returns GUT's nonzero status when selected tests fail;
- exits 127 when no usable Godot binary is found.

Use `--include-gui-required` to include the excluded files. Inclusion does not guarantee they can run meaningfully without a display or editor services.

### Durable category lanes

```bash
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
```

This runs unit, integration, and property selections separately, records incomplete summaries as blocked, and writes the generated lane report. Benchmark evidence is a separate lane and must not be inferred from unit/property timing tests.

The report and raw `logs/` are ignored local outputs, not committed checkout inputs. See [report regeneration](../../docs/DOCUMENTATION_TRUTH.md#regenerating-local-reports) for the other gates and prerequisites.

After a complete local run, regenerate the report without rerunning Godot by naming that run's retained local log directory. This is historical log reuse, not fresh current-tree proof; the directory is absent from a fresh clone:

```bash
./tests/runners/run_tests_by_category.sh \
  --report docs/AUTOMATED_TEST_LANES_REPORT.md \
  --log-dir logs/automated_test_lanes_YYYYMMDD_vN \
  --reuse-logs
```

Reuse mode requires complete `unit.log`, `integration.log`, and `property.log` files. Missing summary metrics remain BLOCKED; a green GUT summary with no emitted `Failing Tests` row is normalized to zero failures.

### Environment

```bash
GODOT_BIN=/path/to/godot ./tests/runners/run_all_tests_headless.sh
```

Optional overrides:

- `MODUS_GODOT_DATA`
- `MODUS_GODOT_CACHE`
- `MODUS_GODOT_CONFIG`
- `MODUS_HEADLESS_GUI_REQUIRED_MANIFEST`
- `MODUS_INCLUDE_GUI_REQUIRED=1`

## Single-file GUT selection

After a project import, GUT accepts a resource path:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_manager.gd
```

Use the same isolated environment as `headless_common.sh` when reproducing CI-like behavior.

## Specialized GDScript runners

The directory also contains older or narrow runners such as `run_map_generator_tests.gd`, `run_performance_benchmarks.gd`, and `run_single_test.gd`. They are not substitutes for the maintained shell selection unless their own result is the exact contract being investigated. `run_gut_tests_headless.gd` and `run_gut_tests.gd` are legacy alternatives with different discovery/startup behavior.

## GUI-required manifest

`headless_gui_required_tests.txt` currently contains:

- `res://tests/integration/test_player_experience_integration.gd`
- `res://tests/integration/test_hud_visual_feedback.gd`

Remove an entry only after it passes under the default headless runner without GUI/editor-only services.

## Verification

```bash
bash tools/check_headless_runner_manifest.sh
bash tools/check_project_truth.sh
```

Historical aggregate outcomes do not certify the current checkout. A runner working correctly is not equivalent to the selected tests passing.
