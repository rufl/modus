# MODUS Product and Evidence Roadmap

> **Documentation status: maintained reference.** This document expands the root roadmap by product area. It does not promote implementation presence into runtime or release proof.

**Updated:** August 4, 2026
**Current version:** `0.9.5-beta`  
**Current readiness:** NOT READY

## Current Evidence Boundary

- Historical August 4 full suite: 1440/1440 with 20,475 assertions and no risky/pending tests or GUT orphans; not the current-tree suite total.
- That aggregate completed in 702.76 seconds under a bounded 3600-second run, with six engine-exit ObjectDB leak diagnostics.
- Historical category observations: August 1 Unit 1056/1056 and Property 175/175; July 19 Integration 200/200; Benchmark skipped. Local `docs/AUTOMATED_TEST_LANES_REPORT.md` is not committed; regenerate it with `./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md`.
- Earlier source-shape/resource/editor-registry proof recorded 37/37 with 172 assertions and zero GUT orphans. September 9 focused repair observations now cover the four formerly missing loot-prop scenes; see [Current Status](CURRENT_STATUS.md).
- Manual gameplay: 0 imported evidence files / 0.00 recorded hours.
- Performance: one bounded 66.4-second, 130-sample showcase capture; production targets remain unproven.
- Release: blocked at `0.9.5-beta`.
Published readiness remains NOT READY. The two-validator-blocker snapshot covers manual evidence and release version only; 69 of the current 218 provenance-ledger rows remain unverified. Local-only raw evidence and generated outputs do not certify a fresh clone; see [report regeneration](DOCUMENTATION_TRUTH.md#local-only-retention).

See [Documentation Truth](DOCUMENTATION_TRUTH.md) and [Current Status](CURRENT_STATUS.md) for details.

## Core Framework

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| GameManager services | Implemented with broad focused coverage | Clean aggregate lifecycle/order behavior |
| Data/config ownership | Implemented and reference-tested | Keep schemas and mod override examples synchronized |
| Save system | Focused tests pass | Manual save/load/corruption observation |
| Events/components/features | Implemented with focused tests | Aggregate suite stability and user-flow evidence |

## Gameplay and Showcase

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| Movement/combat/weapons/enemies | Eight-step automated golden-demo runtime smoke passes; 20-item F8 human recorder workflow is ready | Reviewed human feel, failure recovery, and tuning observations |
| Showcase | Structure tests pass; localized gamepad-ready welcome/evidence panel is focused-proven and captured at wide/narrow resolutions | Manual gameplay route, video, and issue log |
| AI/navigation | Focused tests pass in several lanes | Real map behavior, stress, and long-session stability |
| Splitscreen | Manager/gameplay/stress contracts pass | Real controllers, viewport/UI, audio, and performance evidence |

## Networking

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| ENet/profile startup | Profile startup and September focused real-ENet lifecycle/inventory/late-join checks have dated proof | Reviewed end-to-end sessions, latency/reconnect behavior, and dedicated clients |
| Authority/security | Validation, whitelist, and rate-limit code exist | Adversarial live-client and latency tests |
| Dedicated server | Headless/config paths exist | Real client/server session evidence |
| Lag compensation | Shared RTT-bounded player/enemy rewind and combat integration; focused physics/weapon proof passes | Client-view/interpolation calibration and representative high-latency sessions |
| Steam/GodotSteam | Conditional structures exist | Authenticated client/app/API proof |

## Editor, Mods, and Workshop

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| Main menu and mod workflow | Artwork/showcase/help/responsive/focus/version/welcome/mod/skill-tree contracts pass 26/26 with 109 assertions; recorder/timer passes 2/2 with 21 assertions and a compact 800×600 capture | Run and review the manual menu/input observations |
| Level serialization/export | Focused round-trip passes | Live editor UI authoring workflow |
| Standalone undo/redo | Runtime-safe block placement now uses the shared editor fallback and supports place/undo/redo in focused proof; other standalone command paths remain | Complete and exercise remaining authoring commands |
| Mod loader/SDK | Focused integration/sample proof passes | Distribution packaging and multiplayer behavior |
| Workshop | Local simulation passes | Real Steam upload/download/browse/subscription |

## Map Generator

| Area | Source status | Required proof/hardening |
| --- | --- | --- |
| Core unit directory | 79/79 focused tests pass | Aggregate suite and broader generated-map behavior |
| Export | 10/10 focused tests pass with zero GUT orphans | Preserve focused lifecycle proof while repairing wider-suite failures |
| Seed/RNG | 8/8 focused tests pass | Preserve determinism across full pipeline changes |
| Threaded pipeline | 8/8 focused tests pass with 30 assertions and zero GUT orphans | Preserve serialization/lifecycle coverage in aggregate repairs |

Historical “all tasks complete” map-generator notes are implementation snapshots, not current production proof.

## Performance and Release

1. Capture display-synchronized solo gameplay.
2. Capture splitscreen and multiplayer sessions with player count/map/build context.
3. Test at least one lower-end target and one long session.
4. Review spikes, memory, gameplay anomalies, and teardown leaks—not only average FPS.
5. Build/package supported targets and produce a known-limits matrix.
6. Clear, exclude, or replace all remaining unverified provenance rows and inspect packaged notices.
7. Promote release wording only after all readiness validators and distribution-clearance checks agree.

## Exit Criteria for a 1.0 Candidate

- Complete filtered Godot/GUT suite at an accepted documented boundary.
- Complete batched lane summaries with no hidden/incomplete runner result.
- Reviewed manual evidence for the maintained golden-demo route.
- Contextualized performance evidence for declared supported modes/hardware.
- Proven multiplayer and packaging scope.
- Current docs contain no project-wide claims stronger than the evidence.
- `tools/validate_production_readiness.sh --run-godot-tests --strict` passes.
- `tools/generate_provenance_ledger.py --strict` passes and packaged notices are inspected.
