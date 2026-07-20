#!/usr/bin/env -S godot --headless --script
## Simple validation script for rule system (no GUT dependency)
## Usage:
## godot --headless --script game/scripts/map_generator/tests/simple_rule_system_validation.gd

extends SceneTree

const RuleBase = preload("res://game/scripts/map_generator/rule_base.gd")
const RuleModuleLoader = preload("res://game/scripts/map_generator/rule_module_loader.gd")
const RuleExecutionPipeline = preload("res://game/scripts/map_generator/rule_execution_pipeline.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")

var test_count := 0
var passed_count := 0
var failed_count := 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  RULE SYSTEM VALIDATION - Task 18")
	print("=".repeat(70) + "\n")

	run_tests()

	print("\n" + "=".repeat(70))
	print("  RESULTS")
	print("=".repeat(70))
	print("  Total:  %d" % test_count)
	print("  Passed: %d" % passed_count)
	print("  Failed: %d" % failed_count)
	print("=".repeat(70) + "\n")

	if failed_count == 0:
		print("✓ All validations passed!")
		quit(0)
	else:
		print("✗ Some validations failed")
		quit(1)


func run_tests() -> void:
	test_rule_base_exists()
	test_rule_loader_exists()
	test_rule_pipeline_exists()
	test_rule_loader_loads_rules()
	test_rule_pipeline_executes()
	test_example_rule_exists()


func test_rule_base_exists() -> void:
	test_count += 1
	print("Test: RuleBase class exists...")

	var rule := RuleBase.new()
	if rule != null:
		print("  ✓ PASS: RuleBase instantiated")
		passed_count += 1
	else:
		print("  ✗ FAIL: Could not instantiate RuleBase")
		failed_count += 1


func test_rule_loader_exists() -> void:
	test_count += 1
	print("Test: RuleModuleLoader class exists...")

	var loader := RuleModuleLoader.new()
	if loader != null:
		print("  ✓ PASS: RuleModuleLoader instantiated")
		passed_count += 1
	else:
		print("  ✗ FAIL: Could not instantiate RuleModuleLoader")
		failed_count += 1


func test_rule_pipeline_exists() -> void:
	test_count += 1
	print("Test: RuleExecutionPipeline class exists...")

	var loader := RuleModuleLoader.new()
	var pipeline := RuleExecutionPipeline.new(loader)
	if pipeline != null:
		print("  ✓ PASS: RuleExecutionPipeline instantiated")
		passed_count += 1
	else:
		print("  ✗ FAIL: Could not instantiate RuleExecutionPipeline")
		failed_count += 1


func test_rule_loader_loads_rules() -> void:
	test_count += 1
	print("Test: RuleModuleLoader can load rules...")

	var loader := RuleModuleLoader.new()
	var success := loader.load_rules()

	if success:
		var all_rules := loader.get_all_rules()
		print("  ✓ PASS: Loaded %d rules" % all_rules.size())
		passed_count += 1
	else:
		print("  ✗ FAIL: Could not load rules")
		failed_count += 1


func test_rule_pipeline_executes() -> void:
	test_count += 1
	print("Test: RuleExecutionPipeline can execute rules...")

	var loader := RuleModuleLoader.new()
	loader.load_rules()

	var pipeline := RuleExecutionPipeline.new(loader)
	var context := GenerationContext.new()
	var config := GenerationConfig.new()
	config.map_size = Vector2i(64, 64)
	context.config = config

	var success := pipeline.execute_phase("grid_layout", context)

	if success:
		print("  ✓ PASS: Pipeline executed grid_layout phase")

		# Check if grid was initialized
		if not context.grid.is_empty():
			print("  ✓ PASS: Grid was initialized by rules")
			passed_count += 1
		else:
			print("  ✗ FAIL: Grid was not initialized")
			failed_count += 1
	else:
		print("  ✗ FAIL: Pipeline execution failed")
		failed_count += 1


func test_example_rule_exists() -> void:
	test_count += 1
	print("Test: Example rule file exists...")

	var rule_path := "res://game/data/map_generator/rules/example_grid_init_rule.gd"
	if FileAccess.file_exists(rule_path):
		print("  ✓ PASS: Example rule file exists")
		passed_count += 1
	else:
		print("  ✗ FAIL: Example rule file not found")
		failed_count += 1
