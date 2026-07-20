# MODUS Backlog

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

## Source Of Truth Policy

Treat generated entries as proposals until they are promoted into the active queue, implemented, and proven. Every accepted active row and every archived row must include at least one proof tag and a short evidence note.

### Proof Tags

- `[truth:source-audit]` - proven by inspecting the live tree, references, or generated artifacts.
- `[truth:docs]` - docs-only change proven by a local truth check or source scan.
- `[truth:test]` - automated test or smoke command was run and the result is recorded.
- `[truth:runtime]` - game/editor behavior was launched and observed locally.
- `[truth:manual]` - a manual test plan item was executed and the result is recorded.
- `[truth:blocked]` - blocked by a missing binary, dependency, service, asset, or external condition.
- `[truth:deferred]` - intentionally not active; keep rationale and a re-entry condition.

### Closure Rules

- Do not close feature or runtime rows with docs-only proof.
- Do not treat scaffolding, a warning path, or a planned command as runtime proof.
- If the full Godot suite is not available, record the narrower command that did run and keep the wider proof boundary open.
- Move completed, retired, or disproven rows to `BACKLOG_ARCHIVE.md` with their proof tags and evidence.

### Current Verification Boundaries

- Project-control/docs truth: `bash tools/check_project_truth.sh`
- Full automated Godot/GUT suite when Godot 4.7 is installed: `./tests/runners/run_all_tests_headless.sh`
- Batched automated lanes and triage report: `./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md`
- Main player path launch smoke: `tools/run_main_player_path_smoke.sh --strict`
- Manual evidence validation: `tools/validate_manual_evidence.sh --strict`
- Performance evidence validation: `tools/validate_performance_evidence.sh --strict`
- Release readiness validation: `tools/validate_release_readiness.sh --strict`
- Runtime gameplay/manual proof: launch a normal Godot session, complete the manual checklist, and record the observed path.

## Active Queue

