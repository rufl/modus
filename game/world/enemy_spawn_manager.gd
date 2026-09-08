class_name EnemySpawnManager
extends Node

signal enemy_spawned(enemy: Node, position: Vector3)

const EnemyScene: PackedScene = preload("res://game/entities/enemies/enemy.tscn")
const SpawnPointScript: GDScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
const ItemSpawnerScript: GDScript = preload("res://game/scripts/features/loot/item_spawner.gd")

var enemy_spawns: PackedVector3Array = PackedVector3Array(
	[
		Vector3(5, 0.5, 5),
		Vector3(-5, 0.5, 5),
		Vector3(5, 0.5, -5),
		Vector3(-5, 0.5, -5),
		Vector3(10, 0.5, 0),
		Vector3(-10, 0.5, 0),
		Vector3(0, 0.5, 10),
		Vector3(0, 0.5, -10),
	]
)

var _world: Node
var _match_stats: Dictionary


func setup(world: Node, stats: Dictionary) -> void:
	_world = world
	_match_stats = stats
	# Defensive init
	if not _match_stats.has("enemies_spawned"):
		_match_stats["enemies_spawned"] = 0
	if not _match_stats.has("enemies_relocated"):
		_match_stats["enemies_relocated"] = 0


## Main spawn entry point - called when match starts


func spawn_enemies() -> void:
	if not _world.multiplayer.is_server():
		return

	# Authored levels take precedence over legacy arena spawns.
	for level_root: Node in _world.get_tree().get_nodes_in_group("level_root"):
		if level_root == _world or _world.is_ancestor_of(level_root):
			_spawn_from_level_data(level_root)
			return

	# Legacy spawning logic (fallback)
	_spawn_legacy_enemies()


func _spawn_from_level_data(level_root: Node) -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[EnemySpawn] Spawning from Level Data: " + " " + str(level_root.name), "World")

	# find_children's type filter only recognizes native classes, not script classes.
	for node: Node in level_root.find_children("*", "Node3D", true, false):
		if not node is SpawnPointScript:
			continue

		var data: Dictionary = node.spawn()
		if data.is_empty():
			continue

		match data.get("type", ""):
			"enemy":
				_spawn_enemy_from_data(data)
			"item":
				_spawn_item_from_data(data)

	_start_stuck_detection()


func _spawn_enemy_from_data(data: Dictionary) -> void:
	var enemy_id: String = data.get("id", "")
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var rot: Vector3 = data.get("rotation", Vector3.ZERO)
	var patrol_radius: float = data.get("patrol_radius", 0.0)

	var enemy: Node = spawn_enemy_at(pos, enemy_id, false, rot)

	if enemy:
		# Apply patrol radius to AI controller if present
		if patrol_radius > 0.0:
			var ai_controller: Node = enemy.get_node_or_null("AIController")
			if ai_controller and "patrol_radius" in ai_controller:
				ai_controller.patrol_radius = patrol_radius


func _spawn_item_from_data(data: Dictionary) -> void:
	var spawner: LootItemSpawner = ItemSpawnerScript.new()
	spawner.spawn_on_ready = false
	spawner.spawn_radius = 0.0
	spawner.spawn_height = 0.0
	spawner.spawn_parent = _world
	spawner.respawn_delay = data.get("respawn_time", 0.0)
	spawner.respawn_enabled = spawner.respawn_delay > 0.0
	add_child(spawner)
	spawner.spawn_item_at(
		data.get("position", Vector3.ZERO), data.get("id", ""), data.get("rotation", Vector3.ZERO)
	)


func _spawn_legacy_enemies() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[EnemySpawn] === LEGACY ENEMY SPAWNING START ===", "World")
		logger.info("[EnemySpawn] Total spawn points: " + " " + str(enemy_spawns.size()), "World")

	# Enemy IDs for basic enemies (matching data service keys)
	var basic_enemy_ids: Array[String] = ["grunt_basic", "imp"]

	# Spawn basic enemies at original positions (with validation)
	for i: int in range(enemy_spawns.size()):
		var desired_pos: Vector3 = enemy_spawns[i]
		var spawn_pos: Vector3 = _find_valid_spawn_position(desired_pos)

		var enemy: Node = EnemyScene.instantiate()
		enemy.name = "Enemy_" + str(i)
		enemy.position = spawn_pos

		# Assign enemy_id based on spawn index (variety)
		var enemy_type: String = basic_enemy_ids[i % basic_enemy_ids.size()]
		if "enemy_id" in enemy:
			enemy.enemy_id = enemy_type

		_world.add_child(enemy)
		_match_stats["enemies_spawned"] += 1
		if logger and logger.has_method("info"):
			logger.info(
				"[EnemySpawn] Spawned basic '%s' (%s) at %s" % [enemy.name, enemy_type, spawn_pos],
				"World"
			)

	# Spawn fewer special enemies at more open positions
	_spawn_special_enemy("Healer_1", Vector3(12, 0.5, 12), "healer")
	_spawn_special_enemy("Assassin_1", Vector3(-12, 0.5, 12), "assassin")
	_spawn_special_enemy("Summoner_1", Vector3(0, 0.5, -12), "summoner")

	# Spawn just 1 swarmling for testing
	_spawn_special_enemy("Swarmling_0", Vector3(-12, 0.5, -12), "swarmling")

	if logger and logger.has_method("info"):
		logger.info("[EnemySpawn] === LEGACY ENEMY SPAWNING COMPLETE ===", "World")
		var enemy_count: int = _world.get_tree().get_nodes_in_group("enemies").size()
		logger.info("[EnemySpawn] Total enemies spawned: " + " " + str(enemy_count), "World")

	# Start stuck detection timer
	_start_stuck_detection()


