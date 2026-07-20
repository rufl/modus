class_name CaveSystemGenerator
extends RefCounted

## Cave System Generator
## Generates organic cave systems using cellular automata or Voxel Tools
## Requirements: 5.1, 5.2, 5.3, 5.6, 15.1, 15.2, 15.3, 15.4, 15.5

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const CellularAutomataEngine = preload(
	"res://game/scripts/map_generator/cellular_automata_engine.gd"
)
const VoxelCaveGenerator = preload("res://game/scripts/map_generator/voxel_cave_generator.gd")

var ca_engine: CellularAutomataEngine
var voxel_generator: VoxelCaveGenerator
var use_voxel_tools: bool = false


func _init() -> void:
	ca_engine = CellularAutomataEngine.new()

	# Detect Voxel Tools availability
	use_voxel_tools = VoxelCaveGenerator.is_voxel_tools_available()

	if use_voxel_tools:
		voxel_generator = VoxelCaveGenerator.new()
		print("CaveSystemGenerator: Using Voxel Tools for cave generation")
	else:
		print("CaveSystemGenerator: Voxel Tools not available, using CSG fallback")


## Check if Voxel Tools is being used for cave generation
func is_using_voxel_tools() -> bool:
	return use_voxel_tools


## Generate cave areas based on cave_bias parameter
## context: The generation context containing grid, config, and RNG
## Returns: Array of Rect2i regions representing cave areas
func generate_cave_areas(context: GenerationContext) -> Array:
	var cave_areas: Array = []

	# Check if cave generation is enabled
	if context.config.cave_bias <= 0.0:
		return cave_areas

	# Calculate number of cave areas based on bias and map size
	var map_area := context.grid_size.x * context.grid_size.y
	# 12% of bias-scaled area (caves are denser than outdoor parks)
	var target_cave_cells := int(map_area * context.config.cave_bias * 0.12)

	if target_cave_cells < 16:  # Minimum viable cave area
		return cave_areas

	# Determine number of cave regions (1-3 based on map size)
	var num_regions := _calculate_cave_region_count(context.grid_size, context.config.cave_bias)
	var cells_per_region := target_cave_cells / num_regions

	# Generate cave regions
	for i in range(num_regions):
		var region := _find_suitable_cave_location(context, cells_per_region)
		if region.size.x > 0 and region.size.y > 0:
			_generate_cave_region(region, context)
			cave_areas.append(region)

	return cave_areas


## Calculate number of cave regions based on map size and bias
func _calculate_cave_region_count(grid_size: Vector2i, cave_bias: float) -> int:
	var map_area := grid_size.x * grid_size.y

	# Scale region count with map size and bias
	if map_area < 8192:  # 64x64 or smaller
		return 1
	if map_area < 20000:  # 128x128
		return max(1, int(cave_bias * 2))  # 1-2 regions
	# 256x256
	return max(1, int(cave_bias * 3))  # 1-3 regions


## Find a suitable location for a cave area
## Avoids placing caves too close to existing rooms or other caves
func _find_suitable_cave_location(context: GenerationContext, target_cells: int) -> Rect2i:
	var rng := context.rng
	var _grid := context.grid
	var grid_size := context.grid_size

	# Calculate region dimensions (roughly square)
	var region_side := int(sqrt(target_cells))
	region_side = clamp(region_side, 10, 40)  # Min 10x10, max 40x40 (caves can be larger)

	# Try to find a suitable location (max 20 attempts)
	for attempt in range(20):
		# Random position with margins
		var margin := 5
		var x := rng.randi_range(margin, grid_size.x - region_side - margin)
		var y := rng.randi_range(margin, grid_size.y - region_side - margin)

		var region := Rect2i(x, y, region_side, region_side)

		# Check if location is suitable
		if _is_location_suitable_for_cave(region, context):
			return region

	# If no suitable location found, return empty region
	return Rect2i(0, 0, 0, 0)


## Check if a location is suitable for cave area placement
func _is_location_suitable_for_cave(region: Rect2i, context: GenerationContext) -> bool:
	var empty_count := 0
	var total_cells := region.size.x * region.size.y

	# Count empty cells in the region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= context.grid.size() or x < 0 or x >= context.grid[y].size():
				return false

			if context.grid[y][x].type == Cell.Type.EMPTY:
				empty_count += 1

	# At least 75% of cells should be empty (caves can overlap slightly more)
	return empty_count >= total_cells * 0.75


