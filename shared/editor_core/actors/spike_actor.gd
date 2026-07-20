@tool
class_name SpikeActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum SpikeMode { CONTINUOUS, TIMED, PRESSURE }  ## Always active when triggered  ## Cycles between up/down  ## Only while player is on it

@export var spike_mode: SpikeMode = SpikeMode.TIMED
@export var damage_amount: float = 25.0
@export var spike_height: float = 0.5
@export var up_duration: float = 1.0
@export var down_duration: float = 2.0
@export var start_delay: float = 0.0
@export var damage_interval: float = 0.5

var spike_mesh: Node3D = null
var damage_area: Area3D = null

var _phase_timer: float = 0.0
var _is_up: bool = false
var _damage_timer: float = 0.0
var _entities_in_zone: Array[Node] = []


func _init() -> void:
	actor_category = "hazard"
	actor_name = "Spike Trap"
	actor_description = "Pop-up spikes that damage entities"


func _on_actor_ready() -> void:
	_create_visual()
	_create_damage_area()

	if starts_active:
		_phase_timer = start_delay


func _create_visual() -> void:
	# Base platform
	var base := CSGBox3D.new()
	base.name = "Base"
	base.size = Vector3(1.0, 0.1, 1.0)
	base.position.y = 0.05

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.3, 0.3, 0.3)
	base.material = base_mat
	add_child(base)

	# Spike mesh (starts hidden)
	spike_mesh = CSGCylinder3D.new()
	spike_mesh.name = "SpikeMesh"
	spike_mesh.radius = 0.08
	spike_mesh.height = spike_height
	spike_mesh.position.y = -spike_height * 0.5  # Hidden below surface
	spike_mesh.sides = 6  # Hexagonal spikes

	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.5, 0.5, 0.5)
	spike_mesh.material = spike_mat
	add_child(spike_mesh)


func _create_damage_area() -> void:
	damage_area = Area3D.new()
	damage_area.name = "DamageArea"
	damage_area.monitoring = true
	add_child(damage_area)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, spike_height, 0.8)
	shape.shape = box
	shape.position.y = spike_height * 0.5
	damage_area.add_child(shape)

	damage_area.body_entered.connect(_on_body_entered_damage)
	damage_area.body_exited.connect(_on_body_exited_damage)

	# Start disabled
	damage_area.monitoring = false


func _process(delta: float) -> void:
	super._process(delta)

	if not is_active:
		return

	match spike_mode:
		SpikeMode.TIMED:
			_phase_timer -= delta
			if _phase_timer <= 0:
				if _is_up:
					_retract_spikes()
					_phase_timer = down_duration
				else:
					_extend_spikes()
					_phase_timer = up_duration

		SpikeMode.CONTINUOUS:
			if not _is_up:
				_extend_spikes()

	# Apply damage to entities in zone
	if _is_up:
		_damage_timer -= delta
		if _damage_timer <= 0:
			_deal_damage()
			_damage_timer = damage_interval


func _on_activated(_data: Dictionary) -> void:
	if spike_mode == SpikeMode.TIMED:
		_phase_timer = start_delay if start_delay > 0 else 0.01
	else:
		_extend_spikes()


func _on_deactivated() -> void:
	_retract_spikes()


func _extend_spikes() -> void:
	if _is_up:
		return

	_is_up = true
	damage_area.monitoring = true

	var tween := create_tween()
	tween.tween_property(spike_mesh, "position:y", spike_height * 0.5, 0.1)

	_damage_timer = 0.01  # Immediate damage


func _retract_spikes() -> void:
	if not _is_up:
		return

	_is_up = false
	damage_area.monitoring = false

	var tween := create_tween()
	tween.tween_property(spike_mesh, "position:y", -spike_height * 0.5, 0.15)


func _on_body_entered_damage(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		_entities_in_zone.append(body)


func _on_body_exited_damage(body: Node3D) -> void:
	_entities_in_zone.erase(body)


func _deal_damage() -> void:
	for entity: Node in _entities_in_zone:
		if is_instance_valid(entity) and entity.has_method("take_damage"):
			entity.take_damage(damage_amount, self)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "spike_mode",
				"type": TYPE_INT,
				"label": "Spike Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Continuous,Timed,Pressure"
			},
			{"name": "damage_amount", "type": TYPE_FLOAT, "label": "Damage"},
			{"name": "up_duration", "type": TYPE_FLOAT, "label": "Up Duration"},
			{"name": "down_duration", "type": TYPE_FLOAT, "label": "Down Duration"}
		]
	)
	return props
