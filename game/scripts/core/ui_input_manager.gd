extends Node
class_name UIInputManager

## Centralized UI input management with proper precedence
## Ensures Pause Menu always has priority over other UIs
## Handles all UI toggles: Pause, Inventory, Skill Tree, etc.

signal pause_menu_opened
signal pause_menu_closed
signal inventory_opened
signal inventory_closed
signal skill_tree_opened
signal skill_tree_closed

enum UIState {
	NONE,
	PAUSE_MENU,  # Highest priority
	INVENTORY,
	SKILL_TREE,
	OPTIONS,
	SAVE_LOAD,
	INTERMISSION,
}

var current_ui_state: UIState = UIState.NONE
var ui_stack: Array[UIState] = []  # Stack of open UIs
var ui_manager: Node = null


func _ready() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	name = "UIInputManager"

	# Process even when paused (for pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Find UI manager
	_find_ui_manager()


func _exit_tree() -> void:
	## === SIGNAL HYGIENE: Cleanup to prevent memory leaks ===
	# Note: Most signals are emitted by this class, not connected to external sources
	# But we should clear any internal state

	ui_stack.clear()
	current_ui_state = UIState.NONE
	ui_manager = null

	_log("UIInputManager cleanup complete")


func _find_ui_manager() -> void:
	## Find UI manager from UI service
	var ui_service := GameManager.get_core_system("ui")
	if ui_service and ui_service.get("ui_manager"):
		ui_manager = ui_service.ui_manager


func _input(event: InputEvent) -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	# CRITICAL: Pause always has highest priority
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_handle_pause_input()
		get_viewport().set_input_as_handled()
		return

	# Don't handle other inputs if paused (unless it's pause menu itself)
	if get_tree().paused and current_ui_state != UIState.PAUSE_MENU:
		return

	# Handle other UI toggles (only if not in pause menu)
	if current_ui_state != UIState.PAUSE_MENU:
		if event.is_action_pressed("inventory"):
			_handle_inventory_input()
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("skill_tree"):
			_handle_skill_tree_input()
			get_viewport().set_input_as_handled()
			return


func _handle_pause_input() -> void:
	## Handle pause/unpause with proper precedence

	# If pause menu is open, close it
	if current_ui_state == UIState.PAUSE_MENU:
		close_pause_menu()
		return

	# If any other UI is open, close it first, then open pause
	if current_ui_state != UIState.NONE:
		_close_current_ui()

	# Open pause menu
	open_pause_menu()


func _handle_inventory_input() -> void:
	## Toggle inventory
	if current_ui_state == UIState.INVENTORY:
		close_inventory()
	else:
		# Close current UI if any
		if current_ui_state != UIState.NONE:
			_close_current_ui()
		open_inventory()


func _handle_skill_tree_input() -> void:
	## Toggle skill tree
	if current_ui_state == UIState.SKILL_TREE:
		close_skill_tree()
	else:
		# Close current UI if any
		if current_ui_state != UIState.NONE:
			_close_current_ui()
		open_skill_tree()


# =============================================================================
# PAUSE MENU
# =============================================================================


func open_pause_menu() -> void:
	## Open pause menu (highest priority)
	if current_ui_state == UIState.PAUSE_MENU:
		return

	# Close any other UI first
	if current_ui_state != UIState.NONE:
		_close_current_ui()

	# Open pause menu via UI manager
	if ui_manager and ui_manager.has_method("push_screen"):
		var pause_path := "res://shared/ui_core/screens/pause_screen.tscn"
		ui_manager.push_screen(pause_path)

		_set_ui_state(UIState.PAUSE_MENU)
		pause_menu_opened.emit()

		_log("Pause menu opened")
	else:
		# Fallback: Just pause the game
		get_tree().paused = true
		_set_ui_state(UIState.PAUSE_MENU)
		_log("Game paused (no UI manager)")


func close_pause_menu() -> void:
	## Close pause menu
	if current_ui_state != UIState.PAUSE_MENU:
		return

	# Close via UI manager
	if ui_manager and ui_manager.has_method("pop_screen"):
		ui_manager.pop_screen()
	else:
		# Fallback: Just unpause
		get_tree().paused = false

	_set_ui_state(UIState.NONE)
	pause_menu_closed.emit()

	_log("Pause menu closed")


