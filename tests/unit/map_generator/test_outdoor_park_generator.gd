extends GutTest

## Tests for OutdoorParkGenerator
## Requirements: 4.1, 4.3, 4.4, 4.5, 4.6

const OutdoorParkGenerator = preload("res://game/scripts/map_generator/outdoor_park_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var generator: OutdoorParkGenerator
var context: GenerationContext


func before_each() -> void:
	generator = OutdoorParkGenerator.new()
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345


func after_each() -> void:
	generator = null
	context = null


## Test: No outdoor areas generated when outdoor_bias is 0.0
func test_no_outdoor_areas_when_bias_zero() -> void:
	context.config.outdoor_bias = 0.0
	context.grid_size = Vector2i(64, 64)
	_initialize_grid(context, 64, 64)

	var outdoor_areas := generator.generate_outdoor_areas(context)

	assert_eq(outdoor_areas.size(), 0, "Should generate no outdoor areas when bias is 0.0")


## Test: Outdoor areas generated when outdoor_bias > 0.0
func test_outdoor_areas_generated_with_positive_bias() -> void:
	context.config.outdoor_bias = 0.5
	context.grid_size = Vector2i(128, 128)
	_initialize_grid(context, 128, 128)

	var outdoor_areas := generator.generate_outdoor_areas(context)

	assert_gt(outdoor_areas.size(), 0, "Should generate outdoor areas when bias > 0.0")


## Test: Outdoor cells have no ceiling metadata
func test_outdoor_cells_have_no_ceiling() -> void:
	context.config.outdoor_bias = 0.5
	context.grid_size = Vector2i(64, 64)
	_initialize_grid(context, 64, 64)

	var outdoor_areas := generator.generate_outdoor_areas(context)

	if outdoor_areas.size() > 0:
		var region: Rect2i = outdoor_areas[0]
		var found_outdoor_cell := false

		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if context.grid[y][x].type == Cell.Type.OUTDOOR:
					found_outdoor_cell = true
					assert_eq(
						context.grid[y][x].metadata.get("has_ceiling", true),
						false,
						"Outdoor cells should have has_ceiling = false"
					)
					assert_eq(
						context.grid[y][x].metadata.get("is_outdoor", false),
						true,
						"Outdoor cells should have is_outdoor = true"
					)
					break
			if found_outdoor_cell:
				break

		assert_true(found_outdoor_cell, "Should find at least one outdoor cell")


## Test: Outdoor area count scales with map size
func test_outdoor_area_count_scales_with_map_size() -> void:
	context.config.outdoor_bias = 0.8

	# Small map (64x64)
	context.grid_size = Vector2i(64, 64)
	_initialize_grid(context, 64, 64)
	var small_areas := generator.generate_outdoor_areas(context)

	# Large map (256x256)
	context.grid_size = Vector2i(256, 256)
	_initialize_grid(context, 256, 256)
	var large_areas := generator.generate_outdoor_areas(context)

	assert_lte(
		small_areas.size(), large_areas.size(), "Larger maps should have same or more outdoor areas"
	)


## Test: Outdoor areas use cellular automata (organic shapes)
func test_outdoor_areas_use_cellular_automata() -> void:
	context.config.outdoor_bias = 0.5
	context.grid_size = Vector2i(128, 128)
	_initialize_grid(context, 128, 128)

	var outdoor_areas := generator.generate_outdoor_areas(context)

	if outdoor_areas.size() > 0:
		var region: Rect2i = outdoor_areas[0]
		var outdoor_count := 0
		var total_cells := region.size.x * region.size.y

		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if context.grid[y][x].type == Cell.Type.OUTDOOR:
					outdoor_count += 1

		# Cellular automata should create organic shapes (not fill entire region)
		assert_gt(outdoor_count, 0, "Should have some outdoor cells")
		assert_lt(outdoor_count, total_cells, "Should not fill entire region (organic shape)")


## Test: Outdoor bias scales frequency correctly
func test_outdoor_bias_scales_frequency() -> void:
	context.grid_size = Vector2i(128, 128)

	# Low bias
	context.config.outdoor_bias = 0.2
	_initialize_grid(context, 128, 128)
	var _low_bias_areas := generator.generate_outdoor_areas(context)
	var low_bias_count := _count_outdoor_cells(context.grid)

	# High bias
	context.config.outdoor_bias = 0.8
	_initialize_grid(context, 128, 128)
	var _high_bias_areas := generator.generate_outdoor_areas(context)
	var high_bias_count := _count_outdoor_cells(context.grid)

	assert_gt(high_bias_count, low_bias_count, "Higher bias should generate more outdoor cells")


## Helper: Initialize grid with empty cells
func _initialize_grid(ctx: GenerationContext, width: int, height: int) -> void:
	ctx.grid = []
	for y in range(height):
		var row: Array[Cell] = []
		for x in range(width):
			row.append(Cell.new(Cell.Type.EMPTY))
		ctx.grid.append(row)


## Helper: Count outdoor cells in grid
func _count_outdoor_cells(grid: Array[Array]) -> int:
	var count := 0
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			if grid[y][x].type == Cell.Type.OUTDOOR:
				count += 1
	return count
