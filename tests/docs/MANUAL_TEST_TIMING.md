# Manual Test Timing and CSV Evidence

> **Documentation status: maintained reference.** This page reflects `tests/manual/manual_test_timer.gd` and the test-only recorder. A timer log records human observations; it never creates gameplay passes automatically.

## Recommended workflow

Launch a normal graphical session from the repository root:

```bash
GODOT_BIN=Godot-4.7 tools/run_manual_showcase_session.sh \
  --tester "Reviewer Name" \
  --input "keyboard_mouse,gamepad_xbox" \
  --renderer gl_compatibility \
  --resolution 1280x720
```

The game opens at the maintained main menu. The recorder begins with the first bounded showcase item:

1. Press **F8** or **Gamepad Back** to hide the recorder and perform the displayed test.
2. Toggle the same control again to pause and review the result.
3. Add observation notes, then choose **Pass**, **Fail**, or **Skip**.
4. Fail and Skip require a reason; Pass notes are optional.
5. End the session normally so the summary and metadata are flushed.

The overlay is test-only and is not part of the shipped game route. It uses responsive safe margins, visible keyboard/gamepad focus, 48-pixel-or-larger logical actions, and a compact 800×600 layout.

## Evidence destination

The runner writes directly to:

```text
logs/manual_test_logs/<session>.csv
```

Use `--evidence-dir` only when evidence must be staged elsewhere. Direct `ManualTestTimer` users may set `output_directory` or `MODUS_MANUAL_EVIDENCE_DIR`; otherwise the fallback remains `user://manual_test_logs`.

`logs/` is ignored local evidence, not committed input or a fresh-clone fixture. Publication cleanup preserves existing CSVs byte-for-byte locally; do not delete them to make a gate pass. Publish reviewed, dated conclusions in maintained status/changelog entries. The validator below regenerates local-only `docs/MANUAL_EVIDENCE_REPORT.md`; neither that output nor an old PASS replaces a new reviewed session.

Each CSV includes:

- stable test IDs and pass/fail/skip/incomplete results;
- per-test duration and notes;
- tester, OS, renderer, resolution, input devices, scene route, and build identity;
- wall-session and active-test timing summaries.

## Truth boundary

`tools/validate_manual_evidence.sh` counts only completed test-row duration toward the configured threshold. Recorder setup time and idle overhead do not count. It rejects malformed rows, missing required metadata, fail/skip rows without notes, failed items, and incomplete/unknown results.

Run:

```bash
tools/validate_manual_evidence.sh --strict
```

Keep failed and skipped rows truthful. Fixing or accepting an observation requires a new reviewed session, not editing an old CSV into a pass.
