class_name DownedStateHandler
extends GameComponent

signal revived
signal bleedout_expired
signal time_remaining(seconds: float)
signal revive_progress_changed(progress: float)

@export var bleedout_time: float = 30.0
@export var revive_time: float = 3.0
@export var revive_distance: float = 3.0
@export var revive_health_percent: float = 0.3

var is_downed: bool = false
var bleedout_timer: float = 0.0
var revive_progress: float = 0.0
var is_being_revived: bool = false
var reviver_path: NodePath = NodePath()
var _revive_in_progress: bool = false  # Atomic flag to prevent race condition


func _exit_tree() -> void:
	# Call parent cleanup for automatic signal disconnection
	super._exit_tree()


func _ready() -> void:
	set_process(false)
	_load_config()

	# Listen for config reloads using safe_connect
	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg2: Node = gm.get_core_system("config") if gm else null
	if cfg2:
		safe_connect(cfg2.config_reloaded, _load_config)


func _load_config(_file_path: String = "") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg: Node = gm.get_core_system("config") if gm else null
	if not cfg:
		return

	var data: Dictionary = cfg.get_value("player_modes.downed", {})
	if data.is_empty():
		return

	bleedout_time = data.get("bleedout_time", bleedout_time)
	revive_time = data.get("revive_time", revive_time)
	revive_distance = data.get("revive_distance", revive_distance)
	revive_health_percent = data.get("revive_health_percent", revive_health_percent)


func _process(delta: float) -> void:
	if not is_downed:
		return

	# Handle revive progress
	if is_being_revived:
		revive_progress += delta / revive_time
		revive_progress_changed.emit(revive_progress)

		if revive_progress >= 1.0:
			_complete_revive()
			return
	else:
		# Decay revive progress when not being revived
		revive_progress = maxf(0.0, revive_progress - delta * 2.0)

	# Server validation for revive distance
	# FIXED: Validate IMMEDIATELY in the RPC method to prevent race condition
	# This validation was happening in _process which creates a race condition
	# The validation should occur in the RPC method itself to prevent exploits
	if multiplayer.is_server() and is_being_revived:
		var reviver: Node = get_node_or_null(reviver_path)
		var victim: Node3D = get_parent() as Node3D
		if reviver and victim:
			var cancel: bool = false
			# Check distance (allow 4.0 for network slack vs 3.0 raycast)
			if reviver.global_position.distance_to(victim.global_position) > 4.0:
				cancel = true
			# Check if reviver is valid
			if "is_downed" in reviver and reviver.is_downed:
				cancel = true
			if "is_dead" in reviver and reviver.is_dead:
				cancel = true

			if cancel:
				request_revive_stop()  # Calls RPC to stop for everyone

	# Bleedout timer
	bleedout_timer -= delta

	# Emit time remaining for UI (ceil to show friendly seconds)
	time_remaining.emit(ceil(bleedout_timer))

	if bleedout_timer <= 0:
		_bleedout()


## Enter downed state


func enter_downed() -> void:
	is_downed = true
	bleedout_timer = bleedout_time
	revive_progress = 0.0
	is_being_revived = false
	set_process(true)


## Exit downed state (without revive - e.g. respawn)


func exit_downed() -> void:
	is_downed = false
	is_being_revived = false
	revive_progress = 0.0
	bleedout_timer = 0.0
	_revive_in_progress = false
	reviver_path = NodePath()
	set_process(false)


## Called when bleedout timer expires


func _bleedout() -> void:
	is_downed = false
	set_process(false)
	bleedout_expired.emit()


## Called when revive completes


func _complete_revive() -> void:
	is_downed = false
	is_being_revived = false
	revive_progress = 0.0
	_revive_in_progress = false  # Reset atomic flag
	set_process(false)
	revived.emit()


## Request to start reviving (called via RPC from reviver)

