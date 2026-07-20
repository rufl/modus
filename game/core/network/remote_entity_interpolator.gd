class_name RemoteEntityInterpolator
extends Node

const SnapshotBufferScript = preload("res://game/core/network/snapshot_buffer.gd")
const NetworkSnapshotScript = preload("res://game/core/network/network_snapshot.gd")

var snapshot_buffer: RefCounted = null
var interpolation_delay_ms: float = 100.0  # Render 100ms in the past
var entity: Node3D = null
var entity_id: int = 0
var lerp_speed: float = 15.0


func _ready() -> void:
	set_process(false)  # Only process when we have data

	entity = get_parent() as Node3D
	if not entity:
		push_error("[Interpolator] Must be child of Node3D")
		set_process(false)
		return

	entity_id = entity.get_instance_id()

	# Load config
	var net_config: Resource = null
	var ns: Node = GameManager.get_core_system("network")
	if ns and ns.network_manager:
		net_config = ns.network_manager.config
	if net_config:
		interpolation_delay_ms = net_config.interpolation_delay * 1000.0
		lerp_speed = net_config.interpolation_speed

	# Create snapshot buffer
	snapshot_buffer = SnapshotBufferScript.new()

	# Only run on clients (not server)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		set_process(false)
		return

	# Connect to synchronizer if it exists
	call_deferred("_connect_to_synchronizer")

	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.debug(
			"Enabled for entity %d (delay: %.0fms)" % [entity_id, interpolation_delay_ms],
			"Interpolator"
		)


func _connect_to_synchronizer() -> void:
	## Connect to MultiplayerSynchronizer for snapshot capture
	var synchronizer: Node = entity.get_node_or_null("MultiplayerSynchronizer")
	if synchronizer and synchronizer is MultiplayerSynchronizer:
		if not synchronizer.delta_synchronized.is_connected(_on_snapshot_received):
			synchronizer.delta_synchronized.connect(_on_snapshot_received)
			if OS.is_debug_build():
				var logger: Node = GameManager.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info(
						"[Interpolator] Connected to synchronizer for entity %d" % entity_id, "Core"
					)


func _on_snapshot_received() -> void:
	## Called when server sends new state update
	# Create snapshot from current synced state
	var snapshot: RefCounted = NetworkSnapshotScript.create()
	snapshot.add_entity_from_node(entity)

	# Add to buffer
	snapshot_buffer.add_snapshot(snapshot)


func _process(delta: float) -> void:
	## Apply interpolation every frame
	# Calculate render time (current time - interpolation delay)
	var render_time_ms := Time.get_ticks_msec() - interpolation_delay_ms

	# Get interpolated state
	var interpolated: Dictionary = snapshot_buffer.get_interpolated_state(entity_id, render_time_ms)

	if interpolated.is_empty():
		return  # No data yet

	# Smoothly lerp to interpolated position (prevents snapping)
	entity.global_position = entity.global_position.lerp(interpolated.position, lerp_speed * delta)

	# Lerp rotation
	entity.rotation = entity.rotation.lerp(interpolated.rotation, lerp_speed * delta)

	# Apply other properties directly (no lerp needed)
	if "velocity" in entity and interpolated.has("velocity"):
		entity.velocity = interpolated.velocity

	if "health" in entity and interpolated.has("health"):
		entity.health = interpolated.health


func get_diagnostics() -> Dictionary:
	## Returns diagnostic info
	return {
		"entity_id": entity_id,
		"interpolation_delay_ms": interpolation_delay_ms,
		"buffer_info": snapshot_buffer.get_buffer_info()
	}
