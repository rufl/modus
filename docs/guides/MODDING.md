# MODUS Modding Guide

> **Documentation status: maintained reference.** The proven boundary is the repository sample mod and package validator. Packaging, arbitrary asset replacement, UI activation, and real Workshop distribution are not end-to-end proven.

## Current source surface

- Loader: `game/scripts/features/modding/mod_loader.gd`
- Manifest validator: `game/scripts/features/modding/mod_package_validator.gd`
- Repository samples: `mods/`
- Runtime/user location: `user://mods/`
- Reference sample: `mods/modus_sdk_sample/`
- Focused evidence: `docs/MODDING_SAMPLE_MOD.md` and `docs/MOD_PACKAGE_VALIDATION.md`

The loader reads folder manifests named `mod.json` and has code paths for folders, PCKs, ZIPs, config overrides, asset mappings, scripts, dependencies, and feature/component/entity registration. Those source paths do not prove every package shape works in an exported build.

Discovered manifests are represented as disabled by default in `ModLoader`, regardless of an `enabled` value in the file. Activation state must be handled by the runtime mod-management path; do not assume dropping a folder enables it.

## Minimal manifest

The package validator requires non-empty `id`, `name`, and `version` fields:

```json
{
  "id": "example_mod",
  "name": "Example Mod",
  "version": "0.1.0",
  "enabled": false,
  "dependencies": [],
  "config_overrides": {},
  "scripts": []
}
```

`dependencies` must be an array and `config_overrides` must be an object when present.

## Proven sample pattern

`mods/modus_sdk_sample/mod.json` demonstrates:

- weapon, enemy, and loot configuration overrides;
- one script derived from the mod script base;
- a GameManager event subscription;
- an enemy-spawn hook.

Its focused integration test proves the manifest shape, script inheritance, event exchange, and direct hook call. It does not prove final gameplay balance, package signing, UI enablement, or Steam upload.

## Script hooks and events

Use the current GameManager event API:

```gdscript
func _ready() -> void:
    GameManager.subscribe("example_ping", _on_example_ping)

func _exit_tree() -> void:
    GameManager.unsubscribe("example_ping", _on_example_ping)

func _on_example_ping(data: Dictionary) -> void:
    pass
```

Always unsubscribe on teardown. Optional services obtained with `get_core_system()` can be null under a feature profile.

## Validate packages

```bash
godot --headless --path . --script tools/validate_mod_packages.gd
```

The validator reports missing required fields, type errors, missing dependencies, disabled packages, and duplicate active override ownership. A clean repository scan proves only the manifests scanned by that command.

## Asset and package caution

The loader contains resource-override and packed-mod code, but there is no current published compatibility matrix for every texture/audio/scene/resource format. Test each override in a normal game session and an export. Treat loose files, PCK, ZIP, and Workshop as separate evidence lanes.

## Workshop boundary

`tests/integration/test_workshop_local_simulation.gd` proves a local filesystem simulation for upload/download/cache/subscription concepts. Real Steam Workshop remains blocked on GodotSteam, Steam client/account, app ID, and service evidence.

## Safe contribution sequence

1. Copy the sample mod shape.
2. Keep IDs unique and dependencies explicit.
3. Run package validation.
4. Add a focused integration test for the behavior being introduced.
5. Observe the mod in a normal runtime session.
6. Record package/export/Workshop evidence separately.
