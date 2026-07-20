@tool
class_name TooltipHelper
extends RefCounted

const TOOL_BLOCK_BRUSH := """Block Brush (B)

Place CSG blocks at grid-snapped positions.
• Click to place single block
• Drag to extend placement
• Use [ ] to adjust brush size"""

const TOOL_PAINT_BRUSH := """Paint Brush (P)

Apply materials to existing surfaces.
• Select material from palette
• Click on block to paint
• Drag to paint multiple"""

const TOOL_ERASER := """Eraser (E)

Remove placed objects.
• Click to delete single item
• Drag to box select and delete multiple
• Cannot delete LevelRoot"""

const TOOL_ENTITY_PLACER := """Entity Placer (T)

Place prefab entities from the palette.
• Select entity type from Assets
• Click to place at cursor
• Use R to rotate before placing"""

const TOOL_SPAWN_POINT := """Spawn Point (S)

Place spawn markers for players, enemies, or items.
• Select spawn type from palette
• Configure in Inspector after placing"""

const TOOL_CONNECT := """Connect Tool (C)

Create channel connections between interactables.
• Click source (e.g., lever)
• Click target (e.g., door)
• Connection appears in Level Script panel"""

const TOOL_SELECT := """Select Tool (V)

Select and manipulate placed objects.
• Click to select single item
• Shift+Click to add to selection
• Drag for box selection"""

const GRID_TOGGLE := """Toggle Grid (G)

Show/hide the 3D editing grid.
Grid helps with precise placement."""

const GRID_SIZE := """Grid Cell Size

Adjust the spacing between grid lines.
Smaller = more precision
Larger = faster building"""

const GRID_INCREASE := """Increase Grid Size (+)

Double the current grid cell size."""

const GRID_DECREASE := """Decrease Grid Size (-)

Halve the current grid cell size."""


static func get_tool_tooltip(tool_name: String) -> String:
	match tool_name:
		"block_brush":
			return TOOL_BLOCK_BRUSH
		"paint_brush":
			return TOOL_PAINT_BRUSH
		"eraser":
			return TOOL_ERASER
		"entity_placer":
			return TOOL_ENTITY_PLACER
		"spawn_point":
			return TOOL_SPAWN_POINT
		"connect":
			return TOOL_CONNECT
		"select":
			return TOOL_SELECT
	return ""


static func get_grid_tooltip(action: String) -> String:
	match action:
		"toggle":
			return GRID_TOGGLE
		"size":
			return GRID_SIZE
		"increase":
			return GRID_INCREASE
		"decrease":
			return GRID_DECREASE
	return ""
