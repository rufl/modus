class_name OcclusionCullingManager
extends RefCounted

## Manages occlusion culling system for generated maps
## Generates OccluderInstance3D nodes at room boundaries and large walls
## Provides rendering performance benefits by hiding geometry behind walls

# Constants
const CELL_SIZE := 2.0  # Each grid cell is 2m × 2m in world space
const WALL_HEIGHT := 3.0  # Standard wall height in meters
const OCCLUDER_THICKNESS := 0.2  # Thickness of occluder boxes
const ENTRANCE_EXCLUSION_RADIUS := 2  # Grid cells to exclude around entrances

# Generation context
var context: GenerationContext
var occluders_root: Node3D
var occluder_count: int = 0


## Initialize the occlusion culling manager with generation context
func initialize(gen_context: GenerationContext) -> void:
	context = gen_context
	occluder_count = 0


## Generate occluders for all rooms in the map
## Returns the root node containing all occluders
func generate_occluders() -> Node3D:
	# Create root node for occluders
	occluders_root = Node3D.new()
	occluders_root.name = "Occluders"
	occluder_count = 0

	# Check if occlusion culling is enabled
	if not context.config.enable_occlusion_culling:
		return occluders_root

	# Generate occluders for each room
	for room in context.rooms:
		_generate_room_occluders(room)

	return occluders_root


## Generate occluders for a single room
func _generate_room_occluders(room: Room) -> void:
	# Find boundary walls for this room
	var boundary_walls := _find_boundary_walls(room)

	# Create occluders for each boundary wall
	for wall in boundary_walls:
		_create_occluder(wall)


## Find boundary walls for a room
## Returns array of wall data dictionaries with center, length, and rotation
func _find_boundary_walls(room: Room) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	var processed_edges: Dictionary = {}  # Track processed edges to avoid duplicates

	# Check each cell in the room
	for cell_pos in room.cells:
		# Check all 4 directions for boundaries
		var directions := [
			{"dir": Vector2i(0, -1), "axis": "horizontal"},  # North
			{"dir": Vector2i(0, 1), "axis": "horizontal"},  # South
			{"dir": Vector2i(1, 0), "axis": "vertical"},  # East
			{"dir": Vector2i(-1, 0), "axis": "vertical"}  # West
		]

		for direction: Dictionary in directions:
			var neighbor_pos: Vector2i = cell_pos + direction.dir

			# Check if this is a boundary (neighbor is not part of the room)
			if _is_boundary_edge(cell_pos, neighbor_pos, room):
				# Check if this wall should be excluded (near entrance/doorway)
				if _is_gameplay_critical_wall(cell_pos, neighbor_pos, room):
					continue

				# Create edge key for deduplication
				var edge_key := _get_edge_key(cell_pos, neighbor_pos)
				if processed_edges.has(edge_key):
					continue
				processed_edges[edge_key] = true

				# Find continuous wall segment
				var wall_segment := _find_wall_segment(
					cell_pos, direction.dir, direction.axis, room, processed_edges
				)

				if wall_segment.length > 0:
					walls.append(wall_segment)

	return walls


## Check if an edge is a boundary (neighbor is not part of the room)
func _is_boundary_edge(_cell_pos: Vector2i, neighbor_pos: Vector2i, room: Room) -> bool:
	# Check if neighbor is out of bounds
	if not _is_valid_position(neighbor_pos):
		return true

	# Check if neighbor is not part of this room
	var neighbor_cell: Cell = context.grid[neighbor_pos.y][neighbor_pos.x]
	return neighbor_cell.type != Cell.Type.ROOM or neighbor_cell.room_id != room.id


## Check if a wall is gameplay-critical (near entrance/doorway)
func _is_gameplay_critical_wall(cell_pos: Vector2i, neighbor_pos: Vector2i, room: Room) -> bool:
	# Check if either position is near an entrance point
	for entrance in room.entrance_points:
		var dist_to_cell := _grid_distance(cell_pos, entrance)
		var dist_to_neighbor := _grid_distance(neighbor_pos, entrance)

		if (
			dist_to_cell <= ENTRANCE_EXCLUSION_RADIUS
			or dist_to_neighbor <= ENTRANCE_EXCLUSION_RADIUS
		):
			return true

	# Check if neighbor is a hallway (doorway)
	if _is_valid_position(neighbor_pos):
		var neighbor_cell: Cell = context.grid[neighbor_pos.y][neighbor_pos.x]
		if neighbor_cell.type == Cell.Type.HALLWAY:
			return true

	return false


