extends RigidBody3D

var splat_decal: Sprite3D = null
var fade_tween: Tween
var is_fading: bool = false
var owner_node: Node3D = null
var _has_pooled: bool = false
var _rest_time: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var blood_trail: GPUParticles3D = $BloodTrail
@onready var blood_spray: GPUParticles3D = $BloodSpray
@onready var timer: Timer = $Timer

const RETRO_BLOOD_SHADER = preload("res://game/art/shaders/retro_blood.gdshader")

var visual_component: SkeletalCharacterVisuals = null


func _ready() -> void:
	# Ensure physics material is set if not assigned in editor
	if physics_material_override == null:
		physics_material_override = load(
			"res://game/scripts/features/effects/effects/gib_physics.tres"
		)

	# Generate the procedural mesh if no visual component is set
	if not visual_component:
		generate_gib_mesh()

	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

	# Apply retro shader to particles
	_apply_shader_to_particles(blood_trail)
	_apply_shader_to_particles(blood_spray)

	# Start lifetime timer
	timer.timeout.connect(fade_out)
	# Timer started in launch() for pooling support


func generate_gib_mesh() -> void:
	# Random chunk type for variety
	var chunk_type: int = randi() % 3
	var base_mesh: Mesh

	match chunk_type:
		0:  # Meat chunk - Subdivided box for lumpy chunk look
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(
				randf_range(0.12, 0.22), randf_range(0.10, 0.18), randf_range(0.12, 0.22)
			)
			# Add subdivisions so noise can deform the faces
			box.subdivide_depth = 2
			box.subdivide_height = 2
			box.subdivide_width = 2
			base_mesh = box
		1:  # Bone shard - sharp/elongated
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(
				randf_range(0.04, 0.08), randf_range(0.15, 0.30), randf_range(0.04, 0.08)
			)
			base_mesh = box
		_:  # Gore blob - flattened lumpy chunk
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(
				randf_range(0.20, 0.30), randf_range(0.06, 0.10), randf_range(0.15, 0.25)
			)
			box.subdivide_depth = 2
			box.subdivide_height = 1
			box.subdivide_width = 2
			base_mesh = box

	var arrays: Array = base_mesh.get_mesh_arrays()
	if arrays.is_empty():
		return

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	# Medium frequency noise for a "chunkier" feel
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.4  # Higher frequency than meatballs, lower than spikes

	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		# Apply noise displacement relative to center
		var n_val: float = noise.get_noise_3d(v.x * 12.0, v.y * 12.0, v.z * 12.0)
		var displacement: float = 0.05 + abs(n_val) * 0.12
		v += v.normalized() * displacement
		vertices[i] = v

	arrays[Mesh.ARRAY_VERTEX] = vertices

	# Create a temporary mesh to preserve topology (indices)
	var temp_mesh := ArrayMesh.new()
	temp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Use SurfaceTool to regenerate normals based on the new geometry
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(temp_mesh, 0)
	st.generate_normals()

	mesh_instance.mesh = st.commit()

	# Random scale for more variety
	scale = Vector3.ONE * randf_range(0.6, 1.2)

	# Increase mass for heavier feel
	mass = randf_range(1.5, 3.5)

	# Randomize shader params if possible
	if mesh_instance.material_override and mesh_instance.material_override is ShaderMaterial:
		mesh_instance.material_override.set_shader_parameter("pixel_size", randf_range(8.0, 16.0))


