class_name BossArenaGenerator
extends RefCounted

## Generates boss arenas for map generation
## Boss arenas are large open spaces (40+ cells) designed for boss encounters
## Features: clear sightlines, single entrance, optional exit, boss spawn markers

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")


## Generate boss arena placement in the map
## Ensures at least one boss arena per map (40+ cells)
## @param context: Generation context with grid and configuration
## @return: Array of boss arena Room objects
func generate_boss_arenas(context: GenerationContext) -> Array[Room]:
	var arenas: Array[Room] = []

	# Check if boss arenas are enabled
	if not context.config.enable_boss_arena:
		return arenas

	# Determine number of boss arenas based on map size
	var arena_count := _calculate_arena_count(context.grid_size)

	# Generate arenas
	for i in range(arena_count):
		var arena := _generate_single_arena(i, context)
		if arena != null:
			arenas.append(arena)

	return arenas


## Calculate number of boss arenas based on map size
## @param grid_size: Size of the grid
## @return: Number of arenas to generate (minimum 1)
func _calculate_arena_count(grid_size: Vector2i) -> int:
	var total_cells := grid_size.x * grid_size.y

	# At least 1 arena, more for larger maps
	if total_cells <= 64 * 64:
		return 1
	if total_cells <= 128 * 128:
		return 1
	# 256×256
	return 2


## Generate a single boss arena
## @param arena_id: Unique identifier for the arena
## @param context: Generation context
## @return: Boss arena Room object or null if placement failed
func _generate_single_arena(arena_id: int, context: GenerationContext) -> Room:
	var max_attempts := 50
	var attempt := 0

	while attempt < max_attempts:
		attempt += 1

		# Find suitable location for arena
		var center := _find_arena_location(context)

		# Generate arena shape (large open space)
		var arena := _create_arena_shape(center, arena_id, context)

		# Validate arena placement
		if _validate_arena_placement(arena, context):
			# Mark cells in grid
			_mark_arena_cells(arena, context.grid)

			# Create entrance and optional exit
			_create_arena_connections(arena, context)

			return arena

	push_warning("Failed to place boss arena after %d attempts" % max_attempts)
	return null


## Find suitable location for boss arena
## Prefers locations away from map edges and existing rooms
## @param context: Generation context
## @return: Center position for arena
func _find_arena_location(context: GenerationContext) -> Vector2i:
	var grid_center: Vector2i = context.grid_size / 2

	# Boss arenas should be placed in outer areas (not center)
	# This creates a sense of progression toward the boss
	var angle := context.rng.randf() * TAU
	var distance: float = context.rng.randf_range(0.4, 0.7) * min(grid_center.x, grid_center.y)

	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	var center := grid_center + Vector2i(int(offset.x), int(offset.y))

	# Ensure within bounds with margin
	var margin := 15
	center.x = clampi(center.x, margin, context.grid_size.x - margin)
	center.y = clampi(center.y, margin, context.grid_size.y - margin)

	return center


## Create boss arena shape with open configuration
## @param center: Center position for arena
## @param arena_id: Unique identifier
## @param context: Generation context
## @return: Room object representing the arena
func _create_arena_shape(center: Vector2i, arena_id: int, context: GenerationContext) -> Room:
	# Boss arenas are large open spaces (40-60 cells)
	var target_size := context.rng.randi_range(40, 60)

	# Create arena with rectangular or slightly organic shape
	var shape_type := context.rng.randf()
	var cells: Array[Vector2i] = []

	if shape_type < 0.6:
		# Rectangular arena (60% chance) - better for clear sightlines
		cells = _create_rectangular_arena(center, target_size, context)
	else:
		# Organic arena (40% chance) - more interesting layout
		cells = _create_organic_arena(center, target_size, context)

	# Create room object
	var arena := Room.new(arena_id, center, Room.RoomType.BOSS_ARENA)
	arena.cells = cells
	arena.metadata["is_boss_arena"] = true
	arena.metadata["has_clear_sightlines"] = true

	return arena


