extends Node3D

@export var size_scale: float = 1.0
@export var intensity: float = 1.0
@export var power: float = 120.0
@export var damage_splash: int = 100
@export var splash_radius: float = 5.0
@export var damage_falloff: bool = true
@export var damage_type: int = DamageInfo.DamageType.EXPLOSION

static var _cached_noise_tex: NoiseTexture2D = null
static var _cached_scorch_tex: ImageTexture = null

var damage_source_id: int = 0
var explosion_scene_owner: Node3D

var _visual_only: bool = false
var _hit_bodies: Array[Node] = []


func set_visual_only(val: bool) -> void:
	_visual_only = val


func explode(
	global_pos: Vector3, dir: Vector3 = Vector3.ZERO, power_override: float = -1.0
) -> void:
	global_position = global_pos

	# Orient explosion
	if dir != Vector3.ZERO:
		var target := global_pos + dir
		var up := Vector3.UP
		if abs(dir.normalized().dot(up)) > 0.95:
			up = Vector3.RIGHT
		look_at(target, up)
	else:
		# Looking UP with RIGHT as local-up is safe
		look_at(global_pos + Vector3.UP, Vector3.RIGHT)

	if power_override > 0:
		power = power_override

	scale_all_children(size_scale * intensity)
	emit_all_particles()
	play_layered_sounds()
	tween_light_pulse()
	spawn_scorch_mark(global_pos)
	apply_splash_physics_and_damage()

	# Auto cleanup
	get_tree().create_timer(2.0).timeout.connect(_on_finish, CONNECT_ONE_SHOT)


func _on_finish() -> void:
	# Quake projectiles and explosions are often pooled
	var pool_service: Node = GameManager.get_core_system("pools")
	if pool_service and pool_service.has_method("return_instance") and has_meta("pool_id"):
		pool_service.return_instance(self)
	else:
		queue_free()


func reset() -> void:
	_hit_bodies.clear()
	_visual_only = false
	damage_source_id = 0
	explosion_scene_owner = null

	# Stop all particles
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = false

	# Reset light
	var light: OmniLight3D = get_node_or_null("OmniLight3D")
	if light:
		light.light_energy = 0.0


func scale_all_children(f: float) -> void:
	for child in get_children():
		if child is GPUParticles3D or child is OmniLight3D:
			child.scale = Vector3.ONE * f


func emit_all_particles() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			# GPUParticles3D uses restart() to reset and re-emit
			child.restart()


func play_layered_sounds() -> void:
	var audio: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
	if audio:
		# Generate explosion sound if no stream assigned
		if not audio.stream:
			if GameManager and GameManager.get_core_system("audio"):
				var stream: AudioStream = GameManager.get_core_system("audio").get_event_stream(
					"explosion"
				)
				if stream:
					audio.stream = stream
				else:
					# Fallback to generated sound
					audio.stream = SoundGenerator.generate_explosion_sound()
		audio.play()


func _ready() -> void:
	# Ensure materials have noise texture for "twirling" effect
	_setup_particle_materials()


func _setup_particle_materials() -> void:
	if not _cached_noise_tex:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM

		_cached_noise_tex = NoiseTexture2D.new()
		_cached_noise_tex.noise = noise

		# For NoiseTexture2D, usually we just assign it.

	for child in get_children():
		if child is GPUParticles3D:
			var mat: ShaderMaterial = child.process_material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("noise_tex", _cached_noise_tex)


func spawn_scorch_mark(_pos: Vector3) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	# Raycast along local -Z (Normal) to +Z (Into Wall)
	# explode() orients -Z to look at 'dir' (normal).
	# So -Z is sticking OUT of wall. +Z is sticking INTO wall.
	# Cast from Out -> In.
	var start: Vector3 = to_global(Vector3(0, 0, -1.0))
	var end: Vector3 = to_global(Vector3(0, 0, 1.0))

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = 1  # World

	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		# Use Sprite3D for GLES3 compatibility (Decal nodes don't work)
		var decal: Sprite3D = Sprite3D.new()

		# Configure as decal-like sprite
		decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		decal.shaded = false
		decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		decal.no_depth_test = false
		decal.layers = 0xFFFFF

		var tree := get_tree()
		var scene_root: Node = tree.current_scene if tree else null
		if not scene_root and tree:
			scene_root = tree.root

		if scene_root:
			scene_root.add_child(decal)
			decal.global_position = result.position + result.normal * 0.02
		else:
			decal.queue_free()
			return

		# Align to normal
		if result.normal != Vector3.ZERO:
			# Check if normal is parallel to up vector to avoid colinear warning
			var up := Vector3.UP
			if abs(result.normal.dot(up)) > 0.99:
				up = Vector3.RIGHT
			decal.look_at(result.position + result.normal, up)

		# Random rotation for variety
		decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

		# Use cached texture
		if not _cached_scorch_tex:
			_cached_scorch_tex = _create_procedural_scorch()

		decal.texture = _cached_scorch_tex
		decal.modulate = Color(0.1, 0.1, 0.1, 0.8)  # Dark scorch

		# Scale based on explosion size
		var s: float = size_scale * 3.0
		decal.pixel_size = s / 64.0  # Convert to pixel size

		# Fade out
		var tween: Tween = create_tween()
		tween.tween_interval(10.0)
		tween.tween_property(decal, "modulate:a", 0.0, 5.0)
		tween.tween_callback(decal.queue_free)


