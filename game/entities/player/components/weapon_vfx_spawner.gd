extends GameComponent
class_name WeaponVFXSpawner

const CARTRIDGE_SCENE = preload("res://game/scenes/effects/shell_casing.tscn")

var _camera: Camera3D


func _log(message: String, category: String = "WeaponVFX") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func setup(camera: Camera3D) -> void:
	_camera = camera


# =============================================================================
# BLOOD EFFECTS
# =============================================================================

@rpc("any_peer", "call_local", "unreliable")
func spawn_enemy_blood(
	hit_pos: Vector3, hit_normal: Vector3, is_high_velocity: bool = false
) -> void:
	call_deferred("_finish_spawn_enemy_blood", hit_pos, hit_normal, is_high_velocity)


func _finish_spawn_enemy_blood(
	hit_pos: Vector3, hit_normal: Vector3, _is_high_velocity: bool = false
) -> void:
	# Try to find GameManager.get_core_system("effects") for blood spawning
	var managers: Array[Node] = get_tree().get_nodes_in_group("combat_feedback_manager")
	if managers.size() > 0:
		var manager: Node = managers[0]
		if manager.has_method("spawn_blood"):
			manager.spawn_blood(hit_pos, hit_normal)
		return

	# Fallback: create basic blood particle if no manager found
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.5
	particles.explosiveness = 0.8

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.05
	material.direction = hit_normal
	material.spread = 45.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -10, 0)
	material.color = Color(0.6, 0.0, 0.0)
	particles.process_material = material

	# Retro squared blood particles (DOOM/Quake style)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)  # Small cubes

	# Create blood material
	var blood_mat := StandardMaterial3D.new()
	blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blood_mat.vertex_color_use_as_albedo = true
	blood_mat.albedo_color = Color(0.6, 0.0, 0.0, 1.0)  # Dark red blood
	blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blood_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = blood_mat

	particles.draw_pass_1 = mesh

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(particles)
		particles.global_position = hit_pos
	else:
		particles.queue_free()
		return

	# Cleanup
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free, CONNECT_ONE_SHOT)


@rpc("any_peer", "call_local", "reliable")
func spawn_blood_splat(
	hit_pos: Vector3, hit_normal: Vector3, is_high_velocity: bool = false
) -> void:
	# Create blood splat decal for enemy hits
	var effects_service: Node = GameManager.get_core_system("effects")
	if effects_service and effects_service.has_method("spawn_blood_decal"):
		effects_service.spawn_blood_decal(hit_pos, hit_normal, is_high_velocity)
	else:
		# Fallback: Create simple red decal directly
		_spawn_blood_decal_local(hit_pos, hit_normal, is_high_velocity)


func _spawn_blood_decal_local(
	hit_pos: Vector3, hit_normal: Vector3, is_high_velocity: bool = false
) -> void:
	# Use Sprite3D for GLES3 compatibility (Decal nodes don't work)
	var decal: Sprite3D = Sprite3D.new()

	# Configure as decal-like sprite
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	# Random blood splat texture
	var blood_textures: Array[String] = [
		"res://game/art/textures/decals/blood_splat.png",
		"res://game/art/textures/decals/mid_blood_splat.png",
		"res://game/art/textures/decals/smol_blood_splat.png",
	]

	var texture_path: String = blood_textures[randi() % blood_textures.size()]
	decal.texture = load(texture_path)

	# Size based on velocity
	var size: float = 0.3 if is_high_velocity else 0.2
	decal.pixel_size = size / 64.0  # Convert to pixel size

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(decal)
		decal.global_position = hit_pos + hit_normal * 0.01
	else:
		decal.queue_free()
		return

	# Orient to surface
	if hit_normal != Vector3.ZERO:
		decal.look_at(hit_pos + hit_normal, Vector3.UP)

	# Random rotation for variety
	decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

	# Auto-cleanup after 30 seconds
	get_tree().create_timer(30.0).timeout.connect(decal.queue_free, CONNECT_ONE_SHOT)


# =============================================================================
# BULLET HOLES & DEBRIS
# =============================================================================

