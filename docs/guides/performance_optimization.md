# Performance Measurement and Tuning

> **Documentation status: maintained reference.** No hardware tier, splitscreen FPS target, or optimization gain is certified by this guide. Published context is in [Performance Baseline Proof](../PERFORMANCE_BASELINE_PROOF.md); generated validation reports describe local invocations only.

## Recorded evidence boundary

The July 13 showcase capture, `logs/performance_logs/showcase_baseline_20260713.csv`, is local-only and absent from a fresh clone. The maintained summary records:

- 66.4 seconds;
- 130 samples;
- unthrottled execution;
- one 1-FPS sample and a 108.55 ms maximum frame-time sample;
- observed extreme enemy-position warnings during the route.

The strict evidence validator passed for that capture's duration and structure. Its 1262.31 average FPS is not a production target or representative hardware promise. Historical measurements do not make a fresh checkout's evidence validator pass.

## Capture a baseline

Use the maintained capture path:

```bash
godot --path . --script tools/run_performance_evidence_capture.gd
tools/validate_performance_evidence.sh --strict
```

The capture writes local CSV evidence under `logs/performance_logs/`; the validator writes ignored local output `docs/PERFORMANCE_EVIDENCE_REPORT.md`. Missing captures remain missing evidence. Review the actual new result rather than assuming the recorded baseline still applies.

For publishable evidence, record:

- exact CPU, GPU, RAM, OS, driver, renderer, and resolution;
- build/commit identity;
- map, player count, enemy count, and workload;
- VSync/frame-cap settings;
- warm-up and measurement duration;
- average, percentile, minimum, maximum, and frame-time spike data;
- visible/runtime warnings.

Do not compare captures with different workloads as if they were the same benchmark.

## Live tuning surfaces

| Surface | Current path |
| --- | --- |
| General performance settings | `game/config/performance/system.json5` |
| Graphics settings | `game/config/performance/graphics.json5` |
| Visual settings | `game/config/performance/visuals.json5` |
| Debug settings | `game/config/performance/debug.json5` |
| Performance feature code | `game/scripts/features/performance/` |
| Performance logger | `tests/manual/performance_logger.gd` |
| Benchmark test code | `tests/benchmarks/test_performance_benchmarks.gd` |

Configuration presence does not prove that every value is consumed in every profile. Confirm call sites before documenting a tuning knob.

## Existing optimization code

The tree contains pooling, LOD, hardware-detection, quality, and monitoring code under feature and effects directories. Focused tests exercise portions of these systems. There is no current evidence supporting the old claims of fixed “+15–40 FPS” gains, specific GPU tiers, 100-enemy scalability, or guaranteed splitscreen targets.

When changing an optimization:

1. identify the exact source and configuration consumer;
2. add or update a focused behavior test;
3. capture the same workload before and after;
4. report regressions and warnings, not just the average;
5. keep hardware generalization open until the matrix exists.

## Headless limits

Headless GUT performance/property tests can detect algorithmic regressions or enforce bounded timing contracts. They cannot establish rendered GPU performance, visual quality, driver compatibility, frame pacing under a real window, or input latency.

## Release boundary

A production performance claim requires repeated graphical captures across the supported hardware/OS matrix. One local A770/Mesa capture is useful evidence, but it does not define minimum or recommended hardware requirements.
