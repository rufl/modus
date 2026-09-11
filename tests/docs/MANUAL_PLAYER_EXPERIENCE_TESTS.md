# Manual Player Experience Checklist

> **Documentation status: maintained reference.** Every item is unproven until a normal graphical session records a pass/fail/skip result. The current repository evidence directory contains 0.00 validated manual hours.

## Evidence rules

- Use Godot 4.7 in a normal graphical session.
- Record OS, renderer, resolution, input devices, scene/profile, build identity, and tester.
- Prefer `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES`; it launches the main-menu route with an F8 review overlay, writes CSV directly to `logs/manual_test_logs/`, and enables local JSONL telemetry in `logs/validation_telemetry/`.
- Mark failures and unavailable paths explicitly; Fail and Skip require notes and must not be omitted from the session.
- Direct `ManualTestTimer` users may still copy completed CSVs from `user://manual_test_logs/` to `logs/manual_test_logs/`.
- Required metadata: tester, OS, renderer, resolution, input devices, scene route, and build identity.
- Run `tools/validate_manual_evidence.sh --strict` after each imported session; only test-row time counts toward the threshold.

## Local validation telemetry

Set `MODUS_LOCAL_TELEMETRY=1` before a testplay session to record opt-in JSONL events under `user://validation_telemetry/`. The recorder captures session metadata, scene paths, input actions, runtime samples, warning/error log signals, and explicit checkpoints. It never sends data over the network or uploads automatically.

Use `LocalValidationTelemetry.checkpoint("name", {"key": value})` from a local test harness or feature probe for milestone evidence. Summarize exported files with:

```bash
python tools/report_local_validation_telemetry.py \
  --logs logs/validation_telemetry \
  --report logs/validation_telemetry/report.md
```

Copy only reviewed telemetry and the associated manual CSV/captures into the evidence bundle. Telemetry indicates what occurred; it does not replace human pass/fail notes.

## Startup and route

- [ ] Main menu opens and all visible primary actions respond.
- [ ] Maintained showcase scene loads through the intended user route.
- [ ] Local player spawns at a valid marker without falling through geometry.
- [ ] Pause/resume and clean exit work.
- [ ] Runtime log is reviewed for parse errors, repeated exceptions, and severe warnings.

## Input and movement

- [ ] Keyboard/mouse movement, look, jump, sprint, crouch, and pause work.
- [ ] One real gamepad can navigate UI and control the player without keyboard cross-talk.
- [ ] Walk/run/jump/in-air/crouch transitions recover cleanly.
- [ ] Slide, dash, dodge, wall run, rope, rocket jump, and fly/debug paths are tested where available; unavailable paths are marked skip with reason.
- [ ] Slopes, stairs, ceilings, ledges, collisions, and respawn do not trap the player.

## Combat and feedback

- [ ] At least one loaded weapon is visible and can fire, reload, and switch.
- [ ] Ammo/weapon HUD state matches the action performed.
- [ ] A valid enemy receives damage and reaches a death state.
- [ ] Muzzle, tracer, impact, blood, hit, damage-direction, audio, and screen feedback are observed and defects recorded.
- [ ] Ragdoll/gib behavior remains bounded and does not launch, sink, or persist incorrectly.

## World and gameplay loop

- [ ] Collision, lighting, environment, and navigation-visible areas render as intended.
- [ ] At least one interactable/hazard responds or is recorded absent.
- [ ] Loot/inventory pickup and use are exercised where available.
- [ ] Save, reload, and restored state are observed through a real gameplay path.
- [ ] Sample mod behavior is observed separately from its focused model test.

## UI and accessibility observation

- [ ] Crosshair, health, ammo, prompts, and pause surfaces are readable at the tested resolution.
- [ ] Keyboard and gamepad focus are visible and do not become trapped.
- [ ] Text clipping, contrast, scaling, color-only communication, and motion discomfort are recorded.
- [ ] Every visible menu/context action either works or is logged as an inert affordance.

## Multiplayer and splitscreen (separate evidence lane)

- [ ] ENet host and client connect in separate real processes outside the restricted socket sandbox.
- [ ] Movement, combat, damage, death/respawn, chat, disconnect, and reconnect synchronize.
- [ ] Four, five, and six physical-controller assignment/layout paths are attempted if claimed for support.
- [ ] Device isolation, disconnect/reconnect, pause, teardown, HUD, and frame pacing are recorded.
- [ ] Steam paths remain skipped/blocked unless the exact GodotSteam/Steam environment is present.

## Editor and modding (separate evidence lane)

- [ ] Embedded editor opens, edits, saves, closes, reloads, and preserves content.
- [ ] Standalone editor export/entry is tested before calling it functional.
- [ ] Visible undo/redo and mod-export limitations match the source or are repaired.
- [ ] Mod activation, dependency errors, conflicts, and one sample override are observed.
- [ ] Real Workshop remains blocked unless actual Steam service calls are captured.

## Performance observation

- [ ] Warm-up and measured window use a documented, repeatable workload.
- [ ] Hardware, driver, renderer, resolution, VSync/frame cap, player/enemy counts, and duration are recorded.
- [ ] Average, minimum, percentile/frame-time spikes, memory, and visible warnings are retained.
- [ ] Results are not generalized beyond tested hardware/configuration.

## Session closure

- [ ] Every started item has pass/fail/skip; incomplete rows are retained as failures until rerun.
- [ ] Screenshots/video metadata and logs are retained where relevant.
- [ ] CSV is copied to `logs/manual_test_logs/`.
- [ ] Strict manual validator result is regenerated.
- [ ] `docs/CURRENT_STATUS.md` changes only if the generated report supports the new claim.
