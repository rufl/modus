extends SceneTree

## Test script for RefactoringPlanner
##
## Run with: godot --headless --script tools/analyzer/test_refactoring_planner.gd

const RefactoringPlanner := preload("res://tools/analyzer/refactoring_planner.gd")
const ScriptScanner := preload("res://tools/analyzer/script_scanner.gd")
const DependencyAnalyzer := preload("res://tools/analyzer/dependency_analyzer.gd")
const GodScriptDetector := preload("res://tools/analyzer/god_script_detector.gd")
const MagicNumberDetector := preload("res://tools/analyzer/magic_number_detector.gd")


func _init() -> void:
	var separator := "="
	separator = separator.repeat(60)
	print(separator)
	print("Testing RefactoringPlanner")
	print(separator)
	
	# Create test data
	var script_infos := _create_test_script_infos()
	var dependency_infos := _create_test_dependency_infos()
	var god_script_results := _create_test_god_script_results()
	var magic_number_results := _create_test_magic_number_results()
	
	# Generate plan
	var planner := RefactoringPlanner.new()
	var plan := planner.generate_plan(
		script_infos,
		dependency_infos,
		god_script_results,
		magic_number_results
	)
	
	# Verify plan structure
	print("\n[TEST] Plan Structure")
	print("  Total scripts analyzed: %d" % plan.total_scripts_analyzed)
	print("  Issues found: %d" % plan.issues.size())
	print("  Suggested splits: %d" % plan.suggested_splits.size())
	print("  Migration phases: %d" % plan.migration_order.size())
	print("  Config externalizations: %d" % plan.configuration_externalization.size())
	
	# Test export to JSON5
	print("\n[TEST] Export to JSON5")
	var output_path := "tools/analyzer/test_refactoring_plan.json5"
	var success := planner.export_to_json5(plan, output_path)
	if success:
		print("  ✓ Successfully exported to: %s" % output_path)
	else:
		print("  ✗ Failed to export")
	
	# Verify JSON5 file exists
	if FileAccess.file_exists(output_path):
		print("  ✓ Output file exists")
		var file := FileAccess.open(output_path, FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		print("  File size: %d bytes" % content.length())
	else:
		print("  ✗ Output file not found")
	
	# Test plan dictionary conversion
	print("\n[TEST] Plan Dictionary Conversion")
	var plan_dict := plan.to_dict()
	print("  ✓ Converted to dictionary")
	print("  Keys: %s" % str(plan_dict.keys()))
	
	# Verify summary
	if plan_dict.has("summary"):
		var summary: Dictionary = plan_dict["summary"]
		print("  Summary:")
		print("    Total issues: %d" % summary.get("total_issues", 0))
		print("    God scripts: %d" % summary.get("god_scripts", 0))
		print("    Tight coupling: %d" % summary.get("tight_coupling", 0))
		print("    Magic numbers: %d" % summary.get("magic_numbers", 0))
	
	# Test migration order
	print("\n[TEST] Migration Order")
	for phase in plan.migration_order:
		if phase is RefactoringPlanner.MigrationPhase:
			print("  Phase %d: %s (%d files, effort: %s)" % [
				phase.phase_number,
				phase.phase_name,
				phase.files.size(),
				phase.estimated_effort
			])
	
	print("\n" + separator)
	print("All tests completed!")
	print(separator)
	
	quit()


func _create_test_script_infos() -> Array:
	var infos: Array = []
	
	# Create a test script info
	var info1 := ScriptScanner.ScriptInfo.new()
	info1.file_path = "game/core/services/combat_service.gd"
	info1.class_name_val = "CombatService"
	info1.line_count = 450
	
	# Add some methods
	for i in range(15):
		var method := ScriptScanner.MethodInfo.new()
		method.name = "method_%d" % i
		info1.methods.append(method)
	
	infos.append(info1)
	
	# Create another script
	var info2 := ScriptScanner.ScriptInfo.new()
	info2.file_path = "game/core/utils/math_utils.gd"
	info2.class_name_val = "MathUtils"
	info2.line_count = 100
	
	for i in range(5):
		var method := ScriptScanner.MethodInfo.new()
		method.name = "calculate_%d" % i
		info2.methods.append(method)
	
	infos.append(info2)
	
	return infos


func _create_test_dependency_infos() -> Array:
	var infos: Array = []
	
	# Create dependency info with autoload references
	var dep1 := DependencyAnalyzer.DependencyInfo.new()
	dep1.file_path = "game/core/services/combat_service.gd"
	
	for i in range(5):
		var autoload := DependencyAnalyzer.AutoloadDependency.new()
		autoload.autoload_name = "Autoload%d" % i
		autoload.line_number = i * 10
		dep1.autoload_references.append(autoload)
	
	infos.append(dep1)
	
	# Create dependency info with no dependencies
	var dep2 := DependencyAnalyzer.DependencyInfo.new()
	dep2.file_path = "game/core/utils/math_utils.gd"
	infos.append(dep2)
	
	return infos


func _create_test_god_script_results() -> Array:
	var results: Array = []
	
	# Create a god script result
	var result1 := GodScriptDetector.GodScriptResult.new()
	result1.file_path = "game/core/services/combat_service.gd"
	result1.is_god_script = true
	result1.line_count = 450
	result1.public_method_count = 15
	result1.reasons.append("exceeds 300 lines")
	result1.reasons.append("exceeds 10 public methods")
	
	results.append(result1)
	
	# Create a normal script result
	var result2 := GodScriptDetector.GodScriptResult.new()
	result2.file_path = "game/core/utils/math_utils.gd"
	result2.is_god_script = false
	result2.line_count = 100
	result2.public_method_count = 5
	
	results.append(result2)
	
	return results


func _create_test_magic_number_results() -> Array:
	var results: Array = []
	
	# Create magic number result
	var result1 := MagicNumberDetector.MagicNumberResult.new()
	result1.file_path = "game/core/services/combat_service.gd"
	
	for i in range(10):
		var magic := MagicNumberDetector.MagicNumber.new()
		magic.value = 100 + i * 10
		magic.value_type = "numeric"
		magic.line_number = i * 5
		magic.context = "var damage := %d" % magic.value
		result1.magic_numbers.append(magic)
	
	results.append(result1)
	
	return results