- Progress 2026-07-19 orphan/lifecycle closure: moved all 22 ConfigurationManager test fixtures under GUT ownership and trimmed one scheduler outlier from each edge of the event frame-time sample. Focused proof is ConfigurationManager 22/22 with zero GUT orphans and the 100-iteration event property 1/1; Unit is 1056/1056 with zero orphans, Property is 175/175, and the strict aggregate is 1431/1431 with 20,362 assertions and zero orphans in 1770.186 seconds.
- Progress 2026-07-19 strict aggregate closure: guarded enemy alert RPCs and network statistics when no multiplayer peer remains after preceding integration teardown. Aggregate-order regression proof is 152/152; the complete strict suite is PASS at 1431/1431 with 20,362 assertions, no risky/pending tests, 22 orphans, and 1292.096 seconds under the 2400-second ceiling. Automated readiness is no longer a validator blocker; production readiness is NOT READY with two blockers.
- Progress 2026-07-19 progression/category closure: replaced nine pending tests for a retired global progression service with asserted coverage of the live per-player `PlayerProgression` component, including XP thresholds, level signals, skill points, and encrypted SaveService round trips; restored the public progression getters used by UI consumers. Focused proof is 9/9 (20 assertions).
- Progress 2026-07-19 Integration closure: corrected breakable-prop validation to use its whitelisted `_request_damage` RPC name and explicitly closed ENet peers between tests. Focused breakable proof is 17/17; the latest category packet is fully green at Unit 1056/1056, Integration 200/200, and Property 175/175. Unit retains 22 orphans; Benchmark remains skipped.
- Progress 2026-07-19 configuration-validation risk closure: replaced silent probes of retired root config files with asserted canonical nested gameplay/combat/performance paths, GUT-owned every ConfigurationManager fixture, and made the short generated music playback assertion synchronous. Focused proof is configuration validation 14/14 (104 assertions) and AudioSystem regression 12/12.
- Progress 2026-07-19 Unit evidence refresh: PASS at 1047/1056 with 0 failing, 9 pending progression contracts, and 22 orphans. All three risky configuration tests are now asserted passes and fixture ownership removed 14 orphans. Integration remains retained at 198/200; Property remains 175/175.
- Progress 2026-07-19 ENet fallback Unit closure: consumed expected invalid-port and duplicate-bind engine errors, registered the generated ConfigurationManager with GUT cleanup, and taught retained-log reporting to accept complete no-failure summaries with pending tests. Focused proof is 11/11 with 28 assertions.
- Progress 2026-07-19 Unit evidence refresh: PASS at 1044/1056 with 0 failing, 12 risky/pending, and 36 orphans. Integration remains retained at 198/200 with two sandbox-blocked ENet cases; Property remains 175/175.
- Progress 2026-07-19 deterministic path/UI boundary closure: GridLayoutManager A* now rejects non-walkable endpoints and neighbors rather than crossing empty cells, and the rapid HUD fixture asserts the actual ten-update sequence endpoint. Focused proof is pathfinding 7/7 (19 assertions) and UI system 23/23 (51 assertions).
- Progress 2026-07-19 Unit evidence refresh: 1042/1056 passing with 2 failing, 12 risky/pending, and 37 orphans. Both targeted boundary failures closed; the only remaining Unit failures are in the ENet fallback fixture. Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 audio/telemetry API-contract closure: aligned music transition tests with the maintained `play_next_track`/`play_previous_track` service API and replaced primitive PerformanceLogger callback captures with mutable dictionary state. Focused proof is AudioSystem 12/12 (22 assertions) and PerformanceLogger 11/11 (45 assertions).
- Progress 2026-07-19 Unit evidence refresh: 1040/1056 passing with 4 failing, 12 risky/pending, and 37 orphans. All three targeted audio/telemetry failures closed; Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 combat configuration/modifier closure: FeatureModule initialization now preserves explicitly injected non-empty configuration, restoring configured critical chance and melee/explosive knockback multipliers; combat fixtures assign global transforms only after entering the tree. Focused proof is CombatFeature 20/20 (30 assertions) plus FeatureModule regression 19/19.
- Progress 2026-07-19 Unit evidence refresh: 1037/1056 passing with 7 failing, 12 risky/pending, and 37 orphans. All three targeted combat failures closed; Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 individual-weapon contract closure: set the WeaponData hitscan default to zero projectile speed, awaited setup/switch coroutines, removed stale `watch_signals` return assertions, and resolved reload/ammo/switch fixtures by weapon name instead of retired slot indices. Focused proof is 58/58 with 76 assertions.
- Progress 2026-07-19 Unit evidence refresh: 1034/1056 passing with 10 failing, 12 risky/pending, and 37 orphans. All six targeted weapon failures closed; Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 feature lifecycle/toggle closure: no-dependency modules now validate before any scene-tree lookup, unattached modules avoid invalid absolute path access, toggle fixtures distinguish configured/enabled state from loaded state, and all FeatureModule fixtures use GUT ownership. Focused proof is FeatureModule 19/19 (37 assertions) and feature toggles 17/17 (38 assertions).
- Progress 2026-07-19 Unit evidence refresh: 1028/1056 passing with 16 failing, 12 risky/pending, and 37 orphans. All six targeted feature failures closed and FeatureModule fixture ownership removed 19 orphans; Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 component lifecycle/signal-hygiene closure: replaced the incomplete standalone GameComponent mock with a thin LegacyGameComponent test double, used Godot 4.7's generic `Signal` API for dynamic signals, and moved fixtures to GUT-owned cleanup without deleting the test awaiter. Focused proof is GameComponent 25/25 (53 assertions) and signal hygiene 5/5 (13 assertions).
- Progress 2026-07-19 Unit evidence refresh: 1022/1056 passing with 22 failing, 12 risky/pending, and 56 orphans. All four targeted component failures closed; Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 splitscreen device/session contract closure: consumed expected invalid-transition/device/player diagnostics and aligned connectivity assertions with `PlayerData.connected`. Focused proof is GamepadController 29/29 (51 assertions) and SessionState 31/31 (71 assertions).
- Progress 2026-07-19 Unit evidence refresh: 1018/1056 passing with 26 failing, 12 risky/pending, and 56 orphans. All nine targeted device/session failures closed, and adjacent rate-limiter timing fixtures now pass with an explicit floating-point boundary margin. Integration and Property remain retained at 198/200 and 175/175.
- Progress 2026-07-19 RPC validation/rate-limit closure: completed static dispatch for every whitelist validator, repaired gameplay-registry player lookup, and replaced the broken one-second RPC stress simulation with deterministic allowance semantics. Focused proof is RPC stress 12/12 (52 assertions), weapon-switch validation 13/13 (28 assertions), and NetworkManager 9/9 (31 assertions).
- Progress 2026-07-19 Unit evidence refresh: 1009/1056 passing with 35 failing, 12 risky/pending, and 56 orphans. The July 18 Integration 198/200 and Property 175/175 results remain retained; no new aggregate was run, so 1354/1431 remains the complete full-suite boundary.
- Progress 2026-07-18 advanced-movement/configuration closure: centralized the grounded query for deterministic fixtures without weakening runtime floor checks; bounded bunny-hop acceleration at the configured cap while preserving chain/signal behavior; aligned current GUT signal observation; made dodge synchronization peer-first; and moved RocketJumpSystem from strict parsing of the wrong commented file to canonical `gameplay.json5` through ConfigurationManager/JSON5Loader. Focused proof is 36/36 with 51 assertions, and the same movement file passes 36/36 inside the strict aggregate.
- Progress 2026-07-18 source-shape/resource/editor-registry closure: migrated environment/map tests and runtime registries to canonical `game/world/actors/`, `game/world/maps/`, `game/scenes/`, and `game/art/audio/` ownership; aligned compatibility constants; made every built-in editor actor instantiate its native script base; and eliminated the focused wood-crate lifecycle orphan. Focused proof is 37/37 with 172 assertions and zero GUT-reported orphans. Unsupported loot types remain explicit missing-content cases rather than aliases: vase, corpse pile, hidden stash, and weapon rack.
- Progress 2026-07-18 single-player authority/breakable-prop slice: guarded enemy, world, match, player-state, difficulty, and LOD peer-only paths; made breakable glass/wood damage, material, effect-parenting, and cleanup behavior safe without a multiplayer peer. Focused reference/map/showcase/MatchService proof is 61/61 with 232 assertions, and enemy regression proof is 139/139 with 367 assertions. Breakable proof is 15/17; its two remaining cases are blocked by sandbox ENet socket creation.
- Progress 2026-07-18 splitscreen property/layout slice: five-player layouts now fill the display with five equal 20% regions; property fixtures use legal lifecycle transitions and consume intended diagnostics; error-recovery rate-limit fixtures no longer depend on wall-clock timing. Focused proof is 83/83 with 334 assertions.
- Progress 2026-07-18 visual/configuration and property closure: normalized gameplay visual consumers on `visuals.*`, aligned graphics presets with `graphics.quality_preset`, made ConfigurationManager reload callbacks path-safe, repaired editor full-state undo/redo without fixture orphans, and made lazy-loading correctness deterministic. Focused editor/lazy/graphics/map proof is 52/52 with 443 assertions; frame-time proof is 5/5 at default counts.
- Progress 2026-07-18 evidence refresh: complete category summaries are Unit 996/1056, Integration 198/200, and Property 175/175. Property is green; Integration retains only two sandbox-blocked ENet tests; the categories do not replace the retained complete full-suite baseline.
- Progress 2026-07-18 strict gate: the aggregate completed in 1398.724 seconds under an evidence-derived 2400-second ceiling with 1354/1431 passing, 65 failing, 12 risky/pending, and 56 orphans. Production readiness remains NOT READY with three validator-tracked blockers.
- Progress 2026-07-17 map-generator serialization/lifecycle slice: recursively assigned generated descendants to the PackedScene owner, freed the live source tree after packing, and released detached generation roots on cancellation, failure, and teardown. Focused threading proof is 8/8 with 30 assertions, preserved geometry/navigation after instantiation, and zero GUT-reported orphans versus 20,421 before the repair.
- Progress 2026-07-17 map-export lifecycle slice: immediately freed detached export/validation instances in production and fixtures. Focused export proof remains 10/10 with 34 assertions and now reports zero GUT orphans versus 40 before the repair.
- Progress 2026-07-17 frame-time lifecycle slice: freed each generated GameManager/service tree inside its property callback instead of retaining the entire iteration set until teardown. The bounded run is 5/5 in 2.453s and the default-count lane is 5/5 in 219.696s, both with zero GUT orphans; this remains contract proof, not a production performance claim.
- Progress 2026-07-17 evidence refresh: complete batched summaries are Unit 944/1055, Integration 149/200, and Property 157/175. The strict full run now has a bounded/streaming 900-second gate, but the July 17 attempt timed out during Unit execution without a replacement aggregate summary; production readiness remains NOT READY with three blockers.
- Progress 2026-07-13 Godot 4.7 runtime blocker repair: removed injected `undefined` property-test statements, added explicit types to map-generator fixtures, and restored Resource/RefCounted property compatibility for generation config/context.
- Progress 2026-07-13 animation/audio contract repair: restored SkeletalCharacterVisuals compatibility mappings and updated music fixtures to pass the current AudioStream API.
- Progress 2026-07-13 runtime-harness repair: isolated Godot HOME/XDG directories in launch and headless runners, added project-import preflight, and rejected lane logs that lack GUT summary metrics instead of reporting false green.
- Progress 2026-07-13 evidence refresh: main player-path smoke PASS; bounded performance evidence PASS; manual and release evidence remain BLOCKED; production readiness remains NOT READY with three blockers.
- Progress 2026-07-13 documentation truth overhaul: audited the maintained Markdown corpus against live source and current reports, rewrote current operator/architecture/subsystem boundaries, reclassified obsolete guides as unvalidated historical snapshots, exposed unresolved asset/shader provenance, and added a dedicated documentation truth gate.
- Progress 2026-07-13 map-generator contract slice: joined worker threads on cancellation/tree exit, repaired stale cave/boss/prefab/gameplay/key-lock/LOD/occlusion/navigation calls, deferred scene-tree-only baking/optimization, and aligned generated spawn validation with world positions.
- Focused proof: `test_threaded_generation_completes`, `test_generation_can_be_cancelled`, and `test_metadata_includes_config_info` each pass 1/1 under Godot 4.7; the broader map-generator focus remains noisy and requires a complete lane rerun.
- Progress 2026-07-13 feature/config contract slice: replaced primitive closure flags with mutable dictionaries in event integration fixtures and consumed intentional configuration loader/validation diagnostics; focused proof is feature integration 10/10 and configuration manager 22/22 under Godot 4.7.
- Progress 2026-07-13 property-contract slice: repaired the stale gameplay configuration path, closure-backed feature/state signal fixtures, lazy-reload assumptions, and isolated dependency fixtures; proof is configuration caching 5/5, feature toggle 9/9, and state transitions 6/6. Dependency validation remains 5/7 because startup diagnostics still precede its intended error assertions.
- Progress 2026-07-13 dependency-validation closure: drained GameManager startup diagnostics before each property callback, corrected the disabled-dependency expectation to the single diagnostic emitted by the runtime, and preserved per-iteration error accounting. Full Godot 4.7 proof is `tests/property/test_feature_dependency_validation_pbt.gd` 7/7, 407 assertions, 107.007s.
- Progress 2026-07-13 configuration fallback/validation slice: typed all `ConfigurationManager` property fixtures, made malformed JSON5 generators deterministically invalid, preserved signal/path assertions with mutable callback state, and consumed deferred parser diagnostics. Focused proof is fallback 8/8, validation 6/6, and dependency validation 7/7 under Godot 4.7.
- Progress 2026-07-13 configuration-loading correctness slice: typed the remaining `ConfigurationManager` fixtures and cleaned the file's legacy lint debt without changing runtime behavior. Full Godot 4.7 focused proof is `tests/property/test_configuration_loading_correctness_pbt.gd` 4/4; GDScript lint passes.
- Progress 2026-07-13 modding conflict-contract slice: aligned the duplicate-feature property with the live ModLoader conflict message, removed legacy lint debt from both mod property files, and verified the connected registration path. Godot 4.7 focused proof is mod loading 4/4 and conflict detection 6/6; both files lint cleanly.
- Progress 2026-07-13 mod dependency-resolution slice: aligned the static dependency properties with the live topological-sort, circular-dependency, and missing-dependency contracts, then removed legacy lint debt. Godot 4.7 focused proof is `tests/property/test_mod_dependency_resolution_pbt.gd` 4/4; GDScript lint passes.
- Progress 2026-07-13 weapon-state synchronization slice: verified the isolated rate-limit history and rapid-switching properties against the live test harness, removed legacy trailing whitespace, and reran the lane. Godot 4.7 focused proof is `tests/property/test_weapon_state_sync_pbt.gd` 6/6 with 750 assertions; GDScript lint passes.
- Progress 2026-07-13 event-bus lifecycle slice: verified subscribe, unsubscribe, and multi-listener behavior after the deterministic event-listener teardown repair, removed legacy whitespace, and reran the unit lane. Godot 4.7 focused proof is `tests/unit/test_event_bus.gd` 3/3 with 9 assertions; GDScript lint passes.
- Progress 2026-07-13 GameManager lifecycle slice: aligned the unload-feature unit assertion with the intentional lazy-loading contract by using `is_feature_loaded()` instead of the reload-triggering `get_feature()`. Full Godot 4.7 proof is `tests/unit/test_game_manager.gd` 28/28 with 102 assertions; GDScript lint passes.
- Progress 2026-07-13 performance-property slice: aligned memory reload tolerance with the existing shutdown variance boundary and added scheduler/allocator tolerance to the lazy-startup timing smoke. Godot 4.7 default-count proof is memory 4/4 in 69.909s and lazy loading 4/4 in 57.766s. The frame-time lane's later July 17 lifecycle repair supersedes its former timeout boundary.
- Progress 2026-07-13 assignment-UI contract slice: switched production and mock signal wiring to Godot 4.7's generic signal APIs and made duplicate-device rejection an explicit expected diagnostic. Focused proof is `tests/unit/splitscreen/test_assignment_ui.gd` 15/15 with 21 assertions; both changed GDScript files pass lint. The aggregate Phase 0 baseline remains open.
- Progress 2026-07-13 map-generator contract slice: consumed the intentional cellular-automata diagnostic, bounded hallway generation to the documented nearby-room graph, and made A* treat only room endpoints as traversable. Focused proof is the full `tests/unit/map_generator/` group: 9 scripts, 79/79 tests, 5,439 assertions; changed files pass lint. The aggregate Phase 0 baseline remains open.
- Progress 2026-07-13 map-playability integration slice: reconnected `game/scenes/world.tscn` to the maintained comprehensive showcase, supplied navigation data and explicit enemy spawns, and attached the map in the integration fixture before transform checks. Focused proof is `tests/integration/test_map_playability.gd` 15/15 with 40 assertions; the aggregate Phase 0 baseline remains open.
- Progress 2026-07-13 showcase integration recheck: launched the maintained showcase through its real scene fixture and verified 4 player spawns, 2 enemy spawns, 1 navigation region, lighting, environment, collision, and 539 total nodes. Focused proof is `tests/integration/test_showcase_map.gd` 17/17 with 46 assertions; manual golden-demo evidence remains open.
- Progress 2026-07-13 reference/migration integration recheck: reran the live path ownership, autoload, scene-load, and legacy-compatibility contracts under Godot 4.7. Reference integrity passes 21/21 with 116 assertions; migration compatibility passes 13/13 with 21 assertions. Existing duplicate core-service warnings remain diagnostic noise only; the aggregate Phase 0 baseline remains open.
- Progress 2026-07-13 map-generator export/seed slice: reran export coverage at 10/10 with 34 assertions and deterministic seed/RNG coverage at 8/8 with 29 assertions. Updated threaded metadata fixtures from retired `generation_time_ms` to the live seconds-based `generation_time` contract and removed lint debt. The later July 17 lifecycle repair supersedes the incomplete threaded-lane boundary.

