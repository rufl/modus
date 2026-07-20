extends GutTest

## Tests for the modular rule system
## **Validates: Requirements 24.1, 24.2, 24.3, 24.4, 24.5, 24.6**

var loader: RuleModuleLoader
var pipeline: RuleExecutionPipeline
var context: GenerationContext


func before_each() -> void:
	loader = RuleModuleLoader.new()
	pipeline = RuleExecutionPipeline.new(loader)
	context = GenerationContext.new()

	# Setup basic context
	var config := GenerationConfig.new()
	config.map_size = Vector2i(64, 64)
	context.config = config
	context.rng.seed = 12345


func after_each() -> void:
	loader = null
	pipeline = null
	context = null


func test_rule_base_abstract_methods() -> void:
	# Test that RuleBase methods must be overridden
	var base_rule := RuleBase.new()

	assert_false(base_rule.can_apply(context), "RuleBase.can_apply should return false")
	assert_false(base_rule.apply(context), "RuleBase.apply should return false")
	assert_eq(base_rule.get_priority(), 0, "RuleBase.get_priority should return 0")
	assert_eq(
		base_rule.get_rule_name(), "BaseRule", "RuleBase.get_rule_name should return 'BaseRule'"
	)
	assert_eq(base_rule.get_phase(), "unknown", "RuleBase.get_phase should return 'unknown'")


func test_rule_loader_loads_rules() -> void:
	# Test that the loader can load rules from the rules directory
	var success := loader.load_rules()

	assert_true(success, "Rule loader should load successfully")

	var all_rules := loader.get_all_rules()
	assert_gt(all_rules.size(), 0, "Should load at least one rule (example rule)")


func test_rule_loader_organizes_by_phase() -> void:
	# Test that rules are organized by phase
	loader.load_rules()

	var grid_layout_rules := loader.get_rules_for_phase("grid_layout")
	assert_gt(grid_layout_rules.size(), 0, "Should have at least one grid_layout rule")

	# Check that the example rule is in the grid_layout phase
	var found_example := false
	for rule: RuleBase in grid_layout_rules:
		if rule.get_rule_name() == "ExampleGridInitRule":
			found_example = true
			break

	assert_true(found_example, "Should find ExampleGridInitRule in grid_layout phase")


func test_rule_execution_pipeline() -> void:
	# Test that the pipeline can execute rules
	loader.load_rules()
	pipeline.reset()

	var success := pipeline.execute_phase("grid_layout", context)

	assert_true(success, "Pipeline should execute grid_layout phase successfully")

	# Check that the grid was initialized by the example rule
	assert_false(
		context.grid.is_empty(), "Grid should be initialized after executing grid_layout phase"
	)
	assert_eq(context.grid.size(), 64, "Grid should have 64 rows")
	assert_eq(context.grid[0].size(), 64, "Grid should have 64 columns")


func test_rule_priority_ordering() -> void:
	# Test that rules are executed in priority order
	loader.load_rules()

	var grid_layout_rules := loader.get_rules_for_phase("grid_layout")

	# Rules should be sorted by priority (highest first)
	for i in range(grid_layout_rules.size() - 1):
		var current_priority: int = grid_layout_rules[i].get_priority()
		var next_priority: int = grid_layout_rules[i + 1].get_priority()
		assert_true(
			current_priority >= next_priority, "Rules should be sorted by priority (highest first)"
		)


func test_pipeline_tracks_applied_rules() -> void:
	# Test that the pipeline tracks which rules were applied
	loader.load_rules()
	pipeline.reset()

	pipeline.execute_phase("grid_layout", context)

	var applied_rules := pipeline.get_applied_rules()
	assert_gt(applied_rules.size(), 0, "Should have applied at least one rule")
	assert_true(applied_rules.has("ExampleGridInitRule"), "Should have applied ExampleGridInitRule")


func test_rule_can_apply_check() -> void:
	# Test that rules are only executed if can_apply returns true
	loader.load_rules()
	pipeline.reset()

	# Create a context with invalid config
	var invalid_context := GenerationContext.new()
	invalid_context.config = null

	# The example rule should not apply without a valid config
	var grid_layout_rules := loader.get_rules_for_phase("grid_layout")
	for rule: RuleBase in grid_layout_rules:
		if rule.get_rule_name() == "ExampleGridInitRule":
			assert_false(
				rule.can_apply(invalid_context),
				"ExampleGridInitRule should not apply without valid config"
			)


func test_pipeline_execution_stats() -> void:
	# Test that the pipeline provides execution statistics
	loader.load_rules()
	pipeline.reset()

	pipeline.execute_phase("grid_layout", context)

	var stats := pipeline.get_execution_stats()
	assert_has(stats, "total_applied", "Stats should include total_applied")
	assert_has(stats, "applied_rules", "Stats should include applied_rules")
	assert_has(stats, "phases_with_rules", "Stats should include phases_with_rules")
	assert_gt(stats["total_applied"], 0, "Should have applied at least one rule")


func test_rule_names_for_metadata() -> void:
	# Test that we can get rule names for metadata
	loader.load_rules()

	var rule_names := loader.get_rule_names()
	assert_gt(rule_names.size(), 0, "Should have at least one rule name")
	assert_true(
		rule_names.has("ExampleGridInitRule"), "Should include ExampleGridInitRule in rule names"
	)
