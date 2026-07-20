# Sky Source Boundary

> **Documentation status: maintained reference.** This page describes files in this directory. It is not current visual, integration, or performance proof.

## Present Source

- `retro_sky.gdshader` — a `shader_type sky` three-color vertical gradient with configurable horizon sharpness. Despite the older documentation, it does not currently implement procedural stars.
- `retro_sky_mat.tres` and `retro_sky.tres` — material and sky resources for that gradient shader.
- `clouds.gdshader` — a spatial cloud shader; `skybox_controller.gd` preloads it.
- `skybox_controller.gd` and `enhanced_skybox_controller.gd` — two controller implementations with different source surfaces.

The retro shader itself contains a placeholder comment. No maintained test or generated report currently proves which sky controller/resource is active in the golden route, that every shader compiles on all renderers, or that the result meets a frame-time target.

Before making a player-facing sky claim, identify the scene/resource that owns the environment, run it in Godot 4.7, record the renderer and visible result, and capture a contextualized performance sample.
