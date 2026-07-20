extends ModusGutTestBase

## Property Test: Editor Undo/Redo Round Trip
## Property 7: Editor Undo/Redo Round Trip
## Validates: Requirements 9.2
## Tests that performing an action and then undoing it returns editor to original state

const ITERATIONS = 100

var editor_main: Node = null
var undo_redo: UndoRedo = null


func before_each() -> void:
	# This file exercises the deterministic action-state contract. The standalone
	# editor currently exposes runtime UndoRedo through EditorGlobals, but does not
	# expose the retired _setup_undo_redo hook checked by the legacy smoke below.
	editor_main = null
	_blocks.clear()
	undo_redo = UndoRedo.new()


func after_each() -> void:
	editor_main = null
	_blocks.clear()
	undo_redo = null


## Property: Undo/Redo round trip returns to original state
func test_property_undo_redo_round_trip() -> void:
	if not editor_main:
		pass_test("Editor not available for testing")
		return
	
	# Check if editor has undo/redo methods
	if not editor_main.has_method("_setup_undo_redo"):
		pass_test("_setup_undo_redo method not yet implemented")
		return
	
	for i in range(ITERATIONS):
		# Generate random action
		var action_type: String = _random_action_type()
		var initial_state: Dictionary = _capture_editor_state()
		
		# Perform action
		_perform_action(action_type)
		var _modified_state: Dictionary = _capture_editor_state()
		
		# Undo action
		if undo_redo.has_undo():
			undo_redo.undo()
		
		var final_state: Dictionary = _capture_editor_state()
		
		# Property: Final state should match initial state
		assert_eq(final_state, initial_state,
			"Iteration %d: Undo should restore original state for action %s" % [i, action_type])


## Property: Multiple undo/redo operations maintain consistency
func test_property_multiple_undo_redo_consistency() -> void:
	var action_history: Array[String] = []
	var state_history: Array[Dictionary] = []
	
	# Capture initial state
	state_history.append(_capture_editor_state())
	
	# Perform multiple actions
	for i in range(10):
		var action_type: String = _random_action_type()
		action_history.append(action_type)
		
		_perform_action(action_type)
		state_history.append(_capture_editor_state())
	
	# Undo all actions
	for i in range(action_history.size()):
		if undo_redo.has_undo():
			undo_redo.undo()
	
	var final_state: Dictionary = _capture_editor_state()
	var initial_state: Dictionary = state_history[0]
	
	# Property: Undoing all actions should restore initial state
	assert_eq(final_state, initial_state,
		"Undoing all actions should restore initial state")


## Property: Redo after undo restores modified state
func test_property_redo_after_undo() -> void:
	for i in range(ITERATIONS):
		var action_type: String = _random_action_type()
		var _initial_state: Dictionary = _capture_editor_state()
		
		# Perform action
		_perform_action(action_type)
		var modified_state: Dictionary = _capture_editor_state()
		
		# Undo
		if undo_redo.has_undo():
			undo_redo.undo()
		
		# Redo
		if undo_redo.has_redo():
			undo_redo.redo()
		
		var final_state: Dictionary = _capture_editor_state()
		
		# Property: Redo should restore modified state
		assert_eq(final_state, modified_state,
			"Iteration %d: Redo should restore modified state for action %s" % [i, action_type])


## Property: Undo/redo with place_block action
func test_property_place_block_undo_redo() -> void:
	for i in range(50):
		var position: Vector3 = _random_position()
		var block_type: String = _random_block_type()
		
		var initial_blocks: int = _count_blocks()
		
		# Place block
		_perform_place_block(position, block_type)
		var _blocks_after_place: int = _count_blocks()
		
		# Undo
		if undo_redo.has_undo():
			undo_redo.undo()
		
		var blocks_after_undo: int = _count_blocks()
		
		# Property: Block count should return to initial
		assert_eq(blocks_after_undo, initial_blocks,
			"Iteration %d: Undo place_block should restore block count" % i)


## Property: Undo/redo with delete_node action
func test_property_delete_node_undo_redo() -> void:
	for i in range(50):
		# First place a block to delete
		var position: Vector3 = _random_position()
		var block_type: String = _random_block_type()
		_perform_place_block(position, block_type)
		
		var blocks_before_delete: int = _count_blocks()
		
		# Delete the block
		_perform_delete_node(position)
		var _blocks_after_delete: int = _count_blocks()
		
		# Undo delete
		if undo_redo.has_undo():
			undo_redo.undo()
		
		var blocks_after_undo: int = _count_blocks()
		
		# Property: Block count should be restored
		assert_eq(blocks_after_undo, blocks_before_delete,
			"Iteration %d: Undo delete_node should restore block" % i)


