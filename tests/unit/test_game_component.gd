extends GutTest

const MockGameComponent = preload("res://tests/mocks/mock_game_component.gd")

# Unit tests for GameComponent base class
# Requirements: 4.3


# Test helper: Mock entity node
class MockEntity:
	extends Node

	func _init() -> void:
		name = "MockEntity"


func before_each() -> void:
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	# Cleanup any test nodes
	for child in get_tree().root.get_children():
		if child.name == "MockEntity":
			child.free()


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================


func test_component_starts_enabled() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	assert_true(component.enabled, "Component should start enabled")
	assert_true(component.is_enabled(), "is_enabled() should return true")
	component.free()


func test_component_starts_not_ready() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	assert_false(component.is_ready(), "Component should start not ready")
	component.free()


func test_component_sets_component_id() -> void:
	var component: MockGameComponent = MockGameComponent.new("health")
	assert_eq(component.component_id, "health", "Component ID should be set")
	component.free()


func test_component_ready_lifecycle() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)

	await get_tree().process_frame

	assert_true(component.is_ready(), "Component should be ready after _ready()")
	assert_true(component.ready_called, "Subclass _component_ready should be called")
	assert_eq(component.entity, entity, "Entity reference should be set to parent")

	entity.free()


func test_component_ready_emits_signal() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	watch_signals(component)
	entity.add_child(component)

	await get_tree().process_frame

	assert_signal_emitted(component, "component_ready")

	entity.free()


# =============================================================================
# ENABLE/DISABLE TESTS
# =============================================================================


func test_component_set_enabled_to_false() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	component.set_enabled(false)

	assert_false(component.enabled, "Component should be disabled")
	assert_false(component.is_enabled(), "is_enabled() should return false")
	assert_true(component.disabled_called, "Subclass _on_disabled should be called")
	component.free()


func test_component_set_enabled_to_true() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	component.set_enabled(false)
	component.enabled_called = false  # Reset flag

	component.set_enabled(true)

	assert_true(component.enabled, "Component should be enabled")
	assert_true(component.is_enabled(), "is_enabled() should return true")
	assert_true(component.enabled_called, "Subclass _on_enabled should be called")
	component.free()


func test_component_set_enabled_same_value_no_callback() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	component.enabled_called = false

	# Setting to true when already true should not trigger callback
	component.set_enabled(true)

	assert_false(component.enabled_called, "Callback should not be called for same value")
	component.free()


func test_component_disable_emits_signal() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	watch_signals(component)

	component.set_enabled(false)

	assert_signal_emitted(component, "component_disabled")
	component.free()


func test_component_enable_emits_signal() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	component.set_enabled(false)
	watch_signals(component)

	component.set_enabled(true)

	assert_signal_emitted(component, "component_enabled")
	component.free()


# =============================================================================
# PROCESS TESTS
# =============================================================================


func test_component_process_called_when_enabled() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(component.process_called, "Process should be called when enabled")

	entity.free()


func test_component_process_not_called_when_disabled() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)
	component.set_enabled(false)

	await get_tree().process_frame
	component.process_called = false  # Reset after ready frame
	await get_tree().process_frame

	assert_false(component.process_called, "Process should not be called when disabled")

	entity.free()


func test_component_physics_process_called_when_enabled() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)

	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(component.physics_process_called, "Physics process should be called when enabled")

	entity.free()


func test_component_physics_process_not_called_when_disabled() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)
	component.set_enabled(false)

	await get_tree().physics_frame
	component.physics_process_called = false  # Reset after ready frame
	await get_tree().physics_frame

	assert_false(
		component.physics_process_called, "Physics process should not be called when disabled"
	)

	entity.free()


# =============================================================================
# CONFIGURATION TESTS
# =============================================================================


func test_component_load_config() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	var test_config: Dictionary = {"max_health": 100, "speed": 5.0}

	component.load_config(test_config)

	assert_eq(component.config, test_config, "Config should be loaded")
	assert_true(component.config_loaded_called, "Subclass _on_config_loaded should be called")
	component.free()


func test_component_load_config_emits_signal() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	watch_signals(component)

	component.load_config({"test": "value"})

	assert_signal_emitted(component, "config_reloaded")
	component.free()


func test_component_get_config_value_with_default() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	component.config = {"damage": 50, "range": 10.0}

	assert_eq(component.get_config_value("damage"), 50, "Should return config value")
	assert_eq(component.get_config_value("range"), 10.0, "Should return float config value")
	assert_eq(
		component.get_config_value("missing_key", 42), 42, "Should return default for missing key"
	)
	assert_null(
		component.get_config_value("missing_key"), "Should return null when no default provided"
	)
	component.free()


