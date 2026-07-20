# MODUS Framework

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

MODUS is an experimental Godot 4.7 multiplayer FPS framework and template. The repository contains substantial gameplay, networking, editor, modding, data/configuration, splitscreen, and procedural-map code, but it is not a production-ready game or SDK.

**Version:** `0.9.5-beta`

**Engine:** Godot 4.7+

**Readiness:** **NOT READY**

**Manual evidence:** 0 imported sessions / 0.00 recorded hours

Read [Documentation Truth](docs/DOCUMENTATION_TRUTH.md), [Current Status](docs/CURRENT_STATUS.md), and [Production Readiness](docs/PRODUCTION_READINESS_REPORT.md) before using project-wide claims.

## Start Here

1. Open the repository in Godot 4.7 or set `GODOT_BIN` to a Godot 4.7 executable.
2. Let Godot import the project.
3. Run the configured main scene: `res://shared/ui_core/screens/main_menu_screen.tscn`.
4. Use `res://game/world/maps/showcase.tscn` for the maintained showcase route.
5. Follow [Getting Started](docs/getting_started.md) and [Showcase Route](docs/SHOWCASE_ROUTE.md).

The repository does not guarantee a clean first run on every machine. Optional Steam/GodotSteam and Voxel Tools integrations can be unavailable; the code includes fallback paths, but those fallbacks do not prove feature parity.

## What Exists in Source

| Area | Source-backed boundary |
| --- | --- |
| Core lifecycle | `GameManager` and `MapGenerator` are the two project autoloads |
| Gameplay | Player, combat, weapons, enemies, loot, effects, missions, difficulty, movement, and world systems are present |
| Content | Weapon, enemy, item, loot, localization, and map-generator data live under `game/data/` |
| Runtime configuration | Feature, gameplay, network, entity, item, and performance configuration live under `game/config/` |
| Networking | ENet, server validation, RPC whitelist/rate limits, dedicated-server paths, prediction, and conditional Steam structures exist |
| Splitscreen | Local-player, viewport, input, assignment, and session-management code exists with focused automated coverage |
| Modding | Folder/PCK/ZIP discovery, manifests, dependencies, overrides, event hooks, and a sample SDK mod exist |
| Editor | Shared editor core, embedded and standalone entry points, level serialization/export, prefabs, and local Workshop simulation exist |
| Map generation | Multi-phase procedural generation, validation, export, profiling, and focused unit/integration coverage exist |

“Exists in source” does not mean the complete user flow has been manually proven.

## Current Evidence

| Evidence | Result |
| --- | --- |
| Retained complete Godot/GUT suite | **PASS** — July 19: 1431/1431 passing, 20,362 assertions, zero GUT-reported orphans |
| Latest strict aggregate attempt | **PASS/complete** — July 19: finished in 1770.186 seconds under an evidence-derived 2400-second ceiling; full summary retained |
| Latest batched lanes | **PASS** — July 19 Unit 1056/1056, Integration 200/200, and Property 175/175; Benchmark skipped |
| Main launch-path smoke | **PASS** for startup scope only |
| Manual gameplay | **BLOCKED** — no imported CSV evidence |
| Performance evidence | **PASS** for one bounded 66.4-second/130-sample showcase capture only |
| Release-version gate | **BLOCKED** — current version remains `0.9.5-beta` |
| Production readiness | **NOT READY** with 2 validator-tracked evidence blockers: manual evidence and release version; distribution provenance is a separate open clearance gap |

Focused green tests are listed in [Current Status](docs/CURRENT_STATUS.md). They prove only their named contracts and do not override the non-green aggregate suite.

The latest focused source-shape/editor-registry contract passes 37/37 with 172 assertions and zero GUT orphans. It verifies canonical world/map/resource paths and instantiable built-in editor actors; it does not supply the still-missing vase, corpse-pile, hidden-stash, or weapon-rack loot scenes.

The advanced-movement contract now passes 36/36 with 51 assertions in focused scope and 36/36 inside the strict aggregate. It verifies deterministic grounded bunny-hop/slide behavior, capped hop acceleration, current signal contracts, no-peer-safe dodge synchronization, and canonical rocket-jump JSON5 loading; normal-window feel and tuning remain manual proof.

## Important Boundaries

### Multiplayer and Steam

- The `multiplayer_demo` profile launches without profile/service lookup errors.
- The latest two-process ENet host/join attempt is blocked by sandbox localhost socket creation.
- Real Steam/GodotSteam behavior has not been proven with a running client, app ID, authorized account, and real API result.
- Server-side rewind code exists, but the maintained combat feature still contains an integration TODO; high-latency hit-registration quality is unproven.

