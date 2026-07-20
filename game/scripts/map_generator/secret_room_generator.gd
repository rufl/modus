class_name SecretRoomGenerator
extends RefCounted

## Generates secret rooms with fake walls for exploration rewards
## Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")


## Generate secret rooms based on map size and configuration
## Returns array of secret room data dictionaries
func generate_secret_rooms(context: GenerationContext) -> Array:
	var secret_rooms: Array = []

	if not context.config.enable_secrets:
		return secret_rooms

	# Determine number of secret rooms based on map size (1-3)
	var secret_count := _calculate_secret_count(context)

	# Find suitable locations for secret rooms
	var candidate_locations := _find_secret_room_candidates(context)

	if candidate_locations.is_empty():
		push_warning("No suitable locations found for secret rooms")
		return secret_rooms

	# Place secret rooms
	for i in range(min(secret_count, candidate_locations.size())):
		var location: Dictionary = candidate_locations[i]
		var secret_room := _create_secret_room(context, location)

		if secret_room:
			secret_rooms.append(secret_room)
			_mark_secret_cells(context, secret_room)

	return secret_rooms


## Calculate number of secret rooms based on map size
## Small maps (64x64): 1 secret, Medium (128x128): 2 secrets, Large (256x256): 3 secrets
func _calculate_secret_count(context: GenerationContext) -> int:
	var configured_count: int = context.config.secret_room_count
	var map_area: int = context.grid_size.x * context.grid_size.y

	# Determine max secrets based on map size
	var max_by_size: int = 1
	if map_area >= 256 * 256:
		max_by_size = 3
	elif map_area >= 128 * 128:
		max_by_size = 2

	# Use configured count but cap by map size
	return clampi(configured_count, 1, max_by_size)


## Find candidate locations for secret rooms
## Looks for rooms with suitable walls for fake wall placement
func _find_secret_room_candidates(context: GenerationContext) -> Array:
	var candidates: Array = []

	# Iterate through existing rooms to find suitable locations
	for room: Room in context.rooms:
		# Skip boss arenas and very small rooms
		if room.type == Room.RoomType.BOSS_ARENA or room.cells.size() < 4:
			continue

		# Find walls adjacent to this room that could hide a secret
		var wall_candidates := _find_suitable_walls(context, room)

		for wall_data: Dictionary in wall_candidates:
			candidates.append(
				{
					"adjacent_room": room,
					"wall_position": wall_data.wall_pos,
					"secret_position": wall_data.secret_pos,
					"direction": wall_data.direction
				}
			)

	# Shuffle candidates for variety
	candidates.shuffle()

	return candidates


## Find suitable walls adjacent to a room for secret placement
func _find_suitable_walls(context: GenerationContext, room: Room) -> Array:
	var suitable_walls: Array = []

	# Check each cell in the room for adjacent empty spaces
	for cell_pos: Vector2i in room.cells:
		# Check all 4 directions (North, South, East, West)
		var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

		for dir: Vector2i in directions:
			var wall_pos: Vector2i = cell_pos + dir
			var secret_pos: Vector2i = wall_pos + dir

			# Check if wall position is valid and empty
			if not _is_valid_secret_location(context, wall_pos, secret_pos):
				continue

			suitable_walls.append(
				{"wall_pos": wall_pos, "secret_pos": secret_pos, "direction": dir}
			)

	return suitable_walls


## Check if a location is valid for a secret room
func _is_valid_secret_location(
	context: GenerationContext, wall_pos: Vector2i, secret_pos: Vector2i
) -> bool:
	# Check bounds
	if not _is_in_bounds(context, wall_pos) or not _is_in_bounds(context, secret_pos):
		return false

	# Wall position should be empty (will become fake wall)
	var wall_cell: Cell = context.grid[wall_pos.y][wall_pos.x]
	if wall_cell.type != Cell.Type.EMPTY:
		return false

	# Secret position should be empty (will become secret room)
	var secret_cell: Cell = context.grid[secret_pos.y][secret_pos.x]
	if secret_cell.type != Cell.Type.EMPTY:
		return false

	# Check that secret position has enough empty space around it (at least 3x3)
	var empty_count := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_pos := secret_pos + Vector2i(dx, dy)
			if _is_in_bounds(context, check_pos):
				var check_cell: Cell = context.grid[check_pos.y][check_pos.x]
				if check_cell.type == Cell.Type.EMPTY:
					empty_count += 1

	# Need at least 5 empty cells for a small secret room
	return empty_count >= 5


