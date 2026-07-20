class_name CheatCommands
extends RefCounted

# MODUS Framework Cheat Commands
# Provides cheat functionality for development and testing


static func register_commands(registry: ConsoleCommandRegistry) -> void:
	registry.register_command("god", _god_mode, "Toggle god mode")
	registry.register_command("noclip", _noclip, "Toggle noclip mode")
	registry.register_command("give_weapon", _give_weapon, "Give weapon to player")
	registry.register_command("give_ammo", _give_ammo, "Give ammo to player")
	registry.register_command("heal", _heal_player, "Heal player to full health")


static func _get_local_player() -> CharacterBody3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	var players: Array[Node] = tree.get_nodes_in_group("player")
	for p: Node in players:
		if p is CharacterBody3D and p.is_multiplayer_authority():
			return p as CharacterBody3D
	return null


static func _god_mode(_args: PackedStringArray) -> String:
	var match_svc: MatchSvc = MatchSvc.get_instance()
	if match_svc:
		match_svc.toggle_godmode()
		if match_svc.godmode:
			return "God mode [color=green]enabled[/color] — you are invincible"
		return "God mode [color=red]disabled[/color]"
	return "[color=red]Match service not available[/color]"


static func _noclip(_args: PackedStringArray) -> String:
	var match_svc: MatchSvc = MatchSvc.get_instance()
	if match_svc:
		match_svc.toggle_noclip()
		if match_svc.noclip:
			return "Noclip [color=green]enabled[/color] — fly through walls"
		return "Noclip [color=red]disabled[/color]"
	return "[color=red]Match service not available[/color]"


static func _give_weapon(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: give_weapon <weapon_name_or_index>"

	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	if not "weapon_manager" in player or not player.weapon_manager:
		return "[color=red]Weapon manager not found[/color]"

	var wm: WeaponManager = player.weapon_manager
	if not wm.inventory:
		return "[color=red]Weapon inventory not found[/color]"

	var query: String = args[0].to_lower()

	# Try matching by index first
	if query.is_valid_int():
		var idx: int = query.to_int()
		if idx >= 0 and idx < wm.inventory.weapons.size():
			wm.switch_to_weapon(idx)
			var w: WeaponData = wm.inventory.weapons[idx]
			return "Switched to weapon %d: [color=green]%s[/color]" % [idx, w.weapon_name]
		return (
			"[color=red]Invalid weapon index %d (0-%d)[/color]"
			% [idx, wm.inventory.weapons.size() - 1]
		)

	# Try matching by name
	for i in range(wm.inventory.weapons.size()):
		var w: WeaponData = wm.inventory.weapons[i]
		if w.weapon_name.to_lower().contains(query):
			wm.switch_to_weapon(i)
			return "Switched to: [color=green]%s[/color]" % w.weapon_name

	# List available weapons
	var available: String = ""
	for i in range(wm.inventory.weapons.size()):
		var w: WeaponData = wm.inventory.weapons[i]
		available += "\n  [color=green]%d[/color]: %s" % [i, w.weapon_name]
	return "[color=red]Weapon '%s' not found.[/color] Available:%s" % [args[0], available]


static func _give_ammo(args: PackedStringArray) -> String:
	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	if not "weapon_manager" in player or not player.weapon_manager:
		return "[color=red]Weapon manager not found[/color]"

	var wm: WeaponManager = player.weapon_manager

	# If no args, refill all ammo
	if args.is_empty():
		wm.refill_ammo()
		return "All ammo refilled to maximum"

	# If args, try specific amount for current weapon
	if wm.ammo_system and wm.ammo_system.has_method("refill_all_ammo"):
		wm.ammo_system.refill_all_ammo()
		return "All ammo refilled to maximum"

	return "[color=red]Ammo system not available[/color]"


static func _heal_player(_args: PackedStringArray) -> String:
	var player: CharacterBody3D = _get_local_player()
	if not player:
		return "[color=red]No local player found[/color]"

	if "health_component" in player and player.health_component:
		var hc: Node = player.health_component
		var missing: float = hc.max_health - hc.current_health
		if missing <= 0:
			return "[color=yellow]Player already at full health (%.0f)[/color]" % hc.max_health
		hc.heal(missing)
		return "Healed player to full health (%.0f / %.0f)" % [hc.current_health, hc.max_health]

	return "[color=red]Health component not found[/color]"
