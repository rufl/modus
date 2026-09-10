class_name GameplayElementPlacer
extends RefCounted

## Handles placement of gameplay elements: monsters, items, weapons, ammo, health pickups
## Implements requirements 9 (Monster Placement) and 10 (Item Distribution)

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")


## Place monster spawns based on configuration
## Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.7
## @param context: Generation context with rooms and configuration
func place_monster_spawns(context: GenerationContext) -> void:
	# Skip if monster density is 0
	if context.config.monster_density <= 0.0:
		return

	# Find player start position
	var player_start := _find_player_start_position(context)

	# Calculate total monster count based on density and map size
	var total_monsters := _calculate_monster_count(context)

	# Get eligible rooms for monster placement (exclude player start area)
	var eligible_rooms := _get_eligible_rooms_for_monsters(context, player_start)

	if eligible_rooms.is_empty():
		push_warning("No eligible rooms for monster placement")
		return

	# Place monsters across eligible rooms
	var monsters_placed := 0
	var max_attempts := total_monsters * 3
	var attempts := 0

	while monsters_placed < total_monsters and attempts < max_attempts:
		attempts += 1

		# Select random room weighted by size
		var room: Room = _select_weighted_room(eligible_rooms, context.rng)

		# Find spawn position in room
		var spawn_pos := _find_monster_spawn_position(room, player_start, context)

		if spawn_pos == Vector2i(-1, -1):
			continue

		# Calculate monster tier based on progression
		var progression := _calculate_room_progression(room, player_start, context)
		var tier := _calculate_monster_tier(progression, context)

		# Create spawn point
		var spawn_point := {
			"position": spawn_pos,
			"type": "monster",
			"tier": tier,
			"room_id": room.id,
			"world_position": Vector3(spawn_pos.x * 2.0, 0.0, spawn_pos.y * 2.0),
			"progression": progression
		}

		context.monster_spawns.append(spawn_point)
		monsters_placed += 1

	if monsters_placed < total_monsters:
		push_warning("Only placed %d/%d monsters" % [monsters_placed, total_monsters])


## Calculate total monster count based on density and map size
## @param context: Generation context
## @return: Number of monsters to place
func _calculate_monster_count(context: GenerationContext) -> int:
	var total_cells := context.grid_size.x * context.grid_size.y

	# Base monster count: 1 monster per 100 cells at 1.0 density
	var base_count := int(total_cells / 100.0)

	# Apply density multiplier
	var count := int(base_count * context.config.monster_density)

	# Apply difficulty scaling
	var difficulty_multiplier := _get_difficulty_multiplier(context.config.difficulty_scaling)
	count = int(count * difficulty_multiplier)

	# Respect the authored floor instead of forcing five enemies into every map.
	return maxi(count, maxi(0, context.config.minimum_monsters))


## Get difficulty multiplier for monster count
## @param difficulty: Difficulty level
## @return: Multiplier value
func _get_difficulty_multiplier(difficulty: GenerationConfig.DifficultyLevel) -> float:
	match difficulty:
		GenerationConfig.DifficultyLevel.EASY:
			return 0.7
		GenerationConfig.DifficultyLevel.NORMAL:
			return 1.0
		GenerationConfig.DifficultyLevel.HARD:
			return 1.5
		GenerationConfig.DifficultyLevel.NIGHTMARE:
			return 2.0

	return 1.0


## Find player start position (first room center or grid center)
## @param context: Generation context
## @return: Player start position
func _find_player_start_position(context: GenerationContext) -> Vector2i:
	# Use first room as player start if available
	if not context.rooms.is_empty():
		return context.rooms[0].center

	# Fallback to grid center
	return Vector2i(context.grid_size.x / 2, context.grid_size.y / 2)


## Get rooms eligible for monster placement (not near player start)
## Requirements: 9.2 - Avoid placement near player start (within 10 meters = 5 cells)
## @param context: Generation context
## @param player_start: Player start position
## @return: Array of eligible rooms
func _get_eligible_rooms_for_monsters(
	context: GenerationContext, player_start: Vector2i
) -> Array[Room]:
	var eligible: Array[Room] = []
	var min_distance := 5  # 10 meters = 5 cells (2m per cell)

	for room in context.rooms:
		# Skip boss arenas (they have their own spawn logic)
		if room.type == Room.RoomType.BOSS_ARENA:
			continue

		# Check distance from player start
		var distance := _manhattan_distance(room.center, player_start)

		if distance >= min_distance:
			eligible.append(room)

	return eligible


