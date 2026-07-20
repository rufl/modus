class_name PlayerCommands
extends RefCounted

# MODUS Framework Player Commands
# Provides player-related console commands


static func register_commands(registry: ConsoleCommandRegistry) -> void:
	registry.register_command("teleport", _teleport, "Teleport player to coordinates")
	registry.register_command("set_speed", _set_speed, "Set player movement speed")
	registry.register_command("respawn", _respawn_player, "Respawn player")
	registry.register_command("player_info", _player_info, "Show player information")


static func _get_local_player() -> CharacterBody3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	var players: Array[Node] = tree.get_nodes_in_group("player")
	for p: Node in players:
		if p is CharacterBody3D and p.is_multiplayer_authority():
			return p as CharacterBody3D
	return null


static func _teleport(args: PackedStringArray) -> String:
	if args.size() < 3:
		return "Usage: teleport <x> <y> <z>"

	var x: float = args[0].to_float()
	var y: float = args[1].to_float()
	var z: float = args[2].to_float()

	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	player.global_position = Vector3(x, y, z)
	return "Teleported player to (%.1f, %.1f, %.1f)" % [x, y, z]


static func _set_speed(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: set_speed <speed>"

	var speed: float = args[0].to_float()

	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	if "movement_component" in player and player.movement_component:
		player.movement_component.move_speed = speed
		return "Player speed set to: %.1f" % speed

	return "[color=red]Movement component not found[/color]"


static func _respawn_player(_args: PackedStringArray) -> String:
	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	# Use health_component.die() to trigger the respawn flow
	if "health_component" in player and player.health_component:
		if player.health_component.is_dead:
			return "[color=yellow]Player is already dead, waiting for respawn[/color]"
		player.health_component.die(-1)
		return "Player respawned (death + respawn triggered)"

	return "[color=red]Health component not found[/color]"


static func _player_info(_args: PackedStringArray) -> String:
	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	var info: String = "[color=yellow]Player Information:[/color]\n"
	info += "  Position: %s\n" % str(player.global_position)
	info += "  Velocity: %s\n" % str(player.velocity)

	if "health_component" in player and player.health_component:
		var hc: Node = player.health_component
		info += "  Health: %.0f / %.0f\n" % [hc.current_health, hc.max_health]
		info += "  Armor: %.0f\n" % hc.current_armor
		info += "  Invincible: %s\n" % str(hc.invincible)

	if "movement_component" in player and player.movement_component:
		var mc: Node = player.movement_component
		info += "  Speed: %.1f\n" % mc.move_speed
		info += "  Noclip: %s\n" % str(mc.noclip)
		info += "  Flying: %s\n" % str(mc.can_fly)

	if "weapon_manager" in player and player.weapon_manager:
		var wm: Node = player.weapon_manager
		var weapon: WeaponData = wm.get_current_weapon()
		if weapon:
			info += "  Weapon: %s\n" % weapon.weapon_name
		var ammo: Array = wm.get_current_ammo()
		info += "  Ammo: %d / %d" % [ammo[0], ammo[1]]

	return info
