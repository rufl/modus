@tool
class_name PlatformActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum PlatformMode { ONCE, LOOP, PING_PONG, WAIT_TRIGGER }  ## Moves to end and stops  ## Loops back to start  ## Bounces between endpoints  ## Waits at each point for trigger

@export var platform_mode: PlatformMode = PlatformMode.PING_PONG
@export var platform_size: Vector3 = Vector3(2, 0.3, 2)
@export var move_speed: float = 2.0
@export var wait_at_points: float = 1.0
@export var waypoints: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(0, 3, 0)])
@export var start_moving: bool = true
@export var carry_passengers: bool = true

var platform_mesh: CSGBox3D = null
var platform_body: AnimatableBody3D = null

var _current_waypoint: int = 0
var _direction: int = 1
var _is_moving: bool = false
var _wait_timer: float = 0.0
var _passengers: Array[CharacterBody3D] = []


func _init() -> void:
	actor_category = "mover"
	actor_name = "Moving Platform"
	actor_description = "Platform that moves along waypoints"


func _on_actor_ready() -> void:
	_create_platform()

	if waypoints.is_empty():
		waypoints.append(Vector3.ZERO)

	if start_moving and starts_active:
		_is_moving = true


func _create_platform() -> void:
	# Animatable body for proper physics interaction
	platform_body = AnimatableBody3D.new()
	platform_body.name = "PlatformBody"
	add_child(platform_body)

	# Platform mesh
	platform_mesh = CSGBox3D.new()
	platform_mesh.name = "PlatformMesh"
	platform_mesh.size = platform_size
	platform_mesh.use_collision = true

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.4, 0.5)
	platform_mesh.material = material

	platform_body.add_child(platform_mesh)

	# Detection area for passengers
	if carry_passengers:
		var area := Area3D.new()
		area.name = "PassengerArea"
		platform_body.add_child(area)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(platform_size.x * 0.9, 0.5, platform_size.z * 0.9)
		shape.shape = box
		shape.position.y = platform_size.y * 0.5 + 0.25
		area.add_child(shape)

		area.body_entered.connect(_on_passenger_entered)
		area.body_exited.connect(_on_passenger_exited)


func _physics_process(delta: float) -> void:
	if not is_active or not _is_moving:
		return

	if _wait_timer > 0:
		_wait_timer -= delta
		return

	# Move towards current waypoint
	var target: Vector3 = waypoints[_current_waypoint]
	var current_pos: Vector3 = platform_body.position
	var direction: Vector3 = (target - current_pos).normalized()
	var distance: float = current_pos.distance_to(target)
	var step: float = move_speed * delta

	if step >= distance:
		# Reached waypoint
		platform_body.position = target
		_on_waypoint_reached()
	else:
		var movement: Vector3 = direction * step
		platform_body.position += movement

		# Move passengers
		if carry_passengers:
			for passenger: CharacterBody3D in _passengers:
				if is_instance_valid(passenger):
					passenger.velocity += movement / delta


func _on_waypoint_reached() -> void:
	_wait_timer = wait_at_points

	match platform_mode:
		PlatformMode.ONCE:
			if _current_waypoint >= waypoints.size() - 1:
				_is_moving = false
			else:
				_current_waypoint += 1

		PlatformMode.LOOP:
			_current_waypoint = (_current_waypoint + 1) % waypoints.size()

		PlatformMode.PING_PONG:
			if _direction > 0 and _current_waypoint >= waypoints.size() - 1:
				_direction = -1
			elif _direction < 0 and _current_waypoint <= 0:
				_direction = 1
			_current_waypoint += _direction

		PlatformMode.WAIT_TRIGGER:
			_is_moving = false


func _on_activated(_data: Dictionary) -> void:
	_is_moving = true


func _on_deactivated() -> void:
	_is_moving = false


func _on_passenger_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_passengers.append(body)


func _on_passenger_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_passengers.erase(body)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "platform_mode",
				"type": TYPE_INT,
				"label": "Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Once,Loop,Ping Pong,Wait Trigger"
			},
			{"name": "platform_size", "type": TYPE_VECTOR3, "label": "Size"},
			{"name": "move_speed", "type": TYPE_FLOAT, "label": "Speed"},
			{"name": "wait_at_points", "type": TYPE_FLOAT, "label": "Wait Time"}
		]
	)
	return props


func get_gizmo_data() -> Dictionary:
	var data: Dictionary = super.get_gizmo_data()
	data["waypoints"] = waypoints
	data["show_path"] = true
	return data
