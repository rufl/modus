@tool
class_name DoorActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum DoorType { SLIDE_X, SLIDE_Y, SLIDE_Z, ROTATE_Y, DOUBLE_SLIDE }  ## Slides along X axis  ## Slides up (raising door)  ## Slides along Z axis  ## Rotates around Y axis (swing door)  ## Two panels slide apart
enum OpenDirection { POSITIVE, NEGATIVE, AUTO }  ## Opens in positive axis direction  ## Opens in negative axis direction  ## Opens away from player

@export var door_type: DoorType = DoorType.SLIDE_Y
@export var open_direction: OpenDirection = OpenDirection.POSITIVE
@export var open_distance: float = 2.5
@export var open_angle: float = 90.0  ## For ROTATE_Y type
@export var open_duration: float = 0.5
@export var close_duration: float = 0.5
@export var auto_close: bool = false
@export var auto_close_delay: float = 3.0
@export var locked: bool = false
@export var required_key: String = ""

var door_mesh: Node3D = null

var _closed_transform: Transform3D
var _open_transform: Transform3D
var _current_tween: Tween = null
var _auto_close_timer: float = 0.0


func _init() -> void:
	actor_category = "mover"
	actor_name = "Door"
	actor_description = "Animated door that opens/closes"


func _on_actor_ready() -> void:
	_create_visual()
	_calculate_transforms()


func _create_visual() -> void:
	# Create a simple door visual
	door_mesh = CSGBox3D.new()
	door_mesh.name = "DoorMesh"

	match door_type:
		DoorType.SLIDE_X, DoorType.SLIDE_Z:
			door_mesh.size = Vector3(0.2, 2.5, 1.5)
		DoorType.SLIDE_Y:
			door_mesh.size = Vector3(1.5, 2.5, 0.2)
		DoorType.ROTATE_Y:
			door_mesh.size = Vector3(1.0, 2.5, 0.1)
		DoorType.DOUBLE_SLIDE:
			door_mesh.size = Vector3(0.1, 2.5, 0.75)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.3, 0.2)  # Wood color
	door_mesh.material = material
	door_mesh.use_collision = true

	add_child(door_mesh)

	# Store closed position
	_closed_transform = door_mesh.transform


func _calculate_transforms() -> void:
	if not door_mesh:
		return

	_closed_transform = door_mesh.transform
	_open_transform = _closed_transform

	var direction: float = 1.0 if open_direction == OpenDirection.POSITIVE else -1.0

	match door_type:
		DoorType.SLIDE_X:
			_open_transform.origin.x += open_distance * direction
		DoorType.SLIDE_Y:
			_open_transform.origin.y += open_distance
		DoorType.SLIDE_Z:
			_open_transform.origin.z += open_distance * direction
		DoorType.ROTATE_Y:
			var angle: float = deg_to_rad(open_angle * direction)
			_open_transform = _open_transform.rotated(Vector3.UP, angle)
		DoorType.DOUBLE_SLIDE:
			# Will handle separately with two meshes
			_open_transform.origin.z += open_distance * 0.5


func _process(delta: float) -> void:
	super._process(delta)

	# Handle auto-close
	if auto_close and is_active:
		_auto_close_timer -= delta
		if _auto_close_timer <= 0:
			close_door()


func _on_activated(data: Dictionary) -> void:
	open_door(data.get("source"))


func _on_deactivated() -> void:
	close_door()


func open_door(source: Node = null) -> void:
	if locked:
		# Check for key
		if source and source.has_method("has_key"):
			if source.has_key(required_key):
				locked = false
			else:
				return  # Can't open
		else:
			return

	# Determine direction for AUTO
	if open_direction == OpenDirection.AUTO and source and source is Node3D:
		var to_source: Vector3 = source.global_position - global_position
		var forward: Vector3 = -global_transform.basis.z
		var dot: float = to_source.dot(forward)
		# Adjust open transform based on player position
		_calculate_transforms()
		if dot < 0:
			# Player is behind door, reverse direction
			match door_type:
				DoorType.SLIDE_X:
					_open_transform.origin.x = _closed_transform.origin.x - open_distance
				DoorType.SLIDE_Z:
					_open_transform.origin.z = _closed_transform.origin.z - open_distance
				DoorType.ROTATE_Y:
					_open_transform = _closed_transform.rotated(Vector3.UP, deg_to_rad(-open_angle))

	# Animate door
	_animate_door(_open_transform, open_duration)

	if auto_close:
		_auto_close_timer = auto_close_delay


func close_door() -> void:
	_animate_door(_closed_transform, close_duration)


func _animate_door(target: Transform3D, duration: float) -> void:
	if not door_mesh:
		return

	# Cancel existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(door_mesh, "transform", target, duration)


func interact(player: Node = null) -> bool:
	if locked and not required_key.is_empty():
		if player and player.has_method("has_key"):
			if not player.has_key(required_key):
				return false

	if is_active:
		deactivate()  # Close
	else:
		trigger(player, {"interacted": true})  # Open

	return true


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "door_type",
				"type": TYPE_INT,
				"label": "Door Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Slide X,Slide Y,Slide Z,Rotate Y,Double Slide"
			},
			{
				"name": "open_direction",
				"type": TYPE_INT,
				"label": "Open Direction",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Positive,Negative,Auto"
			},
			{
				"name": "open_distance",
				"type": TYPE_FLOAT,
				"label": "Open Distance",
				"description": "How far the door moves when opening"
			},
			{
				"name": "open_angle",
				"type": TYPE_FLOAT,
				"label": "Open Angle",
				"description": "Rotation angle for swing doors"
			},
			{"name": "open_duration", "type": TYPE_FLOAT, "label": "Open Duration"},
			{
				"name": "auto_close",
				"type": TYPE_BOOL,
				"label": "Auto Close",
				"description": "Automatically close after delay"
			},
			{"name": "auto_close_delay", "type": TYPE_FLOAT, "label": "Auto Close Delay"},
			{"name": "locked", "type": TYPE_BOOL, "label": "Locked"},
			{"name": "required_key", "type": TYPE_STRING, "label": "Required Key"}
		]
	)
	return props
