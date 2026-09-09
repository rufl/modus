# Shared Shader Sources

> **Documentation status: maintained reference.** This page describes files currently present under `shared/shaders/`. It does not claim that the demos parse, render correctly, meet a performance target, or are cleared for distribution.

## Current Source Inventory

The directory contains two blood-pool shader variants, controller/manager scripts, procedural texture helpers, and three demo/test scenes. The primary pair is:

- `blood_pool.gdshader` — spatial shader with arrays for 64 drop positions and scales;
- `blood_pool.gd` — `BloodPoolShader`, a `MeshInstance3D` controller that writes those arrays and recycles inactive drops.

Additional scripts include `blood_pool_manager.gd`, `blood_effects_global.gd`, texture generators, examples, and quick-test/demo scenes. File presence is the only project-wide claim made here.

## Current Wiring Boundary

- `project.godot` does **not** register `blood_effects_global.gd` as a `BloodEffects` autoload.
- The source comment in `blood_effects_global.gd` is setup advice, not evidence that the singleton is active.
- No maintained automated test or generated report currently proves the blood-pool demos render or integrate with combat.
- No current benchmark supports GPU-cost, frame-rate, pool-size, or low-end-hardware claims.

## Current Runtime Boundary

The August 2 source pass corrected the `HEIGHTMAP_STRENGTH` vertex identifier and made the controller fail clearly when surface 0 has no active `ShaderMaterial`. A fresh Godot 4.7 parse/render run is still required before describing the shared demo as working or integrated.

## Provenance Boundary

The implementation was reviewed against dip000's `BloodyPool` source at commit `7a3e9bc685255d37f489e25b509fb56e185aa9fb`. The upstream MIT notice is retained at `docs/licenses/DIP000_BLOODY_POOL_MIT.txt`, and both derived files are cleared in `docs/PROVENANCE_LEDGER.csv`. Historical shader guides remain local-only and absent from fresh clones; their old links and claims are not required reading or current proof.

## Before Using or Shipping

1. Confirm every demo scene imports and renders in Godot 4.7.
2. Add a focused test or recorded visual check for drop creation, recycling, and teardown.
3. Measure performance in the actual target scene and hardware profile.
4. Include the retained MIT notice in packaged release artifacts.

Published project readiness is consolidated in [Current Status](../../docs/CURRENT_STATUS.md). The [Documentation Truth Contract](../../docs/DOCUMENTATION_TRUTH.md) defines local-only report regeneration and historical evidence boundaries.
