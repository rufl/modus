extends Node
## Example: Using Features in MODUS Framework
##
## This script demonstrates how to use the feature system including
## feature toggles, configuration, and integration with the framework.

var _log: ExampleLogger = ExampleLogger.new("FeatureExamples")


func _ready() -> void:
	_log.info("=== Feature System Examples ===\n")
	
	await get_tree().process_frame
	
	example_1_check_feature_enabled()
	example_2_access_feature_instance()
	example_3_configure_feature()
	example_4_feature_dependencies()
	example_5_create_custom_feature()
	example_6_feature_hot_reload()


func _exit_tree() -> void:
	# Disconnect config reload signal to prevent memory leak
	var config_manager = GameManager.get_core_system("config")
	if config_manager and config_manager.has_signal("config_reloaded"):
		if config_manager.config_reloaded.is_connected(_on_config_reloaded):
			config_manager.config_reloaded.disconnect(_on_config_reloaded)


## Example 1: Check if Feature is Enabled
## Features can be toggled on/off through configuration
func example_1_check_feature_enabled() -> void:
	_log.info("Example 1: Checking if features are enabled")
	
	# Check if a feature is enabled
	var is_enabled: bool = GameManager.is_feature_enabled("my_feature")
	_log.info("  my_feature enabled: " + str(is_enabled))
	
	# Conditional code based on feature flag
	if GameManager.is_feature_enabled("advanced_graphics"):
		_log.info("  Advanced graphics enabled - using high quality settings")
		# Enable advanced graphics settings
	else:
		_log.info("  Advanced graphics disabled - using standard settings")
		# Use standard graphics settings
	
	# Check multiple features
	var features_to_check: Array[String] = ["multiplayer", "modding", "level_editor"]
	for feature_name: String in features_to_check:
		var enabled: bool = GameManager.is_feature_enabled(feature_name)
		_log.info("  " + feature_name + ": " + ("enabled" if enabled else "disabled"))
	
	_log.info("")


## Example 2: Access Feature Instance
## Get reference to feature instance for direct interaction
func example_2_access_feature_instance() -> void:
	print("Example 2: Accessing feature instances")
	
	# Get feature instance
	var my_feature = GameManager.get_feature("my_feature")
	
	if my_feature:
		print("  Retrieved my_feature instance")
		
		# Call feature methods
		if my_feature.has_method("do_something"):
			var result = my_feature.do_something("test_parameter")
			print("  Feature method result: ", result)
		
		# Access feature properties
		if "is_initialized" in my_feature:
			print("  Feature initialized: ", my_feature.is_initialized)
	else:
		print("  my_feature not available (disabled or not registered)")
	
	# Access subsystem features
	var localization = GameManager.get_core_system("LocalizationManager")
	if localization:
		print("  Retrieved LocalizationManager")
		if localization.has_method("get_current_language"):
			var lang = localization.get_current_language()
			print("  Current language: ", lang)
	
	print()


## Example 3: Configure Features
## Features can be configured through JSON5 files
func example_3_configure_feature() -> void:
	print("Example 3: Configuring features")
	
	# Example feature configuration structure:
	# game/config/features/my_feature.json5
	# {
	#   "feature_name": "my_feature",
	#   "enabled": true,
	#   "settings": {
	#     "option1": "value1",
	#     "option2": 42,
	#     "option3": true
	#   }
	# }
	
	# Load feature configuration
	var config_path = "res://game/config/features/my_feature.json5"
	var config_manager = GameManager.get_core_system("config")
	var config = config_manager.load_config(config_path) if config_manager else {}
	
	if config:
		print("  Loaded feature configuration")
		print("  Feature enabled: ", config.get("enabled", false))
		
		if "settings" in config:
			var settings = config.settings
			print("  Feature settings:")
			for key in settings.keys():
				print("    ", key, ": ", settings[key])
	else:
		print("  Failed to load feature configuration")
		print("  Using default settings")
	
	print()