func test_component_empty_config() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	component.load_config({})

	assert_eq(component.config, {}, "Empty config should be loaded")
	assert_null(component.get_config_value("any_key"), "Empty config should return null")
	component.free()


func test_component_config_with_nested_values() -> void:
	var component: MockGameComponent = MockGameComponent.new()
	var nested_config: Dictionary = {"weapon": {"damage": 50, "range": 10.0}, "enabled": true}

	component.load_config(nested_config)

	var weapon_config: Dictionary = component.get_config_value("weapon", {})
	assert_eq(weapon_config.get("damage"), 50, "Should retrieve nested dictionary")
	assert_eq(component.get_config_value("enabled"), true, "Should retrieve boolean")
	component.free()


# =============================================================================
# CLEANUP TESTS
# =============================================================================


func test_component_cleanup_called_on_exit_tree() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)

	await get_tree().process_frame

	# Verify component is in tree before removal
	assert_true(component.is_inside_tree(), "Component should be in tree")

	# Remove from tree (this triggers _exit_tree which calls cleanup)
	entity.remove_child(component)

	# Now we can check cleanup_called since component still exists
	assert_true(component.cleanup_called, "Cleanup should be called on exit tree")

	# Clean up
	component.free()
	entity.free()


# =============================================================================
# INTEGRATION TESTS
# =============================================================================


func test_component_full_lifecycle() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new("test")

	# Initial state
	assert_false(component.is_ready(), "Should start not ready")
	assert_true(component.is_enabled(), "Should start enabled")

	# Add to tree
	add_child(entity)
	entity.add_child(component)
	await get_tree().process_frame

	# After ready
	assert_true(component.is_ready(), "Should be ready after _ready()")
	assert_true(component.ready_called, "Ready callback should be called")
	assert_eq(component.entity, entity, "Entity reference should be set")

	# Load config
	component.load_config({"test": "value"})
	assert_true(component.config_loaded_called, "Config loaded callback should be called")

	# Disable
	component.set_enabled(false)
	assert_false(component.is_enabled(), "Should be disabled")
	assert_true(component.disabled_called, "Disabled callback should be called")

	# Enable
	component.set_enabled(true)
	assert_true(component.is_enabled(), "Should be enabled")
	assert_true(component.enabled_called, "Enabled callback should be called")

	# Cleanup - remove from tree to trigger _exit_tree
	entity.remove_child(component)
	assert_true(component.cleanup_called, "Cleanup should be called on exit tree")

	# Clean up
	component.free()
	entity.free()


func test_component_toggle_enable_during_runtime() -> void:
	var entity: MockEntity = MockEntity.new()
	var component: MockGameComponent = MockGameComponent.new()

	add_child(entity)
	entity.add_child(component)
	await get_tree().process_frame

	# Process should be called when enabled
	component.process_called = false
	await get_tree().process_frame
	assert_true(component.process_called, "Process should be called when enabled")

	# Disable and verify process stops
	component.set_enabled(false)
	component.process_called = false
	await get_tree().process_frame
	assert_false(component.process_called, "Process should not be called when disabled")

	# Re-enable and verify process resumes
	component.set_enabled(true)
	component.process_called = false
	await get_tree().process_frame
	assert_true(component.process_called, "Process should resume when re-enabled")

	entity.free()


# =============================================================================
# EDGE CASE TESTS
# =============================================================================


func test_component_multiple_config_loads() -> void:
	var component: MockGameComponent = MockGameComponent.new()

	component.load_config({"value": 1})
	assert_eq(component.config.get("value"), 1, "First config should be loaded")

	component.load_config({"value": 2})
	assert_eq(component.config.get("value"), 2, "Second config should replace first")
	component.free()


func test_component_process_before_ready() -> void:
	var component: MockGameComponent = MockGameComponent.new()

	# Manually call _process before component is ready
	component._process(0.016)

	# Should not crash and process should not be called
	assert_false(component.process_called, "Process should not be called before ready")
	component.free()


func test_component_without_entity() -> void:
	var component: MockGameComponent = MockGameComponent.new()

	# Component not added to tree should not crash
	component.set_enabled(false)
	component.load_config({"test": "value"})

	assert_false(component.is_ready(), "Component should not be ready")
	assert_null(component.entity, "Entity should be null")
	component.free()
