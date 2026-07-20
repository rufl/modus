extends Node3D

const STATE_MAP = {
	"Idle": "idle_state",
	"Patrol": "patrol_state",
	"Attack": "attack_state",
	"Chase": "chase_state",
	"Search": "search_state",
}

var enemies: Dictionary = {}
var dummy_target: Node3D = null


func _ready() -> void:
	if multiplayer.is_server():
		_create_dummy_target()

	# Auto-register enemies
	var lab_enemies: Array[Node] = get_tree().get_nodes_in_group("lab_enemies")
	for i in range(lab_enemies.size()):
		var enemy: Node = lab_enemies[i]
		register_enemy(enemy, i)


func register_enemy(enemy: Node, index: int) -> void:
	enemies[index] = enemy
	GameManager.get_core_system("logger").info(
		"[EnemyLab] Registered enemy %s at index %d" % [enemy.name, index], "World"
	)


## Request a state change for all lab enemies
## Called by buttons (client -> server RPC)

@rpc("any_peer", "call_local", "reliable")
func request_state_change(state_name: String) -> void:
	if not multiplayer.is_server():
		# Forward to server
		request_state_change.rpc_id(1, state_name)
		return

	GameManager.get_core_system("logger").info(
		"[EnemyLab] State change requested: " + " " + str(state_name), "World"
	)
	_apply_state_change(state_name)


func _apply_state_change(state_req: String) -> void:
	for enemy: Node in enemies.values():
		if not is_instance_valid(enemy):
			continue

		# Ensure we have the AI Controller
		var ai: Node = enemy.ai_controller
		if not ai:
			GameManager.get_core_system("logger").info(
				"No AI controller on " + " " + str(enemy.name), "World"
			)
			continue

		# Handle specific logic per state
		if state_req == "Attack":
			# Ensure we have a target
			if dummy_target:
				ai.target = dummy_target
				# Force alert
				if "is_aggro" in enemy:
					enemy.is_aggro = true
		elif state_req == "Idle" or state_req == "Patrol":
			# Clear target
			ai.target = null
			if "is_aggro" in enemy:
				enemy.is_aggro = false

		# Find and switch state
		var target_state_class_name: Variant = STATE_MAP.get(state_req, "")

		# Iterate children of AI controller to find matching state
		var found: bool = false
		for child in ai.get_children():
			# Determine strict class via string or script comparison
			# Simplified: Check if script resource path or class_name matches
			# We can try to cast or check 'name' if conventionally named
			if (
				child.name.contains(state_req)
				or (
					child.get_script()
					and child.get_script().resource_path.contains(target_state_class_name)
				)
			):
				ai.change_state(child)
				found = true
				break

		if not found:
			GameManager.get_core_system("logger").info(
				"[EnemyLab] Could not find state %s on %s" % [state_req, enemy.name], "World"
			)


func _create_dummy_target() -> void:
	# Create an invisible target in the middle of the room/hallway
	# So enemies have something to "look at" and "attack"
	dummy_target = Node3D.new()
	dummy_target.name = "DummyTarget"
	add_child(dummy_target)
	# Position it somewhere central relative to this controller
	dummy_target.position = Vector3(0, 1.5, 5)
