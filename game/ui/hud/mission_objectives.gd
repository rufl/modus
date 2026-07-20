extends Control

@onready var objectives_container: VBoxContainer = $MarginContainer/VBoxContainer


func _ready() -> void:
	# Connect to MissionManager
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.mission:
		gs.mission.mission_started.connect(_on_mission_started)
		gs.mission.mission_completed.connect(_on_mission_completed)
		gs.mission.mission_failed.connect(_on_mission_failed)
		gs.mission.objective_updated.connect(_on_objective_updated)

		# Initial check if already started
		if gs.mission.active_mission_id != "":
			_on_mission_started(gs.mission.active_mission_id)
	else:
		push_warning("[MissionObjectives] GameplaySvc or mission manager not available")


func _exit_tree() -> void:
	# Unsubscribe from mission events to prevent null callable errors
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.mission:
		if gs.mission.mission_started.is_connected(_on_mission_started):
			gs.mission.mission_started.disconnect(_on_mission_started)
		if gs.mission.mission_completed.is_connected(_on_mission_completed):
			gs.mission.mission_completed.disconnect(_on_mission_completed)
		if gs.mission.mission_failed.is_connected(_on_mission_failed):
			gs.mission.mission_failed.disconnect(_on_mission_failed)
		if gs.mission.objective_updated.is_connected(_on_objective_updated):
			gs.mission.objective_updated.disconnect(_on_objective_updated)


func _on_mission_started(mission_id: String) -> void:
	print("[MissionObjectives] Mission started: ", mission_id)
	_refresh_objectives()


func _on_mission_completed(_mission_id: String) -> void:
	_clear_objectives()
	# Maybe show "Mission Complete" label briefly?
	# For now MatchHUD handles the big end screen.


func _on_mission_failed(_mission_id: String) -> void:
	_clear_objectives()


func _on_objective_updated(
	_mission_id: String, objective_id: String, current: int, required: int
) -> void:
	# Find label for this objective
	var label: Label = objectives_container.get_node_or_null(objective_id)
	if label:
		_update_label_text(label, objective_id, current, required)
	else:
		_refresh_objectives()


func _refresh_objectives() -> void:
	_clear_objectives()

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.mission:
		return

	var data: Dictionary = gs.mission.active_mission_data
	var objectives: Array = data.get("objectives", [])

	for obj: Dictionary in objectives:
		var obj_id: String = obj.id
		var label: Label = Label.new()
		label.name = obj_id
		objectives_container.add_child(label)

		# Initial State
		var current: int = gs.mission.objective_state.get(obj_id, 0)
		var required: int = obj.get("required_count", -1)

		_update_label_text(label, obj_id, current, required)


func _update_label_text(label: Label, _obj_id: String, current: int, required: int) -> void:
	var obj_data: Dictionary = _get_objective_data(_obj_id)
	var desc: String = obj_data.get("description", "Objective")

	if required == -1:
		# Kill All / Unknown max
		# For Kill All, we might want to show remaining count if we knew it?
		# MissionManager currently tracks 'living_count' internally but only emits 0/1 or current.
		# Let's assume 'current' passed here is meaningful.
		# Actually MissionManager logic needs to emit useful "current" for KillAll.
		# For now, let's just show the description.
		label.text = "- %s" % desc
	else:
		label.text = "- %s: %d / %d" % [desc, current, required]


func _get_objective_data(obj_id: String) -> Dictionary:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.mission:
		return {}
	var objectives: Array = gs.mission.active_mission_data.get("objectives", [])
	for obj: Dictionary in objectives:
		if obj.id == obj_id:
			return obj
	return {}


func _clear_objectives() -> void:
	for child in objectives_container.get_children():
		child.queue_free()
