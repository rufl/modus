class_name Corpse
extends RigidBody3D

var health: float = 30.0
var max_gibs: int = 5
var gib_threshold: float = 10.0
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

var _is_gibbed: bool = false


func _ready() -> void:
	# Get child nodes
	mesh_instance = get_node_or_null("MeshInstance3D")
	collision_shape = get_node_or_null("CollisionShape3D")

	# Set physics properties for nice tumbling
	collision_layer = CollisionLayers.LAYER_DEBRIS
	collision_mask = CollisionLayers.LAYER_WORLD

	# High drag to prevent rolling forever
	linear_damp = 3.0
	angular_damp = 6.0

	# Add physics material for friction
	if not physics_material_override:
		var mat := PhysicsMaterial.new()
		mat.friction = 1.0
		mat.rough = true
		mat.absorbent = true
		physics_material_override = mat

	# Auto-cleanup after time
	get_tree().create_timer(30.0).timeout.connect(queue_free, CONNECT_ONE_SHOT)

	# Wait for settlement to form blood pool
	get_tree().create_timer(1.0).timeout.connect(_form_blood_pool, CONNECT_ONE_SHOT)


func setup(source_mesh: Mesh, source_transform: Transform3D, base_color: Color) -> void:
	# Create mesh instance if it doesn't exist
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	# Apply mesh
	if source_mesh:
		mesh_instance.mesh = source_mesh.duplicate()
	else:
		# Create default capsule mesh if none provided
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		mesh_instance.mesh = capsule

	# Apply color to material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.darkened(0.2)
	mesh_instance.material_override = mat

	# Create collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		collision_shape.shape = shape
		add_child(collision_shape)

	# Match original transform scale
	if source_transform.basis.get_scale().length() > 0.01:
		scale = source_transform.basis.get_scale()


func take_damage(info_or_damage: Variant, dir: Vector3 = Vector3.ZERO, _force: float = 1.0) -> void:
	var dmg: float = 0.0
	var damage_pos: Vector3 = global_position

	if info_or_damage is DamageInfo:
		dmg = info_or_damage.base_amount
		damage_pos = info_or_damage.hit_position
		dir = info_or_damage.knockback_direction
	else:
		dmg = float(info_or_damage)

	health -= dmg

	# Create blood mist on hit
	if dmg > 5.0:
		_spawn_blood(damage_pos, dir)

	if health <= 0:
		_gib_and_die(dir)


func _gib_and_die(dir: Vector3) -> void:
	if _is_gibbed:
		return
	_is_gibbed = true

	var effects_service: Node = GameManager.get_core_system("effects")
	if effects_service:
		# Increase intensity for more dramatic corpse explosion (matching knife melee)
		effects_service.spawn_gore_effect(global_position, dir, 3.0)
		if effects_service.has_method("spawn_blood_pool"):
			effects_service.spawn_blood_pool(global_position, 2.5)

	queue_free()


func _spawn_blood(pos: Vector3, dir: Vector3) -> void:
	var effects_service: Node = GameManager.get_core_system("effects")
	if effects_service and effects_service.has_method("spawn_gore_effect"):
		effects_service.spawn_gore_effect(pos, dir, 0.5)


func _form_blood_pool() -> void:
	if not is_instance_valid(self):
		return

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0),
		global_position + Vector3.DOWN * 2.0,
		CollisionLayers.MASK_WORLD_ONLY
	)

	var result: Dictionary = space.intersect_ray(query)
	if result:
		var effects_service: Node = GameManager.get_core_system("effects")
		if effects_service and effects_service.has_method("spawn_blood_pool"):
			effects_service.spawn_blood_pool(result.position, 1.2)