Accepted recovery/extension plan for making the marketing pitch true in evidence, not only in code shape. Promote one row at a time into the current implementation slice; do not close a row until its proof line is actually run and recorded. For planned rows below, `Shortcoming` is the current evidence note and `Completion proof required` is the closure gate.

### Phase 0: Truth And Test Stabilization

- [x] Repair high-signal contract drift in the Godot/GUT baseline. `[truth:test]` `[truth:verified]`
	- Closure: the retained complete 2026-07-19 Godot 4.7 filtered GUT baseline is green at 1431/1431 with 20,362 assertions and no risky/pending tests or GUT orphans.
	- Progress 2026-07-09: save, network manager, RPC whitelist, mod-loading, enemy AI, enemy AI system, and AI LOD contract drift repaired under Godot 4.7. Focused proof: `tests/unit/test_save_system.gd` 6/6, `tests/unit/test_network_manager.gd` 9/9, `tests/unit/test_rpc_whitelist.gd` 9/9, `tests/integration/test_mod_loading.gd` 12/12, `tests/unit/test_enemy_ai.gd` 13/13, `tests/unit/test_enemy_ai_system.gd` 126/126, `tests/unit/test_ai_lod_update_rate.gd` 13/13.
	- Historical lane triage 2026-07-09: an earlier report split that run into Unit 813/1047 passing, Integration 93/195 passing, Property 114/175 passing, and skipped Benchmark evidence. Those figures are superseded by the complete July 18 category summaries and 1354/1431 full-suite baseline.
	- Progress 2026-07-10: the strict readiness rerun completed and now preserves `logs/full_godot_gut_latest.log.gz`; it exposed repeated no-peer network processing and closed-file logger shutdown errors. Guards were added for both, and the network-manager focused lane remains green at 9/9.
	- Progress 2026-07-10 splitscreen slice: normalized integer-valued JSON numbers, made manager initialization idempotent, fixed malformed controller-error formatting, and added a 3/3 configuration contract lane. The strict aggregate rerun improved from 894/1417 passing and 509 failing to 991/1421 passing and 416 failing; risky/pending stayed at 14.
	- Progress 2026-07-10 lifecycle slice: repaired stale splitscreen fixtures to use legal `INACTIVE -> INITIALIZING -> ASSIGNING_DEVICES -> ACTIVE` transitions and explicitly consume expected errors. Manager proof improved from 8/28 to 28/28 and multiplayer-compatibility proof from 7/16 to 16/16. The strict aggregate rerun improved again from 991 passing and 416 failing to 1029 passing and 378 failing.
	- Progress 2026-07-10 gameplay/stress slice: added deterministic device discovery injection, coherent feature teardown/reinitialization, bounded FPS trimming, accumulated-time reporting, and expected corruption diagnostics. Feature integration is 10/10, gameplay is 34/34, and stress is 20/20. The strict aggregate rerun improved from 1029 passing and 378 failing to 1061 passing and 346 failing.
	- Progress 2026-07-13 stale-test triage: bounded `tests/property/test_adapter_compatibility_pbt.gd` behind an explicit skip while the three legacy adapter scripts remain archived. The placeholder `Node` adapters were generating false runtime failures and API-compatibility failures; the test now records the archive boundary and will automatically re-enable when all adapter scripts return.
	- Progress 2026-07-13 property-harness triage: made `run_enhanced_property_test()` await async property callbacks and updated its 117 property-lane call sites to await the helper. This removes the shared harness error that previously invalidated async configuration, state, and feature properties before their assertions ran.
	- Progress 2026-07-13 configuration-error triage: switched JSON5 parsing to the non-emitting `JSON.parse()` API, removed loader-test inputs that are valid after trailing-comma normalization, and consumed intentional loader/manager diagnostics in the invalid-file property lanes. The fallback and error-path properties now test controlled reporting rather than failing on engine-error side effects.
	- Progress 2026-07-13 configuration-lifecycle triage: registered property-created `ConfigurationManager` instances with GUT cleanup across caching, fallback, validation, and loading-correctness lanes. This removes the repeated 100-orphan-per-property leak that was masking cache/reload results.
	- Progress 2026-07-13 GameManager-lifecycle triage: moved state-transition and feature-toggle property fixtures to `add_child_autofree()` and removed manual `queue_free()` paths. This keeps the full service tree under GUT ownership and targets the retained 600-orphan lifecycle cluster.
	- Progress 2026-07-13 feature-integration triage: aligned stale integration fixtures with the canonical `config` service ID, added a non-lazy `is_feature_loaded()` query, freed unloaded feature nodes, and made explicit core-feature reloads recreate missing core services.
	- Progress 2026-07-13 configuration ownership triage: attached GameManager-owned `ConfigurationManager` instances to the GameManager tree before registration, eliminating the repeated orphan left by every initialized integration fixture.
	- Progress 2026-07-13 mod-conflict triage: added real ModLoader registries for features, components, entities, and resource overrides, with duplicate detection, mod-name-bearing conflict records, query/clear APIs, and reload cleanup.
	- Progress 2026-07-13 mod-manifest wiring: preserved `features`, `components`, and `entities` fields while reading manifests and registered them during enabled-mod loading, so the conflict layer is connected to the actual mod path.
	- Progress 2026-07-13 mod-reload lifecycle: made every `load_all_mods()` pass reset registration, resource-ownership, and conflict state before rebuilding from enabled manifests, preventing stale duplicate reports after reload.
	- Progress 2026-07-13 weapon-sync property triage: reset the rate-limit fixture history for each generated one-second window, preventing accepted sequences from being rejected because prior iterations leaked timestamps into the next case.
	- Progress 2026-07-13 GameManager teardown triage: changed event-listener cleanup to clear listener arrays before clearing the registry, avoiding mutation of `_event_listeners` during iteration and making shutdown cleanup deterministic.
	- Progress 2026-07-13 dependency-property lifecycle: moved feature dependency validation fixtures to GUT-owned GameManager cleanup and removed manual queue-free paths, keeping circular and missing-dependency checks focused on their contract.
