@tool
class_name SecretWallActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TriggerType { CHANNEL, PROXIMITY, SHOOTABLE, INTERACT }  ## Activated via channel system (switches, buttons)  ## Opens when player gets close  ## Opens when shot  ## Opens when player presses E
enum MoveType { SLIDE_X, SLIDE_Y, SLIDE_Z, ROTATE_Y, LOWER, RAISE }  ## Slides along X axis  ## Slides up/down  ## Slides along Z axis  ## Rotates around Y axis  ## Lowers into floor  ## Raises into ceiling

@export var trigger_type: TriggerType = TriggerType.CHANNEL
@export var move_type: MoveType = MoveType.SLIDE_X
@export var move_direction: Vector3 = Vector3.RIGHT
@export var move_distance: float = 2.0
@export var move_speed: float = 1.0
@export var one_time_use: bool = true
@export var show_secret_message: bool = true
@export var secret_message: String = "Secret discovered!"
@export_group("Proximity Settings")
@export var proximity_range: float = 3.0
@export var proximity_check_interval: float = 0.5
@export_group("Shootable Settings")
@export var health: float = 10.0

var wall_mesh: CSGBox3D = null

var _closed_transform: Transform3D
var _open_transform: Transform3D
var _current_tween: Tween = null
var _is_open: bool = false
var _proximity_timer: float = 0.0
var _current_health: float = 0.0


func _init() -> void:
	actor_category = "mover"
	actor_name = "Secret Wall"
	actor_description = "Hidden wall that opens when triggered"


func _on_actor_ready() -> void:
	_create_visual()
	_calculate_transforms()
	_current_health = health

	# Setup collision for shootable
	if trigger_type == TriggerType.SHOOTABLE:
		_setup_shootable()


func _create_visual() -> void:
	# Create wall visual
	wall_mesh = CSGBox3D.new()
	wall_mesh.name = "WallMesh"
	wall_mesh.size = Vector3(2.0, 2.5, 0.2)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray stone
	wall_mesh.material = material
	wall_mesh.use_collision = true

	add_child(wall_mesh)
	_closed_transform = wall_mesh.transform


func _calculate_transforms() -> void:
	if not wall_mesh:
		return

	_closed_transform = wall_mesh.transform
	_open_transform = _closed_transform

	match move_type:
		MoveType.SLIDE_X:
			_open_transform.origin.x += move_distance * move_direction.x
		MoveType.SLIDE_Y:
			_open_transform.origin.y += move_distance
		MoveType.SLIDE_Z:
			_open_transform.origin.z += move_distance * move_direction.z
		MoveType.ROTATE_Y:
			_open_transform = _open_transform.rotated(Vector3.UP, deg_to_rad(90.0))
		MoveType.LOWER:
			_open_transform.origin.y -= move_distance
		MoveType.RAISE:
			_open_transform.origin.y += move_distance


func _process(delta: float) -> void:
	super._process(delta)

	# Proximity check
	if trigger_type == TriggerType.PROXIMITY and not _is_open:
		_proximity_timer += delta
		if _proximity_timer >= proximity_check_interval:
			_proximity_timer = 0.0
			_check_proximity()


func _check_proximity() -> void:
	# Find player
	var players: Array = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player is Node3D:
			var distance: float = global_position.distance_to(player.global_position)
			if distance <= proximity_range:
				open_wall()
				break


func _setup_shootable() -> void:
	# Add to hittable group
	add_to_group("hittable")


func receive_damage(amount: float, _source: Node = null) -> void:
	if trigger_type != TriggerType.SHOOTABLE:
		return

	_current_health -= amount
	if _current_health <= 0 and not _is_open:
		open_wall()


func _on_activated(data: Dictionary) -> void:
	open_wall(data.get("source"))


func open_wall(source: Node = null) -> void:
	if _is_open:
		return

	if one_time_use and activation_count > 0:
		return

	_is_open = true

	# Show secret message
	if show_secret_message and source:
		_show_secret_notification(source)

	# Animate wall
	_animate_wall(_open_transform)

	# Disable collision when open
	if wall_mesh:
		wall_mesh.use_collision = false


func _animate_wall(target: Transform3D) -> void:
	if not wall_mesh:
		return

	# Cancel existing tween
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	var duration: float = move_distance / move_speed
	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE)
	_current_tween.set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(wall_mesh, "transform", target, duration)


func _show_secret_notification(player: Node) -> void:
	# Try to show message to player
	if player.has_method("show_notification"):
		player.show_notification(secret_message)
	elif GameManager and GameManager.has_method("show_message"):
		GameManager.show_message(secret_message)


func interact(player: Node = null) -> bool:
	if trigger_type != TriggerType.INTERACT:
		return false

	open_wall(player)
	return true


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "trigger_type",
				"type": TYPE_INT,
				"label": "Trigger Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Channel,Proximity,Shootable,Interact"
			},
			{
				"name": "move_type",
				"type": TYPE_INT,
				"label": "Movement Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Slide X,Slide Y,Slide Z,Rotate Y,Lower,Raise"
			},
			{
				"name": "move_distance",
				"type": TYPE_FLOAT,
				"label": "Move Distance",
				"description": "How far the wall moves when opening"
			},
			{
				"name": "move_speed",
				"type": TYPE_FLOAT,
				"label": "Move Speed",
				"description": "Speed of movement (units per second)"
			},
			{
				"name": "one_time_use",
				"type": TYPE_BOOL,
				"label": "One Time Use",
				"description": "Can only be opened once"
			},
			{"name": "show_secret_message", "type": TYPE_BOOL, "label": "Show Secret Message"},
			{"name": "secret_message", "type": TYPE_STRING, "label": "Secret Message"},
			{"name": "proximity_range", "type": TYPE_FLOAT, "label": "Proximity Range"},
			{"name": "health", "type": TYPE_FLOAT, "label": "Health (Shootable)"}
		]
	)
	return props
