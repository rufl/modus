# MODUS Multiplayer Demo Profile Smoke

> **Documentation status: maintained reference.** Project-wide readiness and test totals are defined by `docs/DOCUMENTATION_TRUTH.md` and the generated readiness reports; narrower claims in this file apply only to the named subsystem or workflow.

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
- ENet host/join remains blocked in the current sandbox by localhost socket creation; real Steam/GodotSteam proof remains unavailable.
