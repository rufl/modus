# Movement Mechanics Source Status

> **Documentation status: maintained reference.** This page describes source wiring, not player-visible completion. Project readiness remains defined by `docs/CURRENT_STATUS.md` and `docs/PRODUCTION_READINESS_REPORT.md`.

## Current boundary

The player factory creates a movement state machine and registers ten state scripts. That proves the state classes are present and wired into local-player setup. It does not prove every transition, input path, collision edge case, network correction, or gamepad path works in live play.

No current manual evidence bundle proves the complete movement experience. Treat all unchecked items below as open until observations are recorded through `tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md`.

## Registered states

`game/entities/player/components/player_component_factory.gd` preloads and instantiates:

| State | Source |
| --- | --- |
| Idle | `game/entities/player/components/states/idle_state.gd` |
| Walk | `game/entities/player/components/states/walk_state.gd` |
| Run | `game/entities/player/components/states/run_state.gd` |
| Jump | `game/entities/player/components/states/jump_state.gd` |
| In air | `game/entities/player/components/states/inair_state.gd` |
| Crouch | `game/entities/player/components/states/crouch_state.gd` |
| Slide | `game/entities/player/components/states/slide_state.gd` |
| Dash | `game/entities/player/components/states/dash_state.gd` |
| Wall run | `game/entities/player/components/states/wallrun_state.gd` |
| Fly/debug movement | `game/entities/player/components/states/fly_state.gd` |

The initial state is the first registered state, `IdleState`.

## Additional movement code

| Source | Source-level role | Important boundary |
| --- | --- | --- |
| `game/entities/player/components/player_movement_component.gd` | Coordinates normal movement and attached movement helpers | Live feel and full transition behavior are unproven. |
| `game/entities/player/advanced_movement.gd` | Air movement, bunny hop, slide, slope handling, and speed tracking | Always attached to a local player; behavior is configuration-dependent. |
| `game/entities/player/components/rope_movement_component.gd` | Rope attach, climb, swing, and detach code | Always attached locally; no current end-to-end rope evidence. |
| `game/entities/player/dodge_system.gd` | Double-tap/dedicated dodge input and cooldown state | Always attached locally; enabled/configured behavior still needs live input proof. |
| `game/entities/player/rocket_jump_system.gd` | Explosion-force and rocket-jump state | Created only when the `rocket_jump` feature is enabled. |
| `game/core/network/player_movement_predictor.gd` | Local prediction and server reconciliation code | Source presence is not connected-peer proof. |

## Configuration and input

- Movement data exists in `game/config/gameplay/movement.json5`.
- Player-balance movement values also exist under `balance.player.movement` in `game/config/gameplay/gameplay.json5`.
- Keyboard/gamepad actions are declared in `project.godot`; directional actions are `up`, `down`, `left`, and `right`, with separate `jump`, `crouch`, `sprint`, and `dodge` actions.
- Configuration values are not equivalent to observed behavior. Some mechanics have defaults, feature gates, or independent state code, so they must be checked in the running game.

## Required live verification

- [ ] Walk, sprint, jump, crouch, and land with keyboard and gamepad.
- [ ] Exercise idle/walk/run/jump/in-air/crouch transitions without lockups.
- [ ] Exercise slide, dash, wall run, dodge, rope movement, and rocket jump in scenes that support them.
- [ ] Verify collision, slopes, stairs, ceilings, and edge cases.
- [ ] Verify remote observation, server correction, and reconnect behavior with real peers.
- [ ] Record frame pacing and visible defects during the movement route.

Until those observations exist, the truthful status is: **source-wired, partially test-covered, and not end-to-end proven**.