## Select room weighted by size (larger rooms more likely)
## @param rooms: Array of rooms to choose from
## @param rng: Random number generator
## @return: Selected room
func _select_weighted_room(rooms: Array[Room], rng: RandomNumberGenerator) -> Room:
	if rooms.is_empty():
		return null

	# Calculate total weight
	var total_weight := 0.0
	for room in rooms:
		total_weight += room.cells.size()

	# Select random value
	var value := rng.randf() * total_weight

	# Find room
	var cumulative := 0.0
	for room in rooms:
		cumulative += room.cells.size()
		if value <= cumulative:
			return room

	# Fallback to last room
	return rooms[-1]


## Find suitable monster spawn position in room
## Requirements: 9.5 - Ensure spawns have valid navigation mesh coverage
## Requirements: 9.7 - Block line-of-sight to player start
## @param room: Room to place spawn in
## @param player_start: Player start position
## @param context: Generation context
## @return: Spawn position or Vector2i(-1, -1) if not found
func _find_monster_spawn_position(
	room: Room, player_start: Vector2i, context: GenerationContext
) -> Vector2i:
	var max_attempts := 20

	for attempt in range(max_attempts):
		# Select random cell from room
		var cell: Vector2i = room.cells[context.rng.randi() % room.cells.size()]

		# Check if cell has line-of-sight to player start
		if _has_line_of_sight(cell, player_start, context.grid):
			continue  # Skip cells with direct line-of-sight

		# Check if cell is walkable (will have navigation mesh)
		if not _is_walkable_cell(cell, context.grid):
			continue

		return cell

	# If no ideal position found, return any walkable cell
	for cell in room.cells:
		if _is_walkable_cell(cell, context.grid):
			return cell

	return Vector2i(-1, -1)


## Check if there's line-of-sight between two positions
## Uses simple raycast on grid
## @param from: Start position
## @param to: End position
## @param grid: Grid layout
## @return: True if line-of-sight exists
func _has_line_of_sight(from: Vector2i, to: Vector2i, grid: Array[Array]) -> bool:
	# Use Bresenham's line algorithm for grid raycast
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err: int = dx - dy

	var current := from

	while current != to:
		# Check if current cell blocks line-of-sight
		if (
			current.y >= 0
			and current.y < grid.size()
			and current.x >= 0
			and current.x < grid[current.y].size()
		):
			var cell: Cell = grid[current.y][current.x]

			# Empty cells block line-of-sight
			if cell.type == Cell.Type.EMPTY:
				return false
		else:
			return false  # Out of bounds

		# Move to next cell
		var e2: int = 2 * err

		if e2 > -dy:
			err -= dy
			current.x += sx

		if e2 < dx:
			err += dx
			current.y += sy

	return true


## Check if cell is walkable (has navigation mesh)
## @param cell_pos: Cell position
## @param grid: Grid layout
## @return: True if walkable
func _is_walkable_cell(cell_pos: Vector2i, grid: Array[Array]) -> bool:
	if (
		cell_pos.y < 0
		or cell_pos.y >= grid.size()
		or cell_pos.x < 0
		or cell_pos.x >= grid[cell_pos.y].size()
	):
		return false

	var cell: Cell = grid[cell_pos.y][cell_pos.x]

	# Walkable cell types
	return (
		cell.type
		in [
			Cell.Type.ROOM,
			Cell.Type.HALLWAY,
			Cell.Type.OUTDOOR,
			Cell.Type.CAVE,
			Cell.Type.BOSS_ARENA
		]
	)


## Calculate room progression (0.0 = near start, 1.0 = far from start)
## @param room: Room to calculate progression for
## @param player_start: Player start position
## @param context: Generation context
## @return: Progression value 0.0-1.0
func _calculate_room_progression(
	room: Room, player_start: Vector2i, context: GenerationContext
) -> float:
	var distance := _manhattan_distance(room.center, player_start)
	var max_distance := context.grid_size.x + context.grid_size.y  # Maximum possible distance

	return clampf(float(distance) / float(max_distance), 0.0, 1.0)