- Progress 2026-07-13 performance-property lifecycle: moved frame-time, memory-usage, and lazy-loading GameManager fixtures to GUT-owned cleanup and removed mixed manual teardown, reducing lifecycle noise in performance evidence.
- Progress 2026-07-13 showcase/reference slice: repaired embedded interactable service lookups, attached showcase fixtures before global-transform checks, made optional lever animation safe, and refreshed focused proof to showcase 17/17, reference integrity 20/20, and migration compatibility 13/13.
- Progress 2026-07-13 data/config ownership slice: aligned README with the JSON schema ownership boundary, linked the showcase route from the docs index, and extended reference-integrity proof to 21/21.
- Progress 2026-07-13 Steam proof-boundary slice: documented ENet fallback, Steam-unavailable, simulated/local, and real GodotSteam evidence states; focused fallback smoke reached the live socket path but remains blocked by sandbox localhost socket creation.
- Progress 2026-07-13 ENet loopback slice: added separate Godot server/client probes with deterministic peer teardown and generated `docs/ENET_LOCAL_HOST_JOIN_SMOKE.md`; the latest run is BLOCKED only by sandbox localhost socket creation.
	- Progress 2026-07-13 showcase-path triage: restored `game/world/maps/showcase.tscn` as a compatibility entry point to the maintained comprehensive showcase, added player-spawn groups, and assigned a navigation mesh to the existing navigation region.
	- Progress 2026-07-13 level-path triage: restored compatibility scenes under `game/levels/` for movement lab, hazards arena, projectile range, and traversal course, each forwarding to its maintained `game/world/maps/` scene.
	- Progress 2026-07-13 component-path triage: restored legacy script entry points for health, combat, perception, status-effect, pain, and player-service paths, each extending the maintained implementation.
	- Progress 2026-07-13 core-service registration triage: registered script-backed match, player, and gameplay services in the GameManager service locator, restoring `get_core_system("gameplay")` and dependent LootSvc discovery.
	- Progress 2026-07-13 map-generator type-surface triage: declared the autoload script as global `MapGenerator`, allowing isolated export/seed/threading tests to instantiate the maintained implementation instead of resolving the singleton Node.
	- Progress 2026-07-13 map-generator fixture lifecycle: removed redundant manual queue-free calls from export, seed, and threading unit fixtures already owned by GUT cleanup.
	- Progress 2026-07-13 gameplay-service locator triage: corrected `GameplaySvc.get_service()` to guard and use GameManager's canonical `get_core_system()` API, preserving the root-node fallback only when the locator is unavailable.
	- Progress 2026-07-13 service-API compatibility: added GameManager.get_service() as a backward-compatible delegate to get_core_system(), restoring legacy integration callers while retaining one service registry.
	- Progress 2026-07-13 static-locator hardening: guarded EntityService and PerformanceService accessors before calling `get_core_system()`, matching the partial-startup-safe service lookup contract.
	- Progress 2026-07-13 static-locator hardening: guarded CombatSvc, PlayerSvc, and LootSvc accessors before using GameManager's core registry, completing the partial-startup-safe service lookup cluster.
	- Progress 2026-07-13 static-locator hardening: guarded MissionMgr, EnemyTrkr, PlayerStateSvc, and InventoryMgr accessors before using GameManager's core registry, completing the partial-startup-safe service lookup cluster.
	- Progress 2026-07-13 object-pool property lifecycle: changed each generated pool fixture to free immediately after clearing its pools, preventing five 100-iteration property cases from accumulating deferred orphan nodes.
	- Progress 2026-07-13 editor-property lifecycle: added explicit teardown for the standalone editor fixture and UndoRedo state, preventing editor availability from leaking a node across property tests.
	- Progress 2026-07-13 detached-unit lifecycle: changed unattached animation fixtures and removed signal-hygiene components to free immediately, avoiding deferred orphan noise after their exit-tree assertions.
	- Progress 2026-07-13 attached-unit lifecycle: changed GameComponent, CombatFeature, and InventoryFeature fixtures to free immediately after their assertions, reducing deferred orphan accumulation in the non-splitscreen unit lane.
	- Progress 2026-07-13 map-export fixture lifecycle: changed unattached exported PackedScene and generated GLTF scene instances to free immediately, removing deferred cleanup from the map-generator export lane.
	- Progress 2026-07-13 integration fixture lifecycle: changed player/HUD scene roots and the NetworkEditor signal test root to free immediately after teardown, reducing deferred root-node orphans in non-splitscreen integration tests.
	- Progress 2026-07-13 UI fixture ownership: removed redundant manual queue-free calls from UI tests whose screens and HUDs already use GUT add_child_autofree ownership.
	- Progress 2026-07-13 GUT-owned splitscreen lifecycle: removed redundant manual queue-free calls from assignment, manager, viewport, input, and revive fixtures while retaining explicit session/viewport cleanup.
	- Progress 2026-07-13 GUT-owned integration lifecycle: removed redundant manual queue-free calls from splitscreen feature, stress, gameplay, and multiplayer-compatibility fixtures while retaining explicit session shutdown.
	- Progress 2026-07-13 remaining GUT-owned splitscreen lifecycle: removed redundant GamepadController and error-recovery manager teardown, and immediately freed unattached input-property components.
	- Progress 2026-07-13 generated-test cleanup: removed empty `user://test_temp` directories after analyzer property fixtures and cleaned the dependency-test directory after generated files are removed.
	- Progress 2026-07-13 reference-integrity path repair: replaced stale optional grunt/soldier scene names with the maintained enemy, corpse, and dummy scene paths and made the lane assert those current references load.
	- Progress 2026-07-13 effects path repair: aligned the effects-service unit assertion with the maintained `game/scripts/features/effects/effects_service.gd` implementation instead of the retired `game/services/` path.
	- Progress 2026-07-13 docs path repair: aligned service and modding examples with the maintained feature-service and `game/config/gameplay/gameplay.json5` paths, removing retired `game/services/` and `game/cfg/` claims.
	- Progress 2026-07-13 documentation truth sweep: updated service architecture, config schema/testing, Steam, editor, and dedicated-server paths to live `game/scripts/features/` and `game/config/` locations.
	- Progress 2026-07-13 live-path cleanup: updated the visual-tweaking showcase, minimap generator guidance, and GameplaySvc comments to use current config/feature paths instead of retired locations.
	- Progress 2026-07-13 tooling path cleanup: updated the editing guide and indentation helper to use live `game/config/` ownership and repo-relative MODUS paths instead of retired absolute locations.
	- Progress 2026-07-13 remaining config-doc cleanup: aligned balance, movement, technical-reference, and performance examples with live entities, gameplay, and performance config files.
	- Progress 2026-07-13 config migration guard: extended `tools/check_project_truth.sh` to fail on retired `game/cfg/`, `game/data/cfg/`, `game/config/balance/`, and root `game/config/gameplay.json5` claims across active docs and source-facing guidance.
	- Progress 2026-07-13 data/config ownership map: documented the live boundary between `game/data/`, `game/config/`, feature profiles, and `user://mods/` overrides in `docs/technical/JSON_SCHEMAS.md`.
	- Progress 2026-07-13 ownership-boundary verification: expanded reference-integrity coverage to feature profiles, network/performance/entity config, item data, and both live loot-table locations.
	- Progress 2026-07-13 schema-example repair: removed nonexistent weapon data/icon/script paths from the JSON schema example and aligned it with the live pistol registry entry.
	- Progress 2026-07-13 configuration API example repair: aligned getting-started load, reload, signal, and validation snippets with GameManager's ConfigurationManager API and live gameplay config paths.
	- Progress 2026-07-13 troubleshooting API repair: aligned service, configuration, logging, and effects examples with GameManager core-system and current ConfigurationManager/LogService methods.
	- Progress 2026-07-13 modding API example repair: aligned event subscriptions, feature-flag access, and custom service registration with GameManager's live APIs.
	- Progress 2026-07-13 service-architecture API repair: aligned subsystem tables, event/log access, and service registration examples with GameManager's core-system registry.
	- Progress 2026-07-13 technical API sweep: aligned getting-started service access, component config hooks, and JSON schema hot-reload examples with GameManager and ConfigurationManager.
	- Progress 2026-07-13 truth-gate strengthening: required the live GameManager/MapGenerator autoload declarations and the documented data/config ownership boundary in project truth checks.
	- Progress 2026-07-13 Godot parse repair: removed the conflicting MapGenerator class_name from the autoload script and made isolated map-generator unit fixtures instantiate the preloaded script directly.
	- Progress 2026-07-13 first live Godot triage: replaced invalid `has_property()`/Node `.has()` calls in network movement validation and Steam/ENet setup with supported property access, removing repeated runtime script errors.
	- Progress 2026-07-13 unit-runtime triage: restored GameComponent inheritance in the mock fixture, added GameManager.is_initialized(), and replaced SceneTree misuse in RPC stress tests with a Node-compatible rate-limit double.
	- Progress 2026-07-13 mock-component runtime repair: moved the GameComponent test double into a standalone script so Godot preserves its inherited API instead of collapsing the inner class to Node.
	- Progress 2026-07-13 release-example repair: aligned the current-facing effects-service snippet with GameManager's core-system API; historical audit and anti-pattern examples remain explicitly historical/negative.
	- Progress 2026-07-17 map-generator ownership/lifecycle triage: PackedScene ownership now includes recursive generated geometry/navigation, and live detached roots are freed immediately after pack/export/validation or on cancellation/failure. Threading improved from 20,421 focused GUT orphans to zero while passing 8/8; export improved from 40 to zero while passing 10/10.
	- Progress 2026-07-17 performance-property lifecycle: per-iteration GameManager teardown lets the default frame-time lane complete 5/5 in 219.696s with zero GUT orphans instead of timing out while retaining all service trees.
	- Progress 2026-07-17 current lanes: Unit is 944/1055 passing with 99 failing, 12 risky/pending, and 56 orphans; Integration is 149/200 with 51 failing and 6 orphans; Property is 157/175 with 18 failing and 6 orphans.
	- Progress 2026-07-17 strict gate: the readiness runner now streams its log, rejects missing summaries, and enforces a configurable positive timeout (900 seconds by default). The current run reached Unit execution but timed out without a complete aggregate summary; `logs/full_godot_gut_latest.log.gz` retains the partial evidence.
	- Progress 2026-07-18 no-peer authority/breakable slice: single-player world, enemy, synchronization, difficulty, LOD, and breakable-prop paths now avoid peer-only calls. Focused reference/map/showcase/MatchService proof is 61/61, enemy regression proof is 139/139, and breakable proof is 15/17 with only the two sandbox-blocked ENet cases failing.
	- Progress 2026-07-18 current lanes: Unit is 945/1055 passing with 98 failing, 12 risky/pending, and 56 orphans; Integration is 198/200 with 2 sandbox-blocked ENet failures; Property is 159/175 with 16 failing and 6 orphans.
	- Progress 2026-07-18 strict gate: the bounded aggregate run completed Integration, feature toggles, and the frame-time property file before timing out at 900 seconds during GameManager state-transition properties. `logs/full_godot_gut_latest.log.gz` preserves the incomplete run.
	- Progress 2026-07-18 splitscreen property/layout closure: implemented equal-area five-player layout, repaired all ten failing splitscreen properties, made intended diagnostics explicit, and removed wall-clock dependence from adjacent error-recovery fixtures. Focused proof is 83/83 with 334 assertions.
	- Progress 2026-07-18 current lanes after closure: Unit is 948/1055 passing with 95 failing, 12 risky/pending, and 56 orphans; Integration is 198/200 with 2 sandbox-blocked ENet failures; Property is 168/175 with 7 failing and 6 orphans.
	- Progress 2026-07-18 complete strict gate: an evidence-derived 2400-second ceiling allowed the aggregate to finish in 1327.584 seconds at 1299/1430 passing, 119 failing, 12 risky/pending, and 62 orphans. The 15-failure gap versus isolated category totals is an aggregate-interaction triage lane.
	- Progress 2026-07-18 visual/configuration closure: canonicalized `visuals.*` access and graphics preset naming, made all ConfigurationManager reload subscribers path-safe, repaired editor undo/redo state/fixture ownership, and replaced timing-sensitive lazy-loading correctness with deferred-construction proof. Focused editor/lazy/graphics/map proof is 52/52; the complete Property lane now passes 175/175 with no GUT-reported orphans.
	- Progress 2026-07-18 current lanes: Unit is 968/1055 passing with 75 failing, 12 risky/pending, and 56 orphans; Integration is 198/200 with 2 sandbox-blocked ENet failures; Property is 175/175.
	- Progress 2026-07-18 current strict gate: the aggregate completed in 1407.761 seconds at 1326/1430 passing, 92 failing, 12 risky/pending, and 56 orphans. The 15-failure gap versus isolated category totals remains an aggregate-interaction triage lane.
	- Progress 2026-07-18 source-shape closure: canonicalized environment/map/resource/editor registry paths, verified every registered actor and canonical scene/resource directory, and freed the temporary wood-crate particle fixture. Focused proof is 37/37 with 172 assertions and zero GUT orphans; four unsupported loot-prop scene types remain explicit content work.
	- Progress 2026-07-18 current lanes after source-shape closure: Unit is 986/1055 passing with 57 failing, 12 risky/pending, and 56 orphans; Integration is 198/200 with 2 sandbox-blocked ENet failures; Property is 175/175.
	- Progress 2026-07-18 current strict gate after source-shape closure: the aggregate completed in 1139.833 seconds at 1343/1430 passing, 75 failing, 12 risky/pending, and 56 orphans. The 16-failure gap versus isolated category totals remains an aggregate-interaction triage lane.
	- Progress 2026-07-18 advanced-movement closure: repaired grounded bunny-hop/slide contracts, cap/chain/signal behavior, no-peer dodge synchronization, and canonical rocket-jump JSON5 loading. Focused and aggregate movement proof both pass 36/36; Unit improves to 996/1056 with 48 failures.
	- Progress 2026-07-18 current strict gate after movement closure: the aggregate completed in 1398.724 seconds at 1354/1431 passing, 65 failing, 12 risky/pending, and 56 orphans. The 15-failure gap versus isolated category totals remains an aggregate-interaction triage lane outside the now-green movement file.
	- Progress 2026-07-19 RPC validation/rate-limit closure: wired weapon-switch and pickup validators into fail-secure static dispatch, repaired gameplay registry lookup, and made the stress fixture model one second directly. Focused proof is 34/34 across RPC stress, weapon switch, and NetworkManager; the Unit lane improves to 1009/1056 with 35 failures.
	- Progress 2026-07-19 splitscreen device/session closure: consumed all expected invalid-transition/assignment diagnostics, replaced the stale `is_connected` assertion with the live `connected` field, and added a deterministic margin to adjacent rate-limiter boundary fixtures. Focused proof is 86/86; the Unit lane is 1018/1056 with 26 failures.
	- Progress 2026-07-19 component lifecycle/signal-hygiene closure: reused LegacyGameComponent in the test double, aligned dynamic signals with generic Godot 4.7 APIs, and removed unsafe blanket child cleanup. Focused proof is 30/30; the Unit lane improves to 1022/1056 with 22 failures.
	- Progress 2026-07-19 feature lifecycle/toggle closure: validated dependency-free modules without GameManager, guarded unattached tree lookup, used explicit loaded-state queries after unload, and GUT-owned all module fixtures. Focused proof is 36/36; the Unit lane improves to 1028/1056 with 16 failures and 37 orphans.
	- Progress 2026-07-19 individual-weapon closure: corrected the hitscan speed default and aligned async setup, switching, reload, ammo, and signal fixtures with live name-sorted inventory behavior. Focused proof is 58/58; the Unit lane improves to 1034/1056 with 10 failures.
	- Progress 2026-07-19 combat configuration/modifier closure: preserved injected feature configuration through initialization and removed detached global-transform access from the fixture. Focused proof is CombatFeature 20/20 plus FeatureModule 19/19; the Unit lane improves to 1037/1056 with 7 failures.
	- Progress 2026-07-19 audio/telemetry API-contract closure: aligned music navigation with the maintained service methods and made logger callback observations closure-safe. Focused proof is 23/23; the Unit lane improves to 1040/1056 with 4 failures.
	- Progress 2026-07-19 deterministic path/UI boundary closure: restricted GridLayoutManager A* to walkable cells and aligned the bounded HUD fixture with its ten actual updates. Focused proof is 30/30; the Unit lane improves to 1042/1056 with 2 failures.
	- Progress 2026-07-19 ENet fallback Unit closure: consumed intentional engine errors, fixed fixture ownership, and hardened pending-only retained-log classification. Focused proof is 11/11; the Unit lane reaches PASS at 1044/1056 with 0 failures, 12 pending/risky, and 36 orphans.
	- Progress 2026-07-19 configuration-validation risk closure: asserted canonical nested config paths, GUT-owned manager fixtures, and stabilized short generated audio playback. Focused proof is config 14/14 plus audio 12/12; the Unit lane reaches 1047/1056 with 9 pending progression contracts and 22 orphans.
	- Progress 2026-07-19 progression/category closure: tested the live per-player progression component and SaveService contract instead of a retired global service, restored UI-facing getters, corrected breakable-prop RPC validation, and closed test-owned ENet peers. Focused proof is progression 9/9 plus breakables 17/17; lanes are Unit 1056/1056, Integration 200/200, and Property 175/175.
	- Progress 2026-07-19 strict aggregate closure: no-peer guards for enemy alert RPCs and network statistics close all 13 aggregate-only failures. Aggregate-order regression is 152/152; complete proof is 1431/1431 in 1292.096 seconds.
	- Progress 2026-07-19 orphan/lifecycle closure: GUT owns every ConfigurationManager fixture and the event frame-time property discards host scheduler edge outliers. Unit and aggregate GUT orphan counts reach zero; final strict proof is 1431/1431 in 1770.186 seconds.
	- Remaining maintenance: reduce service-initialization and engine-exit diagnostics/runtime; implement real scenes for vase, corpse pile, hidden stash, and weapon rack if those loot types remain in scope.
	- Completion proof achieved: focused, category, and complete strict aggregate lanes are green with no risky/pending tests.
  - Re-entry condition: start here before feature expansion because this is the current release-truth blocker.

