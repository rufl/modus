## Base class for all feature modules in the MODUS architecture.
##
## FeatureModule provides a standardized interface for toggleable game features
## with lifecycle management, dependency declaration, and configuration support.
## All feature modules (Combat, Inventory, Loot, etc.) extend this base class.
##
## Requirements: 2.3, 2.4
class_name FeatureModule
extends Node

## Emitted when the feature module completes initialization
signal initialized

## Emitted when the feature module is shut down
signal shutdown_complete

## Emitted when configuration is reloaded
signal config_reloaded

## Unique identifier for this feature (e.g., "combat", "inventory")
var feature_id: String = ""

## Human-readable name for this feature
var feature_name: String = ""

## Array of feature IDs that this feature depends on
var dependencies: Array[String] = []

## Configuration dictionary loaded from JSON5 files
var config: Dictionary = {}

## Whether this feature has been initialized
var _is_initialized: bool = false


## Constructor - must be called by subclasses with a unique feature_id
func _init(id: String = "") -> void:
	if id.is_empty():
		push_error("FeatureModule: feature_id cannot be empty")
		return

	feature_id = id
	feature_name = id.capitalize()


## Initialize the feature module.
## Called by GameManager when the feature is loaded.
## Override this in subclasses to implement feature-specific initialization.
func initialize() -> void:
	if _is_initialized:
		push_warning("FeatureModule '%s': Already initialized" % feature_id)
		return

	if config.is_empty():
		reload_config()
	_is_initialized = true
	initialized.emit()


## Shutdown the feature module.
## Called by GameManager when the feature is unloaded or game exits.
## Override this in subclasses to implement feature-specific cleanup.
func shutdown() -> void:
	if not _is_initialized:
		return

	_is_initialized = false
	shutdown_complete.emit()


## Reload configuration from GameManager.
## Called during initialization and when configuration is hot-reloaded.
## Override this in subclasses to handle configuration changes.
func reload_config() -> void:
	var game_manager: Node = null

	# Try to get GameManager from scene tree (when running as autoload)
	if is_inside_tree():
		game_manager = get_node_or_null("/root/GameManager")

	# If not found, check if our parent is a GameManager (when testing)
	if not game_manager and get_parent():
		if get_parent().has_method("get_config"):
			game_manager = get_parent()

	if not game_manager:
		# Silently skip if GameManager not available (e.g., during testing setup)
		return

	if game_manager.has_method("get_config"):
		config = game_manager.get_config("features." + feature_id, {})
	config_reloaded.emit()


## Check if this feature has been initialized
func is_initialized() -> bool:
	return _is_initialized


## Get a configuration value with optional default
func get_config_value(key: String, default: Variant = null) -> Variant:
	return config.get(key, default)


## Declare dependencies for this feature module.
## Call this in subclass _init() to specify required features.
func declare_dependencies(deps: Array[String]) -> void:
	dependencies = deps


## Validate that all dependencies are available and initialized.
## Returns true if all dependencies are met, false otherwise.
func validate_dependencies() -> bool:
	if dependencies.is_empty():
		return true

	var game_manager: Node = null

	# Try to get GameManager from scene tree (when running as autoload)
	if is_inside_tree():
		game_manager = get_node_or_null("/root/GameManager")

	# If not found, check if our parent is a GameManager (when testing)
	if not game_manager and get_parent():
		if get_parent().has_method("is_feature_enabled"):
			game_manager = get_parent()

	if not game_manager:
		push_error(
			"FeatureModule '%s': GameManager not available for dependency validation" % feature_id
		)
		return false

	for dep_id: String in dependencies:
		if game_manager.has_method("is_feature_enabled"):
			if not game_manager.is_feature_enabled(dep_id):
				push_error(
					(
						"FeatureModule '%s': Required dependency '%s' is not enabled"
						% [feature_id, dep_id]
					)
				)
				return false

		if game_manager.has_method("get_feature"):
			var dep_feature: Node = game_manager.get_feature(dep_id)  # FeatureModule instance
			if not dep_feature:
				push_error(
					(
						"FeatureModule '%s': Required dependency '%s' is not loaded"
						% [feature_id, dep_id]
					)
				)
				return false

			if not dep_feature.is_initialized():
				push_error(
					(
						"FeatureModule '%s': Required dependency '%s' is not initialized"
						% [feature_id, dep_id]
					)
				)
				return false

	return true
