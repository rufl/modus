extends ModusGutTestBase

const LOD_SCRIPT = preload("res://game/scripts/features/performance/lod_component.gd")


class LodOnlyEnemy:
	extends Enemy

	func _ready() -> void:
		_setup_lod()
		set_process(false)
		set_physics_process(false)


var viewport: SubViewport
var camera: Camera3D
var target: Node3D
var component: Node


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	target = Node3D.new()
	viewport.add_child(target)
	component = LOD_SCRIPT.new()
	component.optimize_visibility = true
	target.add_child(component)
	component.set_process(false)


func test_active_camera_switch_changes_component_lod() -> void:
	component._update_lod()
	assert_eq(component.current_lod, LOD_SCRIPT.LODLevel.HIGH)
	var replacement := Camera3D.new()
	replacement.position.x = 120.0
	viewport.add_child(replacement)
	replacement.make_current()
	component._update_lod()
	assert_eq(component.current_lod, LOD_SCRIPT.LODLevel.CULL)
	assert_false(target.visible, "Distance culling must follow the newly active camera")
	camera.make_current()
	component._update_lod()
	assert_eq(component.current_lod, LOD_SCRIPT.LODLevel.HIGH)
	assert_true(target.visible, "Switching back must restore visibility")


func test_freed_camera_and_replacement_resume_component_updates() -> void:
	camera.position.x = 120.0
	component._update_lod()
	assert_false(target.visible)
	watch_signals(component)
	camera.free()
	component._update_lod(true)
	assert_signal_emit_count(component, "lod_changed", 0)
	assert_false(target.visible, "Without a camera, preserve the last LOD state")
	var replacement := Camera3D.new()
	viewport.add_child(replacement)
	replacement.make_current()
	component._update_lod()
	assert_eq(component.current_lod, LOD_SCRIPT.LODLevel.HIGH)
	assert_true(target.visible, "A replacement camera must resume distance updates")
	assert_signal_emit_count(component, "lod_changed", 1)


func test_enemy_ready_creates_notifier_and_preserves_ai_elapsed_time() -> void:
	var enemy := LodOnlyEnemy.new()
	viewport.add_child(enemy)
	var lod: Node = enemy.get_node("LODComponent")
	lod.set_process(false)
	var notifier := lod.get_node_or_null("FrustumCuller") as VisibleOnScreenNotifier3D
	assert_not_null(notifier, "Enemy LOD must configure frustum culling before component readiness")
	if not notifier:
		return

	notifier.screen_exited.emit()
	assert_eq(lod.current_lod, LOD_SCRIPT.LODLevel.CULL)
	assert_true(enemy.visible, "Offscreen enemies must throttle AI without hiding network entities")
	assert_eq(enemy.process_mode, Node.PROCESS_MODE_INHERIT)
	enemy.set_update_offset(0.0)
	assert_eq(enemy.consume_ai_update_delta(0.05), 0.0, "Culled AI should defer its update")

	notifier.screen_entered.emit()
	assert_eq(lod.current_lod, LOD_SCRIPT.LODLevel.HIGH)
	assert_almost_eq(
		enemy.consume_ai_update_delta(0.01),
		0.06,
		0.000001,
		"Returning onscreen must retain elapsed time accumulated while throttled"
	)