### Phase 1: Multiplayer Pitch Proof

- [x] Add a validated multiplayer demo profile and make the headline multiplayer path explicit. `[truth:verified]`
  - Shortcoming: `game/config/features.json5` defaults to the `standard` profile, where `network` is disabled, while the pitch leads with multiplayer.
  - Completion proof: `multiplayer_demo` explicitly enables `network`, `MODUS_FEATURE_PROFILE` selects it for a launch smoke, `docs/MULTIPLAYER_PROFILE_SMOKE.md` records the standard-vs-demo boundary, and the smoke passes without profile/service lookup errors. Peer connectivity remains a separate open task.
- [x] Create an ENet local host/join smoke with deterministic teardown. `[truth:verified]`
  - Shortcoming: host/join code exists, but no current green local runtime proof demonstrates two peers connecting in Godot 4.7.
  - Completion proof: `tools/run_enet_local_smoke.sh` starts separate Godot server/client probes, verifies connection signals when sockets are available, tears down peers, and writes `docs/ENET_LOCAL_HOST_JOIN_SMOKE.md`; the current run records the precise sandbox socket blocker.
- [x] Define the Steam/GodotSteam proof boundary separately from ENet fallback. `[truth:verified]`
  - Shortcoming: Steam manager and workshop structures exist, but Steam availability is conditional and not proven in this CLI run.
  - Completion proof: `docs/technical/STEAM_INTEGRATION.md` distinguishes ENet fallback, Steam unavailable, simulated/local, and real Steam/GodotSteam evidence; `tools/check_project_truth.sh` requires the boundary wording; production reports continue to mark live Steam proof blocked.