func setup_from_mannequin(bone_name: String, color: Color) -> void:
	# Hide the procedural mesh
	if mesh_instance:
		mesh_instance.hide()

	# Create visual component
	if not visual_component:
		visual_component = SkeletalCharacterVisuals.new()
		add_child(visual_component)
		visual_component.set_color(color)

	# Setup dismemberment on the gib visual - mask everything EXCEPT the bone
	# We use a special 'mask_all_but' logic or just dismember everything else.
	# Wait, SkeletalCharacterVisuals has a skeleton. We can find the bone.

	# Small delay to ensure skeleton is built
	if not visual_component.is_node_ready():
		await visual_component.ready

	var skel: Skeleton3D = visual_component.skeleton
	if skel:
		# Find the bone we want to KEEP
		var target_idx: int = skel.find_bone(visual_component.find_matching_bone(bone_name))

		# Hide all roots
		for i in range(skel.get_bone_count()):
			if skel.get_bone_parent(i) == -1:
				skel.set_bone_pose_scale(i, Vector3.ZERO)

		# Show the target bone and its subtree
		if target_idx != -1:
			skel.set_bone_pose_scale(target_idx, Vector3.ONE)
			# Parenting issue: If we hide the root, children are hidden too.
			# We need to ensure the path to root is visible but other branches are hidden.

			var current: int = target_idx
			while current != -1:
				skel.set_bone_pose_scale(current, Vector3.ONE)

				# Hide other children of this parent
				var p: int = skel.get_bone_parent(current)
				if p != -1:
					for sibling: int in skel.get_bone_children(p):
						if sibling != current:
							skel.set_bone_pose_scale(sibling, Vector3.ZERO)

				current = p

		# visual_component._spawn_stump_blood("target") maybe?

	# Adjust mass for limb weight
	mass = 2.0

	# Adjust collision shape? Limb might need a bigger shape
	# For simplicity, we keep the sphere.


func launch(
	global_pos: Vector3, scatter_dir: Vector3, power: float = 35.0, _owner: Node3D = null
) -> void:
	owner_node = _owner

	# Reset position and state
	global_position = global_pos + Vector3(randf_range(-0.1, 0.1), 0.2, 0)

	# Ensure physics state is active
	freeze = false
	sleeping = false
	collision_layer = CollisionLayers.LAYER_DEBRIS
	collision_mask = CollisionLayers.MASK_WORLD_ONLY

	# Quake-style velocity randomization
	var random_dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1))
	var dir: Vector3 = (scatter_dir + random_dir).normalized()
	var speed_variation: float = 6.0 + randf() * 8.0
	var power_scale: float = power / 35.0  # Normalizes

	# Cap power to avoid extreme flying
	power_scale = clamp(power_scale, 0.5, 1.5)

	linear_velocity = dir * speed_variation * power_scale

	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))

	blood_trail.emitting = true

	# Start lifetime timer for cleanup
	timer.start(10.0)
	_has_pooled = false
	_rest_time = 0.0


func _physics_process(delta: float) -> void:
	if _has_pooled or is_fading:
		return

	# If we are basically stationary and on the ground
	if linear_velocity.length() < 0.2 and abs(angular_velocity.length()) < 0.2:
		_rest_time += delta
		if _rest_time > 0.5:  # Stayed still for half a second
			spawn_splat(true)  # Spawn a pool
			_has_pooled = true
	else:
		_rest_time = 0.0


func _on_body_entered(body: Node) -> void:
	if body == owner_node:
		return

	# Bounce effects
	if linear_velocity.length() > 2.0:
		blood_spray.restart()
		blood_spray.emitting = true

	# Splat on hard impact
	if linear_velocity.length() > 5.0:
		spawn_splat()


