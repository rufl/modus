# MODUS Hardware Evidence and Requirements

> **Documentation status: maintained reference.** No minimum or recommended shipping specification has been validated. This file records only observed evidence and unproven requirements.

**Updated:** July 13, 2026  
**Version:** `0.9.5-beta`

## Supported Claim

MODUS requires a platform capable of running Godot 4.7 and the project's renderer/physics configuration. The repository does not yet have evidence for a customer-facing minimum, recommended, or optimal hardware specification.

Do not publish CPU, GPU, RAM, storage, player-count, resolution, or FPS requirements from older documentation. Those tables were estimates and included explicitly fabricated examples.

## Recorded Hardware Evidence

The published summary preserves one bounded July 13 showcase observation; its raw CSV remains local-only and is absent from fresh clones:

| Field | Recorded value |
| --- | --- |
| Date | July 13, 2026 |
| GPU | Intel Arc A770 through Mesa |
| Renderer | Godot compatibility renderer |
| Scene | `res://game/world/maps/showcase.tscn` |
| Duration | 66.4 seconds |
| Samples | 130 |
| Maximum frame time | 108.55 ms |
| Maximum process memory | 104.10 MB |

The capture was unthrottled, was not a representative gameplay benchmark, and emitted extreme enemy-position warnings. Its average FPS must not be used as a hardware target or comparative benchmark.

See [Performance Baseline Proof](PERFORMANCE_BASELINE_PROOF.md) for dated context and [capture guidance](guides/performance_optimization.md) for creating new local evidence.

## Unproven Areas

- Display-synchronized solo gameplay
- Splitscreen with real controllers
- Networked multiplayer with real peers
- Dedicated-server capacity
- Integrated GPUs and low-end discrete GPUs
- Windows, macOS, Steam Deck, and non-Mesa Linux configurations
- Long-session memory stability
- Heavy-combat and high-entity-count scenes
- Editor workload and map-generation workload
- Download size, installed size, and mod-storage recommendations
- Bandwidth and latency requirements

## How to Produce Valid Hardware Evidence

Record at least:

1. Commit/build identifier and Godot version.
2. Operating system, renderer, driver, CPU, GPU, RAM, and resolution.
3. Scene/map, game mode, player count, bot/entity count, and quality settings.
4. Capture duration, frame pacing, FPS distribution, memory, and notable warnings.
5. Whether the run was display-synchronized, headless, editor, debug, or export build.
6. Reproduction notes and the raw CSV/log artifact.

Place PerformanceLogger CSVs under `logs/performance_logs/`, review their context, and run:

```bash
tools/validate_performance_evidence.sh --strict
```

The validator writes ignored local output `docs/PERFORMANCE_EVIDENCE_REPORT.md`. Missing local CSVs must remain missing evidence; the historical table above is not a substitute input or a new PASS.

A validator PASS confirms evidence shape and duration only. Product requirements still require reviewed, repeatable runs across the declared support matrix.

## Current Recommendation

Use MODUS for development and evaluation on hardware that already runs Godot 4.7 comfortably. Determine project-specific requirements from your own exported build and content. Do not market the historical estimated tiers as tested specifications.