## Helper to spawn a special enemy


func _spawn_special_enemy(ename: String, pos: Vector3, enemy_id: String) -> void:
	var spawn_pos: Vector3 = _find_valid_spawn_position(pos)
	var was_relocated: bool = spawn_pos != pos

	var enemy: Node = EnemyScene.instantiate()
	enemy.name = ename
	enemy.position = spawn_pos
	if "enemy_id" in enemy:
		enemy.enemy_id = enemy_id
	_world.add_child(enemy)
	_match_stats["enemies_spawned"] += 1

	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		if was_relocated:
			logger.info(
				"[EnemySpawn] Spawned special '%s' (%s) MOVED to %s" % [ename, enemy_id, spawn_pos],
				"World"
			)
		else:
			logger.info(
				"[EnemySpawn] Spawned special '%s' (%s) at %s" % [ename, enemy_id, spawn_pos],
				"World"
			)


## Spawn an enemy at a specific position (public API)


func spawn_enemy_at(
	pos: Vector3,
	enemy_id: String = "grunt_basic",
	is_aggressive: bool = false,
	rot: Vector3 = Vector3.ZERO
) -> Node:
	if not _world.multiplayer.is_server():
		return null

	# Check global enemy cap
	var current_count: int = _world.get_tree().get_nodes_in_group("enemies").size()
	var cm: Node = GameManager.get_core_system("config")
	var max_enemies: int = cm.get_value("enemies.max_count", 30) if cm else 30
	if current_count >= max_enemies:
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.debug(
				"Enemy cap reached (%d/%d), skipping spawn" % [current_count, max_enemies],
				"EnemySpawn"
			)
		return null

	var spawn_pos: Vector3 = _find_valid_spawn_position(pos)
	var enemy: Node3D = EnemyScene.instantiate()

	enemy.name = "Enemy_" + str(Time.get_ticks_msec())
	var spawn_transform := Transform3D(Basis.from_euler(rot), spawn_pos)
	enemy.transform = (
		(_world as Node3D).global_transform.affine_inverse() * spawn_transform
		if _world is Node3D
		else spawn_transform
	)
	if "enemy_id" in enemy:
		enemy.enemy_id = enemy_id

	# Pass aggression flag via meta (processed in Enemy._ready)
	if is_aggressive:
		enemy.set_meta("spawn_aggressive", true)

	_world.add_child(enemy, true)

	# Track spawn in match stats
	_match_stats["enemies_spawned"] += 1

	# Emit spawned signal for other systems (minimap, wave UI, etc.)
	var events: Node = GameManager.get_core_system("events")
	if GameManager and events and events.has_method("emit"):
		events.emit("enemy_spawned", {"enemy": enemy, "position": spawn_pos})
	enemy_spawned.emit(enemy, spawn_pos)

	return enemy


## Validate and find a safe spawn position


func _find_valid_spawn_position(desired_pos: Vector3) -> Vector3:
	if _validate_spawn_position(desired_pos):
		return desired_pos

	# Try to find alternative nearby position
	var search_radius: float = 3.0
	var attempts: int = 8

	for i: int in range(attempts):
		var angle: float = (TAU / attempts) * i
		var offset := Vector3(cos(angle) * search_radius, 0, sin(angle) * search_radius)
		var test_pos: Vector3 = desired_pos + offset

		if _validate_spawn_position(test_pos):
			_match_stats["enemies_relocated"] += 1
			return test_pos

	# As last resort, move up to avoid being stuck in floor
	_match_stats["enemies_relocated"] += 1
	return desired_pos + Vector3(0, 1, 0)


## Validate if a spawn position is in open space


func _validate_spawn_position(pos: Vector3) -> bool:
	var world_3d: World3D = _world.get_viewport().world_3d
	if not world_3d:
		return true
	var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if not space:
		return true

	# Check 1: Raycast down to find ground
	var down_query := PhysicsRayQueryParameters3D.create(
		pos + Vector3(0, 2, 0), pos - Vector3(0, 5, 0), CollisionLayers.LAYER_WORLD
	)
	var ground_result := space.intersect_ray(down_query)
	if not ground_result:
		return false

	# Check 2: Capsule check for clearance
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.0
	var capsule_query := PhysicsShapeQueryParameters3D.new()
	capsule_query.shape = capsule
	capsule_query.collision_mask = CollisionLayers.LAYER_WORLD
	capsule_query.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 1, 0))

	var capsule_result: Array[Dictionary] = space.intersect_shape(capsule_query, 1)
	if not capsule_result.is_empty():
		return false

	return true


func _start_stuck_detection() -> void:
	# Defer stuck check to avoid immediate false-positives
	_world.get_tree().create_timer(2.0).timeout.connect(_check_all_enemies_stuck)


func _check_all_enemies_stuck() -> void:
	var enemies: Array[Node] = _world.get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue

		# Check if enemy has spawn coordinator component
		var spawn_coord: Node = enemy.get_node_or_null("SpawnCoordinator")
		if spawn_coord and spawn_coord.has_method("check_if_stuck"):
			spawn_coord.check_if_stuck()
