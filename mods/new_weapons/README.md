# New Weapons Example Manifest

> **Documentation status: maintained reference.** This page describes `mod.json`; it is not proof of usable weapons or assets.

The manifest declares the `new_weapons` example and proposes records for a laser rifle, plasma gun, minigun, and two ammo types. It is `enabled: false` by default.

The repository package validator accepts the manifest shape. The package does not contain corresponding weapon scenes, models, sounds, projectiles, or scripts, and no current gameplay run proves that these records become selectable or functional weapons. Treat it as a schema/configuration fixture only.

See `docs/MOD_PACKAGE_VALIDATION.md` for structural validation and `mods/modus_sdk_sample/` for the bounded sample-mod contract that has focused automated proof.
