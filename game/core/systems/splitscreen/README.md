# Splitscreen Runtime

> **Documentation status: maintained reference.** This page describes the source/configuration surface. The splitscreen production-readiness lane remains open.

## Current source

| File | Role in source |
| --- | --- |
| `splitscreen_manager.gd` | Session lifecycle and subsystem coordination |
| `session_state.gd` | Session/player/device state model |
| `gamepad_controller.gd` | Device discovery and assignment |
| `viewport_manager.gd` | SubViewport creation and layout |
| `splitscreen_input_component.gd` | Per-device input reads |
| `performance_profiler.gd` | Bounded performance samples and quality state |
| `rate_limiter.gd` | Local operation throttling helper |

Configuration is in `game/config/features/splitscreen.json5`. It currently declares an enabled feature, 4-player minimum/default, 6-player maximum, automatic 2x2/2x3/3x2 layouts, target/performance settings, and gamepad/UI options. Those values express configuration intent, not hardware-tested support.

## Current proof boundary

Focused configuration, manager, gameplay, feature-integration, stress, compatibility, assignment-UI, viewport, error-recovery, and 30-property tests have dated green results recorded in the root changelog and consolidated status. Five-player layout logic now fills the display with five equal 20% regions. No current manual evidence bundle proves four-to-six physical gamepads, real viewports, disconnect/reconnect, visible layout quality, or sustained performance.

Use [Current Status](../../../../docs/CURRENT_STATUS.md) for the historical aggregate and current proof gaps rather than obsolete local reports. Splitscreen is **substantial source plus focused contract proof**, not a finished 4–6-player product.

## Required live proof

- Run the real assignment UI with 4, 5, and 6 physical controllers.
- Confirm unique device routing and no cross-player input.
- Verify 2x2, 2x3, and 3x2 layout/camera/HUD behavior.
- Exercise disconnect, reconnect, cancel, pause, and teardown.
- Capture graphical performance and frame pacing under the same scene/workload.
- Rerun the strict aggregate suite after any repair.

Related tests live below `tests/unit/splitscreen/`, `tests/integration/splitscreen/`, and `tests/property/splitscreen/`.
