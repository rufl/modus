class_name Room
extends RefCounted

## Represents a room in the generated map
## Rooms are collections of grid cells with organic shapes

# 4-8 cells
# 9-16 cells
# 17-32 cells
# 40+ cells
enum RoomType { SMALL, MEDIUM, LARGE, BOSS_ARENA }

var id: int
var center: Vector2i
var cells: Array[Vector2i] = []  # Grid positions occupied by this room
var poly_points: PackedVector2Array  # Polygon outline for organic shape
var type: RoomType
var connections: Array[int] = []  # IDs of connected rooms
var entrance_points: Array[Vector2i] = []  # Grid positions for hallway connections
var metadata: Dictionary = {}  # Custom data for rule modules


func _init(
	room_id: int = 0, room_center: Vector2i = Vector2i.ZERO, room_type: RoomType = RoomType.MEDIUM
) -> void:
	id = room_id
	center = room_center
	type = room_type
