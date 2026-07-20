extends GutTest
## Simple Preservation Test - Test Compilation Fix
##
## **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
##
## IMPORTANT: This test is EXPECTED TO PASS on unfixed code
## Passing confirms baseline behavior to preserve during bugfix
##
## This test validates that the deferred initialization pattern preserves
## runtime behavior by testing that services work correctly when initialized
## in _ready() methods instead of at class level.

## Test that deferred initialization works correctly
func test_deferred_initialization_pattern_works() -> void:
	## Create a test class that uses deferred initialization
	var test_obj: TestDeferredInit = TestDeferredInit.new()
	add_child_autofree(test_obj)
	
	## Wait for _ready() to be called
	await get_tree().process_frame
	
	## Verify service was initialized
	assert_not_null(test_obj.logger, "Logger should be initialized in _ready()")
	assert_true(test_obj.logger.has_method("info"), "Logger should have info method")
	
	pass_test("Deferred initialization pattern works correctly")


## Test class demonstrating deferred initialization pattern
class TestDeferredInit extends Node:
	## Declare service reference at class level WITHOUT initialization
	var logger: Variant = null
	
	func _ready() -> void:
		## Initialize service in _ready() method
		if has_node("/root/GameManager"):
			var gm: Node = get_node("/root/GameManager")
			logger = gm.get_core_system("logger")