## Calculate grid distance (Manhattan distance)
func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Get unique edge key for deduplication
func _get_edge_key(pos1: Vector2i, pos2: Vector2i) -> String:
	# Sort positions to ensure consistent key regardless of order
	var min_pos := pos1 if (pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y < pos2.y)) else pos2
	var max_pos := pos2 if min_pos == pos1 else pos1
	return "%d,%d-%d,%d" % [min_pos.x, min_pos.y, max_pos.x, max_pos.y]


## Find continuous wall segment starting from a position
func _find_wall_segment(
	start_pos: Vector2i, direction: Vector2i, axis: String, room: Room, processed_edges: Dictionary
) -> Dictionary:
	var segment_cells: Array[Vector2i] = [start_pos]

	# Determine perpendicular direction for extending the wall
	var extend_dir: Vector2i
	if axis == "horizontal":
		extend_dir = Vector2i(1, 0)  # Extend along X axis
	else:
		extend_dir = Vector2i(0, 1)  # Extend along Y axis

	# Extend in positive direction
	var current_pos := start_pos + extend_dir
	while true:
		var neighbor_pos := current_pos + direction

		# Check if this continues the wall
		if not _is_boundary_edge(current_pos, neighbor_pos, room):
			break
		if _is_gameplay_critical_wall(current_pos, neighbor_pos, room):
			break
		if current_pos not in room.cells:
			break

		# Mark edge as processed
		var edge_key := _get_edge_key(current_pos, neighbor_pos)
		if processed_edges.has(edge_key):
			break
		processed_edges[edge_key] = true

		segment_cells.append(current_pos)
		current_pos += extend_dir

	# Extend in negative direction
	current_pos = start_pos - extend_dir
	while true:
		var neighbor_pos := current_pos + direction

		# Check if this continues the wall
		if not _is_boundary_edge(current_pos, neighbor_pos, room):
			break
		if _is_gameplay_critical_wall(current_pos, neighbor_pos, room):
			break
		if current_pos not in room.cells:
			break

		# Mark edge as processed
		var edge_key := _get_edge_key(current_pos, neighbor_pos)
		if processed_edges.has(edge_key):
			break
		processed_edges[edge_key] = true

		segment_cells.push_front(current_pos)
		current_pos -= extend_dir

	# Calculate wall properties
	var wall_length := segment_cells.size() * CELL_SIZE
	var wall_center := _calculate_wall_center(segment_cells, direction, axis)
	var wall_rotation := _calculate_wall_rotation(axis, direction)

	return {"center": wall_center, "length": wall_length, "rotation": wall_rotation, "axis": axis}


## Calculate world position for wall center
func _calculate_wall_center(cells: Array[Vector2i], direction: Vector2i, axis: String) -> Vector3:
	# Calculate average position of cells
	var sum := Vector2.ZERO
	for cell_pos in cells:
		sum += Vector2(cell_pos)
	var avg_pos := sum / cells.size()

	# Convert to world position (center of cells)
	var world_x := avg_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var world_z := avg_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	var world_y := WALL_HEIGHT * 0.5  # Center at half wall height

	# Offset to edge of cells based on direction
	if axis == "horizontal":
		world_z += direction.y * CELL_SIZE * 0.5
	else:
		world_x += direction.x * CELL_SIZE * 0.5

	return Vector3(world_x, world_y, world_z)


## Calculate rotation for wall occluder
func _calculate_wall_rotation(axis: String, _direction: Vector2i) -> Vector3:
	# Walls are oriented based on their axis
	if axis == "vertical":
		return Vector3(0, PI * 0.5, 0)  # Rotate 90 degrees around Y axis

	return Vector3.ZERO  # No rotation for horizontal walls


## Create an occluder instance for a wall
func _create_occluder(wall: Dictionary) -> void:
	var occluder := OccluderInstance3D.new()

	# Create box occluder shape
	var occluder_shape := BoxOccluder3D.new()
	occluder_shape.size = Vector3(wall.length, WALL_HEIGHT, OCCLUDER_THICKNESS)

	# Set occluder properties
	occluder.occluder = occluder_shape
	occluder.position = wall.center
	occluder.rotation = wall.rotation

	# Add to occluders root
	occluders_root.add_child(occluder)
	occluder_count += 1


## Check if a grid position is valid
func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < context.grid_size.x and pos.y >= 0 and pos.y < context.grid_size.y


## Bake occlusion data during export phase
## This is called after all occluders are generated
func bake_occlusion_data() -> void:
	# In Godot 4.x, occlusion culling is handled automatically by the renderer
	# when OccluderInstance3D nodes are present in the scene
	# No explicit baking is required, but we can log the completion
	if context.config.enable_occlusion_culling:
		print("Occlusion culling data prepared: %d occluders generated" % occluder_count)


## Get the number of occluders generated
func get_occluder_count() -> int:
	return occluder_count
