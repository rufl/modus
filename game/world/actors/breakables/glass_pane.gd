@tool
class_name GlassPane
extends "res://game/world/actors/hazards/breakable_object.gd"

const GlassParticles = preload("res://game/scenes/effects/glass_shatter_particles.gd")


func _init() -> void:
	material_type = MaterialType.GLASS
	max_health = 15.0
	current_health = 15.0
	debris_count = 8
	debris_impulse_min = 1.0
	debris_impulse_max = 4.0
	debris_lifetime = 12.0


func _create_default_visual() -> void:
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "GlassVisual"

	# Thin pane
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 0.1)
	_visual_mesh.mesh = mesh

	# Transparent glass material
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.4)
	mat.metallic = 0.1
	mat.roughness = 0.1
	mat.refraction_enabled = true
	mat.refraction_scale = 0.05
	_visual_mesh.material_override = mat

	add_child(_visual_mesh)

	# Thin collision
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 0.1)
	collision.shape = shape
	add_child(collision)


func _spawn_procedural_debris() -> void:
	## Spawn triangular glass shards
	for i in debris_count:
		var debris := RigidBody3D.new()
		debris.name = "GlassShard"
		debris.mass = 0.1  # Light

		# Create shard mesh (flat triangle)
		var mesh_inst := MeshInstance3D.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)

		# Triangle vertices
		var verts := PackedVector3Array()
		var size := randf_range(0.1, 0.3)
		verts.append(Vector3(0, size, 0))
		verts.append(Vector3(-size * 0.5, -size * 0.5, 0))
		verts.append(Vector3(size * 0.5, -size * 0.5, 0))

		arrays[Mesh.ARRAY_VERTEX] = verts

		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_inst.mesh = mesh

		# Glass material
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_inst.material_override = mat
		debris.add_child(mesh_inst)

		# Thin collision
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(size, size, 0.02)
		collision.shape = shape
		debris.add_child(collision)

		# Add to scene
		get_parent().add_child(debris)
		debris.global_position = (
			global_position
			+ Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.1, 0.1))
		)

		# Random rotation
		debris.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))

		# Apply impulse
		var impulse_dir := (
			Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()
		)
		var impulse_force := randf_range(debris_impulse_min, debris_impulse_max)
		debris.apply_central_impulse(impulse_dir * impulse_force)

		# Spin
		debris.apply_torque_impulse(
			Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		)

		# Lifetime with fade
		var timer := Timer.new()
		timer.wait_time = debris_lifetime
		timer.one_shot = true
		timer.timeout.connect(
			func() -> void:
				# Fade out
				var tween := debris.create_tween()
				tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
				tween.tween_callback(debris.queue_free)
		)
		debris.add_child(timer)
		timer.start()
