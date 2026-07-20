# Splitscreen Integration and Stress Tests

> **Documentation status: maintained reference.** This directory currently contains 3 GUT scripts and 46 `test_` functions. Simulated stress iterations are not real-duration, real-controller, or rendered performance evidence.

| File | Source-level focus |
| --- | --- |
| `test_splitscreen_feature_integration.gd` | Feature lifecycle and integration |
| `test_splitscreen_stress.gd` | High-iteration state/resource/error scenarios |
| `test_multiplayer_compatibility.gd` | Splitscreen/network compatibility contracts |

Run the directory:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration/splitscreen
```

Focused results have reached feature integration 10/10, stress 20/20, and multiplayer compatibility 16/16 in dated Godot 4.7 runs. These results close those model/integration contracts only; they do not prove physical controllers, GUI layout, a 24-hour soak, memory-leak freedom, or target FPS.
