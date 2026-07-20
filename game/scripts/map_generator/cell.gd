class_name Cell
extends RefCounted

## Represents a single grid cell in the map layout
## Each cell has a type and can store additional metadata for generation

enum Type { EMPTY, ROOM, HALLWAY, OUTDOOR, CAVE, BOSS_ARENA, SECRET }

var type: Type = Type.EMPTY
var room_id: int = -1  # Reference to Room if type == ROOM
var height: float = 0.0  # For 3D floors and slopes
var material_override: Material = null
var metadata: Dictionary = {}  # Custom metadata for generation phases


func _init(cell_type: Type = Type.EMPTY) -> void:
	type = cell_type