@rpc("any_peer", "call_local", "reliable")
func spawn_bullet_hole(hit_pos: Vector3, hit_normal: Vector3) -> void:
	call_deferred("_finish_spawn_bullet_hole", hit_pos, hit_normal)


func _finish_spawn_bullet_hole(hit_pos: Vector3, hit_normal: Vector3) -> void:
	# Use Sprite3D for GLES3 compatibility (Decal nodes don't work)
	var decal := Sprite3D.new()

	# Configure as decal-like sprite
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	# Create visible bullet hole texture
	decal.texture = _create_bullet_hole_texture()
	decal.modulate = Color(0.15, 0.15, 0.15, 1.0)  # Dark gray

	# Size
	decal.pixel_size = 0.4 / 64.0  # Convert world size to pixel size

	# Add to scene FIRST
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(decal)
	else:
		decal.queue_free()
		return

	# Position slightly off surface to avoid z-fighting
	decal.global_position = hit_pos + hit_normal * 0.01

	# Orient to surface - check for colinear vectors to avoid warnings
	if hit_normal != Vector3.ZERO:
		var up := Vector3.UP
		# If normal is parallel to up vector, use a different up vector
		if abs(hit_normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		decal.look_at(hit_pos + hit_normal, up)

	# Random rotation for variety
	decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

	_log("[WeaponVFX] Bullet hole decal spawned at " + " " + str(hit_pos), "Player")

	# Cleanup after 30 seconds
	get_tree().create_timer(30.0).timeout.connect(decal.queue_free, CONNECT_ONE_SHOT)


func _create_bullet_hole_texture() -> Texture2D:
	## Create simple black circle texture for bullet holes
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw black circle in center
	for x in range(64):
		for y in range(64):
			var dx: float = x - 32.0
			var dy: float = y - 32.0
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 24.0:  # Radius
				var alpha: float = 1.0 - (dist / 24.0)
				img.set_pixel(x, y, Color(0, 0, 0, alpha))

	return ImageTexture.create_from_image(img)


@rpc("any_peer", "call_local", "reliable")
func spawn_explosion_mark(hit_pos: Vector3, hit_normal: Vector3, radius: float = 1.5) -> void:
	## Spawn large explosion mark decal (for rockets, grenades, etc.)
	call_deferred("_finish_spawn_explosion_mark", hit_pos, hit_normal, radius)


func _finish_spawn_explosion_mark(hit_pos: Vector3, hit_normal: Vector3, radius: float) -> void:
	# Use Sprite3D for GLES3 compatibility (Decal nodes don't work)
	var decal := Sprite3D.new()

	# Configure as decal-like sprite
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	# Create explosion mark texture
	decal.texture = _create_explosion_mark_texture()
	decal.modulate = Color(0.0, 0.0, 0.0, 0.95)  # Very dark black

	# Large size for explosions
	decal.pixel_size = radius / 64.0

	# Position slightly off surface to avoid z-fighting
	decal.global_position = hit_pos + hit_normal * 0.02

	# Orient to surface
	if hit_normal != Vector3.ZERO:
		decal.look_at(hit_pos + hit_normal, Vector3.UP)

	# Random rotation for variety
	decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

	# Add to scene
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(decal)
		_log(
			(
				"[WeaponVFX] Explosion mark decal spawned at "
				+ str(hit_pos)
				+ " with radius "
				+ str(radius)
			),
			"Player"
		)
	else:
		decal.queue_free()
		return

	# Cleanup after 60 seconds (explosions last longer)
	get_tree().create_timer(60.0).timeout.connect(decal.queue_free, CONNECT_ONE_SHOT)


func _create_explosion_mark_texture() -> Texture2D:
	## Create burn mark texture for explosions (larger, more irregular than bullet holes)
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw irregular burn mark (multiple overlapping circles)
	var center_x: int = 64
	var center_y: int = 64

	# Main burn circle
	for x in range(128):
		for y in range(128):
			var dx: float = x - center_x
			var dy: float = y - center_y
			var dist: float = sqrt(dx * dx + dy * dy)

			# Main circle with soft edges
			if dist < 50.0:
				var alpha: float = 1.0 - (dist / 50.0)
				alpha = pow(alpha, 0.7)  # Softer falloff
				img.set_pixel(x, y, Color(0, 0, 0, alpha))

	# Add some noise/irregularity (secondary burn spots)
	for i in range(5):
		var offset_x: int = randi_range(-20, 20)
		var offset_y: int = randi_range(-20, 20)
		var sub_radius: float = randf_range(15.0, 25.0)

		for x in range(128):
			for y in range(128):
				var dx: float = x - (center_x + offset_x)
				var dy: float = y - (center_y + offset_y)
				var dist: float = sqrt(dx * dx + dy * dy)

				if dist < sub_radius:
					var alpha: float = (1.0 - (dist / sub_radius)) * 0.5
					var current: Color = img.get_pixel(x, y)
					img.set_pixel(x, y, Color(0, 0, 0, max(current.a, alpha)))

	return ImageTexture.create_from_image(img)


@rpc("any_peer", "call_local", "unreliable")
func spawn_wall_debris(hit_pos: Vector3, hit_normal: Vector3) -> void:
	## Spawn debris particles on wall impact (retro FPS style - SQUARE particles)
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 8
	particles.lifetime = 0.8
	particles.explosiveness = 0.7

	# Particle material - retro style
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.05
	mat.direction = hit_normal  # Spray away from wall
	mat.spread = 35.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, -15, 0)  # Fast fall
	mat.scale_min = 0.015
	mat.scale_max = 0.04

	# Gray dust/debris color
	mat.color = Color(0.6, 0.55, 0.5, 0.9)

	particles.process_material = mat

	# CRITICAL: Use BoxMesh for SQUARE debris chunks (not round)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.02, 0.02)  # Small cubes

	# Create material for debris (gray/brown dust color)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.albedo_color = Color(0.6, 0.55, 0.5, 0.9)  # Gray-brown dust
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat

	particles.draw_pass_1 = mesh

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(particles)
		particles.global_position = hit_pos + hit_normal * 0.1
	else:
		particles.queue_free()
		return

	# Orient away from wall
	if hit_normal != Vector3.UP and hit_normal != Vector3.DOWN:
		particles.look_at(hit_pos + hit_normal, Vector3.UP)
	else:
		particles.look_at(hit_pos + hit_normal, Vector3.FORWARD)

	# Cleanup
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free, CONNECT_ONE_SHOT)


