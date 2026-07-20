@tool
class_name CollapsableFloorActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TriggerType { WEIGHT, CHANNEL, TIMED }  # Collapses when stepped on  # Via channel system  # After delay

@export var trigger_type: TriggerType = TriggerType.WEIGHT
@export var collapse_delay: float = 0.5  # Warning shake time
@export var respawn_delay: float = 5.0  # Time before floor respawns
@export var one_time: bool = false  # Don't respawn

var floor_mesh: CSGBox3D = null

var _is_collapsed: bool = false
var _original_position: Vector3
var _shake_tween: Tween
var _weight_bodies: Array[Node] = []


func _ready() -> void:
	super._ready()

	# Create floor visual
	floor_mesh = CSGBox3D.new()
	floor_mesh.name = "FloorMesh"
	floor_mesh.size = Vector3(4, 0.2, 4)

	# Floor material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mat.roughness = 0.8
	floor_mesh.material = mat

	add_child(floor_mesh)
	_original_position = floor_mesh.position

	# Create collision for weight detection
	if trigger_type == TriggerType.WEIGHT:
		_create_weight_sensor()

	# Timed trigger
	if trigger_type == TriggerType.TIMED and activation_delay > 0:
		get_tree().create_timer(activation_delay).timeout.connect(_start_collapse)


func _create_weight_sensor() -> void:
	var area := Area3D.new()
	area.name = "WeightSensor"
	area.collision_layer = 0
	area.collision_mask = CollisionLayers.LAYER_PLAYERS | CollisionLayers.LAYER_ENEMIES

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.5, 4)
	shape.shape = box
	shape.position = Vector3(0, 0.25, 0)

	area.add_child(shape)
	add_child(area)

	area.body_entered.connect(_on_weight_entered)
	area.body_exited.connect(_on_weight_exited)


func _on_weight_entered(body: Node) -> void:
	if _is_collapsed:
		return

	if body not in _weight_bodies:
		_weight_bodies.append(body)

	# Start collapse if weight detected
	if _weight_bodies.size() > 0:
		_start_collapse()


func _on_weight_exited(body: Node) -> void:
	_weight_bodies.erase(body)


func _do_activate(_data: Dictionary) -> void:
	## Channel activation
	if trigger_type == TriggerType.CHANNEL:
		_start_collapse()


func _start_collapse() -> void:
	if _is_collapsed:
		return

	_is_collapsed = true

	# Shake warning
	_play_shake_animation()

	# Collapse after delay
	await get_tree().create_timer(collapse_delay).timeout
	_collapse_floor()


func _play_shake_animation() -> void:
	if not floor_mesh:
		return

	# Play creak sound
	var creak_sound := AudioStreamPlayer3D.new()
	add_child(creak_sound)
	creak_sound.global_position = global_position
	# TODO(v1.1, @audio-team): Add creak sound stream
	# For now, visual feedback only (shake animation)
	# Estimated effort: 2 hours (find/create sound, integrate)

	# Shake tween
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()

	_shake_tween = create_tween()
	_shake_tween.set_loops(int(collapse_delay / 0.1))

	var shake_offset := Vector3(
		randf_range(-0.05, 0.05), randf_range(-0.02, 0.02), randf_range(-0.05, 0.05)
	)

	_shake_tween.tween_property(floor_mesh, "position", _original_position + shake_offset, 0.05)
	_shake_tween.tween_property(floor_mesh, "position", _original_position, 0.05)


func _collapse_floor() -> void:
	if not floor_mesh:
		return

	# Hide original mesh
	floor_mesh.visible = false

	# Spawn falling debris pieces
	var piece_count := 12
	var piece_size := Vector3(1.0, 0.2, 1.0)

	for i in piece_count:
		var debris := RigidBody3D.new()
		debris.name = "FloorDebris"
		debris.mass = 5.0

		# Create mesh
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = piece_size
		mesh_inst.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		mat.roughness = 0.8
		mesh_inst.material_override = mat
		debris.add_child(mesh_inst)

		# Create collision
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = piece_size
		collision.shape = shape
		debris.add_child(collision)

		# Position in grid
		var grid_x := i % 4
		var grid_z := int(float(i) / 4.0)
		var offset := Vector3((grid_x - 1.5) * 1.0, 0, (grid_z - 1.5) * 1.0)

		get_parent().add_child(debris)
		debris.global_position = global_position + offset
		debris.rotation = Vector3(
			randf_range(-0.2, 0.2), randf_range(0, TAU), randf_range(-0.2, 0.2)
		)

		# Apply downward force
		debris.apply_central_impulse(Vector3(0, -2, 0))

		# Cleanup after falling
		var timer := Timer.new()
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(debris.queue_free)
		debris.add_child(timer)
		timer.start()

	# Play collapse sound
	var collapse_sound := AudioStreamPlayer3D.new()
	add_child(collapse_sound)
	collapse_sound.global_position = global_position
	# TODO(v1.1, @audio-team): Add collapse sound stream
	# For now, visual feedback only (debris particles)
	# Estimated effort: 2 hours (find/create sound, integrate)

	# Respawn if not one-time
	if not one_time and respawn_delay > 0:
		await get_tree().create_timer(respawn_delay).timeout
		_respawn_floor()


func _respawn_floor() -> void:
	_is_collapsed = false
	_weight_bodies.clear()

	if floor_mesh:
		floor_mesh.visible = true
		floor_mesh.position = _original_position


func get_inspector_properties() -> Array[Dictionary]:
	return [
		{
			"name": "trigger_type",
			"type": TYPE_INT,
			"label": "Trigger Type",
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Weight,Channel,Timed"
		},
		{
			"name": "collapse_delay",
			"type": TYPE_FLOAT,
			"label": "Collapse Delay",
			"description": "Warning shake time before collapse"
		},
		{
			"name": "respawn_delay",
			"type": TYPE_FLOAT,
			"label": "Respawn Delay",
			"description": "Time before floor respawns (0 = never)"
		},
		{
			"name": "one_time",
			"type": TYPE_BOOL,
			"label": "One Time Use",
			"description": "Floor doesn't respawn"
		}
	]
