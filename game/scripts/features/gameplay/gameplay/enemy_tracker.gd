class_name EnemyTrkr
extends Node

signal enemy_visibility_changed(enemy: Node, visible: bool, reason: String)
signal enemy_position_anomaly(enemy: Node, old_pos: Vector3, new_pos: Vector3, reason: String)
signal enemy_state_changed(enemy: Node, old_state: String, new_state: String)

const TELEPORT_THRESHOLD: float = 10.0  # Units moved in single frame = teleport
const POSITION_SANITY_MIN: float = -5000.0
const POSITION_SANITY_MAX: float = 5000.0
const MAX_ANOMALY_LOG: int = 100

var _tracked_enemies: Dictionary = {}  # instance_id -> TrackedEnemy data
var _watch_mode: bool = false  # Live logging toggle
var _anomaly_log: Array[Dictionary] = []  # Recent anomalies for review


static func get_instance() -> EnemyTrkr:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	var manager: Node = tree.root.get_node_or_null("GameManager")
	if not manager or not manager.has_method("get_core_system"):
		return null
	var gs := manager.get_core_system("gameplay") as GameplaySvc
	return gs.enemy_tracker as EnemyTrkr if gs else null


func _ready() -> void:
	# Connect to GameManager.get_core_system("entity") signals
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.entity_registry:
		gs.entity_registry.enemy_registered.connect(_on_enemy_registered)
		gs.entity_registry.enemy_unregistered.connect(_on_enemy_unregistered)

		# Register existing enemies
		for enemy: Node in gs.entity_registry.get_all_enemies():
			_on_enemy_registered(enemy)

	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[EnemyTracker] Auto-logging active - anomalies logged to session file", "EnemyTracker"
		)
	else:
		print("[EnemyTracker] Auto-logging active - anomalies logged to session file")


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.entity_registry:
		if gs.entity_registry.enemy_registered.is_connected(_on_enemy_registered):
			gs.entity_registry.enemy_registered.disconnect(_on_enemy_registered)
		if gs.entity_registry.enemy_unregistered.is_connected(_on_enemy_unregistered):
			gs.entity_registry.enemy_unregistered.disconnect(_on_enemy_unregistered)


func _physics_process(_delta: float) -> void:
	if not OS.is_debug_build():
		return

	_update_all_tracked_enemies()


func _update_all_tracked_enemies() -> void:
	for id: int in _tracked_enemies.keys():
		var data: Dictionary = _tracked_enemies[id]
		var enemy: Node = data.get("node")

		if not is_instance_valid(enemy):
			continue

		# Track position changes
		var old_pos: Vector3 = data.get("last_position", Vector3.ZERO)
		var new_pos: Vector3 = enemy.global_position

		if old_pos != Vector3.ZERO:
			var distance: float = old_pos.distance_to(new_pos)
			if distance > TELEPORT_THRESHOLD:
				_log_anomaly(
					enemy,
					"TELEPORT",
					{"old_pos": old_pos, "new_pos": new_pos, "distance": distance}
				)
				enemy_position_anomaly.emit(enemy, old_pos, new_pos, "teleport")

		# Check position sanity
		if _is_position_invalid(new_pos):
			_log_anomaly(enemy, "INVALID_POSITION", {"position": new_pos})
			enemy_position_anomaly.emit(enemy, old_pos, new_pos, "invalid")

		# Track visibility changes
		var old_visible: bool = data.get("last_visible", true)
		var new_visible: bool = enemy.visible

		if old_visible != new_visible:
			var reason: String = _determine_visibility_reason(enemy, new_visible)
			_log_anomaly(
				enemy,
				"VISIBILITY_CHANGE",
				{"old": old_visible, "new": new_visible, "reason": reason}
			)
			enemy_visibility_changed.emit(enemy, new_visible, reason)

		# Track AI state changes
		if "ai_controller" in enemy and enemy.ai_controller:
			var ctrl: Node = enemy.ai_controller
			if "current_state" in ctrl and ctrl.current_state:
				var new_state: String = ctrl.current_state.name
				var old_state: String = data.get("last_ai_state", "")
				if old_state != "" and old_state != new_state:
					enemy_state_changed.emit(enemy, old_state, new_state)
				data["last_ai_state"] = new_state

		# Update tracking data
		data["last_position"] = new_pos
		data["last_visible"] = new_visible
		data["last_update"] = Time.get_unix_time_from_system()


