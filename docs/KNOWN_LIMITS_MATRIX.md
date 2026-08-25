# MODUS Known-Limits Matrix

> **Documentation status: maintained reference.** This matrix is a release-communication aid. It does not promote any source-backed or automated result into runtime, manual, multiplayer, or distribution proof.

**Updated:** 2026-08-04
**Canonical sources:** [Documentation Truth](DOCUMENTATION_TRUTH.md), [Current Status](CURRENT_STATUS.md), and [Production Readiness](PRODUCTION_READINESS_REPORT.md)

| Area | Verified boundary | Not verified / release limitation | Evidence |
| --- | --- | --- | --- |
| Automated tests | Current August 4 filtered Godot/GUT aggregate is 1440/1440 with 20,475 assertions and zero GUT-reported orphans | Seven warnings, 31 deprecations, and six ObjectDB shutdown leaks remain diagnostic debt | `logs/full_godot_gut_latest.log.gz` |
| UI route | Showcase entry, hero artwork, focus loop, responsive containment, visible version, forms, welcome panel, mod manager, and skill tree pass 26/26; the manual recorder passes 2/2 with wide/narrow captures | Normal-window input feel remains manual-proof work | `tests/unit/test_ui_system.gd`, `tests/unit/test_manual_evidence.gd`, `RELEASE_EVIDENCE_BUNDLE.md` |
| Runtime gameplay | The golden-demo smoke passes scene load, player spawn, movement input, weapon fire, enemy defeat, pickup collection, encrypted save/load, and bundled sample-mod loading | Gameplay feel, failure recovery, long sessions, and human-operated completion are not manual-proven | `GOLDEN_DEMO_SMOKE.md`, `SHOWCASE_ROUTE.md` |
| Manual evidence | Responsive 20-item recorder, direct CSV export, required metadata, Fail/Skip notes, and active-time validation are ready | Reviewed CSV count is 0 and validated manual hours are 0.00; the configured threshold is 40 hours | `MANUAL_EVIDENCE_REPORT.md`, `../tests/docs/MANUAL_TEST_TIMING.md` |
| Performance | One bounded showcase capture passes evidence-shape validation at 66.4 seconds and 130 samples | It is not a display-synchronized FPS target; splitscreen, multiplayer, low-end hardware, and long-session behavior remain open | `PERFORMANCE_EVIDENCE_REPORT.md`, `PERFORMANCE_BASELINE_PROOF.md` |
| Multiplayer | Profile startup and local simulation paths exist; focused contracts are green | Two-peer ENet is sandbox-blocked; real Steam/GodotSteam, latency behavior, reconnect, and dedicated-server clients are unproven | `MULTIPLAYER_PROFILE_SMOKE.md`, `ENET_LOCAL_HOST_JOIN_SMOKE.md` |
| Editor | Save/export/reload and local Workshop simulation contracts pass | Live embedded/standalone UI operation, custom undo/redo, and real Workshop transfer remain open | `EDITOR_ROUNDTRIP_PROOF.md`, `WORKSHOP_LOCAL_SIMULATION_PROOF.md` |
| Modding | Sample SDK and package validation contracts pass | Distribution packaging, live multiplayer synchronization, and real Workshop publication are unproven | `MODDING_SAMPLE_MOD.md`, `MOD_PACKAGE_VALIDATION.md` |
| Content scope | Broad gameplay/map source exists and canonical paths are tested | Vase, corpse-pile, hidden-stash, and weapon-rack loot scenes remain missing if those enum types stay in scope | `CURRENT_STATUS.md`, `BACKLOG.md` |
| Distribution | Root/project/GUT notices, verified Kenney CC0 records, dip000 MIT records, and a deterministic 220-row ledger are retained | Twelve identified music tracks and 200 unverified assets remain uncleared; packaged notice inclusion is source-configured but not export-proven | `ATTRIBUTION.md`, `PROVENANCE_LEDGER.csv` |
| Release version | Current truth is explicitly `0.9.5-beta` | 1.0.0 release-version gate is blocked until all required proof lanes agree | `RELEASE_READINESS_REPORT.md` |

## Approval Rule

Use this matrix beside the release evidence bundle. Do not describe MODUS as shipped, production-ready, or fully approved while any row has an open limitation.
