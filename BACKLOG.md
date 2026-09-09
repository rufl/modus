# MODUS Backlog

> **Documentation status: maintained reference.** Published readiness and dated test boundaries are defined by `docs/DOCUMENTATION_TRUTH.md` and `docs/CURRENT_STATUS.md`; locally generated reports describe individual runs, not fresh-clone guarantees.

## Source Of Truth Policy

Treat generated entries as proposals until they are promoted into the active queue, implemented, and proven. Every accepted active row and published closure summary must include at least one proof tag and a short evidence note.

### Proof Tags

- `[truth:source-audit]` - proven by inspecting the live tree, references, or generated artifacts.
- `[truth:docs]` - docs-only change proven by a local truth check or source scan.
- `[truth:test]` - automated test or smoke command was run and the result is recorded.
- `[truth:runtime]` - game/editor behavior was launched and observed locally.
- `[truth:manual]` - a manual test plan item was executed and the result is recorded.
- `[truth:blocked]` - blocked by a missing binary, dependency, service, asset, or external condition.
- `[truth:deferred]` - intentionally not active; keep rationale and a re-entry condition.

### Closure Rules

- Do not close feature or runtime rows with docs-only proof.
- Do not treat scaffolding, a warning path, or a planned command as runtime proof.
- If the full Godot suite is not available, record the narrower command that did run and keep the wider proof boundary open.
- Record completed, retired, or disproven work in root `CHANGELOG.md` with its proof tags, date, and evidence boundary before removing it from this active queue. `BACKLOG_ARCHIVE.md` is optional local-only history, not a tracked destination or required checkout input.

### Current Verification Boundaries

- Project-control/docs truth: `bash tools/check_project_truth.sh`
- Full automated Godot/GUT suite when Godot 4.7 is installed: `./tests/runners/run_all_tests_headless.sh`
- Batched automated lanes and triage report: `./tests/runners/run_tests_by_category.sh --report docs/AUTOMATED_TEST_LANES_REPORT.md`
- Main player path launch smoke: `tools/run_main_player_path_smoke.sh --strict`
- Manual evidence validation: `tools/validate_manual_evidence.sh --strict`
- Performance evidence validation: `tools/validate_performance_evidence.sh --strict`
- Release readiness validation: `tools/validate_release_readiness.sh --strict`
- Runtime gameplay/manual proof: launch a normal Godot session, complete the manual checklist, and record the observed path.

Report paths and `logs/` are ignored local outputs. See [report regeneration and evidence prerequisites](docs/DOCUMENTATION_TRUTH.md#regenerating-local-reports); their absence on a fresh clone does not invalidate historical summaries or establish a current PASS.

The six September 9 engineering repair groups are summarized in the [root changelog](CHANGELOG.md) and [current status](docs/CURRENT_STATUS.md): 67 focused tests/612 assertions, eleven actual gameplay checks, native asset rendering, and the compiled engine patch. The MP3 repair requires that patched Godot runtime. These are dated observations, not a fresh full-suite result; release tasks below remain open. `[truth:test]` `[truth:runtime]`

## Active Queue

- Progress 2026-08-02 golden-demo/mod-UX slice: added a player-visible automated showcase smoke that loads the maintained scene, spawns a player, accepts movement input, fires, defeats an enemy, collects a pickup, restores an encrypted save, and loads the bundled SDK sample; fixed stale save/ammo slot APIs, disabled-mod enablement, and the broken skill-tree compatibility scene; rebuilt the mod manager as a responsive localized focusable workflow with explicit pending-reload state. The smoke passes all 8 steps, and focused UI/localization/mod/save proof passes 72/72 with 298 assertions. `[truth:runtime]` `[truth:test]` `[truth:source-audit]`
- Progress 2026-08-02 showcase/provenance hardening slice: replaced the passive keyboard-only showcase splash with a responsive localized panel, mouse/gamepad/keyboard primary action, clear golden-demo route, and explicit evidence boundary; corrected the shared blood-pool shader identifier and missing-material failure; added root/export license packaging, retained verified Kenney CC0 and dip000 MIT records, and generated a deterministic 220-row asset ledger. Eight ledger rows are cleared; 212 still require rights review. `[truth:source-audit]` `[truth:docs]` `[truth:test]`
- Progress 2026-08-02 shared UI accessibility/localization slice: extended 48-pixel logical targets and explicit focus mode through host, multiplayer, options, mods, pause, save/load, and procedural modal actions; added English/Spanish route labels; fixed language-change fallbacks; reserved a deterministic wide menu column so hero art is not hidden behind the panel; made shared forms shrink safely; and added a source-bounded known-limits matrix. `[truth:source-audit]` `[truth:test]`
The August 4 aggregate recorded 1440/1440 with 20,475 assertions. It is historical evidence, not the current-tree suite total; a refreshed aggregate and manual, provenance, packaging, and external proof remain open. `[truth:test]`

### Manual And Performance Evidence

- [ ] Import manual gameplay evidence and clear the zero-hours blocker. `[truth:source-audit]` `[truth:test]`
  - Progress 2026-08-04: added `tools/run_manual_showcase_session.sh` plus a responsive F8/Gamepad Back recorder overlay for the 20-item bounded route. It writes directly to `logs/manual_test_logs/`, captures required tester/build/device/runtime metadata, requires notes for Fail/Skip, and keeps incomplete rows explicit. The validator now counts only reviewed test-row duration instead of idle recorder overhead; its deterministic self-check and focused Godot UI/timer proof pass.
  - Shortcoming: current status still records zero reviewed manual testing hours; automated interaction with the recorder is not manual gameplay evidence.
  - Completion proof required: ManualTestTimer CSV evidence exists under `logs/manual_test_logs`; `tools/validate_manual_evidence.sh --strict` passes; docs record exactly what was tested and what remains untested.

### Marketing-Ready Package

- [ ] Complete a distribution provenance ledger and resolve unverified third-party licensing. `[truth:source-audit]` `[truth:deferred]`
  - Progress 2026-08-02: `docs/PROVENANCE_LEDGER.csv` inventories 220 distributed assets; 8 are cleared with retained local evidence, including exact official-pack pixel matches for five Kenney CC0 files and pinned dip000 MIT review for both blood-pool derivatives. Export presets include the notices. The historical Jeh3no name has no current-tree or retained-base dependency marker and is not represented as a current distributed dependency.
  - Progress 2026-09-09: the ledger now inventories 230 assets with 18 cleared. A real Windows Desktop resource ZIP contains all seven required notice/ledger files byte-for-byte after repairing CSV import and the missing GUT notice. Executable/installer and other-platform verification remain open.
  - Shortcoming: 12 Suno-tagged music tracks are identified but lack retained commercial-rights evidence, and 200 additional assets remain unverified. The production validator's two-count does not include legal/distribution clearance.
  - Completion proof required: inventory every distributed non-code asset and derived code path by file/hash/source/license, retain required notices locally, resolve or replace unknown entries, and verify exported bundles contain the required material.
