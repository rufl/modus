extends Node

## Manual test for OutdoorParkGenerator
## Run this scene to visually verify outdoor park generation

const OutdoorParkGenerator = preload("res://game/scripts/map_generator/outdoor_park_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")


func _ready() -> void:
	print("=== Outdoor Park Generator Manual Test ===")

	# Test 1: Small map with low bias
	print("\nTest 1: 64x64 map, outdoor_bias=0.3")
	_test_generation(64, 64, 0.3)

	# Test 2: Medium map with moderate bias
	print("\nTest 2: 128x128 map, outdoor_bias=0.5")
	_test_generation(128, 128, 0.5)

	# Test 3: Large map with high bias
	print("\nTest 3: 256x256 map, outdoor_bias=0.8")
	_test_generation(256, 256, 0.8)

	# Test 4: No outdoor areas
	print("\nTest 4: 128x128 map, outdoor_bias=0.0")
	_test_generation(128, 128, 0.0)

	print("\n=== All tests completed ===")


func _test_generation(width: int, height: int, bias: float) -> void:
	var generator := OutdoorParkGenerator.new()
	var context := GenerationContext.new()

	# Setup config
	context.config = GenerationConfig.new()
	context.config.outdoor_bias = bias
	context.config.map_size = Vector2i(width, height)
	context.grid_size = Vector2i(width, height)
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid = []
	for y in range(height):
		var row: Array[Cell] = []
		for x in range(width):
			row.append(Cell.new(Cell.Type.EMPTY))
		context.grid.append(row)

	# Generate outdoor areas
	var outdoor_areas := generator.generate_outdoor_areas(context)

	# Count outdoor cells
	var outdoor_count := 0
	var transition_count := 0
	var no_ceiling_count := 0

	for y in range(height):
		for x in range(width):
			if context.grid[y][x].type == Cell.Type.OUTDOOR:
				outdoor_count += 1
				if context.grid[y][x].metadata.get("has_ceiling", true) == false:
					no_ceiling_count += 1
				if context.grid[y][x].metadata.get("is_outdoor_transition", false):
					transition_count += 1

	# Print results
	print("  Outdoor areas: %d" % outdoor_areas.size())
	var outdoor_pct := outdoor_count * 100.0 / (width * height)
	print("  Outdoor cells: %d (%.1f%%)" % [outdoor_count, outdoor_pct])
	print("  Cells with no ceiling: %d" % no_ceiling_count)
	print("  Transition cells: %d" % transition_count)

	# Verify requirements
	if bias > 0.0:
		assert(outdoor_areas.size() > 0, "Should generate outdoor areas when bias > 0")
		assert(outdoor_count > 0, "Should have outdoor cells")
		assert(no_ceiling_count == outdoor_count, "All outdoor cells should have no ceiling")
	else:
		assert(outdoor_areas.size() == 0, "Should not generate outdoor areas when bias = 0")
		assert(outdoor_count == 0, "Should have no outdoor cells")
