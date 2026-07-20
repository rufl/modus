class_name KeyLockSystem
extends RefCounted

## Implements key-lock mechanics for gated progression
## Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

enum KeyColor { RED, BLUE, YELLOW }


## Generate key-lock pairs for the map
## Returns dictionary with keys and locked_doors arrays
func generate_key_lock_system(context: GenerationContext) -> Dictionary:
	if not context.config.enable_key_locks:
		return {"keys": [], "locked_doors": []}

	# Determine number of key types based on map complexity
	var key_count := _calculate_key_count(context)

	# Analyze room progression to determine key placement order
	var progression_order := _analyze_room_progression(context)

	if progression_order.size() < 3:
		push_warning("Not enough rooms for key-lock system")
		return {"keys": [], "locked_doors": []}

	# Place keys and locked doors in progression order
	var keys: Array = []
	var locked_doors: Array = []

	for i in range(key_count):
		var key_color: KeyColor = i as KeyColor
		var key_lock_pair := _place_key_lock_pair(context, progression_order, key_color, i)

		if key_lock_pair.has("key") and key_lock_pair.has("door"):
			keys.append(key_lock_pair.key)
			locked_doors.append(key_lock_pair.door)

	return {"keys": keys, "locked_doors": locked_doors}


## Calculate number of key types based on map complexity
## Small maps: 1 key, Medium: 2 keys, Large: 3 keys
func _calculate_key_count(context: GenerationContext) -> int:
	var map_area: int = context.grid_size.x * context.grid_size.y
	var room_count: int = context.rooms.size()

	# Base on map size and room count
	if map_area >= 256 * 256 or room_count >= 20:
		return 3
	if map_area >= 128 * 128 or room_count >= 10:
		return 2
	return 1


## Analyze room progression from player start
## Returns array of rooms in order of distance from start
func _analyze_room_progression(context: GenerationContext) -> Array[Room]:
	if context.rooms.is_empty():
		return []

	# Find player start room (typically first room or room closest to center)
	var start_room: Room = _find_start_room(context)

	# Build progression order using breadth-first search
	var progression: Array[Room] = []
	var visited: Dictionary = {}
	var queue: Array[Room] = [start_room]
	visited[start_room.id] = true

	while not queue.is_empty():
		var current: Room = queue.pop_front()
		progression.append(current)

		# Add connected rooms to queue
		for connected_id: int in current.connections:
			if not visited.has(connected_id):
				var connected_room := _find_room_by_id(context, connected_id)
				if connected_room:
					queue.append(connected_room)
					visited[connected_id] = true

	return progression


## Find the starting room (first room or closest to center)
func _find_start_room(context: GenerationContext) -> Room:
	if context.rooms.is_empty():
		return null

	# Use first room as start (typically placed near center)
	return context.rooms[0]


## Find room by ID
func _find_room_by_id(context: GenerationContext, room_id: int) -> Room:
	for room: Room in context.rooms:
		if room.id == room_id:
			return room
	return null


## Place a key-lock pair in progression order
func _place_key_lock_pair(
	context: GenerationContext, progression: Array[Room], key_color: KeyColor, pair_index: int
) -> Dictionary:
	# Divide progression into segments for key placement
	var segment_size: int = max(1, progression.size() / 4)

	# Key should be in earlier segment
	var key_segment_start: int = pair_index * segment_size
	var key_segment_end: int = min(key_segment_start + segment_size, progression.size() / 2)

	# Door should be in later segment (after key)
	var door_segment_start: int = key_segment_end + 1
	var door_segment_end: int = min(door_segment_start + segment_size * 2, progression.size())

	# Ensure valid ranges
	if key_segment_end >= progression.size() or door_segment_start >= progression.size():
		return {}

	# Select rooms for key and door
	var key_room_idx: int = context.rng.randi_range(key_segment_start, key_segment_end - 1)
	var door_room_idx: int = context.rng.randi_range(door_segment_start, door_segment_end - 1)

	var key_room: Room = progression[key_room_idx]
	var door_room: Room = progression[door_room_idx]

	# Place key in key_room
	var key_data := _place_key(context, key_room, key_color)

	# Place locked door blocking entrance to door_room
	var door_data := _place_locked_door(context, door_room, key_color)

	return {"key": key_data, "door": door_data}


