extends Node

## Handles menu toggle logic (skill tree, inventory).
## Manages mouse capture state and status component updates.

var _player: Node = null
var _input_component: Node = null
var _status_component: Node = null
var _skill_manager: SkillTreeManager = null


func setup(
	player: Node, input_component: Node, status_component: Node, skill_manager: SkillTreeManager
) -> void:
	_player = player
	_input_component = input_component
	_status_component = status_component
	_skill_manager = skill_manager

	if _input_component:
		_input_component.skill_tree_toggled.connect(_toggle_skill_tree)
		_input_component.inventory_toggled.connect(_toggle_inventory)


func _exit_tree() -> void:
	if _input_component:
		if _input_component.skill_tree_toggled.is_connected(_toggle_skill_tree):
			_input_component.skill_tree_toggled.disconnect(_toggle_skill_tree)
		if _input_component.inventory_toggled.is_connected(_toggle_inventory):
			_input_component.inventory_toggled.disconnect(_toggle_inventory)


func _toggle_skill_tree() -> void:
	if not _skill_manager:
		return

	var skill_tree_ui: Control = get_tree().get_first_node_in_group("skill_tree_ui")

	if skill_tree_ui:
		skill_tree_ui.visible = not skill_tree_ui.visible
		if _status_component:
			_status_component.set_in_menu(skill_tree_ui.visible)
	else:
		GameManager.emit_event("skill_tree_toggled", {})


func _toggle_inventory() -> void:
	var hud_layer: CanvasLayer = _player.get_node_or_null("HUDLayer")
	if not hud_layer:
		return

	var inventory_ui: Control = hud_layer.get_node_or_null("InventoryUI")
	if not inventory_ui:
		return

	inventory_ui.visible = not inventory_ui.visible
	if _status_component:
		_status_component.set_in_menu(inventory_ui.visible)

	if _input_component:
		_input_component.set_mouse_captured(not inventory_ui.visible)
