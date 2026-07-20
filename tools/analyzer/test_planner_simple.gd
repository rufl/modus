extends SceneTree

## Simple test for RefactoringPlanner that creates mock data
## Run with: godot --headless --script tools/analyzer/test_planner_simple.gd

const RefactoringPlanner := preload("res://tools/analyzer/refactoring_planner.gd")


func _init() -> void:
	print("Testing RefactoringPlanner with mock data...")
	
	# Create mock data structures
	var script_infos: Array = []
	var dependency_infos: Array = []
	var god_script_results: Array = []
	var magic_number_results: Array = []
	
	# Add mock script info
	var mock_script := {
		"file_path": "game/core/services/combat_service.gd",
		"class_name_val": "CombatService",
		"line_count": 450,
		"methods": []
	}
	script_infos.append(mock_script)
	
	# Add mock dependency info
	var mock_dep := {
		"file_path": "game/core/services/combat_service.gd",
		"autoload_references": [
			{"autoload_name": "GameCore", "line_number": 10},
			{"autoload_name": "EventBus", "line_number": 20},
			{"autoload_name": "AudioManager", "line_number": 30},
			{"autoload_name": "NetworkManager", "line_number": 40}
		]
	}
	mock_dep["get_all_dependencies"] = func(): return mock_dep["autoload_references"]
	dependency_infos.append(mock_dep)
	
	# Add mock god script result
	var mock_god := {
		"file_path": "game/core/services/combat_service.gd",
		"is_god_script": true,
		"line_count": 450,
		"public_method_count": 15,
		"reasons": ["exceeds 300 lines", "exceeds 10 public methods"]
	}
	god_script_results.append(mock_god)
	
	# Add mock magic number result
	var mock_magic := {
		"file_path": "game/core/services/combat_service.gd",
		"magic_numbers": [
			{"value": 100, "value_type": "numeric", "line_number": 50, "context": "var damage := 100"},
			{"value": 2.5, "value_type": "numeric", "line_number": 60, "context": "var speed := 2.5"},
			{"value": "attack", "value_type": "string", "line_number": 70, "context": "var action := \"attack\""}
		]
	}
	magic_number_results.append(mock_magic)
	
	# Generate plan
	var planner := RefactoringPlanner.new()
	var plan := planner.generate_plan(
		script_infos,
		dependency_infos,
		god_script_results,
		magic_number_results
	)
	
	# Verify results
	print("\n✓ Plan generated successfully!")
	print("  Total scripts analyzed: %d" % plan.total_scripts_analyzed)
	print("  Issues found: %d" % plan.issues.size())
	print("  Suggested splits: %d" % plan.suggested_splits.size())
	print("  Migration phases: %d" % plan.migration_order.size())
	print("  Config externalizations: %d" % plan.configuration_externalization.size())
	
	# Export to JSON5
	var output_path := "tools/analyzer/test_plan_output.json5"
	var success := planner.export_to_json5(plan, output_path)
	
	if success:
		print("\n✓ Exported to: %s" % output_path)
		
		# Read and display first few lines
		if FileAccess.file_exists(output_path):
			var file := FileAccess.open(output_path, FileAccess.READ)
			var content := file.get_as_text()
			file.close()
			
			var lines := content.split("\n")
			print("\nFirst 10 lines of output:")
			for i in range(min(10, lines.size())):
				print("  %s" % lines[i])
	else:
		print("\n✗ Failed to export plan")
	
	print("\n✓ Test completed successfully!")
	quit()
