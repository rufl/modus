class_name DifficultyMgr
extends Node

## DifficultyManager - Dynamic Difficulty Scaling
##
## Scales enemy stats based on connected player count (Minecraft Dungeons style).
## More players = stronger enemies but better loot.

signal difficulty_changed(player_count: int, multiplier: float)

enum DifficultyLevel { EASY, NORMAL, HARD, NIGHTMARE }

const DEFAULT_DIFFICULTY_BASE: Dictionary = {
	"easy": {"health": 0.7, "damage": 0.7, "loot_quality": 0.8, "loot_quantity": 1.2},
	"normal": {"health": 1.0, "damage": 1.0, "loot_quality": 1.0, "loot_quantity": 1.0},
	"hard": {"health": 1.5, "damage": 1.3, "loot_quality": 1.3, "loot_quantity": 1.0},
	"nightmare": {"health": 2.0, "damage": 1.8, "loot_quality": 1.6, "loot_quantity": 0.9}
}

@export var health_scale_per_player: float = 0.3
@export var damage_scale_per_player: float = 0.2
@export var loot_quality_scale: float = 0.15
@export var loot_quantity_scale: float = 0.1

var current_player_count: int = 1
var current_health_multiplier: float = 1.0
var current_damage_multiplier: float = 1.0
var current_loot_quality_multiplier: float = 1.0
var current_loot_quantity_multiplier: float = 1.0
var base_difficulty: DifficultyLevel = DifficultyLevel.NORMAL


static func get_instance() -> DifficultyMgr:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		var manager: Node = tree.root.get_node("GameManager")
		if manager and manager.has_method("get_core_system"):
			var gs: Node = manager.get_core_system("gameplay")
			return gs.difficulty if gs else null
	return null


func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	multiplayer.peer_connected.connect(_on_player_count_changed)
	multiplayer.peer_disconnected.connect(_on_player_count_changed)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var ns: Variant = gm.get_core_system("network")
		if ns and ns is NetworkSvc:
			if ns.dedicated_server and ns.dedicated_server.config.has("difficulty"):
				var diff_value: int = ns.dedicated_server.config.get("difficulty", 1)
				base_difficulty = clampi(diff_value, 0, 3) as DifficultyLevel

	_recalculate_multipliers()


func _exit_tree() -> void:
	if multiplayer:
		if multiplayer.peer_connected.is_connected(_on_player_count_changed):
			multiplayer.peer_connected.disconnect(_on_player_count_changed)
		if multiplayer.peer_disconnected.is_connected(_on_player_count_changed):
			multiplayer.peer_disconnected.disconnect(_on_player_count_changed)


func _on_player_count_changed(_peer_id: int) -> void:
	await get_tree().process_frame
	_recalculate_multipliers()


func _recalculate_multipliers() -> void:
	if multiplayer.multiplayer_peer:
		current_player_count = multiplayer.get_peers().size() + 1
	else:
		current_player_count = 1

	var diff_key: String = DifficultyLevel.keys()[base_difficulty].to_lower()

	var gm: Node = get_node_or_null("/root/GameManager")
	var difficulty_config: Dictionary = {}
	if gm:
		var cm: Variant = gm.get_core_system("config")
		if cm and cm.has_method("get_value"):
			var difficulty_result: Variant = cm.get_value("difficulty")
			if difficulty_result is Dictionary:
				difficulty_config = difficulty_result

	var base: Dictionary
	if difficulty_config.has(diff_key):
		base = difficulty_config[diff_key]
	else:
		base = DEFAULT_DIFFICULTY_BASE.get(diff_key, DEFAULT_DIFFICULTY_BASE["normal"])

	var additional_players: int = maxi(0, current_player_count - 1)

	var health_factor: float = 1.0 + additional_players * health_scale_per_player
	var damage_factor: float = 1.0 + additional_players * damage_scale_per_player
	var quality_factor: float = 1.0 + additional_players * loot_quality_scale
	var quantity_factor: float = 1.0 + additional_players * loot_quantity_scale

	current_health_multiplier = base.health * health_factor
	current_damage_multiplier = base.damage * damage_factor
	current_loot_quality_multiplier = base.loot_quality * quality_factor
	current_loot_quantity_multiplier = base.loot_quantity * quantity_factor

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_difficulty.rpc(
			current_player_count,
			current_health_multiplier,
			current_damage_multiplier,
			current_loot_quality_multiplier,
			current_loot_quantity_multiplier
		)

	difficulty_changed.emit(current_player_count, current_health_multiplier)
	var msg: String = "[DifficultyManager] Players: %d, Health: x%.2f, Damage: x%.2f"

	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(
				msg % [current_player_count, current_health_multiplier, current_damage_multiplier],
				"Core"
			)
		else:
			print(msg % [current_player_count, current_health_multiplier, current_damage_multiplier])
	else:
		print(msg % [current_player_count, current_health_multiplier, current_damage_multiplier])


func get_scaled_health(base_health: float) -> float:
	return base_health * current_health_multiplier


func get_scaled_damage(base_damage: float) -> float:
	return base_damage * current_damage_multiplier


func get_loot_quality_multiplier() -> float:
	return current_loot_quality_multiplier


func get_loot_quantity_multiplier() -> float:
	return current_loot_quantity_multiplier


func set_difficulty(level: DifficultyLevel) -> void:
	base_difficulty = level
	_recalculate_multipliers()


@rpc("authority", "call_local", "reliable")
func _sync_difficulty(
	player_count: int,
	health_mult: float,
	damage_mult: float,
	loot_quality_mult: float,
	loot_quantity_mult: float
) -> void:
	current_player_count = player_count
	current_health_multiplier = health_mult
	current_damage_multiplier = damage_mult
	current_loot_quality_multiplier = loot_quality_mult
	current_loot_quantity_multiplier = loot_quantity_mult

	difficulty_changed.emit(player_count, health_mult)
