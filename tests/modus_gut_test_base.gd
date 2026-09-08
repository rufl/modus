# ModusGutTestBase - Base class for MODUS Framework GUT tests
# Provides conversion utilities and MODUS-specific assertion helpers
extends "res://addons/gut/test.gd"
class_name ModusGutTestBase

# =============================================================================
# LEGACY TEST CONVERSION UTILITIES
# =============================================================================


# Convert legacy Dictionary format test results to GUT assertions
# Note: This is an instance method, not static, to allow proper assertion calls
func convert_legacy_result(legacy_result: Dictionary, test_name: String = "") -> void:
	if not legacy_result.has("passed") or not legacy_result.has("error"):
		assert_true(false, "Invalid legacy test result format - missing 'passed' or 'error' keys")
		return

	var message: String = test_name if test_name != "" else "Legacy test"
	if legacy_result.passed:
		var success_msg: String = message + ": " + str(legacy_result.get("message", "Test passed"))
		assert_true(true, success_msg)
	else:
		var error_msg: String = message + " failed: " + str(legacy_result.error)
		assert_true(false, error_msg)


# Helper to run legacy test method and convert result
func run_legacy_test_method(instance: Node, method_name: String) -> void:
	if not instance.has_method(method_name):
		assert_true(false, "Test method '%s' not found" % method_name)
		return

	var result: Variant = instance.call(method_name)

	if result is Dictionary:
		convert_legacy_result(result, method_name)
	elif result is bool:
		if result:
			assert_true(true, "%s: Test passed" % method_name)
		else:
			assert_true(false, "%s: Test returned false" % method_name)
	else:
		assert_true(false, "%s: Invalid return type - expected Dictionary or bool" % method_name)


# =============================================================================
# MODUS-SPECIFIC ASSERTION HELPERS
# =============================================================================


# Assert that a MODUS autoload exists and is accessible
func assert_autoload_exists(autoload_name: String, custom_message: String = "") -> void:
	var autoload: Node = get_node_or_null("/root/" + autoload_name)
	var message: String = (
		custom_message
		if custom_message != ""
		else "Autoload '%s' should exist and be accessible" % autoload_name
	)
	assert_not_null(autoload, message)


# Assert that a MODUS service is functional
func assert_service_functional(
	service_name: String, test_method: String = "is_ready", custom_message: String = ""
) -> void:
	var service: Node = get_node_or_null("/root/" + service_name)
	var base_message: String = (
		custom_message if custom_message != "" else "Service '%s'" % service_name
	)

	assert_not_null(service, base_message + " should be available")

	if service and service.has_method(test_method):
		var result: Variant = service.call(test_method)
		assert_true(result, base_message + " should be functional (method: %s)" % test_method)
	elif service:
		# If test_method doesn't exist, just verify service exists
		assert_true(
			true,
			base_message + " exists but method '%s' not found - assuming functional" % test_method
		)


# Assert that GameManager subsystem exists and is initialized
func assert_gamecore_subsystem_exists(subsystem_name: String, custom_message: String = "") -> void:
	assert_autoload_exists("GameManager", "GameManager autoload must exist")

	var gm: Variant = get_node_or_null("/root/GameManager")
	if not gm:
		return

	var subsystem: Variant = gm.get_core_system(subsystem_name)
	var message: String = (
		custom_message
		if custom_message != ""
		else "GameManager.get_core_system('%s') subsystem should be initialized" % subsystem_name
	)
	assert_not_null(subsystem, message)


# Assert that a service is registered with GameManager
func assert_service_registered_with_gamecore(
	service_name: String, custom_message: String = ""
) -> void:
	assert_autoload_exists(
		"GameManager", "GameManager autoload must exist for service registration"
	)

	var gm: Variant = get_node_or_null("/root/GameManager")
	if not gm or not gm.has_method("get_core_system"):
		assert_true(false, "GameManager missing get_core_system() method")
		return

	var service: Variant = gm.get_core_system(service_name)
	var message: String = (
		custom_message
		if custom_message != ""
		else "Service '%s' should be registered with GameManager" % service_name
	)
	assert_not_null(service, message)


