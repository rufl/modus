# Manual Test Timing and CSV Evidence

> **Documentation status: maintained reference.** This page reflects `tests/manual/manual_test_timer.gd`. A timer log records observations; it does not make those observations pass automatically.

## Source behavior

`ManualTestTimer` can:

- start/end one named session;
- start/complete one test at a time;
- record `pass`, `fail`, or any other value (counted as incomplete by current code);
- calculate durations and aggregate counts;
- write CSV to `user://manual_test_logs/<session>.csv`.

## Minimal use

```gdscript
var timer := ManualTestTimer.new()
add_child(timer)

timer.start_session("showcase_player_route")
timer.start_test("startup_and_spawn")
# Perform and observe the step.
timer.complete_test("pass", "Main menu and showcase spawn observed")
timer.end_session()
```

The CSV header is:

```text
Timestamp,TestName,Duration,Result,Notes
```

The source appends a `# Session Summary` section with session name, total duration/tests, pass/fail/incomplete counts, test-time statistics, and overhead.

## Import and validate

1. End the session so its summary is written.
2. Copy the CSV from the Godot user-data directory into `logs/manual_test_logs/`.
3. Keep failed/incomplete rows; never edit them into passes.
4. Run:

```bash
tools/validate_manual_evidence.sh --strict
```

The current generated report is BLOCKED because no validated manual evidence files/hours are present.

## Evidence quality

Use stable test names from `tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md`. Notes should identify the scene/profile, input device, visible result, and defect/reference when a step fails or is skipped. Timing alone does not prove visual quality, correctness, or coverage.
