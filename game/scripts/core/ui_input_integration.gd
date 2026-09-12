extends Node

## Quick integration helper to connect UI inputs to UIInputManager
## Add this as autoload or call from GameManager


static func integrate_ui_inputs() -> void:
	## Connect all UI input signals to UIInputManager

	# Find UIInputManager
	var ui_input_mgr := _find_ui_input_manager()
	if not ui_input_mgr:
		push_error("[UIInputIntegration] UIInputManager not found!")
		return

	# Find player
	var player := _find_local_player()
	if not player:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.process_frame.connect(integrate_ui_inputs, CONNECT_ONE_SHOT)
		return

	# Connect input signals
	_connect_player_inputs(player, ui_input_mgr)

	print("[UIInputIntegration] UI inputs integrated successfully")


static func _find_ui_input_manager() -> Node:
	## Find UIInputManager in scene tree
	var paths: Array[String] = [
		"/root/GameManager/UIInputManager",
		"/root/UIInputManager",
	]

	for path: String in paths:
		var node: Node = Engine.get_main_loop().root.get_node_or_null(path) as Node
		if node:
			return node

	# Search in tree
	var result: Node = Engine.get_main_loop().root.find_child("UIInputManager", true, false) as Node
	return result


static func _find_local_player() -> Node:
	## Find player in the scene tree using the canonical group and legacy alias.
	var world: Node = Engine.get_main_loop().root.find_child("World", true, false) as Node
	if not world:
		return null

	var players_array: Array = world.get_tree().get_nodes_in_group("player")
	if players_array.is_empty():
		players_array = world.get_tree().get_nodes_in_group("players")
	for player: Node in players_array:
		if player.has_method("is_multiplayer_authority"):
			if player.is_multiplayer_authority():
				return player
		else:
			# Singleplayer - return first player
			return player

	return null


static func _connect_player_inputs(player: Node, ui_input_mgr: Node) -> void:
	## Connect player input signals to UIInputManager

	var input_comp := player.get_node_or_null("PlayerInputComponent")
	if not input_comp:
		push_warning("[UIInputIntegration] PlayerInputComponent not found on player")
		return

	# Pause (already handled by UIInputManager._input, but can connect for consistency)
	if input_comp.has_signal("pause_toggled"):
		if not input_comp.is_connected("pause_toggled", ui_input_mgr.open_pause_menu):
			input_comp.pause_toggled.connect(ui_input_mgr.open_pause_menu)

	# Inventory
	if input_comp.has_signal("inventory_toggled"):
		if not input_comp.is_connected("inventory_toggled", _on_inventory_toggle):
			input_comp.inventory_toggled.connect(_on_inventory_toggle.bind(ui_input_mgr))

	# Skill Tree
	if input_comp.has_signal("skill_tree_toggled"):
		if not input_comp.is_connected("skill_tree_toggled", _on_skill_tree_toggle):
			input_comp.skill_tree_toggled.connect(_on_skill_tree_toggle.bind(ui_input_mgr))


static func _on_inventory_toggle(ui_input_mgr: Node) -> void:
	## Toggle inventory via UIInputManager
	# Check current state using get() to avoid class reference issues
	var current_state: int = ui_input_mgr.get("current_ui_state")
	var inventory_state: int = 4  # UIInputManager.UIState.INVENTORY

	if current_state == inventory_state:
		ui_input_mgr.close_inventory()
	else:
		ui_input_mgr.open_inventory()


static func _on_skill_tree_toggle(ui_input_mgr: Node) -> void:
	## Toggle skill tree via UIInputManager
	# Check current state using get() to avoid class reference issues
	var current_state: int = ui_input_mgr.get("current_ui_state")
	var skill_tree_state: int = 5  # UIInputManager.UIState.SKILL_TREE

	if current_state == skill_tree_state:
		ui_input_mgr.close_skill_tree()
	else:
		ui_input_mgr.open_skill_tree()
