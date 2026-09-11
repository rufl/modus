extends ModusGutTestBase

## Integration tests for NetworkEditor synchronization and payload validation.

var _network_editor: Node = null
var _test_scene: Node = null
var _level_root: Node = null
var _original_scene: Node = null
var _signal_received := false
var _received_path := ""


func before_each() -> void:
	await modus_setup()
	var network_service := NetworkSvc.get_service()
	if network_service:
		_network_editor = network_service.network_editor
	if not _network_editor:
		_network_editor = get_node_or_null("/root/NetworkService/NetworkEditor")
	_signal_received = false
	_received_path = ""
	_original_scene = get_tree().current_scene
	_install_level_fixture()

func after_each() -> void:
	if _network_editor and _network_editor.node_deleted.is_connected(_on_node_deleted):
		_network_editor.node_deleted.disconnect(_on_node_deleted)
	if get_tree().current_scene == _test_scene:
		get_tree().current_scene = _original_scene
	if is_instance_valid(_test_scene):
		_test_scene.queue_free()
	await get_tree().process_frame
	_test_scene = null
	_level_root = null
	_original_scene = null
	_network_editor = null
	modus_teardown()


func test_network_editor_exists() -> void:
	assert_not_null(_network_editor, "NetworkEditor should be accessible via NetworkService")


func test_node_deleted_signal_has_path_parameter() -> void:
	assert_not_null(_network_editor, "NetworkEditor is required for deletion synchronization")
	if not _network_editor:
		return

	_network_editor.node_deleted.connect(_on_node_deleted)
	var test_node := _level_root.get_node("TestNode")
	var expected_path: NodePath = test_node.get_path()

	# Invoke the production client-sync handler; do not emit the signal from the test.
	_network_editor._sync_delete_node("TestNode")

	assert_true(_signal_received, "Deleting a level node should emit node_deleted")
	assert_eq(_received_path, str(expected_path), "node_deleted should contain the deleted node path")
	assert_false(_received_path.is_empty(), "Deleted node path should not be empty")
	await get_tree().process_frame
	assert_null(_level_root.get_node_or_null("TestNode"))


func test_node_deleted_signal_definition() -> void:
	assert_not_null(_network_editor, "NetworkEditor is required for signal metadata coverage")
	if not _network_editor:
		return

	var signal_info := _network_editor.get_signal_list().filter(
		func(info: Dictionary) -> bool: return info.get("name") == "node_deleted"
	)
	assert_eq(signal_info.size(), 1, "NetworkEditor should define one node_deleted signal")
	if signal_info.is_empty():
		return

	var args: Array = signal_info[0].get("args", [])
	assert_eq(args.size(), 1, "node_deleted should have exactly one argument")
	if args.size() == 1:
		assert_eq(args[0].get("name"), "path")
		assert_eq(args[0].get("type"), TYPE_STRING)


func test_editor_payload_validation_accepts_editor_shapes() -> void:
	assert_not_null(_network_editor, "NetworkEditor is required for payload validation")
	if not _network_editor:
		return

	assert_true(
		_network_editor._validate_editor_payload(
			"place_block",
			{
				"type": "block_brush",
				"position": Vector3.ZERO,
				"size": Vector3.ONE,
				"material_path": "",
			}
		)
	)
	assert_true(
		_network_editor._validate_editor_payload(
			"place_entity",
			{
				"type": "entity_placer",
				"subtype": "spawn_point",
				"spawn_type": 1,
				"enemy_id": "crawler",
				"position": Vector3.ZERO,
				"rotation_y": 0.0,
			}
		)
	)
	assert_true(
		_network_editor._validate_editor_payload(
			"transform_node", {"path": "Block", "position": Vector3.ONE}
		)
	)


func test_editor_payload_validation_rejects_unsafe_values() -> void:
	assert_not_null(_network_editor, "NetworkEditor is required for payload validation")
	if not _network_editor:
		return

	assert_false(
		_network_editor._validate_editor_payload(
			"place_block",
			{
				"type": "block_brush",
				"position": Vector3(INF, 0.0, 0.0),
				"size": Vector3.ONE,
				"material_path": "",
			}
		)
	)
	assert_false(_network_editor._validate_editor_payload("delete_node", "../root"))
	assert_false(
		_network_editor._validate_editor_payload(
			"paint_block", {"path": "Block", "material_path": "user://untrusted.tres"}
		)
	)


func _install_level_fixture() -> void:
	_test_scene = Node.new()
	_test_scene.name = "NetworkEditorIntegrationScene"
	add_child(_test_scene)
	_level_root = Node.new()
	_level_root.name = "LevelRoot"
	_test_scene.add_child(_level_root)
	var block := Node.new()
	block.name = "Block"
	_level_root.add_child(block)
	var test_node := Node.new()
	test_node.name = "TestNode"
	_level_root.add_child(test_node)
	get_tree().current_scene = _test_scene


func _on_node_deleted(path: String) -> void:
	_signal_received = true
	_received_path = path
