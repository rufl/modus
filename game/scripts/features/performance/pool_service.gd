extends Node

var pools: Dictionary = {}


func initialize() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("[PoolService] Initializing...", "PoolService")
	await get_tree().process_frame


func register_pool(
	pool_id: String, scene: PackedScene, initial_size: int = 20, max_size: int = 100
) -> void:
	if pools.has(pool_id):
		return

	var container: Node = Node.new()
	container.name = pool_id + "_pool"
	add_child(container)

	pools[pool_id] = {
		"scene": scene, "container": container, "max_size": max_size, "available": [], "active": []
	}

	_populate_pool(pool_id, initial_size)


func _populate_pool(pool_id: String, count: int) -> void:
	var pool: Dictionary = pools[pool_id]
	for i in range(count):
		var instance: Node = pool["scene"].instantiate()
		instance.set_meta("pool_id", pool_id)
		pool["container"].add_child(instance)
		_reset_instance(instance)
		pool["available"].append(instance)


func get_instance(pool_id: String) -> Node:
	if not pools.has(pool_id):
		return null

	var pool: Dictionary = pools[pool_id]
	var instance: Node = null

	# Try to get a valid instance from the available pool
	while pool["available"].size() > 0:
		var candidate: Variant = pool["available"].pop_back()
		if is_instance_valid(candidate) and candidate is Node:
			instance = candidate
			break
		# else: instance was freed externally, discard it

	# If no valid instance found, create or recycle
	if not instance:
		if pool["active"].size() < pool["max_size"]:
			instance = pool["scene"].instantiate()
			instance.set_meta("pool_id", pool_id)
			pool["container"].add_child(instance)
		else:
			# Recycle oldest active instance
			instance = pool["active"].pop_front()
			if not is_instance_valid(instance):
				# Active instance was also freed, create new one
				instance = pool["scene"].instantiate()
				instance.set_meta("pool_id", pool_id)
				pool["container"].add_child(instance)
			else:
				_reset_instance(instance)

	if instance:
		pool["active"].append(instance)
		_activate_instance(instance)
	return instance


func return_instance(instance: Node) -> void:
	if not is_instance_valid(instance):
		return  # Already freed, nothing to return

	if not instance.has_meta("pool_id"):
		instance.queue_free()
		return

	var pool_id: String = instance.get_meta("pool_id")
	if not pools.has(pool_id):
		instance.queue_free()
		return

	var pool: Dictionary = pools[pool_id]
	pool["active"].erase(instance)
	_reset_instance(instance)
	pool["available"].append(instance)


func _reset_instance(instance: Node) -> void:
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is Node3D:
		instance.visible = false
	elif instance is CanvasItem:
		instance.visible = false

	if instance.has_method("reset"):
		instance.reset()


func _activate_instance(instance: Node) -> void:
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if instance is Node3D or instance is CanvasItem:
		instance.visible = true
