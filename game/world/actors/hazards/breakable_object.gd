@tool
class_name BreakableObject
extends StaticBody3D

signal broken(position: Vector3, material_type: int)

enum MaterialType { WOOD, GLASS, METAL, CONCRETE, PLASTIC, EXPLOSIVE }

@export var material_type: MaterialType = MaterialType.WOOD
@export var max_health: float = 50.0
@export var current_health: float = 50.0
@export var debris_count: int = 6
@export var debris_impulse_min: float = 2.0
@export var debris_impulse_max: float = 8.0
@export var debris_lifetime: float = 15.0
@export var break_sound: AudioStream
@export var break_particles: PackedScene
@export var debris_scene: PackedScene
@export var drop_items: Array[PackedScene] = []
@export var drop_chance: float = 0.5

var is_broken: bool = false

var _visual_mesh: MeshInstance3D
var _damage_taken: float = 0.0
var _wobble_tween: Tween
var _original_transform: Transform3D


func _ready() -> void:
	# Add to hittable group for damage system
	add_to_group("hittable")
	add_to_group("breakables")

	current_health = max_health

	# Create visual if not present
	if not _visual_mesh:
		_create_default_visual()


func _create_default_visual() -> void:
	## Override in subclasses for custom visuals
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "Visual"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	_visual_mesh.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_material_color()
	_visual_mesh.material_override = mat

	add_child(_visual_mesh)

	# Create collision shape
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	collision.shape = shape
	add_child(collision)


func _get_material_color() -> Color:
	match material_type:
		MaterialType.WOOD:
			return Color(0.6, 0.4, 0.2)
		MaterialType.GLASS:
			return Color(0.8, 0.9, 1.0, 0.3)
		MaterialType.METAL:
			return Color(0.5, 0.5, 0.5)
		MaterialType.CONCRETE:
			return Color(0.6, 0.6, 0.6)
		MaterialType.PLASTIC:
			return Color(0.8, 0.2, 0.2)
		MaterialType.EXPLOSIVE:
			return Color(1.0, 0.5, 0.0)
		_:
			return Color.WHITE


## Receive damage from weapons/explosions


func receive_damage(amount: float, source: Node = null) -> void:
	if is_broken:
		return

	# Server authority
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	current_health -= amount
	_damage_taken += amount

	# Visual feedback for damage
	_play_wobble_animation()

	# Near-break warning (crack/damage state)
	if current_health <= max_health * 0.3 and current_health > 0:
		_show_damage_state()

	if current_health <= 0:
		break_object(source)




func restore_state(broken: bool) -> bool:
	if broken:
		break_object()
		return is_broken

	is_broken = false
	current_health = max_health
	_damage_taken = 0.0
	if _visual_mesh:
		_visual_mesh.visible = true
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred("disabled", false)
	return not is_broken


## Break the object and spawn debris


func break_object(_source: Node = null) -> void:
	if is_broken:
		return

	is_broken = true

	# Emit signal
	broken.emit(global_position, material_type)

	# Spawn debris
	_spawn_debris()

	# Spawn particles
	_spawn_particles()

	# Play sound
	_play_break_sound()

	# Drop items
	_drop_items()

	# Sync to clients
	if multiplayer.has_multiplayer_peer():
		_sync_break.rpc()

	# Remove object
	queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_break() -> void:
	if not is_broken:
		is_broken = true
		_spawn_particles()
		_play_break_sound()
		queue_free()


func _spawn_debris() -> void:
	if not debris_scene:
		_spawn_procedural_debris()
		return

	for i in debris_count:
		var debris: Node = debris_scene.instantiate()
		get_parent().add_child(debris)

		if debris is RigidBody3D:
			debris.global_position = (
				global_position
				+ Vector3(randf_range(-0.5, 0.5), randf_range(0, 1), randf_range(-0.5, 0.5))
			)

			# Apply random impulse
			var impulse_dir := (
				Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1)).normalized()
			)
			var impulse_force := randf_range(debris_impulse_min, debris_impulse_max)
			debris.apply_central_impulse(impulse_dir * impulse_force)

			# Set lifetime
			if debris.has_method("set_lifetime"):
				debris.set_lifetime(debris_lifetime)
			else:
				# Fallback: use timer
				var timer := Timer.new()
				timer.wait_time = debris_lifetime
				timer.one_shot = true
				timer.timeout.connect(debris.queue_free)
				debris.add_child(timer)
				timer.start()