# =============================================================================
# TRACERS & SMOKE
# =============================================================================

const RETRO_TRACER_SHADER = preload("res://game/art/shaders/retro_tracer.gdshader")

@rpc("any_peer", "call_local", "unreliable")
func spawn_muzzle_flash(muzzle_pos: Vector3 = Vector3.ZERO) -> void:
	## Spawn retro-style muzzle flash (light + particles)

	# Fallback to camera relative if no pos provided
	if muzzle_pos == Vector3.ZERO:
		if _camera:
			var gun_forward := -_camera.global_transform.basis.z
			muzzle_pos = _camera.global_position + gun_forward * 0.5
		else:
			return

	# Use pooled muzzle flash if available
	var effects_service: Node = GameManager.get_core_system("effects") if GameManager else null
	if effects_service and effects_service.has_method("spawn_pooled_muzzle_flash"):
		effects_service.spawn_pooled_muzzle_flash(muzzle_pos, Color.ORANGE, 1.0, 0.15)
		# Also spawn particles
		if effects_service.has_method("spawn_pooled_particles"):
			effects_service.spawn_pooled_particles(
				muzzle_pos, 20, 0.15, Color.ORANGE, 15.0, 2.0, 5.0
			)
		return

	# Fallback: Create flash light manually
	var flash_light := OmniLight3D.new()
	flash_light.light_color = Color.ORANGE
	flash_light.light_energy = 3.0
	flash_light.omni_range = 4.0
	flash_light.omni_attenuation = 2.0

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(flash_light)
		flash_light.global_position = muzzle_pos
	else:
		flash_light.queue_free()
		return

	# Fade out quickly
	var tween := flash_light.create_tween()
	tween.tween_property(flash_light, "light_energy", 0.0, 0.15)
	tween.tween_callback(flash_light.queue_free)

	# 2. Create flash particles (retro style)
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.15
	particles.explosiveness = 1.0

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.05
	p_mat.direction = -_camera.global_transform.basis.z if _camera else Vector3.FORWARD
	p_mat.spread = 15.0
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3.ZERO
	p_mat.scale_min = 0.03
	p_mat.scale_max = 0.08

	# Orange/yellow flash color
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.ORANGE)
	gradient.add_point(0.5, Color.YELLOW.lightened(0.3))
	gradient.add_point(1.0, Color(1.0, 0.5, 0.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	p_mat.color_ramp = grad_tex

	particles.process_material = p_mat

	# Retro squared particles
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.albedo_color = Color.ORANGE
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat

	particles.draw_pass_1 = mesh

	scene_root.add_child(particles)
	particles.global_position = muzzle_pos

	# Cleanup
	get_tree().create_timer(0.3).timeout.connect(particles.queue_free, CONNECT_ONE_SHOT)


@rpc("any_peer", "call_local", "unreliable")
func spawn_bullet_tracer(
	from_pos: Vector3,
	to_pos: Vector3,
	color: Color = Color(1.0, 0.8, 0.4, 1.0),
	width: float = 0.05
) -> void:
	## Spawn thick cylinder tracer (visible at distance)
	_log(
		"[WeaponVFX] spawn_bullet_tracer called: from=" + str(from_pos) + " to=" + str(to_pos),
		"Player"
	)

	var dist: float = from_pos.distance_to(to_pos)
	if dist < 0.1:
		_log("[WeaponVFX] Tracer distance too short: " + " " + str(dist), "Player")
		return

	# Create thick cylinder for tracer (much more visible than thin line)
	var tracer := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = width * 0.5  # Use width parameter
	cylinder.bottom_radius = width * 0.5
	cylinder.height = dist
	tracer.mesh = cylinder
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Bright unshaded material with high emission
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0  # Very bright
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	# Z-Test must be ON to be occluded by walls,
	# allowing OFF might be better for visibility but weirder

	tracer.material_override = mat

	# Add to scene FIRST (required for global_position and look_at to work)
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if not scene_root:
		tracer.queue_free()
		_log("[WeaponVFX] No scene root found", "Player")
		return

	scene_root.add_child(tracer)

	# NOW set position and orientation (after adding to tree)
	var midpoint: Vector3 = (from_pos + to_pos) / 2.0
	tracer.global_position = midpoint

	# Orient cylinder along the shot direction
	tracer.look_at(to_pos, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)  # Align cylinder with direction

	_log(
		"[WeaponVFX] Tracer cylinder created at " + str(midpoint) + " with length " + str(dist),
		"Player"
	)

	# Fade out quickly
	var fade_time: float = 0.8  # Increased from 0.5 for better visibility

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, fade_time)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, fade_time)

	# Cleanup
	tween.tween_callback(tracer.queue_free)


