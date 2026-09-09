# MODUS Documentation Index

> **Documentation status: maintained reference.** This index separates published references and curated evidence from local-only generated outputs and historical snapshots.

**Updated:** September 9, 2026

## Canonical Current Truth

- [Documentation Truth Contract](DOCUMENTATION_TRUTH.md): publication policy and current headline boundary
- [Current Status](CURRENT_STATUS.md): consolidated current snapshot
- [Ship-Readiness Estimate](SHIP_READINESS_ESTIMATE.md): explicit evidence gateboard and calendar estimate
- [Active Backlog](../BACKLOG.md): open work and current progress
- [Root Roadmap](../ROADMAP.md) and [Product Roadmap](ROADMAP.md): proof sequence and product-area gaps

## Local Reports and Published Evidence

The eight generated reports are ignored local outputs, absent from a fresh clone. See [Regenerating Local Reports](DOCUMENTATION_TRUTH.md#regenerating-local-reports) for output paths, commands, and evidence prerequisites. A fresh report describes only its invocation; old local logs do not certify the current checkout.

- [Performance Baseline Context](PERFORMANCE_BASELINE_PROOF.md)
- [Multiplayer Profile Smoke](MULTIPLAYER_PROFILE_SMOKE.md)
- [ENet Local Host/Join Smoke](ENET_LOCAL_HOST_JOIN_SMOKE.md)
- [Editor Round-Trip Proof](EDITOR_ROUNDTRIP_PROOF.md)
- [Workshop Local Simulation Proof](WORKSHOP_LOCAL_SIMULATION_PROOF.md)
- [Sample Mod Proof](MODDING_SAMPLE_MOD.md)
- [Mod Package Validation](MOD_PACKAGE_VALIDATION.md)
- [Showcase Route](SHOWCASE_ROUTE.md)
- [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)
- [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md)

A PASS applies only to the scope stated in that report. Focused or simulated evidence does not promote the whole project to ready.

## Maintained User and Operator Guides

- [Getting Started](getting_started.md)
- [Troubleshooting](troubleshooting.md)
- [Hardware Requirements](hardware_requirements.md)
- [Console](guides/CONSOLE.md)
- [Modding](guides/MODDING.md)
- [Multiplayer Security](guides/multiplayer_security.md)
- [Performance Evidence Guidance](guides/performance_optimization.md)
- [Manual Player-Experience Checklist](../tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md)
- [Manual Test Timing](../tests/docs/MANUAL_TEST_TIMING.md)
- [Standalone Editor Boundary](../standalone/editor/README.md)
- [Dedicated Server Boundary](../standalone/dedicated/README.md)

## Maintained Architecture and Technical References

- [Architecture Overview](architecture.md)
- [Technical Reference](TECHNICAL_REFERENCE.md)
- [JSON Schemas and Ownership](technical/JSON_SCHEMAS.md)
- [Steam Integration Boundary](technical/STEAM_INTEGRATION.md)
- [Multiplayer Authority Model](MULTIPLAYER_AUTHORITY_MODEL.md)
- [Movement Mechanics Status](MOVEMENT_MECHANICS_STATUS.md)
- [Technical Index](technical/README.md)

## Maintained Subsystem References

- [Map Generator](../game/scripts/map_generator/README.md)
- [Splitscreen Runtime](../game/core/systems/splitscreen/README.md)
- [Splitscreen Integration Tests](../tests/integration/splitscreen/README.md)
- [Splitscreen Unit Tests](../tests/unit/splitscreen/README.md)
- [Splitscreen Property Tests](../tests/property/splitscreen/README.md)
- [Test Inventory](../tests/README.md) and [Test Runners](../tests/runners/README.md)
- [Shared Source Boundary](../shared/README.md)
- [Shader Source Boundary](../shared/shaders/README.md)
- [Maintenance Scripts](../tools/scripts/README.md)

## Licensing and Change History

- [Licensing and Provenance Inventory](ATTRIBUTION.md)
- [Machine-Readable Provenance Ledger](PROVENANCE_LEDGER.csv)
- [Retained Third-Party License Records](licenses/README.md)
- [Root Changelog](../CHANGELOG.md): maintained chronological record; old entries retain their original bounded results
- `docs/CHANGELOG.md` and `docs/RELEASE_NOTES.md`: local-only historical snapshots, not published release evidence

## Historical Documents

Historical files remain byte-for-byte on the originating workstation but are no longer tracked or included in fresh clones. Their bodies have not been revalidated against the current tree. Paths, APIs, scores, counts, estimates, completion claims, test outcomes, and instructions may be wrong or superseded. `BACKLOG_ARCHIVE.md` and `MEMORY.md` are also local-only; public closure summaries belong in the root changelog.

Historical families include:

- `docs/audits/`, `docs/fixes/`, and `docs/newdocs/`;
- phase, cleanup, session, UI-refactor, lessons-learned, and release-draft reports;
- the old manual test plan and testing-profiler guides;
- former component/service architecture and service-registration guides;
- old breakable-prop compatibility/feature claims;
- migration-tool instructions;
- map-generator checkpoint/completion reports and old threading design notes;
- showcase generation/fix summaries beside map scenes;
- shader architecture, quick-start, integration, implementation, index, and changelog documents;
- old runner-fix, type-safety, CI, and UI-audit reports.

This inventory describes historical scope without modifying local-only files. Historical text never overrides live source, the truth contract, or newly reviewed observations. Raw `logs/` and generated reports are local evidence, not published navigation targets; curated `docs/media/` captures and licensing records remain tracked.

## Verification

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
```
