# Getting Started with MODUS

> **Documentation status: maintained reference.** MODUS is `0.9.5-beta` and NOT READY for production use. This guide gets the current checkout running; it is not a release promise.

## Requirements

- Godot 4.7 or newer in the 4.7 line expected by `project.godot`.
- Bash for repository verification scripts.
- A writable `/tmp` for the isolated headless runner environment.
- A graphical session for editor, visual, input, and manual gameplay evidence.

No GodotSteam extension is bundled. Steam-specific behavior requires separate installation and proof.

## Open and launch

From the repository root:

```bash
godot --editor --path .
```

The configured main scene is `shared/ui_core/screens/main_menu_screen.tscn`. For a bounded startup check:

```bash
tools/run_main_player_path_smoke.sh --strict
```

That smoke proves menu/startup only. It does not prove movement, combat, saves, multiplayer, or editor interaction.

## Verify the checkout

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
```

Run automated tests when you need runtime contract evidence:

```bash
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
```

The retained full baseline is non-green. A clean source/docs check should not be described as a green game test suite.

## Repository map

- `game/scripts/core/` — GameManager and foundational runtime code.
- `game/scripts/features/` — feature/service modules.
- `game/entities/` — player, enemies, components, effects, and projectiles.
- `game/world/` — maps and world actors.
- `game/editor/` and `shared/editor_core/` — editor surfaces.
- `game/data/` — content data.
- `game/config/` — runtime configuration and profiles.
- `mods/` — sample repository mods.
- `tests/` — automated/manual evidence surfaces.
- `docs/` — current truth, generated reports, maintained guides, and labeled historical snapshots.

## Core APIs

The current global entry point is `GameManager`:

```gdscript
var logger: Node = GameManager.get_core_system("logger")
var config: Node = GameManager.get_core_system("config")

if logger:
    logger.info("Example initialized", "Example")

GameManager.subscribe("example_event", _on_example_event)
GameManager.emit_event("example_event", {"source": "getting_started"})
```

Optional services can be absent under a feature profile, so null-check lookups. Do not add a new autoload just to obtain an existing service.

## Data and configuration

Use the ownership map in `docs/technical/JSON_SCHEMAS.md`:

- authored registries such as weapons, enemies, and loot live under `game/data/`;
- runtime settings live under `game/config/`;
- feature profiles begin at `game/config/features.json5`;
- user mod overrides belong under `user://mods/`.

Do not restore retired configuration directories or duplicate root-level gameplay configuration files.

## First safe change

1. Identify the source file and its focused test.
2. Change the smallest coherent surface.
3. Run GDScript formatting/lint for touched scripts when available.
4. Run the focused test, then the relevant wider lane.
5. Update `BACKLOG.md`, `CHANGELOG.md`, and current docs with the exact proof boundary.
6. Leave manual, hardware, Steam, and connected-peer claims open unless they were actually observed.

## Where to go next

- Current state: `docs/CURRENT_STATUS.md`
- Architecture: `docs/architecture.md`
- Testing: `tests/README.md`
- Modding: `docs/guides/MODDING.md`
- Troubleshooting: `docs/troubleshooting.md`
- Evidence collection: `tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md`
