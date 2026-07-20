class_name NetworkSnapshot
extends RefCounted

var timestamp_ms: float = 0.0
var entity_states: Dictionary = {}  # entity_id (int) -> EntityState (Dictionary)


class EntityState:
	## State of a single entity at snapshot time
	var position: Vector3
	var rotation: Vector3
	var velocity: Vector3
	var health: float
	var is_dead: bool

	func _init(
		p_pos: Vector3 = Vector3.ZERO,
		p_rot: Vector3 = Vector3.ZERO,
		p_vel: Vector3 = Vector3.ZERO,
		p_health: float = 100.0,
		p_dead: bool = false
	) -> void:
		position = p_pos
		rotation = p_rot
		velocity = p_vel
		health = p_health
		is_dead = p_dead


static func create() -> NetworkSnapshot:
	## Factory method
	var snap := NetworkSnapshot.new()
	snap.timestamp_ms = Time.get_ticks_msec()
	return snap


func add_entity(entity_id: int, state: EntityState) -> void:
	## Add or update entity state in snapshot
	entity_states[entity_id] = state


func add_entity_from_node(entity: Node3D) -> void:
	## Convenience method to add entity from Node3D
	var entity_id := entity.get_instance_id()

	var state := EntityState.new()
	state.position = entity.global_position
	state.rotation = entity.rotation

	if "velocity" in entity:
		state.velocity = entity.velocity

	if "health" in entity:
		state.health = entity.health

	if "is_dead" in entity:
		state.is_dead = entity.is_dead

	add_entity(entity_id, state)


func get_entity_state(entity_id: int) -> EntityState:
	## Get entity state, returns null if not found
	return entity_states.get(entity_id, null)


func get_debug_string() -> String:
	return "Snapshot @ %.1fms: %d entities" % [timestamp_ms, entity_states.size()]
