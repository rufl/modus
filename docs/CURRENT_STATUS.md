# MODUS Current Status

> **Documentation status: maintained reference.** This is the consolidated current snapshot. Generated reports remain authoritative for their individual gates.

**Updated:** July 19, 2026  
**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Project status:** Alpha-quality codebase with a pre-alpha evidence boundary  
**Production readiness:** **NOT READY**

## Summary

MODUS contains broad FPS framework code plus green July 19 category and strict aggregate lanes, but manual gameplay evidence is absent and the release-version gate is blocked. The latest complete aggregate plus Unit, Integration, and Property summaries define the current automated boundary. A bounded performance capture exists, but it is not sufficient for production targets.

The canonical publication rules are in [Documentation Truth](DOCUMENTATION_TRUTH.md).

## Readiness Snapshot

| Evidence | Current result | Boundary |
| --- | --- | --- |
| Documentation truth | **PASS** | Source/docs consistency only |
| Main player-path smoke | **PASS** | Startup and launch path only |
| Retained complete Godot/GUT suite | **PASS** | July 19: 1431/1431 passing, 20,362 assertions, no risky/pending tests or GUT-reported orphans |
| Latest strict aggregate attempt | **PASS/complete** | July 19: full summary completed in 1770.186 seconds under a 2400-second evidence ceiling |
| Latest batched Unit lane | **PASS** | July 19: 1056/1056 passing, 0 failing, pending, or GUT-reported orphans |
| Latest batched Integration lane | **PASS** | July 19: 200/200 passing; 2 GUI-required files skipped |
| Latest batched Property lane | **PASS** | July 19: 175/175 passing, 2,804 assertions, no GUT-reported orphans |
| Manual evidence | **BLOCKED** | 0 CSV files, 0.00 hours |
| Performance evidence | **PASS** | One bounded 66.4-second/130-sample showcase capture; not a production FPS claim |
| Release-version evidence | **BLOCKED** | Project remains `0.9.5-beta` |
| Production readiness | **NOT READY** | 2 validator-tracked blockers: manual evidence and release version; provenance clearance is outside that count |

## Current Focused Automated Proof

These results are narrower than the aggregate suite and must not be summed into a replacement “overall pass rate.”

| Contract | Result |
| --- | --- |
| Save service | 6/6 |
| Network manager | 9/9 |
| RPC whitelist | 9/9 |
| Mod-loading integration | 12/12 |
| Enemy AI | 13/13 |
| Enemy AI system | 126/126 |
| AI LOD update rate | 13/13 |
| Splitscreen configuration | 3/3 |
| Splitscreen manager | 28/28 |
| Splitscreen assignment UI | 15/15, 21 assertions |
| Splitscreen multiplayer compatibility | 16/16 |
| Splitscreen feature integration | 10/10 |
| Splitscreen gameplay | 34/34 |
| Splitscreen stress | 20/20 |
| Splitscreen property/layout/error recovery | 83/83, 334 assertions; includes all 30 properties and equal-area five-player layout |
| Feature integration | 10/10 |
| Configuration manager | 22/22 |
| Configuration caching | 5/5 |
| Configuration fallback | 8/8 |
| Configuration validation | 6/6 |
| Configuration loading correctness | 4/4 |
| Feature toggles | 9/9 |
| GameManager state transitions | 6/6 |
| Feature dependency validation | 7/7, 407 assertions |
| Mod loading properties | 4/4 |
| Mod conflict detection | 6/6 |
| Mod dependency resolution | 4/4 |
| Weapon synchronization | 6/6, 750 assertions |
| Event bus | 3/3, 9 assertions |
| Component lifecycle/signal hygiene | 30/30, 66 assertions; generic dynamic signals and GUT-owned fixture cleanup |
| Feature lifecycle/toggles | 36/36, 75 assertions; no-dependency validation, explicit loaded-state checks, GUT-owned fixtures |
| Individual weapons | 58/58, 76 assertions; hitscan defaults and name-based async switching/reload contracts |
| Combat feature | 20/20, 30 assertions; injected configuration preserves critical and knockback modifiers |
| Audio/performance logging | 23/23, 67 assertions; maintained music navigation API and mutable signal observations |
| Grid pathfinding/HUD boundaries | 30/30, 70 assertions; walkable-only A* and deterministic ten-update state |
| ENet fallback Unit contract | 11/11, 28 assertions; expected engine errors consumed and config fixture owned |
| Configuration validation | 14/14, 104 assertions; canonical nested paths and GUT-owned managers |
| GameManager lifecycle | 28/28, 102 assertions |
| Memory usage property | 4/4 |
| Lazy loading property | 4/4; deferred construction is verified without a wall-clock microbenchmark |
| Frame-time property | 5/5 at default counts in 331.79s; stability uses the middle 90% to exclude host descheduling, while absolute spikes stay in the performance lane |
| Visual configuration/reload | Editor, lazy-loading, graphics, and map focus passes 52/52 with 443 assertions; graphics preset coverage is 27/27; all ConfigurationManager reload subscribers accept the emitted path |
| Map-generator unit directory | 79/79, 5,439 assertions |
| Map-generator threading | 8/8, 30 assertions; generated geometry/navigation survive PackedScene instantiation; zero GUT orphans |
| Map-generator export | 10/10, 34 assertions; zero GUT orphans |
| Map-generator seed/RNG | 8/8, 29 assertions |
| Map playability | 15/15, 40 assertions |
| Showcase structure | 17/17, 46 assertions |
| Reference integrity | 21/21, 116 assertions |
| MatchService | 8/8 |
| Breakable props | 17/17; RPC validation uses the whitelisted method name and test peers close before port reuse |
| Migration compatibility | 13/13, 21 assertions |
| Sample mod SDK | 2/2 |
| Mod package validator | 4/4; repository scan 9 packages, 0 errors, 8 disabled-mod warnings |
| Editor save/export/reload | 1/1, 15 assertions |
| Local Workshop simulation | 1/1, 13 assertions |
| Source shape/resource/editor registry | 37/37, 172 assertions, zero GUT orphans; canonical paths and built-in actor instantiation only |

