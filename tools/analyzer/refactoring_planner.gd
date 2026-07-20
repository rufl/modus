class_name RefactoringPlanner
extends RefCounted

## Refactoring Plan Generator for Architecture Analyzer
##
## Generates a comprehensive refactoring plan by integrating results from:
## - ScriptScanner: Script structure information
## - DependencyAnalyzer: Dependency relationships
## - GodScriptDetector: Scripts that need decomposition
## - MagicNumberDetector: Hardcoded values to externalize
##
## Outputs a JSON5 file with:
## - Identified issues
## - Suggested component splits
## - Migration order based on dependencies


## Complete refactoring plan
class RefactoringPlan:
	var analysis_date: String = ""
	var total_scripts_analyzed: int = 0
	var issues: Array = []  # Array of Issue
	var suggested_splits: Array = []  # Array of ComponentSplit
	var migration_order: Array = []  # Array of MigrationPhase
	var configuration_externalization: Array = []  # Array of ConfigExternalization
	
	func to_dict() -> Dictionary:
		var dict := {
			"analysis_date": analysis_date,
			"total_scripts_analyzed": total_scripts_analyzed,
			"summary": {
				"total_issues": issues.size(),
				"god_scripts": _count_issues_by_type("god_script"),
				"tight_coupling": _count_issues_by_type("tight_coupling"),
				"magic_numbers": _count_issues_by_type("magic_numbers")
			},
			"issues": [],
			"suggested_splits": [],
			"migration_order": [],
			"configuration_externalization": []
		}
		
		for issue in issues:
			if issue is Issue:
				dict["issues"].append(issue.to_dict())
		
		for split in suggested_splits:
			if split is ComponentSplit:
				dict["suggested_splits"].append(split.to_dict())
		
		for phase in migration_order:
			if phase is MigrationPhase:
				dict["migration_order"].append(phase.to_dict())
		
		for config in configuration_externalization:
			if config is ConfigExternalization:
				dict["configuration_externalization"].append(config.to_dict())
		
		return dict
	
	func _count_issues_by_type(issue_type: String) -> int:
		var count := 0
		for issue in issues:
			if issue is Issue and issue.issue_type == issue_type:
				count += 1
		return count


## Individual issue identified in the codebase
class Issue:
	var issue_type: String = ""  # "god_script", "tight_coupling", "magic_numbers"
	var severity: String = ""  # "high", "medium", "low"
	var file_path: String = ""
	var description: String = ""
	var metrics: Dictionary = {}
	
	func to_dict() -> Dictionary:
		return {
			"type": issue_type,
			"severity": severity,
			"file": file_path,
			"description": description,
			"metrics": metrics
		}


## Suggested component split for a god script
class ComponentSplit:
	var original_file: String = ""
	var reason: String = ""
	var suggested_components: Array = []  # Array of SuggestedComponent
	
	func to_dict() -> Dictionary:
		var components_array: Array = []
		for component in suggested_components:
			if component is SuggestedComponent:
				components_array.append(component.to_dict())
		
		return {
			"original_file": original_file,
			"reason": reason,
			"suggested_components": components_array
		}


## Individual suggested component from a split
class SuggestedComponent:
	var component_name: String = ""
	var responsibility: String = ""
	var methods: Array[String] = []
	var signals_list: Array[String] = []
	var variables: Array[String] = []
	
	func to_dict() -> Dictionary:
		return {
			"name": component_name,
			"responsibility": responsibility,
			"methods": methods,
			"signals": signals_list,
			"variables": variables
		}


## Migration phase with ordered tasks
class MigrationPhase:
	var phase_number: int = 0
	var phase_name: String = ""
	var description: String = ""
	var files: Array[String] = []
	var dependencies: Array[String] = []  # Files that must be migrated first
	var estimated_effort: String = ""  # "low", "medium", "high"
	
	func to_dict() -> Dictionary:
		return {
			"phase": phase_number,
			"name": phase_name,
			"description": description,
			"files": files,
			"dependencies": dependencies,
			"estimated_effort": estimated_effort
		}


## Configuration externalization suggestion
class ConfigExternalization:
	var file_path: String = ""
	var config_file: String = ""
	var values_to_externalize: Array = []  # Array of ValueToExternalize
	
	func to_dict() -> Dictionary:
		var values_array: Array = []
		for value in values_to_externalize:
			if value is ValueToExternalize:
				values_array.append(value.to_dict())
		
		return {
			"source_file": file_path,
			"target_config": config_file,
			"values": values_array
		}


## Individual value to externalize
class ValueToExternalize:
	var value: Variant = null
	var value_type: String = ""
	var line_number: int = 0
	var suggested_key: String = ""
	var context: String = ""
	
	func to_dict() -> Dictionary:
		return {
			"value": str(value),
			"type": value_type,
			"line": line_number,
			"suggested_key": suggested_key,
			"context": context
		}


