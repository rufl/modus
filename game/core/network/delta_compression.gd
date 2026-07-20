class_name DeltaCompression
extends RefCounted

var last_states: Dictionary = {}  # entity_id -> Dictionary


func encode_delta(entity_id: int, current_state: Dictionary) -> Dictionary:
	## Encode only properties that changed since last send
	## Returns delta dictionary (only changed properties)

	if not last_states.has(entity_id):
		# First time sending this entity - send full state
		last_states[entity_id] = current_state.duplicate()
		return current_state

	var last_state: Dictionary = last_states[entity_id]
	var delta: Dictionary = {}

	# Compare each property
	for key: String in current_state:
		var current_value: Variant = current_state[key]
		var last_value: Variant = last_state.get(key, null)

		# Check if changed
		if last_value == null or not _values_equal(current_value, last_value):
			delta[key] = current_value

	# Update last state
	last_states[entity_id] = current_state.duplicate()

	return delta


func _values_equal(a: Variant, b: Variant) -> bool:
	## Compare values with tolerance for floats
	if typeof(a) != typeof(b):
		return false

	match typeof(a):
		TYPE_FLOAT:
			return absf(a - b) < 0.001  # 1mm tolerance
		TYPE_VECTOR2:
			return a.distance_to(b) < 0.001
		TYPE_VECTOR3:
			return a.distance_to(b) < 0.001
		_:
			return a == b


func reset_entity(entity_id: int) -> void:
	## Clear last state for entity (to force full update next time)
	last_states.erase(entity_id)


func get_compression_ratio(entity_id: int, delta: Dictionary) -> float:
	## Calculate compression ratio for this delta
	if not last_states.has(entity_id):
		return 1.0  # No compression on first send

	var last_state: Dictionary = last_states[entity_id]
	if last_state.is_empty():
		return 1.0

	var compressed_size := delta.size()
	var full_size := last_state.size()

	if full_size == 0:
		return 1.0

	return float(compressed_size) / float(full_size)


func get_stats() -> Dictionary:
	## Return statistics about compression
	var total_entities := last_states.size()
	var avg_properties := 0.0

	if total_entities > 0:
		var total_props := 0
		for state: Dictionary in last_states.values():
			total_props += state.size()
		avg_properties = float(total_props) / float(total_entities)

	return {"tracked_entities": total_entities, "avg_properties_per_entity": avg_properties}
