class_name ExampleLogger
extends RefCounted
## Helper class for logging in example scripts
## Provides consistent logging with fallback to print() for standalone examples

var _logger: Variant = null
var _category: String = "Examples"


func _init(category: String = "Examples") -> void:
	_category = category
	if GameManager:
		_logger = GameManager.get_core_system("logger")


## Log info message
func info(message: String) -> void:
	if _logger and _logger.has_method("info"):
		_logger.info(message, _category)
	else:
		print("[%s] %s" % [_category, message])


## Log debug message
func debug(message: String) -> void:
	if _logger and _logger.has_method("debug"):
		_logger.debug(message, _category)
	else:
		print("[%s] DEBUG: %s" % [_category, message])


## Log warning message
func warn(message: String) -> void:
	if _logger and _logger.has_method("warn"):
		_logger.warn(message, _category)
	else:
		push_warning("[%s] %s" % [_category, message])


## Log error message
func error(message: String) -> void:
	if _logger and _logger.has_method("error"):
		_logger.error(message, _category)
	else:
		push_error("[%s] %s" % [_category, message])


## Quick log (defaults to info)
func log(message: String) -> void:
	info(message)