## Calculate monster tier based on progression and difficulty
## Requirements: 9.3, 9.4 - Scale monster count and tier based on difficulty_scaling
## @param progression: Room progression (0.0-1.0)
## @param context: Generation context
## @return: Monster tier (1-5)
func _calculate_monster_tier(progression: float, context: GenerationContext) -> int:
	# Base tier from progression
	var base_tier := 1 + int(progression * 3.0)  # 1-4 based on progression

	# Apply difficulty scaling
	var difficulty_bonus := 0
	match context.config.difficulty_scaling:
		GenerationConfig.DifficultyLevel.EASY:
			difficulty_bonus = -1
		GenerationConfig.DifficultyLevel.NORMAL:
			difficulty_bonus = 0
		GenerationConfig.DifficultyLevel.HARD:
			difficulty_bonus = 1
		GenerationConfig.DifficultyLevel.NIGHTMARE:
			difficulty_bonus = 2

	var tier := base_tier + difficulty_bonus

	return clampi(tier, 1, 5)


## Calculate Manhattan distance between two positions
## @param a: First position
## @param b: Second position
## @return: Manhattan distance
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Place boss monsters in boss arena areas
## Requirements: 9.6 - Place boss monsters only in boss arena areas
## @param context: Generation context with boss arenas
func place_boss_monsters(context: GenerationContext) -> void:
	# Boss spawns are already placed by BossArenaGenerator.place_boss_spawn_marker()
	# This function validates and ensures proper configuration

	for spawn: Dictionary in context.monster_spawns:
		if spawn.get("type") == "boss":
			# Ensure proper spawn marker configuration
			if not spawn.has("world_position"):
				var pos: Vector2i = spawn["position"]
				spawn["world_position"] = Vector3(pos.x * 2.0, 0.0, pos.y * 2.0)

			if not spawn.has("tier"):
				spawn["tier"] = 5  # Boss tier is always maximum


## Place weapon and ammo pickups
## Requirements: 10.1, 10.2, 10.4, 10.5
## @param context: Generation context
func place_weapons_and_ammo(context: GenerationContext) -> void:
	# Skip if item density is 0
	if context.config.item_density <= 0.0:
		return

	var player_start := _find_player_start_position(context)

	# Place weapons in early rooms (first 20% of progression)
	_place_weapons(context, player_start)

	# Place ammo proportional to monster count
	_place_ammo(context, player_start)


## Place weapon pickups in early rooms
## Requirements: 10.1 - Place weapon pickups in early rooms (first 20% of progression)
## Requirements: 10.4 - Ensure at least one weapon before first combat
## @param context: Generation context
## @param player_start: Player start position
func _place_weapons(context: GenerationContext, player_start: Vector2i) -> void:
	# Get early rooms (first 20% of progression)
	var early_rooms := _get_early_rooms(context, player_start, 0.2)

	if early_rooms.is_empty():
		push_warning("No early rooms found for weapon placement")
		return

	# Calculate weapon count based on item density
	var weapon_count := maxi(int(3.0 * context.config.item_density), 1)

	# Ensure at least one weapon in the very first room (before first combat)
	var _first_weapon_placed := false

	for i in range(weapon_count):
		var room: Room

		if i == 0 and not early_rooms.is_empty():
			# First weapon goes in earliest room
			room = early_rooms[0]
			_first_weapon_placed = true
		else:
			# Other weapons distributed in early rooms
			room = early_rooms[context.rng.randi() % early_rooms.size()]

		# Find spawn position
		var spawn_pos := _find_item_spawn_position(room, context)

		if spawn_pos == Vector2i(-1, -1):
			continue

		# Calculate weapon quality based on progression
		var progression := _calculate_room_progression(room, player_start, context)
		var quality := _calculate_item_quality(progression)

		# Create weapon spawn
		var spawn_point := {
			"position": spawn_pos,
			"type": "weapon",
			"quality": quality,
			"room_id": room.id,
			"world_position": Vector3(spawn_pos.x * 2.0, 0.5, spawn_pos.y * 2.0),
			"progression": progression
		}

		context.item_spawns.append(spawn_point)