func _is_position_invalid(pos: Vector3) -> bool:
	if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
		return true
	if is_inf(pos.x) or is_inf(pos.y) or is_inf(pos.z):
		return true
	if pos.x < POSITION_SANITY_MIN or pos.x > POSITION_SANITY_MAX:
		return true
	if pos.y < POSITION_SANITY_MIN or pos.y > POSITION_SANITY_MAX:
		return true
	if pos.z < POSITION_SANITY_MIN or pos.z > POSITION_SANITY_MAX:
		return true
	return false


func _determine_visibility_reason(enemy: Node, visible: bool) -> String:
	if not visible:
		if "is_dead" in enemy and enemy.is_dead:
			return "death"
		if "health" in enemy and enemy.health <= 0:
			return "health_zero"

		# Check for LOD culling
		var lod_manager: Node = get_tree().get_first_node_in_group("lod_manager")
		if lod_manager and lod_manager.has_method("is_culled_by_lod"):
			if lod_manager.is_culled_by_lod(enemy):
				return "lod_cull"

		return "unknown_hide"
	return "shown"


func _log_anomaly(enemy: Node, anomaly_type: String, details: Dictionary) -> void:
	# Filter out valid LOD culling from anomaly log
	if anomaly_type == "VISIBILITY_CHANGE":
		var reason: String = details.get("reason", "unknown")
		if reason == "lod_cull" or reason == "death":
			# These are expected behavior, not anomalies
			return

	var enemy_name: String = "INVALID"
	if is_instance_valid(enemy):
		enemy_name = enemy.name
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"enemy_name": enemy_name,
		"type": anomaly_type,
		"details": details
	}

	_anomaly_log.append(entry)
	if _anomaly_log.size() > MAX_ANOMALY_LOG:
		_anomaly_log.pop_front()

	# ALWAYS log anomalies to session log file (for post-session analysis)
	var log_msg: String = "[EnemyTracker] ANOMALY %s: %s" % [anomaly_type, enemy_name]
	match anomaly_type:
		"VISIBILITY_CHANGE":
			var reason: String = details.get("reason", "unknown")
			log_msg += (
				" | %s->%s (%s)"
				% [
					"visible" if details.get("old", true) else "hidden",
					"visible" if details.get("new", true) else "hidden",
					reason
				]
			)
			GameManager.get_core_system("logger").warning(log_msg, "EnemyTracker")
		"TELEPORT":
			var dist: float = details.get("distance", 0.0)
			log_msg += " | teleported %.1fm" % dist
			GameManager.get_core_system("logger").warning(log_msg, "EnemyTracker")
		"INVALID_POSITION":
			var pos: Vector3 = details.get("position", Vector3.ZERO)
			log_msg += " | invalid pos: %s" % pos
			GameManager.get_core_system("logger").error(log_msg, "EnemyTracker")
		_:
			GameManager.get_core_system("logger").warning(
				log_msg + " | " + str(details), "EnemyTracker"
			)

	# Watch mode: also print to immediate console for live debugging
	if _watch_mode:
		GameManager.get_core_system("logger").info(str(log_msg), "Core")


