extends ModusGutTestBase

# Test MODUS Framework EventBus functionality
# Converted from legacy Dictionary format to GUT assertions

class TestState:
	extends RefCounted
	var received: bool = false
	var data: Dictionary = {}
	var count: int = 0

func before_each():
	await modus_setup()

func after_each():
	modus_teardown()

func test_subscribe_and_emit() -> void:
	var state: TestState = TestState.new()

	var callback: Callable = func(data: Dictionary) -> void:
		state.received = true
		state.data = data

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available")
		return

	gm.subscribe("test_event", callback)
	gm.emit_event("test_event", {"value": 42})

	# Cleanup
	gm.unsubscribe("test_event", callback)

	assert_true(state.received, "Event should be received")
	assert_eq(state.data.get("value"), 42, "Event data should match")

func test_unsubscribe() -> void:
	var state: TestState = TestState.new()

	var callback: Callable = func(_data: Dictionary) -> void: state.count += 1

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available")
		return

	gm.subscribe("test_unsub", callback)
	gm.emit_event("test_unsub", {})

	assert_eq(state.count, 1, "First emit should trigger callback")

	gm.unsubscribe("test_unsub", callback)
	gm.emit_event("test_unsub", {})

	assert_eq(state.count, 1, "Callback should not be called after unsubscribe")

func test_multiple_listeners() -> void:
	var state_a: TestState = TestState.new()
	var state_b: TestState = TestState.new()

	var callback_a: Callable = func(_data: Dictionary) -> void: state_a.count += 1
	var callback_b: Callable = func(_data: Dictionary) -> void: state_b.count += 1

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available")
		return

	gm.subscribe("test_multi", callback_a)
	gm.subscribe("test_multi", callback_b)
	gm.emit_event("test_multi", {})

	# Cleanup
	gm.unsubscribe("test_multi", callback_a)
	gm.unsubscribe("test_multi", callback_b)

	assert_eq(state_a.count, 1, "First listener should be called")
	assert_eq(state_b.count, 1, "Second listener should be called")
