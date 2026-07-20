class_name Interactable
extends Area3D

signal interacted(interactor: Node)
signal focused(interactor: Node)
signal unfocused(interactor: Node)

@export_group("Interaction Settings")
@export var is_interactable: bool = true
@export var prompt_text: String = "Interact"
@export var interaction_time: float = 0.0  # Hold time (0 = instant)
@export var one_shot: bool = false
@export var cooldown: float = 0.5

var _current_interactor: Node = null
var _cooldown_timer: float = 0.0
var _has_been_used: bool = false


func _ready() -> void:
	set_process(false)  # Only process when cooldown is active
	# Ensure correct collision layer/mask for interaction
	collision_layer = CollisionLayers.LAYER_INTERACTABLES
	collision_mask = 0


func _process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			set_process(false)  # Disable when cooldown complete


func interact(interactor: Node) -> void:
	if not is_interactable:
		return

	if one_shot and _has_been_used:
		return

	if _cooldown_timer > 0:
		return

	_has_been_used = true
	_cooldown_timer = cooldown
	if cooldown > 0:
		set_process(true)  # Enable processing for cooldown

	interacted.emit(interactor)


func on_focus(interactor: Node) -> void:
	if not is_interactable:
		return
	_current_interactor = interactor
	focused.emit(interactor)


func on_unfocus(interactor: Node) -> void:
	if _current_interactor == interactor:
		_current_interactor = null
		unfocused.emit(interactor)


func set_interactable(state: bool) -> void:
	is_interactable = state
