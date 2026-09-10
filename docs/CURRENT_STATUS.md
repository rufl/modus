# MODUS Current Status

> **Documentation status: maintained reference.** This is the consolidated published snapshot; fresh verification records are dated below. Generated reports and raw logs are local-only; each report describes its own invocation.

**Updated:** September 10, 2026 <!-- craft-ignore: status sheet uses deliberate labels -->
**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Project status:** Alpha-quality codebase with a pre-alpha evidence boundary  
**Production readiness:** **NOT READY**

## Summary

MODUS contains broad FPS framework code plus focused and golden-demo runtime proof, but reviewed manual gameplay evidence is absent and the release-version gate is blocked. September 9 closes six engineering repair groups with 67 focused tests/612 assertions, an eleven-step actual gameplay smoke, isolated native asset rendering, and a compiled Godot audio-shutdown patch. The September 10 refreshed headless aggregate passes 1,568/1,568 tests with 21,718 assertions across 135 scripts; two GUI-required files remain skipped. A bounded performance capture exists but does not establish production targets.

The canonical publication rules are in [Documentation Truth](DOCUMENTATION_TRUTH.md).

Publication cleanup preserves old local evidence without refreshing it. Fresh clones retain this summary, maintained guides, licenses, and curated media—not raw `logs/`, historical session/archive files, or generated reports. See [local report regeneration](DOCUMENTATION_TRUTH.md#regenerating-local-reports) for commands and prerequisites. Missing local inputs must remain missing evidence; earlier PASS results below are dated observations, not checkout guarantees.

## Readiness Snapshot

| Evidence | Current result | Boundary |
| --- | --- | --- |
| Documentation truth | **PASS** | Source/docs consistency only |
| Craft / Slopometer | **PASS** | Craft penalty 0; MODUS 0.0/10 with recorded aggregate proof and no reclaimable caches |
| Main player-path smoke | **PASS** | Fresh August 2 main-menu startup only |
| Showcase scene launch smoke | **PASS** | Fresh August 2 world-scene load/initialization only |
| Golden demo runtime smoke | **PASS** | August 4: all 8 controlled framework-loop steps; automated scope, not manual feel |
| September engineering repairs | **PASS** | 67 focused tests/612 assertions; eleven-step real-player smoke; native four-prop/ten-icon render; explicit patched Godot required for the MP3 fix |
| Retained complete Godot/GUT suite | **PASS** | September 10 refreshed headless aggregate: 1,568/1,568 passing, 21,718 assertions across 135 scripts; 10 warnings and 31 deprecations; two GUI-required files skipped |
| Latest strict aggregate attempt | **PASS/complete** | September 10: `run_all_tests_headless.sh` completed in 1,169.121 seconds with the patched Godot 4.7.2 binary; Godot emitted the known engine-exit ObjectDB diagnostics |
| Latest batched Unit lane | **PASS** | September 10: 1,166/1,166 passing |
| Latest batched Integration lane | **PASS** | September 10: 227/227 passing; 2 GUI-required files skipped |
| Latest batched Property lane | **PASS** | September 10: 175/175 passing, 2,804 assertions |
| Manual evidence | **BLOCKED / RECORDER READY** | Responsive 20-item F8 workflow and strict CSV validation pass; 0 reviewed CSV files and 0.00 validated hours |
| Performance evidence | **PASS** | One bounded 66.4-second/130-sample showcase capture; not a production FPS claim |
| Release-version evidence | **BLOCKED** | Project remains `0.9.5-beta` |
| Production readiness | **NOT READY** | 2 validator-tracked blockers: manual evidence and release version; provenance clearance is outside that count |
| Release evidence bundle | **INDEX COMPLETE / RELEASE BLOCKED** | Hashed menu/welcome/mod/golden-demo captures, short automated video, bounded benchmark table, known-limits matrix, and provenance ledger are retained; manual marketing review, packaging, and rights clearance remain open |

## Current Focused Automated Proof

These results are narrower than the aggregate suite and must not be summed into a replacement “overall pass rate.”

| Contract | Result |
| --- | --- |
| Server rewind / combat / adjacent weapons | September 9: 119/119, 255 assertions; eight runtime checks pass after six baseline failures; controlled latency and real physics, not WAN/manual proof |
| Save service | 8/8; current encrypted slot existence/list/delete contract and score-key restoration |
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
| UI/UX | 26/26, 109 assertions on August 3; supplied hero artwork, player-visible Showcase route, contextual action help, responsive containment, 48-pixel logical controls, visible version, explicit focus loop, responsive shared forms, localized welcome panel, responsive mod workflow, and complete skill-tree compatibility scene; fresh menu, welcome, mod, and golden-demo captures are retained |
| Manual evidence recorder | 2/2, 21 assertions on August 4; safe CSV output, required metadata, explicit Skip accounting, compact 800×600 layout, 48-pixel targets, and focus order |
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
| Reference integrity | 22/22, 119 assertions; shared blood-pool shader/controller parse and load |
| MatchService | 8/8 |
| Breakable props | 17/17; RPC validation uses the whitelisted method name and test peers close before port reuse |
| Migration compatibility | 13/13, 21 assertions |
| Sample mod SDK | 2/2 |
| Mod package validator | 4/4; repository scan 9 packages, 0 errors, 8 disabled-mod warnings |
| Editor save/export/reload | 1/1, 15 assertions |
| Local Workshop simulation | 1/1, 13 assertions |
| Source shape/resource/editor registry | 37/37, 172 assertions, zero GUT orphans; canonical paths and built-in actor instantiation only |


The September 10 refreshed aggregate is current-tree automated evidence: 1,568/1,568 selected tests passed with 21,718 assertions across 135 scripts. It does not certify the two GUI-required files, benchmark performance, manual gameplay feel, packaging, rights, or external service proof.
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
- Historical two-process ENet host/join smoke: **BLOCKED** by sandbox localhost socket creation at that run's boundary. September 9 focused real-ENet host lifecycle, inventory, and late-join checks now pass; the client transport reconnect path now preserves and submits the PlayerSvc session token after a successful network reconnect. Broader latency/reconnect/dedicated-client proof remains open.
- Real Steam/GodotSteam: **UNPROVEN**; no current authenticated Steam API evidence exists.
- Server rewind and combat integration: **FOCUSED PASS** on September 9. One CombatSvc-owned system captures player/enemy history, uses bounded server-measured RTT/2, rejects invalid/out-of-window requests, and restores query state. Temporary static query bodies handle Jolt's deferred kinematic transforms without changing live body modes or velocities. Feature and multi-pellet weapon flows share the service; projectile/melee and nonplayer validation remain current-state.
- High-latency combat quality: **UNPROVEN**. Client-view/interpolation calibration and representative end-to-end latency sessions remain outside the focused physics/weapon proof.

### Editor and Workshop

- Save/export/reload serialization contract: **PASS**.
- Local Workshop filesystem simulation: **PASS**.
- August main-menu/showcase/mod-manager/skill-tree presentation: **FOCUSED PASS** through 26/26 structural/accessibility tests plus dated wide/narrow captures in `docs/media/release/`. The menu captures predate artwork removal and are not current rendered proof.
- Standalone block, erase, paint, transform, selection, paste, and duplicate history: **FOCUSED PASS**; runtime-safe fallback, centroid-preserving paste, offset duplication, and live node-tree/material/transform round trips are covered. Full editor UI and manual authoring workflow remain open.
- Live complete editor UI workflow: **UNPROVEN**.
- Standalone custom undo/redo commands: **FOCUSED PASS** for block, erase, paint, transform, selection, paste, duplicate, `EditorState` block/entity/spawn placement, runtime-safe level-save boundaries, runtime-safe visual-script selection, tool-cycle signaling, Escape cancellation signaling, positive brush-size shortcuts, embedded editor save/load round trips, toolbar/hotbar runtime construction, workshop browser construction, optional environment preset apply/load/delete/parameter handling, and zone selection safety; full editor UI and manual authoring workflow remain open.
- Real Steam Workshop transfer: **BLOCKED** without GodotSteam/client/app/account evidence.

### Showcase and Performance

- Showcase structure: **PASS** with 4 player spawns, 2 enemy spawns, 1 navigation region, lighting, environment, collision, and 539 nodes.
- Automated golden-demo route: **PASS** for all 8 controlled framework-loop steps.
- Human-operated golden-demo feel and failure recovery: **UNPROVEN**; the F8 recorder workflow is ready but contains no human observations yet.
- Bounded performance CSV: **PASS** for evidence shape/duration.
- Display-synchronized gameplay, splitscreen, multiplayer, low-end hardware, and long-session performance: **UNPROVEN**.
- The capture's 108.55 ms maximum frame time and extreme enemy-position warnings remain active concerns.

## Current Validator-Tracked Blockers

1. No reviewed ManualTestTimer CSV evidence has been imported; the recorder and validator are ready, but recorded manual gameplay remains 0.00 validated hours.
2. The project is still explicitly `0.9.5-beta`, so the 1.0 release-version gate is blocked.

The two-count is the scope of `tools/validate_production_readiness.sh`, not exhaustive release or legal clearance. The current 230-row provenance ledger clears 18 assets, including ten new original SVG icons. Twelve music tracks still require commercial-rights evidence, and 200 additional distributed assets remain unverified. Distribution clearance remains open even if automated gates pass.

Additional open proof: network latency and automatic reconnect, real Steam/GodotSteam, live complete editor UI, real Workshop publication, display-synchronized performance, a refreshed full aggregate, and resolution of all 212 non-cleared provenance rows. Local real-ENet behavior and all four formerly missing props now have focused proof; stock Godot still requires the explicit audio patch described in [Known Limits](KNOWN_LIMITS_MATRIX.md).

## Project Inventory

| Metric | Retained August 4 inventory |
| --- | ---: |
| Project autoloads | 2 |
| Unit test files | 71 |
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
tools/generate_provenance_ledger.py --check
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
tools/run_showcase_golden_demo_smoke.sh --strict
tools/run_manual_showcase_session.sh --tester NAME --input DEVICES
tests/runners/test_manual_evidence_validator.sh
tools/run_main_player_path_smoke.sh --strict
tools/validate_manual_evidence.sh --strict
tools/validate_performance_evidence.sh --strict
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```

## Related Current Sources

- [Report Regeneration and Evidence Prerequisites](DOCUMENTATION_TRUTH.md#regenerating-local-reports)
- [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md)
- [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)
- [Active Backlog](../BACKLOG.md)
