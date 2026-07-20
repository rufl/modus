extends PropertyBasedTesting

## Property-Based Test: Object Pool Reuse
## Feature: architecture-refactoring, Property 36: Object pool reuse
## **Validates: Requirements 11.3**

const ObjectPoolClass = preload("res://game/scripts/core/object_pool.gd")


# Simple test object for pooling
class TestPooledObject extends Node:
	var id: int = 0
	var acquire_count: int = 0
	var release_count: int = 0
	
	func _on_pool_acquire() -> void:
		acquire_count += 1
	
	func _on_pool_release() -> void:
		release_count += 1


func test_property_pool_reuses_released_objects() -> void:
	# Property: For any pooled object type, requesting an object from the pool
	# should reuse an existing inactive object if available, rather than
	# creating a new instance

	await run_enhanced_property_test(
		"Pool reuses released objects",
		_test_pool_reuses_released_objects,
		100,
		SamplingStrategy.MIXED,
		"Released objects should be reused instead of creating new ones"
	)


func _test_pool_reuses_released_objects(test_data: Dictionary) -> bool:
	var pool: ObjectPoolClass = ObjectPoolClass.new()
	add_child(pool)
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	# Create a pool with a simple script
	var test_script := GDScript.new()
	test_script.source_code = """
extends Node
var id: int = 0
var acquire_count: int = 0
var release_count: int = 0

func _on_pool_acquire() -> void:
	acquire_count += 1

func _on_pool_release() -> void:
	release_count += 1
"""
	test_script.reload()
	
	# Save the script temporarily
	var script_path := "res://tests/property/temp_pooled_object_%d.gd" % rng.randi()
	ResourceSaver.save(test_script, script_path)
	
	pool.create_pool("test_pool", script_path, 5, 20)
	
	# Get initial stats
	var stats_before := pool.get_pool_stats("test_pool")
	var created_before: int = stats_before.get("created", 0)
	
	# Acquire and release an object
	var obj1 := pool.acquire("test_pool")
	if obj1:
		obj1.id = 42
	pool.release("test_pool", obj1)
	
	# Acquire again - should reuse the same object
	var obj2 := pool.acquire("test_pool")
	
	# Get stats after reuse
	var stats_after := pool.get_pool_stats("test_pool")
	var created_after: int = stats_after.get("created", 0)
	var reused: int = stats_after.get("reused", 0)
	
	# Property: No new objects should be created (reused existing one)
	var no_new_objects: bool = created_before == created_after
	
	# Property: Reuse count should increase
	var reuse_increased: bool = reused > 0
	
	# Property: The object should be the same instance (same id)
	var same_object: bool = obj2 and obj2.id == 42
	
	pool.clear_all_pools()
	pool.free()
	
	# Clean up temp script
	if ResourceLoader.exists(script_path):
		DirAccess.remove_absolute(script_path)
	
	return no_new_objects and reuse_increased and same_object


func test_property_pool_creates_when_empty() -> void:
	# Property: When the pool is empty, acquiring an object should create
	# a new instance

	await run_enhanced_property_test(
		"Pool creates when empty",
		_test_pool_creates_when_empty,
		100,
		SamplingStrategy.MIXED,
		"Pool should create new objects when empty"
	)


func _test_pool_creates_when_empty(test_data: Dictionary) -> bool:
	var pool: ObjectPoolClass = ObjectPoolClass.new()
	add_child(pool)
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	# Create a pool with initial size 0
	var test_script := GDScript.new()
	test_script.source_code = "extends Node"
	test_script.reload()
	
	var script_path := "res://tests/property/temp_pooled_object_%d.gd" % rng.randi()
	ResourceSaver.save(test_script, script_path)
	
	pool.create_pool("test_pool", script_path, 0, 20)
	
	# Get initial stats
	var stats_before := pool.get_pool_stats("test_pool")
	var created_before: int = stats_before.get("created", 0)
	
	# Acquire an object (pool is empty, should create new)
	var obj := pool.acquire("test_pool")
	
	# Get stats after acquire
	var stats_after := pool.get_pool_stats("test_pool")
	var created_after: int = stats_after.get("created", 0)
	
	# Property: A new object should be created
	var object_created: bool = created_after > created_before
	
	# Property: Object should be valid
	var object_valid: bool = obj != null
	
	pool.clear_all_pools()
	pool.free()
	
	if ResourceLoader.exists(script_path):
		DirAccess.remove_absolute(script_path)
	
	return object_created and object_valid


func test_property_acquire_release_cycle() -> void:
	# Property: Acquiring and releasing objects multiple times should
	# maintain pool integrity

	await run_enhanced_property_test(
		"Acquire/release cycle maintains integrity",
		_test_acquire_release_cycle,
		100,
		SamplingStrategy.MIXED,
		"Multiple acquire/release cycles should work correctly"
	)


