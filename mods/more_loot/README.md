# More Loot Example Manifest

> **Documentation status: maintained reference.** This page describes `mod.json`; it is not live drop-rate or balance proof.

The manifest declares the `more_loot` example and proposes drop-chance, guaranteed-drop, and rarity-weight overrides for three loot-table records. It is `enabled: false` by default.

The repository package validator accepts the manifest shape. No current runtime evidence proves each override is applied by the active loot path or guarantees the described drops in gameplay. Treat these values as an inactive fixture until an enabled-mod run records loader output and observed drops.

See `docs/MOD_PACKAGE_VALIDATION.md` for structural validation and `docs/guides/MODDING.md` for the proven modding boundary.
