# Test helper object for error testing
extends Node


# Method that returns an error code
func failing_method() -> int:
	return ERR_UNAVAILABLE


# Method that succeeds
func succeeding_method() -> int:
	return OK


# Method that takes time
func slow_method(duration_ms: float) -> void:
	var start_time = Time.get_unix_time_from_system() * 1000
	while (Time.get_unix_time_from_system() * 1000 - start_time) < duration_ms:
		pass  # Busy wait
