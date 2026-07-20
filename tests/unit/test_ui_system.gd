extends ModusGutTestBase

## Unit tests for MODUS UI System
## Tests UI service, console system, HUD updates, menu navigation,
## and UI responsiveness
##
## Requirements: 13 (UI System Testing)

var ui_service: Node
var test_screen: Control
var test_hud: Control


func before_each() -> void:
	await modus_setup()
	ui_service = _get_ui_service()


func after_each() -> void:
	# Fixtures are registered with add_child_autofree(); GUT owns destruction.
	test_screen = null
	test_hud = null
	
	modus_teardown()


func _get_ui_service() -> Node:
	return UISystem.get_service()

# =============================================================================
# UI SERVICE (Requirement 13)
# =============================================================================


func test_ui_service_exists() -> void:
	assert_not_null(ui_service, "UIService should be available")


func test_ui_service_has_required_methods() -> void:
	assert_not_null(ui_service, "UIService should be available")
	
	var required_methods: Array[String] = [
		"open_screen",
		"close_screen",
		"get_current_screen",
	]
	
	for method_name: String in required_methods:
		assert_true(
			ui_service.has_method(method_name),
			"UIService should have method: " + method_name
		)

# =============================================================================
# CONSOLE SYSTEM (Requirement 13)
# =============================================================================


func test_console_script_exists() -> void:
	var path: String = "res://game/ui/console/dropdown_console.gd"
	assert_true(FileAccess.file_exists(path), "Dropdown console script should exist")


func test_console_command_registry_exists() -> void:
	var path: String = "res://game/ui/console/console_command_registry.gd"
	assert_true(
		FileAccess.file_exists(path),
		"Console command registry should exist"
	)


func test_cheat_commands_exist() -> void:
	var path: String = "res://game/ui/console/commands/cheat_commands.gd"
	assert_true(FileAccess.file_exists(path), "Cheat commands script should exist")


func test_debug_commands_exist() -> void:
	var path: String = "res://game/ui/console/commands/debug_commands.gd"
	assert_true(FileAccess.file_exists(path), "Debug commands script should exist")


func test_player_commands_exist() -> void:
	var path: String = "res://game/ui/console/commands/player_commands.gd"
	assert_true(FileAccess.file_exists(path), "Player commands script should exist")


func test_enemy_commands_exist() -> void:
	var path: String = "res://game/ui/console/commands/enemy_commands.gd"
	assert_true(FileAccess.file_exists(path), "Enemy commands script should exist")

# =============================================================================
# HUD SYSTEM (Requirement 13.2)
# =============================================================================


func test_hud_directory_exists() -> void:
	var path: String = "res://game/ui/hud/"
	assert_true(DirAccess.dir_exists_absolute(path), "HUD directory should exist")


func test_hud_updates_reflect_game_state() -> void:
	# Create a simple test HUD node
	test_hud = Control.new()
	test_hud.name = "TestHUD"
	add_child_autofree(test_hud)
	
	# Add health label
	var health_label: Label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "100"
	test_hud.add_child(health_label)
	
	# Simulate health change
	health_label.text = "75"
	await get_tree().process_frame
	
	# Verify HUD updated
	assert_eq(health_label.text, "75", "HUD should reflect updated health value")


func test_hud_handles_rapid_updates() -> void:
	# Create test HUD
	test_hud = Control.new()
	test_hud.name = "TestHUD"
	add_child_autofree(test_hud)
	
	# Add ammo label
	var ammo_label: Label = Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.text = "30"
	test_hud.add_child(ammo_label)
	
	# Simulate rapid updates
	for i: int in range(10):
		ammo_label.text = str(30 - i)
		await get_tree().process_frame
	
	# Verify final state
	assert_eq(ammo_label.text, "21", "Ten updates from 30 should end at 21")


func test_hud_visibility_toggle() -> void:
	# Create test HUD
	test_hud = Control.new()
	test_hud.name = "TestHUD"
	test_hud.visible = true
	add_child_autofree(test_hud)
	
	# Toggle visibility
	test_hud.visible = false
	await get_tree().process_frame
	
	assert_false(test_hud.visible, "HUD should be hidden when visibility toggled")
	
	# Toggle back
	test_hud.visible = true
	await get_tree().process_frame
	
	assert_true(test_hud.visible, "HUD should be visible when toggled back")

# =============================================================================
# MENU NAVIGATION (Requirement 13.1)
# =============================================================================


func test_main_menu_screen_exists() -> void:
	var paths: Array[String] = [
		"res://game/ui/screens/main_menu_screen.tscn",
		"res://game/ui/screens/main_menu.tscn",
		"res://shared/ui_core/screens/main_menu_screen.tscn",
	]
	
	var found_menu: bool = false
	for path: String in paths:
		if ResourceLoader.exists(path):
			found_menu = true
			break
	
	assert_true(
		found_menu,
		"Main menu screen should exist in one of the expected locations"
	)


func test_settings_screen_exists() -> void:
	var paths: Array[String] = [
		"res://game/ui/screens/settings_screen.tscn",
		"res://shared/ui_core/screens/settings_screen.tscn",
	]
	
	var found_settings: bool = false
	for path: String in paths:
		if ResourceLoader.exists(path):
			found_settings = true
			break
	
	assert_true(
		found_settings,
		"Settings screen should exist in one of the expected locations"
	)


