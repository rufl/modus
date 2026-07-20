# Alien Blood Example Manifest

> **Documentation status: maintained reference.** This page describes `mod.json`; it is not live gameplay proof.

The manifest declares the `alien_blood` example and proposes blood-color, droplet-count, velocity, and physics overrides. It is `enabled: false` by default.

The repository package validator accepts the manifest shape, but no current runtime evidence proves these keys are consumed by the active blood implementation or produce a visible green-blood effect. Enable only in a test copy, inspect loader diagnostics, and record a gameplay observation before making a behavior claim.

See `docs/MOD_PACKAGE_VALIDATION.md` for structural validation and `docs/guides/MODDING.md` for the proven modding boundary.
