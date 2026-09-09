# MODUS Architecture

> **Documentation status: maintained reference.** This is a source map for the current checkout. It does not certify feature completeness or production readiness.

## Runtime entry points

- Godot requirement: 4.7+ (`project.godot` feature tag).
- Main scene: `shared/ui_core/screens/main_menu_screen.tscn`.
- Autoloads: `GameManager` and `MapGenerator` only.
- Game version constant: `0.9.5-beta` in `game/scripts/core/game_manager.gd`.
- Export presets: Windows client, Linux dedicated server, and Windows standalone editor. A preset is build configuration, not evidence that an exported product was tested.

## Core control plane

`game/scripts/core/game_manager.gd` combines several framework responsibilities:

- lifecycle state (`INITIALIZING`, `READY`, `RUNNING`, `PAUSED`, `SHUTTING_DOWN`);
- core-system registration and lookup;
- event subscribe/unsubscribe/emit;
- feature loading and unloading;
- configuration ownership.

This central surface is convenient but broad. Callers should use `get_core_system()` and feature APIs rather than inventing additional autoloads.

`MapGenerator` is a separate autoload at `game/scripts/map_generator/map_generator.gd` because procedural generation has its own state and worker lifecycle.

## Source ownership

| Path | Current role |
| --- | --- |
| `game/scripts/core/` | GameManager, configuration, logging, and foundational runtime code |
| `game/scripts/features/` | Feature modules and service implementations |
| `game/core/network/` | Network manager, dedicated server, Steam adapter, whitelist, and network support |
| `game/entities/` | Player, enemy, component, effect, and projectile runtime code |
| `game/world/` | Actors, maps, and test scenes |
| `game/editor/` | Embedded editor implementation |
| `shared/editor_core/` | Shared editor data, tools, gizmos, and UI resources |
| `shared/ui_core/` | Shared screens, components, and UI managers |
| `game/data/` | Content registries and authored game data |
| `game/config/` | Runtime configuration and feature profiles |
| `mods/` | Repository sample mods |
| `tests/` | GUT, property, benchmark, and manual evidence code |

The detailed data/config/mod override boundary is in `docs/technical/JSON_SCHEMAS.md`.

## Feature and service model

Feature enablement starts from `game/config/features.json5`; profile-specific data also exists below `game/config/features/`. The standard profile does not prove the headline multiplayer path. The `multiplayer_demo` profile has startup smoke evidence, while actual peer connectivity remains open.

Feature modules may register services in GameManager's core-system dictionary. Live IDs and implementations must be read from GameManager and the feature code; old documentation referring to a separate `GameCore` autoload or retired service tree is historical.

Typical access:

```gdscript
var config: Node = GameManager.get_core_system("config")
var network: Node = GameManager.get_core_system("network")
```

Always handle a missing optional service. Feature profiles can leave services unloaded.

## Networking boundary

The repository contains ENet hosting/joining, rate limits, an RPC whitelist, movement validation/prediction, a dedicated-server node, Steam adapter code, and multiplayer feature modules. Current proof is narrower:

- profile startup passes;
- September focused local real-ENet lifecycle/inventory/late-join observations supersede older sandbox socket failures for that narrow scope; latency/reconnect/dedicated-client proof remains open;
- real Steam/GodotSteam has no current runtime evidence;
- source-level authority and validation code is not a security certification.

See `docs/MULTIPLAYER_AUTHORITY_MODEL.md`, `docs/technical/STEAM_INTEGRATION.md`, and the generated readiness report.

## Editor and modding boundary

The embedded editor has focused save/export/reload round-trip proof. The standalone editor preset and scene exist, but its UI has explicit TODOs for undo/redo and mod export, and no current exported-app evidence. Local Workshop simulation proves filesystem behavior only; it does not prove Steam Workshop.

The sample mod and package validator provide bounded SDK evidence. They do not establish arbitrary asset replacement, packaging, distribution, or compatibility for every mod shape.

## Verification boundary

The architecture is exercised by focused tests and source guards. [Current Status](CURRENT_STATUS.md) consolidates dated evidence; historical aggregate results do not certify the current checkout. Use:

```bash
bash tools/check_project_truth.sh
./tests/runners/run_all_tests_headless.sh
```

Read `docs/CURRENT_STATUS.md` before making broader claims.
