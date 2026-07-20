# MODUS SDK Sample Mod

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

This reference mod demonstrates the supported sample boundary:

- `config_overrides.weapons.pistol` changes a weapon value.
- `config_overrides.enemies.grunt` changes an enemy value.
- `config_overrides.loot` changes the loot multiplier.
- `scripts/sample_mod.gd` subscribes to `modus_sample_ping` and exposes an `on_enemy_spawn` hook.

The focused integration test validates the manifest, override shape, script inheritance, event exchange, and hook call. It does not claim a packaged release, Workshop upload, or live gameplay balance proof.
