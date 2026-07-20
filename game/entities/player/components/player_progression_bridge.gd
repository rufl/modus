extends Node

## Handles XP awards and kill event tracking.
## Subscribes to EventBus "enemy_died" and awards XP
## to the PlayerProgression system.

const BASE_KILL_XP: int = 10
const CRIT_BONUS_XP: int = 5

var _progression: PlayerProgression = null


func setup(progression: PlayerProgression) -> void:
	_progression = progression


func _enter_tree() -> void:
	# Subscribe to events if we're the local player
	# In single-player (no peer), always subscribe
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if is_local:
		GameManager.subscribe("enemy_died", _on_enemy_killed_event)


func _exit_tree() -> void:
	GameManager.unsubscribe("enemy_died", _on_enemy_killed_event)


func _on_enemy_killed_event(data: Dictionary) -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if not is_local:
		return

	var killer_id: int = data.get("killer_id", -1)
	var my_id: int = multiplayer.get_unique_id()

	if killer_id == my_id:
		_handle_enemy_killed(data)


func _handle_enemy_killed(data: Dictionary) -> void:
	var enemy_id: String = data.get("enemy_id", "unknown")
	var is_crit: bool = data.get("is_crit", false)

	var xp_amount: int = BASE_KILL_XP
	if is_crit:
		xp_amount += CRIT_BONUS_XP

	if _progression:
		_progression.add_xp(xp_amount)

	GameManager.get_core_system("logger").info(
		"[Player] Killed %s! Awarded %d XP" % [enemy_id, xp_amount], "Player"
	)
