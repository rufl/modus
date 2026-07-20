class_name WeaponFeedbackSystem
extends GameComponent3D

signal muzzle_flash_spawned(position: Vector3)
signal shell_ejected(position: Vector3, velocity: Vector3)

@export_group("Muzzle Flash")
@export var muzzle_flash_enabled: bool = true
@export var muzzle_flash_particle_count: int = 20
@export var muzzle_flash_lifetime: float = 0.15
@export var muzzle_flash_spread: float = 15.0
@export var muzzle_flash_color: Color = Color.ORANGE
@export_group("Shell Ejection")
@export var shell_ejection_enabled: bool = true
@export var shell_ejection_velocity: float = 3.0
@export var shell_lifetime: float = 5.0
@export var shell_type: String = "bullet"  # bullet, shotgun, rifle
@export_group("Screen Shake")
@export var screen_shake_enabled: bool = true
@export var weapon_weight: String = "medium"  # light, medium, heavy

var _player: Node3D = null
var _screen_shake: Node = null


func _ready() -> void:
	# Find player reference
	await get_tree().process_frame
	_find_references()


func _find_references() -> void:
	# Walk up tree to find player
	var parent: Node = get_parent()
	while parent:
		if parent.is_in_group("player"):
			_player = parent as Node3D
			_screen_shake = parent.get_node_or_null("ScreenShakeSystem")
			break
		parent = parent.get_parent()


func trigger_fire_feedback(muzzle_position: Vector3 = Vector3.ZERO) -> void:
	var flash_pos := muzzle_position if muzzle_position != Vector3.ZERO else global_position

	if muzzle_flash_enabled:
		spawn_muzzle_flash(flash_pos)

	if shell_ejection_enabled:
		eject_shell()

	if screen_shake_enabled:
		add_fire_screen_shake()


func spawn_muzzle_flash(flash_position: Vector3 = Vector3.ZERO) -> void:
	var pos := flash_position if flash_position != Vector3.ZERO else global_position

	# Use pooled effects if available
	var gm: Node = get_node_or_null("/root/GameManager")
	var effects_service: Node = gm.get_core_system("effects") if gm else null
	if effects_service and effects_service.has_method("spawn_pooled_muzzle_flash"):
		effects_service.spawn_pooled_muzzle_flash(
			pos, muzzle_flash_color, 1.0, muzzle_flash_lifetime
		)
		# Also spawn particles
		if effects_service.has_method("spawn_pooled_particles"):
			effects_service.spawn_pooled_particles(
				pos,
				muzzle_flash_particle_count,
				muzzle_flash_lifetime,
				muzzle_flash_color,
				muzzle_flash_spread,
				2.0,
				5.0
			)
		muzzle_flash_spawned.emit(pos)
	else:
		# Fallback to old method
		call_deferred("_finish_spawn_muzzle_flash", pos)


func _finish_spawn_muzzle_flash(pos: Vector3) -> void:
	# Create flash light
	var flash_light := OmniLight3D.new()
	flash_light.light_color = muzzle_flash_color
	flash_light.light_energy = 3.0
	flash_light.omni_range = 4.0
	flash_light.omni_attenuation = 2.0

	var tree := get_tree()
	if not tree:
		return
	var root := tree.root
	if root:
		root.add_child(flash_light)
		flash_light.global_position = pos

	# Fade out quickly
	var tween := flash_light.create_tween()
	tween.tween_property(flash_light, "light_energy", 0.0, muzzle_flash_lifetime)
	tween.tween_callback(flash_light.queue_free)

	# Create particles
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = muzzle_flash_particle_count
	particles.lifetime = muzzle_flash_lifetime
	particles.explosiveness = 1.0

	# Particle material
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.05
	p_mat.direction = Vector3(0, 0, -1)
	p_mat.spread = muzzle_flash_spread
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3.ZERO
	p_mat.damping_min = 5.0
	p_mat.damping_max = 10.0
	# RETRO: Smaller, squared particles like blood spray
	p_mat.scale_min = 0.15
	p_mat.scale_max = 0.25

	# Color gradient
	var gradient := Gradient.new()
	gradient.add_point(0.0, muzzle_flash_color)
	gradient.add_point(0.5, muzzle_flash_color.lightened(0.3))
	gradient.add_point(
		1.0, Color(muzzle_flash_color.r, muzzle_flash_color.g, muzzle_flash_color.b, 0.0)
	)
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	p_mat.color_ramp = grad_tex

	particles.process_material = p_mat

	# Draw pass - RETRO: Smaller, squared particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)  # Smaller, squared like blood (was 0.1x0.1)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true  # CRITICAL: Use particle colors
	draw_mat.albedo_color = muzzle_flash_color
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = draw_mat
	particles.draw_pass_1 = quad

	add_child(particles)
	particles.position = Vector3(0, 0, -0.3)

	muzzle_flash_spawned.emit(pos)

	# Cleanup
	var timer := get_tree().create_timer(muzzle_flash_lifetime + 0.1)
	safe_connect(timer.timeout, particles.queue_free, CONNECT_ONE_SHOT)


