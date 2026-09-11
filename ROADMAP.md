# MODUS Roadmap

> **Documentation status: maintained reference.** This roadmap prioritizes proof and hardening. Current status is defined by `docs/DOCUMENTATION_TRUTH.md` and `docs/CURRENT_STATUS.md`.

**Updated:** September 11, 2026
**Current version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Readiness:** NOT READY

## North Star

Make MODUS a dependable Godot 4.7 FPS framework whose public claims are backed by live source, focused automated contracts, complete aggregate test runs, runtime observation, manual evidence, and contextualized performance captures.

## Now: Maintain the Verified Baseline

1. Preserve the September 10 refreshed aggregate: 1,568/1,568 tests with 21,718 assertions across 135 scripts; two GUI-required files remain skipped.
2. Preserve zero GUT orphans in focused lanes while reducing service-initialization and engine-exit diagnostics without weakening assertions.
3. Keep maintained status, known limits, active backlog, and root changelog synchronized. Generated reports and raw logs remain local-only; completed work belongs in the published root changelog.

The current baseline includes the eight-step golden-demo smoke, responsive manual recorder, focused editor history/productization proof, local ENet lifecycle proof, authenticated local GodotSteam initialization, refreshed package-notice/export checks, and a reproducible Linux desktop export smoke. These are bounded observations, not production or release approval.

Historical August and July totals remain below only as dated context. They must not be reused as current-tree totals.

## Next: Runtime and Manual Proof

1. Run `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES` in a normal Godot window.
2. Use F8 to record the 20-item menu, Showcase, movement, combat, interaction, HUD, save/load, accessibility, and log-review route; automated interaction with the recorder does not count as manual gameplay.
3. Review the directly exported CSV evidence and rerun `tools/validate_manual_evidence.sh --strict`.
4. Exercise the embedded and standalone editor UI, including save/export/reload and known undo/redo boundaries; the main-menu responsive/focus pass is complete but does not prove the full editor workflow.
5. Record display-synchronized solo and splitscreen performance with hardware/build context.

Completion requires reviewed evidence, not merely available harnesses.

## Then: Multiplayer and External Integrations

1. Extend the September focused local real-ENet lifecycle/inventory/late-join proof into reviewed end-to-end multiplayer sessions; older socket-sandbox failures are historical boundaries.
2. Exercise reconnect, authority validation, RPC rate limits, and representative combat under latency.
3. Validate the integrated RTT-bounded hitscan rewind against client-view/interpolation timing and representative high-latency sessions; focused server physics and weapon proof now passes.
4. Prove real GodotSteam startup and Workshop operations with a running Steam client, app ID, and authorized account.
5. Test the dedicated-server path with real clients and recorded configuration.

ENet fallback, local filesystem simulation, and Steam-unavailable handling are separate evidence states.

## Productization After Proof

- Standalone Undo/Redo now routes through the shared runtime history manager, and the standalone File/Edit/View/Help menus provide selection actions, maintained local guidance, stateful view toggles, and `.mdsl` export through the existing LevelPackager. Native exported-app and full graphical proof remain required.
- Focused mod packaging and local Workshop behavior are documented as a `.mdsl` distribution workflow; real Steam publication remains blocked.
- Advanced brush geometry and density-aware fill are implemented and focused-tested; native visual/editor workflow proof remains separate.
- Provenance is complete for the current 218-row ledger: 218 cleared and 0 unverified. A local Linux desktop artifact now builds and launches through bounded smoke; installer definition/toolchain, target-Windows runtime, and external distribution proof remain open.
- Add contextualized benchmark tables for supported hardware/build profiles.
- Review the completed evidence index and replace automated-only media with approved manual marketing captures where required.
- Promote version/release wording only after automated, manual, performance, packaging, and distribution-clearance gates agree.

## Deferred Exploration

- Broader AI behavior validation and level-design tuning.
- Matchmaking, public-service deployment, replay tooling beyond local match replay, and wider platform packaging.
- Additional procedural-generation features after current thread/lifecycle cleanup.
- Expanded mod/editor UX after core authoring and distribution flows are proven.

## Gates

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
tools/validate_manual_evidence.sh --strict
tools/validate_performance_evidence.sh --strict
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```

Generated report paths above are ignored local outputs, not checkout inputs. See [report regeneration](docs/DOCUMENTATION_TRUTH.md#regenerating-local-reports) for commands and evidence prerequisites.

Temporary `GODOT_BIN` paths are workstation conveniences. The maintained requirement is Godot 4.7+, not any particular local path.
