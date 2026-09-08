extends ModusGutTestBase

## Unit tests for ShapeGrammarEngine

const ShapeGrammarEngine = preload("res://game/scripts/map_generator/shape_grammar_engine.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var engine: ShapeGrammarEngine
var rng: RandomNumberGenerator
var context: GenerationContext


func before_each() -> void:
	engine = ShapeGrammarEngine.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for deterministic tests

	# Create minimal context
	context = GenerationContext.new()
	context.grid_size = Vector2i(128, 128)
	context.rng = rng
	context.config = GenerationConfig.new()
	context.config.enable_boss_arena = true

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		for x in range(context.grid_size.x):
			row.append(Cell.new())
		context.grid.append(row)


func test_generate_room_shape_small() -> void:
	var center := Vector2i(64, 64)
	var target_size := 6
	var room_type: Room.RoomType = Room.RoomType.SMALL

	var points: PackedVector2Array = engine.generate_room_shape(
		center, target_size, room_type, rng, null
	)

	assert_gt(points.size(), 0, "Should generate polygon points")


func test_generate_room_shape_medium() -> void:
	var center := Vector2i(64, 64)
	var target_size := 12
	var room_type: Room.RoomType = Room.RoomType.MEDIUM

	var points: PackedVector2Array = engine.generate_room_shape(
		center, target_size, room_type, rng, null
	)

	assert_gt(points.size(), 0, "Should generate polygon points")


func test_generate_room_shape_large() -> void:
	var center := Vector2i(64, 64)
	var target_size := 25
	var room_type: Room.RoomType = Room.RoomType.LARGE

	var points: PackedVector2Array = engine.generate_room_shape(
		center, target_size, room_type, rng, null
	)

	assert_gt(points.size(), 0, "Should generate polygon points")


func test_generate_room_shape_boss_arena() -> void:
	var center := Vector2i(64, 64)
	var target_size := 50
	var room_type: Room.RoomType = Room.RoomType.BOSS_ARENA

	var points: PackedVector2Array = engine.generate_room_shape(
		center, target_size, room_type, rng, null
	)

	assert_gt(points.size(), 0, "Should generate polygon points for boss arena")


func test_polygon_to_grid_cells() -> void:
	# Create a simple square polygon
	var points := PackedVector2Array(
		[Vector2(64, 64), Vector2(68, 64), Vector2(68, 68), Vector2(64, 68)]
	)

	var cells: Array[Vector2i] = engine.polygon_to_grid_cells(points, context.grid_size)

	assert_gt(cells.size(), 0, "Should generate at least one cell")

	# All cells should be within grid bounds
	for cell in cells:
		assert_true(cell.x >= 0 and cell.x < context.grid_size.x, "Cell X should be in bounds")
		assert_true(cell.y >= 0 and cell.y < context.grid_size.y, "Cell Y should be in bounds")


func test_generate_room_creates_valid_room() -> void:
	var center := Vector2i(64, 64)
	var room_type: Room.RoomType = Room.RoomType.MEDIUM
	var room_id := 0

	var room: Room = engine.generate_room(center, room_type, room_id, context)

	assert_not_null(room, "Should create a room")
	assert_eq(room.id, room_id, "Room ID should match")
	assert_eq(room.center, center, "Room center should match")
	assert_eq(room.type, room_type, "Room type should match")
	assert_gt(room.cells.size(), 0, "Room should have cells")
	assert_gt(room.entrance_points.size(), 0, "Room should have at least one entrance point")


func test_room_meets_minimum_size_requirements() -> void:
	var center := Vector2i(64, 64)

	# Test small room
	var small_room: Room = engine.generate_room(center, Room.RoomType.SMALL, 0, context)
	assert_true(small_room.cells.size() >= 4, "Small room should have at least 4 cells")

	# Test medium room
	var medium_room: Room = engine.generate_room(
		center + Vector2i(20, 0), Room.RoomType.MEDIUM, 1, context
	)
	assert_true(medium_room.cells.size() >= 9, "Medium room should have at least 9 cells")

	# Test large room
	var large_room: Room = engine.generate_room(
		center + Vector2i(40, 0), Room.RoomType.LARGE, 2, context
	)
	assert_true(large_room.cells.size() >= 17, "Large room should have at least 17 cells")


func test_load_theme_rules_default() -> void:
	var rules: Dictionary = engine.load_theme_rules("")
	assert_eq(rules, engine.DEFAULT_RULES, "Empty theme should return default rules")


func test_load_theme_rules_tech() -> void:
	var rules: Dictionary = engine.load_theme_rules("tech")
	assert_not_null(rules, "Should load tech theme rules")
	assert_true(rules.has("F"), "Tech rules should have F expansion")


func test_load_theme_rules_hell() -> void:
	var rules: Dictionary = engine.load_theme_rules("hell")
	assert_not_null(rules, "Should load hell theme rules")
	assert_true(rules.has("F"), "Hell rules should have F expansion")


func test_load_theme_rules_urban() -> void:
	var rules: Dictionary = engine.load_theme_rules("urban")
	assert_not_null(rules, "Should load urban theme rules")
	assert_true(rules.has("F"), "Urban rules should have F expansion")


func test_load_theme_rules_cave() -> void:
	var rules: Dictionary = engine.load_theme_rules("cave")
	assert_not_null(rules, "Should load cave theme rules")
	assert_true(rules.has("F"), "Cave rules should have F expansion")


func test_theme_rules_are_cached() -> void:
	var rules1: Dictionary = engine.load_theme_rules("tech")
	var rules2: Dictionary = engine.load_theme_rules("tech")

	# Should return the same cached instance
	assert_eq(rules1, rules2, "MapTheme rules should be cached")


func test_validate_no_narrow_passages_valid() -> void:
	# Create a 2x2 block of cells (no narrow passages)
	var cells: Array[Vector2i] = [
		Vector2i(64, 64), Vector2i(65, 64), Vector2i(64, 65), Vector2i(65, 65)
	]

	var is_valid: bool = engine.validate_no_narrow_passages(cells)
	assert_true(is_valid, "2x2 block should have no narrow passages")


func test_deterministic_generation_with_same_seed() -> void:
	var center := Vector2i(64, 64)
	var room_type: Room.RoomType = Room.RoomType.MEDIUM

	# Generate with first RNG
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var points1: PackedVector2Array = engine.generate_room_shape(center, 12, room_type, rng1, null)

	# Generate with second RNG (same seed)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var points2: PackedVector2Array = engine.generate_room_shape(center, 12, room_type, rng2, null)

	assert_eq(points1.size(), points2.size(), "Should generate same number of points")

	# Check if points are identical
	for i in range(points1.size()):
		assert_almost_eq(points1[i].x, points2[i].x, 0.01, "Point X should match")
		assert_almost_eq(points1[i].y, points2[i].y, 0.01, "Point Y should match")


func test_generate_rooms_creates_multiple_rooms() -> void:
	var room_count := 5
	var rooms: Array[Room] = engine.generate_rooms(room_count, context)

	assert_gt(rooms.size(), 0, "Should generate at least one room")
	assert_true(rooms.size() <= room_count, "Should not generate more rooms than requested")

	# Verify each room has required properties
	for room in rooms:
		assert_not_null(room, "Room should not be null")
		assert_gt(room.cells.size(), 0, "Room should have cells")
		assert_gt(room.entrance_points.size(), 0, "Room should have entrance points")


func test_apply_theme_modifications() -> void:
	var room: Room = engine.generate_room(Vector2i(64, 64), Room.RoomType.MEDIUM, 0, context)

	# Apply tech theme modifications
	engine.apply_theme_modifications(room, "tech", context)

	# Room should still be valid after modifications
	assert_not_null(room, "Room should not be null after theme modifications")
	assert_gt(room.cells.size(), 0, "Room should still have cells")
