class_name EffectPoolManager
extends Node
## Object pooling system for frequently spawned effects (muzzle flashes, particles, lights)
## Reduces GC pressure and improves performance for high-frequency effects

## Signal emitted when pool statistics are updated (currently unused but available for monitoring)
@warning_ignore("unused_signal")
signal pool_stats_updated(stats: Dictionary)

## Pool configuration
@export var muzzle_flash_pool_size: int = 20
@export var particle_pool_size: int = 50
@export var light_pool_size: int = 30
@export var shell_casing_pool_size: int = 100
@export var enable_stats: bool = false

const MAX_POOL_MULTIPLIER: int = 2
var _overflow_warning_emitted: Dictionary = {}


func _pool_capacity(configured_size: int) -> int:
	return maxi(configured_size, 0) * MAX_POOL_MULTIPLIER


func _can_create(configured_size: int, pool_size: int, active_size: int) -> bool:
	return pool_size + active_size < _pool_capacity(configured_size)


func _warn_pool_exhausted(pool_name: String) -> void:
	if _overflow_warning_emitted.has(pool_name):
		return
	_overflow_warning_emitted[pool_name] = true
	push_warning("[Effects] %s pool exhausted; preserving active effects" % pool_name)


func _deactivate_node(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)


func _activate_node(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_process(true)
	node.set_physics_process(true)

func _trim_or_pool(node: Node, pool: Array, configured_size: int) -> void:
	# Keep the configured warm pool; trim overflow on return so active effects
	# are never recycled or displaced to make room.
	if pool.size() >= maxi(configured_size, 0):
		node.queue_free()
		return
	pool.append(node)

## Pools
var _muzzle_flash_pool: Array[Node3D] = []
var _particle_pool: Array[GPUParticles3D] = []
var _light_pool: Array[OmniLight3D] = []
var _shell_casing_pool: Array[RigidBody3D] = []

## Active tracking
var _active_muzzle_flashes: Array[Node3D] = []
var _active_particles: Array[GPUParticles3D] = []
var _active_lights: Array[OmniLight3D] = []
var _active_shells: Array[RigidBody3D] = []

## Stats
var _stats := {
	"muzzle_flash_spawns": 0,
	"muzzle_flash_reuses": 0,
	"particle_spawns": 0,
	"particle_reuses": 0,
	"light_spawns": 0,
	"light_reuses": 0,
	"shell_spawns": 0,
	"shell_reuses": 0,
}


func _ready() -> void:
	_prewarm_pools()


func _prewarm_pools() -> void:
	## Pre-create pool objects to avoid runtime allocation.
	for i in range(maxi(muzzle_flash_pool_size, 0)):
		var flash := _create_muzzle_flash_instance()
		add_child(flash)
		flash.visible = false
		_deactivate_node(flash)
		_muzzle_flash_pool.append(flash)

	for i in range(maxi(particle_pool_size, 0)):
		var particles := _create_particle_instance()
		add_child(particles)
		particles.emitting = false
		_deactivate_node(particles)
		_particle_pool.append(particles)

	for i in range(maxi(light_pool_size, 0)):
		var light := _create_light_instance()
		add_child(light)
		light.visible = false
		_deactivate_node(light)
		_light_pool.append(light)

	for i in range(maxi(shell_casing_pool_size, 0)):
		var shell := _create_shell_instance()
		add_child(shell)
		_deactivate_shell(shell)
		_shell_casing_pool.append(shell)


func _create_muzzle_flash_instance() -> Node3D:
	## Create a reusable muzzle flash node
	var container := Node3D.new()
	container.name = "MuzzleFlash"

	# Light
	var light := OmniLight3D.new()
	light.name = "Light"
	light.omni_range = 4.0
	light.omni_attenuation = 2.0
	container.add_child(light)

	# Mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	mesh_instance.mesh = quad
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	container.add_child(mesh_instance)

	return container


func _create_particle_instance() -> GPUParticles3D:
	## Create a reusable particle system
	var particles := GPUParticles3D.new()
	particles.name = "PooledParticles"
	particles.one_shot = true
	particles.emitting = false
	return particles


func _create_light_instance() -> OmniLight3D:
	## Create a reusable light
	var light := OmniLight3D.new()
	light.name = "PooledLight"
	light.visible = false
	return light


func _create_shell_instance() -> RigidBody3D:
	## Create a reusable shell casing
	var shell := RigidBody3D.new()
	shell.name = "PooledShell"
	shell.mass = 0.01
	shell.gravity_scale = 1.0
	shell.collision_layer = 0
	shell.collision_mask = 0  # No collision for pooled shells

	# Mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	shell.add_child(mesh_instance)

	# Collision
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.height = 0.02
	shape.radius = 0.005
	collision.shape = shape
	shell.add_child(collision)

	return shell


func _deactivate_shell(shell: RigidBody3D) -> void:
	shell.visible = false
	shell.freeze = true
	shell.sleeping = true
	shell.set_physics_process(false)
	shell.process_mode = Node.PROCESS_MODE_DISABLED
	var collision := shell.get_node_or_null("Collision") as CollisionShape3D
	if collision:
		collision.disabled = true


## Muzzle Flash API
func spawn_muzzle_flash(
	pos: Vector3, color: Color = Color.ORANGE, scale: float = 1.0, lifetime: float = 0.05
) -> Node3D:
	var flash: Node3D = null

	if _muzzle_flash_pool.size() > 0:
		flash = _muzzle_flash_pool.pop_back()
		if enable_stats:
			_stats.muzzle_flash_reuses += 1
	elif _can_create(
		muzzle_flash_pool_size, _muzzle_flash_pool.size(), _active_muzzle_flashes.size()
	):
		flash = _create_muzzle_flash_instance()
		add_child(flash)
		if enable_stats:
			_stats.muzzle_flash_spawns += 1
	else:
		_warn_pool_exhausted("muzzle flash")
		return null

	_activate_node(flash)
	flash.visible = true

	var light := flash.get_node("Light") as OmniLight3D
	light.light_color = color
	light.light_energy = 3.0 * scale
	light.omni_range = 4.0 * scale

	var mesh_instance := flash.get_node("Mesh") as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.set_surface_override_material(0, mat)

	_active_muzzle_flashes.append(flash)

	# Auto-return to pool
	var tween := flash.create_tween()
	tween.tween_property(light, "light_energy", 0.0, lifetime)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, lifetime)
	tween.tween_callback(func() -> void: _return_muzzle_flash(flash))

	return flash


