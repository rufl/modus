# Harder Enemies Example Manifest

> **Documentation status: maintained reference.** This page describes `mod.json`; it is not live balance or gameplay proof.

The manifest declares the `harder_enemies` example and proposes overrides for `troo`, `cpos`, and `pain` enemy records. It is `enabled: false` by default.

The repository package validator accepts the manifest shape. No current runtime evidence proves every identifier maps to an active enemy, every field is consumed, or the resulting combat is harder or balanced. Treat the values as an inactive fixture until an enabled-mod run records loader output and observed enemy behavior.

See `docs/MOD_PACKAGE_VALIDATION.md` for structural validation and `docs/guides/MODDING.md` for the proven modding boundary.
