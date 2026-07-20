# MODUS Documentation Truth Contract

> **Documentation status: maintained reference.** This file defines how present-tense claims are published. Generated reports remain authoritative for their individual gates.

**Audited:** July 19, 2026  
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
| Test inventory | 70 unit files, 18 integration files, 29 property files, 2 GUI-required manifest entries |
| Retained complete full suite | PASS: 1431/1431 passing, 20,362 assertions, no risky/pending tests, zero GUT-reported orphans (July 19, 2026) |
| Latest strict aggregate attempt | PASS/complete: the July 19 run finished in 1770.186 seconds under a 2400-second evidence ceiling and retained a full aggregate summary |
| Latest batched lanes | PASS: July 19 Unit 1056/1056, Integration 200/200, and Property 175/175; Benchmark is skipped |
| Launch smoke | PASS for startup/launch-path scope only |
| Manual gameplay | BLOCKED: 0 imported CSV files and 0.00 recorded hours |
| Performance evidence | PASS for one bounded 66.4-second, 130-sample showcase capture; not a production FPS claim |
| Release-version gate | BLOCKED while current truth remains `0.9.5-beta` |
| Production readiness | NOT READY with 2 validator-tracked blockers: manual gameplay evidence and release-version readiness. This count is not legal/distribution clearance; third-party provenance remains incomplete. |
| Multiplayer runtime | Profile launch passes; two-peer ENet host/join is blocked by sandbox socket creation; real Steam/GodotSteam is unproven |
| Workshop | Local filesystem simulation passes; real Steam Workshop upload/download is blocked |
| Editor | Focused save/export/reload and 37/37 source-shape/registry contracts pass; live editor UI and complete authoring workflow remain unproven |
| Map generator | Focused unit/threading/export/seed/map-playability lanes pass; July 17 threading and export runs report zero GUT orphans, while aggregate readiness remains open |

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
GODOT_BIN=/path/to/godot-4.7 \
  bash tools/validate_production_readiness.sh
```

Set `GODOT_BIN` to an available Godot 4.7 binary when it is not on PATH; temporary workstation paths are not repository dependencies.