## Generate a complete refactoring plan
func generate_plan(
	script_infos: Array,
	dependency_infos: Array,
	god_script_results: Array,
	magic_number_results: Array
) -> RefactoringPlan:
	var plan := RefactoringPlan.new()
	plan.analysis_date = Time.get_datetime_string_from_system()
	plan.total_scripts_analyzed = script_infos.size()
	
	# Identify issues
	_identify_god_script_issues(god_script_results, plan)
	_identify_coupling_issues(dependency_infos, plan)
	_identify_magic_number_issues(magic_number_results, plan)
	
	# Generate component splits for god scripts
	_generate_component_splits(god_script_results, script_infos, plan)
	
	# Generate configuration externalization suggestions
	_generate_config_externalization(magic_number_results, plan)
	
	# Generate migration order based on dependencies
	var dep_graph := _build_dependency_graph(dependency_infos)
	_generate_migration_order(dep_graph, god_script_results, plan)
	
	return plan


## Export plan to JSON5 format
func export_to_json5(plan: RefactoringPlan, output_path: String) -> bool:
	var dict := plan.to_dict()
	var json_string := JSONHelper.safe_stringify(dict, "\t")
	
	# Add JSON5 header comment
	var json5_content := "// Refactoring Plan Generated: %s\n" % plan.analysis_date
	json5_content += "// Total Scripts Analyzed: %d\n\n" % plan.total_scripts_analyzed
	json5_content += json_string
	
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_error("[RefactoringPlanner] Failed to write to: %s" % output_path)
		return false
	
	file.store_string(json5_content)
	file.close()
	
	print("[RefactoringPlanner] Refactoring plan exported to: %s" % output_path)
	return true


## Identify god script issues
func _identify_god_script_issues(god_script_results: Array, plan: RefactoringPlan) -> void:
	for result in god_script_results:
		if result is GodScriptDetector.GodScriptResult and result.is_god_script:
			var issue := Issue.new()
			issue.issue_type = "god_script"
			issue.file_path = result.file_path
			issue.description = "Script has too many responsibilities: %s" % ", ".join(result.reasons)
			issue.metrics = {
				"line_count": result.line_count,
				"public_method_count": result.public_method_count
			}
			
			# Determine severity based on how much it exceeds thresholds
			if result.line_count > 600 or result.public_method_count > 20:
				issue.severity = "high"
			elif result.line_count > 450 or result.public_method_count > 15:
				issue.severity = "medium"
			else:
				issue.severity = "low"
			
			plan.issues.append(issue)


## Identify tight coupling issues
func _identify_coupling_issues(dependency_infos: Array, plan: RefactoringPlan) -> void:
	for dep_info in dependency_infos:
		if dep_info is DependencyAnalyzer.DependencyInfo:
			var autoload_count: int = dep_info.autoload_references.size()
			
			# Flag files with excessive autoload dependencies
			if autoload_count > 3:
				var issue := Issue.new()
				issue.issue_type = "tight_coupling"
				issue.file_path = dep_info.file_path
				issue.description = "Excessive autoload dependencies (%d references)" % autoload_count
				issue.metrics = {
					"autoload_count": autoload_count,
					"total_dependencies": dep_info.get_all_dependencies().size()
				}
				
				if autoload_count > 6:
					issue.severity = "high"
				elif autoload_count > 4:
					issue.severity = "medium"
				else:
					issue.severity = "low"
				
				plan.issues.append(issue)


## Identify magic number issues
func _identify_magic_number_issues(magic_number_results: Array, plan: RefactoringPlan) -> void:
	for result in magic_number_results:
		# Check if it's a MagicNumberResult using duck typing
		if result.has("magic_numbers") and result.has("file_path"):
			var magic_count: int = result.magic_numbers.size()
			
			# Only flag files with significant magic numbers
			if magic_count > 5:
				var issue := Issue.new()
				issue.issue_type = "magic_numbers"
				issue.file_path = result.file_path
				issue.description = "Contains %d hardcoded values that should be externalized" % magic_count
				issue.metrics = {
					"magic_number_count": magic_count
				}
				
				if magic_count > 20:
					issue.severity = "high"
				elif magic_count > 10:
					issue.severity = "medium"
				else:
					issue.severity = "low"
				
				plan.issues.append(issue)


