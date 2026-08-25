# MODUS Documentation Truth Contract

> **Documentation status: maintained reference.** This file defines how present-tense claims are published. Generated reports remain authoritative for their individual gates.

**Audited:** August 4, 2026
**Version:** `0.9.5-beta`  
**Engine:** Godot 4.7+  
**Overall readiness:** **NOT READY**

## Canonical Current Sources

Use these files in this order when documents disagree:

1. `docs/PRODUCTION_READINESS_REPORT.md` for the current release boundary and blocker count.
2. `docs/CURRENT_STATUS.md` for the consolidated implementation and evidence snapshot.
3. `docs/AUTOMATED_TEST_LANES_REPORT.md` and `logs/full_godot_gut_latest.log.gz` for automated-test boundaries.
4. `docs/MANUAL_EVIDENCE_REPORT.md`, `docs/PERFORMANCE_EVIDENCE_REPORT.md`, and `docs/RELEASE_READINESS_REPORT.md` for their individual gates.
5. `BACKLOG.md` for open work and `BACKLOG_ARCHIVE.md` for completed or retired work.

Historical audits, completion notes, old fix logs, release drafts, and subsystem checkpoint reports are not current evidence.

## Current Verified Boundary

| Area | Current truth |
| --- | --- |
| Engine/version | Godot 4.7+, project version `0.9.5-beta` |
| Autoloads | 2: `GameManager` and `MapGenerator` |
| Test inventory | 71 unit files, 18 integration files, 29 property files, 2 GUI-required manifest entries |
| Current complete full suite | PASS: 1440/1440 passing, 20,475 assertions, no risky/pending tests, zero GUT-reported orphans (August 4, 2026) |
| Latest strict aggregate attempt | PASS/complete: the August 4 run finished in 702.76 seconds under a bounded 3600-second run and retained a full aggregate summary; six engine-exit ObjectDB leak diagnostics remain |
| Latest batched lanes | PASS: August 1 Unit 1056/1056 and Property 175/175; July 19 Integration 200/200 retained; Benchmark is skipped |
| Craft / Slopometer | PASS: Craft penalty 0 and MODUS 0.0/10; proof recorded in `.overzeer/proof-results.md` |
| Launch smoke | Fresh August 2 main-menu and world-scene smokes PASS for startup scope only; they do not prove spawned-player gameplay actions |
| Manual gameplay | BLOCKED: the 20-item F8 recorder and strict metadata/active-time validator are ready, but 0 reviewed CSV files and 0.00 validated hours exist |
| Performance evidence | PASS for one bounded 66.4-second, 130-sample showcase capture; not a production FPS claim |
| Release-version gate | BLOCKED while current truth remains `0.9.5-beta` |
| Production readiness | NOT READY with 2 validator-tracked blockers: manual gameplay evidence and release-version readiness. This count is not legal/distribution clearance; 212 of 220 ledgered assets still require rights review. |
| Multiplayer runtime | Profile launch passes; two-peer ENet host/join is blocked by sandbox socket creation; real Steam/GodotSteam is unproven |
| Workshop | Local filesystem simulation passes; real Steam Workshop upload/download is blocked |
| UI/editor | Main-menu/showcase/mod-manager/skill-tree structure and accessibility pass 26/26 with 109 assertions; the test-only manual recorder adds focused 2/2 proof, a compact 800×600 layout, direct CSV export, and F8 gameplay/review handoff; live complete editor UI and authoring workflow remain unproven |
| Map generator | Focused unit/threading/export/seed/map-playability lanes pass; July 17 threading and export runs report zero GUT orphans; the aggregate suite is green, while manual/release readiness remains open |
| Release evidence | `docs/RELEASE_EVIDENCE_BUNDLE.md` links the source-bounded known-limits matrix and 220-row provenance ledger; gameplay screenshots/video, manual CSV evidence, and clearance of 212 ledger rows remain open |
| Ship estimate | `docs/SHIP_READINESS_ESTIMATE.md` records a bounded 69% evidence-completeness estimate and a 6–9 working-day minimum path; it is not a release approval |

## Documentation Classes

### Maintained Reference

A maintained reference describes a live subsystem, workflow, command, or current project boundary. Its subsystem details must match source. Any project-wide readiness or test-total claim must defer to the canonical current sources above.

### Generated Evidence

Generated reports describe one validator invocation. A PASS applies only to that validator's scope. For example, the performance evidence validator confirms a sufficiently long CSV capture; it does not prove stable gameplay or target hardware performance.

### Historical Snapshot

A historical snapshot preserves an audit, implementation checkpoint, fix session, draft release note, old instruction set, or previous test result. Its body is not revalidated during classification and may contain wrong or superseded paths, APIs, counts, estimates, outcomes, and instructions. It must carry the historical-snapshot banner and must never be used as current evidence.

## Claim Rules

- “Implemented” means a live source path exists; it does not imply runtime or UX proof.
- “Tested” must name the test or report and its observed result.
- “Runtime proof” must identify the launched scene/path and observed behavior.
- “Manual proof” requires imported manual evidence and reviewed observations.
- “Performance proof” must state hardware, renderer, duration, and exclusions.
- “Steam proof” requires GodotSteam, a running Steam client, an app ID, authorization, and a real API result.
- “Production ready,” “release ready,” and “complete” are prohibited as project-wide present-tense claims while the production report is NOT READY.
- A subsystem may be called complete only when the scope is explicit and current proof is linked.

## Verification

```bash
bash tools/check_documentation_truth.sh
bash tools/check_project_truth.sh
bash tools/check_headless_runner_manifest.sh
tools/generate_provenance_ledger.py --check
GODOT_BIN=/path/to/godot-4.7 \
  bash tools/validate_production_readiness.sh
```

Set `GODOT_BIN` to an available Godot 4.7 binary when it is not on PATH; temporary workstation paths are not repository dependencies.
