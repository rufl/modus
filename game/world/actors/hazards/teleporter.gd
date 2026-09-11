@tool
class_name Teleporter
extends Area3D

const TELEPORT_COOLDOWN: float = 1.0

@export_category("Teleporter Settings")
@export var destination_node: Node3D
@export var teleport_sound: AudioStream
@export var enter_sound: AudioStream
@export var exit_sound: AudioStream
@export var relative: bool = false
@export var reorient_velocity: bool = true
@export_category("Visuals")
@export var enter_particles: GPUParticles3D
@export var exit_particles: GPUParticles3D

var _cooldowns: Dictionary = {}  # Body -> Timer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto-find destination if linked via Editor connection system (future proofing)
	if not destination_node and has_meta("linked_nodes"):
		var linked: Array = get_meta("linked_nodes")
		if linked is Array and linked.size() > 0:
			destination_node = get_node_or_null(linked[0])


func _process(delta: float) -> void:
	# Cleanup cooldowns
	var to_remove: Array[Node3D] = []
	for body: Node3D in _cooldowns.keys():
		_cooldowns[body] -= delta
		if _cooldowns[body] <= 0:
			to_remove.append(body)

	for body: Node3D in to_remove:
		_cooldowns.erase(body)


func _on_body_entered(body: Node3D) -> void:
	if not destination_node:
		return

	if body in _cooldowns:
		return

	if body is CharacterBody3D or body is RigidBody3D:
		teleport(body)


func teleport(body: Node3D) -> void:
	# 1. Play Enter Sound/FX
	if enter_sound:
		var enter_audio: Node = GameManager.get_core_system("audio")
		if enter_audio and enter_audio.has_method("play_stream_3d"):
			enter_audio.play_stream_3d(enter_sound, global_position)

	# 2. Calculate new position
	var target_pos: Vector3 = destination_node.global_position

	if relative:
		var offset: Vector3 = body.global_position - global_position
		target_pos += offset

	# 3. Teleport Physics Body
	# Physics interpolation requires teleporting in physics process or resetting state
	# For CharacterBody3D, usually safe to set global_position directly
	body.global_position = target_pos

	# 4. Handle Rotation / Velocity reorientation
	if reorient_velocity:
		# Match destination Y rotation
		var rot_diff: float = destination_node.global_rotation.y - global_rotation.y
		body.rotate_y(rot_diff)

		# Rotate velocity if applicable
		if "velocity" in body:
			body.velocity = body.velocity.rotated(Vector3.UP, rot_diff)

		# If player, rotate camera too
		if body.has_method("force_look_direction"):
			body.force_look_direction(destination_node.global_rotation)

	# 5. Play Exit Sound/FX at destination
	if exit_sound:
		var exit_audio: Node = GameManager.get_core_system("audio")
		if exit_audio and exit_audio.has_method("play_stream_3d"):
			exit_audio.play_stream_3d(exit_sound, target_pos)

	# Trigger Destination Cooldown (so we don't teleport back instantly if it's a 2-way)
	if destination_node is Teleporter:
		destination_node.add_cooldown(body)

	# Local cooldown
	add_cooldown(body)

	GameManager.get_core_system("logger").info(
		"[Teleporter] Teleported %s to %s" % [body.name, destination_node.name], "World"
	)


func add_cooldown(body: Node3D) -> void:
	_cooldowns[body] = TELEPORT_COOLDOWN