func _create_procedural_scorch() -> ImageTexture:
	var size: int = 128
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var max_radius: float = size / 2.0

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 12345  # Fixed seed for cache consistency
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.05

	for y: int in size:
		for x: int in size:
			var pos: Vector2 = Vector2(x, y)
			var dist: float = pos.distance_to(center)
			var normalized_dist: float = dist / max_radius

			# Irregular scorch with noise
			var noise_val: float = noise.get_noise_2d(x, y) * 0.3
			var alpha: float = 1.0 - normalized_dist + noise_val
			alpha = clamp(alpha, 0.0, 1.0)
			alpha = pow(alpha, 2.0)

			var color: Color = Color(0.05, 0.05, 0.05, alpha)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


func tween_light_pulse() -> void:
	var light: OmniLight3D = get_node_or_null("OmniLight3D")
	if not light:
		return

	var tween: Tween = create_tween()
	tween.tween_method(func(v: float) -> void: light.light_energy = v, 0.0, 15.0 * intensity, 0.1)
	tween.tween_method(func(v: float) -> void: light.light_energy = v, 15.0 * intensity, 0.0, 0.4)


func apply_splash_physics_and_damage() -> void:
	var area: Area3D = get_node_or_null("Area3D")
	if not area:
		return

	# We use a one-frame physics check via the Area3D
	# By connecting, waiting a frame, then disconnecting
	if not area.body_entered.is_connected(_on_splash_hit):
		area.body_entered.connect(_on_splash_hit)

	# Enable monitoring for a frame
	area.monitoring = true

	if not is_inside_tree():
		return
	await get_tree().physics_frame

	if not is_inside_tree():
		return
	await get_tree().physics_frame  # Wait 2 frames to be safe with physics server

	if is_instance_valid(area):
		area.monitoring = false
		if area.body_entered.is_connected(_on_splash_hit):
			area.body_entered.disconnect(_on_splash_hit)


func _on_splash_hit(body: Node3D) -> void:
	# Quake-style: Allow self-damage (for rocket jumping) but reduce damage by 50%
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)

	var is_self_damage: bool = body == explosion_scene_owner
	var self_damage_multiplier: float = 0.5 if is_self_damage else 1.0

	var dist: float = global_position.distance_to(body.global_position)
	if dist > splash_radius:
		return

	# Physics Impulse - FULL knockback even for self (essential for rocket jump)
	if body is RigidBody3D:
		var force: float = power / (dist * dist + 1.0)
		force = min(force, 200.0)  # Clamp to prevent physics glitches
		var dir: Vector3 = (body.global_position - global_position).normalized()
		body.apply_central_impulse(dir * force)
	elif body is CharacterBody3D:
		# Apply knockback for rocket/grenade jumping
		var force: float = power / (dist + 1.0)  # Linear falloff for player feel
		force = min(force, 200.0)
		var dir_impulse: Vector3 = (body.global_position - global_position).normalized()

		# Add upward bias for vertical boost (Quake rocket jump feel)
		dir_impulse.y = max(dir_impulse.y, 0.3)
		dir_impulse = dir_impulse.normalized()

		if body.has_method("apply_knockback"):
			body.apply_knockback(dir_impulse * force * 0.15)
		elif "velocity" in body:
			body.velocity += dir_impulse * force * 0.15

	# Damage - reduced for self
	var final_damage: float = float(damage_splash) * self_damage_multiplier
	if damage_falloff:
		final_damage = damage_splash * self_damage_multiplier * (1.0 - dist / splash_radius)

	if final_damage <= 0:
		return

	# Centralized Damage via CombatService
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.combat:
		var owner_node: Node = null
		if is_instance_valid(explosion_scene_owner):
			owner_node = explosion_scene_owner

		gs.combat.apply_damage(
			body, final_damage, owner_node, damage_type, null, false, damage_source_id
		)
	else:
		# Fallback if service missing (shouldn't happen now)
		if body.has_method("take_damage"):
			var info: DamageInfo = DamageInfo.new()
			info.base_amount = final_damage
			info.source = explosion_scene_owner
			if damage_source_id != 0:
				info.source_id = damage_source_id
			elif is_instance_valid(explosion_scene_owner):
				info.source_id = explosion_scene_owner.get_instance_id()
			else:
				info.source_id = 0
			info.damage_type = damage_type as DamageInfo.DamageType
			# GameplayService.combat.apply_damage creates a NEW DamageInfo. It loses KB direction.
			# We might want to extend GameplayService.combat.apply_damage later.
			# For now, let's stick to direct take_damage IF we need custom params like KB direction,
			# OR update GameplayService.combat.
			# Using CombatService is safer for "dealing damage" debugging.
			# Let's use the local logic but wrapped safely.

			info.knockback_direction = (body.global_position - global_position).normalized()
			body.take_damage(info)
		elif body.has_node("HealthComponent"):
			var health: Node = body.get_node("HealthComponent")
			var info: DamageInfo = DamageInfo.new()
			info.base_amount = final_damage
			info.source = explosion_scene_owner
			if is_instance_valid(explosion_scene_owner):
				info.source_id = explosion_scene_owner.get_instance_id()
			else:
				info.source_id = 0
			info.damage_type = damage_type as DamageInfo.DamageType
			health.take_damage(info)


func set_size_scale(v: float) -> void:
	size_scale = v
	if is_inside_tree():
		scale_all_children(size_scale * intensity)


func set_intensity(v: float) -> void:
	intensity = v
	if is_inside_tree():
		scale_all_children(size_scale * intensity)
