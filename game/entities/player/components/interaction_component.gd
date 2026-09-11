class_name InteractionComponent
extends GameComponent

signal item_collected(item_id: String)
signal object_picked_up(object: RigidBody3D)
signal object_thrown(object: RigidBody3D)

@export var pickup_range: float = 3.0
@export var throw_force: float = 15.0

var held_object: RigidBody3D = null

var _player: CharacterBody3D
var _camera: Camera3D
var _collected_keys: Array[String] = []
var _hold_distance: float = 2.0
var _lerp_speed: float = 0.3


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect signals to prevent memory leaks ===
	if (
		GameManager.get_core_system("config")
		and GameManager.get_core_system("config").config_reloaded.is_connected(_load_config)
	):
		GameManager.get_core_system("config").config_reloaded.disconnect(_load_config)


func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera

	# Load config
	_load_config()

	# Listen for config reloads
	if GameManager.get_core_system("config"):
		GameManager.get_core_system("config").config_reloaded.connect(_load_config)


func _load_config(_file_path: String = "") -> void:
	if not GameManager.get_core_system("config"):
		return

	var cfg: Dictionary = GameManager.get_core_system("config").get_value("interaction", {})
	if cfg.is_empty():
		return

	# Pickup settings
	var pickup_cfg: Dictionary = cfg.get("pickup", {})
	pickup_range = pickup_cfg.get("range", pickup_range)
	throw_force = pickup_cfg.get("throw_force", throw_force)
	_hold_distance = pickup_cfg.get("hold_distance", _hold_distance)


func _physics_process(_delta: float) -> void:
	# Update held object position
	if held_object and _camera:
		_update_held_object_position()


func interact() -> void:
	if held_object:
		throw_object()
	else:
		try_pickup()


func try_pickup() -> void:
	if not _camera:
		return

	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		_camera.global_position,
		_camera.global_position - _camera.global_transform.basis.z * pickup_range,
		CollisionLayers.LAYER_INTERACTABLES | CollisionLayers.LAYER_WORLD,
		[_player.get_rid()]
	)

	var result: Dictionary = space.intersect_ray(query)
	if result:
		var collider: Object = result["collider"]

		# Handle Interactables (Keys, Switches)
		var interactable: Node = null
		if collider is Node:
			interactable = collider.get_node_or_null("Interactable")
		if interactable and interactable.has_method("interact"):
			interactable.interact(_player)
			return

		# Handle Physics Objects
		if collider is RigidBody3D:
			if multiplayer.is_server():
				perform_pickup(collider)
			else:
				_request_pickup_object.rpc_id(1, collider.get_path())


func throw_object() -> void:
	if not held_object:
		return

	var throw_direction: Vector3 = -_camera.global_transform.basis.z

	if multiplayer.is_server():
		_perform_throw(throw_direction)
	else:
		_request_throw_object.rpc_id(1, throw_direction)


func has_key(key_id: String) -> bool:
	return key_id in _collected_keys


func collect_key(key_id: String) -> void:
	if key_id not in _collected_keys:
		if multiplayer.is_server():
			_collected_keys.append(key_id)
			_sync_collected_keys.rpc(_collected_keys)
			item_collected.emit(key_id)
		else:
			# Client can optimistically collect or wait for sync
			pass


# Internal Logic


func _update_held_object_position() -> void:
	var offset: Vector3 = _camera.global_transform.basis.z * _hold_distance
	var target_pos: Vector3 = _camera.global_position - offset

	# Smoothly move object to target position
	held_object.global_position = held_object.global_position.lerp(target_pos, _lerp_speed)

	# Match camera rotation
	held_object.global_rotation = _camera.global_rotation


func _validate_client_rpc(method: String, args: Array) -> bool:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return true
	if not _player or _player.get_multiplayer_authority() != sender_id:
		return false
	var network_svc: Node = GameManager.get_core_system("network")
	return (
		network_svc
		and network_svc.network_manager
		and network_svc.network_manager.validate_rpc(sender_id, method, args)
	)


## Networking

@rpc("any_peer", "call_local", "reliable")
func _request_pickup_object(object_path: NodePath) -> void:
	if (
		not multiplayer.is_server()
		or not _validate_client_rpc("_request_pickup_object", [object_path])
	):
		return
	var obj: Node = get_node_or_null(object_path)
	if (
		obj
		and obj is RigidBody3D
		and _player
		and (obj as Node3D).global_position.distance_to(_player.global_position) <= pickup_range
	):
		perform_pickup(obj)


func perform_pickup(obj: RigidBody3D) -> void:
	held_object = obj
	_sync_held_object.rpc(obj.get_path())
	object_picked_up.emit(obj)


@rpc("authority", "call_local", "reliable")
func _sync_held_object(object_path: NodePath) -> void:
	var obj: Node = get_node_or_null(object_path)
	if obj is RigidBody3D:
		held_object = obj
		held_object.freeze = true
		held_object.collision_layer = 0  # Disable collision while held


@rpc("any_peer", "call_local", "reliable")
func _request_throw_object(dir: Vector3) -> void:
	if not multiplayer.is_server() or not _validate_client_rpc("_request_throw_object", [dir]):
		return
	_perform_throw(dir)


func _perform_throw(dir: Vector3) -> void:
	if not held_object:
		return
	_sync_throw_object.rpc(held_object.get_path(), dir)

	held_object.freeze = false
	held_object.collision_layer = CollisionLayers.LAYER_INTERACTABLES
	held_object.apply_central_impulse(dir * throw_force)

	var thrown: RigidBody3D = held_object
	held_object = null
	object_thrown.emit(thrown)


@rpc("authority", "call_local", "reliable")
func _sync_throw_object(obj_path: NodePath, _dir: Vector3) -> void:
	var obj: Node = get_node_or_null(obj_path)
	if obj is RigidBody3D:
		obj.freeze = false
		obj.collision_layer = CollisionLayers.LAYER_INTERACTABLES

	if held_object == obj:
		held_object = null


@rpc("authority", "call_local", "reliable")
func _sync_collected_keys(keys: Array[String]) -> void:
	_collected_keys = keys
