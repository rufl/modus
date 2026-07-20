extends SceneTree

## Simple integration test for cave system generator

const CaveSystemGenerator = preload("res://game/scripts/map_generator/cave_system_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")


func _init() -> void:
	print("=== Cave System Generator Integration Test ===")

	var cave_generator := CaveSystemGenerator.new()
	var context := GenerationContext.new()

	# Initialize context
	context.grid_size = Vector2i(64, 64)
	context.config = GenerationConfig.new()
	context.config.cave_bias = 0.5
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		for x in range(context.grid_size.x):
			var cell := Cell.new()
			cell.type = Cell.Type.EMPTY
			row.append(cell)
		context.grid.append(row)

	# Add test rooms
	for y in range(10, 20):
		for x in range(10, 20):
			context.grid[y][x].type = Cell.Type.ROOM

	print("Generating cave areas...")
	var start_time := Time.get_ticks_msec()
	var cave_areas := cave_generator.generate_cave_areas(context)
	var end_time := Time.get_ticks_msec()

	print("Generation completed in %d ms" % (end_time - start_time))
	print("Cave areas generated: %d" % cave_areas.size())

	# Count cave cells
	var cave_cell_count := 0
	var entrance_count := 0
	for y in range(context.grid_size.y):
		for x in range(context.grid_size.x):
			if context.grid[y][x].type == Cell.Type.CAVE:
				cave_cell_count += 1
				if context.grid[y][x].metadata.has("is_cave_entrance"):
					if context.grid[y][x].metadata["is_cave_entrance"]:
						entrance_count += 1

	print("Cave cells: %d" % cave_cell_count)
	print("Cave entrances: %d" % entrance_count)

	# Verify results
	if cave_areas.size() > 0:
		print("✓ Cave areas generated successfully")
	else:
		print("✗ No cave areas generated")

	if cave_cell_count > 0:
		print("✓ Cave cells created")
	else:
		print("✗ No cave cells created")

	# Test with zero bias
	print("\nTesting with zero cave bias...")
	context.config.cave_bias = 0.0

	# Reset grid
	for y in range(context.grid_size.y):
		for x in range(context.grid_size.x):
			context.grid[y][x].type = Cell.Type.EMPTY
			context.grid[y][x].metadata.clear()

	var zero_bias_areas := cave_generator.generate_cave_areas(context)
	print("Cave areas with zero bias: %d" % zero_bias_areas.size())

	if zero_bias_areas.size() == 0:
		print("✓ No caves generated with zero bias")
	else:
		print("✗ Caves generated with zero bias (unexpected)")

	print("\n=== Test Complete ===")
	quit()