func eject_shell() -> void:
	# Use pooled shell casing if available
	var gm: Node = get_node_or_null("/root/GameManager")
	var effects_service: Node = gm.get_core_system("effects") if gm else null
	if effects_service and effects_service.has_method("spawn_pooled_shell_casing"):
		# Calculate position and velocity
		var pos := global_position + global_transform.basis.x * 0.15
		pos += global_transform.basis.y * 0.05

		var eject_dir := global_transform.basis.x
		eject_dir += global_transform.basis.y * randf_range(0.3, 0.7)
		eject_dir += global_transform.basis.z * randf_range(-0.2, 0.2)
		eject_dir = eject_dir.normalized()

		var velocity := eject_dir * shell_ejection_velocity
		var angular_vel := Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))

		var shell: RigidBody3D = effects_service.spawn_pooled_shell_casing(
			pos, velocity, angular_vel, shell_type, shell_lifetime
		)
		if shell:
			shell_ejected.emit(pos, velocity)
	else:
		# Fallback to old method
		call_deferred("_finish_eject_shell")


func _finish_eject_shell() -> void:
	var shell := RigidBody3D.new()
	shell.name = "ShellCasing"

	# Create shell mesh based on type
	var mesh_instance := MeshInstance3D.new()
	var shell_mesh := CylinderMesh.new()

	match shell_type:
		"bullet", "pistol":
			shell_mesh.height = 0.015
			shell_mesh.top_radius = 0.004
			shell_mesh.bottom_radius = 0.004
		"rifle":
			shell_mesh.height = 0.025
			shell_mesh.top_radius = 0.004
			shell_mesh.bottom_radius = 0.004
		"shotgun":
			shell_mesh.height = 0.05
			shell_mesh.top_radius = 0.008
			shell_mesh.bottom_radius = 0.008
		_:
			shell_mesh.height = 0.02
			shell_mesh.top_radius = 0.005
			shell_mesh.bottom_radius = 0.005

	mesh_instance.mesh = shell_mesh

	# Brass material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.3
	mesh_instance.set_surface_override_material(0, mat)
	shell.add_child(mesh_instance)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = shell_mesh.height
	shape.radius = shell_mesh.top_radius
	collision.shape = shape
	shell.add_child(collision)

	# Physics setup
	shell.mass = 0.01
	shell.gravity_scale = 1.0
	shell.collision_layer = 0  # No collision layer (visual only)
	shell.collision_mask = CollisionLayers.MASK_SHELL

	# Add to scene
	var tree := get_tree()
	if not tree:
		return
	var root := tree.root
	if root:
		root.add_child(shell)

	# Position at ejection port (right side of weapon)
	shell.global_position = global_position + global_transform.basis.x * 0.15
	shell.global_position += global_transform.basis.y * 0.05

	# Eject direction (right and up with randomness)
	var eject_dir := global_transform.basis.x
	eject_dir += global_transform.basis.y * randf_range(0.3, 0.7)
	eject_dir += global_transform.basis.z * randf_range(-0.2, 0.2)
	eject_dir = eject_dir.normalized()

	shell.linear_velocity = eject_dir * shell_ejection_velocity
	shell.angular_velocity = Vector3(
		randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)
	)

	shell_ejected.emit(shell.global_position, shell.linear_velocity)

	# Cleanup after lifetime
	var timer := get_tree().create_timer(shell_lifetime)
	safe_connect(timer.timeout, shell.queue_free, CONNECT_ONE_SHOT)


func add_fire_screen_shake() -> void:
	if not _screen_shake:
		_find_references()
		if not _screen_shake:
			return

	if not _screen_shake.has_method("add_trauma"):
		return

	var trauma_amount: float = 0.3

	match weapon_weight:
		"light", "pistol", "smg":
			trauma_amount = 0.15
		"medium", "rifle", "shotgun":
			trauma_amount = 0.3
		"heavy", "rocket", "sniper":
			trauma_amount = 0.5
		_:
			trauma_amount = 0.3

	_screen_shake.add_trauma(trauma_amount, "weapon_fire")


func set_weapon_type(type: String) -> void:
	match type:
		"pistol":
			shell_type = "pistol"
			weapon_weight = "light"
			muzzle_flash_particle_count = 15
		"rifle", "machinegun":
			shell_type = "rifle"
			weapon_weight = "medium"
			muzzle_flash_particle_count = 20
		"shotgun":
			shell_type = "shotgun"
			weapon_weight = "medium"
			muzzle_flash_particle_count = 30
			muzzle_flash_spread = 25.0
		"rocket":
			shell_ejection_enabled = false
			weapon_weight = "heavy"
			muzzle_flash_particle_count = 40
			muzzle_flash_color = Color.ORANGE_RED
		"sniper":
			shell_type = "rifle"
			weapon_weight = "heavy"
			muzzle_flash_particle_count = 25
		_:
			shell_type = "bullet"
			weapon_weight = "medium"