## Example 4: Feature Dependencies
## Features can depend on other features
func example_4_feature_dependencies() -> void:
	print("Example 4: Feature dependencies")
	
	# Check if required features are available
	var required_features = ["base_feature", "dependency_feature"]
	var all_available = true
	
	for feature_name in required_features:
		if not GameManager.is_feature_enabled(feature_name):
			print("  Required feature missing: ", feature_name)
			all_available = false
	
	if all_available:
		print("  All required features available")
		# Initialize feature that depends on others
	else:
		print("  Cannot initialize - missing dependencies")
	
	# Example: Feature with dependencies
	var feature_config = {
		"feature_name": "advanced_feature",
		"enabled": true,
		"dependencies": [
			"base_feature",
			"graphics_feature"
		],
		"settings": {
			"quality": "high"
		}
	}
	
	print("  Feature configuration:")
	print("    Name: ", feature_config.feature_name)
	print("    Dependencies: ", feature_config.dependencies)
	
	print()


## Example 5: Create Custom Feature
## Demonstrates creating a custom feature
func example_5_create_custom_feature() -> void:
	print("Example 5: Creating custom feature")
	
	# Create and register custom feature
	var custom_feature = CustomFeatureExample.new()
	add_child(custom_feature)
	
	# Wait for initialization
	await get_tree().create_timer(0.5).timeout
	
	# Use custom feature
	if custom_feature.is_initialized:
		custom_feature.perform_action("test_data")
		
		var status = custom_feature.get_status()
		print("  Custom feature status: ", status)
	
	print()


## Example 6: Feature Hot-Reload
## Features can be reloaded at runtime
func example_6_feature_hot_reload() -> void:
	print("Example 6: Feature hot-reload")
	
	# Connect to configuration reload signal
	var config_manager = GameManager.get_core_system("config")
	if config_manager:
		config_manager.config_reloaded.connect(_on_config_reloaded)
	
	print("  Listening for configuration changes...")
	print("  Modify game/config/features/*.json5 to trigger reload")
	
	# Manually trigger reload (for testing)
	await get_tree().create_timer(1.0).timeout
	if config_manager:
		config_manager.reload_all_configs()
	
	print()


func _on_config_reloaded(config_path: String) -> void:
	print("  Configuration reloaded: ", config_path)
	
	# Reload feature if it's a feature config
	if "features/" in config_path:
		var feature_name = config_path.get_file().get_basename()
		print("  Reloading feature: ", feature_name)
		
		# Get feature instance and reload
		var feature = GameManager.get_feature(feature_name)
		if feature and feature.has_method("reload_configuration"):
			feature.reload_configuration()
			print("  Feature reloaded successfully")


## Custom Feature Example
## Template for creating custom features
class CustomFeatureExample extends Node:
	## Example custom feature implementation
	
	# Configuration
	var config: Dictionary = {}
	
	# State
	var is_initialized: bool = false
	var action_count: int = 0
	
	func _ready() -> void:
		load_configuration()
		initialize()
	
	## Load feature configuration
	func load_configuration() -> void:
		var config_path = "res://game/config/features/custom_feature.json5"
		var config_manager = GameManager.get_core_system("config")
		var config_data = config_manager.load_config(config_path) if config_manager else {}
		
		if config_data:
			config = config_data.get("settings", {})
			print("  CustomFeature: Configuration loaded")
		else:
			config = get_default_config()
			print("  CustomFeature: Using default configuration")
	
	## Get default configuration
	func get_default_config() -> Dictionary:
		return {
			"enabled": true,
			"max_actions": 100,
			"action_delay": 1.0
		}
	
	## Initialize the feature
	func initialize() -> void:
		if is_initialized:
			return
		
		# Setup feature
		setup_signals()
		register_with_services()
		
		is_initialized = true
		print("  CustomFeature: Initialized")
	
	## Setup signal connections
	func setup_signals() -> void:
		GameManager.subscribe("game_started", _on_game_started)
		GameManager.subscribe("game_ended", _on_game_ended)
	
	## Register with services
	func register_with_services() -> void:
		# Register with GameManager or other services
		GameManager.register_feature("custom_feature", self)
	
	## Perform feature action
	func perform_action(data: String) -> bool:
		if not is_initialized:
			push_error("CustomFeature not initialized")
			return false
		
		var max_actions = config.get("max_actions", 100)
		if action_count >= max_actions:
			push_warning("CustomFeature: Max actions reached")
			return false
		
		action_count += 1
		print("  CustomFeature: Performed action #", action_count, " with data: ", data)
		
		# Emit event
		GameManager.emit_event("custom_feature_action", {"data": data, "count": action_count})
		
		return true
	
	## Get feature status
	func get_status() -> Dictionary:
		return {
			"initialized": is_initialized,
			"action_count": action_count,
			"config": config
		}
	
	## Reload configuration
	func reload_configuration() -> void:
		load_configuration()
		print("  CustomFeature: Configuration reloaded")
	
	func _on_game_started() -> void:
		print("  CustomFeature: Game started")
	
	func _on_game_ended() -> void:
		print("  CustomFeature: Game ended")
		action_count = 0  # Reset on game end


