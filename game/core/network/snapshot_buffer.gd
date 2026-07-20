class_name SnapshotBuffer
extends RefCounted

const NetworkSnapshotScript = preload("res://game/core/network/network_snapshot.gd")

var snapshots: Array = []  # Array of NetworkSnapshot
var max_buffer_duration: float = 1.0  # Keep 1 second of history


func add_snapshot(snapshot: RefCounted) -> void:
	## Add new snapshot and cleanup old ones
	snapshots.append(snapshot)
	_cleanup_old_snapshots()


func get_interpolated_state(entity_id: int, render_time_ms: float) -> Dictionary:
	## Get interpolated state for entity at specific render time
	## Returns empty dict if insufficient data

	if snapshots.size() < 2:
		return {}  # Need at least 2 snapshots to interpolate

	# Find the two snapshots to interpolate between
	var from_snap: RefCounted = null
	var to_snap: RefCounted = null

	for i in range(snapshots.size() - 1):
		var current: RefCounted = snapshots[i]
		var next: RefCounted = snapshots[i + 1]

		if current.timestamp_ms <= render_time_ms and next.timestamp_ms > render_time_ms:
			from_snap = current
			to_snap = next
			break

	if not from_snap or not to_snap:
		# Render time is outside buffer range, extrapolate or use latest
		return _extrapolate_state(entity_id)

	# Get entity states from both snapshots
	var from_state: Variant = from_snap.get_entity_state(entity_id)
	var to_state: Variant = to_snap.get_entity_state(entity_id)

	if not from_state or not to_state:
		return {}  # Entity doesn't exist in one of the snapshots

	# Calculate interpolation factor (t)
	var time_delta: float = to_snap.timestamp_ms - from_snap.timestamp_ms
	if time_delta <= 0:
		return _state_to_dict(to_state)  # Avoid division by zero

	var t: float = (render_time_ms - from_snap.timestamp_ms) / time_delta
	t = clampf(t, 0.0, 1.0)

	# Interpolate between states
	return {
		"position": from_state.position.lerp(to_state.position, t),
		"rotation": from_state.rotation.lerp(to_state.rotation, t),
		"velocity": from_state.velocity.lerp(to_state.velocity, t),
		"health": lerpf(from_state.health, to_state.health, t),
		"is_dead": to_state.is_dead  # Don't interpolate boolean
	}


func _extrapolate_state(entity_id: int) -> Dictionary:
	## Extrapolate state when render time is outside buffer
	## Uses latest snapshot + velocity prediction

	if snapshots.is_empty():
		return {}

	var latest: RefCounted = snapshots[snapshots.size() - 1]
	var state: Variant = latest.get_entity_state(entity_id)

	if not state:
		return {}

	# Get network config for extrapolation limit
	var net_config: Resource = null
	var ns: Node = GameManager.get_core_system("network")
	if ns and ns.network_manager:
		net_config = ns.network_manager.config
	var extrap_limit: float = net_config.extrapolation_limit if net_config else 0.25

	# Calculate how far ahead we're trying to render
	var current_time: float = Time.get_ticks_msec()
	var time_ahead: float = (current_time - latest.timestamp_ms) / 1000.0

	# Cap extrapolation to limit
	if time_ahead > extrap_limit:
		# Too far ahead, just use latest state
		return _state_to_dict(state)

	# Extrapolate using velocity
	var extrap_pos: Vector3 = state.position + (state.velocity * time_ahead)

	return {
		"position": extrap_pos,
		"rotation": state.rotation,
		"velocity": state.velocity,
		"health": state.health,
		"is_dead": state.is_dead
	}


func _state_to_dict(state: RefCounted) -> Dictionary:
	## Convert EntityState to Dictionary
	return {
		"position": state.position,
		"rotation": state.rotation,
		"velocity": state.velocity,
		"health": state.health,
		"is_dead": state.is_dead
	}


func _cleanup_old_snapshots() -> void:
	## Remove snapshots older than max_buffer_duration
	var cutoff_time := Time.get_ticks_msec() - (max_buffer_duration * 1000.0)

	# Keep only snapshots newer than cutoff
	snapshots = snapshots.filter(func(s: RefCounted) -> bool: return s.timestamp_ms > cutoff_time)


func get_buffer_info() -> Dictionary:
	## Return diagnostic info
	if snapshots.is_empty():
		return {"count": 0, "oldest_ms": 0, "newest_ms": 0}

	return {
		"count": snapshots.size(),
		"oldest_ms": snapshots[0].timestamp_ms,
		"newest_ms": snapshots[snapshots.size() - 1].timestamp_ms,
		"span_ms": snapshots[snapshots.size() - 1].timestamp_ms - snapshots[0].timestamp_ms
	}