## Create rectangular boss arena
## @param center: Center position
## @param target_size: Target number of cells
## @param context: Generation context
## @return: Array of cell positions
func _create_rectangular_arena(
	center: Vector2i, target_size: int, _context: GenerationContext
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	# Calculate dimensions for rectangular arena
	# Prefer wider arenas (aspect ratio 1.2:1 to 1.5:1)
	var aspect_ratio := 1.3
	var height: int = int(sqrt(target_size / aspect_ratio))
	var width: int = int(target_size / height)

	# Ensure minimum dimensions
	width = maxi(width, 7)
	height = maxi(height, 6)

	# Generate rectangular grid of cells
	var half_width: int = width / 2
	var half_height: int = height / 2

	for dy in range(-half_height, half_height + 1):
		for dx in range(-half_width, half_width + 1):
			var cell_pos := center + Vector2i(dx, dy)
			cells.append(cell_pos)

	return cells


## Create organic boss arena using simplified shape grammar
## @param center: Center position
## @param target_size: Target number of cells
## @param context: Generation context
## @return: Array of cell positions
func _create_organic_arena(
	center: Vector2i, target_size: int, context: GenerationContext
) -> Array[Vector2i]:
	# Use shape grammar engine for organic shape
	var shape_engine := ShapeGrammarEngine.new()
	var poly_points := shape_engine.generate_room_shape(
		center, target_size, Room.RoomType.BOSS_ARENA, context.rng, context.theme
	)

	# Convert polygon to grid cells
	var cells := shape_engine.polygon_to_grid_cells(poly_points, context.grid_size)

	# Ensure open configuration by removing narrow passages
	cells = _ensure_open_configuration(cells)

	return cells


## Ensure arena has open configuration with clear sightlines
## Removes narrow passages and ensures minimum width
## @param cells: Arena cells
## @return: Modified cell array with open configuration
func _ensure_open_configuration(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.size() < 40:
		return cells

	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true

	# Remove cells that create narrow passages
	var to_remove: Array[Vector2i] = []

	for cell in cells:
		# Check if cell is part of a narrow passage (< 3 cells wide)
		if _is_narrow_passage(cell, cell_set):
			to_remove.append(cell)

	# Remove narrow passage cells
	for cell in to_remove:
		cells.erase(cell)

	return cells


## Check if a cell is part of a narrow passage
## @param cell: Cell to check
## @param cell_set: Set of all arena cells
## @return: True if cell is in narrow passage
func _is_narrow_passage(cell: Vector2i, cell_set: Dictionary) -> bool:
	# Check horizontal width
	var left_count := 0
	var right_count := 0

	for i in range(1, 4):
		if cell_set.has(cell + Vector2i(-i, 0)):
			left_count += 1
		else:
			break

	for i in range(1, 4):
		if cell_set.has(cell + Vector2i(i, 0)):
			right_count += 1
		else:
			break

	var horizontal_width := left_count + right_count + 1

	# Check vertical width
	var up_count := 0
	var down_count := 0

	for i in range(1, 4):
		if cell_set.has(cell + Vector2i(0, -i)):
			up_count += 1
		else:
			break

	for i in range(1, 4):
		if cell_set.has(cell + Vector2i(0, i)):
			down_count += 1
		else:
			break

	var vertical_width := up_count + down_count + 1

	# Cell is in narrow passage if both dimensions are < 3
	return horizontal_width < 3 and vertical_width < 3


## Validate boss arena placement
## Checks for overlaps, minimum size, and clear sightlines
## @param arena: Arena to validate
## @param context: Generation context
## @return: True if arena placement is valid
func _validate_arena_placement(arena: Room, context: GenerationContext) -> bool:
	# Check minimum size requirement (40+ cells)
	if arena.cells.size() < 40:
		return false

	# Check all cells are within grid bounds
	for cell in arena.cells:
		if (
			cell.x < 0
			or cell.x >= context.grid_size.x
			or cell.y < 0
			or cell.y >= context.grid_size.y
		):
			return false

	# Check for overlaps with existing rooms
	for existing_room in context.rooms:
		if _check_overlap(arena, existing_room):
			return false

	# Check for overlaps with outdoor areas
	for outdoor_area: Rect2i in context.outdoor_areas:
		if _check_area_overlap(arena, outdoor_area):
			return false

	# Check for overlaps with cave areas
	for cave_area: Rect2i in context.cave_areas:
		if _check_area_overlap(arena, cave_area):
			return false

	return true


## Check if two rooms overlap
## @param room1: First room
## @param room2: Second room
## @return: True if rooms overlap
func _check_overlap(room1: Room, room2: Room) -> bool:
	var room1_set := {}
	for cell in room1.cells:
		room1_set[cell] = true

	for cell in room2.cells:
		if room1_set.has(cell):
			return true

	return false


## Check if room overlaps with a rectangular area
## @param room: Room to check
## @param area: Rect2i area
## @return: True if overlap exists
func _check_area_overlap(room: Room, area: Rect2i) -> bool:
	for cell in room.cells:
		if area.has_point(cell):
			return true

	return false


## Mark arena cells in the grid
## @param arena: Arena room
## @param grid: Grid layout
func _mark_arena_cells(arena: Room, grid: Array[Array]) -> void:
	for cell_pos in arena.cells:
		if (
			cell_pos.y >= 0
			and cell_pos.y < grid.size()
			and cell_pos.x >= 0
			and cell_pos.x < grid[cell_pos.y].size()
		):
			var cell: Cell = grid[cell_pos.y][cell_pos.x]
			cell.type = Cell.Type.BOSS_ARENA
			cell.room_id = arena.id


## Create entrance and optional exit for boss arena
## @param arena: Arena room
## @param context: Generation context
func _create_arena_connections(arena: Room, context: GenerationContext) -> void:
	# Find edge cells suitable for connections
	var edge_cells := _find_edge_cells(arena)

	if edge_cells.is_empty():
		push_warning("No edge cells found for boss arena connections")
		return

	# Shuffle edge cells for random selection
	edge_cells.shuffle()

	# Create single entrance (required)
	if edge_cells.size() > 0:
		var entrance := edge_cells[0]
		arena.entrance_points.append(entrance)
		arena.metadata["entrance"] = entrance

	# Create optional exit (50% chance)
	if edge_cells.size() > 1 and context.rng.randf() < 0.5:
		# Find exit on opposite side from entrance
		var entrance_pos: Vector2i = arena.entrance_points[0]
		var exit := _find_opposite_edge_cell(entrance_pos, edge_cells, arena.center)

		if exit != entrance_pos:
			arena.entrance_points.append(exit)
			arena.metadata["exit"] = exit


## Find edge cells of arena (cells with at least one non-arena neighbor)
## @param arena: Arena room
## @return: Array of edge cell positions
func _find_edge_cells(arena: Room) -> Array[Vector2i]:
	var edge_cells: Array[Vector2i] = []
	var cell_set := {}

	for cell in arena.cells:
		cell_set[cell] = true

	# Find cells on the edge
	for cell in arena.cells:
		var is_edge := false

		# Check 4-directional neighbors
		var neighbors: Array[Vector2i] = [
			cell + Vector2i(1, 0),
			cell + Vector2i(-1, 0),
			cell + Vector2i(0, 1),
			cell + Vector2i(0, -1)
		]

		for neighbor: Vector2i in neighbors:
			if not cell_set.has(neighbor):
				is_edge = true
				break

		if is_edge:
			edge_cells.append(cell)

	return edge_cells


## Find edge cell on opposite side from entrance
## @param entrance: Entrance position
## @param edge_cells: Available edge cells
## @param center: Arena center
## @return: Exit position
func _find_opposite_edge_cell(
	entrance: Vector2i, edge_cells: Array[Vector2i], center: Vector2i
) -> Vector2i:
	# Calculate direction from center to entrance
	var entrance_dir := Vector2(entrance - center).normalized()

	# Find edge cell in opposite direction
	var best_exit := entrance
	var best_score := -INF

	for edge_cell in edge_cells:
		if edge_cell == entrance:
			continue

		var exit_dir := Vector2(edge_cell - center).normalized()

		# Calculate dot product (negative means opposite direction)
		var score := -entrance_dir.dot(exit_dir)

		if score > best_score:
			best_score = score
			best_exit = edge_cell

	return best_exit


## Place boss spawn marker at arena center
## @param arena: Arena room
## @param context: Generation context
func place_boss_spawn_marker(arena: Room, context: GenerationContext) -> void:
	# Place boss spawn at arena center
	var spawn_point := {
		"position": arena.center,
		"type": "boss",
		"arena_id": arena.id,
		"world_position": Vector3(arena.center.x * 2.0, 0.0, arena.center.y * 2.0)
	}

	context.monster_spawns.append(spawn_point)
	arena.metadata["boss_spawn"] = spawn_point


## Add elevated platforms or cover elements based on theme
## @param arena: Arena room
## @param context: Generation context
func add_arena_elements(arena: Room, context: GenerationContext) -> void:
	# Determine number of elements based on arena size
	var element_count: int = int(arena.cells.size() / 15)
	element_count = clampi(element_count, 2, 6)

	# Get theme-specific element types
	var element_types := _get_theme_elements(context.config.theme)

	# Place elements around the arena (not in center)
	var placed_elements: Array[Dictionary] = []

	for i in range(element_count):
		var element := _place_arena_element(arena, element_types, context)
		if element != null:
			placed_elements.append(element)

	arena.metadata["arena_elements"] = placed_elements


## Get theme-specific arena element types
## @param theme: MapTheme type
## @return: Array of element type strings
func _get_theme_elements(theme: GenerationConfig.ThemeType) -> Array[String]:
	var elements: Array[String] = []

	match theme:
		GenerationConfig.ThemeType.TECH:
			elements = ["platform", "cover_crate", "pillar"]
		GenerationConfig.ThemeType.HELL:
			elements = ["platform", "rock_pillar", "lava_pit"]
		GenerationConfig.ThemeType.URBAN:
			elements = ["platform", "concrete_barrier", "pillar"]
		GenerationConfig.ThemeType.CAVE:
			elements = ["platform", "stalagmite", "rock_formation"]
		GenerationConfig.ThemeType.JUMBLED:
			elements = ["platform", "cover_crate", "pillar", "rock_pillar"]

	return elements


## Place a single arena element
## @param arena: Arena room
## @param element_types: Available element types
## @param context: Generation context
## @return: Element dictionary or null
func _place_arena_element(
	arena: Room, element_types: Array[String], context: GenerationContext
) -> Dictionary:
	# Select random element type
	var element_type: String = element_types[context.rng.randi() % element_types.size()]

	# Find suitable position (away from center and edges)
	var position := _find_element_position(arena, context)

	if position == Vector2i(-1, -1):
		return {}

	# Create element data
	var element := {
		"type": element_type,
		"position": position,
		"world_position": Vector3(position.x * 2.0, 0.0, position.y * 2.0),
		"arena_id": arena.id
	}

	return element


## Find suitable position for arena element
## @param arena: Arena room
## @param context: Generation context
## @return: Position or Vector2i(-1, -1) if no suitable position found
func _find_element_position(arena: Room, context: GenerationContext) -> Vector2i:
	var max_attempts := 20
	var center := arena.center

	for attempt in range(max_attempts):
		# Select random cell from arena
		var cell: Vector2i = arena.cells[context.rng.randi() % arena.cells.size()]

		# Check if cell is not too close to center (leave center clear)
		var dist_to_center := _manhattan_distance(cell, center)

		if dist_to_center >= 4 and dist_to_center <= 8:
			return cell

	return Vector2i(-1, -1)


## Calculate Manhattan distance between two positions
## @param a: First position
## @param b: Second position
## @return: Manhattan distance
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
