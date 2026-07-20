# MODUS Showcase Route

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

**Status:** route defined; manual capture evidence remains pending
**Scene:** `res://game/world/maps/showcase.tscn`
**Compatibility entry point:** `res://game/scenes/world.tscn`

This is the bounded route for screenshots, video capture, and manual gameplay validation. It is a human-run route; the automated showcase-map test proves scene structure and loadability, not player movement or combat quality.

## Preflight

1. Open the project with Godot 4.7+ and run `res://game/world/maps/showcase.tscn`.
2. Confirm the scene loads without parse errors and the player starts at a `player_spawn` marker.
3. Start the manual timer from `tests/manual/manual_test_timer.gd` and record the resulting CSV under `logs/manual_test_logs/`.

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

- Store manual timer CSVs in `logs/manual_test_logs/`.
- Store screenshots/video metadata beside the capture or in the release evidence bundle; do not claim captures from source-only tests.
- Validate imported CSV evidence with `tools/validate_manual_evidence.sh --strict`.
- Update `docs/MANUAL_EVIDENCE_REPORT.md` and `docs/CURRENT_STATUS.md` only after the route has been observed in a normal Godot session.

## Automated Boundary

`tests/integration/test_showcase_map.gd` checks that the scene exists, loads, instantiates, has player spawns, navigation/lighting/environment/collision structure, and stays within basic node/light limits. It does not close the golden-demo or manual-gameplay backlog items.
