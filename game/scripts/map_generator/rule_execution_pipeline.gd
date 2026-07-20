## RuleExecutionPipeline - Executes rule modules in priority order
##
## This class manages the execution of rule modules during map generation.
## It executes rules in priority order within each phase, passes the generation
## context to rules, and tracks which rules were applied for metadata.
##
## **Validates: Requirements 24.4, 24.5**

class_name RuleExecutionPipeline
extends RefCounted

# Preload dependencies to avoid type resolution issues
const RuleModuleLoader = preload("res://game/scripts/map_generator/rule_module_loader.gd")
const RuleBase = preload("res://game/scripts/map_generator/rule_base.gd")

## Rule module loader
var _loader

## Logger reference
var _logger: Node = null

## Track applied rules for metadata
var _applied_rules: Array[String] = []


func _init(loader) -> void:
	_loader = loader

	# Get logger if available
	if GameManager and GameManager.has_method("get_core_system"):
		_logger = GameManager.get_core_system("logger")


## Execute all rules for a specific generation phase
##
## Rules are executed in priority order (highest priority first).
## Only rules where can_apply() returns true are executed.
## The generation context is passed to each rule for modification.
##
## @param phase: The generation phase name
## @param context: The generation context to pass to rules
## @return: true if all applicable rules executed successfully, false if any failed
func execute_phase(phase: String, context: GenerationContext) -> bool:
	_log_info("Executing rules for phase: %s" % phase)

	var rules: Array = _loader.get_rules_for_phase(phase)

	if rules.is_empty():
		_log_info("No rules registered for phase: %s" % phase)
		return true

	var executed_count := 0
	var skipped_count := 0
	var failed_count := 0

	for rule in rules:
		var rule_name: String = rule.get_rule_name()

		# Check if rule can be applied
		if not rule.can_apply(context):
			_log_debug("Rule '%s' skipped (can_apply returned false)" % rule_name)
			skipped_count += 1
			continue

		# Execute the rule
		_log_info("Applying rule: %s (priority=%d)" % [rule_name, rule.get_priority()])

		var success: bool = rule.apply(context)

		if success:
			executed_count += 1
			_applied_rules.append(rule_name)
			_log_info("Rule '%s' applied successfully" % rule_name)
		else:
			failed_count += 1
			_log_error("Rule '%s' failed to apply" % rule_name)
			return false

	_log_info(
		(
			"Phase '%s' complete: %d executed, %d skipped, %d failed"
			% [phase, executed_count, skipped_count, failed_count]
		)
	)

	return true


## Execute rules for multiple phases in sequence
##
## @param phases: Array of phase names to execute in order
## @param context: The generation context to pass to rules
## @return: true if all phases executed successfully, false if any failed
func execute_phases(phases: Array[String], context: GenerationContext) -> bool:
	for phase in phases:
		if not execute_phase(phase, context):
			_log_error("Phase '%s' failed, aborting pipeline" % phase)
			return false

	return true


## Execute a single rule by name (useful for testing or manual execution)
##
## @param rule_name: The name of the rule to execute
## @param context: The generation context to pass to the rule
## @return: true if the rule was found and executed successfully, false otherwise
func execute_rule_by_name(rule_name: String, context: GenerationContext) -> bool:
	var all_rules: Array = _loader.get_all_rules()

	for rule in all_rules:
		if rule.get_rule_name() == rule_name:
			if not rule.can_apply(context):
				_log_warning("Rule '%s' cannot be applied in current context" % rule_name)
				return false

			var success: bool = rule.apply(context)

			if success:
				_applied_rules.append(rule_name)
				_log_info("Rule '%s' executed successfully" % rule_name)
			else:
				_log_error("Rule '%s' failed to execute" % rule_name)

			return success

	_log_error("Rule '%s' not found" % rule_name)
	return false


## Get list of rules that were applied during generation
##
## This is used to populate the metadata for generated maps.
##
## @return: Array of rule names that were successfully applied
func get_applied_rules() -> Array[String]:
	return _applied_rules.duplicate()


## Reset the applied rules list (call before starting a new generation)
func reset() -> void:
	_applied_rules.clear()


## Get statistics about rule execution
##
## @return: Dictionary with execution statistics
func get_execution_stats() -> Dictionary:
	var stats := {
		"total_applied": _applied_rules.size(),
		"applied_rules": _applied_rules.duplicate(),
		"phases_with_rules": []
	}

	# Count rules per phase
	var phase_counts := {}
	for rule in _loader.get_all_rules():
		var phase: String = rule.get_phase()
		if not phase_counts.has(phase):
			phase_counts[phase] = 0
		phase_counts[phase] += 1

	stats["phases_with_rules"] = phase_counts

	return stats


## Logging helpers
func _log_info(message: String) -> void:
	if _logger and _logger.has_method("info"):
		_logger.info("RuleExecutionPipeline", message)
	else:
		print("[RuleExecutionPipeline] INFO: ", message)


func _log_debug(message: String) -> void:
	if _logger and _logger.has_method("debug"):
		_logger.debug("RuleExecutionPipeline", message)
	# Don't print debug messages to console by default


func _log_warning(message: String) -> void:
	if _logger and _logger.has_method("warning"):
		_logger.warning("RuleExecutionPipeline", message)
	else:
		push_warning("[RuleExecutionPipeline] WARNING: " + message)


func _log_error(message: String) -> void:
	if _logger and _logger.has_method("error"):
		_logger.error("RuleExecutionPipeline", message)
	else:
		push_error("[RuleExecutionPipeline] ERROR: " + message)
