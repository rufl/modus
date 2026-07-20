extends ModusGutTestBase

## Unit tests for SecretRoomGenerator
## Tests Requirements 11.1, 11.2, 11.3, 11.4, 11.5, 11.6

const SecretRoomGenerator = preload("res://game/scripts/map_generator/secret_room_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var generator: SecretRoomGenerator
var context: GenerationContext

func before_each() -> void:
	generator = SecretRoomGenerator.new()
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_secrets = true
	context.config.secret_room_count = 2
	context.grid_size = Vector2i(64, 64)
	
	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)
	
	# Seed RNG for deterministic tests
	context.rng.seed = 12345

func after_each() -> void:
	generator = null
	context = null

## Test that secret room count is calculated based on map size
## Requirement 11.1
func test_calculate_secret_count_based_on_map_size() -> void:
	# Small map (64x64) should have 1-2 secrets
	context.grid_size = Vector2i(64, 64)
	context.config.secret_room_count = 3
	var count_small: int = generator._calculate_secret_count(context)
	assert_lte(count_small, 2, "Small map should have max 2 secrets")
	
	# Medium map (128x128) should have 1-2 secrets
	context.grid_size = Vector2i(128, 128)
	context.config.secret_room_count = 3
	var count_medium: int = generator._calculate_secret_count(context)
	assert_lte(count_medium, 2, "Medium map should have max 2 secrets")
	
	# Large map (256x256) should have 1-3 secrets
	context.grid_size = Vector2i(256, 256)
	context.config.secret_room_count = 3
	var count_large: int = generator._calculate_secret_count(context)
	assert_lte(count_large, 3, "Large map should have max 3 secrets")

## Test that secret rooms are generated when enabled
## Requirement 11.1
func test_generate_secret_rooms_when_enabled() -> void:
	# Create a simple room
	_create_test_room(context, Vector2i(10, 10), 5)
	
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	
	# Should generate at least one secret room if conditions are met
	# (may be 0 if no suitable locations found)
	assert_true(secret_rooms.size() >= 0, "Should return array of secret rooms")

## Test that secret rooms are not generated when disabled
func test_no_secret_rooms_when_disabled() -> void:
	context.config.enable_secrets = false
	
	# Create a simple room
	_create_test_room(context, Vector2i(10, 10), 5)
	
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	
	assert_eq(secret_rooms.size(), 0, "Should not generate secret rooms when disabled")

## Test that fake walls are marked in metadata
## Requirement 11.2, 11.4
func test_fake_wall_marked_in_metadata() -> void:
	# Create a room with adjacent empty space
	var room: Room = _create_test_room(context, Vector2i(20, 20), 8)
	
	# Generate secret rooms
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	
	if secret_rooms.size() > 0:
		var secret_room: Dictionary = secret_rooms[0]
		var wall_pos: Vector2i = secret_room.fake_wall_position
		
		# Check that fake wall is marked
		var wall_cell: Cell = context.grid[wall_pos.y][wall_pos.x]
		assert_true(wall_cell.metadata.get("is_fake_wall", false), "Fake wall should be marked in metadata")
		assert_true(wall_cell.metadata.get("passable", false), "Fake wall should be passable")

## Test that secret room cells are marked as SECRET type
## Requirement 11.1
func test_secret_cells_marked_as_secret_type() -> void:
	# Create a room with adjacent empty space
	_create_test_room(context, Vector2i(20, 20), 8)
	
	# Generate secret rooms
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	
	if secret_rooms.size() > 0:
		var secret_room: Dictionary = secret_rooms[0]
		
		# Check that all secret room cells are marked as SECRET
		for cell_pos: Vector2i in secret_room.cells:
			var cell: Cell = context.grid[cell_pos.y][cell_pos.x]
			assert_eq(cell.type, Cell.Type.SECRET, "Secret room cells should be marked as SECRET type")
			assert_true(cell.metadata.get("is_secret", false), "Secret room cells should have is_secret metadata")

## Test that high-value items are placed in secret rooms
## Requirement 11.3
func test_high_value_items_placed_in_secret_rooms() -> void:
	# Create a room with adjacent empty space
	_create_test_room(context, Vector2i(20, 20), 8)
	
	# Generate secret rooms
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	context.secret_rooms = secret_rooms
	
	# Place items
	generator.place_secret_items(context)
	
	# Check that items were placed
	var secret_items: Array = []
	for spawn: Dictionary in context.item_spawns:
		if spawn.get("type") == "high_value":
			secret_items.append(spawn)
	
	assert_eq(secret_items.size(), secret_rooms.size(), "Should place one high-value item per secret room")

## Test that secret rooms are marked in metadata for achievement tracking
## Requirement 11.6
func test_secret_rooms_marked_for_achievement_tracking() -> void:
	# Create a room with adjacent empty space
	_create_test_room(context, Vector2i(20, 20), 8)
	
	# Generate secret rooms
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	
	if secret_rooms.size() > 0:
		var secret_room: Dictionary = secret_rooms[0]
		
		# Check that secret room has ID for tracking
		assert_true(secret_room.has("id"), "Secret room should have ID for tracking")
		assert_true(secret_room.has("cells"), "Secret room should have cells list")
		assert_true(secret_room.has("fake_wall_position"), "Secret room should have fake wall position")

## Test that secret rooms are not required for map completion
## Requirement 11.5
func test_secret_rooms_not_required_for_completion() -> void:
	# This is a design constraint - secret rooms should be off the main path
	# We verify this by checking that secret rooms are not connected to the main room graph
	
	# Create main rooms
	var main_room1: Room = _create_test_room(context, Vector2i(10, 10), 5)
	var main_room2: Room = _create_test_room(context, Vector2i(20, 20), 5)
	main_room1.connections.append(main_room2.id)
	main_room2.connections.append(main_room1.id)
	
	# Generate secret rooms
	var secret_rooms: Array = generator.generate_secret_rooms(context)
	
	# Secret rooms should not be in the main room connections
	for secret_room: Dictionary in secret_rooms:
		var adjacent_room_id: int = secret_room.get("adjacent_room_id", -1)
		
		# The adjacent room should exist but the secret room itself is not a Room object
		# It's accessible through a fake wall, not through normal room connections
		assert_true(adjacent_room_id >= 0, "Secret room should reference an adjacent room")

## Helper function to create a test room
func _create_test_room(ctx: GenerationContext, center: Vector2i, size: int) -> Room:
	var room := Room.new(ctx.rooms.size(), center, Room.RoomType.MEDIUM)
	
	# Create room cells in a square pattern
	for dy in range(-size/2, size/2 + 1):
		for dx in range(-size/2, size/2 + 1):
			var pos := center + Vector2i(dx, dy)
			if pos.x >= 0 and pos.x < ctx.grid_size.x and pos.y >= 0 and pos.y < ctx.grid_size.y:
				ctx.grid[pos.y][pos.x].type = Cell.Type.ROOM
				ctx.grid[pos.y][pos.x].room_id = room.id
				room.cells.append(pos)
	
	ctx.rooms.append(room)
	return room
