# MODUS Documentation

> **Documentation status: maintained reference.** Start with the published truth contract and consolidated status. Generated reports and historical files are local-only, not prerequisites for reading a fresh clone.

**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Readiness:** NOT READY

## Read First

1. [Documentation Truth Contract](DOCUMENTATION_TRUTH.md)
2. [Current Status](CURRENT_STATUS.md)
3. [Ship-Readiness Estimate](SHIP_READINESS_ESTIMATE.md)
4. [Active Backlog](../BACKLOG.md)
5. [Documentation Index](INDEX.md)

## Evidence and Regeneration

Generated reports and raw logs are ignored local outputs, not committed evidence links. [Regenerating Local Reports](DOCUMENTATION_TRUTH.md#regenerating-local-reports) lists all eight report paths, commands, and prerequisites. Missing manual/performance inputs on a fresh clone remain missing evidence, not a historical PASS.

Published context and curated artifacts:

- [ENet Host/Join](ENET_LOCAL_HOST_JOIN_SMOKE.md)
- [Editor Round Trip](EDITOR_ROUNDTRIP_PROOF.md)
- [Workshop Local Simulation](WORKSHOP_LOCAL_SIMULATION_PROOF.md)
- [Sample Mod and Package Validation](MODDING_SAMPLE_MOD.md)
- [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)
- [Known-Limits Matrix](KNOWN_LIMITS_MATRIX.md)
- [Provenance Inventory and Ledger](ATTRIBUTION.md)

## Maintained References

- [Getting Started](getting_started.md)
- [Architecture](architecture.md)
- [Technical Reference](TECHNICAL_REFERENCE.md)
- [JSON/Data Ownership](technical/JSON_SCHEMAS.md)
- [Testing Inventory](../tests/README.md)
- [Test Runners](../tests/runners/README.md)
- [Manual Test Checklist](../tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md)
- [Modding](guides/MODDING.md)
- [Console](guides/CONSOLE.md)
- [Troubleshooting](troubleshooting.md)
- [Hardware Requirements](hardware_requirements.md)
- [Roadmap](ROADMAP.md)
- [Full Index](INDEX.md)

## Historical Material

Historical audits, fix logs, session summaries, migration instructions, release drafts, old architecture guides, `BACKLOG_ARCHIVE.md`, and subsystem “complete” reports remain byte-for-byte on the originating workstation but are untracked and absent from fresh clones. `MEMORY.md`, agent state, and raw `logs/` are also local-only. Historical bodies are not revalidated and may contain wrong paths, APIs, counts, estimates, results, or instructions. Maintained references retain their classification; do not rewrite local-only files to add banners or repair obsolete links.

Historical text never overrides current source or reviewed observations. Curated media, licenses, maintained status/known-limits, active backlog/roadmaps, and the root changelog remain published. See the [publication policy](DOCUMENTATION_TRUTH.md#local-only-retention) for retention and evidence boundaries.

## Contribution Rule

When changing code or evidence:

1. Update the narrow maintained subsystem reference.
2. Update `docs/CURRENT_STATUS.md` with dated observations and explicit exclusions, not unexecuted commands or old local PASS results.
3. Refresh generated reports through their validators; keep reports and raw evidence local. Publish reviewed conclusions in maintained docs.
4. Record completed/retired backlog work and its proof boundary in root `CHANGELOG.md` before removing it from the active queue. An optional local `BACKLOG_ARCHIVE.md` is not the public closure record.
5. Run the documentation, project, and runner-manifest truth checks.

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
```
