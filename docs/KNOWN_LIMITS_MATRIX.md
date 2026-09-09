# MODUS Known-Limits Matrix

> **Documentation status: maintained reference.** This matrix is a release-communication aid. It does not promote any source-backed or automated result into runtime, manual, multiplayer, or distribution proof.

**Updated:** 2026-09-09
**Canonical sources:** [Documentation Truth](DOCUMENTATION_TRUTH.md), [Current Status](CURRENT_STATUS.md), and [Release Evidence Bundle](RELEASE_EVIDENCE_BUNDLE.md)

Results below summarize dated observations, not a fresh run. Raw `logs/` and generated report paths in code spans are local-only and absent from fresh clones. See [report regeneration](DOCUMENTATION_TRUTH.md#regenerating-local-reports) for all commands and prerequisites; published summaries preserve historical scope without guaranteeing missing local inputs or a new PASS.

| Area | Verified boundary | Not verified / release limitation | Evidence |
| --- | --- | --- | --- |
| Automated tests | The retained August 4 snapshot records 1440/1440 tests with 20,475 assertions and zero GUT-reported orphans; it is historical evidence, not the current suite total | That snapshot records seven warnings, 31 deprecations, and six ObjectDB shutdown leaks; focused regressions do not refresh a full-suite boundary | [Published history](../CHANGELOG.md); local-only original `logs/full_godot_gut_latest.log.gz`; rerun `./tests/runners/run_all_tests_headless.sh` for new logs |
| CI/CD repair | Stock Godot 4.7.2/GUT 9.7.1 passes 95 focused tests/633 assertions, including the 21 cases from failed run `34350061062`; fresh import and Linux resource export pass with all seven notices | Hosted CI and executable/platform matrix remain unrerun; local proof is not a green GitHub run or a deployment | `../.github/workflows/ci.yml`, `../tools/scripts/install-gut.sh`, `../tests/README.md`, `../CHANGELOG.md` |
| Audio shutdown | The pinned Godot 4.7.2 audio-server patch compiles; the no-autoload immediate-stop regression passes without retained MP3/playback instances, and the patched gameplay smoke exits without shutdown retention | Requires the patched engine; stock `ed1daf0bf` still fails the regression. No claim of an upstream merge or released fix | `../tools/godot/audio-server-shutdown.patch`, `../tools/godot/build.sh`, `../tests/runners/test_audio_shutdown.sh` |
| UI route | Main-menu warrior artwork has been removed; the procedural 3D background remains. Focused headless menu regression passed after removal | Rendered appearance and normal-window input feel remain manual-proof work; older wide/narrow captures predate artwork removal | `tests/unit/test_ui_system.gd`, `tests/unit/test_manual_evidence.gd`, `../CHANGELOG.md`, `RELEASE_EVIDENCE_BUNDLE.md` |
| Runtime gameplay | The golden-demo smoke passes scene load, player spawn, movement input, weapon fire, enemy defeat, pickup collection, encrypted save/load, and bundled sample-mod loading | Gameplay feel, failure recovery, long sessions, and human-operated completion are not manual-proven | `GOLDEN_DEMO_SMOKE.md`, `SHOWCASE_ROUTE.md` |
| Manual evidence | Responsive 20-item recorder, direct CSV export, required metadata, Fail/Skip notes, and active-time validation are ready | Reviewed CSV count is 0 and validated manual hours are 0.00; the configured threshold is 40 hours | `MANUAL_EVIDENCE_REPORT.md`, `../tests/docs/MANUAL_TEST_TIMING.md` |
| Performance | One bounded showcase capture passes evidence-shape validation at 66.4 seconds and 130 samples | It is not a display-synchronized FPS target; splitscreen, multiplayer, low-end hardware, and long-session behavior remain open | `PERFORMANCE_EVIDENCE_REPORT.md`, `PERFORMANCE_BASELINE_PROOF.md` |
| Multiplayer | Local real-ENet host lifecycle, health/status identity, initial player/pickup state, owner inventory updates, and prediction acknowledgements pass focused checks | Real Steam/GodotSteam, latency behavior, end-to-end automatic reconnect, and dedicated-server clients remain unproven; older sandbox-blocked reports do not describe current local ENet capability | `tests/unit/test_world_host_lifecycle.gd`, `tests/unit/test_loot_service.gd`, `tests/unit/test_input_command.gd`, `MULTIPLAYER_PROFILE_SMOKE.md`, `../CHANGELOG.md` |
| Editor | Save/export/reload and local Workshop simulation contracts pass | Live embedded/standalone UI operation, custom undo/redo, and real Workshop transfer remain open | `EDITOR_ROUNDTRIP_PROOF.md`, `WORKSHOP_LOCAL_SIMULATION_PROOF.md` |
| Modding | Sample SDK and package validation contracts pass | Distribution packaging, live multiplayer synchronization, and real Workshop publication are unproven | `MODDING_SAMPLE_MOD.md`, `MOD_PACKAGE_VALIDATION.md` |
| Content scope | All four previously absent prop scenes now load and render; the procedural reference exports/imports with its preserved two-node hierarchy and no empty buffer | The reference intentionally contains no mesh, skin, or animation; it is not a finished character asset | `CURRENT_STATUS.md`, `../CHANGELOG.md` |
| Loot and props | Focused prop/spawner/ENet tests cover actual default-table collection, nested authoritative spawning, once-only interaction, configured weapons, and late-join state; all four forms render in an isolated native gallery | Human gameplay feel, long sessions, and the disabled automatic map-replacement workflow's multiplayer lifecycle remain outside this proof | `../tests/integration/test_loot_props.gd`, `../tests/integration/test_loot_prop_network.gd`, `../tests/integration/test_loot_prop_spawner.gd` |
| Inventory transactions | Earlier transaction/UI proof remains; current owned-drop checks cover complete stacks, rejection conservation, owner snapshots, persistence, plain Node worlds, saved-world restoration, and real ENet late joins | Human-operated drag feel, latency behavior, and long sessions remain unproven | `../tests/unit/test_inventory_drops.gd`, `../tests/unit/test_inventory_transactions.gd`, `../CHANGELOG.md` |
| Item trading and icons | Conserved trading remains covered; all ten sample-item paths now load original hash-pinned MIT SVG artwork, rendered at 32/48 pixels. Existing weapon PNG pixels remain unchanged | The new icon provenance does not clear unrelated artwork; human-operated trading and latency behavior remain unproven | `../tests/unit/test_inventory_trading.gd`, `PROVENANCE_LEDGER.csv`, `ATTRIBUTION.md`, `../CHANGELOG.md` |
| Consumables and clearing | Focused action/buff/loot tests pass; real Player smoke verifies consumption, movement/damage modifiers and expiry; ENet verifies refresh/expiry and rejects forged buff state | Latency, human-operated effects, and long-session balance remain unproven | `../tests/unit/test_inventory_consumption.gd`, `../tests/unit/test_consumable_buffs.gd`, `../CHANGELOG.md` |
| Distribution | The Windows Desktop resource ZIP contains all seven required notice/ledger files byte-for-byte, with no erroneous ledger translations; the 230-row ledger clears 18 assets | Twelve identified music tracks and 200 unverified assets remain uncleared; executable/installer contents and other platform payloads remain unproven | `ATTRIBUTION.md`, `PROVENANCE_LEDGER.csv`, `../tests/runners/test_export_notices.sh` |
| Release version | Current truth is explicitly `0.9.5-beta` | 1.0.0 release-version gate is blocked until all required proof lanes agree | `RELEASE_READINESS_REPORT.md` |

## Patched Godot Runtime

The audio repair is a local source patch against official revision `ed1daf0bf001b61586d9930840f2f1394092c079`, not an application shutdown delay. Build and select that runtime explicitly; existing official binaries are not replaced:

```bash
export GODOT_SOURCE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/modus/godot-ed1daf0bf"
bash tools/godot/build.sh
export GODOT_BIN="$GODOT_SOURCE_DIR/bin/godot.linuxbsd.editor.x86_64.modus_audio_shutdown"
bash tests/runners/test_audio_shutdown.sh
```

## Approval Rule

Use this matrix beside the release evidence bundle. Do not describe MODUS as shipped, production-ready, or fully approved while any row has an open limitation.
