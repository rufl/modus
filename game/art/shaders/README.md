# Shaders

This directory contains the shader code (`.gdshader`) used for visual effects in the game.

## Retro Liquid Shaders

A suite of retro-styled animated liquid shaders inspired by Quake/Half-Life.

- **`retro_water.gdshader`**:
  - Features: Animated vertex waves, depth-based color absorption, edge foam, specular highlights.
  - Usage: Apply to a PlaneMesh.
  - Parameters: Wave speed, amplitude, foam threshold, deep/shallow colors.

- **`retro_lava.gdshader`**:
  - Features: Scrolling texture base, bubbling animation brightness pulsing, crust formation.
  - Usage: Apply to a PlaneMesh.
  - Parameters: Scroll speed, glow intensity, crust amount.

- **`retro_poison.gdshader`**:
  - Features: Toxic green/purple gradient, bubbling sludge animation, flow distortion.
  - Usage: Apply to a PlaneMesh for acid pools or toxic waste.
  - Parameters: Flow speed, bubble density, toxic glow.

- **`retro_blood.gdshader`**:
  - Features: Thick, viscous red liquid with coagulation patterns (darker clots).
  - Usage: Apply to a PlaneMesh for blood pools or gore effects.
  - Parameters: Flow direction, viscosity (via noise scale), blood freshness color.

## Utility Shaders

- **`liquid.gdshader`**: Generic liquid shader with vertex wobble and UV scrolling.
- **`post_process.gdshader`**: Screen-space effect for dithering and color quantization.