# =============================================================================
# INVENTORY
# =============================================================================


func open_inventory() -> void:
	## Open inventory UI
	if current_ui_state == UIState.INVENTORY:
		return

	# Find inventory UI
	var inventory_ui := _find_inventory_ui()
	if inventory_ui and inventory_ui.has_method("open_inventory"):
		inventory_ui.open_inventory()

		_set_ui_state(UIState.INVENTORY)
		inventory_opened.emit()

		_log("Inventory opened")
	else:
		_log("Inventory UI not found")


func close_inventory() -> void:
	## Close inventory UI
	if current_ui_state != UIState.INVENTORY:
		return

	var inventory_ui := _find_inventory_ui()
	if inventory_ui and inventory_ui.has_method("close_inventory"):
		inventory_ui.close_inventory()

	_set_ui_state(UIState.NONE)
	inventory_closed.emit()

	_log("Inventory closed")


func _find_inventory_ui() -> Node:
	## Find inventory UI in scene tree
	# Try common paths
	var paths := [
		"/root/UILayer/InventoryUI",
		"/root/World/UILayer/InventoryUI",
	]

	for path: String in paths:
		var node := get_node_or_null(path)
		if node:
			return node

	# Search in tree
	return get_tree().root.find_child("InventoryUI", true, false)


# =============================================================================
# SKILL TREE
# =============================================================================


func open_skill_tree() -> void:
	## Open skill tree UI
	if current_ui_state == UIState.SKILL_TREE:
		return

	# Find skill tree UI
	var skill_tree_ui := _find_skill_tree_ui()
	if skill_tree_ui and skill_tree_ui.has_method("open_skill_tree"):
		skill_tree_ui.open_skill_tree()

		_set_ui_state(UIState.SKILL_TREE)
		skill_tree_opened.emit()

		_log("Skill tree opened")
	else:
		_log("Skill tree UI not found")


func close_skill_tree() -> void:
	## Close skill tree UI
	if current_ui_state != UIState.SKILL_TREE:
		return

	var skill_tree_ui := _find_skill_tree_ui()
	if skill_tree_ui and skill_tree_ui.has_method("close_skill_tree"):
		skill_tree_ui.close_skill_tree()

	_set_ui_state(UIState.NONE)
	skill_tree_closed.emit()

	_log("Skill tree closed")


func _find_skill_tree_ui() -> Node:
	## Find skill tree UI in scene tree
	# Try common paths
	var paths := [
		"/root/UILayer/SkillTreeUI",
		"/root/World/UILayer/SkillTreeUI",
	]

	for path: String in paths:
		var node := get_node_or_null(path)
		if node:
			return node

	# Search in tree
	return get_tree().root.find_child("SkillTreeUI", true, false)


# =============================================================================
# UTILITY
# =============================================================================


func _close_current_ui() -> void:
	## Close currently open UI
	match current_ui_state:
		UIState.PAUSE_MENU:
			close_pause_menu()
		UIState.INVENTORY:
			close_inventory()
		UIState.SKILL_TREE:
			close_skill_tree()
		_:
			_set_ui_state(UIState.NONE)


func _set_ui_state(new_state: UIState) -> void:
	## Set current UI state
	var old_state := current_ui_state
	current_ui_state = new_state

	# Manage UI stack
	if new_state != UIState.NONE:
		if not ui_stack.has(new_state):
			ui_stack.append(new_state)
	else:
		if old_state != UIState.NONE:
			ui_stack.erase(old_state)


func is_any_ui_open() -> bool:
	## Check if any UI is currently open
	return current_ui_state != UIState.NONE


func get_current_ui() -> UIState:
	## Get current UI state
	return current_ui_state


func force_close_all_uis() -> void:
	## Force close all UIs (for game state transitions)
	while current_ui_state != UIState.NONE:
		_close_current_ui()

	ui_stack.clear()
	_log("All UIs force closed")


func _log(message: String) -> void:
	## Safe logging
	if Engine.is_editor_hint():
		return

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info("[UIInputManager] %s" % message, "UI")