## Generate component split suggestions
func _generate_component_splits(
	god_script_results: Array,
	script_infos: Array,
	plan: RefactoringPlan
) -> void:
	# Create a lookup map for script infos
	var script_info_map := {}
	for info in script_infos:
		if info is ScriptScanner.ScriptInfo:
			script_info_map[info.file_path] = info
	
	for result in god_script_results:
		if result is GodScriptDetector.GodScriptResult and result.is_god_script:
			var script_info: ScriptScanner.ScriptInfo = script_info_map.get(result.file_path)
			if not script_info:
				continue
			
			var split := ComponentSplit.new()
			split.original_file = result.file_path
			split.reason = "God script with %d lines and %d public methods" % [
				result.line_count, result.public_method_count
			]
			
			# Suggest splitting based on method grouping
			split.suggested_components = _suggest_component_grouping(script_info)
			
			plan.suggested_splits.append(split)


## Suggest component grouping based on method names and patterns
func _suggest_component_grouping(script_info: ScriptScanner.ScriptInfo) -> Array:
	var components: Array = []
	
	# Group methods by common prefixes/patterns
	var method_groups := {}
	
	for method in script_info.methods:
		if method is ScriptScanner.MethodInfo:
			var prefix := _extract_method_prefix(method.name)
			if not method_groups.has(prefix):
				method_groups[prefix] = []
			method_groups[prefix].append(method.name)
	
	# Create suggested components from groups
	for prefix in method_groups:
		if method_groups[prefix].size() >= 2:  # Only suggest if multiple methods
			var component := SuggestedComponent.new()
			component.component_name = "%sComponent" % prefix.capitalize()
			component.responsibility = "Handle %s-related functionality" % prefix
			component.methods = method_groups[prefix]
			components.append(component)
	
	# If no clear grouping, suggest splitting by method count
	if components.is_empty() and script_info.methods.size() > 10:
		var half := script_info.methods.size() / 2
		
		var component1 := SuggestedComponent.new()
		component1.component_name = "%sCore" % script_info.class_name_val
		component1.responsibility = "Core functionality"
		for i in range(half):
			if i < script_info.methods.size():
				var method: ScriptScanner.MethodInfo = script_info.methods[i]
				component1.methods.append(method.name)
		
		var component2 := SuggestedComponent.new()
		component2.component_name = "%sExtended" % script_info.class_name_val
		component2.responsibility = "Extended functionality"
		for i in range(half, script_info.methods.size()):
			var method: ScriptScanner.MethodInfo = script_info.methods[i]
			component2.methods.append(method.name)
		
		components.append(component1)
		components.append(component2)
	
	return components


## Extract method prefix for grouping
func _extract_method_prefix(method_name: String) -> String:
	# Common patterns: get_*, set_*, handle_*, process_*, update_*, etc.
	var parts := method_name.split("_", false, 1)
	if parts.size() > 0:
		var prefix: String = parts[0]
		# Common action verbs
		if prefix in ["get", "set", "handle", "process", "update", "apply", "calculate", "validate", "init", "load", "save"]:
			return prefix
	
	# Default to "misc" if no clear prefix
	return "misc"


## Generate configuration externalization suggestions
func _generate_config_externalization(magic_number_results: Array, plan: RefactoringPlan) -> void:
	for result in magic_number_results:
		# Check if it's a MagicNumberResult using duck typing
		if result.has("magic_numbers") and result.has("file_path") and result.magic_numbers.size() > 0:
			var config_ext := ConfigExternalization.new()
			config_ext.file_path = result.file_path
			config_ext.config_file = _suggest_config_file(result.file_path)
			
			for magic in result.magic_numbers:
				# Check if it's a MagicNumber using duck typing
				if magic.has("value") and magic.has("value_type"):
					var value_to_ext := ValueToExternalize.new()
					value_to_ext.value = magic.value
					value_to_ext.value_type = magic.value_type
					value_to_ext.line_number = magic.line_number
					value_to_ext.suggested_key = _suggest_config_key(result.file_path, magic)
					value_to_ext.context = magic.context
					config_ext.values_to_externalize.append(value_to_ext)
			
			plan.configuration_externalization.append(config_ext)


## Suggest appropriate config file based on file path
func _suggest_config_file(file_path: String) -> String:
	var path_lower := file_path.to_lower()
	
	if "combat" in path_lower or "damage" in path_lower or "weapon" in path_lower:
		return "game/config/gameplay/combat.json5"
	elif "movement" in path_lower or "player" in path_lower:
		return "game/config/gameplay/movement.json5"
	elif "audio" in path_lower or "sound" in path_lower:
		return "game/config/features/audio.json5"
	elif "network" in path_lower or "multiplayer" in path_lower:
		return "game/config/features/network.json5"
	elif "ui" in path_lower or "menu" in path_lower:
		return "game/config/ui.json5"
	elif "performance" in path_lower or "graphics" in path_lower:
		return "game/config/performance/graphics.json5"
	else:
		return "game/config/core.json5"


