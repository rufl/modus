@tool
extends "res://shared/editor_core/actors/actor_base.gd"

# FOG_SHADER removed - not compatible with GLES3
# Using particle-based fog instead

@export var size: Vector3 = Vector3(10, 5, 10)
@export_group("Fog Settings")
@export var density: float = 0.1
@export var color: Color = Color.WHITE
@export var speed: Vector3 = Vector3(0.1, 0, 0.1)

var fog_particles: GPUParticles3D = null
var _shader_material: ShaderMaterial = null


func _exit_tree() -> void:
	# Clean up shader material to prevent leaks
	if _shader_material:
		_shader_material = null
	if fog_particles:
		fog_particles = null


func _init() -> void:
	actor_category = "effect"
	actor_name = "Fog Zone"
	actor_description = "Particle-based Fog Zone (GLES3 compatible)"


func _on_actor_ready() -> void:
	# Setup particle-based fog (GLES3 compatible)
	_setup_particle_fog()

	if fog_particles:
		# Initial visibility based on active state
		fog_particles.visible = is_active


func _setup_particle_fog() -> void:
	if fog_particles:
		return

	fog_particles = GPUParticles3D.new()
	fog_particles.name = "FogParticles"
	fog_particles.amount = int(size.x * size.y * size.z * density * 10.0)  # Scale with volume
	fog_particles.lifetime = 8.0
	fog_particles.explosiveness = 0.0
	fog_particles.randomness = 0.5
	fog_particles.visibility_aabb = AABB(-size / 2.0, size)

	add_child(fog_particles)

	# Create particle material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = size / 2.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.3
	mat.gravity = Vector3(0, 0, 0)

	# Drift with speed parameter
	mat.linear_accel_min = speed.length() * 0.5
	mat.linear_accel_max = speed.length() * 1.5

	# Scale for fog puffs
	mat.scale_min = 1.0
	mat.scale_max = 2.0

	# Alpha fade
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.2, 0.8))
	alpha_curve.add_point(Vector2(0.8, 0.8))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_tex := CurveTexture.new()
	alpha_tex.curve = alpha_curve
	mat.alpha_curve = alpha_tex

	fog_particles.process_material = mat

	# Create fog mesh with simple material
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)

	var fog_mat := StandardMaterial3D.new()
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	fog_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fog_mat.albedo_color = color
	fog_mat.albedo_color.a = 0.3  # Semi-transparent

	quad.material = fog_mat
	fog_particles.draw_pass_1 = quad


func _on_quality_changed(settings: Dictionary) -> void:
	# Particle fog doesn't need quality checks
	if fog_particles:
		fog_particles.visible = is_active


func _on_activated(_data: Dictionary) -> void:
	if fog_particles:
		fog_particles.visible = true
		fog_particles.emitting = true


func _on_deactivated() -> void:
	if fog_particles:
		fog_particles.visible = false
		fog_particles.emitting = false


func _update_material() -> void:
	# Update particle fog appearance
	if not fog_particles:
		return

	var mesh := fog_particles.draw_pass_1 as QuadMesh
	if mesh and mesh.material:
		var mat := mesh.material as StandardMaterial3D
		if mat:
			mat.albedo_color = color
			mat.albedo_color.a = density * 3.0  # Scale alpha with density


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "size",
				"type": TYPE_VECTOR3,
				"label": "Size",
				"description": "Dimensions of the fog volume"
			},
			{
				"name": "density",
				"type": TYPE_FLOAT,
				"label": "Fog Density",
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0, 1.0"
			},
			{"name": "color", "type": TYPE_COLOR, "label": "Fog Color"},
			{
				"name": "speed",
				"type": TYPE_VECTOR3,
				"label": "Scroll Speed",
				"description": "Speed of the noise scrolling"
			}
		]
	)
	return props


## Editor Interface for resizing handles (if supported by editor tools)


func set_editor_size(new_size: Vector3) -> void:
	self.size = new_size


func get_editor_size() -> Vector3:
	return self.size
