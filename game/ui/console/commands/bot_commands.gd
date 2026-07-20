extends "res://game/ui/console/command_module.gd"

const BOT_TYPES: Array[String] = [
	"bot_grunt",
	"bot_sniper",
	"bot_tank",
	"bot_assassin",
	"bot_support",
]


func register_commands(registry: Object) -> void:
	super.register_commands(registry)

	register("spawn_bot", _cmd_spawn_bot, "Spawn arena bot(s)", "spawn_bot <type> [count]")
	register("kill_bot", _cmd_kill_bot, "Kill specific bot by name", "kill_bot <name>")
	register("kill_all_bots", _cmd_kill_all_bots, "Kill all arena bots")
	register("list_bots", _cmd_list_bots, "List all active bots")
	register("bot_info", _cmd_bot_info, "Show bot type info", "bot_info <type>")


func _cmd_spawn_bot(args: Array) -> String:
	if args.is_empty():
		return _show_bot_types()

	var bot_type: String = args[0].to_lower()
	if not bot_type.begins_with("bot_"):
		bot_type = "bot_" + bot_type

	if bot_type not in BOT_TYPES:
		return "[color=red]Unknown bot type: %s[/color]\n%s" % [args[0], _show_bot_types()]

	var count: int = 1
	if args.size() > 1:
		count = int(args[1])
		count = clampi(count, 1, 10)  # Max 10 bots at once

	var player: Node = get_player()
	if not player:
		return "[color=red]No local player found[/color]"

	var spawn_manager: Node = _get_spawn_manager()
	if not spawn_manager:
		return "[color=red]EnemySpawnManager not available[/color]"

	var spawned: int = 0
	for i: int in range(count):
		# Spawn in a circle around player
		var angle: float = (TAU / float(count)) * i
		var offset: Vector3 = Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0)
		var spawn_pos: Vector3 = player.global_position + offset

		var bot: Node = spawn_manager.spawn_enemy_at(spawn_pos, bot_type)
		if bot:
			spawned += 1

	if spawned == 0:
		return "[color=red]Failed to spawn bots (check enemy cap)[/color]"

	var bot_name: String = bot_type.replace("bot_", "").capitalize()
	return "[color=green]Spawned %d x %s[/color]" % [spawned, bot_name]


func _cmd_kill_bot(args: Array) -> String:
	if args.is_empty():
		return "[color=yellow]Usage: kill_bot <name>[/color]"

	var search: String = args[0]
	var tracker: Node = _get_enemy_tracker()
	if not tracker:
		return "[color=red]EnemyTracker not available[/color]"

	var info: Dictionary = tracker.get_enemy_by_name(search)
	if info.is_empty():
		return "[color=red]No bot found matching: %s[/color]" % search

	var enemy: Node = info.get("node", null)
	if not enemy or not is_instance_valid(enemy):
		return "[color=red]Bot reference invalid[/color]"

	# Kill the bot
	if enemy.has_node("HealthComponent"):
		var health: Node = enemy.get_node("HealthComponent")
		health.die(0)  # 0 = console kill
	else:
		enemy.queue_free()

	return "[color=green]Killed bot: %s[/color]" % info.get("name", "?")


func _cmd_kill_all_bots(_args: Array) -> String:
	var bots: Array[Node] = []
	var tree: SceneTree = Engine.get_main_loop()
	var all_enemies: Array[Node] = tree.get_nodes_in_group("enemies")

	# Filter for bots only (check enemy_id)
	for enemy: Node in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if "enemy_id" in enemy:
			var eid: String = enemy.enemy_id
			if eid.begins_with("bot_"):
				bots.append(enemy)

	if bots.is_empty():
		return "[color=yellow]No bots found[/color]"

	var killed: int = 0
	for bot: Node in bots:
		if bot.has_node("HealthComponent"):
			var health: Node = bot.get_node("HealthComponent")
			health.die(0)
		else:
			bot.queue_free()
		killed += 1

	return "[color=green]Killed %d bots[/color]" % killed


