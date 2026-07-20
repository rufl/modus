extends Node
class_name InputComponent

signal interact_pressed
signal interact_released
signal weapon_switch_requested(index: int)
signal quick_switch_requested
signal melee_pressed
signal skill_tree_toggled
signal inventory_toggled
signal pause_toggled

var move_vector: Vector2
var wish_jump: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var wish_shoot: bool = false
var wish_reload: bool = false

var _parent_node: Node = null


func _ready() -> void:
	_parent_node = get_parent()
	# Child nodes don't inherit multiplayer authority in Godot 4
	# Check parent's authority instead
	var is_auth: bool = _is_local_authority()
	if is_auth:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Check if this is the local player's input component


func _is_local_authority() -> bool:
	if not _parent_node:
		_parent_node = get_parent()

	if _parent_node and _parent_node.has_method("is_multiplayer_authority"):
		return _parent_node.is_multiplayer_authority()
	# Fallback: if no multiplayer peer, assume local authority
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_authority():
		return

	# Only process gameplay inputs if the mouse is captured (In-Game)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# Actions
	if Input.is_action_just_pressed("interact"):
		interact_pressed.emit()
	if Input.is_action_just_released("interact"):
		interact_released.emit()
	if Input.is_action_just_pressed("reload"):
		wish_reload = true
	if Input.is_action_just_pressed("quick_weapon_switch"):
		quick_switch_requested.emit()

	if Input.is_action_just_pressed("inventory"):
		inventory_toggled.emit()
	if Input.is_action_just_pressed("pause"):
		pause_toggled.emit()
	if Input.is_action_just_pressed("melee"):
		melee_pressed.emit()
	if Input.is_action_just_pressed("skill_tree"):
		skill_tree_toggled.emit()

	# Weapon Switching (1-9 for available weapons, 0 for 10th weapon)
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.keycode
		if keycode >= KEY_1 and keycode <= KEY_9:
			weapon_switch_requested.emit(keycode - KEY_1)
		elif keycode == KEY_0:
			weapon_switch_requested.emit(9)  # 10th weapon slot


func _process(_delta: float) -> void:
	if not _is_local_authority():
		return

	# Polling for continuous state
	# Only process gameplay inputs if the mouse is captured (In-Game)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		move_vector = Input.get_vector("left", "right", "up", "down")
		wish_jump = Input.is_action_pressed("jump")
		is_crouching = Input.is_action_pressed("crouch")
		is_sprinting = Input.is_action_pressed("sprint")
		wish_shoot = Input.is_action_pressed("shoot")
	else:
		# Reset all inputs if in menu/cursor mode
		move_vector = Vector2.ZERO
		wish_jump = false
		is_crouching = false
		is_sprinting = false
		wish_shoot = false