## Check if position is within grid bounds
func _is_in_bounds(context: GenerationContext, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < context.grid_size.x and pos.y >= 0 and pos.y < context.grid_size.y


## Create a secret room at the specified location
func _create_secret_room(context: GenerationContext, location: Dictionary) -> Dictionary:
	var secret_pos: Vector2i = location.secret_position
	var wall_pos: Vector2i = location.wall_position

	# Generate small room shape (3-5 cells)
	var secret_cells := _generate_secret_room_cells(context, secret_pos)

	if secret_cells.is_empty():
		return {}

	# Create secret room data
	var secret_room := {
		"id": context.secret_rooms.size(),
		"cells": secret_cells,
		"fake_wall_position": wall_pos,
		"entrance_position": secret_pos,
		"adjacent_room_id": location.adjacent_room.id,
		"direction": location.direction,
		"has_high_value_items": true
	}

	return secret_room


## Generate cells for a secret room (small 3-5 cell room)
func _generate_secret_room_cells(
	context: GenerationContext, start_pos: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var target_size := context.rng.randi_range(3, 5)

	# Start with the entrance cell
	cells.append(start_pos)

	# Grow the room using flood fill approach
	var candidates: Array[Vector2i] = [start_pos]
	var visited: Dictionary = {start_pos: true}

	while cells.size() < target_size and not candidates.is_empty():
		# Pick a random candidate
		var current_idx := context.rng.randi_range(0, candidates.size() - 1)
		var current: Vector2i = candidates[current_idx]
		candidates.remove_at(current_idx)

		# Try to expand in random directions
		var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
		directions.shuffle()

		for dir: Vector2i in directions:
			if cells.size() >= target_size:
				break

			var next_pos: Vector2i = current + dir

			# Check if valid and not visited
			if visited.has(next_pos):
				continue

			if not _is_in_bounds(context, next_pos):
				continue

			var cell: Cell = context.grid[next_pos.y][next_pos.x]
			if cell.type != Cell.Type.EMPTY:
				continue

			# Add to secret room
			cells.append(next_pos)
			candidates.append(next_pos)
			visited[next_pos] = true

	return cells


## Mark cells in the grid as secret room cells
func _mark_secret_cells(context: GenerationContext, secret_room: Dictionary) -> void:
	for cell_pos: Vector2i in secret_room.cells:
		var cell: Cell = context.grid[cell_pos.y][cell_pos.x]
		cell.type = Cell.Type.SECRET
		cell.metadata["secret_room_id"] = secret_room.id
		cell.metadata["is_secret"] = true

	# Mark fake wall position
	var wall_pos: Vector2i = secret_room.fake_wall_position
	var wall_cell: Cell = context.grid[wall_pos.y][wall_pos.x]
	wall_cell.metadata["is_fake_wall"] = true
	wall_cell.metadata["secret_room_id"] = secret_room.id
	wall_cell.metadata["passable"] = true


## Place high-value items in secret rooms
func place_secret_items(context: GenerationContext) -> void:
	for secret_room: Dictionary in context.secret_rooms:
		# Find center of secret room for item placement
		var center_pos := _calculate_room_center(secret_room.cells)

		# Place high-value item spawn point
		var item_spawn := {
			"position": Vector3(center_pos.x * 2.0, 0.0, center_pos.y * 2.0),
			"type": "high_value",
			"item_tier": "rare",
			"secret_room_id": secret_room.id
		}

		context.item_spawns.append(item_spawn)


## Calculate center position of a room
func _calculate_room_center(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO

	var sum := Vector2i.ZERO
	for cell_pos: Vector2i in cells:
		sum += cell_pos

	return Vector2i(sum.x / cells.size(), sum.y / cells.size())
