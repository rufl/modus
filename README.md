# MODUS Framework

> **Documentation status: maintained reference.** Published readiness is consolidated in `docs/DOCUMENTATION_TRUTH.md` and `docs/CURRENT_STATUS.md`. Generated reports are local invocation records; narrower claims in this file apply only to the named subsystem or workflow.

MODUS is an experimental Godot 4.7 multiplayer FPS framework and template. The repository contains substantial gameplay, networking, editor, modding, data/configuration, splitscreen, and procedural-map code, but it is not a production-ready game or SDK.

**Version:** `0.9.5-beta`

**Engine:** Godot 4.7+

**Readiness:** **NOT READY**

**Manual evidence:** 0 imported sessions / 0.00 recorded hours

Read [Documentation Truth](docs/DOCUMENTATION_TRUTH.md) and [Current Status](docs/CURRENT_STATUS.md) before using project-wide claims. Generate the local `docs/PRODUCTION_READINESS_REPORT.md` with `tools/validate_production_readiness.sh`; it is an output, not a required checkout file. See the [Ship-Readiness Estimate](docs/SHIP_READINESS_ESTIMATE.md) for the explicit gateboard and calendar estimate.

## Start Here

1. Open the repository in Godot 4.7 or set `GODOT_BIN` to a Godot 4.7 executable.
2. Let Godot import the project.
3. Run the configured main scene: `res://shared/ui_core/screens/main_menu_screen.tscn`.
4. Use `res://game/world/maps/showcase.tscn` for the maintained showcase route.
5. Follow [Getting Started](docs/getting_started.md) and [Showcase Route](docs/SHOWCASE_ROUTE.md).

The repository does not guarantee a clean first run on every machine. Optional Steam/GodotSteam and Voxel Tools integrations can be unavailable; the code includes fallback paths, but those fallbacks do not prove feature parity.

## Proven Showcase Route <!-- craft-ignore: maintained project reference -->

The main menu exposes **Showcase**, which opens the maintained `game/world/maps/showcase.tscn` route. The automated golden-demo smoke now proves one controlled local framework loop: scene load, player spawn, movement input, weapon fire, enemy defeat, pickup collection, encrypted save/load restoration, and bundled SDK sample-mod loading. <!-- craft-ignore: scoped evidence emphasis -->

![MODUS automated golden-demo result](docs/media/release/golden_demo_smoke_1280x720.png)

- Golden demo report: `docs/GOLDEN_DEMO_SMOKE.md`, generated locally by `tools/run_showcase_golden_demo_smoke.sh`
- [Short automated runtime video](docs/media/release/golden_demo_smoke_1280x720.mp4)
- [Release Evidence Bundle](docs/RELEASE_EVIDENCE_BUNDLE.md)

This route does not prove gameplay feel, real multiplayer peers, Steam, long sessions, packaging, manual hours, or release approval.

For a real reviewed session, run `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES`. Its test-only F8/Gamepad Back recorder covers 20 bounded observations and writes metadata-rich CSVs directly to `logs/manual_test_logs/`; it does not fabricate evidence.

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
| Current complete Godot/GUT suite | **PASS:** August 4, 1440/1440 passing, 20,475 assertions, zero GUT-reported orphans |
| Latest strict aggregate attempt | **PASS/complete:** August 4, finished in 702.76 seconds under the 3600-second bounded run; full summary retained, with six engine-exit ObjectDB leak diagnostics |
| Latest batched lanes | **PASS:** August 1 Unit 1056/1056 and Property 175/175; July 19 Integration 200/200 retained; Benchmark skipped |
| Craft / Slopometer | **PASS:** Craft penalty 0; MODUS 0.0/10 across all five dimensions |
| Golden demo runtime smoke | **PASS:** all 8 controlled framework-loop steps on August 4; automated scope only |
| Main menu / showcase scene launch smokes | **PASS** on August 2 for startup scope only |
| Manual gameplay | **BLOCKED:** the recorder workflow is ready, but no reviewed CSV evidence has been imported |
| Performance evidence | **PASS** for one bounded 66.4-second/130-sample showcase capture only |
| Release-version gate | **BLOCKED** — current version remains `0.9.5-beta` |
| Production readiness | **NOT READY** with 2 validator-tracked evidence blockers: manual evidence and release version; distribution provenance is a separate open clearance gap |

