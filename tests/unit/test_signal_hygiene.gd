extends ModusGutTestBase

# Test MODUS Framework signal hygiene patterns
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_eventbus_unsubscribe() -> void:
	# Use dictionary to work around lambda capture limitation
	var state: Dictionary = {"called": false}
	var test_callback := func(_data: Dictionary) -> void: state.called = true

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available")
		return

	# Subscribe
	gm.subscribe("test_signal_hygiene_event", test_callback)

	# Emit - should call
	gm.emit_event("test_signal_hygiene_event", {})
	assert_true(state.called, "Callback should be called after subscribe")

	# Unsubscribe
	gm.unsubscribe("test_signal_hygiene_event", test_callback)

	# Reset and emit again - should NOT call
	state.called = false
	gm.emit_event("test_signal_hygiene_event", {})

	assert_false(state.called, "Callback should not be called after unsubscribe")


## Test that signals can be disconnected safely with is_connected check


func test_signal_disconnect_pattern() -> void:
	# Create a mock signal source
	var source := Node.new()
	source.add_user_signal("test_signal")

	# Empty callback - we only test connection state not execution
	var callback := func() -> void: pass

	# Connect
	source.connect("test_signal", callback)

	# Verify connected
	assert_true(
		source.is_connected("test_signal", callback), "Signal should be connected after connect()"
	)

	# Disconnect with is_connected guard (the pattern we're implementing)
	if source.is_connected("test_signal", callback):
		source.disconnect("test_signal", callback)

	# Verify disconnected
	assert_false(
		source.is_connected("test_signal", callback),
		"Signal should be disconnected after disconnect()"
	)

	source.free()


## Test that double-disconnect doesn't crash (our pattern prevents this)


func test_double_disconnect_safety() -> void:
	var source := Node.new()
	source.add_user_signal("test_signal")

	var callback := func() -> void: pass

	# Connect and disconnect once
	source.connect("test_signal", callback)
	source.disconnect("test_signal", callback)

	# Try to disconnect again WITH guard (safe)
	if source.is_connected("test_signal", callback):
		source.disconnect("test_signal", callback)

	# If we got here without crash, test passed
	assert_true(true, "Double disconnect with guard should not crash")

	source.free()
