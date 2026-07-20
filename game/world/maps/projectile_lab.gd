class_name ProjectileLab
extends Node3D

@export var interactable_button_path: NodePath

var _is_frozen: bool = false
var _button: Node = null


func _ready() -> void:
	if interactable_button_path:
		_button = get_node_or_null(interactable_button_path)
		if _button and _button.has_signal("interacted"):
			_button.interacted.connect(_on_button_pressed)


func _on_button_pressed(_interactor: Node) -> void:
	# Request server to toggle
	toggle_freeze.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func toggle_freeze() -> void:
	# Only server decides (or authorized logic)
	if not multiplayer.is_server():
		return

	_is_frozen = not _is_frozen
	var new_scale: float = 0.1 if _is_frozen else 1.0

	# Broadcast to all
	_sync_time_scale.rpc(new_scale)


@rpc("authority", "call_local", "reliable")
func _sync_time_scale(time_scale_value: float) -> void:
	Engine.time_scale = time_scale_value
	_is_frozen = (time_scale_value < 1.0)
	GameManager.get_core_system("logger").info(
		"[Lab] Time Scale: " + str(time_scale_value), "ProjectileLab"
	)


# Spawns a test projectile (Server only)


func spawn_test_projectile() -> void:
	if not multiplayer.is_server():
		return

	# Default to rocket for testing
	var projectile_scene: PackedScene = load("res://game/content/weapons/rocket/rocket.tscn")
	if projectile_scene:
		var proj: Node3D = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector3(0, 2, 0)
		proj.look_at(global_position + Vector3(10, 2, 0))  # Fire forward X+
