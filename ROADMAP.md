# MODUS Roadmap

> **Documentation status: maintained reference.** This roadmap prioritizes proof and hardening. Current status is defined by `docs/DOCUMENTATION_TRUTH.md` and `docs/CURRENT_STATUS.md`.

**Updated:** August 4, 2026
**Current version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Readiness:** NOT READY

## North Star

Make MODUS a dependable Godot 4.7 FPS framework whose public claims are backed by live source, focused automated contracts, complete aggregate test runs, runtime observation, manual evidence, and contextualized performance captures.

## Now: Preserve the Automated Baseline

1. Preserve the green automated packet: August 1 Unit 1056/1056 and Property 175/175, plus retained July 19 Integration 200/200.
2. Preserve the green August 4 strict aggregate at 1440/1440 with 20,475 assertions and no risky/pending tests.
3. Preserve zero GUT orphans while reducing service-initialization and engine-exit diagnostic volume without weakening assertions.
4. Preserve the July 17 zero-orphan focused map-generator threading/export boundary.
5. Keep documentation truth, generated reports, backlog, and archive classification synchronized.

The August 3 batch adds the eight-step golden-demo runtime smoke, repairs save-slot/ammo restoration and score-key normalization, fixes disabled-mod activation and skill-tree compatibility, and rebuilds the mod manager as a responsive localized workflow. The August 4 follow-up adds a responsive test-only F8 recorder for 20 bounded human observations, direct metadata-rich CSV export, and validator enforcement that excludes idle recorder overhead. Automated recorder/timer proof is 2/2 with 21 assertions; no human pass is implied.

The automated baseline and manual capture workflow are complete; reviewed runtime evidence is now the release-critical path.

## Next: Runtime and Manual Proof

1. Run `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES` in a normal Godot window.
2. Use F8 to record the 20-item menu, Showcase, movement, combat, interaction, HUD, save/load, accessibility, and log-review route; automated interaction with the recorder does not count as manual gameplay.
3. Review the directly exported CSV evidence and rerun `tools/validate_manual_evidence.sh --strict`.
4. Exercise the embedded and standalone editor UI, including save/export/reload and known undo/redo boundaries; the main-menu responsive/focus pass is complete but does not prove the full editor workflow.
5. Record display-synchronized solo and splitscreen performance with hardware/build context.

Completion requires reviewed evidence, not merely available harnesses.

## Then: Multiplayer and External Integrations

1. Prove two-peer ENet host/join outside the restricted socket sandbox.
2. Exercise reconnect, authority validation, RPC rate limits, and representative combat under latency.
3. Integrate or explicitly retire the remaining combat lag-compensation TODO.
4. Prove real GodotSteam startup and Workshop operations with a running Steam client, app ID, and authorized account.
5. Test the dedicated-server path with real clients and recorded configuration.

ENet fallback, local filesystem simulation, and Steam-unavailable handling are separate evidence states.

## Productization After Proof

- Harden the editor's standalone undo/redo workflow.
- Turn focused mod packaging and local Workshop behavior into a documented distribution workflow.
- Clear, exclude, or replace the 212 non-cleared rows in the generated provenance ledger; verified Kenney CC0 and dip000 MIT notices are already retained.
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

Temporary `GODOT_BIN` paths are workstation conveniences. The maintained requirement is Godot 4.7+, not any particular local path.