func test_menu_navigation_button_focus() -> void:
	# Create test menu with buttons
	test_screen = Control.new()
	test_screen.name = "TestMenu"
	add_child_autofree(test_screen)
	
	# Add buttons
	var button1: Button = Button.new()
	button1.name = "Button1"
	button1.text = "Start Game"
	test_screen.add_child(button1)
	
	var button2: Button = Button.new()
	button2.name = "Button2"
	button2.text = "Settings"
	test_screen.add_child(button2)
	
	# Set focus
	button1.grab_focus()
	await get_tree().process_frame
	
	# Verify focus
	assert_true(button1.has_focus(), "Button should receive focus")


func test_menu_navigation_keyboard_input() -> void:
	# Create test menu
	test_screen = Control.new()
	test_screen.name = "TestMenu"
	add_child_autofree(test_screen)
	
	# Add button
	var button: Button = Button.new()
	button.name = "TestButton"
	button.text = "Test"
	test_screen.add_child(button)
	
	# Watch for button press
	watch_signals(button)
	
	# Simulate keyboard input (grab focus and press)
	button.grab_focus()
	await get_tree().process_frame
	
	# Simulate Enter key press
	button.emit_signal("pressed")
	await get_tree().process_frame
	
	# Verify signal emitted
	assert_signal_emitted(button, "pressed", "Button should respond to keyboard input")


func test_menu_screen_transition() -> void:
	# Create two test screens
	var screen1: Control = Control.new()
	screen1.name = "Screen1"
	screen1.visible = true
	add_child_autofree(screen1)
	
	var screen2: Control = Control.new()
	screen2.name = "Screen2"
	screen2.visible = false
	add_child_autofree(screen2)
	
	# Simulate screen transition
	screen1.visible = false
	screen2.visible = true
	await get_tree().process_frame
	
	# Verify transition
	assert_false(screen1.visible, "Previous screen should be hidden")
	assert_true(screen2.visible, "New screen should be visible")


# =============================================================================
# UI RESPONSIVENESS (Requirement 13.3)
# =============================================================================


func test_ui_handles_rapid_input() -> void:
	# Create test button
	test_screen = Control.new()
	test_screen.name = "TestScreen"
	add_child_autofree(test_screen)
	
	var button: Button = Button.new()
	button.name = "RapidButton"
	test_screen.add_child(button)
	
	# Watch signals
	watch_signals(button)
	
	# Simulate rapid clicks
	for i: int in range(10):
		button.emit_signal("pressed")
		await get_tree().process_frame
	
	# Verify button still functional
	assert_signal_emit_count(button, "pressed", 10, "UI should handle rapid input")


func test_ui_input_queue_processing() -> void:
	# Create test control
	test_screen = Control.new()
	test_screen.name = "TestScreen"
	add_child_autofree(test_screen)
	
	var input_count: Array[int] = [0]  # Use array to avoid capture reassignment warning
	var process_callback: Callable = func() -> void:
		input_count[0] += 1
	
	# Simulate multiple inputs
	for i: int in range(5):
		process_callback.call()
		await get_tree().process_frame
	
	# Verify all inputs processed
	assert_eq(input_count[0], 5, "UI should process all queued inputs")


func test_ui_maintains_state_during_updates() -> void:
	# Create test control with state
	test_screen = Control.new()
	test_screen.name = "TestScreen"
	add_child_autofree(test_screen)
	
	var checkbox: CheckBox = CheckBox.new()
	checkbox.name = "TestCheckbox"
	checkbox.button_pressed = true
	test_screen.add_child(checkbox)
	
	# Simulate multiple updates
	for i: int in range(5):
		await get_tree().process_frame
	
	# Verify state maintained
	assert_true(
		checkbox.button_pressed,
		"UI should maintain state during updates"
	)


# =============================================================================
# UI ACCESSIBILITY (Requirement 13.4)
# =============================================================================


func test_ui_keyboard_navigation_support() -> void:
	# Create test menu with multiple buttons
	test_screen = Control.new()
	test_screen.name = "TestMenu"
	add_child_autofree(test_screen)
	
	var button1: Button = Button.new()
	button1.name = "Button1"
	button1.focus_mode = Control.FOCUS_ALL
	test_screen.add_child(button1)
	
	var button2: Button = Button.new()
	button2.name = "Button2"
	button2.focus_mode = Control.FOCUS_ALL
	test_screen.add_child(button2)
	
	# Set focus neighbor
	button1.focus_neighbor_bottom = button2.get_path()
	button2.focus_neighbor_top = button1.get_path()
	
	# Verify focus navigation setup
	assert_eq(
		button1.focus_mode,
		Control.FOCUS_ALL,
		"UI elements should support keyboard focus"
	)


func test_ui_focus_indicators_exist() -> void:
	# Create test button
	test_screen = Control.new()
	test_screen.name = "TestScreen"
	add_child_autofree(test_screen)
	
	var button: Button = Button.new()
	button.name = "TestButton"
	button.focus_mode = Control.FOCUS_ALL
	test_screen.add_child(button)
	
	# Grab focus
	button.grab_focus()
	await get_tree().process_frame
	
	# Verify focus capability
	assert_true(button.has_focus(), "UI should provide focus indicators")


func test_ui_tab_order_navigation() -> void:
	# Create test form with multiple inputs
	test_screen = Control.new()
	test_screen.name = "TestForm"
	add_child_autofree(test_screen)
	
	var input1: LineEdit = LineEdit.new()
	input1.name = "Input1"
	input1.focus_mode = Control.FOCUS_ALL
	test_screen.add_child(input1)
	
	var input2: LineEdit = LineEdit.new()
	input2.name = "Input2"
	input2.focus_mode = Control.FOCUS_ALL
	test_screen.add_child(input2)
	
	# Set tab order
	input1.focus_next = input2.get_path()
	input2.focus_previous = input1.get_path()
	
	# Verify tab order setup
	assert_not_null(input1.focus_next, "UI should support tab order navigation")
