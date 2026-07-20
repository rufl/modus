extends Node2D

## Manual test for boss arena generation
## Visualizes boss arenas on a 2D grid

const BossArenaGenerator = preload("res://game/scripts/map_generator/boss_arena_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GridLayoutManager = preload("res://game/scripts/map_generator/grid_layout_manager.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var generator: BossArenaGenerator
var context: GenerationContext
var grid_manager: GridLayoutManager

var cell_size := 4  # Pixels per grid cell
var arenas: Array = []


func _ready() -> void:
	# Initialize generator
	generator = BossArenaGenerator.new()
	context = GenerationContext.new()
	grid_manager = GridLayoutManager.new()

	# Set up context
	context.config = GenerationConfig.new()
	context.config.enable_boss_arena = true
	context.config.map_size = Vector2i(128, 128)
	context.grid_size = Vector2i(128, 128)
	context.seed_hash = 12345
	context.rng.seed = 12345

	# Initialize grid
	grid_manager.initialize_grid(context.grid_size)
	context.grid = grid_manager.grid

	# Generate boss arenas
	arenas = generator.generate_boss_arenas(context)

	# Place boss spawn markers
	for arena in arenas:
		generator.place_boss_spawn_marker(arena, context)
		generator.add_arena_elements(arena, context)

	# Print results
	print("Generated %d boss arena(s)" % arenas.size())
	for i in range(arenas.size()):
		var arena = arenas[i]
		print("Arena %d: %d cells, center at %s" % [i, arena.cells.size(), arena.center])
		print("  Entrance points: %d" % arena.entrance_points.size())
		print("  Boss spawn: %s" % arena.metadata.get("boss_spawn", "none"))
		if arena.metadata.has("arena_elements"):
			print("  Arena elements: %d" % arena.metadata["arena_elements"].size())

	# Trigger redraw
	queue_redraw()


func _draw() -> void:
	if arenas.is_empty():
		return

	# Draw grid background
	draw_rect(
		Rect2(0, 0, context.grid_size.x * cell_size, context.grid_size.y * cell_size),
		Color(0.1, 0.1, 0.1)
	)

	# Draw boss arenas
	for arena in arenas:
		# Draw arena cells
		for cell_pos in arena.cells:
			var rect := Rect2(cell_pos.x * cell_size, cell_pos.y * cell_size, cell_size, cell_size)
			draw_rect(rect, Color(0.8, 0.2, 0.2, 0.7))

		# Draw arena center (boss spawn)
		var center_world := Vector2(arena.center.x * cell_size, arena.center.y * cell_size)
		draw_circle(
			center_world + Vector2(cell_size / 2, cell_size / 2), cell_size * 2, Color.YELLOW
		)

		# Draw entrance points
		for entrance in arena.entrance_points:
			var entrance_world := Vector2(entrance.x * cell_size, entrance.y * cell_size)
			draw_rect(Rect2(entrance_world.x, entrance_world.y, cell_size, cell_size), Color.GREEN)

		# Draw arena elements
		if arena.metadata.has("arena_elements"):
			for element in arena.metadata["arena_elements"]:
				if element is Dictionary and element.has("position"):
					var pos: Vector2i = element["position"]
					var element_world := Vector2(pos.x * cell_size, pos.y * cell_size)
					draw_circle(
						element_world + Vector2(cell_size / 2, cell_size / 2), cell_size, Color.CYAN
					)

	# Draw legend
	var legend_y := 10
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, legend_y),
		"Boss Arena Test",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)
	legend_y += 25
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, legend_y),
		"Red: Arena cells",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.8, 0.2, 0.2)
	)
	legend_y += 20
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, legend_y),
		"Yellow: Boss spawn",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.YELLOW
	)
	legend_y += 20
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, legend_y),
		"Green: Entrance",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.GREEN
	)
	legend_y += 20
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, legend_y),
		"Cyan: Arena elements",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.CYAN
	)
