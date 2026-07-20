@tool
class_name WoodCrate
extends "res://game/world/actors/hazards/breakable_object.gd"

const WoodParticles = preload("res://game/scenes/effects/wood_splinter_particles.gd")


func _init() -> void:
	material_type = MaterialType.WOOD
	max_health = 40.0
	current_health = 40.0
	debris_count = 6
	debris_impulse_min = 2.0
	debris_impulse_max = 6.0
	debris_lifetime = 20.0
	drop_chance = 0.7  # High chance of items

	# Set particle effect
	var particles := GPUParticles3D.new()
	particles.set_script(WoodParticles)
	break_particles = PackedScene.new()
	break_particles.pack(particles)
	particles.free()


func _create_default_visual() -> void:
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "CrateVisual"

	# Cube crate
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	_visual_mesh.mesh = mesh

	# Wood material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	mat.roughness = 0.8
	mat.metallic = 0.0
	_visual_mesh.material_override = mat

	add_child(_visual_mesh)

	# Collision
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = shape
	add_child(collision)


func _spawn_procedural_debris() -> void:
	## Spawn wooden planks and splinters
	for i in debris_count:
		var debris := RigidBody3D.new()
		debris.name = "WoodPlank"
		debris.mass = 0.5

		# Create plank mesh (rectangular)
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()

		# Random plank size
		var is_plank: bool = i < debris_count - 2  # Last 2 are splinters
		if is_plank:
			mesh.size = Vector3(
				randf_range(0.1, 0.2), randf_range(0.4, 0.8), randf_range(0.05, 0.1)
			)
		else:
			# Splinter
			mesh.size = Vector3(
				randf_range(0.05, 0.1), randf_range(0.2, 0.4), randf_range(0.02, 0.05)
			)

		mesh_inst.mesh = mesh

		# Wood material with variation
		var mat := StandardMaterial3D.new()
		var brown_variation := randf_range(0.5, 0.7)
		mat.albedo_color = Color(brown_variation, brown_variation * 0.6, brown_variation * 0.3)
		mat.roughness = 0.9
		mesh_inst.material_override = mat
		debris.add_child(mesh_inst)

		# Collision
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		debris.add_child(collision)

		# Add to scene
		get_parent().add_child(debris)
		debris.global_position = (
			global_position
			+ Vector3(randf_range(-0.5, 0.5), randf_range(0, 1), randf_range(-0.5, 0.5))
		)

		# Random rotation
		debris.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))

		# Apply impulse
		var impulse_dir := (
			Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1)).normalized()
		)
		var impulse_force := randf_range(debris_impulse_min, debris_impulse_max)
		debris.apply_central_impulse(impulse_dir * impulse_force)

		# Spin
		debris.apply_torque_impulse(
			Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
		)

		# Lifetime
		var timer := Timer.new()
		timer.wait_time = debris_lifetime
		timer.one_shot = true
		timer.timeout.connect(debris.queue_free)
		debris.add_child(timer)
		timer.start()
