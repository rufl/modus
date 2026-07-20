# Data and Configuration Ownership

> **Documentation status: maintained reference.** This page maps the current files and loader behavior. It does not claim every declared key is consumed by gameplay.

## Ownership Boundary

| Path | Current role |
| --- | --- |
| `game/data/` | Content registries and inputs: weapons, enemies, loot tables, sample items, localization, and map-generator data. |
| `game/config/` | Runtime configuration: feature profiles plus gameplay, network, entity, item, debug, graphics, and performance settings. |
| `mods/` | Repository fixtures and sample packages. Most example manifests are disabled. |
| `user://mods/` | User-installed package discovery path used by mod source. |

In short, `game/data/` is content data, `game/config/` is runtime configuration, and `user://mods/` is the user-installed package-discovery boundary.

Do not recreate retired parallel configuration directories or move runtime configuration into `game/data/`.

## Configuration Loaded by GameManager

During initialization, `game/scripts/core/game_manager.gd` creates `ConfigurationManager` and loads:

- `game/config/performance/system.json5`
- `game/config/performance/graphics.json5`
- `game/config/performance/visuals.json5`
- `game/config/performance/debug.json5`
- `game/config/gameplay/gameplay.json5`
- `game/config/gameplay/loot.json5`

It separately loads `game/config/features.json5` as the feature-profile switchboard. Additional files under `game/config/features/`, `entities/`, `items/`, `network/`, and other subdirectories exist, but file presence does not prove GameManager loads each file directly or that every key has a live consumer.

### Current top-level groups

- `gameplay/gameplay.json5`: `ai_combat`, `movement`, `combat`, `loot`, `difficulty`, `balance`, `game_rules`, `free_roam`, `player_modes`, `map_settings`, `fall_death`, and `enemies`.
- `performance/visuals.json5`: top-level `ui` plus a `visuals` namespace containing `hud`, `screen_shake`, `gore`, `targeting`, `quality_presets`, `scoreboard`, `death_messages`, `chat`, `day_night`, `boss_effects`, and `weapon_visuals`. The duplicate nested `ui` declaration was removed; consumers use the canonical `visuals.*` paths for gameplay-facing visual settings.
- `performance/system.json5`: `systems_enabled`, `performance`, `prop_replacer`, `first_person_camera`, `network`, `console`, `audio_profiles`, `maps`, and `interaction`.

These are declared groups, not a guarantee that every setting is read or effective.

## Content Data

The main registries are:

- `game/data/weapons.json5` — entries from `knife` through `bfg`, including scene/script/icon paths and nested stats;
- `game/data/enemies.json5` — enemy records, aliases, bot records, and tier modifiers;
- `game/data/loot_tables.json5` — content loot definitions;
- `game/data/items/` and `game/data/map_generator/` — additional item and generation inputs.

Representative live values can change; inspect the files instead of copying old examples. Existing reference-integrity tests cover selected paths, not every field or asset.

## Access Semantics

`ConfigurationManager` is registered as GameManager's `config` core system:

```gdscript
var config_manager: Node = GameManager.get_core_system("config")
var speed: float = config_manager.get_value("gameplay.balance.player.base_speed", 7.0)
```

`get_value()` searches the manager's cached files using dot notation and returns the supplied default when no value is found. Because it searches multiple cached dictionaries, callers should use namespaced keys where duplicate group names could make ownership ambiguous.

`is_feature_enabled(id)` reads the loaded `systems_enabled` dictionary and defaults to `true` when an ID is absent. That opt-out behavior is source behavior, not a recommendation for security-sensitive switches.

## Reload Boundary

The manager implements `reload_file()`, `reload_all()`, `enable_file_watching()`, and `check_for_changes()`, and emits `config_reloaded(file_path)`. The current GameManager initialization does not enable or poll file watching. Automatic hot reload therefore requires an explicit caller; do not describe it as active by default.

## Mod Overrides

Manifests can declare `config_overrides` and asset mappings. Structural validation is reported in `docs/MOD_PACKAGE_VALIDATION.md`. The focused sample proves a bounded override/event/hook contract; it does not prove arbitrary files, all package formats, multiplayer synchronization, or real Workshop distribution.

## Verification

```bash
bash tools/check_project_truth.sh
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_configuration_manager.gd
```

Use `GODOT_BIN` or the repository runners when `godot` is not on PATH. Current project-wide totals remain in `docs/DOCUMENTATION_TRUTH.md`.