func _on_enemy_registered(enemy: Node) -> void:
	var id: int = enemy.get_instance_id()
	_tracked_enemies[id] = {
		"node": enemy,
		"last_position": enemy.global_position,
		"last_visible": enemy.visible,
		"last_ai_state": "",
		"last_update": Time.get_unix_time_from_system(),
		"spawn_time": Time.get_unix_time_from_system()
	}

	if _watch_mode:
		GameManager.get_core_system("logger").info(
			"[EnemyTracker] Registered: %s at %s" % [enemy.name, enemy.global_position], "Debug"
		)


func _on_enemy_unregistered(enemy: Node) -> void:
	var id: int = enemy.get_instance_id()
	if id in _tracked_enemies:
		if _watch_mode:
			GameManager.get_core_system("logger").info(
				"[EnemyTracker] Unregistered: %s" % enemy.name, "Debug"
			)
		_tracked_enemies.erase(id)


# =============================================================================
# PUBLIC API FOR CONSOLE COMMANDS
# =============================================================================


func set_watch_mode(enabled: bool) -> void:
	_watch_mode = enabled
	var status: String = "ENABLED" if enabled else "DISABLED"
	GameManager.get_core_system("logger").info("[EnemyTracker] Watch mode: %s" % status, "Debug")


func is_watch_mode() -> bool:
	return _watch_mode


func get_all_enemy_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for id: int in _tracked_enemies.keys():
		var data: Dictionary = _tracked_enemies[id]
		var enemy: Node = data.get("node")

		if not is_instance_valid(enemy):
			continue

		var info: Dictionary = {
			"name": enemy.name,
			"position": enemy.global_position,
			"visible": enemy.visible,
			"health": enemy.health if "health" in enemy else 0.0,
			"max_health": enemy.max_health if "max_health" in enemy else 0.0,
			"is_dead": enemy.is_dead if "is_dead" in enemy else false,
			"ai_state": data.get("last_ai_state", "Unknown"),
			"in_registry":
			(
				(
					(
						(GameManager.get_core_system("gameplay") as GameplaySvc)
						. entity_registry
						. get_enemy(id)
					)
					!= null
				)
				if (GameManager.get_core_system("gameplay") as GameplaySvc)
				else false
			)
		}
		result.append(info)

	return result


func get_enemy_by_name(enemy_name: String) -> Dictionary:
	for id: int in _tracked_enemies.keys():
		var data: Dictionary = _tracked_enemies[id]
		var enemy: Node = data.get("node")

		if is_instance_valid(enemy) and enemy.name.to_lower().contains(enemy_name.to_lower()):
			return {
				"node": enemy,
				"name": enemy.name,
				"position": enemy.global_position,
				"visible": enemy.visible,
				"health": enemy.health if "health" in enemy else 0.0,
				"max_health": enemy.max_health if "max_health" in enemy else 0.0,
				"is_dead": enemy.is_dead if "is_dead" in enemy else false,
				"ai_state": data.get("last_ai_state", "Unknown"),
				"spawn_time": data.get("spawn_time", 0.0),
				"last_update": data.get("last_update", 0.0),
				"in_registry": true
			}

	return {}


func get_anomaly_log() -> Array[Dictionary]:
	return _anomaly_log.duplicate()


func clear_anomaly_log() -> void:
	_anomaly_log.clear()


func get_stats() -> Dictionary:
	var total: int = _tracked_enemies.size()
	var visible_count: int = 0
	var dead_count: int = 0
	var invalid_count: int = 0

	for id: int in _tracked_enemies.keys():
		var data: Dictionary = _tracked_enemies[id]
		var enemy: Node = data.get("node")

		if not is_instance_valid(enemy):
			invalid_count += 1
			continue

		if enemy.visible:
			visible_count += 1
		if "is_dead" in enemy and enemy.is_dead:
			dead_count += 1

	return {
		"total_tracked": total,
		"visible": visible_count,
		"hidden": total - visible_count - invalid_count,
		"dead": dead_count,
		"invalid_refs": invalid_count,
		"anomalies_logged": _anomaly_log.size(),
		"watch_mode": _watch_mode
	}
