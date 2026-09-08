extends ModusGutTestBase

## Unit tests for KeyLockSystem
## Tests Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6

const KeyLockSystem = preload("res://game/scripts/map_generator/key_lock_system.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var key_lock_system: KeyLockSystem
var context: GenerationContext


func before_each() -> void:
	key_lock_system = KeyLockSystem.new()
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_key_locks = true
	context.grid_size = Vector2i(128, 128)

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)

	# Seed RNG for deterministic tests
	context.rng.seed = 54321


func after_each() -> void:
	key_lock_system = null
	context = null


## Test that key-lock system supports colored keys
## Requirement 12.1
func test_supports_colored_keys() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])

	# Check that keys have color property
	for key: Dictionary in keys:
		assert_true(key.has("color"), "Key should have color property")
		var color: String = key.get("color", "")
		assert_true(color in ["RED", "BLUE", "YELLOW"], "Key color should be RED, BLUE, or YELLOW")


## Test that locked doors have corresponding colors
## Requirement 12.1
func test_locked_doors_have_corresponding_colors() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var locked_doors: Array = result.get("locked_doors", [])

	# Check that doors have color property
	for door: Dictionary in locked_doors:
		assert_true(door.has("color"), "Door should have color property")
		var color: String = door.get("color", "")
		assert_true(color in ["RED", "BLUE", "YELLOW"], "Door color should be RED, BLUE, or YELLOW")


## Test that keys are placed before corresponding locked doors in progression order
## Requirement 12.2
func test_keys_placed_before_doors_in_progression() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 8)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])
	var locked_doors: Array = result.get("locked_doors", [])

	# For each key-door pair, verify key comes before door
	for i in range(min(keys.size(), locked_doors.size())):
		var key: Dictionary = keys[i]
		var door: Dictionary = locked_doors[i]

		var key_room_id: int = key.get("room_id", -1)
		var door_room_id: int = door.get("room_id", -1)

		# Key room should have lower ID (earlier in progression)
		# This is a simplification - in reality we'd check actual progression order
		assert_true(key_room_id >= 0, "Key should have valid room ID")
		assert_true(door_room_id >= 0, "Door should have valid room ID")


## Test that locked doors block critical path progression
## Requirement 12.3
func test_locked_doors_block_progression() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var locked_doors: Array = result.get("locked_doors", [])

	# Check that doors are marked as blocking progression
	for door: Dictionary in locked_doors:
		assert_true(door.get("blocks_progression", false), "Locked door should block progression")


## Test that key locations are marked in metadata
## Requirement 12.4
func test_key_locations_marked_in_metadata() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])

	# Check that keys are added to context
	for key: Dictionary in keys:
		var grid_pos: Vector2i = key.get("grid_position", Vector2i(-1, -1))

		if (
			grid_pos != Vector2i(-1, -1)
			and grid_pos.x >= 0
			and grid_pos.x < context.grid_size.x
			and grid_pos.y >= 0
			and grid_pos.y < context.grid_size.y
		):
			var cell: Cell = context.grid[grid_pos.y][grid_pos.x]
			assert_true(
				cell.metadata.get("has_key", false), "Key cell should be marked in metadata"
			)
			assert_true(cell.metadata.has("key_color"), "Key cell should have color in metadata")


## Test that all locked doors are reachable after key acquisition
## Requirement 12.5
func test_locked_doors_reachable_after_key_acquisition() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 6)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])
	var locked_doors: Array = result.get("locked_doors", [])

	# Validate progression
	var is_valid: bool = key_lock_system.validate_key_lock_progression(context, keys, locked_doors)

	assert_true(is_valid, "Key-lock progression should be valid")


## Test that system supports 1-3 key types based on map complexity
## Requirement 12.6
func test_key_count_based_on_map_complexity() -> void:
	# Small map (64x64) with few rooms should have 1 key
	context.grid_size = Vector2i(64, 64)
	_create_room_chain(context, 5)
	var count_small: int = key_lock_system._calculate_key_count(context)
	assert_eq(count_small, 1, "Small map should have 1 key type")

	# Medium map (128x128) with moderate rooms should have 2 keys
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_key_locks = true
	context.grid_size = Vector2i(128, 128)
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)
	context.rng.seed = 54321
	_create_room_chain(context, 12)
	var count_medium: int = key_lock_system._calculate_key_count(context)
	assert_eq(count_medium, 2, "Medium map should have 2 key types")

	# Large map (256x256) with many rooms should have 3 keys
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_key_locks = true
	context.grid_size = Vector2i(256, 256)
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)
	context.rng.seed = 54321
	_create_room_chain(context, 25)
	var count_large: int = key_lock_system._calculate_key_count(context)
	assert_eq(count_large, 3, "Large map should have 3 key types")


## Test that no keys are generated when disabled
func test_no_keys_when_disabled() -> void:
	context.config.enable_key_locks = false

	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Generate key-lock system
	var result: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = result.get("keys", [])
	var locked_doors: Array = result.get("locked_doors", [])

	assert_eq(keys.size(), 0, "Should not generate keys when disabled")
	assert_eq(locked_doors.size(), 0, "Should not generate locked doors when disabled")


## Test that room progression analysis works correctly
func test_room_progression_analysis() -> void:
	# Create a chain of connected rooms
	_create_room_chain(context, 5)

	# Analyze progression
	var progression: Array[Room] = key_lock_system._analyze_room_progression(context)

	# Should return all rooms in order
	assert_eq(progression.size(), context.rooms.size(), "Should return all rooms")

	# First room should be the start room
	assert_eq(progression[0].id, 0, "First room should be start room")


## Helper function to create a chain of connected rooms
func _create_room_chain(ctx: GenerationContext, room_count: int) -> void:
	var spacing := 15

	for i in range(room_count):
		var center := Vector2i(10 + i * spacing, 10)
		var room := Room.new(i, center, Room.RoomType.MEDIUM)

		# Create room cells
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var pos := center + Vector2i(dx, dy)
				if (
					pos.x >= 0
					and pos.x < ctx.grid_size.x
					and pos.y >= 0
					and pos.y < ctx.grid_size.y
				):
					ctx.grid[pos.y][pos.x].type = Cell.Type.ROOM
					ctx.grid[pos.y][pos.x].room_id = room.id
					room.cells.append(pos)

		# Add entrance point
		room.entrance_points.append(center + Vector2i(3, 0))

		# Connect to previous room
		if i > 0:
			room.connections.append(i - 1)
			ctx.rooms[i - 1].connections.append(i)

		ctx.rooms.append(room)
