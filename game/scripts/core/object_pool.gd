class_name ObjectPool
extends Node

## Object Pool for frequently created/destroyed objects
## Reduces memory allocation overhead and improves performance
## **Validates: Requirements 11.3**

signal object_acquired(pool_name: String, object: Node)
signal object_released(pool_name: String, object: Node)

# Pool storage: pool_name -> Array of pooled objects
var _pools: Dictionary = {}

# Pool configuration: pool_name -> Dictionary with max_size, prefab_path, etc.
var _pool_configs: Dictionary = {}

# Active objects tracking: pool_name -> Array of active objects
var _active_objects: Dictionary = {}

# Statistics for monitoring
var _stats: Dictionary = {}


## Initialize a pool for a specific object type
## pool_name: Unique identifier for the pool
## prefab_path: Path to the scene/script to instantiate
## initial_size: Number of objects to pre-create
## max_size: Maximum pool size (0 = unlimited)
func create_pool(
	pool_name: String, prefab_path: String, initial_size: int = 10, max_size: int = 100
) -> void:
	if _pools.has(pool_name):
		push_warning("[ObjectPool] Pool '%s' already exists" % pool_name)
		return

	_pools[pool_name] = []
	_active_objects[pool_name] = []
	_pool_configs[pool_name] = {
		"prefab_path": prefab_path, "max_size": max_size, "initial_size": initial_size
	}
	_stats[pool_name] = {"created": 0, "acquired": 0, "released": 0, "reused": 0}

	# Pre-create initial objects
	for i in range(initial_size):
		var obj := _create_object(pool_name)
		if obj:
			_pools[pool_name].append(obj)


## Acquire an object from the pool
## Returns a pooled object if available, or creates a new one
func acquire(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_error("[ObjectPool] Pool '%s' does not exist" % pool_name)
		return null

	var pool: Array = _pools[pool_name]
	var obj: Node = null

	# Try to reuse an inactive object
	if pool.size() > 0:
		obj = pool.pop_back()
		_stats[pool_name]["reused"] += 1
	else:
		# Create a new object if pool is empty
		obj = _create_object(pool_name)
		if not obj:
			return null

	# Activate the object
	if obj.has_method("_on_pool_acquire"):
		obj._on_pool_acquire()

	obj.set_process(true)
	obj.set_physics_process(true)
	if obj.has_method("show"):
		obj.show()

	_active_objects[pool_name].append(obj)
	_stats[pool_name]["acquired"] += 1

	object_acquired.emit(pool_name, obj)

	return obj


## Release an object back to the pool
func release(pool_name: String, obj: Node) -> void:
	if not _pools.has(pool_name):
		push_error("[ObjectPool] Pool '%s' does not exist" % pool_name)
		return

	if not obj:
		push_warning("[ObjectPool] Attempted to release null object to pool '%s'" % pool_name)
		return

	# Remove from active objects
	var active: Array = _active_objects[pool_name]
	var index := active.find(obj)
	if index >= 0:
		active.remove_at(index)

	# Deactivate the object
	if obj.has_method("_on_pool_release"):
		obj._on_pool_release()

	obj.set_process(false)
	obj.set_physics_process(false)
	if obj.has_method("hide"):
		obj.hide()

	# Check pool size limit
	var config: Dictionary = _pool_configs[pool_name]
	var max_size: int = config.get("max_size", 0)
	var pool: Array = _pools[pool_name]

	if max_size > 0 and pool.size() >= max_size:
		# Pool is full, destroy the object
		obj.queue_free()
	else:
		# Return to pool
		pool.append(obj)

	_stats[pool_name]["released"] += 1

	object_released.emit(pool_name, obj)


## Clear a specific pool, destroying all objects
func clear_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return

	# Destroy inactive objects
	var pool: Array = _pools[pool_name]
	for obj in pool:
		if obj:
			obj.queue_free()
	pool.clear()

	# Destroy active objects
	var active: Array = _active_objects[pool_name]
	for obj in active:
		if obj:
			obj.queue_free()
	active.clear()


## Clear all pools
func clear_all_pools() -> void:
	for pool_name in _pools.keys():
		clear_pool(pool_name)

	_pools.clear()
	_active_objects.clear()
	_pool_configs.clear()
	_stats.clear()


## Get pool statistics
func get_pool_stats(pool_name: String) -> Dictionary:
	if not _stats.has(pool_name):
		return {}

	var stats: Dictionary = _stats[pool_name].duplicate()
	stats["inactive_count"] = _pools[pool_name].size()
	stats["active_count"] = _active_objects[pool_name].size()
	stats["total_count"] = stats["inactive_count"] + stats["active_count"]

	return stats


## Get all pool statistics
func get_all_stats() -> Dictionary:
	var all_stats: Dictionary = {}
	for pool_name in _pools.keys():
		all_stats[pool_name] = get_pool_stats(pool_name)
	return all_stats


## Check if a pool exists
func has_pool(pool_name: String) -> bool:
	return _pools.has(pool_name)


## Get the number of inactive objects in a pool
func get_pool_size(pool_name: String) -> int:
	if not _pools.has(pool_name):
		return 0
	return _pools[pool_name].size()


## Get the number of active objects from a pool
func get_active_count(pool_name: String) -> int:
	if not _active_objects.has(pool_name):
		return 0
	return _active_objects[pool_name].size()


# Private helper methods


func _create_object(pool_name: String) -> Node:
	var config: Dictionary = _pool_configs[pool_name]
	var prefab_path: String = config.get("prefab_path", "")

	if prefab_path.is_empty():
		push_error("[ObjectPool] No prefab_path configured for pool '%s'" % pool_name)
		return null

	var obj: Node = null

	# Try to load as a scene first
	if ResourceLoader.exists(prefab_path):
		var resource = load(prefab_path)
		if resource is PackedScene:
			obj = resource.instantiate()
		elif resource is Script:
			obj = resource.new()

	if not obj:
		push_error(
			(
				"[ObjectPool] Failed to create object for pool '%s' from '%s'"
				% [pool_name, prefab_path]
			)
		)
		return null

	# Add to scene tree but keep inactive
	add_child(obj)
	obj.set_process(false)
	obj.set_physics_process(false)
	if obj.has_method("hide"):
		obj.hide()

	_stats[pool_name]["created"] += 1

	return obj
