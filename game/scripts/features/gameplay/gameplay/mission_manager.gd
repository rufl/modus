class_name MissionMgr
extends Node

signal mission_started(mission_id: String)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)
signal objective_updated(mission_id: String, objective_id: String, current: int, required: int)

const MISSIONS_PATH := "res://game/data/missions"
const DEFAULT_MISSION_ID := "mission_kill_all"

var active_mission_id: String = ""
var active_mission_data: Dictionary = {}
var objective_state: Dictionary = {}  # obj_id -> current_count
var objective_totals: Dictionary = {}  # obj_id -> initial/total_count
var available_missions: Dictionary = {}  # id -> data


static func get_instance() -> MissionMgr:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	var manager: Node = tree.root.get_node_or_null("GameManager")
	if not manager or not manager.has_method("get_core_system"):
		return null
	var gs := manager.get_core_system("gameplay") as GameplaySvc
	return gs.mission as MissionMgr if gs else null


## MissionManager
## Handles moddable missions, quests, and game loop objectives.
## Works as the "Loop Director" by checking win/loss conditions.

# Service preloads to resolve lints

# Data paths

# State

# Cache


func _ready() -> void:
	_load_all_missions()

	# Wait for parent GameplaySvc to finish initializing all services
	var gs := get_parent() as GameplaySvc
	if gs:
		if gs.has_signal("services_ready"):
			gs.services_ready.connect(_connect_signals, CONNECT_ONE_SHOT)
		else:
			# Fallback if signal doesn't exist
			call_deferred("_connect_signals")
	else:
		call_deferred("_connect_signals")


func _connect_signals() -> void:
	# Listen for match events
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.match_started.connect(_on_match_started)

		# Check if match already started before we connected
		if gs.match_service.current_match_state == gs.match_service.MatchState.PLAYING:
			var logger: Variant = GameManager.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info(
					"[MissionManager] Match already in progress, starting default mission", "Core"
				)
			# Start default mission
			if available_missions.has(DEFAULT_MISSION_ID):
				start_mission(DEFAULT_MISSION_ID)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service and gs.match_service.match_started.is_connected(_on_match_started):
		gs.match_service.match_started.disconnect(_on_match_started)


func handle_match_started(settings: Dictionary) -> void:
	var logger: Variant = GameManager.get_core_system("logger")

	# Check if settings specify a mission, otherwise load default/random?
	var mission_id: String = settings.get("mission_id", "")

	# MVP: If no mission specified, try to find a default "kill_all" or similar
	if mission_id == "" and available_missions.has(DEFAULT_MISSION_ID):
		mission_id = DEFAULT_MISSION_ID
		if logger and logger.has_method("info"):
			logger.info(
				"[MissionManager] No mission specified, using default: %s" % mission_id, "Core"
			)

	if mission_id != "" and available_missions.has(mission_id):
		start_mission(mission_id)
	else:
		if logger and logger.has_method("warn"):
			logger.warn(
				(
					"[MissionManager] No valid mission to start. Available: %s"
					% str(available_missions.keys())
				),
				"Core"
			)
		else:
			push_warning(
				(
					"[MissionManager] No valid mission to start. Available: %s"
					% str(available_missions.keys())
				)
			)


func _on_match_started(settings: Dictionary) -> void:
	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[MissionManager] Match started signal received with settings: %s" % str(settings),
			"Core"
		)
	else:
		print("[MissionManager] Match started signal received with settings: %s" % str(settings))
	handle_match_started(settings)


func _load_all_missions() -> void:
	available_missions.clear()

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(MISSIONS_PATH):
		DirAccess.make_dir_recursive_absolute(MISSIONS_PATH)

	var dir := DirAccess.open(MISSIONS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				_load_mission_file(MISSIONS_PATH.path_join(file_name))
			file_name = dir.get_next()

	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[MissionManager] Loaded %d missions" % available_missions.size(), "Core")
	else:
		print("[MissionManager] Loaded %d missions" % available_missions.size())


func _load_mission_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err == OK:
		var data: Dictionary = json.data
		if "id" in data:
			available_missions[data.id] = data


func start_mission(mission_id: String) -> void:
	if not available_missions.has(mission_id):
		push_error("[MissionManager] Mission not found: " + mission_id)
		return

	active_mission_id = mission_id
	active_mission_data = available_missions[mission_id].duplicate(true)
	objective_state.clear()

	# Initialize objectives
	var objectives: Array = active_mission_data.get("objectives", [])
	for obj: Dictionary in objectives:
		var type: String = obj.get("type", "")
		if type == "eliminate_group":
			var group: String = obj.get("target_group", "enemies")
			var total := get_tree().get_nodes_in_group(group).size()
			objective_totals[obj.id] = total
			objective_state[obj.id] = 0

	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[MissionManager] Started mission: " + active_mission_data.get("name", mission_id),
			"Core"
		)
	else:
		print("[MissionManager] Started mission: " + active_mission_data.get("name", mission_id))
	mission_started.emit(mission_id)

	# Start monitoring loop
	set_process(true)


func _process(_delta: float) -> void:
	if active_mission_id == "":
		set_process(false)
		return

	# Check objectives
	var all_complete: bool = true
	var objectives: Array = active_mission_data.get("objectives", [])

	for obj: Dictionary in objectives:
		var type: String = obj.get("type", "")
		var is_complete: bool = false

		if type == "eliminate_group":
			is_complete = _check_eliminate_group(obj)

		if not is_complete:
			all_complete = false

	# Update Compass periodically
	_update_compass_markers()

	if all_complete:
		_complete_mission()


func _update_compass_markers() -> void:
	var compass_nodes: Array[Node] = get_tree().get_nodes_in_group("compass_bar")
	if compass_nodes.is_empty():
		return
	var compass: Node = compass_nodes[0]  # Assume one

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			# Check dead state
			var is_dead: Variant = enemy.get("is_dead")
			if is_dead:
				compass.remove_marker(str(enemy.get_instance_id()))
				continue

			compass.add_marker(
				str(enemy.get_instance_id()), enemy.global_position, compass.MarkerType.ENEMY
			)


func _check_eliminate_group(obj: Dictionary) -> bool:
	var group_name: String = obj.get("target_group", "enemies")
	var required: int = obj.get("required_count", -1)

	var current_nodes: Array = get_tree().get_nodes_in_group(group_name)
	var living_count: int = 0

	for node: Node in current_nodes:
		if not node.is_queued_for_deletion():
			# Check specific "dead" property if it exists
			# Use safe access to avoid errors if property missing
			if node.get("is_dead") == false:
				living_count += 1
			elif not "is_dead" in node:
				# If no dead property, assume existence = alive
				living_count += 1

	# Emit Update for UI
	var total: int = objective_totals.get(obj.id, required)
	if required != -1:
		total = required

	var killed := total - living_count
	if required == -1:
		killed = total - living_count

	objective_updated.emit(active_mission_id, obj.id, killed, total)

	# If required is -1, we need 0 living.
	if required == -1:
		return living_count == 0

	# MVP supports "Kill All" (-1)
	return living_count == 0


func _complete_mission() -> void:
	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[MissionManager] Mission Complete: " + active_mission_id, "Core")
	else:
		print("[MissionManager] Mission Complete: " + active_mission_id)
	mission_completed.emit(active_mission_id)
	active_mission_id = ""
	set_process(false)

	# Trigger Match End
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		# 1 = Generic Winner/Player Team
		gs.match_service.end_match.rpc(1)


func abort_mission() -> void:
	if active_mission_id != "":
		active_mission_id = ""
		mission_failed.emit(active_mission_id)
		set_process(false)
