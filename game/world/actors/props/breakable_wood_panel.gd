@tool
extends BreakableProp
class_name BreakableWoodPanel

## Half-Life 2 style breakable wood panels with splinters and realistic physics

@export_group("Wood Panel Settings")
@export var wood_type: String = "plank"  # plank, crate, door, pallet
@export var panel_thickness: float = 0.05
@export var splinter_count: int = 8
@export var splinter_size_min: float = 0.15
@export var splinter_size_max: float = 0.4
@export var break_force: float = 6.0
@export var wood_color: Color = Color(0.6, 0.4, 0.2)
@export_group("Break Effects")
@export var spawn_sawdust: bool = true
@export var play_crack_sound: bool = true
@export var crack_sound_volume: float = 0.7
@export var splinter_lifetime: float = 15.0
@export var splinter_fade_time: float = 3.0
@export_group("Damage Visuals")
@export var show_crack_decals: bool = true
@export var max_crack_decals: int = 3

var _crack_count: int = 0


func _ready() -> void:
	# Skip initialization in editor
	if Engine.is_editor_hint():
		return

	super._ready()

	# Override base settings for wood
	max_health = 30.0  # Wood is tougher than glass
	damage_resistance = 0.1
	wobble_on_damage = true
	wobble_intensity = 0.15
	show_damage_cracks = true

	# Wood-specific visuals
	break_particle_color = wood_color
	debris_count = splinter_count


func _apply_damage(amount: float, damage_type: String, source: Node3D) -> bool:
	if not super._apply_damage(amount, damage_type, source):
		return false

	# Spawn crack decal on damage
	if show_crack_decals and _crack_count < max_crack_decals:
		_spawn_crack_decal()
		_crack_count += 1

	return true


func _spawn_crack_decal() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var effects: Node = gm.get_core_system("effects")
	if not effects:
		return

	# Spawn crack decal on wood surface
	var _decal_pos := (
		global_position + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), 0.01)
	)

	# TODO: Use actual crack texture
	# if effects.has_method("spawn_decal"):
	#     var crack_texture = load("res://game/assets/textures/decals/wood_crack.png")
	#     effects.spawn_decal(
	#         crack_texture, _decal_pos, Vector3.FORWARD,
	#         Vector3(0.3, 0.3, 0.1), 30.0
	#     )


@rpc("authority", "call_local", "reliable")
func _play_destruction() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	is_destroyed = true
	prop_destroyed.emit(prop_type, global_position)

	# Spawn wood splinters with physics
	_spawn_wood_splinters()

	# Spawn break particles
	_spawn_break_particles()

	# Spawn sawdust cloud
	if spawn_sawdust:
		_spawn_sawdust_cloud()

	# Play crack/break sound
	if play_crack_sound:
		_play_crack_sound()

	# Disable collision and hide
	if collision_shape:
		collision_shape.disabled = true
	if mesh_instance:
		mesh_instance.visible = false

	# Cleanup
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _spawn_wood_splinters() -> void:
	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		return
	var break_position: Vector3 = global_position

	for i in range(splinter_count):
		var splinter := _create_wood_splinter(i)
		if not splinter:
			continue

		effect_parent.add_child(splinter)
		splinter.global_position = (
			break_position
			+ Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))
		)

		# Calculate launch direction (radial + upward)
		var angle := (TAU / splinter_count) * i + randf_range(-0.4, 0.4)
		var direction := Vector3(cos(angle), randf_range(0.3, 0.9), sin(angle)).normalized()
		var force := direction * randf_range(break_force * 0.6, break_force * 1.4)

		# Apply impulse
		splinter.apply_central_impulse(force)
		splinter.apply_torque_impulse(
			Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
		)

		# Fade out and cleanup
		_fade_and_cleanup_splinter(splinter)


func _create_wood_splinter(index: int) -> RigidBody3D:
	var splinter := RigidBody3D.new()
	splinter.name = "WoodSplinter_%d" % index
	splinter.mass = 0.2
	splinter.gravity_scale = 1.0
	splinter.contact_monitor = true
	splinter.max_contacts_reported = 1

	# Create splinter mesh (elongated box)
	var mesh_inst := MeshInstance3D.new()
	var splinter_mesh := _create_splinter_mesh()
	mesh_inst.mesh = splinter_mesh
	splinter.add_child(mesh_inst)

	# Create collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var length := randf_range(splinter_size_min, splinter_size_max)
	var width := length * randf_range(0.15, 0.25)
	shape.size = Vector3(width, panel_thickness, length)
	collision.shape = shape
	splinter.add_child(collision)

	# Play impact sound
	splinter.body_entered.connect(_on_splinter_impact.bind(splinter))

	return splinter