func _return_muzzle_flash(flash: Node3D) -> void:
	if not is_instance_valid(flash):
		return

	# Clean up materials to prevent leaks
	var mesh_instance := flash.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)

	_deactivate_node(flash)
	_active_muzzle_flashes.erase(flash)
	_trim_or_pool(flash, _muzzle_flash_pool, muzzle_flash_pool_size)


## Particle API
func spawn_particles(
	pos: Vector3,
	amount: int = 20,
	lifetime: float = 0.15,
	color: Color = Color.ORANGE,
	spread: float = 15.0,
	velocity_min: float = 2.0,
	velocity_max: float = 5.0
) -> GPUParticles3D:
	var particles: GPUParticles3D = null

	if _particle_pool.size() > 0:
		particles = _particle_pool.pop_back()
		if enable_stats:
			_stats.particle_reuses += 1
	elif _can_create(particle_pool_size, _particle_pool.size(), _active_particles.size()):
		particles = _create_particle_instance()
		add_child(particles)
		if enable_stats:
			_stats.particle_spawns += 1
	else:
		_warn_pool_exhausted("particle")
		return null

	_activate_node(particles)

	# Configure
	particles.global_position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0

	# Material
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.05
	p_mat.direction = Vector3(0, 0, -1)
	p_mat.spread = spread
	p_mat.initial_velocity_min = velocity_min
	p_mat.initial_velocity_max = velocity_max
	p_mat.gravity = Vector3.ZERO
	p_mat.damping_min = 5.0
	p_mat.damping_max = 10.0
	p_mat.scale_min = 0.15
	p_mat.scale_max = 0.25

	# Color
	var gradient := Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.5, color.lightened(0.3))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	p_mat.color_ramp = grad_tex

	particles.process_material = p_mat

	# Draw pass
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.albedo_color = color
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = draw_mat
	particles.draw_pass_1 = quad

	particles.emitting = true
	_active_particles.append(particles)

	# Auto-return to pool
	get_tree().create_timer(lifetime + 0.1).timeout.connect(
		func() -> void: _return_particles(particles), CONNECT_ONE_SHOT
	)

	return particles


func _return_particles(particles: GPUParticles3D) -> void:
	if not is_instance_valid(particles):
		return

	# Clean up materials and resources to prevent leaks
	particles.process_material = null
	particles.draw_pass_1 = null
	particles.emitting = false
	_deactivate_node(particles)
	_active_particles.erase(particles)
	_trim_or_pool(particles, _particle_pool, particle_pool_size)


## Light API
func spawn_light(
	pos: Vector3,
	color: Color = Color.ORANGE,
	energy: float = 3.0,
	light_range: float = 4.0,
	lifetime: float = 0.05
) -> OmniLight3D:
	var light: OmniLight3D = null

	if _light_pool.size() > 0:
		light = _light_pool.pop_back()
		if enable_stats:
			_stats.light_reuses += 1
	elif _can_create(light_pool_size, _light_pool.size(), _active_lights.size()):
		light = _create_light_instance()
		add_child(light)
		if enable_stats:
			_stats.light_spawns += 1
	else:
		_warn_pool_exhausted("light")
		return null

	_activate_node(light)

	# Configure
	light.global_position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 2.0
	light.visible = true

	_active_lights.append(light)

	# Auto-return to pool
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, lifetime)
	tween.tween_callback(func() -> void: _return_light(light))

	return light

