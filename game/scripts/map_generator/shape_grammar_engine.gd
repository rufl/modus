class_name ShapeGrammarEngine
extends RefCounted

## Generates organic room shapes using L-system rules
## Creates non-rectangular rooms with natural-looking boundaries

# L-system configuration
const BASE_AXIOM := "F+F+F+F"  # Square starting shape
const DEFAULT_ITERATIONS := 2  # Number of L-system expansions
const TURN_ANGLE := PI / 2  # 90-degree turns
const STEP_SIZE := 2.0  # Grid cell size for polygon generation

# Default L-system rules for organic growth
const DEFAULT_RULES := {"F": "F+F-F-FF+F+F-F"}  # Expansion rule for organic growth

# MapTheme-specific rule sets (can be extended)
var theme_rules: Dictionary = {}


## Apply L-system rules to expand a string
## @param input_string: The current L-system string
## @param rules: Dictionary mapping characters to replacement strings
## @return: Expanded L-system string
func _apply_lsystem_rules(input_string: String, rules: Dictionary) -> String:
	var result := ""

	for character: String in input_string:
		if rules.has(character):
			result += rules[character]
		else:
			result += character

	return result


## Generate an organic room shape using L-system rules
## @param center: Grid center position for the room
## @param target_size: Target number of cells for the room
## @param room_type: Type of room (affects complexity)
## @param rng: RandomNumberGenerator for deterministic generation
## @param theme: Optional theme for theme-specific rules
## @return: PackedVector2Array of polygon points defining the room shape
func generate_room_shape(
	center: Vector2i,
	target_size: int,
	room_type: Room.RoomType,
	rng: RandomNumberGenerator,
	theme: Variant = null
) -> PackedVector2Array:
	# Select rules based on theme or use defaults
	var rules := _get_rules_for_theme(theme)

	# Adjust iterations based on room type for complexity variation
	var iterations := _get_iterations_for_room_type(room_type, rng)

	# Start with base axiom
	var lsystem_string := BASE_AXIOM

	# Apply L-system iterations
	for i in range(iterations):
		lsystem_string = _apply_lsystem_rules(lsystem_string, rules)

	# Convert L-system string to polygon points
	var points := _lsystem_to_polygon(lsystem_string, Vector2(center))

	# Simplify polygon to match target size
	points = _simplify_polygon(points, target_size, rng)

	return points


## Get L-system rules for a specific theme
## @param theme: MapTheme variant (can be null for default)
## @return: Dictionary of L-system rules
func _get_rules_for_theme(theme: Variant) -> Dictionary:
	if theme == null:
		return DEFAULT_RULES

	# Try to get theme name from theme object
	var theme_name := ""

	# Handle different theme representations
	if theme is String:
		theme_name = theme
	elif theme is Dictionary and theme.has("name"):
		theme_name = theme["name"]
	elif theme is Object and "name" in theme:
		theme_name = theme.name

	if theme_name.is_empty():
		return DEFAULT_RULES

	return load_theme_rules(theme_name)


## Get number of L-system iterations based on room type
## @param room_type: Type of room
## @param rng: RandomNumberGenerator for variation
## @return: Number of iterations (1-3)
func _get_iterations_for_room_type(room_type: Room.RoomType, rng: RandomNumberGenerator) -> int:
	match room_type:
		Room.RoomType.SMALL:
			return 1  # Simple shapes for small rooms
		Room.RoomType.MEDIUM:
			return rng.randi_range(1, 2)  # Moderate complexity
		Room.RoomType.LARGE:
			return 2  # More complex shapes
		Room.RoomType.BOSS_ARENA:
			return rng.randi_range(2, 3)  # Most complex for boss arenas
		_:
			return DEFAULT_ITERATIONS