## Place ammo pickups proportional to monster count
## Requirements: 10.2 - Distribute ammo proportional to expected monster count
## @param context: Generation context
## @param player_start: Player start position
func _place_ammo(context: GenerationContext, player_start: Vector2i) -> void:
	# Calculate ammo count based on monster count (1 ammo per 2 monsters)
	var monster_count := context.monster_spawns.size()
	var ammo_count := maxi(int(monster_count / 2.0 * context.config.item_density), 3)

	# Get all non-boss rooms
	var eligible_rooms := _get_non_boss_rooms(context)

	if eligible_rooms.is_empty():
		push_warning("No eligible rooms for ammo placement")
		return

	# Place ammo across rooms
	for i in range(ammo_count):
		# Select random room
		var room: Room = eligible_rooms[context.rng.randi() % eligible_rooms.size()]

		# Find spawn position
		var spawn_pos := _find_item_spawn_position(room, context)

		if spawn_pos == Vector2i(-1, -1):
			continue

		# Calculate ammo quality based on progression
		var progression := _calculate_room_progression(room, player_start, context)
		var quality := _calculate_item_quality(progression)

		# Create ammo spawn
		var spawn_point := {
			"position": spawn_pos,
			"type": "ammo",
			"quality": quality,
			"room_id": room.id,
			"world_position": Vector3(spawn_pos.x * 2.0, 0.5, spawn_pos.y * 2.0),
			"progression": progression
		}

		context.item_spawns.append(spawn_point)


## Get early rooms (within progression threshold)
## @param context: Generation context
## @param player_start: Player start position
## @param threshold: Progression threshold (0.0-1.0)
## @return: Array of early rooms
func _get_early_rooms(
	context: GenerationContext, player_start: Vector2i, threshold: float
) -> Array[Room]:
	var early_rooms: Array[Room] = []

	for room in context.rooms:
		# Skip boss arenas
		if room.type == Room.RoomType.BOSS_ARENA:
			continue

		var progression := _calculate_room_progression(room, player_start, context)

		if progression <= threshold:
			early_rooms.append(room)

	# Sort by progression (earliest first)
	early_rooms.sort_custom(
		func(a: Room, b: Room) -> bool:
			var prog_a := _calculate_room_progression(a, player_start, context)
			var prog_b := _calculate_room_progression(b, player_start, context)
			return prog_a < prog_b
	)

	return early_rooms


## Get non-boss rooms
## @param context: Generation context
## @return: Array of non-boss rooms
func _get_non_boss_rooms(context: GenerationContext) -> Array[Room]:
	var rooms: Array[Room] = []

	for room in context.rooms:
		if room.type != Room.RoomType.BOSS_ARENA:
			rooms.append(room)

	return rooms


## Find suitable item spawn position in room
## @param room: Room to place item in
## @param context: Generation context
## @return: Spawn position or Vector2i(-1, -1) if not found
func _find_item_spawn_position(room: Room, context: GenerationContext) -> Vector2i:
	var max_attempts := 20

	for attempt in range(max_attempts):
		# Select random cell from room
		var cell: Vector2i = room.cells[context.rng.randi() % room.cells.size()]

		# Check if cell is walkable
		if _is_walkable_cell(cell, context.grid):
			return cell

	# Fallback to first walkable cell
	for cell in room.cells:
		if _is_walkable_cell(cell, context.grid):
			return cell

	return Vector2i(-1, -1)


## Calculate item quality based on progression
## Requirements: 10.5 - Scale item quality based on map progression
## @param progression: Room progression (0.0-1.0)
## @return: Item quality (1-5)
func _calculate_item_quality(progression: float) -> int:
	# Quality increases with progression
	var quality := 1 + int(progression * 4.0)  # 1-5 based on progression

	return clampi(quality, 1, 5)


## Place health pickups near high-difficulty areas
## Requirements: 10.3 - Place health pickups near high-difficulty areas
## @param context: Generation context
func place_health_pickups(context: GenerationContext) -> void:
	# Skip if item density is 0
	if context.config.item_density <= 0.0:
		return

	var player_start := _find_player_start_position(context)

	# Calculate health pickup count based on item density and map size
	var health_count := _calculate_health_pickup_count(context)

	# Get high-difficulty rooms (later in progression)
	var high_difficulty_rooms := _get_high_difficulty_rooms(context, player_start)

	if high_difficulty_rooms.is_empty():
		# Fallback to all rooms if no high-difficulty rooms found
		high_difficulty_rooms = _get_non_boss_rooms(context)

	if high_difficulty_rooms.is_empty():
		push_warning("No eligible rooms for health pickup placement")
		return

	# Place health pickups
	var _pickups_placed := 0

	for i in range(health_count):
		# Select room weighted by difficulty (higher difficulty = more likely)
		var room: Room = _select_room_by_difficulty(high_difficulty_rooms, player_start, context)

		# Find spawn position
		var spawn_pos := _find_item_spawn_position(room, context)

		if spawn_pos == Vector2i(-1, -1):
			continue

		# Calculate health amount based on progression
		var progression := _calculate_room_progression(room, player_start, context)
		var amount := _calculate_health_amount(progression)

		# Create health pickup spawn
		var spawn_point := {
			"position": spawn_pos,
			"type": "health",
			"amount": amount,
			"room_id": room.id,
			"world_position": Vector3(spawn_pos.x * 2.0, 0.5, spawn_pos.y * 2.0),
			"progression": progression
		}

		context.item_spawns.append(spawn_point)
		_pickups_placed += 1

	# Balance health distribution across map
	_balance_health_distribution(context, player_start)


