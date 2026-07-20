class_name EnemySummonerState
extends EnemyState

# Use dynamic loading to avoid circular dependency with enemy.tscn
const ENEMY_SCENE_PATH: String = "res://game/entities/enemies/enemy.tscn"

@export var summon_cooldown: float = 8.0
@export var minion_type: String = "swarmling"  # enemy_id to spawn
@export var max_minions: int = 3
@export var flee_dist: float = 8.0

var _timer: float = 2.0  # Initial delay
var _active_minions: Array[Node] = []


func update(delta: float) -> void:
	_timer -= delta

	# Flee logic
	if controller.target and is_instance_valid(controller.target):
		var my_pos: Vector3 = controller.parent_body.global_position
		var target_pos: Vector3 = controller.target.global_position
		var dist: float = my_pos.distance_to(target_pos)
		if dist < flee_dist:
			_flee_from_target()
		else:
			# Stop moving if safe
			if controller.movement:
				controller.movement.stop()

	if _timer <= 0.0:
		_try_summon()


func _flee_from_target() -> void:
	if not controller.movement:
		return

	var dir: Vector3 = (
		(controller.parent_body.global_position - controller.target.global_position).normalized()
	)
	var flee_pos: Vector3 = controller.parent_body.global_position + dir * 5.0
	controller.movement.set_target_position(flee_pos)


func _try_summon() -> void:
	# Clean up dead or invalid minions
	_active_minions = _active_minions.filter(
		func(m: Node) -> bool:
			if not is_instance_valid(m):
				return false
			# Check if minion is dead or queued for deletion
			if "is_dead" in m and m.is_dead:
				return false
			if m.is_queued_for_deletion():
				return false
			return true
	)

	if _active_minions.size() >= max_minions:
		_timer = 2.0  # Wait a bit and check again
		return

	_perform_summon()


func _perform_summon() -> void:
	# Check global enemy cap before summoning
	var current_enemies: int = get_tree().get_nodes_in_group("enemies").size()
	var gm_cap: Node = get_node_or_null("/root/GameManager")
	var config_cap: Node = gm_cap.get_core_system("config") if gm_cap else null
	var max_global: int = config_cap.get_value("enemies.max_count", 30) if config_cap else 30
	if current_enemies >= max_global:
		_timer = 3.0  # Wait and try again
		return

	# Spawn near summoner
	var offset: Vector3 = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	var spawn_pos: Vector3 = controller.parent_body.global_position + offset

	# Try to use World's spawn system for proper network sync
	var world: Node = get_tree().current_scene
	var gm: Node = get_node_or_null("/root/GameManager")
	if world and world.has_method("spawn_enemy_at"):
		var minion: Node = world.spawn_enemy_at(spawn_pos, minion_type)
		if minion:
			_active_minions.append(minion)
			if gm:
				var logger: Node = gm.get_core_system("logger")
				if logger:
					logger.info(
						"[Summoner] Spawned %s via World at %s" % [minion_type, spawn_pos], "Enemy"
					)
	else:
		# Fallback: direct spawn (might not sync in multiplayer)
		var enemy_scene: PackedScene = load(ENEMY_SCENE_PATH)
		var minion: Node = enemy_scene.instantiate()
		minion.name = "Minion_" + str(Time.get_ticks_msec())
		if "enemy_id" in minion:
			minion.enemy_id = minion_type

		world.add_child(minion)
		minion.global_position = spawn_pos

		_active_minions.append(minion)

		# Track spawn in match_stats
		if "match_stats" in world:
			world.match_stats.enemies_spawned += 1

		if gm:
			var logger2: Node = gm.get_core_system("logger")
			if logger2:
				logger2.info(
					"[Summoner] Spawned %s (fallback) at %s" % [minion_type, spawn_pos], "Enemy"
				)

	_timer = summon_cooldown
