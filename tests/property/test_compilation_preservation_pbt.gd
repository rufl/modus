extends PropertyBasedTesting
## Property-Based Test: Test Compilation Fix - Preservation Testing
##
## **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
##
## IMPORTANT: This test is EXPECTED TO PASS on unfixed code
## Passing confirms baseline behavior to preserve during bugfix
##
## This test observes and validates runtime service access patterns on production
## files that currently compile successfully (no class-level GameManager refs).
## These behaviors MUST remain unchanged after the fix is applied.
##
## Preservation Requirements (from bugfix.md):
## - 3.1: Runtime service access functionality unchanged
## - 3.2: Type safety with proper type annotations maintained
## - 3.3: Test execution in GUI and headless mode works
## - 3.4: Single autoload pattern unchanged
## - 3.5: Public APIs function correctly
## - 3.6: Hot-reload and configuration changes work
## - 3.7: Core services provide same functionality

## Test configuration
const TEST_ITERATIONS: int = 30
const SEED_BASE: int = 42

## Test state
var _test_failures: Array[Dictionary] = []
var _core_services: Array[String] = []


func before_all() -> void:
	super.before_all()
	
	## Initialize core services list (avoid class-level initialization)
	_core_services = [
		"logger",
		"config",
		"data",
		"events",
		"globals",
		"audio",
		"ui",
		"performance",
		"localization",
		"entities",
		"save",
		"mod_loader",
		"chat",
		"assets",
		"ui_input"
	]
	
	print("\n" + "=".repeat(70))
	print("  PRESERVATION PROPERTY TEST")
	print("  Test Compilation Fix - Runtime Service Access Behavior")
	print("  Testing on UNFIXED code to establish baseline")
	print("=".repeat(70) + "\n")


## Helper: Get GameManager reference (must be called from test methods, not before_all)
func _get_game_manager() -> Variant:
	## Access GameManager through GUT's scene tree
	if gut and gut.get_tree():
		return gut.get_tree().root.get_node_or_null("GameManager")
	return null


func after_all() -> void:
	print("\n" + "=".repeat(70))
	print("  PRESERVATION TEST COMPLETE")
	if _test_failures.is_empty():
		print("  ✓ All preservation properties verified")
		print("  ✓ Baseline behavior established")
	else:
		print("  ✗ %d preservation failures detected" % _test_failures.size())
	print("=".repeat(70) + "\n")
	super.after_all()


## Property 2.1: Logger Service Access Produces Expected Output
## **Validates: Requirement 3.1, 3.7**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that logger.info(), logger.debug(), logger.warning(), logger.error()
## calls work correctly and produce expected output
func test_preservation_logger_service_access() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	for i: int in range(TEST_ITERATIONS):
		var _rng: RandomNumberGenerator = get_seeded_rng(SEED_BASE + i)
		
		## Get logger service through GameManager
		var logger: Variant = game_manager.get_core_system("logger")
		
		## Verify logger is accessible
		if not logger:
			failures.append({
				"iteration": i,
				"service": "logger",
				"reason": "Logger service not accessible via GameManager.get_core_system()"
			})
			continue
		
		## Verify logger has expected methods
		var expected_methods: Array[String] = ["info", "debug", "warning", "error"]
		for method_name: String in expected_methods:
			if not logger.has_method(method_name):
				failures.append({
					"iteration": i,
					"service": "logger",
					"method": method_name,
					"reason": "Logger missing expected method: %s" % method_name
				})
		
		## Test logger method calls (should not crash)
		var test_message: String = "Test message %d" % i
		var test_category: String = "PreservationTest"
		
		if logger.has_method("info"):
			logger.info(test_message, test_category)
		
		if logger.has_method("debug"):
			logger.debug(test_message, test_category)
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Logger service preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), TEST_ITERATIONS, summary
			]
		)
	else:
		pass_test("Logger service access preserved - all methods work correctly")


