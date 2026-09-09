# MODUS Performance Baseline Proof

> **Documentation status: maintained reference.** This page preserves dated, focused observations, not fresh proof. Published readiness is consolidated in [Current Status](CURRENT_STATUS.md); generated reports and raw logs remain local-only under the [truth contract](DOCUMENTATION_TRUTH.md).

**Run date:** 2026-07-13
**Recorded status:** PASS (bounded July 13 baseline; not a production target or current checkout result)
**Original local-only capture:** `logs/performance_logs/showcase_baseline_20260713.csv`

The real showcase scene (`res://game/world/maps/showcase.tscn`) was run for 66.4 seconds through `PerformanceLogger` using Godot 4.7, OpenGL compatibility rendering, Wayland, and an Intel Arc A770/Mesa runtime. The validator accepted 130 samples with zero malformed rows.

Measured values: average FPS 1262.31, minimum FPS 1.00, maximum FPS 1555.00, maximum frame time 108.55 ms, and maximum static memory 104.10 MB. The very high FPS indicates an unthrottled capture context and must not replace a display-synchronized user-facing target. The maximum frame-time spike and repeated extreme enemy-position warnings also keep gameplay stability and production performance open for manual/runtime follow-up.

This closes the backlog requirement for a first imported PerformanceLogger baseline and a passing validator. It does not prove 60/75/120 FPS targets, split-screen performance, multiplayer performance, or release readiness.

The original CSV is preserved locally, not committed or available in a fresh clone. This page retains its dated measurement context without claiming new proof. Create a new capture with `godot --path . --script tools/run_performance_evidence_capture.gd`, then run `tools/validate_performance_evidence.sh --strict` to write local `docs/PERFORMANCE_EVIDENCE_REPORT.md`. Review hardware/workload and the new result before updating published status; without a local capture the evidence gate remains missing or blocked. See the [measurement guide](guides/performance_optimization.md).
