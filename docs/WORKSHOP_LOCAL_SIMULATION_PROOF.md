# MODUS Workshop Proof Boundary

> **Documentation status: maintained reference.** This page preserves dated, focused observations, not fresh proof. Published readiness is consolidated in [Current Status](CURRENT_STATUS.md); generated reports and raw logs remain local-only under the [truth contract](DOCUMENTATION_TRUTH.md).

**Run date:** 2026-07-13
**Local simulation status:** PASS
Real Steam Workshop status: BLOCKED

`tests/integration/test_workshop_local_simulation.gd` passes 1/1 with 13 assertions under Godot 4.7/GUT. It packages a fixture level, uploads it through `WorkshopManager` local mode, verifies metadata and the local upload copy, downloads it, browses the cached item, subscribes, and unsubscribes while checking the downloaded path is removed.

The passing lane is local filesystem simulation only. It does not prove Steam account identity, Workshop visibility, Steam callbacks, cloud storage, or a real upload/download. Real Steam proof requires the GodotSteam extension, a running Steam client, a configured app ID, and account/app authorization; those prerequisites are unavailable in this checkout and remain blocked.
