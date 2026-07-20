class_name GibPool
extends Node

const GIB_SCENE = preload("res://game/entities/effects/gib.tscn")
const POOL_SIZE: int = 100  # Pre-allocate this many gibs
const MAX_ACTIVE: int = 50  # Hard limit on active gibs

var _pool: Array[RigidBody3D] = []
var _active: Array[RigidBody3D] = []


func _ready() -> void:
	# Pre-warm the pool
	for i in POOL_SIZE:
		var gib: RigidBody3D = GIB_SCENE.instantiate()
		gib.set_physics_process(false)
		gib.visible = false
		gib.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(gib)
		_pool.append(gib)

	GameManager.get_core_system("logger").info(
		"[GibPool] Pre-allocated %d gibs" % POOL_SIZE, "Core"
	)


func spawn_gib(pos: Vector3, dir: Vector3, power: float, owner_node: Node3D = null) -> void:
	# Enforce hard limit - recycle oldest if at capacity
	if _active.size() >= MAX_ACTIVE:
		_recycle_oldest()

	var gib: RigidBody3D = _get_from_pool()
	if not gib:
		return  # Pool exhausted (shouldn't happen)

	# Reset and activate gib
	gib.global_position = pos
	gib.visible = true
	gib.process_mode = Node.PROCESS_MODE_INHERIT
	gib.set_physics_process(true)

	# Launch the gib
	if gib.has_method("launch"):
		gib.launch(pos, dir, power, owner_node)

	_active.append(gib)


func return_gib(gib: RigidBody3D) -> void:
	## Called when gib lifetime expires
	if gib in _active:
		_active.erase(gib)
	_return_to_pool(gib)


func _get_from_pool() -> RigidBody3D:
	if _pool.is_empty():
		push_warning("[GibPool] Pool exhausted! Consider increasing POOL_SIZE")
		return null
	return _pool.pop_back()


func _return_to_pool(gib: RigidBody3D) -> void:
	if not is_instance_valid(gib):
		return

	# Reset gib state
	gib.visible = false
	gib.set_physics_process(false)
	gib.process_mode = Node.PROCESS_MODE_DISABLED
	gib.linear_velocity = Vector3.ZERO
	gib.angular_velocity = Vector3.ZERO

	_pool.append(gib)


func _recycle_oldest() -> void:
	## Force-recycle the oldest active gib
	if _active.is_empty():
		return

	var old_gib: RigidBody3D = _active.pop_front()
	_return_to_pool(old_gib)


func get_active_count() -> int:
	return _active.size()


func get_pool_count() -> int:
	return _pool.size()
