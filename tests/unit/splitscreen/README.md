# Splitscreen Unit Tests

> **Documentation status: maintained reference.** This directory currently contains 8 GUT scripts and 181 `test_` functions. Function count is inventory, not a coverage percentage or aggregate pass claim.

The files cover assignment UI, error recovery, gamepad control, session state, the configuration contract, input routing, manager behavior, and viewport management.

Run the directory through GUT:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/splitscreen
```

Focused green results exist for several files, including the 15/15 assignment-UI contract and repaired manager/configuration lanes. Read [Current Status](../../../docs/CURRENT_STATUS.md) and the root changelog for exact dated results; historical aggregates do not certify the current checkout. Unit/model tests do not prove physical gamepads or rendered viewports.
