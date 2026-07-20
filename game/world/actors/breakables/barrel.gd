@tool
class_name Barrel
extends "res://game/world/actors/hazards/breakable_object.gd"

const ExplosionParticles = preload("res://game/scenes/effects/explosion_particles.gd")

@export var is_explosive: bool = false
@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 50.0


func _init() -> void:
	material_type = MaterialType.METAL
	max_health = 80.0
	current_health = 80.0
	debris_count = 4
	debris_impulse_min = 3.0
	debris_impulse_max = 10.0
	debris_lifetime = 25.0

	# Explosive barrels get explosion particles
	if is_explosive:
		var particles := GPUParticles3D.new()
		particles.set_script(ExplosionParticles)
		break_particles = PackedScene.new()
		break_particles.pack(particles)


func _create_default_visual() -> void:
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "BarrelVisual"

	# Cylinder barrel
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 1.0
	_visual_mesh.mesh = mesh

	# Metal or explosive material
	var mat := StandardMaterial3D.new()
	if is_explosive:
		mat.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.0)
		mat.emission_energy_multiplier = 0.5
		material_type = MaterialType.EXPLOSIVE
		max_health = 50.0
		current_health = 50.0
	else:
		mat.albedo_color = Color(0.5, 0.5, 0.5)  # Gray metal
		mat.metallic = 0.8
		mat.roughness = 0.3

	_visual_mesh.material_override = mat
	add_child(_visual_mesh)

	# Collision
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.0
	collision.shape = shape
	add_child(collision)


func break_object(source: Node = null) -> void:
	# Explosive barrels create blast
	if is_explosive:
		_create_explosion()

	# Call parent to handle normal breaking
	super.break_object(source)


func _create_explosion() -> void:
	# Apply damage to nearby entities
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = CollisionLayers.LAYER_PLAYERS | CollisionLayers.LAYER_ENEMIES

	var results: Array[Dictionary] = space_state.intersect_shape(query)
	for result in results:
		var collider: Node = result.collider
		if collider and collider.has_method("receive_damage"):
			var distance: float = global_position.distance_to(collider.global_position)
			var damage_falloff: float = 1.0 - (distance / explosion_radius)
			var final_damage: float = explosion_damage * damage_falloff

			collider.receive_damage(final_damage, self)

			# Apply knockback
			if collider is CharacterBody3D:
				var knockback_dir: Vector3 = (
					(collider.global_position - global_position).normalized()
				)
				collider.velocity += knockback_dir * 10.0 * damage_falloff

	# Spawn explosion effect
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.effects:
		gs.effects.spawn_explosion_effect.rpc(global_position, explosion_radius)


func _spawn_procedural_debris() -> void:
	## Spawn metal chunks
	for i in debris_count:
		var debris := RigidBody3D.new()
		debris.name = "MetalChunk"
		debris.mass = 2.0  # Heavy

		# Create chunk mesh (irregular box)
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.2, 0.4), randf_range(0.2, 0.4), randf_range(0.1, 0.3))
		mesh_inst.mesh = mesh

		# Metal material
		var mat := StandardMaterial3D.new()
		if is_explosive:
			# Burnt/charred metal
			mat.albedo_color = Color(0.2, 0.2, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.3, 0.0)
			mat.emission_energy_multiplier = 0.3
		else:
			mat.albedo_color = Color(0.5, 0.5, 0.5)
			mat.metallic = 0.7
			mat.roughness = 0.4

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

		# Apply strong impulse for explosion
		var impulse_dir := (
			Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)).normalized()
		)
		var impulse_force := randf_range(
			debris_impulse_min if not is_explosive else debris_impulse_max * 1.5,
			debris_impulse_max if not is_explosive else debris_impulse_max * 2.5
		)
		debris.apply_central_impulse(impulse_dir * impulse_force)

		# Spin
		debris.apply_torque_impulse(
			Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		)

		# Lifetime
		var timer := Timer.new()
		timer.wait_time = debris_lifetime
		timer.one_shot = true
		timer.timeout.connect(debris.queue_free)
		debris.add_child(timer)
		timer.start()


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "is_explosive",
				"type": TYPE_BOOL,
				"label": "Explosive",
				"description": "Creates blast radius when broken"
			},
			{"name": "explosion_radius", "type": TYPE_FLOAT, "label": "Explosion Radius"},
			{"name": "explosion_damage", "type": TYPE_FLOAT, "label": "Explosion Damage"}
		]
	)
	return props
