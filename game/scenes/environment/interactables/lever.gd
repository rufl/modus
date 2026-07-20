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


func _on_interacted(_interactor: Node) -> void:
	_set_state.rpc(not is_on)


@rpc("any_peer", "call_local", "reliable")
func _set_state(new_state: bool) -> void:
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
