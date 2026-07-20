# MODUS Roadmap

> **Documentation status: maintained reference.** This roadmap prioritizes proof and hardening. Current status is defined by `docs/DOCUMENTATION_TRUTH.md` and `docs/CURRENT_STATUS.md`.

**Updated:** July 19, 2026  
**Current version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Readiness:** NOT READY

## North Star

Make MODUS a dependable Godot 4.7 FPS framework whose public claims are backed by live source, focused automated contracts, complete aggregate test runs, runtime observation, manual evidence, and contextualized performance captures.

## Now: Preserve the Automated Baseline

1. Preserve the green July 19 category packet: Unit 1056/1056, Integration 200/200, and Property 175/175.
2. Preserve the green strict aggregate at 1431/1431 with 20,362 assertions and no risky/pending tests.
3. Preserve zero GUT orphans while reducing service-initialization and engine-exit diagnostic volume without weakening assertions.
4. Preserve the July 17 zero-orphan focused map-generator threading/export boundary.
5. Keep documentation truth, generated reports, backlog, and archive classification synchronized.

The automated baseline is complete; runtime/manual evidence is now the release-critical path.

## Next: Runtime and Manual Proof

1. Execute the maintained showcase/golden-demo route in a normal Godot window.
2. Record menu, world load, movement, combat, interaction, HUD, save/load, and failure observations.
3. Import ManualTestTimer CSV evidence and rerun `tools/validate_manual_evidence.sh --strict`.
4. Exercise the embedded and standalone editor UI, including save/export/reload and known undo/redo boundaries.
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
- Complete third-party code/asset provenance and retain required licenses/notices before redistribution.
- Add contextualized benchmark tables for supported hardware/build profiles.
- Build a release evidence bundle with screenshots/video tied to the maintained showcase route.
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
./tests/runners/run_all_tests_headless.sh
./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md
tools/validate_manual_evidence.sh --strict
tools/validate_performance_evidence.sh --strict
tools/validate_release_readiness.sh --strict
tools/validate_production_readiness.sh --run-godot-tests --strict
```

Temporary `GODOT_BIN` paths are workstation conveniences. The maintained requirement is Godot 4.7+, not any particular local path.
