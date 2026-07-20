# Player Experience Integration Tests

> **Documentation status: maintained reference.** This page documents the live test files and their execution boundary. It does not claim that player-visible behavior currently passes.

## Current test surface

Two integration files inspect player/HUD structure and behavior:

- `tests/integration/test_player_experience_integration.gd`
- `tests/integration/test_hud_visual_feedback.gd`

Both are listed in `tests/runners/headless_gui_required_tests.txt`. The default headless suite deliberately omits them because they depend on GUI/full player-scene services. There is no `tests/runners/run_player_experience_tests.gd` runner in this checkout.

The tests contain a mixture of assertions, optional-component checks, and `pending()` branches. A file being present does not prove a complete HUD, visual quality, input behavior, audio playback, accessibility, or a playable game loop.

## What the files inspect

`test_player_experience_integration.gd` covers source/runtime structure such as:

- player scene instantiation, camera, collision, and HUD layer;
- weapon-manager components, weapon assets, signals, and visibility;
- VFX method availability;
- selected service lookups;
- initialization and null-reference checks;
- limited weapon-switching and ammo-update behavior.

`test_hud_visual_feedback.gd` inspects selected HUD, crosshair, health, ammo, damage indicator, minimap, pause, theme, contrast, and text-size surfaces. Several elements are optional or become pending when required services are unavailable.

## How to run

Run the maintained default headless selection:

```bash
./tests/runners/run_all_tests_headless.sh
```

Attempt the legacy selection that includes both GUI-required files:

```bash
./tests/runners/run_all_tests_headless.sh --include-gui-required
```

Use `GODOT_BIN=/path/to/godot` if the executable is not named `godot` or `godot4`. A real display/editor session may still be required for useful GUI evidence. The two files can also be selected from the GUT panel in the Godot editor.

## Result interpretation

- A green run proves only the assertions reached in that environment.
- Pending tests are not passes.
- Optional-node branches do not prove absent UI is acceptable to the product.
- Headless structure checks do not prove visual quality or input usability.
- Player-visible closure requires the manual route in `tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md` and a validated evidence bundle.

## Current status

The latest project evidence does not contain a complete green GUI-required run or manual player-experience bundle. These tests therefore remain **available but not current end-to-end proof**.
