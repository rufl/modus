extends RigidBody3D
class_name ExplosiveBarrel

@export var explosion_radius: float = 5.0
@export var explosion_damage: int = 2

var has_exploded: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Make sure we're in the correct collision layer to be hit by raycasts
	collision_layer = 1
	collision_mask = 0


## Called when shot by a player


func take_damage(shooter_id: int) -> void:
	if has_exploded:
		return

	has_exploded = true

	# Broadcast explosion to all clients
	explode.rpc(shooter_id)


@rpc("authority", "call_local", "reliable")
func explode(shooter_id: int) -> void:
	# Visual feedback - hide the barrel
	if mesh:
		mesh.hide()
	if collision:
		collision.set_deferred("disabled", true)

	# Spawn explosion particles
	_spawn_explosion_particles()

	# Only the server/host calculates damage
	if multiplayer.is_server():
		_deal_explosion_damage(shooter_id)

	# Remove barrel after a short delay
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)


func _spawn_explosion_particles() -> void:
	call_deferred("_finish_spawn_explosion_particles")


func _finish_spawn_explosion_particles() -> void:
	# Create explosion effect using GPUParticles3D
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 32
	particles.lifetime = 0.8
	particles.explosiveness = 1.0

	# Create particle material
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8

	# Orange/red color gradient
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.5, 0.0, 1.0))  # Orange
	gradient.set_color(1, Color(0.3, 0.0, 0.0, 0.0))  # Fade to dark red
	var gradient_tex: GradientTexture1D = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	particles.process_material = mat

	# Create mesh for particles
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var quad_mat: StandardMaterial3D = StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	# Add to scene at barrel position
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.5, 0)
	else:
		particles.queue_free()
		return

	# Auto-cleanup
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(2.0)
	cleanup_timer.timeout.connect(
		func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
	)


func _deal_explosion_damage(shooter_id: int) -> void:
	var explosion_force: float = 15.0  # Max knockback force

	# Find all entities in explosion radius
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if not scene_root:
		return

	for node: Node in scene_root.get_children():
		if not is_instance_valid(node):
			continue
		if node == self:
			continue

		var node_pos: Vector3 = Vector3.ZERO
		if node is Node3D:
			node_pos = (node as Node3D).global_position
		else:
			continue

		var distance: float = global_position.distance_to(node_pos)
		if distance > explosion_radius:
			continue

		# Calculate force based on distance (closer = stronger)
		var force_mult: float = 1.0 - (distance / explosion_radius)
		var direction: Vector3 = (node_pos - global_position).normalized()
		direction.y = 0.3  # Add upward component
		direction = direction.normalized()
		var impulse: Vector3 = direction * explosion_force * force_mult

		# Push RigidBody3D objects (barrels, pickups)
		if node is RigidBody3D and node != self:
			if not node.freeze:
				(node as RigidBody3D).apply_impulse(impulse * 50.0)
			# Chain reaction for other barrels
			if node is ExplosiveBarrel and not (node as ExplosiveBarrel).has_exploded:
				var barrel: ExplosiveBarrel = node as ExplosiveBarrel
				var chain_timer: SceneTreeTimer = get_tree().create_timer(0.1)
				chain_timer.timeout.connect(
					func() -> void:
						if is_instance_valid(barrel) and not barrel.has_exploded:
							barrel.take_damage(shooter_id)
				)

		# Push and damage players
		if node is CharacterBody3D:
			var char_body: CharacterBody3D = node as CharacterBody3D

			# Apply knockback via velocity
			if "velocity" in char_body:
				char_body.velocity += impulse * 5.0

			# Store explosion knockback for player to use
			if "explosion_knockback" in char_body:
				char_body.explosion_knockback = impulse * 5.0

			# Deal damage to players
			if char_body.has_method("receive_damage"):
				char_body.receive_damage.rpc_id(
					char_body.get_multiplayer_authority(),
					explosion_damage,
					shooter_id,
					global_position
				)

			# Deal damage to enemies
			if char_body.has_method("take_damage"):
				char_body.take_damage(explosion_damage, shooter_id)