func _create_splinter_mesh() -> Mesh:
	var length := randf_range(splinter_size_min, splinter_size_max)
	var width := length * randf_range(0.15, 0.25)

	var box := BoxMesh.new()
	box.size = Vector3(width, panel_thickness, length)

	# Apply wood material
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = wood_color
	wood_mat.roughness = 0.8
	wood_mat.metallic = 0.0

	# Add some variation
	wood_mat.albedo_color = wood_mat.albedo_color * randf_range(0.8, 1.2)

	box.material = wood_mat

	return box


func _on_splinter_impact(_body: Node, splinter: RigidBody3D) -> void:
	if not is_instance_valid(splinter):
		return

	# Play wood impact sound
	var audio := AudioStreamPlayer3D.new()
	var impact_position: Vector3 = splinter.global_position
	audio.bus = "SFX"
	audio.volume_db = -18.0
	audio.pitch_scale = randf_range(0.85, 1.15)
	audio.max_distance = 12.0

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		audio.free()
		return
	effect_parent.add_child(audio)
	audio.global_position = impact_position

	# TODO: Load actual wood impact sound
	# audio.stream = load("res://game/assets/audio/sfx/wood_impact.ogg")

	audio.finished.connect(audio.queue_free)
	if audio.stream:
		audio.play()
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)


func _fade_and_cleanup_splinter(splinter: RigidBody3D) -> void:
	await get_tree().create_timer(splinter_lifetime - splinter_fade_time).timeout

	if not is_instance_valid(splinter):
		return

	var mesh_inst := splinter.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst:
		splinter.queue_free()
		return

	# Fade out by darkening
	var tween := splinter.create_tween()
	var mat := mesh_inst.get_active_material(0) as StandardMaterial3D
	if mat:
		var start_color := mat.albedo_color
		tween.tween_method(
			func(t: float) -> void:
				if is_instance_valid(mat):
					mat.albedo_color = start_color.lerp(Color(0, 0, 0, 0), t),
			0.0,
			1.0,
			splinter_fade_time
		)

	await tween.finished
	if is_instance_valid(splinter):
		splinter.queue_free()


func _spawn_break_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "BreakParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 1.2
	particles.explosiveness = 1.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.4
	material.direction = Vector3(0, 0.7, 0)
	material.spread = 160.0
	material.initial_velocity_min = 2.5
	material.initial_velocity_max = 6.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.08
	material.scale_max = 0.2
	material.damping_min = 1.5
	material.damping_max = 3.0

	var gradient := Gradient.new()
	gradient.add_point(0.0, wood_color)
	gradient.add_point(0.5, wood_color * 0.7)
	gradient.add_point(1.0, Color(wood_color.r, wood_color.g, wood_color.b, 0.0))

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		particles.free()
		return
	effect_parent.add_child(particles)
	particles.global_position = global_position
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


func _spawn_sawdust_cloud() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "SawdustCloud"
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 30
	dust.lifetime = 2.5
	dust.explosiveness = 0.7

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.6
	material.direction = Vector3(0, 1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 0.8
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0, 0.3, 0)  # Slow fall
	material.scale_min = 0.2
	material.scale_max = 0.6
	material.damping_min = 0.5
	material.damping_max = 1.5

	# Sawdust color (lighter than wood)
	var sawdust_color := wood_color.lightened(0.3)

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(sawdust_color.r, sawdust_color.g, sawdust_color.b, 0.4))
	gradient.add_point(0.5, Color(sawdust_color.r, sawdust_color.g, sawdust_color.b, 0.25))
	gradient.add_point(1.0, Color(sawdust_color.r, sawdust_color.g, sawdust_color.b, 0.0))

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	dust.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	dust.draw_pass_1 = quad

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		dust.free()
		return
	effect_parent.add_child(dust)
	dust.global_position = global_position
	get_tree().create_timer(dust.lifetime + 0.5).timeout.connect(dust.queue_free)


func _play_crack_sound() -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.name = "CrackSound"
	audio.bus = "SFX"
	audio.volume_db = linear_to_db(crack_sound_volume)
	audio.pitch_scale = randf_range(0.9, 1.1)
	audio.max_distance = 20.0

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		audio.free()
		return
	effect_parent.add_child(audio)
	audio.global_position = global_position

	# TODO: Load actual wood break sound
	# var sound_path := "res://game/assets/audio/sfx/wood_break_%s.ogg" % wood_type
	# if ResourceLoader.exists(sound_path):
	#     audio.stream = load(sound_path)

	audio.finished.connect(audio.queue_free)
	if audio.stream:
		audio.play()
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)
