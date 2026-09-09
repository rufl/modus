# MODUS Mod Package Validation

> **Documentation status: maintained reference.** This page preserves dated, focused observations, not fresh proof. Published readiness is consolidated in [Current Status](CURRENT_STATUS.md); generated reports and raw logs remain local-only under the [truth contract](DOCUMENTATION_TRUTH.md).

**Generated:** 2026-07-13
**Status:** PASS
**Repository scan:** 9 packages, 0 errors, 8 disabled-mod warnings
**Focused proof:** `tests/unit/test_mod_package_validator.gd` — 4/4

## Validator

Run the repository scan with `godot --headless --script res://tools/validate_mod_packages.gd --path .`.

The validator reports missing `id`/`name`/`version` fields, invalid dependencies, missing package dependencies, invalid override shapes, disabled packages, and duplicate active override ownership with both mod IDs.

## Current Boundary

The reference sample and repository manifests validate structurally. Disabled legacy/example packages remain visible as warnings so they are not mistaken for active content. This does not prove packaged PCK/ZIP distribution, Workshop upload, multiplayer synchronization, or balance quality.
