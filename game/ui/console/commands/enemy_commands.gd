class_name EnemyCommands
extends RefCounted

# MODUS Framework Enemy Commands
# Provides enemy-related console commands for testing


static func register_commands(registry: ConsoleCommandRegistry) -> void:
	registry.register_command("spawn_enemy", _spawn_enemy, "Spawn enemy at player location")
	registry.register_command("kill_all_enemies", _kill_all_enemies, "Kill all enemies")
	registry.register_command("enemy_count", _enemy_count, "Show enemy count")
	registry.register_command("set_enemy_ai", _set_enemy_ai, "Enable/disable enemy AI")


static func _get_local_player() -> CharacterBody3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	var players: Array[Node] = tree.get_nodes_in_group("player")
	for p: Node in players:
		if p is CharacterBody3D and p.is_multiplayer_authority():
			return p as CharacterBody3D
	return null


static func _spawn_enemy(args: PackedStringArray) -> String:
	var enemy_type: String = "grunt"
	if not args.is_empty():
		enemy_type = args[0]

	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	# Try using EnemySpawnCoordinator via gameplay service
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and "enemy_spawn_coordinator" in gs and gs.enemy_spawn_coordinator:
		var coord: Node = gs.enemy_spawn_coordinator
		var spawn_pos: Vector3 = player.global_position + player.global_transform.basis.z * -3.0
		spawn_pos.y = player.global_position.y
		if coord.has_method("spawn_enemy_at"):
			coord.spawn_enemy_at(spawn_pos, enemy_type)
			return "Spawned '%s' at %s" % [enemy_type, str(spawn_pos)]
		if coord.has_method("spawn_enemy"):
			coord.spawn_enemy(enemy_type, spawn_pos)
			return "Spawned '%s' at %s" % [enemy_type, str(spawn_pos)]

	return "[color=red]Enemy spawn coordinator not available[/color]"


static func _kill_all_enemies(_args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "[color=red]No scene tree[/color]"

	var enemies: Array[Node] = tree.get_nodes_in_group("enemy")
	if enemies.is_empty():
		return "[color=yellow]No enemies to kill[/color]"

	var count: int = 0
	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue
		if "health_component" in enemy and enemy.health_component:
			enemy.health_component.die(-1)
		elif enemy.has_method("die"):
			enemy.die()
		else:
			enemy.queue_free()
		count += 1

	return "Killed %d enemies" % count


static func _enemy_count(_args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "[color=red]No scene tree[/color]"

	var enemies: Array[Node] = tree.get_nodes_in_group("enemy")
	var alive: int = 0
	for enemy: Node in enemies:
		if is_instance_valid(enemy):
			if "is_dead" in enemy and enemy.is_dead:
				continue
			alive += 1

	return "Enemy count: %d (total in group: %d)" % [alive, enemies.size()]


static func _set_enemy_ai(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: set_enemy_ai <true/false> or <1/0>"

	var val: String = args[0].to_lower()
	var enabled: bool = val == "true" or val == "1"

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "[color=red]No scene tree[/color]"

	var enemies: Array[Node] = tree.get_nodes_in_group("enemy")
	var count: int = 0
	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue
		# Try common AI toggle patterns
		if "ai_enabled" in enemy:
			enemy.ai_enabled = enabled
			count += 1
		elif enemy.has_method("set_ai_enabled"):
			enemy.set_ai_enabled(enabled)
			count += 1
		else:
			# Toggle processing as fallback
			enemy.set_physics_process(enabled)
			enemy.set_process(enabled)
			count += 1

	return "Enemy AI %s for %d enemies" % ["enabled" if enabled else "disabled", count]