Focused green tests are listed in [Current Status](docs/CURRENT_STATUS.md). They prove only their named contracts and do not replace manual, release, or distribution evidence.

The UI/UX pass now uses the supplied warrior artwork, exposes the maintained Showcase route directly, explains focused or hovered actions, preserves responsive containment and 48-pixel logical controls across shared menus/modals, localizes Showcase and Editor labels, makes options, multiplayer, host, pause, and save/load layouts shrink safely, and adds a gamepad-ready showcase welcome panel that states the evidence boundary. The mod manager now stacks on constrained screens, localizes its workflow, keeps actions disabled until selection, and explains that changes apply after reload; the skill-tree compatibility route now resolves the complete focusable UI. The test-only manual recorder adds a compact 800×600 review surface, clear Pass/Fail/Skip states, required failure notes, direct evidence export, and an F8/Gamepad Back gameplay/review handoff. Recorder/timer proof passes 2/2 with 21 assertions; captures are retained in [Release Evidence Bundle](docs/RELEASE_EVIDENCE_BUNDLE.md).

The latest focused source-shape/editor-registry contract passes 37/37 with 172 assertions and zero GUT orphans. It verifies canonical world/map/resource paths and instantiable built-in editor actors; it does not supply the still-missing vase, corpse-pile, hidden-stash, or weapon-rack loot scenes.

The advanced-movement contract now passes 36/36 with 51 assertions in focused scope and 36/36 inside the strict aggregate. It verifies deterministic grounded bunny-hop/slide behavior, capped hop acceleration, current signal contracts, no-peer-safe dodge synchronization, and canonical rocket-jump JSON5 loading; normal-window feel and tuning remain manual proof.

## Important Boundaries

### Multiplayer and Steam

- The `multiplayer_demo` profile launches without profile/service lookup errors.
- Focused real-ENet lifecycle, inventory, and late-join checks have dated passing evidence; broader latency and dedicated-client sessions remain unproven.
- Real Steam/GodotSteam behavior has not been proven with a running client, app ID, authorized account, and real API result.
- Server-authoritative hitscan now uses the shared, RTT-bounded player/enemy rewind system. Focused physics and weapon tests pass; client-view/interpolation calibration and representative high-latency sessions remain unproven.

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
tools/generate_provenance_ledger.py --check
```

Automated tests:

```bash
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
```

Evidence/readiness reports:

```bash
tools/run_showcase_golden_demo_smoke.sh --strict
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
tools/             reusable validators, smoke harnesses, and maintenance tooling
docs/              maintained references, licenses, provenance, and curated evidence media
```

## Repository Hygiene

Git tracks source, tests, CI, shared project configuration, licenses, the provenance ledger, maintained guides, and curated documentation media. Godot `.uid` and asset `.import` sidecars remain tracked because they encode resource identity and import behavior.

Raw `logs/`, IDE/agent state, `MEMORY.md`, `BACKLOG_ARCHIVE.md`, generated readiness reports, historical implementation notes, and completed one-off migration scripts are local-only. Existing copies remain in their original locations, ignored by Git; fresh clones regenerate outputs with the commands above. Missing evidence is not a passing readiness result. Locally retained logs are also excluded from exports.

Record lasting changes in `CHANGELOG.md` and maintained guides rather than adding session transcripts or generated reports. Untracking changes the published tree without deleting local files or rewriting Git history; older commits still contain their original files.

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

The project MIT text is retained at `LICENSE` and `docs/LICENSE`; vendored GUT carries its MIT notice under `addons/gut/LICENSE.md`. Kenney, dip000 blood-pool material, and ten original sample-item icons have pinned local license evidence. The generated 230-row ledger clears 18 assets and retains 212 requiring rights review. See [Licensing and Provenance Inventory](docs/ATTRIBUTION.md) before redistributing the project.
