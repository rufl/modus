## Base class for all game components with automatic signal hygiene
## Provides safe_connect() for automatic signal cleanup and memory leak prevention
class_name GameComponent
extends Node

## Tracks all signal connections made through safe_connect() for automatic cleanup
var _tracked_connections: Array[Dictionary] = []


## Safe signal connection that automatically disconnects on component removal
## @param sig: The signal to connect to
## @param callable: The callable to connect
## @param flags: Optional connection flags (default: 0)
func safe_connect(sig: Signal, callable: Callable, flags: int = 0) -> void:
	if not sig.get_object():
		push_error("GameComponent.safe_connect: Invalid signal (no object)")
		return

	# Check if already connected to avoid duplicate connections
	if sig.is_connected(callable):
		push_warning("GameComponent.safe_connect: Signal already connected, skipping")
		return

	# Connect the signal
	sig.connect(callable, flags)

	# Track the connection for cleanup
	_tracked_connections.append({"signal": sig, "callable": callable})


## Automatically cleanup all tracked signal connections when component is removed
func _exit_tree() -> void:
	_cleanup_signals()


## Manual cleanup method for tracked signals (called automatically in _exit_tree)
func _cleanup_signals() -> void:
	for connection in _tracked_connections:
		var sig: Signal = connection.get("signal")
		var callable: Callable = connection.get("callable")

		if sig and sig.get_object() and callable and sig.is_connected(callable):
			sig.disconnect(callable)

	_tracked_connections.clear()


## Get the number of tracked connections (useful for debugging/testing)
func get_tracked_connection_count() -> int:
	return _tracked_connections.size()