## Feature Manager Helper
## Utility class for managing features
class FeatureManager:
	## Check if all required features are enabled
	static func check_dependencies(dependencies: Array) -> bool:
		for feature_name in dependencies:
			if not GameManager.is_feature_enabled(feature_name):
				return false
		return true
	
	## Get all enabled features
	static func get_enabled_features() -> Array:
		var enabled: Array = []
		# This would need to iterate through registered features
		# Implementation depends on GameCore structure
		return enabled
	
	## Enable feature at runtime
	static func enable_feature(feature_name: String) -> bool:
		var feature = GameManager.get_feature(feature_name)
		if feature and feature.has_method("enable"):
			feature.enable()
			return true
		return false
	
	## Disable feature at runtime
	static func disable_feature(feature_name: String) -> bool:
		var feature = GameManager.get_feature(feature_name)
		if feature and feature.has_method("disable"):
			feature.disable()
			return true
		return false


## Example: Feature Toggle System
## Demonstrates runtime feature toggling
func example_feature_toggle_system() -> void:
	print("Bonus: Feature toggle system")
	
	# Define feature toggles
	var feature_toggles = {
		"debug_mode": false,
		"experimental_features": false,
		"performance_mode": true,
		"advanced_graphics": true
	}
	
	# Apply feature toggles
	for feature_name in feature_toggles.keys():
		var enabled = feature_toggles[feature_name]
		print("  ", feature_name, ": ", "enabled" if enabled else "disabled")
		
		# Apply toggle
		if enabled:
			FeatureManager.enable_feature(feature_name)
		else:
			FeatureManager.disable_feature(feature_name)
	
	print()


## Example: Feature-Based Gameplay
## Use features to modify gameplay
func example_feature_based_gameplay() -> void:
	print("Bonus: Feature-based gameplay")
	
	# Check features and adjust gameplay
	if GameManager.is_feature_enabled("hardcore_mode"):
		print("  Hardcore mode enabled:")
		print("    - No health regeneration")
		print("    - Permadeath")
		print("    - Increased enemy damage")
	
	if GameManager.is_feature_enabled("casual_mode"):
		print("  Casual mode enabled:")
		print("    - Auto health regeneration")
		print("    - Reduced enemy damage")
		print("    - Extra lives")
	
	if GameManager.is_feature_enabled("speedrun_mode"):
		print("  Speedrun mode enabled:")
		print("    - Timer display")
		print("    - Split tracking")
		print("    - Optimized loading")
	
	print()


## Tips for Using Features:
##
## 1. Use feature flags for experimental or optional functionality
## 2. Keep features independent when possible
## 3. Document feature dependencies clearly
## 4. Provide sensible defaults for feature configuration
## 5. Use hot-reload for rapid iteration during development
## 6. Test with features both enabled and disabled
## 7. Consider performance impact of feature checks
## 8. Use feature flags for A/B testing
## 9. Version your feature configurations
## 10. Clean up unused features regularly
