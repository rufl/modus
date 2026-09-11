@tool
class_name Door
extends Node3D

signal opened
signal closed
signal locked_tried

@export_group("Door Settings")
@export var is_locked: bool = false
@export var key_required: String = ""  # Item ID needed
@export var auto_close: bool = true
@export var auto_close_delay: float = 3.0
@export var open_speed: float = 2.0

var is_open: bool = false

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var interactable: Interactable = $Interactable
@onready var trigger_zone: TriggerZone = $TriggerZone  # Optional for auto-doors


func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)
		# Update prompt
		_update_prompt()

	if trigger_zone:
		trigger_zone.triggered.connect(_on_trigger_entered)

	# Ensure multiplayer sync configuration if needed
	# (Usually handled by MultiplayerSynchronizer node in scene, but we can enforce authority logic)


func _on_interacted(interactor: Node) -> void:
	if is_locked:
		# Check for key
		if _has_key(interactor):
			_unlock_door()
			_toggle_door()
		else:
			locked_tried.emit()
			# Feedback: "Locked"
	else:
		_toggle_door()


func _on_trigger_entered(_body: Node) -> void:
	if not is_locked and not is_open:
		open_door()


func _toggle_door() -> void:
	if is_open:
		close_door()
	else:
		open_door()


func open_door() -> void:
	if is_open:
		return

	# Sync request
	if multiplayer.is_server():
		_perform_open.rpc()
	else:
		_request_open.rpc_id(1)


func close_door() -> void:
	if not is_open:
		return

	if multiplayer.is_server():
		_perform_close.rpc()
	else:
		_request_close.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_open() -> void:
	if not multiplayer.is_server():
		return
	var requesting_player: Node = _get_requesting_player()
	if not requesting_player:
		return
	if is_locked:
		if not _has_key(requesting_player):
			return
		_unlock_door()
	_perform_open.rpc()


@rpc("any_peer", "call_local", "reliable")
func _request_close() -> void:
	if not multiplayer.is_server() or not _is_valid_request_sender():
		return
	_perform_close.rpc()


func _get_requesting_player() -> Node:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return null
	for player: Node in get_tree().get_nodes_in_group("player"):
		if (
			player.get_multiplayer_authority() == sender_id
			and player is Node3D
			and (player as Node3D).global_position.distance_to(global_position) <= 3.5
		):
			return player
	return null


func _is_valid_request_sender() -> bool:
	return _get_requesting_player() != null



@rpc("authority", "call_local", "reliable")
func _perform_open() -> void:
	is_open = true
	opened.emit()
	if anim_player:
		anim_player.play("open")

	# Schedule auto close if enabled
	# (server authority only for timer logic usually, but works local too)
	if auto_close and multiplayer.is_server():
		await get_tree().create_timer(auto_close_delay).timeout
		if is_open:  # Check if still open
			close_door()


@rpc("authority", "call_local", "reliable")
func _perform_close() -> void:
	is_open = false
	closed.emit()
	if anim_player:
		anim_player.play_backwards("open")


func _has_key(interactor: Node) -> bool:
	# Integrate with Inventory system when available
	# For now, return false if key required
	if key_required == "":
		return true

	# Mock inventory check
	if interactor.has_method("has_item"):
		return interactor.has_item(key_required)

	return false


func _unlock_door() -> void:
	if not is_locked:
		return

	# Sync unlock? For now assume local toggle sufficient or triggers open
	is_locked = false
	_update_prompt()


func _update_prompt() -> void:
	if not interactable:
		return

	if is_locked:
		var key_name: String = key_required if key_required else "Key"
		interactable.prompt_text = "Locked (Requires %s)" % key_name
	else:
		interactable.prompt_text = "Open" if not is_open else "Close"