## Convert L-system string to 2D polygon points
## @param lsystem_string: L-system command string (F, +, -)
## @param start_pos: Starting position for polygon generation
## @return: PackedVector2Array of polygon points
func _lsystem_to_polygon(lsystem_string: String, start_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var current_pos := start_pos
	var angle := 0.0

	# Add starting point
	points.append(current_pos)

	# Interpret L-system commands
	for character: String in lsystem_string:
		match character:
			"F":  # Move forward and add point
				var direction := Vector2.from_angle(angle)
				current_pos += direction * STEP_SIZE
				points.append(current_pos)
			"+":  # Turn right
				angle += TURN_ANGLE
			"-":  # Turn left
				angle -= TURN_ANGLE
			# Ignore other characters

	return points


## @param target_size: Target number of cells
## @param _rng: RandomNumberGenerator for variation (unused)
## @return: Simplified PackedVector2Array
func _simplify_polygon(
	points: PackedVector2Array, target_size: int, _rng: RandomNumberGenerator
) -> PackedVector2Array:
	if points.size() <= 3:
		return points

	# Calculate current approximate area (in cells)
	var current_area := _estimate_polygon_area(points) / (STEP_SIZE * STEP_SIZE)

	# If area is close to target, return as-is
	if abs(current_area - target_size) < target_size * 0.2:
		return points

	# Scale polygon to match target size
	var scale_factor := sqrt(float(target_size) / max(current_area, 1.0))
	var center := _get_polygon_center(points)
	var scaled_points := PackedVector2Array()

	for point in points:
		var offset := (point - center) * scale_factor
		scaled_points.append(center + offset)

	# Reduce point count if too many (keep every Nth point)
	if scaled_points.size() > target_size * 2:
		var reduction_factor := int(ceil(float(scaled_points.size()) / (target_size * 2)))
		var reduced_points := PackedVector2Array()

		for i in range(scaled_points.size()):
			if i % reduction_factor == 0:
				reduced_points.append(scaled_points[i])

		scaled_points = reduced_points

	return scaled_points


## Estimate polygon area using shoelace formula
## @param points: Polygon points
## @return: Approximate area
func _estimate_polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0

	var area := 0.0
	var n := points.size()

	for i in range(n):
		var j := (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y

	return abs(area) / 2.0


## Get center point of polygon
## @param points: Polygon points
## @return: Center position
func _get_polygon_center(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO

	var sum := Vector2.ZERO
	for point in points:
		sum += point

	return sum / points.size()


## Convert polygon points to grid cells
## @param points: Polygon points in world space
## @param grid_size: Size of the grid for bounds checking
## @return: Array of Vector2i grid positions
func polygon_to_grid_cells(points: PackedVector2Array, grid_size: Vector2i) -> Array[Vector2i]:
	if points.size() < 3:
		return []

	var cells: Array[Vector2i] = []
	var bounds := _get_polygon_bounds(points)

	# Scan all cells within polygon bounds
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
			var cell_pos := Vector2i(x, y)
			var world_pos := Vector2(x, y) * STEP_SIZE

			# Check if cell center is inside polygon
			if _is_point_in_polygon(world_pos, points):
				# Ensure within grid bounds
				if (
					cell_pos.x >= 0
					and cell_pos.x < grid_size.x
					and cell_pos.y >= 0
					and cell_pos.y < grid_size.y
				):
					cells.append(cell_pos)

	# Ensure connectivity by filling gaps
	cells = _ensure_connected_cells(cells)

	return cells


## Get bounding rectangle for polygon
## @param points: Polygon points
## @return: Rect2 bounding box
func _get_polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()

	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y

	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	# Convert to grid coordinates
	min_x = floor(min_x / STEP_SIZE)
	max_x = ceil(max_x / STEP_SIZE)
	min_y = floor(min_y / STEP_SIZE)
	max_y = ceil(max_y / STEP_SIZE)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


## Check if a point is inside a polygon using ray casting
## @param point: Point to test
## @param polygon: Polygon points
## @return: True if point is inside polygon
func _is_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false

	var inside := false
	var n := polygon.size()

	for i in range(n):
		var j := (i + 1) % n
		var pi := polygon[i]
		var pj := polygon[j]

		# Ray casting algorithm
		if (
			((pi.y > point.y) != (pj.y > point.y))
			and (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x)
		):
			inside = !inside

	return inside


## Ensure all cells are connected using flood fill
## @param cells: Array of grid cells
## @return: Connected array of cells
func _ensure_connected_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return cells

	# Create a set for fast lookup
	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true

	# Flood fill from first cell
	var connected: Array[Vector2i] = []
	var visited := {}
	var queue: Array[Vector2i] = [cells[0]]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()

		if visited.has(current):
			continue

		visited[current] = true
		connected.append(current)

		# Check 4-directional neighbors
		var neighbors := [
			current + Vector2i(1, 0),
			current + Vector2i(-1, 0),
			current + Vector2i(0, 1),
			current + Vector2i(0, -1)
		]

		for neighbor: Vector2i in neighbors:
			if cell_set.has(neighbor) and not visited.has(neighbor):
				queue.append(neighbor)

	# If not all cells are connected, add bridge cells
	if connected.size() < cells.size():
		# Find disconnected cells and connect them
		for cell in cells:
			if not visited.has(cell):
				# Find nearest connected cell and add bridge
				var nearest := _find_nearest_cell(cell, connected)
				var bridge := _create_bridge(cell, nearest)
				for bridge_cell in bridge:
					if not visited.has(bridge_cell):
						connected.append(bridge_cell)
						visited[bridge_cell] = true

	return connected


## Find nearest cell in a list to a target cell
## @param target: Target cell position
## @param cells: List of cells to search
## @return: Nearest cell position
func _find_nearest_cell(target: Vector2i, cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return target

	var nearest := cells[0]
	var min_dist := _manhattan_distance(target, nearest)

	for cell in cells:
		var dist := _manhattan_distance(target, cell)
		if dist < min_dist:
			min_dist = dist
			nearest = cell

	return nearest


## Create a bridge of cells between two positions
## @param from: Starting position
## @param to: Ending position
## @return: Array of cells forming the bridge
func _create_bridge(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var bridge: Array[Vector2i] = []
	var current := from

	# Simple pathfinding: move horizontally then vertically
	while current.x != to.x:
		current.x += 1 if current.x < to.x else -1
		bridge.append(current)

	while current.y != to.y:
		current.y += 1 if current.y < to.y else -1
		bridge.append(current)

	return bridge


## Calculate Manhattan distance between two cells
## @param a: First cell
## @param b: Second cell
## @return: Manhattan distance
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Check if room shape avoids single-cell-wide passages
## @param cells: Array of room cells
## @return: True if no single-cell-wide passages exist
func validate_no_narrow_passages(cells: Array[Vector2i]) -> bool:
	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true

	# Check each cell for narrow passage patterns
	for cell in cells:
		var horizontal_neighbors := 0
		var vertical_neighbors := 0

		# Check horizontal neighbors
		if cell_set.has(cell + Vector2i(1, 0)):
			horizontal_neighbors += 1
		if cell_set.has(cell + Vector2i(-1, 0)):
			horizontal_neighbors += 1

		# Check vertical neighbors
		if cell_set.has(cell + Vector2i(0, 1)):
			vertical_neighbors += 1
		if cell_set.has(cell + Vector2i(0, -1)):
			vertical_neighbors += 1

		# If cell has neighbors in only one direction, it might be a narrow passage
		if (
			(horizontal_neighbors > 0 and vertical_neighbors == 0)
			or (vertical_neighbors > 0 and horizontal_neighbors == 0)
		):
			# Check if this is part of a single-cell-wide corridor
			var perpendicular_neighbors := _count_perpendicular_neighbors(cell, cell_set)
			if perpendicular_neighbors == 0:
				return false  # Found a single-cell-wide passage

	return true


## Count neighbors perpendicular to the main direction
## @param cell: Cell to check
## @param cell_set: Set of all cells in the room
## @return: Number of perpendicular neighbors
func _count_perpendicular_neighbors(cell: Vector2i, cell_set: Dictionary) -> int:
	var count := 0

	# Check all 8 directions for perpendicular connections
	var diagonals := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

	for diag: Vector2i in diagonals:
		if cell_set.has(cell + diag):
			count += 1

	return count


## Generate a complete room with specified type
## @param center: Grid center position for the room
## @param room_type: Type of room to generate
## @param room_id: Unique identifier for the room
## @param context: Generation context with grid and RNG
## @return: Room object with shape and metadata
func generate_room(
	center: Vector2i, room_type: Room.RoomType, room_id: int, context: GenerationContext
) -> Room:
	# Determine target cell count based on room type
	var target_size := _get_target_size_for_room_type(room_type, context.rng)

	# Generate organic shape
	var poly_points := generate_room_shape(
		center, target_size, room_type, context.rng, context.theme
	)

	# Convert to grid cells
	var cells := polygon_to_grid_cells(poly_points, context.grid_size)

	# Ensure minimum size requirements are met
	cells = _ensure_minimum_size(cells, room_type, center, context.grid_size)

	# Create room object
	var room := Room.new(room_id, center, room_type)
	room.poly_points = poly_points
	room.cells = cells

	# Find connection points (cells on the edge of the room)
	room.entrance_points = _find_entrance_points(cells)

	# Ensure at least one connection point
	if room.entrance_points.is_empty():
		# Add center as fallback connection point
		room.entrance_points.append(center)

	return room


## Get target cell count for a room type
## @param room_type: Type of room
## @param rng: RandomNumberGenerator for variation
## @return: Target number of cells
func _get_target_size_for_room_type(room_type: Room.RoomType, rng: RandomNumberGenerator) -> int:
	match room_type:
		Room.RoomType.SMALL:
			return rng.randi_range(4, 8)
		Room.RoomType.MEDIUM:
			return rng.randi_range(9, 16)
		Room.RoomType.LARGE:
			return rng.randi_range(17, 32)
		Room.RoomType.BOSS_ARENA:
			return rng.randi_range(40, 60)
		_:
			return 12  # Default to medium size


## Ensure room meets minimum size requirements
## @param cells: Current room cells
## @param room_type: Type of room
## @param center: Room center position
## @param grid_size: Grid dimensions for bounds checking
## @return: Adjusted cell array meeting minimum size
func _ensure_minimum_size(
	cells: Array[Vector2i], room_type: Room.RoomType, center: Vector2i, grid_size: Vector2i
) -> Array[Vector2i]:
	var min_size := _get_minimum_size_for_room_type(room_type)

	if cells.size() >= min_size:
		return cells

	# Add cells in a spiral pattern from center until minimum size is reached
	var result := cells.duplicate()
	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true

	var radius := 1
	while result.size() < min_size and radius < 20:
		var added := false

		# Check cells at current radius
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check perimeter

				var candidate := center + Vector2i(dx, dy)

				# Check if valid and not already added
				if (
					candidate.x >= 0
					and candidate.x < grid_size.x
					and candidate.y >= 0
					and candidate.y < grid_size.y
					and not cell_set.has(candidate)
				):
					result.append(candidate)
					cell_set[candidate] = true
					added = true

					if result.size() >= min_size:
						return result

		if not added:
			break  # No more cells can be added

		radius += 1

	return result


## Get minimum cell count for a room type
## @param room_type: Type of room
## @return: Minimum number of cells
func _get_minimum_size_for_room_type(room_type: Room.RoomType) -> int:
	match room_type:
		Room.RoomType.SMALL:
			return 4
		Room.RoomType.MEDIUM:
			return 9
		Room.RoomType.LARGE:
			return 17
		Room.RoomType.BOSS_ARENA:
			return 40
		_:
			return 9


## Find potential entrance points for hallway connections
## @param cells: Room cells
## @return: Array of edge cells suitable for connections
func _find_entrance_points(cells: Array[Vector2i]) -> Array[Vector2i]:
	var entrance_points: Array[Vector2i] = []
	var cell_set := {}

	for cell in cells:
		cell_set[cell] = true

	# Find cells on the edge (have at least one non-room neighbor)
	for cell in cells:
		var is_edge := false

		# Check 4-directional neighbors
		var neighbors := [
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
			entrance_points.append(cell)

	# Limit to reasonable number of entrance points (every 3rd edge cell)
	if entrance_points.size() > 8:
		var filtered: Array[Vector2i] = []
		for i in range(entrance_points.size()):
			if i % 3 == 0:
				filtered.append(entrance_points[i])
		entrance_points = filtered

	return entrance_points


## Generate multiple rooms for a map
## @param room_count: Number of rooms to generate
## @param context: Generation context
## @return: Array of generated rooms
func generate_rooms(room_count: int, context: GenerationContext) -> Array[Room]:
	var rooms: Array[Room] = []
	var grid_center: Vector2i = context.grid_size / 2
	var placement_attempts := 0
	var max_attempts := room_count * 10

	# Generate rooms with varied types
	var room_types := _determine_room_types(room_count, context)

	for i in range(room_count):
		var room: Room = null
		var placed := false

		while not placed and placement_attempts < max_attempts:
			placement_attempts += 1

			# Generate random position (prefer center area)
			var offset_x: int = context.rng.randi_range(-grid_center.x / 2, grid_center.x / 2)
			var offset_y: int = context.rng.randi_range(-grid_center.y / 2, grid_center.y / 2)
			var center := grid_center + Vector2i(offset_x, offset_y)

			# Generate room
			room = generate_room(center, room_types[i], i, context)

			# Check if room fits without overlapping existing rooms
			if _can_place_room(room, rooms, context.grid):
				placed = true
				rooms.append(room)

		if not placed:
			push_warning("Failed to place room %d after %d attempts" % [i, placement_attempts])

	return rooms


## Determine room types for generation
## @param room_count: Total number of rooms
## @param context: Generation context
## @return: Array of room types
func _determine_room_types(room_count: int, context: GenerationContext) -> Array[Room.RoomType]:
	var types: Array[Room.RoomType] = []

	# Ensure at least one boss arena if enabled
	if context.config.enable_boss_arena:
		types.append(Room.RoomType.BOSS_ARENA)

	# Fill remaining with varied types
	var remaining := room_count - types.size()
	for i in range(remaining):
		var rand := context.rng.randf()

		if rand < 0.3:
			types.append(Room.RoomType.SMALL)
		elif rand < 0.7:
			types.append(Room.RoomType.MEDIUM)
		else:
			types.append(Room.RoomType.LARGE)

	# Shuffle to randomize placement order
	types.shuffle()

	return types


## Check if a room can be placed without overlapping
## @param room: Room to place
## @param existing_rooms: Already placed rooms
## @param grid: Grid layout
## @return: True if room can be placed
func _can_place_room(room: Room, existing_rooms: Array[Room], grid: Array[Array]) -> bool:
	# Check grid bounds
	for cell in room.cells:
		if cell.x < 0 or cell.x >= grid[0].size() or cell.y < 0 or cell.y >= grid.size():
			return false

	# Check overlap with existing rooms (allow 1 cell spacing)
	for existing in existing_rooms:
		for cell in room.cells:
			for existing_cell in existing.cells:
				var dist := _manhattan_distance(cell, existing_cell)
				if dist < 2:  # Minimum 1 cell spacing
					return false

	return true


## Load theme-specific L-system rules from rule modules
## @param theme_name: Name of the theme (e.g., "tech", "hell", "urban")
## @return: Dictionary of L-system rules for the theme
func load_theme_rules(theme_name: String) -> Dictionary:
	if theme_name.is_empty():
		return DEFAULT_RULES

	# Check if rules are already cached
	if theme_rules.has(theme_name):
		return theme_rules[theme_name]

	# Try to load theme-specific rule file
	var rule_path := (
		"res://game/data/map_generator/themes/%s/shape_rules.json" % theme_name.to_lower()
	)

	if not FileAccess.file_exists(rule_path):
		# Fall back to default rules
		theme_rules[theme_name] = DEFAULT_RULES
		return DEFAULT_RULES

	# Load and parse JSON rules
	var file := FileAccess.open(rule_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open theme rules file: %s" % rule_path)
		theme_rules[theme_name] = DEFAULT_RULES
		return DEFAULT_RULES

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		push_warning("Failed to parse theme rules JSON: %s" % rule_path)
		theme_rules[theme_name] = DEFAULT_RULES
		return DEFAULT_RULES

	var data: Variant = json.data

	# Extract L-system rules from JSON
	var rules := {}
	if data is Dictionary and data.has("lsystem_rules"):
		rules = data["lsystem_rules"]
	else:
		rules = DEFAULT_RULES

	# Cache the rules
	theme_rules[theme_name] = rules
	return rules


## Apply theme-specific modifications to room generation
## @param room: Room to modify
## @param theme_name: Name of the theme
## @param context: Generation context
func apply_theme_modifications(room: Room, theme_name: String, _context: GenerationContext) -> void:
	if theme_name.is_empty():
		return

	# Load theme configuration
	var theme_config := _load_theme_config(theme_name)

	if theme_config.is_empty():
		return

	# Apply theme-specific metadata
	if theme_config.has("room_metadata"):
		var metadata: Variant = theme_config["room_metadata"]

		# Apply based on room type
		var type_key := _get_room_type_key(room.type)
		if metadata.has(type_key):
			var type_metadata: Variant = metadata[type_key]
			for key: String in type_metadata:
				room.metadata[key] = type_metadata[key]

	# Apply shape adjustments
	if theme_config.has("shape_adjustments"):
		var adjustments: Variant = theme_config["shape_adjustments"]

		# Adjust room complexity
		if adjustments.has("complexity_multiplier"):
			var multiplier: float = adjustments["complexity_multiplier"]
			# This would affect future generations, stored in metadata
			room.metadata["complexity_multiplier"] = multiplier

		# Adjust room spacing
		if adjustments.has("min_spacing"):
			room.metadata["min_spacing"] = adjustments["min_spacing"]


## Load theme configuration from JSON file
## @param theme_name: Name of the theme
## @return: Dictionary with theme configuration
func _load_theme_config(theme_name: String) -> Dictionary:
	var config_path := (
		"res://game/data/map_generator/themes/%s/theme_config.json" % theme_name.to_lower()
	)

	if not FileAccess.file_exists(config_path):
		return {}

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		return {}

	return json.data if json.data is Dictionary else {}


## Get room type key for theme configuration
## @param room_type: Room type enum
## @return: String key for configuration lookup
func _get_room_type_key(room_type: Room.RoomType) -> String:
	match room_type:
		Room.RoomType.SMALL:
			return "small"
		Room.RoomType.MEDIUM:
			return "medium"
		Room.RoomType.LARGE:
			return "large"
		Room.RoomType.BOSS_ARENA:
			return "boss_arena"
		_:
			return "medium"


## Create example theme rule files for documentation
## This is a helper function to generate example theme configurations
static func create_example_theme_files() -> void:
	# Example Tech theme rules
	var tech_rules := {"lsystem_rules": {"F": "F+F-F-FF+F+F-F"}}  # Default organic growth

	var tech_config := {
		"name": "tech",
		"description": "High-tech facility with clean geometric shapes",
		"room_metadata":
		{
			"small": {"lighting_intensity": 1.2, "wall_height": 3.0},
			"medium": {"lighting_intensity": 1.0, "wall_height": 3.5},
			"large": {"lighting_intensity": 0.8, "wall_height": 4.0},
			"boss_arena": {"lighting_intensity": 1.5, "wall_height": 6.0}
		},
		"shape_adjustments": {"complexity_multiplier": 1.0, "min_spacing": 2}
	}

	# Example Hell theme rules (more chaotic)
	var hell_rules := {"lsystem_rules": {"F": "F+F-F+F-F-F+F"}}  # More chaotic growth pattern

	var hell_config := {
		"name": "hell",
		"description": "Demonic realm with irregular organic shapes",
		"room_metadata":
		{
			"small": {"lighting_intensity": 0.6, "wall_height": 2.5},
			"medium": {"lighting_intensity": 0.5, "wall_height": 3.0},
			"large": {"lighting_intensity": 0.4, "wall_height": 4.5},
			"boss_arena": {"lighting_intensity": 0.8, "wall_height": 8.0}
		},
		"shape_adjustments": {"complexity_multiplier": 1.5, "min_spacing": 1}
	}

	print("Example theme configurations created (not saved to disk)")
	print("Tech rules: ", JSONHelper.safe_stringify(tech_rules, "\t"))
	print("Tech config: ", JSONHelper.safe_stringify(tech_config, "\t"))
	print("Hell rules: ", JSONHelper.safe_stringify(hell_rules, "\t"))
	print("Hell config: ", JSONHelper.safe_stringify(hell_config, "\t"))
