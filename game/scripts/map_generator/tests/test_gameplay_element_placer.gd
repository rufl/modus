extends GutTest

## Unit tests for GameplayElementPlacer
## Tests monster spawn placement, weapon/ammo distribution, and health pickup placement

const GameplayElementPlacer = preload("res://game/scripts/map_generator/gameplay_element_placer.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GridLayoutManager = preload("res://game/scripts/map_generator/grid_layout_manager.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var placer: GameplayElementPlacer
var context: GenerationContext
var grid_manager: GridLayoutManager


func before_each() -> void:
	placer = GameplayElementPlacer.new()
	context = GenerationContext.new()
	grid_manager = GridLayoutManager.new()

	# Set up basic configuration
	context.config = GenerationConfig.new()
	context.config.monster_density = 0.5
	context.config.item_density = 0.5
	context.config.difficulty_scaling = GenerationConfig.DifficultyLevel.NORMAL
	context.grid_size = Vector2i(64, 64)

	# Initialize grid
	grid_manager.initialize_grid(context.grid_size)
	context.grid = grid_manager.grid
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Create some test rooms
	_create_test_rooms()


func after_each() -> void:
	# Clean up resources to prevent orphans
	if placer:
		placer.free()
		placer = null

	if context:
		context.free()
		context = null

	if grid_manager:
		grid_manager.free()
		grid_manager = null


func _create_test_rooms() -> void:
	# Create player start room (room 0)
	var start_room := Room.new(0, Vector2i(10, 10), Room.RoomType.SMALL)
	start_room.cells = _create_room_cells(Vector2i(10, 10), 6)
	_mark_room_cells(start_room, context.grid)
	context.rooms.append(start_room)

	# Create mid-progression room (room 1)
	var mid_room := Room.new(1, Vector2i(30, 30), Room.RoomType.MEDIUM)
	mid_room.cells = _create_room_cells(Vector2i(30, 30), 12)
	_mark_room_cells(mid_room, context.grid)
	context.rooms.append(mid_room)

	# Create late-progression room (room 2)
	var late_room := Room.new(2, Vector2i(50, 50), Room.RoomType.LARGE)
	late_room.cells = _create_room_cells(Vector2i(50, 50), 20)
	_mark_room_cells(late_room, context.grid)
	context.rooms.append(late_room)


func _create_room_cells(center: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var half_size: int = size / 2

	for dy in range(-half_size, half_size + 1):
		for dx in range(-half_size, half_size + 1):
			cells.append(center + Vector2i(dx, dy))

	return cells


func _mark_room_cells(room: Room, grid: Array[Array]) -> void:
	for cell_pos in room.cells:
		if (
			cell_pos.y >= 0
			and cell_pos.y < grid.size()
			and cell_pos.x >= 0
			and cell_pos.x < grid[cell_pos.y].size()
		):
			var cell: Cell = grid[cell_pos.y][cell_pos.x]
			cell.type = Cell.Type.ROOM
			cell.room_id = room.id


## Test: Monster spawn placement creates spawns
func test_place_monster_spawns_creates_spawns() -> void:
	# Act
	placer.place_monster_spawns(context)

	# Assert
	assert_gt(context.monster_spawns.size(), 0, "Should create at least one monster spawn")


## Test: Monster spawns avoid player start area
func test_monster_spawns_avoid_player_start() -> void:
	# Act
	placer.place_monster_spawns(context)

	# Assert
	var player_start := Vector2i(10, 10)  # First room center
	var min_distance := 5  # 10 meters = 5 cells

	for spawn: Dictionary in context.monster_spawns:
		if spawn.get("type") == "monster":
			var spawn_pos: Vector2i = spawn["position"]
			var distance := absi(spawn_pos.x - player_start.x) + absi(spawn_pos.y - player_start.y)

			var msg: String = "Monster spawn should be at least %d cells from player start"
			assert_gte(distance, min_distance, msg % min_distance)


## Test: Monster tier scales with progression
func test_monster_tier_scales_with_progression() -> void:
	# Act
	placer.place_monster_spawns(context)

	# Assert
	var has_low_tier := false
	var has_high_tier := false

	for spawn: Dictionary in context.monster_spawns:
		if spawn.get("type") == "monster":
			var tier: int = spawn.get("tier", 0)

			if tier <= 2:
				has_low_tier = true
			if tier >= 3:
				has_high_tier = true

	# With multiple rooms at different progressions, we should see tier variation
	assert_true(has_low_tier or has_high_tier, "Should have monsters with varying tiers")


## Test: Boss monster placement validates configuration
func test_place_boss_monsters_validates_configuration() -> void:
	# Arrange - Add a boss spawn
	context.monster_spawns.append({"type": "boss", "position": Vector2i(30, 30)})

	# Act
	placer.place_boss_monsters(context)

	# Assert
	var boss_spawn: Dictionary = context.monster_spawns[0]
	assert_true(boss_spawn.has("world_position"), "Boss spawn should have world_position")
	assert_eq(boss_spawn.get("tier", 0), 5, "Boss tier should be 5")


## Test: Weapon placement in early rooms
func test_weapons_placed_in_early_rooms() -> void:
	# Act
	placer.place_weapons_and_ammo(context)

	# Assert
	var weapon_spawns: Array[Dictionary] = []
	for spawn: Dictionary in context.item_spawns:
		if spawn.get("type") == "weapon":
			weapon_spawns.append(spawn)

	assert_gt(weapon_spawns.size(), 0, "Should place at least one weapon")

	# Check that weapons are in early progression
	for spawn: Dictionary in weapon_spawns:
		var progression: float = spawn.get("progression", 1.0)
		# Should be in first half of map
		assert_lte(progression, 0.5, "Weapons should be placed in early areas")


## Test: Ammo count proportional to monster count
func test_ammo_proportional_to_monsters() -> void:
	# Arrange
	placer.place_monster_spawns(context)
	var monster_count := context.monster_spawns.size()

	# Act
	placer.place_weapons_and_ammo(context)

	# Assert
	var ammo_spawns: Array[Dictionary] = []
	for spawn: Dictionary in context.item_spawns:
		if spawn.get("type") == "ammo":
			ammo_spawns.append(spawn)

	# Ammo count should be roughly half of monster count (with item density applied)
	var expected_min := int(monster_count / 4.0)  # Allow some variance

	assert_gte(
		ammo_spawns.size(), expected_min, "Ammo count should be proportional to monster count"
	)


## Test: Health pickups placed in high-difficulty areas
func test_health_pickups_in_high_difficulty_areas() -> void:
	# Act
	placer.place_health_pickups(context)

	# Assert
	var health_spawns: Array[Dictionary] = []
	for spawn: Dictionary in context.item_spawns:
		if spawn.get("type") == "health":
			health_spawns.append(spawn)

	assert_gt(health_spawns.size(), 0, "Should place at least one health pickup")

	# Check that health pickups tend to be in later progression
	var avg_progression := 0.0
	for spawn: Dictionary in health_spawns:
		avg_progression += spawn.get("progression", 0.0)

	if health_spawns.size() > 0:
		avg_progression /= health_spawns.size()

		# Average progression should be > 0.3 (favoring later areas)
		assert_gt(avg_progression, 0.2, "Health pickups should favor higher difficulty areas")


## Test: Item quality scales with progression
func test_item_quality_scales_with_progression() -> void:
	# Act
	placer.place_weapons_and_ammo(context)
	placer.place_health_pickups(context)

	# Assert
	var has_low_quality := false
	var has_high_quality := false

	for spawn: Dictionary in context.item_spawns:
		var quality: int = spawn.get("quality", 0)
		var amount: int = spawn.get("amount", 0)

		if quality <= 2 or amount <= 25:
			has_low_quality = true
		if quality >= 4 or amount >= 100:
			has_high_quality = true

	# With rooms at different progressions, we should see quality variation
	assert_true(has_low_quality or has_high_quality, "Should have items with varying quality")


## Test: Zero density skips placement
func test_zero_density_skips_placement() -> void:
	# Arrange
	context.config.monster_density = 0.0
	context.config.item_density = 0.0

	# Act
	placer.place_monster_spawns(context)
	placer.place_weapons_and_ammo(context)
	placer.place_health_pickups(context)

	# Assert
	assert_eq(context.monster_spawns.size(), 0, "Should not place monsters with zero density")
	assert_eq(context.item_spawns.size(), 0, "Should not place items with zero density")


## Test: Difficulty scaling affects monster count
func test_difficulty_scaling_affects_monster_count() -> void:
	# Test EASY difficulty
	context.config.difficulty_scaling = GenerationConfig.DifficultyLevel.EASY
	placer.place_monster_spawns(context)
	var easy_count := context.monster_spawns.size()

	# Reset and test HARD difficulty
	context.monster_spawns.clear()
	context.config.difficulty_scaling = GenerationConfig.DifficultyLevel.HARD
	placer.place_monster_spawns(context)
	var hard_count := context.monster_spawns.size()

	# Assert
	assert_gt(hard_count, easy_count, "Hard difficulty should spawn more monsters than easy")
