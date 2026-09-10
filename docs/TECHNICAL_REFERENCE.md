# MODUS Technical Reference

> **Documentation status: maintained reference.** This page lists current source entry points and stable public surfaces. It deliberately omits invented performance gains and unproven production guarantees.

## Project identity

| Item | Current value |
| --- | --- |
| Version | `0.9.5-beta` |
| Engine feature tag | Godot 4.7 |
| Main scene | `res://shared/ui_core/screens/main_menu_screen.tscn` |
| Autoloads | `GameManager`, `MapGenerator` |
| Overall readiness | NOT READY |

## GameManager

Source: `game/scripts/core/game_manager.gd`.

Current callable surfaces include:

```gdscript
GameManager.is_initialized()
GameManager.get_state()
GameManager.change_state(new_state)
GameManager.get_feature(feature_id)
GameManager.load_feature(feature_id)
GameManager.unload_feature(feature_id)
GameManager.is_feature_enabled(feature_id)
GameManager.register_core_system(system_id, node)
GameManager.get_core_system(system_id)
GameManager.get_service(service_id) # compatibility delegate
GameManager.subscribe(event_id, callback, priority)
GameManager.unsubscribe(event_id, callback)
GameManager.emit_event(event_id, data)
```

Features are configuration-dependent. A lookup can return null; callers must not assume every profile loads every service.

## Configuration and content

| Surface | Path |
| --- | --- |
| Feature/profile root | `game/config/features.json5` |
| Gameplay aggregate | `game/config/gameplay/gameplay.json5` |
| Movement configuration | `game/config/gameplay/movement.json5` |
| Network configuration | `game/config/network/network_config.json5` |
| Performance configuration | `game/config/performance/` |
| Weapon content registry | `game/data/weapons.json5` |
| Enemy content registry | `game/data/enemies.json5` |
| Loot registry | `game/data/loot_tables.json5` |

See `docs/technical/JSON_SCHEMAS.md` for ownership and mod overrides.

## Networking

Primary sources:

- `game/core/network/network_manager.gd`
- `game/core/network/rpc_whitelist.gd`
- `game/core/network/dedicated_server.gd`
- `game/core/network/steam_manager.gd`
- `game/scripts/features/network/`

`NetworkManager` contains hosting/joining, validation, rate limits, snapshots, prediction/reconciliation, and stats methods. `RPCWhitelist.ALLOWED_RPCS` denies unknown method names at the whitelist boundary, but many listed RPCs do not request additional validators. This is not a security audit or production certification.

ENet two-peer and real Steam proof remain open as described in the generated reports.

## Player and movement

- Player scene: `game/entities/player/player.tscn`
- Player script: `game/entities/player/player.gd`
- Component assembly: `game/entities/player/components/player_component_factory.gd`
- Movement state directory: `game/entities/player/components/states/`
- Movement status boundary: `docs/MOVEMENT_MECHANICS_STATUS.md`

Source wiring does not prove live feel, controller behavior, network correction, or collision edge cases.

## Editor

- Embedded editor: `game/editor/embedded_level_editor.gd`
- Shared editor library: `shared/editor_core/`
- Standalone scene: `standalone/editor/main.tscn`
- Focused proof: `docs/EDITOR_ROUNDTRIP_PROOF.md`

- The standalone entry now routes Undo/Redo through the shared runtime history manager and exports the current level through `LevelPackager` as `.mdsl`; focused proof covers both dispatch and packaging. Native exported-app startup and full graphical workflow evidence remain open.
- Advanced brush source: `game/editor/advanced_brush_tool.gd`; staircase, arch, torus, capsule, density-aware fill, and detached operation guards have focused proof.
- Concrete debt fixes: `editor_console.gd` now honors `setblock keep` occupancy, `editor_features.gd` resolves package authors from config/system identity, action nodes execute sound/variable/teleport operations, `DamageCalculator` applies configured armor formulas, rule hot reload removes only file-owned instances, and player profiles prefer SteamID persistence with non-Steam fallback.

## Map generation and showcase

- Map generator autoload: `game/scripts/map_generator/map_generator.gd`
- Maintained showcase: `game/world/maps/showcase.tscn`
- Compatibility world scene: `game/scenes/world.tscn`
- Showcase route: `docs/SHOWCASE_ROUTE.md`

Focused map tests are not equivalent to a complete threaded or manual gameplay pass.

## Modding

- Loader: `game/scripts/features/modding/mod_loader.gd`
- Package validator: `game/scripts/features/modding/mod_package_validator.gd`
- Sample: `mods/modus_sdk_sample/`
- Proof: `docs/MODDING_SAMPLE_MOD.md` and `docs/MOD_PACKAGE_VALIDATION.md`

Local Workshop simulation is filesystem proof only.

## Verification commands

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
./tests/runners/run_all_tests_headless.sh
```

For current totals and blockers, use `docs/CURRENT_STATUS.md`; never copy totals from a historical audit.