func _test_acquire_release_cycle(test_data: Dictionary) -> bool:
	var pool: ObjectPoolClass = ObjectPoolClass.new()
	add_child(pool)
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	var test_script := GDScript.new()
	test_script.source_code = "extends Node"
	test_script.reload()
	
	var script_path := "res://tests/property/temp_pooled_object_%d.gd" % rng.randi()
	ResourceSaver.save(test_script, script_path)
	
	pool.create_pool("test_pool", script_path, 5, 20)
	
	# Perform multiple acquire/release cycles
	var cycle_count := rng.randi_range(5, 15)
	var objects: Array = []
	
	for i in range(cycle_count):
		var obj := pool.acquire("test_pool")
		if obj:
			objects.append(obj)
	
	# Release all objects
	for obj in objects:
		pool.release("test_pool", obj)
	
	# Get stats
	var stats := pool.get_pool_stats("test_pool")
	var acquired: int = stats.get("acquired", 0)
	var released: int = stats.get("released", 0)
	var inactive: int = stats.get("inactive_count", 0)
	var active: int = stats.get("active_count", 0)
	
	# Property: Acquired and released counts should match
	var counts_match: bool = acquired == released
	
	# Property: All objects should be inactive (back in pool)
	var all_inactive: bool = active == 0
	
	# Property: Pool should have objects available
	var has_objects: bool = inactive > 0
	
	pool.clear_all_pools()
	pool.free()
	
	if ResourceLoader.exists(script_path):
		DirAccess.remove_absolute(script_path)
	
	return counts_match and all_inactive and has_objects


func test_property_pool_respects_max_size() -> void:
	# Property: When releasing objects to a full pool, excess objects
	# should be destroyed rather than added to the pool

	await run_enhanced_property_test(
		"Pool respects max size",
		_test_pool_respects_max_size,
		100,
		SamplingStrategy.MIXED,
		"Pool should not exceed max size"
	)


func _test_pool_respects_max_size(test_data: Dictionary) -> bool:
	var pool: ObjectPoolClass = ObjectPoolClass.new()
	add_child(pool)
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	var test_script := GDScript.new()
	test_script.source_code = "extends Node"
	test_script.reload()
	
	var script_path := "res://tests/property/temp_pooled_object_%d.gd" % rng.randi()
	ResourceSaver.save(test_script, script_path)
	
	var max_size := 5
	pool.create_pool("test_pool", script_path, 0, max_size)
	
	# Acquire more objects than max size
	var objects: Array = []
	for i in range(max_size + 3):
		var obj := pool.acquire("test_pool")
		if obj:
			objects.append(obj)
	
	# Release all objects
	for obj in objects:
		pool.release("test_pool", obj)
	
	# Get pool size
	var pool_size := pool.get_pool_size("test_pool")
	
	# Property: Pool size should not exceed max size
	var respects_max: bool = pool_size <= max_size
	
	pool.clear_all_pools()
	pool.free()
	
	if ResourceLoader.exists(script_path):
		DirAccess.remove_absolute(script_path)
	
	return respects_max


func test_property_callbacks_invoked() -> void:
	# Property: _on_pool_acquire and _on_pool_release callbacks should
	# be invoked when objects are acquired/released

	await run_enhanced_property_test(
		"Callbacks invoked on acquire/release",
		_test_callbacks_invoked,
		100,
		SamplingStrategy.MIXED,
		"Pool callbacks should be invoked correctly"
	)


func _test_callbacks_invoked(test_data: Dictionary) -> bool:
	var pool: ObjectPoolClass = ObjectPoolClass.new()
	add_child(pool)
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	var test_script := GDScript.new()
	test_script.source_code = """
extends Node
var acquire_count: int = 0
var release_count: int = 0

func _on_pool_acquire() -> void:
	acquire_count += 1

func _on_pool_release() -> void:
	release_count += 1
"""
	test_script.reload()
	
	var script_path := "res://tests/property/temp_pooled_object_%d.gd" % rng.randi()
	ResourceSaver.save(test_script, script_path)
	
	pool.create_pool("test_pool", script_path, 1, 20)
	
	# Acquire and release
	var obj := pool.acquire("test_pool")
	var acquire_called: bool = obj and obj.acquire_count == 1
	
	pool.release("test_pool", obj)
	var release_called: bool = obj and obj.release_count == 1
	
	pool.clear_all_pools()
	pool.free()
	
	if ResourceLoader.exists(script_path):
		DirAccess.remove_absolute(script_path)
	
	return acquire_called and release_called