## Suggest configuration key name
func _suggest_config_key(file_path: String, magic: Variant) -> String:
	var file_name := file_path.get_file().get_basename()
	var context_lower: String = magic.context.to_lower()
	
	# Try to extract variable name from context
	var key_parts: Array[String] = []
	
	# Add file-based prefix
	key_parts.append(file_name.to_snake_case())
	
	# Try to infer purpose from context
	if "speed" in context_lower:
		key_parts.append("speed")
	elif "damage" in context_lower:
		key_parts.append("damage")
	elif "health" in context_lower or "hp" in context_lower:
		key_parts.append("health")
	elif "range" in context_lower or "distance" in context_lower:
		key_parts.append("range")
	elif "cooldown" in context_lower or "delay" in context_lower:
		key_parts.append("cooldown")
	elif "size" in context_lower or "scale" in context_lower:
		key_parts.append("size")
	else:
		key_parts.append("value")
	
	return "_".join(key_parts)


## Build dependency graph from dependency infos
func _build_dependency_graph(dependency_infos: Array) -> DependencyAnalyzer.DependencyGraph:
	var analyzer := DependencyAnalyzer.new()
	return analyzer.generate_graph(dependency_infos)


## Generate migration order based on dependency graph
func _generate_migration_order(
	dep_graph: DependencyAnalyzer.DependencyGraph,
	god_script_results: Array,
	plan: RefactoringPlan
) -> void:
	# Phase 1: Core infrastructure (no dependencies)
	var phase1 := MigrationPhase.new()
	phase1.phase_number = 1
	phase1.phase_name = "Core Infrastructure"
	phase1.description = "Migrate core systems with no dependencies"
	phase1.estimated_effort = "high"
	phase1.files = _find_files_with_no_dependencies(dep_graph)
	plan.migration_order.append(phase1)
	
	# Phase 2: Utility and helper scripts
	var phase2 := MigrationPhase.new()
	phase2.phase_number = 2
	phase2.phase_name = "Utilities and Helpers"
	phase2.description = "Migrate utility scripts and helpers"
	phase2.estimated_effort = "low"
	phase2.dependencies = phase1.files.duplicate()
	phase2.files = _find_utility_files(dep_graph)
	plan.migration_order.append(phase2)
	
	# Phase 3: God scripts (high priority refactoring)
	var phase3 := MigrationPhase.new()
	phase3.phase_number = 3
	phase3.phase_name = "God Script Decomposition"
	phase3.description = "Decompose god scripts into components"
	phase3.estimated_effort = "high"
	phase3.dependencies = phase2.files.duplicate()
	phase3.files = _extract_god_script_paths(god_script_results)
	plan.migration_order.append(phase3)
	
	# Phase 4: Remaining scripts
	var phase4 := MigrationPhase.new()
	phase4.phase_number = 4
	phase4.phase_name = "Remaining Scripts"
	phase4.description = "Migrate all remaining scripts"
	phase4.estimated_effort = "medium"
	phase4.dependencies = phase3.files.duplicate()
	phase4.files = _find_remaining_files(dep_graph, phase1.files + phase2.files + phase3.files)
	plan.migration_order.append(phase4)


## Find files with no dependencies
func _find_files_with_no_dependencies(dep_graph: DependencyAnalyzer.DependencyGraph) -> Array[String]:
	var files: Array[String] = []
	for node in dep_graph.get_all_nodes():
		if node is DependencyAnalyzer.DependencyGraphNode:
			if node.dependencies.is_empty():
				files.append(node.file_path)
	return files


## Find utility files (typically in utils/ or helpers/)
func _find_utility_files(dep_graph: DependencyAnalyzer.DependencyGraph) -> Array[String]:
	var files: Array[String] = []
	for node in dep_graph.get_all_nodes():
		if node is DependencyAnalyzer.DependencyGraphNode:
			var path_lower: String = node.file_path.to_lower()
			if "util" in path_lower or "helper" in path_lower or "common" in path_lower:
				files.append(node.file_path)
	return files


## Extract file paths from god script results
func _extract_god_script_paths(god_script_results: Array) -> Array[String]:
	var paths: Array[String] = []
	for result in god_script_results:
		if result is GodScriptDetector.GodScriptResult and result.is_god_script:
			paths.append(result.file_path)
	return paths


## Find remaining files not in previous phases
func _find_remaining_files(
	dep_graph: DependencyAnalyzer.DependencyGraph,
	processed_files: Array
) -> Array[String]:
	var files: Array[String] = []
	for node in dep_graph.get_all_nodes():
		if node is DependencyAnalyzer.DependencyGraphNode:
			if not node.file_path in processed_files:
				files.append(node.file_path)
	return files
