# MODUS Showcase Route

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

**Status:** automated golden-demo route PASS; manual gameplay evidence remains pending
**Scene:** `res://game/world/maps/showcase.tscn`
**Compatibility entry point:** `res://game/scenes/world.tscn`

This is the bounded route for screenshots, video capture, automated framework-loop proof, and manual gameplay validation. The automated golden-demo smoke proves one controlled action path; it does not prove player-perceived movement or combat quality.

## Preflight

1. Start `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES` with Godot 4.7+ in a normal graphical environment.
2. Press **F8** or **Gamepad Back** to resume the maintained main menu, activate **Showcase**, and toggle the recorder whenever an observation is ready.
3. Review the responsive welcome panel, then activate **Begin Showcase** by mouse, Enter/Space, or gamepad A.
4. Confirm the player starts at a `player_spawn` marker without parse errors. The recorder writes the reviewed CSV directly under `logs/manual_test_logs/`.

## Capture Checklist

| Step | Action | Expected visible state | Capture point |
| --- | --- | --- | --- |
| 1 | Launch the showcase scene | Player is standing in the maintained showcase map | Wide establishing screenshot |
| 2 | Move through the main geometry | Camera and collision remain stable; no fall-through | Movement clip or screenshot |
| 3 | Look across the navigation area | Lighting, environment, and navigation region are present | Wide environment screenshot |
| 4 | Exercise any visible interactable or hazard | The element responds, or its absence is recorded | Interaction screenshot/video |
| 5 | If an enemy/player fixture is present, engage it | Combat feedback is visible and the result is recorded | Combat clip; otherwise mark N/A |
| 6 | Exit cleanly | No crash or stuck teardown | Final timer timestamp |

## Evidence Handoff

- The recommended runner stores CSVs directly in `logs/manual_test_logs/`; direct timer users must import their `user://manual_test_logs/` output.
- Store screenshots/video metadata beside the capture or in `docs/RELEASE_EVIDENCE_BUNDLE.md`; do not claim captures from source-only tests.
- The retained menu captures prove the Showcase entry is visible, not that the gameplay route was activated successfully.
- Validate CSV evidence with `tools/validate_manual_evidence.sh --strict`; only reviewed test-row duration counts, not recorder overhead.
- Update `docs/MANUAL_EVIDENCE_REPORT.md` and `docs/CURRENT_STATUS.md` only after the route has been observed in a normal Godot session.

## Automated Boundary

`tests/integration/test_showcase_map.gd` checks that the scene exists, loads, instantiates, has player spawns, navigation/lighting/environment/collision structure, and stays within basic node/light limits. `SHOWCASE_LAUNCH_SMOKE.md` records startup only. `GOLDEN_DEMO_SMOKE.md` adds controlled movement, firing, enemy, pickup, save/load, and sample-mod runtime proof; none of these replaces manual gameplay evidence.