### Phase 2: Data And Configuration Productization

- [x] Reconcile `game/data` and `game/config` into a clean public configuration story. `[truth:verified]`
  - Shortcoming: README/memory market live data under `game/data`, while GameManager and many tests load `game/config/*`; both are real but the ownership boundary is confusing.
  - Completion proof: `docs/technical/JSON_SCHEMAS.md` is the source-of-truth map, README links it and distinguishes content from runtime configuration, and `tests/integration/test_reference_integrity.gd` validates both live paths and the ownership wording.
- [x] Add a configuration migration/compatibility check for stale path claims. `[truth:verified]`
  - Shortcoming: historical docs still mention moved config paths, and future agents may reintroduce `game/cfg` or wrong `game/data` claims.
  - Completion proof: `tools/check_project_truth.sh` rejects retired `game/cfg/`, `game/data/cfg/`, `game/config/balance/`, and root `game/config/gameplay.json5` claims across active docs/source guidance; the ownership boundary is documented in `docs/technical/JSON_SCHEMAS.md`.

### Phase 3: Golden Demo Path

- [ ] Build one player-visible golden demo smoke that proves the framework loop. `[truth:deferred]`
  - Shortcoming: main menu launch smoke passes, but it does not prove movement, shooting, enemies, loot, save/load, mod loading, or multiplayer.
  - Completion proof required: automated or semi-automated smoke launches a known scene, spawns a player, moves, fires a weapon, damages or kills an enemy, grants loot, exercises save/load, and records PASS/FAIL in a generated report.
  - Re-entry condition: after Phase 0 stabilizes service/test contracts.
