# Splitscreen Property Tests

> **Documentation status: maintained reference.** This directory contains one GUT script with 30 `test_` functions. The properties model invariants; they are not a 100% coverage claim.

The file exercises state transitions, player/device mappings, viewport rectangles, resource bounds, configuration, recovery, pause state, quality adjustment, and related generated inputs.

Run it directly:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/property/splitscreen/test_splitscreen_properties.gd
```

A property pass proves only the generated/model cases executed by that run. It does not prove scene rendering, controller hardware, network peers, performance, or absence of unmodeled states. Use generated reports for the latest result rather than the original February design count.