func _return_light(light: OmniLight3D) -> void:
	if not is_instance_valid(light):
		return

	light.visible = false
	_deactivate_node(light)
	_active_lights.erase(light)
	_trim_or_pool(light, _light_pool, light_pool_size)


## Shell Casing API
func spawn_shell_casing(
	pos: Vector3,
	velocity: Vector3,
	angular_velocity: Vector3,
	shell_type: String = "bullet",
	lifetime: float = 5.0
) -> RigidBody3D:
	var shell: RigidBody3D = null

	if _shell_casing_pool.size() > 0:
		shell = _shell_casing_pool.pop_back()
		if enable_stats:
			_stats.shell_reuses += 1
	elif _can_create(
		shell_casing_pool_size, _shell_casing_pool.size(), _active_shells.size()
	):
		shell = _create_shell_instance()
		add_child(shell)
		if enable_stats:
			_stats.shell_spawns += 1
	else:
		_warn_pool_exhausted("shell casing")
		return null

	# Configure mesh based on type
	var mesh_instance := shell.get_node("Mesh") as MeshInstance3D
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

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.3
	shell_mesh.material = mat
	mesh_instance.mesh = shell_mesh

	# Update collision shape
	var collision := shell.get_node("Collision") as CollisionShape3D
	var shape := collision.shape as CylinderShape3D
	shape.height = shell_mesh.height
	shape.radius = shell_mesh.top_radius
	_activate_node(shell)
	shell.freeze = false
	shell.sleeping = false
	collision.disabled = false

	# Position and physics
	shell.global_position = pos
	shell.linear_velocity = velocity
	shell.angular_velocity = angular_velocity
	shell.visible = true

	_active_shells.append(shell)

	# Auto-return to pool
	get_tree().create_timer(lifetime).timeout.connect(
		func() -> void: _return_shell(shell), CONNECT_ONE_SHOT
	)

	return shell


func _return_shell(shell: RigidBody3D) -> void:
	if not is_instance_valid(shell):
		return

	# Clean up mesh materials to prevent leaks
	var mesh_instance := shell.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance:
		mesh_instance.mesh = null

	_deactivate_shell(shell)
	shell.linear_velocity = Vector3.ZERO
	shell.angular_velocity = Vector3.ZERO
	_active_shells.erase(shell)
	_trim_or_pool(shell, _shell_casing_pool, shell_casing_pool_size)


## Stats API
func get_stats() -> Dictionary:
	var current_stats := _stats.duplicate()
	current_stats["muzzle_flash_pool_size"] = _muzzle_flash_pool.size()
	current_stats["muzzle_flash_active"] = _active_muzzle_flashes.size()
	current_stats["particle_pool_size"] = _particle_pool.size()
	current_stats["particle_active"] = _active_particles.size()
	current_stats["light_pool_size"] = _light_pool.size()
	current_stats["light_active"] = _active_lights.size()
	current_stats["shell_pool_size"] = _shell_casing_pool.size()
	current_stats["shell_active"] = _active_shells.size()
	return current_stats


func reset_stats() -> void:
	for key: String in _stats:
		_stats[key] = 0


func _exit_tree() -> void:
	# Clean up all pools - use free() for immediate cleanup to prevent leaks
	for flash in _muzzle_flash_pool:
		if is_instance_valid(flash):
			# Free children first to release their resources
			for child in flash.get_children():
				if is_instance_valid(child):
					child.free()
			flash.free()
	for flash in _active_muzzle_flashes:
		if is_instance_valid(flash):
			for child in flash.get_children():
				if is_instance_valid(child):
					child.free()
			flash.free()

	for particles in _particle_pool:
		if is_instance_valid(particles):
			# Clear process material and draw passes to free resources
			particles.process_material = null
			particles.draw_pass_1 = null
			particles.free()
	for particles in _active_particles:
		if is_instance_valid(particles):
			particles.process_material = null
			particles.draw_pass_1 = null
			particles.free()

	for light in _light_pool:
		if is_instance_valid(light):
			light.free()
	for light in _active_lights:
		if is_instance_valid(light):
			light.free()

	for shell in _shell_casing_pool:
		if is_instance_valid(shell):
			# Free children first
			for child in shell.get_children():
				if is_instance_valid(child):
					child.free()
			shell.free()
	for shell in _active_shells:
		if is_instance_valid(shell):
			for child in shell.get_children():
				if is_instance_valid(child):
					child.free()
			shell.free()

	_muzzle_flash_pool.clear()
	_active_muzzle_flashes.clear()
	_particle_pool.clear()
	_active_particles.clear()
	_light_pool.clear()
	_active_lights.clear()
	_shell_casing_pool.clear()
	_active_shells.clear()
