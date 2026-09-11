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

The September 10 refreshed headless aggregate passed 1,568/1,568 tests with 21,718 assertions across 135 scripts using the patched Godot 4.7.2 binary; the category report passed Unit 1,166/1,166, Integration 227/227 with 2 GUI-required files skipped, and Property 175/175. Manual, provenance, packaging, benchmark, GUI-required, and external proof remain open. `[truth:test]`

## Active Queue

- Progress 2026-08-02 golden-demo/mod-UX slice: added a player-visible automated showcase smoke that loads the maintained scene, spawns a player, accepts movement input, fires, defeats an enemy, collects a pickup, restores an encrypted save, and loads the bundled SDK sample; fixed stale save/ammo slot APIs, disabled-mod enablement, and the broken skill-tree compatibility scene; rebuilt the mod manager as a responsive localized focusable workflow with explicit pending-reload state. The smoke passes all 8 steps, and focused UI/localization/mod/save proof passes 72/72 with 298 assertions. `[truth:runtime]` `[truth:test]` `[truth:source-audit]`
- Progress 2026-08-02 showcase/provenance hardening slice: replaced the passive keyboard-only showcase splash with a responsive localized panel, mouse/gamepad/keyboard primary action, clear golden-demo route, and explicit evidence boundary; corrected the shared blood-pool shader identifier and missing-material failure; added root/export license packaging, retained verified Kenney CC0 and dip000 MIT records, and generated a deterministic 220-row asset ledger. Eight ledger rows are cleared; 212 still require rights review. `[truth:source-audit]` `[truth:docs]` `[truth:test]`
- Progress 2026-08-02 shared UI accessibility/localization slice: extended 48-pixel logical targets and explicit focus mode through host, multiplayer, options, mods, pause, save/load, and procedural modal actions; added English/Spanish route labels; fixed language-change fallbacks; reserved a deterministic wide menu column so hero art is not hidden behind the panel; made shared forms shrink safely; and added a source-bounded known-limits matrix. `[truth:source-audit]` `[truth:test]`
The September 10 refreshed aggregate supersedes the August 4 historical total for current-tree automated evidence: 1,568/1,568 tests and 21,718 assertions across 135 scripts, with two GUI-required files skipped and benchmark tests deferred. Manual, provenance, packaging, and external proof remain open. `[truth:test]`
- Progress 2026-09-10 standalone editor productization: File/Edit/View/Help actions now dispatch through shared selection and runtime history services; `.mdsl` level export uses `LevelPackager`; focused editor proof passes 27/27 with 107 assertions. Native exported-app startup, full graphical workflow, corrupt-file handling, permission failures, and overwrite behavior remain open. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 advanced brush tranche: staircase, arch, torus, and capsule meshes are generated as non-empty ArrayMesh geometry; fill uses deterministic density sampling and batch limits; detached clear/remove paths are safe. Focused editor proof passes 29/29 with 121 assertions and no GUT orphans. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 implementation-debt tranche: fixed editor-console `keep` occupancy, configurable package authors, visual action sound/variable/teleport nodes, procedural collapsable-floor audio, configured armor reduction, file-owned rule hot reload, SteamID-first persistence, milestone popups, threat-aware AI retaliation, and configurable small-map monster floors. Focused proof passes 31/31 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 NetworkEditor security tranche: server-only RPC handlers now reject malformed/non-finite/out-of-bounds payloads and unsafe relative paths; entity/transform requests have explicit whitelist/rate limits. Focused proof passes NetworkEditor 5/5 with 19 assertions and RPC whitelist 9/9 with 119 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 trusted-peer security tranche: Steam-authenticated peers no longer bypass RPC whitelist/rate limits or server movement bounds. NetworkManager focused proof passes 14/14 with 54 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 semantic RPC validation tranche: player-status updates are peer-bound with bounded health/state values; chat payloads reject empty, oversized, and line-control input. NetworkManager proof passes 15/15 with 59 assertions; RPC whitelist proof remains 9/9 with 119 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 RPC payload tranche: kill reports now require sender participation and bounded weapon-source text; Steam ticket payloads require positive IDs and bounded non-empty buffers. NetworkManager proof passes 15/15 with 62 assertions; RPC whitelist proof remains 9/9 with 119 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 revive authority tranche: start, stop, and immediate-bleedout RPCs now validate sender-owned targets and rate limits before server-side handling; distance checks remain authoritative. Revive unit proof passes 8/8 and property proof 5/5; whitelist proof passes 9/9 with 125 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-10 interaction RPC tranche: physics-object pickup requests now require sender ownership, rigid-body targets, and server distance bounds; throw requests reject non-finite/excessive directions. NetworkManager proof passes 15/15 with 64 assertions; whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 damage authority tranche: player damage reception is authority-only; malformed and non-finite damage-request payloads are rejected before server processing. Combat feature proof passes 20/20 with 30 assertions; NetworkManager proof passes 15/15 with 64 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 weapon VFX authority tranche: blood, decal, debris, muzzle-flash, tracer, and cartridge RPCs are authority-only, blocking remote peers from spawning arbitrary world effects. Combat proof passes 20/20 with 30 assertions; NetworkManager proof passes 15/15 with 64 assertions; RPC whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 player-state authority tranche: movement, dodge, dash, slide, wallrun, walljump, fly, firing-state, and restored-alive synchronization RPCs are authority-only, blocking forged remote state updates. NetworkManager proof passes 15/15 with 64 assertions; combat proof passes 20/20 with 30 assertions; RPC whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 player lifecycle tranche: mode/state requests now execute only on the server with valid senders and bounded enums; downed assistance and spectate targets are validated. Player systems proof passes 15/15 with 38 assertions; NetworkManager proof passes 15/15 with 64 assertions; RPC whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 gameplay request tranche: grenade spawn requests require owning senders and finite origin/direction bounds; breakable-prop damage rejects malformed/non-finite/excessive payloads and unsafe damage types; military-chest requests bind opener identity to the sender. Weapon proof passes 58/58 with 76 assertions; NetworkManager proof passes 15/15 with 64 assertions; RPC whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 loot-request tranche: backpack retrieval and military-chest opening now require valid sender identity and server-side interaction distance. Loot proof passes 7/7 with 71 assertions; NetworkManager proof passes 15/15 with 64 assertions; RPC whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 treasure/effect tranche: treasure-chest requests now reject missing senders/players and enforce interaction distance; enemy damage flashes are authority-only. Effects proof passes 12/12 with 26 assertions; NetworkManager proof passes 15/15 with 64 assertions; RPC whitelist proof passes 9/9 with 127 assertions. `[truth:test]` `[truth:source-audit]`
- Progress 2026-09-11 interaction-authority tranche: button and lever requests now require sender-owned nearby players; authority-only replication separates client requests from shared state/effects; EnemyLab state changes require valid mapped states and nearby senders. Local formatter/lint proof passes; CI run 52 remains red on 60 unit and 28 property failures outside this tranche. `[truth:source-audit]`
- Progress 2026-09-11 door/barrel/spawn tranche: door requests now require nearby sender-owned players; explosive-barrel effects are authority-only; world spawn requests accept only bounded modes and positive peer IDs. Local formatter/lint proof passes; runtime proof remains bounded by CI's existing baseline failures. `[truth:source-audit]`
- Progress 2026-09-11 ProjectileLab tranche: freeze requests now require nearby sender-owned players; time-scale replication is authority-only; pickup, health-sync, and status-effect RPCs retain existing gates. Local formatter/lint proof passes; runtime proof remains bounded by CI's existing baseline failures. `[truth:source-audit]`
- Progress 2026-09-11 downed/player-state/interaction tranche: revive and bleedout requests now bind to sender-owned player nodes with distance checks; assistance/spectate requests are rate-limited; validated player-state requests apply transitions; interaction pickup requests enforce server-side range. Local formatter/lint proof passes; runtime proof remains bounded by CI's existing baseline failures. `[truth:source-audit]`
- Progress 2026-09-11 inventory/editor tranche: split/equip/unequip inventory requests now require positive sender IDs and whitelist rate limits; NetworkEditor permission fallback fails closed without runtime manager/config context. Local formatter/lint proof passes; runtime proof remains bounded by CI's existing baseline failures. `[truth:source-audit]`
### Manual And Performance Evidence