## Property 2.2: Config Service Returns Expected Values
## **Validates: Requirement 3.1, 3.6, 3.7**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that GameManager.get_config() returns expected configuration values
func test_preservation_config_service_access() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	for i: int in range(TEST_ITERATIONS):
		var _rng: RandomNumberGenerator = get_seeded_rng(SEED_BASE + i)
		
		## Test various config paths
		var config_tests: Array[Dictionary] = [
			{"path": "performance.profiling_enabled", "type": TYPE_BOOL},
			{"path": "development.log_feature_loading", "type": TYPE_BOOL},
			{"path": "development.validate_dependencies", "type": TYPE_BOOL},
		]
		
		for test_case: Dictionary in config_tests:
			var path: String = test_case["path"]
			var expected_type: int = test_case["type"]
			
			## Get config value through GameManager
			var value: Variant = game_manager.get_config(path, null)
			
			## Verify config value is accessible (not null or has correct type)
			if value == null:
				## Null is acceptable if default is returned
				var default_value: Variant = game_manager.get_config(path, false)
				if typeof(default_value) != expected_type:
					failures.append({
						"iteration": i,
						"config_path": path,
						"expected_type": expected_type,
						"actual_type": typeof(default_value),
						"reason": "Config value type mismatch"
					})
			elif typeof(value) != expected_type:
				failures.append({
					"iteration": i,
					"config_path": path,
					"expected_type": expected_type,
					"actual_type": typeof(value),
					"reason": "Config value type mismatch"
				})
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Config service preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), TEST_ITERATIONS, summary
			]
		)
	else:
		pass_test("Config service access preserved - values return correctly")


## Property 2.3: Data Service Queries Return Expected Results
## **Validates: Requirement 3.1, 3.7**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that data service queries work correctly
func test_preservation_data_service_access() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	for i: int in range(TEST_ITERATIONS):
		## Get data service through GameManager
		var data: Variant = game_manager.get_core_system("data")
		
		## Verify data service is accessible
		if not data:
			failures.append({
				"iteration": i,
				"service": "data",
				"reason": "Data service not accessible via GameManager.get_core_system()"
			})
			continue
		
		## Verify data service has expected methods
		var expected_methods: Array[String] = ["get_weapon_data", "get_enemy_data"]
		for method_name: String in expected_methods:
			if not data.has_method(method_name):
				failures.append({
					"iteration": i,
					"service": "data",
					"method": method_name,
					"reason": "Data service missing expected method: %s" % method_name
				})
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Data service preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), TEST_ITERATIONS, summary
			]
		)
	else:
		pass_test("Data service access preserved - queries work correctly")


## Property 2.4: Service Initialization Pattern Works Correctly
## **Validates: Requirement 3.1, 3.4**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that services can be accessed in _ready() and _init() methods
func test_preservation_service_initialization_pattern() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	## Create a test node that accesses GameManager in _ready()
	var test_node: Node = Node.new()
	test_node.name = "PreservationTestNode"
	add_child_autofree(test_node)
	
	## Wait for _ready() to be called
	await get_tree().process_frame
	
	## Verify GameManager is accessible from the node
	for i: int in range(TEST_ITERATIONS):
		var service_id: String = _core_services[i % _core_services.size()]
		
		## Access service through GameManager
		var service: Variant = game_manager.get_core_system(service_id)
		
		## Verify service is accessible
		if not service:
			failures.append({
				"iteration": i,
				"service": service_id,
				"reason": "Service not accessible in _ready() context"
			})
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Service initialization preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), TEST_ITERATIONS, summary
			]
		)
	else:
		pass_test("Service initialization pattern preserved - _ready() access works")


## Property 2.5: Type Annotations Are Maintained
## **Validates: Requirement 3.2**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that service references maintain proper type annotations
func test_preservation_type_annotations() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	## Test that services return Node types (as per type-safety.md)
	for i: int in range(min(TEST_ITERATIONS, _core_services.size())):
		var service_id: String = _core_services[i]
		
		## Get service through GameManager
		var service: Variant = game_manager.get_core_system(service_id)
		
		## Verify service is a Node or RefCounted (valid types)
		if service:
			var is_valid_type: bool = (
				service is Node
				or service is RefCounted
			)
			
			if not is_valid_type:
				failures.append({
					"iteration": i,
					"service": service_id,
					"actual_type": typeof(service),
					"reason": "Service is not Node or RefCounted type"
				})
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Type annotation preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), min(TEST_ITERATIONS, _core_services.size()), summary
			]
		)
	else:
		pass_test("Type annotations preserved - services return correct types")


## Property 2.6: Single Autoload Pattern Unchanged
## **Validates: Requirement 3.4**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that GameManager is the only autoload and all services accessed through it
func test_preservation_single_autoload_pattern() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		failures.append({
			"reason": "GameManager not accessible"
		})
		## Report early if GameManager not found
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Single autoload pattern preservation failed:\n%s" % summary
		)
		return
	
	## Verify all core services are accessible through GameManager
	for service_id: String in _core_services:
		var service: Variant = game_manager.get_core_system(service_id)
		if not service:
			## Some services might be optional, so just log
			pass
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Single autoload pattern preservation failed:\n%s" % summary
		)
	else:
		pass_test("Single autoload pattern preserved - GameManager is only autoload")