func spawn_muzzle_smoke(muzzle_pos: Vector3 = Vector3.ZERO) -> void:
	## Spawn retro-style muzzle smoke puff (Quake 2/Dusk inspired)

	# Fallback to camera relative if no pos provided (and camera exists)
	if muzzle_pos == Vector3.ZERO:
		if _camera:
			var gun_forward := -_camera.global_transform.basis.z
			muzzle_pos = _camera.global_position + gun_forward * 0.5
		else:
			return

	# Get direction from camera if available (for smoke drift), otherwise usage forward
	var smoke_dir := Vector3.FORWARD
	if _camera:
		smoke_dir = -_camera.global_transform.basis.z

	var smoke := GPUParticles3D.new()
	smoke.one_shot = true
	smoke.emitting = true
	smoke.amount = 4  # Small puff
	smoke.lifetime = 0.4
	smoke.explosiveness = 0.9

	# Retro smoke material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.03

	# Use gun forward direction
	mat.direction = smoke_dir
	mat.spread = 15.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3.ZERO  # Smoke floats

	# Scale up quickly (classic puff)
	mat.scale_min = 0.03
	mat.scale_max = 0.08

	# Gray smoke color (slight fade)
	var smoke_color := Color(0.5, 0.5, 0.5, 0.6)
	mat.color = smoke_color

	# Retro squared smoke particles (Quake 2/Dusk style)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)  # Slightly larger cubes for smoke

	# Create smoke material
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.albedo_color = smoke_color
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = smoke_mat

	smoke.draw_pass_1 = mesh

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(smoke)
		smoke.global_position = muzzle_pos + smoke_dir * 0.2  # Slightly forward
	else:
		smoke.queue_free()
		return

	# Cleanup
	get_tree().create_timer(0.8).timeout.connect(smoke.queue_free, CONNECT_ONE_SHOT)