The July 17 focused threaded and export lanes are clean at their stated boundary and are now covered by a green complete strict aggregate.

## Source-Backed Implementation Boundary

- `project.godot` registers two autoloads: `GameManager` and `MapGenerator`.
- GameManager creates logging, events, data, audio, UI, performance, localization, entities, saves, mods, chat, networking, assets, and UI-input services.
- Runtime feature code covers player, combat, loot, match, effects, missions, difficulty, movement, world systems, and supporting components.
- `game/data/` owns content registries; `game/config/` owns runtime feature/system configuration.
- Network source includes ENet, dedicated-server paths, server-side validation, RPC whitelist/rate limits, prediction, and conditional Steam structures.
- Shared editor source includes serialization, packaging, local Workshop simulation, UI panels, prefabs, and embedded/standalone entry points; every registered built-in actor resolves and instantiates its native script base.
- Map-generator source includes a multi-phase pipeline, profiling, validation, export, and batch-oriented support.

This source inventory is not equivalent to complete runtime or user-experience proof.

## Player-Visible and External Boundaries

### Multiplayer

- `multiplayer_demo` profile launch: **PASS** for profile/service startup.
- Two-process ENet host/join: **BLOCKED** by sandbox localhost socket creation.
- Real Steam/GodotSteam: **UNPROVEN**; no current authenticated Steam API evidence exists.
- High-latency combat quality: **UNPROVEN**; lag-compensation source exists but the maintained combat integration still has an open TODO.

### Editor and Workshop

- Save/export/reload serialization contract: **PASS**.
- Local Workshop filesystem simulation: **PASS**.
- Live editor UI workflow: **UNPROVEN**.
- Standalone custom undo/redo commands: **OPEN TODO**.
- Real Steam Workshop transfer: **BLOCKED** without GodotSteam/client/app/account evidence.

### Showcase and Performance

- Showcase structure: **PASS** with 4 player spawns, 2 enemy spawns, 1 navigation region, lighting, environment, collision, and 539 nodes.
- Manual golden-demo route: **UNPROVEN**.
- Bounded performance CSV: **PASS** for evidence shape/duration.
- Display-synchronized gameplay, splitscreen, multiplayer, low-end hardware, and long-session performance: **UNPROVEN**.
- The capture's 108.55 ms maximum frame time and extreme enemy-position warnings remain active concerns.

## Current Validator-Tracked Blockers

1. No ManualTestTimer CSV evidence has been imported; recorded manual gameplay remains 0.00 hours.
2. The project is still explicitly `0.9.5-beta`, so the 1.0 release-version gate is blocked.

The two-count is the scope of `tools/validate_production_readiness.sh`, not an exhaustive release or legal clearance. `docs/ATTRIBUTION.md` records unresolved third-party asset/code provenance, including missing local evidence for Kenney asset licensing and the blood-pool shader's upstream license. Distribution clearance remains open even if the three automated gates later pass.

Additional open proof: real two-peer networking, real Steam/GodotSteam, live editor UI, real Workshop publication, display-synchronized performance, aggregate test diagnostic/runtime reduction, and a complete distribution provenance ledger. Vase, corpse-pile, hidden-stash, and weapon-rack loot scenes are also explicit missing content if those enum types remain in product scope.

## Project Inventory

| Metric | Current source-audited value |
| --- | ---: |
| Project autoloads | 2 |
| Unit test files | 70 |
| Integration test files | 18 |
| Property test files | 29 |
| GUI-required manifest entries | 2 |
| Manual evidence files | 0 |
| Recorded manual hours | 0.00 |
| Performance evidence files | 1 |
| Performance evidence duration/samples | 66.4 seconds / 130 samples |

## Verification Commands

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
tools/run_main_player_path_smoke.sh --strict
tools/validate_manual_evidence.sh --strict
tools/validate_performance_evidence.sh --strict
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```

## Related Current Sources

- [Production Readiness](PRODUCTION_READINESS_REPORT.md)
- [Automated Lanes](AUTOMATED_TEST_LANES_REPORT.md)
- [Manual Evidence](MANUAL_EVIDENCE_REPORT.md)
- [Performance Evidence](PERFORMANCE_EVIDENCE_REPORT.md)
- [Release Readiness](RELEASE_READINESS_REPORT.md)
- [Active Backlog](../BACKLOG.md)
