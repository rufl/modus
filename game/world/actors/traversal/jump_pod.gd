@tool
class_name JumpPod
extends Area3D

@export var launch_force: float = 15.0
@export var forward_force: float = 0.0  # Optional forward push
@export var launch_sound: AudioStream
@export var cooldown: float = 0.5

@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _cooldown_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if launch_sound and audio:
		audio.stream = launch_sound


func _process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta


func _on_body_entered(body: Node) -> void:
	if _cooldown_timer > 0:
		return

	if body is CharacterBody3D:
		# Ignore Editor/Spectator (unless they are tagged as players, which they usually aren't)
		if not body.is_in_group("player"):
			return

		_launch(body)


func _launch(player: CharacterBody3D) -> void:
	_cooldown_timer = cooldown

	# Determine launch direction
	# Default is UP relative to pad
	var launch_dir: Vector3 = global_transform.basis.y

	# Apply forces directly to velocity
	# Note: This is client-side prediction friendly if player is authority
	# But best to do this on the authority of the player

	if player.has_method("apply_launch_impulse"):
		# If player has specific method, use it
		var impulse: Vector3 = launch_dir * launch_force
		if forward_force > 0:
			impulse += -global_transform.basis.z * forward_force
		player.apply_launch_impulse(impulse)

	elif "velocity" in player:
		# Fallback: simple velocity set
		# We add to Y but might want to set Y for consistent height
		var current_vel: Vector3 = player.velocity
		current_vel.y = launch_force

		# Add forward component
		if forward_force > 0:
			var fwd: Vector3 = -global_transform.basis.z
			current_vel.x += fwd.x * forward_force
			current_vel.z += fwd.z * forward_force

		player.velocity = current_vel

	# Play sound/effects
	_play_effects()


func _play_effects() -> void:
	if audio and audio.stream:
		audio.play()

	# Spawn particle burst
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	p_mat.emission_ring_radius = 0.5
	p_mat.emission_ring_inner_radius = 0.3
	p_mat.emission_ring_height = 0.1
	p_mat.emission_ring_axis = Vector3.UP
	p_mat.direction = Vector3.UP
	p_mat.spread = 30.0
	p_mat.initial_velocity_min = 3.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3(0, -2, 0)
	p_mat.scale_min = 0.1
	p_mat.scale_max = 0.2
	p_mat.color = Color(0.3, 0.8, 1.0)
	particles.process_material = p_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	particles.draw_pass_1 = sphere

	add_child(particles)

	# Cleanup after particles finish
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