See [Multiplayer Authority](docs/MULTIPLAYER_AUTHORITY_MODEL.md), [Profile Smoke](docs/MULTIPLAYER_PROFILE_SMOKE.md), [ENet Smoke](docs/ENET_LOCAL_HOST_JOIN_SMOKE.md), and [Steam Integration](docs/technical/STEAM_INTEGRATION.md).

### Editor and Workshop

- Focused save/export/reload proof passes for a constructed level.
- Local filesystem Workshop upload/download/browse/subscription simulation passes.
- The standalone editor still contains TODOs for its custom undo/redo commands.
- Live editor UI operation and real Steam Workshop transfer remain unproven.

See [Editor Round-Trip Proof](docs/EDITOR_ROUNDTRIP_PROOF.md) and [Workshop Local Simulation](docs/WORKSHOP_LOCAL_SIMULATION_PROOF.md).

### Performance

One compatibility-renderer showcase capture exists on Intel Arc A770/Mesa: 66.4 seconds, 130 samples, and a 108.55 ms maximum frame-time spike. It was unthrottled and produced extreme enemy-position warnings. Do not use its average FPS as a player-facing target.

No display-synchronized solo, splitscreen, multiplayer, low-end hardware, or long-session target has been validated. See [Performance Baseline Proof](docs/PERFORMANCE_BASELINE_PROOF.md).

### Map Generator

The focused `tests/unit/map_generator/` group passes 79/79 tests. The repaired threaded lane passes 8/8 with 30 assertions and the export lane passes 10/10 with 34 assertions; neither reports GUT orphans in its July 17 focused run. Seed/RNG also passes 8/8. The strict aggregate suite is green, but automated proof alone does not establish production readiness. Historical map-generator “production ready” reports are archived snapshots, not current truth.

## Data and Configuration

Keep content and runtime configuration separate:

```text
game/data/                 content registries and map-generator data
game/config/               runtime feature and system configuration
user://mods/               user-installed mod packages and overrides
mods/                      repository sample mods
```

See [JSON Schemas](docs/technical/JSON_SCHEMAS.md) for maintained ownership rules.

## Modding

The reference package is `mods/modus_sdk_sample/`. Focused proof covers manifest/override shape, `ModScript` inheritance, event exchange, and an enemy-spawn hook. It does not prove packaging for distribution, live multiplayer synchronization, real Workshop publication, or balance.

See [Modding Guide](docs/guides/MODDING.md), [Sample Mod Proof](docs/MODDING_SAMPLE_MOD.md), and [Mod Package Validation](docs/MOD_PACKAGE_VALIDATION.md).

## Verification

Documentation and source-truth gates:

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
```

Automated tests:

```bash
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
```

Evidence/readiness reports:

```bash
tools/run_main_player_path_smoke.sh --strict
tools/validate_manual_evidence.sh --strict
tools/validate_performance_evidence.sh --strict
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```

Strict validators intentionally return nonzero while their proof is blocked.

## Repository Layout

```text
game/              runtime code, scenes, data, configuration, UI, and editor entry points
shared/            shared editor and UI infrastructure
standalone/        standalone editor and dedicated-server entry points
mods/              repository sample mods
tests/             GUT unit, integration, property, benchmark, and manual helpers
tools/             validators, smoke harnesses, migration, and maintenance tooling
docs/              maintained references, generated evidence, and labeled history
```

## Documentation

- [Documentation Index](docs/INDEX.md)
- [Documentation Truth Contract](docs/DOCUMENTATION_TRUTH.md)
- [Current Status](docs/CURRENT_STATUS.md)
- [Active Backlog](BACKLOG.md)
- [Roadmap](ROADMAP.md)
- [Architecture](docs/architecture.md)
- [Technical Reference](docs/TECHNICAL_REFERENCE.md)
- [Attribution](docs/ATTRIBUTION.md)

## Intended Use

- Suitable for source study, experimentation, and prototypes where the current limitations are acceptable.
- Potentially useful as a framework foundation after project-specific validation and hardening.
- Not currently supported by evidence for production deployment, a 1.0 release, public multiplayer service, or store publication.

## License and Provenance

The project license text is currently stored at `docs/LICENSE`, and vendored GUT carries its own MIT license under `addons/gut/LICENSE.md`. Third-party asset and code provenance is not yet complete enough for release clearance; previous template/asset attributions that lack local evidence remain unverified. See [Licensing and Provenance Inventory](docs/ATTRIBUTION.md) before redistributing the project.