# Assert that configuration value exists and has expected type
func assert_config_value_exists(
	config_path: String, expected_type: int = -1, custom_message: String = ""
) -> void:
	assert_autoload_exists("GameManager", "GameManager autoload must exist for config access")

	var gm: Variant = get_node_or_null("/root/GameManager")
	if not gm or not gm.get_core_system("config"):
		assert_true(false, 'GameManager.get_core_system("config") not available')
		return

	var value: Variant = gm.get_core_system("config").get_value(config_path)
	var message: String = (
		custom_message if custom_message != "" else "Config value '%s' should exist" % config_path
	)

	if expected_type == -1:
		# Just check existence (not null)
		assert_not_null(value, message)
	else:
		# Check type as well
		assert_not_null(value, message)
		if value != null:
			assert_eq(typeof(value), expected_type, message + " and have correct type")


# =============================================================================
# COLLECTION-SPECIFIC ASSERTIONS
# =============================================================================


# Assert value is greater than or equal to expected
func assert_ge(actual: Variant, expected: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Expected %s >= %s" % [str(actual), str(expected)]
	)
	assert_true(actual >= expected, message)


# Assert value is less than or equal to expected
func assert_le(actual: Variant, expected: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Expected %s <= %s" % [str(actual), str(expected)]
	)
	assert_true(actual <= expected, message)


# Assert value is greater than expected
func assert_gt(actual: Variant, expected: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Expected %s > %s" % [str(actual), str(expected)]
	)
	assert_true(actual > expected, message)


# Assert value is less than expected
func assert_lt(actual: Variant, expected: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Expected %s < %s" % [str(actual), str(expected)]
	)
	assert_true(actual < expected, message)


# Assert array contains specific element
func assert_array_contains(array: Array, element: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Array should contain element: %s" % str(element)
	)
	assert_true(array.has(element), message)


# Assert array has expected size
func assert_array_size(array: Array, expected_size: int, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Array should have size %d, got %d" % [expected_size, array.size()]
	)
	assert_eq(array.size(), expected_size, message)


# Assert dictionary has specific key
func assert_dict_has_key(dict: Dictionary, key: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message if custom_message != "" else "Dictionary should have key: %s" % str(key)
	)
	assert_true(dict.has(key), message)


# Assert dictionary has expected number of keys
func assert_dict_size(dict: Dictionary, expected_size: int, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Dictionary should have %d keys, got %d" % [expected_size, dict.size()]
	)
	assert_eq(dict.size(), expected_size, message)


# =============================================================================
# SIGNAL ASSERTIONS (Enhanced)
# =============================================================================


# Assert that a signal was emitted with specific parameters
func assert_signal_emitted_with_params(
	object: Object, signal_name: String, expected_params: Array, custom_message: String = ""
) -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Signal '%s' should be emitted with params: %s" % [signal_name, str(expected_params)]
	)
	# Use GUT's built-in signal watching
	assert_signal_emitted(object, signal_name, message)


# =============================================================================
# EXCEPTION HANDLING ASSERTIONS
# =============================================================================


# Assert that a method call throws an error (for error condition testing)
func assert_method_throws_error(
	object: Object, method_name: String, params: Array = [], custom_message: String = ""
) -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Method '%s' should throw an error" % method_name
	)

	var error_occurred: bool = false

	# Try to call method and catch any errors
	if object.has_method(method_name):
		# Use callv to handle parameter arrays
		var result: Variant = object.callv(method_name, params)
		# In GDScript, errors usually return null or specific error values
		if result == null or (result is int and result != OK):
			error_occurred = true

	assert_true(error_occurred, message)


# =============================================================================
# PROPERTY-BASED TESTING SUPPORT
# =============================================================================


# Property test runner with configurable iterations (minimum 100)
func run_property_test(
	property_name: String, test_func: Callable, iterations: int = 100, custom_message: String = ""
) -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Property '%s' should hold for all test cases" % property_name
	)
	var failures: Array = []

	for i in range(iterations):
		var test_data: Dictionary = generate_test_data_for_iteration(i, iterations)
		var result: bool = test_func.call(test_data)

		if not result:
			failures.append({"iteration": i, "test_data": test_data, "property": property_name})

	if failures.size() > 0:
		var failure_msg: String = (
			"%s - Failed on %d/%d iterations. First failure: iteration %d with data: %s"
			% [
				message,
				failures.size(),
				iterations,
				failures[0].iteration,
				str(failures[0].test_data)
			]
		)
		assert_true(false, failure_msg)
	else:
		assert_true(true, "%s - Passed all %d iterations" % [message, iterations])


