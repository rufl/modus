# MODUS Ship-Readiness Estimate

> **Documentation status: maintained reference.** This is a dated evidence-completeness estimate, not release approval. Published status is consolidated in [Current Status](CURRENT_STATUS.md); regenerate local gate reports using the [truth contract](DOCUMENTATION_TRUTH.md#regenerating-local-reports).

**Estimated:** 2026-08-04
**Target:** a distributable MODUS release with green local gates, craft/slopometer zero, reviewed runtime evidence, and bounded release claims.

## Gateboard

This August 4 estimate counts evidence gates, not lines of code or feature volume. It is retained planning context and has not been recomputed for September repairs or publication cleanup. The gateboard reflects its original observation date, not the current checkout. A yellow gate is half-credit because dated proof existed but needed refreshing; a partial gate is quarter-credit because its inventory existed but most clearance work remained. Raw JSON/logs and generated reports remain local-only; curated screenshots/video stay published.

| Gate | Status | Evidence / remaining proof |
| --- | --- | --- |
| Documentation truth | PASS | `bash tools/check_documentation_truth.sh` and current canonical docs |
| Project and runner truth | PASS | `bash tools/check_project_truth.sh` and `bash tools/check_headless_runner_manifest.sh` |
| Craft / Slopometer / cache hygiene | PASS | Craft penalty `0`; Slopometer `0.0/10`; OVERZEER hygiene `0 B` in the current scan |
| Complete Godot/GUT aggregate | PASS | August 4 `1440/1440`, 20,475 assertions, zero GUT-reported orphans |
| UI surface proof | PASS | UI `26/26`, 109 assertions plus manual recorder/timer `2/2`, 21 assertions; fresh wide/narrow captures |
| Main player-path smoke | PASS | Fresh August 2 Godot 4.7 headless launch smoke |
| Performance evidence | PASS | One bounded `66.4s / 130-sample` capture; broader hardware/mode coverage remains open |
| Golden demo runtime path | PASS | All 8 controlled automated steps pass with retained JSON/log/screenshot/video; manual feel remains separate |
| Manual gameplay evidence | BLOCKED / TOOLING READY | 20-item F8/Gamepad Back recorder and strict active-time validation pass; `0.00` reviewed hours remain against the 40-hour threshold |
| Release version | BLOCKED | Project truth is still `0.9.5-beta`, not `1.0.0` |
| Distribution provenance | PARTIAL | Current 218-row ledger has 174 cleared Quaternius/Kenney/original/known-source assets and 44 unverified rows; private Suno music was removed from the repository |
| External/runtime clearance | OPEN | Real ENet peers, Steam/GodotSteam, live editor UX, Workshop, packaging, and long-session performance remain unproven |

## Estimate

- **Evidence-complete shipping readiness:** approximately **69%** (`8.25 / 12` weighted gates).
- **Source implementation coverage:** materially higher, but intentionally not used as the shipping percentage.
- **Calendar estimate:** **6–9 working days** with manual test hardware, provenance decisions, and external accounts available.
- **Risk range:** **20+ working days** if Steam, provenance, hardware, or multiplayer evidence requires external coordination.

The critical path is not more framework code. It is at least 40 hours of reviewed manual evidence, provenance clearance, real external/runtime checks, release-version promotion, and final packaging/review.

## Approval Rule

Do not call MODUS shipped or approved until all rows are green, the current working tree has a fresh full aggregate and UI capture, and the release bundle links the observed evidence. Craft/slopometer zero is necessary but not sufficient.

## Next Smallest Actions

1. Run `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES` and review its direct CSV output under `logs/manual_test_logs/`.
2. Clear, exclude, or replace the remaining 44 unverified provenance rows and inspect packaged notices.
3. Complete real ENet/editor/packaging checks, then promote the version only when every required lane agrees.
