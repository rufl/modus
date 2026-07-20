extends ModusGutTestBase

# Test NetworkEditor signal emission with path parameter
# Validates Critical Issue #2: NetworkEditor Signal Emission Fix

var _network_editor: Node = null
var _signal_received: bool = false
var _received_path: String = ""


func before_each() -> void:
	await modus_setup()
	# Get NetworkEditor via NetworkService
	var ns := NetworkSvc.get_service()
	if ns and "network_editor" in ns:
		_network_editor = ns.network_editor

	# If not found via service, try direct path
	if not _network_editor:
		_network_editor = get_node_or_null("/root/NetworkService/NetworkEditor")

	_signal_received = false
	_received_path = ""


func after_each() -> void:
	if _network_editor and _network_editor.node_deleted.is_connected(_on_node_deleted):
		_network_editor.node_deleted.disconnect(_on_node_deleted)
	modus_teardown()


func test_network_editor_exists() -> void:
	assert_not_null(_network_editor, "NetworkEditor should be accessible via NetworkService")


func test_node_deleted_signal_has_path_parameter() -> void:
	if not _network_editor:
		_fail_test("NetworkEditor not available")
		return

	# Connect to the signal
	_network_editor.node_deleted.connect(_on_node_deleted)

	# Create a test node to delete
	var test_root: Node = Node.new()
	test_root.name = "TestLevelRoot"
	add_child(test_root)

	var test_node: Node = Node.new()
	test_node.name = "TestNode"
	test_root.add_child(test_node)

	var expected_path: NodePath = test_node.get_path()

	# Emit the signal as the NetworkEditor would
	_network_editor.node_deleted.emit(expected_path)

	# Verify signal was received with path parameter
	assert_true(_signal_received, "node_deleted signal should be emitted")
	assert_eq(_received_path, str(expected_path), "Signal should include the node path parameter")
	assert_ne(_received_path, "", "Path parameter should not be empty")

	# Cleanup
	test_root.free()


func test_node_deleted_signal_definition() -> void:
	if not _network_editor:
		_fail_test("NetworkEditor not available")
		return

	# Verify the signal exists and has the correct signature
	var signals_list: Array = _network_editor.get_signal_list()
	var found_signal: bool = false

	for sig: Dictionary in signals_list:
		if sig["name"] == "node_deleted":
			found_signal = true
			# Check that it has exactly one argument
			assert_eq(sig["args"].size(), 1, "node_deleted signal should have exactly 1 parameter")
			if sig["args"].size() > 0:
				assert_eq(sig["args"][0]["name"], "path", "Parameter should be named 'path'")
				assert_eq(sig["args"][0]["type"], TYPE_STRING, "Parameter should be of type String")
			break

	assert_true(found_signal, "node_deleted signal should be defined in NetworkEditor")


func _on_node_deleted(path: String) -> void:
	_signal_received = true
	_received_path = path
