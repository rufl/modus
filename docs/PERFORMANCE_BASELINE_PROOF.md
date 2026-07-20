# MODUS Performance Baseline Proof

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

**Run date:** 2026-07-13
**Status:** PASS (bounded baseline; not a production target)
**Capture:** `logs/performance_logs/showcase_baseline_20260713.csv`

The real showcase scene (`res://game/world/maps/showcase.tscn`) was run for 66.4 seconds through `PerformanceLogger` using Godot 4.7, OpenGL compatibility rendering, Wayland, and an Intel Arc A770/Mesa runtime. The validator accepted 130 samples with zero malformed rows.

Measured values: average FPS 1262.31, minimum FPS 1.00, maximum FPS 1555.00, maximum frame time 108.55 ms, and maximum static memory 104.10 MB. The very high FPS indicates an unthrottled capture context and must not replace a display-synchronized user-facing target. The maximum frame-time spike and repeated extreme enemy-position warnings also keep gameplay stability and production performance open for manual/runtime follow-up.

This closes the backlog requirement for a first imported PerformanceLogger baseline and a passing validator. It does not prove 60/75/120 FPS targets, split-screen performance, multiplayer performance, or release readiness.