@rpc("any_peer", "call_local", "reliable")
func request_revive_start(reviver: NodePath) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_downed:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var victim := get_parent() as Node3D
	var reviver_node: Node = get_node_or_null(reviver)
	if sender_id > 0:
		if (
			not victim
			or victim.get_multiplayer_authority() == sender_id
			or not reviver_node
			or not reviver_node is Node3D
			or reviver_node.get_multiplayer_authority() != sender_id
		):
			return
		var gm: Node = get_node_or_null("/root/GameManager")
		var network_svc: Node = gm.get_core_system("network") if gm else null
		if network_svc and network_svc.has_method("get"):
			var network_mgr: Node = network_svc.network_manager
			if (
				network_mgr
				and not network_mgr.validate_rpc(sender_id, "request_revive_start", [reviver])
			):
				return
	elif multiplayer.has_multiplayer_peer():
		return

	if _revive_in_progress:
		push_warning("[DownedState] Revive already in progress - rejecting duplicate request")
		return

	_revive_in_progress = true
	if reviver_node and victim:
		const MAX_REVIVE_DISTANCE: float = 3.0
		if (
			not reviver_node is Node3D
			or (
				(reviver_node as Node3D).global_position.distance_to(victim.global_position)
				> MAX_REVIVE_DISTANCE
			)
		):
			_revive_in_progress = false
			return
		if "is_downed" in reviver_node and reviver_node.is_downed:
			_revive_in_progress = false
			return
		if "is_dead" in reviver_node and reviver_node.is_dead:
			_revive_in_progress = false
			return

	is_being_revived = true
	reviver_path = reviver
	_sync_revive_state.rpc(true, reviver)


## Request to stop reviving (called via RPC from reviver)

@rpc("any_peer", "call_local", "reliable")
func request_revive_stop() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id > 0:
		var reviver_node := get_node_or_null(reviver_path)
		if not reviver_node or reviver_node.get_multiplayer_authority() != sender_id:
			return
		var network_svc: Node = GameManager.get_core_system("network")
		if (
			network_svc
			and network_svc.network_manager
			and not network_svc.network_manager.validate_rpc(
				sender_id, "request_revive_stop", [get_path()]
			)
		):
			return
	is_being_revived = false
	reviver_path = NodePath()
	_revive_in_progress = false
	_sync_revive_state.rpc(false, NodePath())


## Sync revive state to all clients

@rpc("authority", "call_local", "reliable")
func _sync_revive_state(being_revived: bool, reviver: NodePath) -> void:
	is_being_revived = being_revived
	reviver_path = reviver


func get_bleedout_progress() -> float:
	if bleedout_time <= 0:
		return 1.0
	return 1.0 - (bleedout_timer / bleedout_time)


## Request immediate bleedout (Give Up) - Called by local player


func request_bleedout() -> void:
	if is_downed:
		request_bleedout_immediate.rpc_id(1)


## Server RPC to execute forced bleedout

@rpc("any_peer", "call_local", "reliable")
func request_bleedout_immediate() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_downed:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var victim := get_parent() as Node3D
	if sender_id > 0:
		if not victim or victim.get_multiplayer_authority() != sender_id:
			return
		var network_svc: Node = GameManager.get_core_system("network")
		if (
			network_svc
			and network_svc.network_manager
			and not network_svc.network_manager.validate_rpc(
				sender_id, "request_bleedout_immediate", [get_path()]
			)
		):
			return
	elif multiplayer.has_multiplayer_peer():
		return

	_bleedout()


func try_revive_target(camera: Camera3D, owner_rid: RID) -> bool:
	# Raycast to find downed ally
	if not camera:
		return false

	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_transform.basis.z * revive_distance,
		CollisionLayers.LAYER_PLAYERS,
		[owner_rid]
	)

	var result: Dictionary = space.intersect_ray(query)
	if result:
		var collider: Object = result["collider"]
		# Check if it's a downed player
		if collider is CharacterBody3D and collider != get_parent():  # get_parent() is likely Player
			if "is_downed" in collider and collider.is_downed:
				if "downed_handler" in collider and collider.downed_handler:
					var handler: DownedStateHandler = collider.downed_handler
					handler.request_revive_start.rpc_id(1, get_parent().get_path())
					return true

	return false
