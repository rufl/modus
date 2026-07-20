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

## Known Source Blocker

`blood_pool.gdshader` declares `HEIGHTMAP_STRENGTH` but its vertex function references `HEIGHTMAP_STRENGHT`. That misspelling is an unresolved shader compile risk. Until the shader is repaired and a Godot 4.7 run records a clean parse/render result, do not describe this system as working or ready to integrate.

The controller also requires an active `ShaderMaterial`; `_ready()` calls `set_shader_parameter()` without a null guard. A scene using the script must supply the expected material and uniforms.

## Provenance Boundary

Source comments attribute the approach to dip000's “Bloody Pool” shader on GodotShaders.com. This checkout does not contain a local copy of the upstream license or another reviewed provenance record. `docs/ATTRIBUTION.md` therefore keeps distribution clearance open. Historical shader guides retain old links and claims for traceability only.

## Before Using or Shipping

1. Resolve the shader identifier mismatch.
2. Confirm every demo scene imports and renders in Godot 4.7.
3. Add a focused test or recorded visual check for drop creation, recycling, and teardown.
4. Measure performance in the actual target scene and hardware profile.
5. Confirm the upstream license and retain the required attribution/license material in the repository.

Current project readiness remains defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports.