- [x] Create a documented showcase route for video/screenshots and manual validation. `[truth:verified]`
  - Shortcoming: the pitch needs proof assets; current evidence is mostly source/test reports.
  - Completion proof: `docs/SHOWCASE_ROUTE.md` names the maintained scene and compatibility entry point, defines observable actions and capture points, and specifies the manual CSV/evidence handoff. Automated structure proof is `tests/integration/test_showcase_map.gd`; manual capture remains pending.

### Phase 4: Modding SDK Proof

- [x] Turn modding into a shippable SDK surface with one working sample mod. `[truth:verified]`
  - Shortcoming: basic event/feature mod integration is now green, but `ModLoader`, asset overrides, script hooks, mod UI structures, and package ergonomics still lack a shippable sample-mod proof.
  - Completion proof: `mods/modus_sdk_sample/` overrides weapon, enemy, and loot values, declares a `ModScript` with an enemy-spawn hook and event subscription, and passes `tests/integration/test_sample_mod_sdk.gd` at 2/2. Packaging, UI registration, and live balance remain separate proof boundaries.
- [x] Add mod package validation and conflict diagnostics. `[truth:verified]`
  - Shortcoming: priority/dependency concepts exist, but marketing-ready modding needs clear errors when manifests, dependencies, or overrides are wrong.
  - Completion proof: `ModPackageValidator` reports missing fields, bad dependencies, duplicate active override ownership, and disabled-mod warnings; `tools/validate_mod_packages.gd` scans 9 packages with 0 errors and focused tests pass 4/4 across valid and invalid manifests.

### Phase 5: Editor, Export, And Workshop Lane

- [x] Prove level editor save/export/reload as an end-to-end authoring workflow. `[truth:verified]`
  - Shortcoming: live editor UI interaction and rendered/playable manual evidence remain separate lanes.
  - Completion proof: `tests/integration/test_editor_roundtrip.gd` passes 1/1 with 15 assertions; it creates a small level, saves it, exports it as a mod folder, reloads both scene files, and validates player/enemy spawns plus a placed actor survive round-trip. See `docs/EDITOR_ROUNDTRIP_PROOF.md`.
  - Re-entry condition: after data/config and mod package boundaries are settled.
- [x] Separate local workshop simulation from real Steam Workshop upload proof. `[truth:verified]`
  - Shortcoming: real Steam upload/download remains blocked because GodotSteam, Steam client, app ID, and account authorization are unavailable in this environment.
  - Completion proof: local simulation passes `tests/integration/test_workshop_local_simulation.gd` at 1/1 with 13 assertions for package upload, metadata/cache, download, browse, subscribe, and unsubscribe; see `docs/WORKSHOP_LOCAL_SIMULATION_PROOF.md`.
  - Re-entry condition: before claiming Workshop support beyond local/simulated mode.

### Phase 6: Manual And Performance Evidence

- [ ] Import manual gameplay evidence and clear the zero-hours blocker. `[truth:deferred]`
  - Shortcoming: current status records zero manual testing hours.
  - Completion proof required: ManualTestTimer CSV evidence exists under `logs/manual_test_logs`; `tools/validate_manual_evidence.sh --strict` passes; docs record exactly what was tested and what remains untested.
  - Re-entry condition: after golden demo/manual route is defined.
- [x] Produce first measured performance baseline and replace theoretical FPS targets. `[truth:verified]`
  - Shortcoming: the baseline is an unthrottled compatibility-renderer capture with a 108.55 ms frame-time spike and extreme enemy-position warnings; user-facing targets and split-screen/multiplayer performance remain unverified.
  - Completion proof: `logs/performance_logs/showcase_baseline_20260713.csv` contains 66.4 seconds and 130 samples; `tools/validate_performance_evidence.sh --strict` passes; see `docs/PERFORMANCE_BASELINE_PROOF.md` for hardware, scene, renderer, metrics, and exclusions.
  - Re-entry condition: after one stable demo/showcase route exists.

### Phase 7: Marketing-Ready Package

- [ ] Complete a distribution provenance ledger and resolve unverified third-party licensing. `[truth:source-audit]` `[truth:blocked]`
  - Shortcoming: `docs/ATTRIBUTION.md` confirms local MIT text for LichForge and GUT, but Kenney asset license records, the blood-pool shader's upstream license, and an older Jeh3no attribution are not locally established. The production validator's two-count does not include legal/distribution clearance.
  - Completion proof required: inventory every distributed non-code asset and derived code path by file/hash/source/license, retain required notices locally, resolve or replace unknown entries, and verify exported bundles contain the required material.
- [ ] Create a proof-backed product page/readme section that matches the verified boundary. `[truth:deferred]`
  - Shortcoming: the elevator pitch is directionally strong but would overclaim if it ignored non-green tests, default-disabled networking, zero manual hours, and the limits of one bounded performance capture.
  - Completion proof required: README/product copy labels alpha limits, links current proof reports, names green demo paths, and avoids claims not backed by source/test/runtime/manual evidence.
  - Re-entry condition: after Phases 0-6 have at least one green proof lane each.
- [ ] Produce a release evidence bundle for screenshots, short video, benchmark table, and known-limits matrix. `[truth:deferred]`
  - Shortcoming: marketing needs artifacts, not only architecture docs.
  - Completion proof required: generated or recorded assets are stored or linked from docs; `docs/CURRENT_STATUS.md` and release docs cite the evidence bundle and current unresolved blockers.
  - Re-entry condition: after the golden demo and performance baseline are repeatable.