## Place a key in a room
func _place_key(context: GenerationContext, room: Room, key_color: KeyColor) -> Dictionary:
	# Find a good position in the room (not at entrance)
	var key_pos := _find_key_position(room)

	var key_data := {
		"id": context.key_placements.size(),
		"color": KeyColor.keys()[key_color],
		"position": Vector3(key_pos.x * 2.0, 0.5, key_pos.y * 2.0),
		"room_id": room.id,
		"grid_position": key_pos
	}

	# Mark in metadata
	context.key_placements.append(key_data)

	# Mark cell metadata
	var cell: Cell = context.grid[key_pos.y][key_pos.x]
	cell.metadata["has_key"] = true
	cell.metadata["key_color"] = KeyColor.keys()[key_color]

	return key_data


## Find a suitable position for a key in a room
func _find_key_position(room: Room) -> Vector2i:
	if room.cells.is_empty():
		return Vector2i.ZERO

	# Prefer positions away from entrance points
	var candidates: Array[Vector2i] = []

	for cell_pos: Vector2i in room.cells:
		# Skip entrance points
		if cell_pos in room.entrance_points:
			continue
		candidates.append(cell_pos)

	# If no candidates, use any cell
	if candidates.is_empty():
		candidates = room.cells.duplicate()

	# Return random candidate
	return candidates[randi() % candidates.size()]


## Place a locked door at a room entrance
func _place_locked_door(context: GenerationContext, room: Room, key_color: KeyColor) -> Dictionary:
	# Find a connection point to place the door
	var door_pos := _find_door_position(context, room)

	if door_pos == Vector2i(-1, -1):
		push_warning("Could not find valid door position for room %d" % room.id)
		return {}

	var door_data := {
		"id": len(context.grid),  # Temporary ID
		"color": KeyColor.keys()[key_color],
		"position": Vector3(door_pos.x * 2.0, 0.0, door_pos.y * 2.0),
		"room_id": room.id,
		"grid_position": door_pos,
		"blocks_progression": true
	}

	# Mark cell metadata
	var cell: Cell = context.grid[door_pos.y][door_pos.x]
	cell.metadata["has_locked_door"] = true
	cell.metadata["door_color"] = KeyColor.keys()[key_color]
	cell.metadata["blocks_progression"] = true

	return door_data


## Find a suitable position for a locked door (at room entrance)
func _find_door_position(context: GenerationContext, room: Room) -> Vector2i:
	# Use entrance points if available
	if not room.entrance_points.is_empty():
		return room.entrance_points[0]

	# Otherwise find a hallway connection
	for cell_pos: Vector2i in room.cells:
		# Check if adjacent to hallway
		var neighbors := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

		for dir: Vector2i in neighbors:
			var neighbor_pos: Vector2i = cell_pos + dir
			if _is_in_bounds(context, neighbor_pos):
				var neighbor_cell: Cell = context.grid[neighbor_pos.y][neighbor_pos.x]
				if neighbor_cell.type == Cell.Type.HALLWAY:
					return cell_pos

	return Vector2i(-1, -1)


## Check if position is within grid bounds
func _is_in_bounds(context: GenerationContext, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < context.grid_size.x and pos.y >= 0 and pos.y < context.grid_size.y


## Validate that all locked doors are reachable after key acquisition
func validate_key_lock_progression(
	context: GenerationContext, keys: Array, locked_doors: Array
) -> bool:
	# For each key-door pair, verify the key is reachable before the door
	for i in range(min(keys.size(), locked_doors.size())):
		var key: Dictionary = keys[i]
		var door: Dictionary = locked_doors[i]

		# Check that key room comes before door room in progression
		var key_room := _find_room_by_id(context, key.room_id)
		var door_room := _find_room_by_id(context, door.room_id)

		if not key_room or not door_room:
			push_warning("Invalid room references in key-lock pair %d" % i)
			return false

		# Verify key is accessible from start
		if not _is_room_reachable(context, key_room):
			push_warning("Key room %d is not reachable from start" % key_room.id)
			return false

	return true


## Check if a room is reachable from the start
func _is_room_reachable(context: GenerationContext, target_room: Room) -> bool:
	var start_room := _find_start_room(context)
	if not start_room:
		return false

	# BFS to check reachability
	var visited: Dictionary = {}
	var queue: Array[Room] = [start_room]
	visited[start_room.id] = true

	while not queue.is_empty():
		var current: Room = queue.pop_front()

		if current.id == target_room.id:
			return true

		for connected_id: int in current.connections:
			if not visited.has(connected_id):
				var connected_room := _find_room_by_id(context, connected_id)
				if connected_room:
					queue.append(connected_room)
					visited[connected_id] = true

	return false