## Calculate health pickup count
## @param context: Generation context
## @return: Number of health pickups to place
func _calculate_health_pickup_count(context: GenerationContext) -> int:
	var total_cells := context.grid_size.x * context.grid_size.y

	# Base count: 1 health per 200 cells at 1.0 density
	var base_count := int(total_cells / 200.0)

	# Apply density multiplier
	var count := int(base_count * context.config.item_density)

	# Ensure minimum count
	return maxi(count, 3)


## Get high-difficulty rooms (later in progression, more monsters)
## @param context: Generation context
## @param player_start: Player start position
## @return: Array of high-difficulty rooms
func _get_high_difficulty_rooms(context: GenerationContext, player_start: Vector2i) -> Array[Room]:
	var high_difficulty: Array[Room] = []

	for room in context.rooms:
		# Skip boss arenas
		if room.type == Room.RoomType.BOSS_ARENA:
			continue

		var progression := _calculate_room_progression(room, player_start, context)

		# High difficulty = progression > 0.4
		if progression > 0.4:
			high_difficulty.append(room)

	return high_difficulty


## Select room weighted by difficulty (higher progression = more likely)
## @param rooms: Array of rooms to choose from
## @param player_start: Player start position
## @param context: Generation context
## @return: Selected room
func _select_room_by_difficulty(
	rooms: Array[Room], player_start: Vector2i, context: GenerationContext
) -> Room:
	if rooms.is_empty():
		return null

	# Calculate total weight (progression values)
	var total_weight := 0.0
	for room in rooms:
		var progression := _calculate_room_progression(room, player_start, context)
		total_weight += progression + 0.1  # Add 0.1 to ensure non-zero weight

	# Select random value
	var value := context.rng.randf() * total_weight

	# Find room
	var cumulative := 0.0
	for room in rooms:
		var progression := _calculate_room_progression(room, player_start, context)
		cumulative += progression + 0.1
		if value <= cumulative:
			return room

	# Fallback to last room
	return rooms[-1]


## Calculate health amount based on progression
## @param progression: Room progression (0.0-1.0)
## @return: Health amount (25, 50, 100)
func _calculate_health_amount(progression: float) -> int:
	if progression < 0.3:
		return 25  # Small health pack
	if progression < 0.7:
		return 50  # Medium health pack
	return 100  # Large health pack


## Balance health distribution across map
## Ensures health pickups are spread out, not clustered
## @param context: Generation context
## @param _player_start: Player start position (unused)
func _balance_health_distribution(context: GenerationContext, _player_start: Vector2i) -> void:
	# Get all health pickups
	var health_pickups: Array[Dictionary] = []

	for spawn: Dictionary in context.item_spawns:
		if spawn.get("type") == "health":
			health_pickups.append(spawn)

	if health_pickups.size() < 2:
		return  # Nothing to balance

	# Check for clusters (health pickups too close together)
	var min_distance := 10  # Minimum distance between health pickups
	var to_remove: Array[Dictionary] = []

	for i in range(health_pickups.size()):
		for j in range(i + 1, health_pickups.size()):
			var pos_i: Vector2i = health_pickups[i]["position"]
			var pos_j: Vector2i = health_pickups[j]["position"]

			var distance := _manhattan_distance(pos_i, pos_j)

			if distance < min_distance:
				# Remove the one with lower progression (keep the one in harder area)
				var prog_i: float = health_pickups[i].get("progression", 0.0)
				var prog_j: float = health_pickups[j].get("progression", 0.0)

				if prog_i < prog_j:
					to_remove.append(health_pickups[i])
				else:
					to_remove.append(health_pickups[j])

	# Remove clustered pickups
	for pickup in to_remove:
		context.item_spawns.erase(pickup)