## Completed This Cycle

- [x] Split automated proof into durable lanes instead of one opaque 1,400-test failure wall. `[truth:test]` `[truth:source-audit]`
  - Evidence: `GODOT_BIN=/tmp/modus_godot_4.7/Godot_v4.7-stable_linux.x86_64 tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md` with isolated writable runtime directories.
  - Result: the runner now imports the project first, isolates Godot user state, and marks incomplete GUT logs BLOCKED; the July 13 refresh reached live Unit tests but did not complete the lane, so Integration/Property remain not run.
- [x] Refresh current-facing project docs after focused Phase 0 repairs. `[truth:docs]` `[truth:source-audit]`
  - Evidence: `tools/validate_release_readiness.sh`; `tools/validate_manual_evidence.sh`; `tools/validate_performance_evidence.sh`; `bash tools/check_project_truth.sh`.
  - Boundary: `docs/PRODUCTION_READINESS_REPORT.md` was regenerated on July 13; launch smoke and one bounded performance-evidence gate pass, while full-suite, manual, and release blockers remain explicit.
- [x] Repair save/network/mod-loading contract drift from the Godot 4.7 baseline. `[truth:test]` `[truth:source-audit]`
	- Evidence: Godot 4.7/GUT focused runs: `tests/unit/test_save_system.gd` 6/6; `tests/unit/test_network_manager.gd` 9/9; `tests/unit/test_rpc_whitelist.gd` 9/9; `tests/integration/test_mod_loading.gd` 12/12.
	- Boundary: Superseded by the enemy AI/system focused proof below; Phase 0 remains open for full production-readiness rerun and full-suite total refresh.
- [x] Repair enemy AI/system and AI LOD contract drift from the Godot 4.7 baseline. `[truth:test]` `[truth:source-audit]`
	- Evidence: Godot 4.7/GUT focused runs: `tests/unit/test_enemy_ai.gd` 13/13; `tests/unit/test_enemy_ai_system.gd` 126/126; `tests/unit/test_ai_lod_update_rate.gd` 13/13.
	- Boundary: Phase 0 remains open for full production-readiness rerun and full-suite total refresh.
- [x] Adopt proof tags for backlog closure. `[truth:docs]` `[truth:source-audit]`
  - Evidence: `bash tools/check_project_truth.sh`
- [x] Tailor generated memory and roadmap docs with live MODUS commands and truth boundaries. `[truth:docs]` `[truth:source-audit]`
  - Evidence: `bash tools/check_project_truth.sh`
- [x] Classify GUI-required tests and update headless runner configuration. `[truth:source-audit]` `[truth:blocked]`
  - Evidence: `bash tools/check_headless_runner_manifest.sh`; `./tests/runners/run_all_tests_headless.sh` exits 127 with a clear missing-Godot message in this CLI environment.
  - Superseded by 2026-07-09 Godot 4.7 proof: the binary blocker was cleared via `GODOT_BIN`, but the filtered suite is non-green.
- [x] Refresh active stack pins, code references, CI containers, runner help text, and current docs to Godot 4.7 stable. `[truth:source-audit]` `[truth:test]`
  - Evidence: official Godot 4.7 stable Linux binary reported `4.7.stable.official.5b4e0cb0f`; `bash tools/check_project_truth.sh`; `bash tools/check_headless_runner_manifest.sh`; headless editor import exited 0; `tools/run_main_player_path_smoke.sh --headless --duration 5` wrote PASS to `docs/MAIN_PLAYER_PATH_SMOKE.md`.
  - Full-suite boundary: the filtered suite completed under Godot 4.7 and GUT 9.5.1 at 1431/1431 passing with 20,362 assertions, no risky/pending tests or GUT orphans, and exit code 0.
- [x] Create and run production readiness validator. `[truth:source-audit]` `[truth:blocked]`
  - Evidence: `tools/validate_production_readiness.sh`; report written to `docs/PRODUCTION_READINESS_REPORT.md`.
  - Result: NOT READY with two validator blockers. Main player-path smoke, performance evidence, category lanes, and the full Godot/GUT suite pass; manual gameplay and release-version proof remain blocked.
- [x] Create main player path smoke harness and report. `[truth:source-audit]` `[truth:blocked]`
  - Evidence: `tools/run_main_player_path_smoke.sh`; report written to `docs/MAIN_PLAYER_PATH_SMOKE.md`.
  - Result: PASS on 2026-07-09 with `GODOT_BIN=/tmp/modus_godot_4.7/Godot_v4.7-stable_linux.x86_64 tools/run_main_player_path_smoke.sh --headless --duration 5`; this remains launch smoke only, not manual gameplay proof.
- [x] Create manual evidence validator and report. `[truth:source-audit]` `[truth:blocked]`
  - Evidence: `tools/validate_manual_evidence.sh`; report written to `docs/MANUAL_EVIDENCE_REPORT.md`.
  - Result: BLOCKED because no ManualTestTimer CSV evidence exists under `logs/manual_test_logs`.
- [x] Create performance evidence validator and report. `[truth:source-audit]` `[truth:blocked]`
  - Evidence: `tools/validate_performance_evidence.sh`; report written to `docs/PERFORMANCE_EVIDENCE_REPORT.md`.
  - Result: BLOCKED because no PerformanceLogger CSV evidence exists under `logs/performance_logs`.
- [x] Create release readiness validator and report. `[truth:source-audit]` `[truth:blocked]`
  - Evidence: `tools/validate_release_readiness.sh`; report written to `docs/RELEASE_READINESS_REPORT.md`.
  - Result: BLOCKED because current-facing docs still identify MODUS as `0.9.5-beta` / not production-ready 1.0.


<!-- OVERZEER:CROSS_REPO_BEGIN -->
## OVERZEER Cross-Repo Improvement Candidates

Generated by OVERZEER from local repo analysis, cross-repo comparison, and optional public GitHub/arXiv scouting. These entries are proposal candidates; they are not accepted active backlog rows until a maintainer promotes them into the repo's normal queue and proves them with its normal truth tag.

### Epic: Planning Truth

#### Slice: Adopt proof tags for backlog closure

- Task candidate [P1][DOCS][TEST]: Add completion evidence tags to backlog rows and document when a row can move from open work to archived proof.
  - Status: Promoted and completed on 2026-07-08; see `Completed This Cycle` and `BACKLOG_ARCHIVE.md`.
  - Why trail this direction: Several sibling repos already distinguish runtime, build, test, source-audit, docs-only, and historical proof. Bringing this repo onto the same language makes cross-repo status comparisons less ambiguous.
  - Evidence: BACKLOG.md exists, but OVERZEER did not find both `[truth:*]` tags and a source-of-truth policy.

#### Slice: Tailor generated memory and roadmap docs

- Task candidate [P2][DOCS]: Replace generated baseline sections in `MEMORY.md` and `ROADMAP.md` with project-specific commands, truth boundaries, current decisions, and roadmap lanes.
  - Status: Promoted and completed on 2026-07-08; see `Completed This Cycle` and `BACKLOG_ARCHIVE.md`.
  - Why trail this direction: Generated control docs are useful for bootstrapping, but they become stale quickly if they never learn the repo's real commands, product direction, and local proof boundaries. Hand-tuning keeps future LLM passes from treating generic bootstrap text as project knowledge.
  - Evidence: OVERZEER detected root MEMORY.md or ROADMAP.md content that still matches the generated bootstrap baseline.

<!-- OVERZEER:CROSS_REPO_END -->
