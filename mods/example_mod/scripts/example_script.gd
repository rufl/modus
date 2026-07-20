extends ModScript

## Example Mod Script
## Demonstrates how to use the mod scripting API with hook methods


func _mod_init() -> void:
	mod_print("Example mod initialized!")


func on_game_start() -> void:
	## Called when the game/level starts
	mod_print("Game started! Example mod is active.")


func on_enemy_spawn(enemy: Node, enemy_type: String) -> void:
	## Called whenever an enemy spawns
	mod_print("Enemy spawned: %s" % enemy_type)

	# Example: Modify enemy on spawn
	if enemy and enemy.has_method("set_color"):
		# Could change enemy color, add effects, etc.
		pass


func on_enemy_died(_enemy: Node, killer: Node) -> void:
	## Called when an enemy dies
	var killer_name: String = str(killer.name) if killer else "unknown"
	mod_print("Enemy died! Killed by: %s" % killer_name)


func on_loot_drop(position: Vector3, loot_table: String, items: Array) -> void:
	## Called when loot drops
	mod_print("Loot dropped at %s from table: %s (%d items)" % [position, loot_table, items.size()])


func on_player_level_up(player: Node, new_level: int) -> void:
	## Called when the player levels up
	mod_print("Player leveled up to level %d!" % new_level)

	# Example: Give bonus on level up
	if player and player.has_method("heal"):
		player.heal(50.0)  # Heal 50 HP on level up


func on_player_damage(_player: Node, amount: float, source: Node) -> void:
	## Called when player takes damage
	var source_name: String = str(source.name) if source else "environment"
	mod_print("Player took %.1f damage from %s" % [amount, source_name])


func on_weapon_fired(_weapon: Node, _weapon_name: String) -> void:
	## Called when player fires a weapon
	# This is called very frequently, so we don't log it
	pass


func on_prop_destroyed(prop: Node, destroyer: Node) -> void:
	## Called when a prop is destroyed
	var destroyer_name: String = str(destroyer.name) if destroyer else "unknown"
	mod_print("Prop %s destroyed by %s" % [prop.name, destroyer_name])