# =============================================================================
# CHAIN LIGHTNING EFFECT
# =============================================================================

@rpc("authority", "call_local", "unreliable")
func spawn_chain_effect(from_pos: Vector3, to_pos: Vector3) -> void:
	call_deferred("_finish_spawn_chain_effect", from_pos, to_pos)


func _finish_spawn_chain_effect(from_pos: Vector3, to_pos: Vector3) -> void:
	var line: MeshInstance3D = MeshInstance3D.new()
	var im: ImmediateMesh = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from_pos)
	im.surface_add_vertex(to_pos)
	im.surface_end()
	line.mesh = im

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.DEEP_SKY_BLUE
	mat.emission_enabled = true
	mat.emission = Color.DEEP_SKY_BLUE
	mat.emission_energy_multiplier = 3.0
	line.material_override = mat

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(line)

	# Clean up after brief display
	get_tree().create_timer(0.15).timeout.connect(line.queue_free, CONNECT_ONE_SHOT)


# =============================================================================
# CARTRIDGE EJECTION
# =============================================================================

@rpc("any_peer", "call_local", "unreliable")
func spawn_cartridge(
	start_pos: Vector3, direction: Vector3, scale: float = 1.0, scene_path: String = ""
) -> void:
	_log(
		"[WeaponVFX] spawn_cartridge called at %s with scene: %s" % [start_pos, scene_path],
		"Player"
	)

	# Determine which scene to use
	var cartridge_scene: PackedScene = null
	if scene_path != "" and ResourceLoader.exists(scene_path):
		cartridge_scene = load(scene_path)
		_log("[WeaponVFX] Loaded custom cartridge scene: %s" % scene_path, "Player")
	elif CARTRIDGE_SCENE:
		cartridge_scene = CARTRIDGE_SCENE
		_log("[WeaponVFX] Using default CARTRIDGE_SCENE", "Player")

	if not cartridge_scene:
		_log("[WeaponVFX] No cartridge scene available!", "Player")
		return

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if not scene_root:
		_log("[WeaponVFX] No scene root found!", "Player")
		return

	var cartridge: Node3D = cartridge_scene.instantiate()
	scene_root.add_child(cartridge)
	cartridge.global_position = start_pos

	_log("[WeaponVFX] Cartridge spawned at %s" % cartridge.global_position, "Player")

	# Random initial rotation
	cartridge.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

	if abs(scale - 1.0) > 0.01:
		cartridge.scale = Vector3.ONE * scale

	# Eject force
	if cartridge is RigidBody3D:
		var eject_dir := (direction + Vector3(0, randf_range(0.2, 0.5), 0)).normalized()
		var impulse_force := randf_range(2.0, 4.0)
		cartridge.apply_impulse(eject_dir * impulse_force)
		cartridge.apply_torque_impulse(Vector3.ONE * randf_range(-10, 10))
		_log("[WeaponVFX] Applied impulse: %s with force %s" % [eject_dir, impulse_force], "Player")
	else:
		_log("[WeaponVFX] Cartridge is not a RigidBody3D!", "Player")