func _spawn_procedural_debris() -> void:
	## Spawn simple box debris if no custom scene provided
	for i in debris_count:
		var debris := RigidBody3D.new()
		debris.name = "Debris"

		# Create mesh
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.2, 0.2, 0.2) * randf_range(0.5, 1.5)
		mesh_inst.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = _get_material_color()
		mesh_inst.material_override = mat
		debris.add_child(mesh_inst)

		# Create collision
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

		# Apply impulse
		var impulse_dir := (
			Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1)).normalized()
		)
		var impulse_force := randf_range(debris_impulse_min, debris_impulse_max)
		debris.apply_central_impulse(impulse_dir * impulse_force)

		# Lifetime
		var timer := Timer.new()
		timer.wait_time = debris_lifetime
		timer.one_shot = true
		timer.timeout.connect(debris.queue_free)
		debris.add_child(timer)
		timer.start()


func _spawn_particles() -> void:
	if not break_particles:
		return

	var particles: Node = break_particles.instantiate()
	get_parent().add_child(particles)
	particles.global_position = global_position

	if particles is GPUParticles3D:
		particles.emitting = true
		particles.one_shot = true

		# Auto-cleanup
		var timer := Timer.new()
		timer.wait_time = particles.lifetime + 1.0
		timer.one_shot = true
		timer.timeout.connect(particles.queue_free)
		particles.add_child(timer)
		timer.start()


func _play_break_sound() -> void:
	# Generate procedural sound if none provided
	if not break_sound:
		break_sound = _get_procedural_break_sound()

	if not break_sound:
		return

	var audio := AudioStreamPlayer3D.new()
	audio.stream = break_sound
	audio.max_distance = 20.0
	get_parent().add_child(audio)
	audio.global_position = global_position
	audio.play()

	# Auto-cleanup
	audio.finished.connect(audio.queue_free)


func _drop_items() -> void:
	if drop_items.is_empty():
		return

	if randf() > drop_chance:
		return

	# Pick random item
	var item_scene: PackedScene = drop_items.pick_random()
	if not item_scene:
		return

	var item: Node = item_scene.instantiate()
	get_parent().add_child(item)
	item.global_position = global_position + Vector3(0, 0.5, 0)


## Get inspector properties for editor


func get_inspector_properties() -> Array[Dictionary]:
	return [
		{
			"name": "material_type",
			"type": TYPE_INT,
			"label": "Material Type",
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Wood,Glass,Metal,Concrete,Plastic,Explosive"
		},
		{
			"name": "max_health",
			"type": TYPE_FLOAT,
			"label": "Max Health",
			"description": "HP before breaking"
		},
		{
			"name": "debris_count",
			"type": TYPE_INT,
			"label": "Debris Count",
			"description": "Number of pieces spawned"
		},
		{
			"name": "drop_chance",
			"type": TYPE_FLOAT,
			"label": "Drop Chance",
			"description": "Probability of dropping items (0-1)"
		}
	]


func _get_procedural_break_sound() -> AudioStream:
	## Get procedurally generated break sound based on material
	match material_type:
		MaterialType.GLASS:
			return SoundGenerator.generate_glass_shatter()
		MaterialType.WOOD:
			return SoundGenerator.generate_wood_crack()
		MaterialType.METAL:
			return SoundGenerator.generate_metal_clang()
		MaterialType.EXPLOSIVE:
			return SoundGenerator.generate_breakable_explosion()
		_:
			return SoundGenerator.generate_wood_crack()


func _play_wobble_animation() -> void:
	## Wobble effect when damaged
	if not _visual_mesh:
		return

	# Store original transform on first wobble
	if not _original_transform:
		_original_transform = _visual_mesh.transform

	# Cancel existing wobble
	if _wobble_tween and _wobble_tween.is_running():
		_wobble_tween.kill()

	_wobble_tween = create_tween()
	_wobble_tween.set_ease(Tween.EASE_OUT)
	_wobble_tween.set_trans(Tween.TRANS_ELASTIC)

	# Wobble intensity based on damage
	var intensity: float = min(_damage_taken / max_health, 0.3)
	var wobble_angle: float = deg_to_rad(randf_range(-5, 5)) * intensity

	# Rotate slightly
	var wobble_rotation := _original_transform.basis.rotated(Vector3.UP, wobble_angle)
	var wobble_transform := Transform3D(wobble_rotation, _original_transform.origin)

	_wobble_tween.tween_property(_visual_mesh, "transform", wobble_transform, 0.1)
	_wobble_tween.tween_property(_visual_mesh, "transform", _original_transform, 0.3)


func _show_damage_state() -> void:
	## Show visual damage (cracks, dents)
	if not _visual_mesh:
		return

	# Darken material slightly
	var mat: StandardMaterial3D = _visual_mesh.material_override
	if mat:
		var damaged_color := mat.albedo_color.darkened(0.2)
		mat.albedo_color = damaged_color

		# Add roughness for damaged look
		mat.roughness = min(mat.roughness + 0.2, 1.0)