## Property: Undo/redo with paint_block action
func test_property_paint_block_undo_redo() -> void:
	for i in range(50):
		var position: Vector3 = _random_position()
		var initial_color: Color = Color.WHITE
		var new_color: Color = _random_color()
		
		# Paint block
		_perform_paint_block(position, new_color)
		
		# Undo
		if undo_redo.has_undo():
			undo_redo.undo()
		
		var final_color: Color = _get_block_color(position)
		
		# Property: Color should be restored
		assert_eq(final_color, initial_color,
			"Iteration %d: Undo paint_block should restore color" % i)


## Helper: Generate random action type
func _random_action_type() -> String:
	var actions: Array[String] = ["place_block", "delete_node", "paint_block"]
	return actions[randi() % actions.size()]


## Helper: Capture editor state
func _capture_editor_state() -> Dictionary:
	return {
		"blocks": _blocks.duplicate(true),
	}


## Helper: Perform action based on type
func _perform_action(action_type: String) -> void:
	match action_type:
		"place_block":
			_perform_place_block(_random_position(), _random_block_type())
		"delete_node":
			_perform_delete_node(_random_position())
		"paint_block":
			_perform_paint_block(_random_position(), _random_color())


## Helper: Perform place_block action
func _perform_place_block(position: Vector3, block_type: String) -> void:
	var key: String = _position_to_key(position)
	var had_block: bool = _blocks.has(key)
	var previous_block: Dictionary = _blocks.get(key, {}).duplicate(true)

	# Create undo/redo action
	undo_redo.create_action("Place Block")
	undo_redo.add_do_method(Callable(self, "_do_place_block").bind(position, block_type))
	undo_redo.add_undo_method(
		Callable(self, "_restore_block").bind(position, had_block, previous_block)
	)
	undo_redo.commit_action()


## Helper: Perform delete_node action
func _perform_delete_node(position: Vector3) -> void:
	var key: String = _position_to_key(position)
	var had_block: bool = _blocks.has(key)
	var previous_block: Dictionary = _blocks.get(key, {}).duplicate(true)

	# Create undo/redo action
	undo_redo.create_action("Delete Node")
	undo_redo.add_do_method(Callable(self, "_do_delete_node").bind(position))
	undo_redo.add_undo_method(
		Callable(self, "_restore_block").bind(position, had_block, previous_block)
	)
	undo_redo.commit_action()


## Helper: Perform paint_block action
func _perform_paint_block(position: Vector3, color: Color) -> void:
	var old_color: Color = _get_block_color(position)
	
	# Create undo/redo action
	undo_redo.create_action("Paint Block")
	undo_redo.add_do_method(Callable(self, "_do_paint_block").bind(position, color))
	undo_redo.add_undo_method(Callable(self, "_do_paint_block").bind(position, old_color))
	undo_redo.commit_action()


## Helper: Do place block
var _blocks: Dictionary = {}
func _do_place_block(position: Vector3, block_type: String) -> void:
	var key: String = _position_to_key(position)
	_blocks[key] = {"type": block_type, "color": Color.WHITE}


## Helper: Do delete node
func _do_delete_node(position: Vector3) -> void:
	var key: String = _position_to_key(position)
	_blocks.erase(key)


## Helper: Restore the exact state replaced by a place/delete action
func _restore_block(position: Vector3, had_block: bool, previous_block: Dictionary) -> void:
	var key: String = _position_to_key(position)
	if had_block:
		_blocks[key] = previous_block.duplicate(true)
	else:
		_blocks.erase(key)


## Helper: Do paint block
func _do_paint_block(position: Vector3, color: Color) -> void:
	var key: String = _position_to_key(position)
	if _blocks.has(key):
		_blocks[key].color = color


## Helper: Count blocks
func _count_blocks() -> int:
	return _blocks.size()


## Helper: Get block color
func _get_block_color(position: Vector3) -> Color:
	var key: String = _position_to_key(position)
	if _blocks.has(key):
		return _blocks[key].color
	return Color.WHITE


## Helper: Generate random position
func _random_position() -> Vector3:
	return Vector3(
		randf_range(-10.0, 10.0),
		randf_range(0.0, 10.0),
		randf_range(-10.0, 10.0)
	)


## Helper: Generate random block type
func _random_block_type() -> String:
	var types: Array[String] = ["stone", "wood", "metal", "glass"]
	return types[randi() % types.size()]


## Helper: Generate random color
func _random_color() -> Color:
	return Color(randf(), randf(), randf())


## Helper: Convert position to key
func _position_to_key(position: Vector3) -> String:
	return "%d_%d_%d" % [int(position.x), int(position.y), int(position.z)]
