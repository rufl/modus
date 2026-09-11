# MODUS Multiplayer Demo Profile Smoke

> **Documentation status: maintained reference.** This page preserves the July 13 invocation boundary, not current ENet capability or fresh proof. Later focused local ENet observations are consolidated in [Current Status](CURRENT_STATUS.md); generated reports and raw logs remain local-only under the [truth contract](DOCUMENTATION_TRUTH.md).

**Generated:** 2026-07-13
**Status:** PASS (profile launch); host/join runtime proof remains blocked
**Profile:** `multiplayer_demo`

## Launch Proof

```bash
GODOT_BIN=/tmp/modus_godot_4.7/Godot_v4.7-stable_linux.x86_64 \
  tools/run_multiplayer_profile_smoke.sh
```

The smoke launches Godot headlessly with `MODUS_FEATURE_PROFILE=multiplayer_demo`, applies the profile through `GameManager`, and rejects parse errors, unknown-profile warnings, or service-lookup failures. The latest run passed.

## Profile Boundary

- `standard` remains the default single-player profile and does not enable `network`.
- `multiplayer_demo` explicitly enables `network` plus the core gameplay features required by the pitch path.
- The profile does not prove two peers connected, Steam availability, or gameplay synchronization.
- At this July 13 invocation's boundary, ENet host/join was blocked by sandbox localhost socket creation. Later focused local ENet observations and authenticated local GodotSteam initialization are documented in [Current Status](CURRENT_STATUS.md); two-account Steam, Workshop, and representative WAN proof remain open.