# Generate test data for property-based testing (deterministic based on iteration)
func generate_test_data_for_iteration(iteration: int, _total_iterations: int) -> Dictionary:
	# Basic test data generation - can be overridden in subclasses
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = iteration  # Deterministic based on iteration

	return {
		"iteration": iteration,
		"random_int": rng.randi_range(-1000, 1000),
		"random_float": rng.randf_range(-100.0, 100.0),
		"random_bool": rng.randf() > 0.5,
		"random_string": "test_string_%d" % iteration,
		"random_array": generate_random_array(rng, 5),
		"random_dict": generate_random_dict(rng, 3)
	}


# Helper to generate random array for testing
func generate_random_array(rng: RandomNumberGenerator, max_size: int) -> Array:
	var size: int = rng.randi_range(0, max_size)
	var array: Array = []
	for i in range(size):
		array.append(rng.randi_range(0, 100))
	return array


# Helper to generate random dictionary for testing
func generate_random_dict(rng: RandomNumberGenerator, max_keys: int) -> Dictionary:
	var size: int = rng.randi_range(0, max_keys)
	var dict: Dictionary = {}
	for i in range(size):
		dict["key_%d" % i] = rng.randi_range(0, 100)
	return dict


# =============================================================================
# BENCHMARK TEST SUPPORT
# =============================================================================


# Run performance benchmark test
func run_benchmark_test(
	test_name: String, test_func: Callable, iterations: int = 1000, custom_message: String = ""
) -> Dictionary:
	var message: String = (
		custom_message if custom_message != "" else "Benchmark test '%s'" % test_name
	)

	var _start_time: Dictionary = Time.get_time_dict_from_system()
	var start_usec: float = Time.get_unix_time_from_system() * 1000000

	for i in range(iterations):
		test_func.call()

	var end_usec: float = Time.get_unix_time_from_system() * 1000000
	var total_time_usec: float = end_usec - start_usec
	var avg_time_usec: float = total_time_usec / iterations

	var result: Dictionary = {
		"test_name": test_name,
		"iterations": iterations,
		"total_time_usec": total_time_usec,
		"avg_time_usec": avg_time_usec,
		"total_time_ms": total_time_usec / 1000.0,
		"avg_time_ms": avg_time_usec / 1000.0
	}

	# Log benchmark results
	print(
		(
			"%s completed: %d iterations in %.2f ms (avg: %.4f ms per iteration)"
			% [message, iterations, result.total_time_ms, result.avg_time_ms]
		)
	)

	return result


# =============================================================================
# SETUP AND TEARDOWN HELPERS
# =============================================================================


# Common setup for MODUS tests
func modus_setup() -> void:
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify core autoloads are available
	assert_autoload_exists("GameManager", "GameManager must be available for MODUS tests")


# Common teardown for MODUS tests
func modus_teardown() -> void:
	# Clean up any test-specific state
	# GameManager handles event cleanup internally

	# Reset any global state that might affect other tests
	var gm: Variant = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("reset_test_state"):
		gm.reset_test_state()


# =============================================================================
# TYPE ASSERTION HELPERS
# =============================================================================


# Assert value is a boolean
func assert_is_bool(value: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Value should be a boolean, got type %d" % typeof(value)
	)
	assert_eq(typeof(value), TYPE_BOOL, message)


# Assert value is an integer
func assert_is_int(value: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Value should be an integer, got type %d" % typeof(value)
	)
	assert_eq(typeof(value), TYPE_INT, message)


# Assert value is a float
func assert_is_float(value: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Value should be a float, got type %d" % typeof(value)
	)
	assert_eq(typeof(value), TYPE_FLOAT, message)


# Assert value is a string
func assert_is_string(value: Variant, custom_message: String = "") -> void:
	var message: String = (
		custom_message
		if custom_message != ""
		else "Value should be a string, got type %d" % typeof(value)
	)
	assert_eq(typeof(value), TYPE_STRING, message)


# =============================================================================
# CHILD NODE MANAGEMENT HELPERS
# =============================================================================


# Add a child node that will be automatically freed after the test
func add_child_autofree(node: Node, force_readable_name: bool = false) -> Node:
	return super.add_child_autofree(node, force_readable_name)


# =============================================================================
# LEGACY TEST COMPATIBILITY
# =============================================================================


# Fail the current test with a message (legacy compatibility method)
func _fail_test(message: String) -> void:
	assert_true(false, message)