- [ ] Import manual gameplay evidence and clear the zero-hours blocker. `[truth:source-audit]` `[truth:test]`
  - Progress 2026-08-04: added `tools/run_manual_showcase_session.sh` plus a responsive F8/Gamepad Back recorder overlay for the 20-item bounded route. It writes directly to `logs/manual_test_logs/`, captures required tester/build/device/runtime metadata, requires notes for Fail/Skip, and keeps incomplete rows explicit. The validator now counts only reviewed test-row duration instead of idle recorder overhead; its deterministic self-check and focused Godot UI/timer proof pass.
  - Shortcoming: current status still records zero reviewed manual testing hours; automated interaction with the recorder is not manual gameplay evidence.
  - Completion proof required: ManualTestTimer CSV evidence exists under `logs/manual_test_logs`; `tools/validate_manual_evidence.sh --strict` passes; docs record exactly what was tested and what remains untested.

### Marketing-Ready Package

- [ ] Complete a distribution provenance ledger and resolve unverified third-party licensing. `[truth:source-audit]` `[truth:deferred]`
  - Progress 2026-08-02: `docs/PROVENANCE_LEDGER.csv` inventories 220 distributed assets; 8 are cleared with retained local evidence, including exact official-pack pixel matches for five Kenney CC0 files and pinned dip000 MIT review for both blood-pool derivatives. Export presets include the notices. The historical Jeh3no name has no current-tree or retained-base dependency marker and is not represented as a current distributed dependency.
  - Progress 2026-09-10: notice checks and executable exports pass with installed Godot 4.7.2 templates; no installer definition/toolchain is present.
  - Progress 2026-09-11: author-confirmed liquid shaders/materials and skybox shaders/materials are original AI-assisted LichForge work and classified MIT under the project notice; the ledger now has 163 cleared and 55 unverified assets. The production validator's two-count does not include legal/distribution clearance.
  - Completion proof required: inventory every distributed non-code asset and derived code path by file/hash/source/license, retain required notices locally, resolve or replace unknown entries, and verify exported bundles contain the required material.
