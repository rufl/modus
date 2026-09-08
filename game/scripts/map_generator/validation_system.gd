extends RefCounted
class_name ValidationSystem

## ValidationSystem
## Provides validation methods for each generation phase
## Validates connectivity, navigation mesh coverage, spawn points, and progression order

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")


## Validation result structure
class ValidationResult:
	var is_valid: bool = false
	var error_message: String = ""
	var warnings: Array[String] = []

	func _init(valid: bool = false, error: String = "") -> void:
		is_valid = valid
		error_message = error


## Validate grid layout phase output
func validate_grid_layout(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.grid or context.grid.is_empty():
		result.error_message = "Grid is empty or null"
		return result

	# Check grid dimensions match configuration
	var expected_height: int = context.config.map_size.y
	var expected_width: int = context.config.map_size.x

	if context.grid.size() != expected_height:
		result.error_message = (
			"Grid height mismatch: expected %d, got %d" % [expected_height, context.grid.size()]
		)
		return result

	for row_data: Variant in context.grid:
		var row: Array = row_data as Array
		if not row:
			result.error_message = "Grid contains invalid row"
			return result

		if row.size() != expected_width:
			result.error_message = (
				"Grid width mismatch: expected %d, got %d" % [expected_width, row.size()]
			)
			return result

	result.is_valid = true
	return result


## Validate room generation phase output
func validate_room_generation(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.rooms or context.rooms.is_empty():
		result.error_message = "No rooms generated"
		return result

	# Validate each room
	for room_variant: Variant in context.rooms:
		var typed_room: Room = room_variant as Room
		if not typed_room:
			continue

		if typed_room.cells.is_empty():
			result.error_message = "Room %d has no cells" % typed_room.id
			return result

		if typed_room.entrance_points.is_empty():
			result.warnings.append("Room %d has no entrance points" % typed_room.id)

	result.is_valid = true
	return result


## Validate connectivity - all rooms reachable from player start
func validate_connectivity(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	# Find player start position
	var player_start := _find_player_start_position(context)
	if player_start == Vector2i(-1, -1):
		result.error_message = "No valid player start position found"
		return result

	# Perform flood fill from player start
	var reachable_count := _flood_fill_count(context.grid, player_start)
	var total_walkable := _count_walkable_cells(context.grid)

	if total_walkable == 0:
		result.error_message = "No walkable cells in map"
		return result

	# At least 90% of walkable cells should be reachable
	var coverage_ratio := float(reachable_count) / float(total_walkable)
	if coverage_ratio < 0.9:
		result.error_message = (
			"Connectivity validation failed: only %.1f%% of walkable area reachable (minimum 90%%)"
			% (coverage_ratio * 100.0)
		)
		return result

	if coverage_ratio < 0.95:
		result.warnings.append(
			"Connectivity coverage is %.1f%% (below ideal 95%%)" % (coverage_ratio * 100.0)
		)

	result.is_valid = true
	return result


## Validate navigation mesh coverage
func validate_navigation_mesh(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.navigation_region:
		result.error_message = "Navigation region is null"
		return result

	var navmesh: NavigationMesh = context.navigation_region.navigation_mesh
	if not navmesh:
		result.error_message = "Navigation mesh is null"
		return result

	# Calculate approximate navigation mesh coverage
	var polygon_count := navmesh.get_polygon_count()
	if polygon_count == 0:
		result.error_message = "Navigation mesh has no polygons"
		return result

	# Approximate coverage: each polygon covers ~4 square meters
	var navmesh_coverage := float(polygon_count) * 4.0
	var walkable_area := float(_count_walkable_cells(context.grid)) * 4.0  # Each cell is 2x2m

	if walkable_area == 0:
		result.error_message = "No walkable area in map"
		return result

	var coverage_ratio := navmesh_coverage / walkable_area

	# Navigation mesh should cover at least 90% of walkable area
	if coverage_ratio < 0.9:
		result.error_message = (
			"Navigation mesh covers only %.1f%% of walkable area (minimum 90%%)"
			% (coverage_ratio * 100.0)
		)
		return result

	if coverage_ratio < 0.95:
		result.warnings.append(
			"Navigation mesh coverage is %.1f%% (below ideal 95%%)" % (coverage_ratio * 100.0)
		)

	result.is_valid = true
	return result


## Validate monster spawn points have navigation coverage
func validate_monster_spawns(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.monster_spawns:
		result.warnings.append("No monster spawns to validate")
		result.is_valid = true
		return result

	if not context.navigation_region or not context.navigation_region.navigation_mesh:
		result.error_message = "Cannot validate monster spawns: navigation mesh not available"
		return result

	var invalid_spawns: int = 0

	for spawn_data: Variant in context.monster_spawns:
		var spawn: Dictionary = spawn_data as Dictionary
		if not spawn:
			continue

		var spawn_pos: Vector3 = spawn.get("world_position", Vector3.ZERO)

		# Check if spawn position is on navigation mesh
		var closest_point := NavigationServer3D.map_get_closest_point(
			context.navigation_region.get_navigation_map(), spawn_pos
		)

		# If closest point is too far, spawn is not on navmesh
		var distance := spawn_pos.distance_to(closest_point)
		if distance > 2.0:  # 2 meter tolerance
			invalid_spawns += 1
			result.warnings.append(
				"Monster spawn at %s is %.1fm from navigation mesh" % [spawn_pos, distance]
			)

	if invalid_spawns > 0:
		var invalid_ratio := float(invalid_spawns) / float(context.monster_spawns.size())
		if invalid_ratio > 0.1:  # More than 10% invalid
			result.error_message = (
				"%d/%d monster spawns lack navigation coverage (%.1f%%)"
				% [invalid_spawns, context.monster_spawns.size(), invalid_ratio * 100.0]
			)
			return result

	result.is_valid = true
	return result


## Validate key-lock progression order
func validate_key_lock_progression(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	if not context.key_placements or context.key_placements.is_empty():
		result.warnings.append("No key-lock system to validate")
		result.is_valid = true
		return result

	# Build a map of key colors to their positions
	var key_positions: Dictionary = {}  # Color -> Vector2i
	var locked_door_positions: Dictionary = {}  # Color -> Array[Vector2i]

	for placement_data: Variant in context.key_placements:
		var placement: Dictionary = placement_data as Dictionary
		if not placement:
			continue

		if placement.get("is_key", false):
			var color: String = placement.get("color", "")
			var pos: Vector2i = placement.get("grid_position", Vector2i(-1, -1))
			if color != "" and pos != Vector2i(-1, -1):
				key_positions[color] = pos
		elif placement.get("is_door", false):
			var color: String = placement.get("color", "")
			var pos: Vector2i = placement.get("grid_position", Vector2i(-1, -1))
			if color != "" and pos != Vector2i(-1, -1):
				if not locked_door_positions.has(color):
					locked_door_positions[color] = []
				locked_door_positions[color].append(pos)

	# Validate each locked door has a corresponding key placed earlier
	for color: String in locked_door_positions:
		if not key_positions.has(color):
			result.error_message = "Locked door with color '%s' has no corresponding key" % color
			return result

		var key_pos: Vector2i = key_positions[color]
		var doors: Array = locked_door_positions[color]

		# Check if key is reachable before any door (simplified check)
		# In a full implementation, this would use pathfinding to verify order
		for door_pos: Vector2i in doors:
			# Simple heuristic: key should be "earlier" in the map (closer to start)
			# This is a placeholder - full implementation would need proper analysis
			if key_pos.length() > door_pos.length():
				result.warnings.append(
					(
						"Key '%s' may be placed after its locked door " % color
						+ "(needs progression analysis)"
					)
				)

	result.is_valid = true
	return result


## Validate player start position is accessible
func validate_player_start(context: RefCounted) -> ValidationResult:
	var result := ValidationResult.new()

	var player_start := _find_player_start_position(context)
	if player_start == Vector2i(-1, -1):
		result.error_message = "No valid player start position found"
		return result

	# Check if player start is on a walkable cell
	if player_start.y < 0 or player_start.y >= context.grid.size():
		result.error_message = "Player start position out of bounds (Y)"
		return result

	if player_start.x < 0 or player_start.x >= context.grid[0].size():
		result.error_message = "Player start position out of bounds (X)"
		return result

	var cell: Cell = context.grid[player_start.y][player_start.x]
	if not _is_walkable_cell(cell):
		result.error_message = "Player start position is not on a walkable cell"
		return result

	result.is_valid = true
	return result


## Find player start position in the grid
func _find_player_start_position(context: RefCounted) -> Vector2i:
	# Look for player start marker in context
	if context.has("player_start_position") and context.player_start_position != Vector2i(-1, -1):
		return context.player_start_position

	# Fallback: find first room's center
	if context.rooms and not context.rooms.is_empty():
		var first_room: Room = context.rooms[0]
		if (
			first_room.center.y >= 0
			and first_room.center.y < context.grid.size()
			and first_room.center.x >= 0
			and first_room.center.x < context.grid[first_room.center.y].size()
			and _is_walkable_cell(context.grid[first_room.center.y][first_room.center.x])
		):
			return first_room.center
		for room_cell: Vector2i in first_room.cells:
			if (
				room_cell.y >= 0
				and room_cell.y < context.grid.size()
				and room_cell.x >= 0
				and room_cell.x < context.grid[room_cell.y].size()
				and _is_walkable_cell(context.grid[room_cell.y][room_cell.x])
			):
				return room_cell

	# Last resort: find first walkable cell
	for y in range(context.grid.size()):
		for x in range(context.grid[y].size()):
			var cell: Cell = context.grid[y][x]
			if _is_walkable_cell(cell):
				return Vector2i(x, y)

	return Vector2i(-1, -1)


## Count walkable cells in grid
func _count_walkable_cells(grid: Array) -> int:
	var count := 0
	for row_data: Variant in grid:
		var row: Array = row_data as Array
		if not row:
			continue
		for cell_data: Variant in row:
			var cell: Cell = cell_data as Cell
			if cell and _is_walkable_cell(cell):
				count += 1
	return count


## Check if cell is walkable
func _is_walkable_cell(cell: Cell) -> bool:
	return (
		cell.type
		in [
			Cell.Type.ROOM,
			Cell.Type.HALLWAY,
			Cell.Type.OUTDOOR,
			Cell.Type.CAVE,
			Cell.Type.BOSS_ARENA,
			Cell.Type.SECRET
		]
	)


## Flood fill to count reachable cells from start position
func _flood_fill_count(grid: Array, start: Vector2i) -> int:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	var count: int = 0

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()

		if visited.has(current):
			continue

		# Check bounds
		if current.y < 0 or current.y >= grid.size():
			continue
		if current.x < 0 or current.x >= grid[0].size():
			continue

		var cell: Cell = grid[current.y][current.x]
		if not _is_walkable_cell(cell):
			continue

		visited[current] = true
		count += 1

		# Add neighbors (4-directional)
		queue.append(Vector2i(current.x + 1, current.y))
		queue.append(Vector2i(current.x - 1, current.y))
		queue.append(Vector2i(current.x, current.y + 1))
		queue.append(Vector2i(current.x, current.y - 1))

	return count
