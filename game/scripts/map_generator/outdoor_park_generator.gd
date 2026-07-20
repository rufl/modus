class_name OutdoorParkGenerator
extends RefCounted

## Outdoor Park Generator
## Generates outdoor park areas using cellular automata
## Requirements: 4.1, 4.3, 4.4, 4.5, 4.6

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const CellularAutomataEngine = preload(
	"res://game/scripts/map_generator/cellular_automata_engine.gd"
)

var ca_engine: CellularAutomataEngine


func _init() -> void:
	ca_engine = CellularAutomataEngine.new()


## Generate outdoor park areas based on outdoor_bias parameter
## context: The generation context containing grid, config, and RNG
## Returns: Array of Rect2i regions representing outdoor areas
func generate_outdoor_areas(context: GenerationContext) -> Array:
	var outdoor_areas: Array = []

	# Check if outdoor generation is enabled
	if context.config.outdoor_bias <= 0.0:
		return outdoor_areas

	# Calculate number of outdoor areas based on bias and map size
	var map_area := context.grid_size.x * context.grid_size.y
	# 15% of bias-scaled area
	var target_outdoor_cells := int(map_area * context.config.outdoor_bias * 0.15)

	if target_outdoor_cells < 16:  # Minimum viable outdoor area
		return outdoor_areas

	# Determine number of outdoor regions (1-3 based on map size)
	var num_regions := _calculate_outdoor_region_count(
		context.grid_size, context.config.outdoor_bias
	)
	var cells_per_region := target_outdoor_cells / num_regions

	# Generate outdoor regions
	for i in range(num_regions):
		var region := _find_suitable_outdoor_location(context, cells_per_region)
		if region.size.x > 0 and region.size.y > 0:
			_generate_outdoor_region(region, context)
			outdoor_areas.append(region)

	return outdoor_areas


## Calculate number of outdoor regions based on map size and bias
func _calculate_outdoor_region_count(grid_size: Vector2i, outdoor_bias: float) -> int:
	var map_area := grid_size.x * grid_size.y

	# Scale region count with map size and bias
	if map_area < 8192:  # 64x64 or smaller
		return 1
	if map_area < 20000:  # 128x128
		return max(1, int(outdoor_bias * 2))  # 1-2 regions
	# 256x256
	return max(1, int(outdoor_bias * 3))  # 1-3 regions


## Find a suitable location for an outdoor area
## Avoids placing outdoor areas too close to existing rooms or other outdoor areas
func _find_suitable_outdoor_location(context: GenerationContext, target_cells: int) -> Rect2i:
	var rng := context.rng
	var _grid := context.grid
	var grid_size := context.grid_size

	# Calculate region dimensions (roughly square)
	var region_side := int(sqrt(target_cells))
	region_side = clamp(region_side, 8, 32)  # Min 8x8, max 32x32

	# Try to find a suitable location (max 20 attempts)
	for attempt in range(20):
		# Random position with margins
		var margin := 4
		var x := rng.randi_range(margin, grid_size.x - region_side - margin)
		var y := rng.randi_range(margin, grid_size.y - region_side - margin)

		var region := Rect2i(x, y, region_side, region_side)

		# Check if location is suitable
		if _is_location_suitable_for_outdoor(region, context):
			return region

	# If no suitable location found, return empty region
	return Rect2i(0, 0, 0, 0)


## Check if a location is suitable for outdoor area placement
func _is_location_suitable_for_outdoor(region: Rect2i, context: GenerationContext) -> bool:
	var empty_count := 0
	var total_cells := region.size.x * region.size.y

	# Count empty cells in the region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= context.grid.size() or x < 0 or x >= context.grid[y].size():
				return false

			if context.grid[y][x].type == Cell.Type.EMPTY:
				empty_count += 1

	# At least 80% of cells should be empty
	return empty_count >= total_cells * 0.8


## Generate an outdoor region using cellular automata
func _generate_outdoor_region(region: Rect2i, context: GenerationContext) -> void:
	# Use cellular automata to create organic outdoor shape
	# 5 iterations for organic shape
	ca_engine.generate_area(region, context.grid, context.rng, Cell.Type.OUTDOOR, 5)

	# Create transitions to adjacent indoor areas
	_create_outdoor_transitions(region, context)

	# Mark outdoor cells as having no ceiling
	_mark_outdoor_cells_no_ceiling(region, context.grid)


## Create transitions between indoor and outdoor areas
## Finds adjacent indoor cells and creates doorway connections
func _create_outdoor_transitions(region: Rect2i, context: GenerationContext) -> void:
	var grid := context.grid
	var transition_points: Array[Vector2i] = []

	# Scan the perimeter of the outdoor region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			# Only process outdoor cells on the edge
			if grid[y][x].type != Cell.Type.OUTDOOR:
				continue

			# Check if this cell is adjacent to an indoor area
			if _is_adjacent_to_indoor(Vector2i(x, y), grid):
				transition_points.append(Vector2i(x, y))

	# Create doorways at transition points (limit to 2-4 per region)
	var num_transitions: int = clamp(transition_points.size() / 8, 2, 4)
	transition_points.shuffle()

	for i in range(min(num_transitions, transition_points.size())):
		var pos := transition_points[i]
		# Mark as transition (doorway will be created during geometry phase)
		grid[pos.y][pos.x].metadata["is_outdoor_transition"] = true


## Check if a position is adjacent to an indoor area (room or hallway)
func _is_adjacent_to_indoor(pos: Vector2i, grid: Array[Array]) -> bool:
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


## Mark outdoor cells as having no ceiling for geometry generation
func _mark_outdoor_cells_no_ceiling(region: Rect2i, grid: Array[Array]) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			if grid[y][x].type == Cell.Type.OUTDOOR:
				# Set metadata flag for CSG builder to skip ceiling
				grid[y][x].metadata["has_ceiling"] = false
				grid[y][x].metadata["is_outdoor"] = true
