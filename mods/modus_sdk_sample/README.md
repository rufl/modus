# MODUS SDK Sample Mod

> **Documentation status: maintained reference.** Published readiness is consolidated in [Current Status](../../docs/CURRENT_STATUS.md); narrower claims here apply only to the sample-mod workflow. Generated reports and historical evidence remain local-only under the [truth contract](../../docs/DOCUMENTATION_TRUTH.md).

This reference mod demonstrates the supported sample boundary:

- `config_overrides.weapons.pistol` changes a weapon value.
- `config_overrides.enemies.grunt` changes an enemy value.
- `config_overrides.loot` changes the loot multiplier.
- `scripts/sample_mod.gd` subscribes to `modus_sample_ping` and exposes an `on_enemy_spawn` hook.

The focused integration test validates the manifest, override shape, script inheritance, event exchange, and hook call. It does not claim a packaged release, Workshop upload, or live gameplay balance proof.
