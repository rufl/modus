# MODUS Documentation

> **Documentation status: maintained reference.** Start with the truth contract and generated readiness reports. Historical files are unvalidated snapshots, not fallback documentation.

**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Readiness:** NOT READY

## Read First

1. [Documentation Truth Contract](DOCUMENTATION_TRUTH.md)
2. [Current Status](CURRENT_STATUS.md)
3. [Production Readiness Report](PRODUCTION_READINESS_REPORT.md)
4. [Ship-Readiness Estimate](SHIP_READINESS_ESTIMATE.md)
5. [Active Backlog](../BACKLOG.md)
6. [Documentation Index](INDEX.md)

## Current Evidence

- [Automated Test Lanes](AUTOMATED_TEST_LANES_REPORT.md)
- [Main Player Path Smoke](MAIN_PLAYER_PATH_SMOKE.md)
- [Showcase Scene Launch Smoke](SHOWCASE_LAUNCH_SMOKE.md)
- [Golden Demo Smoke](GOLDEN_DEMO_SMOKE.md)
- [Manual Evidence](MANUAL_EVIDENCE_REPORT.md)
- [Performance Evidence](PERFORMANCE_EVIDENCE_REPORT.md)
- [Release Readiness](RELEASE_READINESS_REPORT.md)
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

Historical audits, fix logs, session summaries, migration instructions, release drafts, old architecture guides, and subsystem “complete” reports are preserved only for traceability. Their bodies have not been revalidated and may contain wrong paths, APIs, counts, estimates, results, or instructions. Every file in the maintained documentation corpus must carry a maintained, generated, or historical classification.

If historical text conflicts with current source, the truth contract, or a current generated report, the historical text loses.

## Contribution Rule

When changing code or evidence:

1. Update the narrow maintained subsystem reference.
2. Update `docs/CURRENT_STATUS.md` only with current evidence.
3. Refresh generated reports through their validators.
4. Move completed/retired backlog work to `BACKLOG_ARCHIVE.md` with evidence.
5. Run the documentation, project, and runner-manifest truth checks.

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
```
