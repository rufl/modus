# MODUS SDK Sample Mod Proof

> **Documentation status: maintained reference.** This page preserves dated, focused observations, not fresh proof. Published readiness is consolidated in [Current Status](CURRENT_STATUS.md); generated reports and raw logs remain local-only under the [truth contract](DOCUMENTATION_TRUTH.md).

**Generated:** 2026-07-13
**Status:** PASS
**Sample:** `mods/modus_sdk_sample/`
**Focused proof:** `tests/integration/test_sample_mod_sdk.gd` — 2/2

## Covered SDK Surface

- Manifest discovery fields and script declaration
- Weapon override: `pistol.display_name` and `pistol.damage`
- Enemy override: `grunt.health`
- Loot override: `drop_rate_multiplier`
- `ModScript` inheritance and lifecycle installation
- Event subscription/receipt through `modus_sample_ping`
- `on_enemy_spawn` hook invocation

## Reload Lifecycle

Reload frees loader-owned script nodes before creating replacements and restores owned data/configuration and resource-path overrides. Disabled or deleted mods no longer retain those loader-managed effects. `ModScript._mod_cleanup()` (or an ordinary script's `on_mod_unloaded()`) must undo external side effects such as mutations to unrelated nodes.

Already-held references to replacement resources are not rewritten; subsequent loads use the restored paths. Godot-mounted PCK/ZIP packs cannot be unmounted by this lifecycle. These boundaries also apply when a mod is disabled.

## Boundary

This is a source-and-runtime contract proof for one sample mod. It does not prove packaged PCK/ZIP distribution, Workshop upload, multiplayer synchronization, or player-visible balance quality. Those remain separate backlog/evidence tasks.