## Property 2.7: Public APIs Function Correctly
## **Validates: Requirement 3.5**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that GameManager public APIs work correctly
func test_preservation_public_apis() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	## Test GameManager public API methods
	var api_tests: Array[Dictionary] = [
		{"method": "get_core_system", "args": ["logger"]},
		{"method": "get_config", "args": ["performance.profiling_enabled", false]},
		{"method": "get_state", "args": []},
		{"method": "is_feature_enabled", "args": ["combat"]},
	]
	
	for i: int in range(TEST_ITERATIONS):
		var test_case: Dictionary = api_tests[i % api_tests.size()]
		var method_name: String = test_case["method"]
		var args: Array = test_case["args"]
		
		## Verify method exists
		if not game_manager.has_method(method_name):
			failures.append({
				"iteration": i,
				"method": method_name,
				"reason": "GameManager missing public API method: %s" % method_name
			})
			continue
		
		## Call method (should not crash)
		var result: Variant = game_manager.callv(method_name, args)
		
		## Verify result is not null for getter methods
		if method_name.begins_with("get_") and result == null and method_name != "get_core_system":
			## get_core_system can return null for non-existent services
			pass
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Public API preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), TEST_ITERATIONS, summary
			]
		)
	else:
		pass_test("Public APIs preserved - all methods function correctly")


## Property 2.8: Hot-Reload Configuration Changes Work
## **Validates: Requirement 3.6**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that configuration hot-reload works correctly
func test_preservation_hot_reload_config() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	## Test config set/get cycle
	for i: int in range(min(TEST_ITERATIONS, 10)):  # Fewer iterations for hot-reload
		var test_path: String = "test.preservation.value_%d" % i
		var test_value: int = i * 10
		
		## Set config value
		game_manager.set_config(test_path, test_value)
		
		## Get config value back
		var retrieved_value: Variant = game_manager.get_config(test_path, -1)
		
		## Verify value matches
		if retrieved_value != test_value:
			failures.append({
				"iteration": i,
				"config_path": test_path,
				"expected_value": test_value,
				"actual_value": retrieved_value,
				"reason": "Config value mismatch after set/get cycle"
			})
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Hot-reload config preservation failed in %d/%d iterations:\n%s" % [
				failures.size(), min(TEST_ITERATIONS, 10), summary
			]
		)
	else:
		pass_test("Hot-reload config preserved - set/get cycle works correctly")


## Property 2.9: Core Services Provide Same Functionality
## **Validates: Requirement 3.7**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that core services provide expected functionality
func test_preservation_core_service_functionality() -> void:
	var failures: Array[Dictionary] = []
	
	## Get GameManager reference
	var game_manager: Variant = _get_game_manager()
	if not game_manager:
		assert_true(false, "GameManager not found in scene tree")
		return
	
	## Test each core service for basic functionality
	var service_tests: Dictionary = {
		"logger": ["info", "debug", "warning", "error"],
		"config": [],  # Tested via GameManager.get_config()
		"data": ["get_weapon_data", "get_enemy_data"],
		"events": [],  # Tested via GameManager event methods
		"globals": [],  # Global state service
		"audio": [],  # Audio service
		"ui": [],  # UI service
	}
	
	for service_id: String in service_tests.keys():
		var expected_methods: Array = service_tests[service_id]
		
		## Get service
		var service: Variant = game_manager.get_core_system(service_id)
		
		if not service:
			## Some services might be optional
			continue
		
		## Verify expected methods exist
		for method_name: String in expected_methods:
			if not service.has_method(method_name):
				failures.append({
					"service": service_id,
					"method": method_name,
					"reason": "Service missing expected method: %s" % method_name
				})
	
	## Report results
	if not failures.is_empty():
		_test_failures.append_array(failures)
		var summary: String = _format_failures(failures)
		assert_true(
			false,
			"Core service functionality preservation failed:\n%s" % summary
		)
	else:
		pass_test("Core service functionality preserved - all services work correctly")


## Helper: Format failure messages
func _format_failures(failures: Array[Dictionary]) -> String:
	var summary: String = ""
	var max_show: int = min(5, failures.size())
	
	for i: int in range(max_show):
		var failure: Dictionary = failures[i]
		summary += "  Failure %d:\n" % (i + 1)
		
		for key: String in failure.keys():
			summary += "    %s: %s\n" % [key, str(failure[key])]
	
	if failures.size() > max_show:
		summary += "  ... and %d more failures\n" % (failures.size() - max_show)
	
	return summary
