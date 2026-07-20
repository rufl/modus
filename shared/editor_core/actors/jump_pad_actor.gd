@tool
class_name JumpPadActor
extends "res://shared/editor_core/actors/actor_base.gd"

@export var launch_velocity: float = 25.0
@export var launch_angle: float = 90.0  # 90 = straight up, 45 = angled
@export var sound_effect: String = "jump_pad"
@export var particle_effect: bool = true

var pad_mesh: Node3D = null
var launch_area: Area3D = null
var particles: GPUParticles3D = null


func _init() -> void:
	actor_category = "mover"
	actor_name = "Jump Pad"
	actor_description = "Launches entities into the air"


func _on_actor_ready() -> void:
	_create_visual()
	_create_launch_area()
	_create_particles()


func _create_visual() -> void:
	# Base platform
	var base := CSGBox3D.new()
	base.name = "JumpPadBase"
	base.size = Vector3(1.5, 0.2, 1.5)
	base.position.y = 0.1

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(1.0, 0.6, 0.2)  # Orange
	base_mat.emission_enabled = true
	base_mat.emission = Color(1.0, 0.7, 0.3)
	base_mat.emission_energy_multiplier = 1.5
	base.material = base_mat
	add_child(base)

	# Directional arrow indicator
	var arrow := CSGBox3D.new()
	arrow.name = "DirectionArrow"
	arrow.size = Vector3(0.3, 0.1, 0.8)
	arrow.position.y = 0.25

	# Rotate arrow based on launch angle
	var angle_rad: float = deg_to_rad(launch_angle - 90.0)
	arrow.rotation.x = angle_rad

	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(1.0, 1.0, 0.0)  # Yellow
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color(1.0, 1.0, 0.5)
	arrow_mat.emission_energy_multiplier = 2.0
	arrow.material = arrow_mat
	add_child(arrow)

	pad_mesh = base


func _create_launch_area() -> void:
	launch_area = Area3D.new()
	launch_area.name = "LaunchArea"
	launch_area.monitoring = true
	add_child(launch_area)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 0.5, 1.5)
	shape.shape = box
	shape.position.y = 0.25
	launch_area.add_child(shape)

	launch_area.body_entered.connect(_on_body_entered_launch)


func _create_particles() -> void:
	if not particle_effect:
		return

	particles = GPUParticles3D.new()
	particles.name = "LaunchParticles"
	particles.amount = 16
	particles.lifetime = 0.5
	particles.emitting = false  # Only emit on launch
	particles.one_shot = true
	particles.position.y = 0.3
	add_child(particles)

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.7, 0.1, 0.7)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 4.0
	process_mat.gravity = Vector3(0, -9.8, 0)
	process_mat.color = Color(1.0, 0.8, 0.3, 0.8)
	particles.process_material = process_mat


func _on_body_entered_launch(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return

	# Calculate launch direction
	var launch_dir: Vector3 = Vector3.UP
	if launch_angle != 90.0:
		var angle_rad: float = deg_to_rad(launch_angle)
		var forward: Vector3 = -global_transform.basis.z
		launch_dir = Vector3.UP.rotated(forward.cross(Vector3.UP).normalized(), angle_rad - PI / 2)

	# Apply launch velocity
	var vel: Vector3 = body.velocity
	vel.y = launch_velocity * launch_dir.y
	if launch_angle != 90.0:
		vel.x += launch_velocity * launch_dir.x
		vel.z += launch_velocity * launch_dir.z
	body.velocity = vel

	# Callback if available
	if body.has_method("on_launch"):
		body.on_launch()

	# Play sound
	var audio_service = GameManager.get_core_system("audio") if GameManager else null
	if audio_service:
		var audio: Node = audio_service
		if audio.has_method("play_sound_3d"):
			var stream: AudioStream = load("res://game/art/audio/sfx/jump_pad.wav")
			audio.play_sound_3d(stream, global_position)

	# Spawn particles
	if particles:
		particles.restart()

	# Spawn visual feedback
	var gs_node: Node = get_node_or_null("/root/GameplayService")
	if gs_node and gs_node.has_method("get_service"):
		var gs: Node = gs_node.call("get_service")
		if gs and gs.get("effects") and gs.get("effects").has_method("spawn_explosion"):
			# spawn_explosion(position, explosion_type, damage, radius)
			gs.get("effects").spawn_explosion.rpc(global_position, 0, 0.0, 0.3)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "launch_velocity",
				"type": TYPE_FLOAT,
				"label": "Launch Velocity",
				"description": "Upward launch speed"
			},
			{
				"name": "launch_angle",
				"type": TYPE_FLOAT,
				"label": "Launch Angle",
				"description": "90 = straight up, 45 = angled"
			},
			{"name": "particle_effect", "type": TYPE_BOOL, "label": "Particle Effect"}
		]
	)
	return props