## Generate a cave region using cellular automata
func _generate_cave_region(region: Rect2i, context: GenerationContext) -> void:
	# Use cellular automata to create organic cave shape
	# 6 iterations for more organic, natural cave formations
	ca_engine.generate_area(region, context.grid, context.rng, Cell.Type.CAVE, 6)

	# Smooth cave edges for natural appearance
	_smooth_cave_edges(region, context)

	# Ensure caves connect to main level structure
	_create_cave_connections(region, context)

	# Mark cave cells with appropriate metadata
	_mark_cave_cells(region, context.grid)


## Smooth cave edges for natural appearance
## Uses a second pass of cellular automata with different rules
func _smooth_cave_edges(region: Rect2i, context: GenerationContext) -> void:
	var grid := context.grid
	var smoothed_cells: Array[Vector2i] = []

	# Identify edge cells (cave cells adjacent to non-cave cells)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			if grid[y][x].type == Cell.Type.CAVE:
				if _is_edge_cell(Vector2i(x, y), grid):
					smoothed_cells.append(Vector2i(x, y))

	# Apply smoothing to edge cells
	for pos: Vector2i in smoothed_cells:
		var cave_neighbors := _count_cave_neighbors(pos, grid)

		# If less than 4 cave neighbors, consider removing this edge cell
		# This creates smoother, more natural cave walls
		if cave_neighbors < 4:
			# 30% chance to smooth out the edge
			if context.rng.randf() < 0.3:
				grid[pos.y][pos.x].type = Cell.Type.EMPTY


## Check if a cave cell is on the edge (adjacent to non-cave cells)
func _is_edge_cell(pos: Vector2i, grid: Array[Array]) -> bool:
	# Left, Right, Up, Down, Diagonals
	var directions := [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]

	for dir: Vector2i in directions:
		var nx: int = pos.x + dir.x
		var ny: int = pos.y + dir.y

		if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[ny].size():
			if grid[ny][nx].type != Cell.Type.CAVE:
				return true

	return false


## Count cave neighbors for smoothing algorithm
func _count_cave_neighbors(pos: Vector2i, grid: Array[Array]) -> int:
	var count := 0
	# Left, Right, Up, Down, Diagonals
	var directions := [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]

	for dir: Vector2i in directions:
		var nx: int = pos.x + dir.x
		var ny: int = pos.y + dir.y

		if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[ny].size():
			if grid[ny][nx].type == Cell.Type.CAVE:
				count += 1

	return count


## Create connections between caves and main level structure
## Finds adjacent rooms/hallways and creates connection points
func _create_cave_connections(region: Rect2i, context: GenerationContext) -> void:
	var grid := context.grid
	var connection_points: Array[Vector2i] = []

	# Scan the perimeter of the cave region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			# Only process cave cells on the edge
			if grid[y][x].type != Cell.Type.CAVE:
				continue

			# Check if this cell is adjacent to main level structure
			if _is_adjacent_to_main_structure(Vector2i(x, y), grid):
				connection_points.append(Vector2i(x, y))

	# Create connections at transition points (1-3 per cave region)
	var num_connections: int = clamp(connection_points.size() / 10, 1, 3)
	connection_points.shuffle()

	for i in range(min(num_connections, connection_points.size())):
		var pos := connection_points[i]
		# Mark as cave entrance (doorway/tunnel will be created during geometry phase)
		grid[pos.y][pos.x].metadata["is_cave_entrance"] = true


## Check if a position is adjacent to main level structure (room or hallway)
func _is_adjacent_to_main_structure(pos: Vector2i, grid: Array[Array]) -> bool:
	# Left, Right, Up, Down
	var directions := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

	for dir: Vector2i in directions:
		var nx: int = pos.x + dir.x
		var ny: int = pos.y + dir.y

		if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[ny].size():
			var neighbor_type: Cell.Type = grid[ny][nx].type
			if neighbor_type == Cell.Type.ROOM or neighbor_type == Cell.Type.HALLWAY:
				return true

	return false


## Mark cave cells with appropriate metadata for geometry generation
func _mark_cave_cells(region: Rect2i, grid: Array[Array]) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			if grid[y][x].type == Cell.Type.CAVE:
				# Set metadata flags for CSG builder
				grid[y][x].metadata["is_cave"] = true
				grid[y][x].metadata["has_ceiling"] = true  # Caves have ceilings
				grid[y][x].metadata["use_cave_materials"] = true


## Generate voxel-based cave geometry for a region
## This is called during the geometry generation phase
## region: The grid region containing cave cells
## context: The generation context
## Returns: Node3D containing voxel terrain, or null if voxel tools not available
func generate_voxel_cave_geometry(region: Rect2i, context: GenerationContext) -> Node3D:
	if not use_voxel_tools or voxel_generator == null:
		return null

	return voxel_generator.generate_voxel_cave_terrain(region, context)
