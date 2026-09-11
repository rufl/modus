class_name ButtonStand
extends Node3D

signal pressed(interactor: Node)

@onready var interactable: Interactable = $Interactable
@onready var button_mesh: Node3D = $ButtonMesh


func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node) -> void:
	if not interactor or not _is_valid_interactor(interactor):
		return
	if multiplayer.is_server():
		_sync_press.rpc()
	else:
		_request_press.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_press() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player.get_multiplayer_authority() == sender_id and _is_valid_interactor(player):
			_sync_press.rpc()
			return


func _is_valid_interactor(interactor: Node) -> bool:
	return (
		interactor.is_in_group("player")
		and interactor is Node3D
		and (interactor as Node3D).global_position.distance_to(global_position) <= 3.5
	)


@rpc("authority", "call_local", "reliable")
func _sync_press() -> void:
	pressed.emit(null)
	_animate_press()


func _animate_press() -> void:
	if not button_mesh:
		return

	var start_y: float = button_mesh.position.y
	var tween: Tween = create_tween()
	tween.tween_property(button_mesh, "position:y", start_y - 0.05, 0.1)
	tween.tween_property(button_mesh, "position:y", start_y, 0.1)