func _cmd_list_bots(_args: Array) -> String:
	var bots: Array[Dictionary] = []
	var tracker: Node = _get_enemy_tracker()

	if tracker:
		var all_enemies: Array[Dictionary] = tracker.get_all_enemy_info()
		for info: Dictionary in all_enemies:
			var node: Node = info.get("node", null)
			if node and is_instance_valid(node) and "enemy_id" in node:
				if node.enemy_id.begins_with("bot_"):
					bots.append(info)
	else:
		# Fallback: manual search
		var tree: SceneTree = Engine.get_main_loop()
		var all_enemies: Array[Node] = tree.get_nodes_in_group("enemies")
		for enemy: Node in all_enemies:
			if not is_instance_valid(enemy):
				continue
			if "enemy_id" in enemy and enemy.enemy_id.begins_with("bot_"):
				var max_hp_val: float = enemy.max_health if "max_health" in enemy else 100.0
				var pos_val: Vector3 = Vector3.ZERO
				if "global_position" in enemy:
					pos_val = enemy.global_position
				var info: Dictionary = {
					"name": enemy.name,
					"health": enemy.health if "health" in enemy else 0.0,
					"max_health": max_hp_val,
					"position": pos_val,
					"is_dead": enemy.is_dead if "is_dead" in enemy else false
				}
				bots.append(info)

	if bots.is_empty():
		return "[color=yellow]No bots active[/color]"

	var output: String = "[color=yellow]═══ ARENA BOTS (%d) ═══[/color]\n" % bots.size()

	for info: Dictionary in bots:
		var name: String = info.get("name", "?")
		var hp: float = info.get("health", 0.0)
		var max_hp: float = info.get("max_health", 100.0)
		var pos: Vector3 = info.get("position", Vector3.ZERO)
		var is_dead: bool = info.get("is_dead", false)

		if is_dead:
			output += "  [color=gray]✗ %s (DEAD)[/color]\n" % name
		else:
			output += (
				"  %s: HP:%.0f/%.0f @ (%.1f, %.1f, %.1f)\n"
				% [name, hp, max_hp, pos.x, pos.y, pos.z]
			)

	return output


func _cmd_bot_info(args: Array) -> String:
	if args.is_empty():
		return _show_bot_types()

	var bot_type: String = args[0].to_lower()
	if not bot_type.begins_with("bot_"):
		bot_type = "bot_" + bot_type

	if bot_type not in BOT_TYPES:
		return "[color=red]Unknown bot type: %s[/color]\n%s" % [args[0], _show_bot_types()]

	var data_service = GameManager.get_core_system("data")
	var data: Dictionary = data_service.get_enemy_data(bot_type) if data_service else {}
	if data.is_empty():
		return "[color=red]Bot data not found for: %s[/color]" % bot_type

	var stats: Dictionary = data.get("stats", {})
	var ai_config: Dictionary = data.get("ai_config", {})
	var movement: Dictionary = data.get("movement", {})

	var output: String = "[color=yellow]═══ %s ═══[/color]\n" % data.get("name", "?")
	output += "  Tier: %d\n" % data.get("tier", 1)
	output += "  Health: %d\n" % stats.get("health", 0)
	output += "  Damage: %d\n" % stats.get("damage", 0)
	output += "  Speed: %.1f\n" % stats.get("speed", 0.0)
	output += "  Attack Range: %.1f\n" % stats.get("attack_range", 0.0)
	output += "  Aggression: %.0f%%\n" % (stats.get("aggression", 0.0) * 100)
	output += "  Accuracy: %.0f%%\n" % (ai_config.get("accuracy", 1.0) * 100)
	output += "  Reaction Time: %.2fs\n" % ai_config.get("reaction_time", 0.0)
	output += "  Combat Style: %s\n" % ai_config.get("combat_style", "balanced")
	output += "  Can Dash: %s\n" % ("Yes" if movement.get("can_dash", false) else "No")
	output += "  Uses Cover: %s\n" % ("Yes" if ai_config.get("uses_cover", false) else "No")

	return output


func _show_bot_types() -> String:
	var output: String = "[color=yellow]Available Bot Types:[/color]\n"
	var data_service = GameManager.get_core_system("data")
	for bot_type: String in BOT_TYPES:
		var short_name: String = bot_type.replace("bot_", "")
		var data: Dictionary = data_service.get_enemy_data(bot_type) if data_service else {}
		var name: String = data.get("name", short_name.capitalize())
		output += "  [color=green]%s[/color] - %s\n" % [short_name, name]
	return output


func _get_spawn_manager() -> Node:
	var world: Node = Engine.get_main_loop().root.get_node_or_null("World")
	if world:
		return world.get_node_or_null("EnemySpawnManager")
	return null


func _get_enemy_tracker() -> Node:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	return gs.enemy_tracker if gs else null