func spawn_splat(is_pool: bool = false) -> void:
	## Create procedural blood splat decal or growing pool
	if is_pool and _has_pooled:
		return

	var splat_scn: PackedScene = load("res://game/scenes/effects/blood_pool.tscn")
	if is_pool and splat_scn:
		var pool: Node3D = splat_scn.instantiate()
		get_parent().add_child(pool)
		pool.global_position = global_position
		# Align to floor
		var ray_end: Vector3 = global_position + Vector3.DOWN * 2.0
		var down_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			global_position, ray_end
		)
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var result: Dictionary = space_state.intersect_ray(down_ray)
		if result:
			pool.global_position = result.position + result.normal * 0.01
			if result.normal.dot(Vector3.UP) < 0.99:
				pool.look_at(result.position + result.normal, Vector3.UP)

		# Track for cleanup if it's a Sprite3D
		if pool is Sprite3D:
			splat_decal = pool
		return

	if splat_decal:
		return  # Already spawned

	# Create the Sprite3D decal (GLES3 compatible)
	splat_decal = Sprite3D.new()
	splat_decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	splat_decal.shaded = false
	splat_decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	splat_decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splat_decal.no_depth_test = false
	splat_decal.layers = 0xFFFFF
	add_child(splat_decal)

	# Position slightly below gib for floor splat
	splat_decal.position = Vector3(0, -0.05, 0)
	splat_decal.look_at(global_position + Vector3.DOWN, Vector3.FORWARD)

	# Apply procedural gib splat texture
	var splat_generator_script: GDScript = load(
		"res://game/scripts/features/effects/effects/procedural_splat_generator.gd"
	)
	if splat_generator_script:
		splat_decal.texture = splat_generator_script.create_gib_splat_texture()

	# Randomize size and rotation
	var splat_size := randf_range(0.6, 1.4)
	splat_decal.pixel_size = splat_size / 64.0
	splat_decal.rotation.z = randf() * TAU

	# Spawn drip if on vertical surface (wall)
	var drip_space_state := get_world_3d().direct_space_state

	var test_dirs: Array[Vector3] = [
		Vector3.DOWN, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP
	]
	var best_hit: Dictionary = {}
	var min_dist: float = 2.0

	for dir: Vector3 in test_dirs:
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * 1.0)
		q.collision_mask = CollisionLayers.MASK_WORLD_ONLY
		var res := drip_space_state.intersect_ray(q)
		if res:
			var d: float = global_position.distance_to(res.position)
			if d < min_dist:
				min_dist = d
				best_hit = res

	if best_hit:
		# Re-orient decal to surface
		if splat_decal:
			splat_decal.global_position = best_hit.position + best_hit.normal * 0.02
			if abs(best_hit.normal.dot(Vector3.UP)) < 0.99:
				splat_decal.look_at(best_hit.position + best_hit.normal, Vector3.UP)
			else:
				# Floor/Ceiling
				splat_decal.rotation.x = PI / 2 if best_hit.normal.dot(Vector3.UP) < 0 else -PI / 2
				splat_decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

		# Note: Wall drip effect removed - would need Sprite3D conversion (low priority)


func fade_out() -> void:
	if is_fading:
		return
	is_fading = true

	fade_tween = create_tween()
	# Use shader alpha parameter for fading
	var mat: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	if mat:
		fade_tween.tween_property(mat, "shader_parameter/alpha", 0.0, 2.0)
	if splat_decal:
		fade_tween.parallel().tween_property(splat_decal, "modulate:a", 0.0, 2.0)

	# Check if we are pooled by checking for manager existence
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.effects:
		fade_tween.tween_callback(func() -> void: gs.effects.return_pooled_gib(self))
	else:
		fade_tween.tween_callback(queue_free)


## Reset state for object pooling


func reset() -> void:
	is_fading = false
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	# Reset visuals - reset shader alpha parameter
	var mat: ShaderMaterial = mesh_instance.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("alpha", 1.0)

	# Reset physics
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true

	# Reset particles
	if blood_trail:
		blood_trail.emitting = false
	if blood_spray:
		blood_spray.emitting = false

	# Clean up splat decal if it exists
	if splat_decal:
		if is_instance_valid(splat_decal):
			splat_decal.queue_free()
		splat_decal = null

	timer.stop()


func _apply_shader_to_particles(particles: GPUParticles3D) -> void:
	if not particles:
		return
	var mesh: QuadMesh = particles.draw_pass_1 as QuadMesh
	if mesh:
		var mat := ShaderMaterial.new()
		mat.shader = RETRO_BLOOD_SHADER
		mat.set_shader_parameter("flow_speed", 0.8)
		# Use a slightly brighter red for projectile trails
		mat.set_shader_parameter("fresh_blood", Color(0.9, 0.1, 0.1))
		mesh.material = mat
