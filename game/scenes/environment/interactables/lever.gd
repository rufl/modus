class_name Lever
extends Node3D

signal toggled(state: bool)

@export var is_on: bool = false

@onready var interactable: Interactable = $Interactable
@onready var handle: Node3D = $HandlePivot/Handle
@onready var handle_pivot: Node3D = $HandlePivot
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)
	_update_visuals(true)


func _on_interacted(interactor: Node) -> void:
	if not interactor or not _is_valid_interactor(interactor):
		return
	if multiplayer.is_server():
		_sync_state.rpc(not is_on)
	else:
		_request_state.rpc_id(1, not is_on)


@rpc("any_peer", "call_local", "reliable")
func _request_state(new_state: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player.get_multiplayer_authority() == sender_id and _is_valid_interactor(player):
			_sync_state.rpc(new_state)
			return


func _is_valid_interactor(interactor: Node) -> bool:
	return (
		interactor.is_in_group("player")
		and interactor is Node3D
		and (interactor as Node3D).global_position.distance_to(global_position) <= 3.5
	)


@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: bool) -> void:
	is_on = new_state
	toggled.emit(is_on)
	_update_visuals()


func _update_visuals(instant: bool = false) -> void:
	var target_rot: float = 45.0 if is_on else -45.0

	if instant:
		handle_pivot.rotation_degrees.x = target_rot
	else:
		var tween: Tween = create_tween()
		(
			tween
			. tween_property(handle_pivot, "rotation_degrees:x", target_rot, 0.3)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_OUT)
		)

	# Update prompt
	if interactable:
		interactable.prompt_text = "Turn Off" if is_on else "Turn On"
