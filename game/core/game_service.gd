class_name GameService
extends Node

signal service_ready

var _initialized: bool = false
var _dependencies: Array[String] = []
var _optional_dependencies: Array[String] = []


func initialize() -> void:
	push_error("[%s] initialize() must be overridden" % get_script().get_global_name())


## Override this to implement service shutdown


func shutdown() -> void:
	pass


## Check if service is initialized


func is_service_ready() -> bool:
	return _initialized


## Mark service as initialized


func _mark_initialized() -> void:
	_initialized = true
	service_ready.emit()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[%s] Service ready" % name, "Core")


## Get initialization priority (lower = earlier)


func get_init_priority() -> int:
	return 100  # Default priority


## Define required dependencies (must be initialized first)


func get_dependencies() -> Array[String]:
	return _dependencies


## Define optional dependencies (won't block initialization)


func get_optional_dependencies() -> Array[String]:
	return _optional_dependencies


## Wait for dependencies to be ready


func _wait_for_dependencies() -> void:
	if _dependencies.is_empty():
		return

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[%s] Waiting for dependencies: %s" % [name, _dependencies], "Core")

	# Wait for GameManager if it exists
	if not gm:
		await get_tree().process_frame
		return

	# Wait for each dependency
	for dep_id: String in _dependencies:
		if not gm.has_method("get_core_system"):
			continue
		var service: Node = gm.get_core_system(dep_id)
		if not service:
			push_warning("[%s] Required dependency not found: %s" % [name, dep_id])
			continue

		if service.has_method("is_service_ready"):
			while not service.is_service_ready():
				await get_tree().process_frame

	if gm:
		var logger2: Variant = gm.get_core_system("logger")
		if logger2 and logger2.has_method("info"):
			logger2.info("[%s] All dependencies ready" % name, "Core")


## Helper to get injected service


func find_service(service_id: String) -> Node:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_core_system"):
		return gm.get_core_system(service_id)
	return null


## Helper to check if feature is enabled


func is_feature_enabled(feature_id: String) -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("is_feature_enabled"):
		return gm.is_feature_enabled(feature_id)
	return true


## Helper to emit event via GameManager


func emit_event(event_id: String, data: Dictionary = {}) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("emit_event"):
		gm.emit_event(event_id, data)


## Helper to subscribe to event via GameManager


func subscribe_event(event_id: String, callback: Callable, priority: int = 0) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("subscribe"):
		if gm.has_method("is_subscribed") and gm.is_subscribed(event_id, callback):
			return
		gm.subscribe(event_id, callback, priority)


## Helper to unsubscribe from event via GameManager


func unsubscribe_event(event_id: String, callback: Callable) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("unsubscribe"):
		gm.unsubscribe(event_id, callback)


## Helper to unsubscribe from all events for this service


func unsubscribe_all_events(callback: Callable) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("unsubscribe_all"):
		gm.unsubscribe_all(callback)


## Helper to get config value


func get_config(path: String, default: Variant = null) -> Variant:
	var config_manager: Node = find_service("config")
	if config_manager and config_manager.has_method("get_value"):
		return config_manager.get_value(path, default)
	return default
