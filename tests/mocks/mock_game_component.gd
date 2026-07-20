extends LegacyGameComponent
class_name TestMockGameComponent

var ready_called: bool = false
var process_called: bool = false
var physics_process_called: bool = false
var enabled_called: bool = false
var disabled_called: bool = false
var config_loaded_called: bool = false
var cleanup_called: bool = false


func _init(id: String = "test_component") -> void:
	component_id = id


func _component_ready() -> void:
	ready_called = true


func _component_process(_delta: float) -> void:
	process_called = true


func _component_physics_process(_delta: float) -> void:
	physics_process_called = true


func _on_enabled() -> void:
	enabled_called = true


func _on_disabled() -> void:
	disabled_called = true


func _on_config_loaded() -> void:
	config_loaded_called = true


func cleanup() -> void:
	cleanup_called = true
