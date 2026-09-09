# MODUS Troubleshooting

> **Documentation status: maintained reference.** These are current repository checks. Historical error reports may describe retired paths or already-fixed failures.

## Start with the evidence boundary

Read [Current Status](CURRENT_STATUS.md) and [Known Limits](KNOWN_LIMITS_MATRIX.md). Generated `docs/PRODUCTION_READINESS_REPORT.md` is a local output, absent from a fresh clone; regenerate it with `tools/validate_production_readiness.sh --run-godot-tests --strict` when attempting a new readiness baseline. See [report prerequisites](DOCUMENTATION_TRUTH.md#regenerating-local-reports). Some failures are known project blockers; others are environment limitations or missing local evidence. Do not erase any category by rerunning a narrower check or copying an old PASS.

## Godot is not found

The shell runners search `GODOT_BIN`, then `godot`, then `godot4`.

```bash
GODOT_BIN=/absolute/path/to/godot ./tests/runners/run_all_tests_headless.sh
```

The runner exits 127 if no executable is available.

## Import or cache errors

The maintained runners perform a headless import and isolate runtime state under `/tmp`. Remove only project-local generated state you intend to rebuild; do not treat cache cleanup as a code fix.

```bash
godot --headless --editor --path . --quit
```

If imports remain stale, close Godot before removing `.godot/`, then re-import. `.godot/` is generated state, not source.

## A GUT run has no final summary

An incomplete log is BLOCKED, not PASS. Common causes include timeout, process termination, parse failure, or a test that never returns. Preserve the log, run the smallest file that reproduces the issue, and keep the aggregate report open.

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_game_manager.gd
```

## The full suite is red while focused files pass

This is the current aggregate boundary. Order-dependent state, leaked nodes, deferred diagnostics, and shared singleton state can make a file pass alone and fail in the full selection. A focused pass does not replace the retained full-suite result.

Check:

- fixture ownership and GUT cleanup;
- mutable state shared across property iterations;
- event subscriptions removed during teardown;
- timers/threads joined before exit;
- intentional errors consumed explicitly;
- feature/service state reset between tests.

## GUI-required tests are skipped

The default headless runner excludes the two files listed in `tests/runners/headless_gui_required_tests.txt`. Use `--include-gui-required` to attempt them, but collect visual/input proof in a graphical editor or game session.

## ENet host/join cannot create a socket

`tools/run_enet_local_smoke.sh` may be blocked by sandbox socket policy. That is an environment blocker unless the same failure reproduces outside the restricted environment. Do not convert it into a connected-peer pass.

## Steam is unavailable

This checkout does not bundle GodotSteam. Expected fallback handling and local Workshop filesystem simulation do not prove Steam lobbies, relay, authentication, achievements, or Workshop service calls. See `docs/technical/STEAM_INTEGRATION.md`.

## Main menu launches but gameplay is unproven

The main-player-path smoke is intentionally a startup smoke. Use `docs/SHOWCASE_ROUTE.md` and `tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md` for the actual gameplay route, then validate the evidence bundle with:

```bash
tools/validate_manual_evidence.sh --strict
```

## Performance numbers look implausibly high

The retained showcase capture is unthrottled and includes a one-FPS sample plus a large maximum frame-time spike. It proves that a correctly shaped capture exists, not that the game sustains its average on target hardware. Read `docs/PERFORMANCE_BASELINE_PROOF.md` before citing it.

## Standalone editor limitations

The scene and export preset exist, but the source explicitly reports undo/redo and mod export as unavailable. The current editor round-trip proof exercises the focused model path, not a shipped standalone-editor UI.

## Dedicated server limitations

Dedicated mode is selected by the `dedicated_server` export feature, `--dedicated-server`, `--modus-dedicated`, or `MODUS_DEDICATED_SERVER=1`. The default config is `user://server_config.json5`. No current external client/server evidence proves a production deployment.

## Documentation conflict

Use this precedence order:

1. live source/configuration;
2. latest generated evidence reports;
3. maintained current docs;
4. historical snapshots.

Run `bash tools/check_documentation_truth.sh`. Historical files must never be promoted over current evidence.

## Reporting a reproducible problem

Record the Godot binary/version, command, exit code, complete final summary, relevant log path, environment constraints, and whether the failure reproduces in a focused run. Avoid “all tests fail” or “works” without the exact lane and totals.
