class_name Hallway
extends RefCounted

## Represents a hallway connecting two rooms or areas
## Hallways are generated using A* pathfinding

var id: int
var start_room_id: int
var end_room_id: int
var path: Array[Vector2i] = []  # Grid positions forming the hallway
var width: int = 2  # Hallway width in cells (minimum 2)
var is_junction: bool = false  # True if this hallway intersects another


func _init(hallway_id: int = 0, start_id: int = -1, end_id: int = -1) -> void:
	id = hallway_id
	start_room_id = start_id
	end_room_id = end_id
