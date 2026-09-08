extends ModusGutTestBase

const LOD_SCRIPT = preload("res://game/scripts/features/performance/lod_manager.gd")


class ManagedEntity:
	extends Node3D
	var level: int = -1
	var updates: int = 0

	func set_lod_level(value: int) -> void:
		level = value
		updates += 1


var viewport: SubViewport
var manager: Node
var camera: Camera3D
var entity: ManagedEntity


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	manager = LOD_SCRIPT.new()
	viewport.add_child(manager)
	manager.set_process(false)
	manager.enable_culling = false
	entity = ManagedEntity.new()
	viewport.add_child(entity)
	manager.register_entity(entity)


func test_updates_wait_for_configured_interval() -> void:
	manager.lod_update_interval = 0.25
	manager._process(0.1)
	assert_eq(entity.updates, 0)
	manager._process(0.15)
	assert_eq(entity.updates, 1)


func test_distance_boundaries_reach_managed_entity() -> void:
	for level in range(4):
		var boundary: float = manager.LOD_DISTANCES[level]
		entity.position.x = boundary - 0.01
		manager._process(0.25)
		assert_eq(entity.level, level)
		entity.position.x = boundary
		manager._process(0.25)
		assert_eq(entity.level, level + 1)


func test_bias_changes_distance_selection() -> void:
	entity.position.x = 20.0
	manager._process(0.25)
	assert_eq(entity.level, 1)
	manager.set_lod_bias(2.0)
	manager._process(0.25)
	assert_eq(entity.level, 0)


func test_registration_is_unique_and_unregister_stops_updates() -> void:
	manager.register_entity(entity)
	manager._process(0.25)
	assert_eq(entity.updates, 1)
	manager.unregister_entity(entity)
	manager._process(0.25)
	assert_eq(entity.updates, 1)


func test_active_camera_switch_changes_entity_lod() -> void:
	manager._process(0.25)
	assert_eq(entity.level, 0)
	var replacement := Camera3D.new()
	viewport.add_child(replacement)
	replacement.position.x = 60.0
	replacement.make_current()
	manager._process(0.25)
	assert_eq(entity.level, 3, "LOD should follow the newly active camera")


func test_camera_teardown_and_replacement_resume_updates() -> void:
	manager._process(0.25)
	camera.free()
	manager._process(0.25)
	assert_eq(entity.updates, 1, "No camera means no LOD update")
	var replacement := Camera3D.new()
	viewport.add_child(replacement)
	replacement.position.x = 35.0
	replacement.make_current()
	manager._process(0.25)
	assert_eq(entity.level, 2, "Updates should resume from the replacement camera")
