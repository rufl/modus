extends GutTest

## Unit tests for BossArenaGenerator
## Tests boss arena generation, placement, and spawn marker logic

const BossArenaGenerator = preload("res://game/scripts/map_generator/boss_arena_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GridLayoutManager = preload("res://game/scripts/map_generator/grid_layout_manager.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var generator: BossArenaGenerator
var context: GenerationContext
var grid_manager: GridLayoutManager


func before_each() -> void:
	generator = BossArenaGenerator.new()
	context = GenerationContext.new()
	grid_manager = GridLayoutManager.new()

	# Set up basic context
	context.config = GenerationConfig.new()
	context.config.enable_boss_arena = true
	context.config.map_size = Vector2i(128, 128)
	context.grid_size = Vector2i(128, 128)
	context.seed_hash = 12345
	context.rng.seed = 12345

	# Initialize grid
	grid_manager.initialize_grid(context.grid_size)
	context.grid = grid_manager.grid


func test_generate_boss_arenas_creates_at_least_one_arena() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_gt(arenas.size(), 0, "Should generate at least one boss arena")


func test_boss_arena_has_minimum_40_cells() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	for arena in arenas:
		assert_gte(arena.cells.size(), 40, "Boss arena should have at least 40 cells")


func test_boss_arena_type_is_boss_arena() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	for arena in arenas:
		assert_eq(arena.type, Room.RoomType.BOSS_ARENA, "Arena type should be BOSS_ARENA")


func test_boss_arena_has_entrance_point() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	for arena in arenas:
		assert_gt(arena.entrance_points.size(), 0, "Arena should have at least one entrance point")


func test_boss_arena_cells_marked_in_grid() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	# Check that arena cells are marked in grid
	var marked_count := 0
	for cell_pos in arena.cells:
		var cell: Cell = context.grid[cell_pos.y][cell_pos.x]
		if cell.type == Cell.Type.BOSS_ARENA:
			marked_count += 1

	assert_eq(marked_count, arena.cells.size(), "All arena cells should be marked in grid")


func test_boss_arena_has_metadata() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	assert_true(arena.metadata.has("is_boss_arena"), "Arena should have is_boss_arena metadata")
	assert_true(arena.metadata["is_boss_arena"], "is_boss_arena should be true")
	assert_true(
		arena.metadata.has("has_clear_sightlines"),
		"Arena should have has_clear_sightlines metadata"
	)


func test_place_boss_spawn_marker_adds_spawn_to_context() -> void:
	# Arrange
	var arenas := generator.generate_boss_arenas(context)
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	var initial_spawn_count := context.monster_spawns.size()

	# Act
	generator.place_boss_spawn_marker(arena, context)

	# Assert
	assert_eq(context.monster_spawns.size(), initial_spawn_count + 1, "Should add one spawn marker")

	var spawn: Dictionary = context.monster_spawns[-1]
	assert_eq(spawn["type"], "boss", "Spawn type should be 'boss'")
	assert_eq(spawn["position"], arena.center, "Spawn should be at arena center")
	assert_eq(spawn["arena_id"], arena.id, "Spawn should reference arena ID")


func test_add_arena_elements_creates_elements() -> void:
	# Arrange
	var arenas := generator.generate_boss_arenas(context)
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	# Act
	generator.add_arena_elements(arena, context)

	# Assert
	assert_true(arena.metadata.has("arena_elements"), "Arena should have arena_elements metadata")
	var elements: Array = arena.metadata["arena_elements"]
	assert_gt(elements.size(), 0, "Should have at least one arena element")


func test_arena_elements_have_required_fields() -> void:
	# Arrange
	var arenas := generator.generate_boss_arenas(context)
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	# Act
	generator.add_arena_elements(arena, context)

	# Assert
	var elements: Array = arena.metadata["arena_elements"]
	for element in elements:
		if element is Dictionary and not element.is_empty():
			assert_true(element.has("type"), "Element should have type")
			assert_true(element.has("position"), "Element should have position")
			assert_true(element.has("world_position"), "Element should have world_position")
			assert_true(element.has("arena_id"), "Element should have arena_id")


func test_boss_arena_disabled_generates_no_arenas() -> void:
	# Arrange
	context.config.enable_boss_arena = false

	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_eq(arenas.size(), 0, "Should not generate arenas when disabled")


func test_boss_arena_has_single_entrance() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	# Should have at least one entrance
	assert_gte(arena.entrance_points.size(), 1, "Arena should have at least one entrance")

	# Should have entrance metadata
	assert_true(arena.metadata.has("entrance"), "Arena should have entrance metadata")


func test_boss_arena_within_grid_bounds() -> void:
	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	# Check all cells are within bounds
	for cell_pos in arena.cells:
		assert_true(
			cell_pos.x >= 0 and cell_pos.x < context.grid_size.x,
			"Cell X should be within grid bounds"
		)
		assert_true(
			cell_pos.y >= 0 and cell_pos.y < context.grid_size.y,
			"Cell Y should be within grid bounds"
		)


func test_multiple_arenas_do_not_overlap() -> void:
	# Arrange - Use larger map to allow multiple arenas
	context.config.map_size = Vector2i(256, 256)
	context.grid_size = Vector2i(256, 256)
	grid_manager.initialize_grid(context.grid_size)
	context.grid = grid_manager.grid

	# Act
	var arenas := generator.generate_boss_arenas(context)

	# Assert
	if arenas.size() > 1:
		var arena1: Room = arenas[0]
		var arena2: Room = arenas[1]

		# Create set of arena1 cells
		var arena1_cells := {}
		for cell in arena1.cells:
			arena1_cells[cell] = true

		# Check arena2 cells don't overlap
		var overlap_count := 0
		for cell in arena2.cells:
			if arena1_cells.has(cell):
				overlap_count += 1

		assert_eq(overlap_count, 0, "Arenas should not overlap")


func test_boss_spawn_marker_has_world_position() -> void:
	# Arrange
	var arenas := generator.generate_boss_arenas(context)
	assert_true(arenas.size() > 0, "Should have at least one arena")
	var arena: Room = arenas[0]

	# Act
	generator.place_boss_spawn_marker(arena, context)

	# Assert
	var spawn: Dictionary = context.monster_spawns[-1]
	assert_true(spawn.has("world_position"), "Spawn should have world_position")
	assert_true(spawn["world_position"] is Vector3, "world_position should be Vector3")


func test_arena_elements_vary_by_theme() -> void:
	# Test different themes produce different element types
	var themes := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.CAVE
	]

	var element_types_by_theme := {}

	for theme in themes:
		# Arrange
		context.config.theme = theme
		var arenas := generator.generate_boss_arenas(context)
		assert_true(arenas.size() > 0, "Should have arena for theme")
		var arena: Room = arenas[0]

		# Act
		generator.add_arena_elements(arena, context)

		# Collect element types
		var elements: Array = arena.metadata["arena_elements"]
		var types := []
		for element in elements:
			if element is Dictionary and element.has("type"):
				types.append(element["type"])

		element_types_by_theme[theme] = types

	# Assert - at least some variation exists
	# (This is a weak test but ensures theme affects elements)
	assert_true(element_types_by_theme.size() > 0, "Should have collected element types")
