# MODUS Truth and Quality Checklist

> **Documentation status: maintained reference.** This checklist is a review aid, not evidence that any item has passed.

## Claims and documentation

- [ ] Present-tense claims follow `docs/DOCUMENTATION_TRUTH.md` precedence.
- [ ] Focused tests are described as focused, not as project-wide readiness.
- [ ] Generated, manual, runtime, hardware, connected-peer, Steam, and editor-UI proof are kept separate.
- [ ] Historical snapshots retain the historical banner and are not linked as current truth.
- [ ] Counts include date, command/report, and complete summary.
- [ ] Missing/incomplete summaries, timeouts, skips, risky tests, and orphans remain visible.
- [ ] Current docs contain no retired paths or invented APIs.

## Code changes

- [ ] The smallest relevant test reproduces or protects the changed behavior.
- [ ] Touched GDScript is formatted/linted when tooling is available.
- [ ] Optional GameManager services are null-checked.
- [ ] Signals, timers, threads, files, and test-owned nodes have deterministic cleanup.
- [ ] Intentional warnings/errors are expected and consumed in tests.
- [ ] TODO/inert UI surfaces are documented and not called implemented.

## Networking and security

- [ ] Every `any_peer` RPC is audited at its actual handler.
- [ ] Server authority, sender identity, payload bounds, state, range, ownership, and cooldown are validated.
- [ ] Allowlisting/rate limiting is not mistaken for semantic validation.
- [ ] Debug/editor/admin commands are disabled or authorized for release profiles.
- [ ] Connected-peer, reconnect, loss/latency, hostile input, and dedicated-server evidence is recorded before support claims.

## Performance

- [ ] Workload, hardware, OS/driver, renderer, resolution, cap/VSync, and duration are recorded.
- [ ] Average is accompanied by minimum/percentile/frame-time spikes, memory, and warnings.
- [ ] Before/after captures use the same workload.
- [ ] Headless timing is not described as graphical GPU proof.
- [ ] Results are not generalized beyond the tested matrix.

## Manual and UI

- [ ] A normal graphical session is used for player-visible claims.
- [ ] Keyboard, gamepad, focus, scaling, accessibility, and inert affordances are checked.
- [ ] Manual CSVs are imported and the strict validator is regenerated.
- [ ] Failed/skipped/incomplete steps remain in the evidence.

## Release handoff

- [ ] `bash tools/check_documentation_truth.sh` passes.
- [ ] `bash tools/check_project_truth.sh` passes.
- [ ] Relevant focused and wider test lanes are recorded.
- [ ] Generated manual, performance, release, and production reports are refreshed.
- [ ] `BACKLOG.md`, `CHANGELOG.md`, and roadmaps reflect the same boundary.
- [ ] Release remains blocked while the production report says NOT READY.
