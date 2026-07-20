## Base class for all game components in the MODUS architecture.
##
## GameComponent provides a standardized interface for reusable, single-responsibility
## components that can be attached to entities (like HealthComponent, WeaponComponent, etc.).
## Components have lifecycle hooks, enable/disable functionality, and configuration support.
##
## Requirements: 4.3
class_name LegacyGameComponent
extends Node

## Emitted when the component is ready and initialized
signal component_ready

## Emitted when the component is enabled
signal component_enabled

## Emitted when the component is disabled
signal component_disabled

## Emitted when configuration is reloaded
signal config_reloaded

## Unique identifier for this component instance
var component_id: String = ""

## Whether this component is currently enabled
var enabled: bool = true

## Configuration dictionary loaded from GameManager or entity
var config: Dictionary = {}

## Reference to the entity/node this component is attached to
var entity: Node = null

## Whether the component has completed initialization
var _is_ready: bool = false


## Called when the component is added to the scene tree
func _ready() -> void:
	entity = get_parent()
	_component_ready()
	_is_ready = true
	component_ready.emit()


## Called every frame if the component is enabled
func _process(delta: float) -> void:
	if not enabled or not _is_ready:
		return
	_component_process(delta)


## Called every physics frame if the component is enabled
func _physics_process(delta: float) -> void:
	if not enabled or not _is_ready:
		return
	_component_physics_process(delta)


## Lifecycle hook called after component is added to entity.
## Override this in subclasses to implement component-specific initialization.
func _component_ready() -> void:
	pass


## Lifecycle hook called every frame if enabled.
## Override this in subclasses to implement per-frame logic.
func _component_process(_delta: float) -> void:
	pass


## Lifecycle hook called every physics frame if enabled.
## Override this in subclasses to implement physics logic.
func _component_physics_process(_delta: float) -> void:
	pass


## Load configuration data for this component.
## Can be called during initialization or at runtime to update configuration.
func load_config(config_data: Dictionary) -> void:
	config = config_data
	_on_config_loaded()
	config_reloaded.emit()


## Hook called after configuration is loaded.
## Override this in subclasses to respond to configuration changes.
func _on_config_loaded() -> void:
	pass


## Enable or disable the component.
## When disabled, _component_process and _component_physics_process are not called.
func set_enabled(value: bool) -> void:
	if enabled == value:
		return

	enabled = value

	if enabled:
		_on_enabled()
		component_enabled.emit()
	else:
		_on_disabled()
		component_disabled.emit()


## Hook called when the component is enabled.
## Override this in subclasses to respond to enable events.
func _on_enabled() -> void:
	pass


## Hook called when the component is disabled.
## Override this in subclasses to respond to disable events.
func _on_disabled() -> void:
	pass


## Check if the component is currently enabled
func is_enabled() -> bool:
	return enabled


## Check if the component has completed initialization
func is_ready() -> bool:
	return _is_ready


## Get a configuration value with optional default
func get_config_value(key: String, default: Variant = null) -> Variant:
	return config.get(key, default)


## Load configuration from GameManager using a config path.
## Useful for components that need to load shared configuration.
func load_config_from_manager(config_path: String) -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		push_warning("GameComponent '%s': GameManager not available" % component_id)
		return

	if game_manager.has_method("get_config"):
		var loaded_config: Variant = game_manager.get_config(config_path, {})
		if loaded_config is Dictionary:
			load_config(loaded_config)
		else:
			push_warning(
				(
					"GameComponent '%s': Config at '%s' is not a Dictionary"
					% [component_id, config_path]
				)
			)


## Cleanup method called before the component is removed.
## Override this in subclasses to implement cleanup logic.
func cleanup() -> void:
	pass


## Called when the component is about to be removed from the scene tree
func _exit_tree() -> void:
	cleanup()
