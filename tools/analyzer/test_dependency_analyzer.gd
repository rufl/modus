extends SceneTree

## Simple test for DependencyAnalyzer
## Run with: godot --headless --script tools/analyzer/test_dependency_analyzer.gd

const DependencyAnalyzer = preload("res://tools/analyzer/dependency_analyzer.gd")

func _init() -> void:
	print("=== Testing DependencyAnalyzer ===\n")

	var analyzer := DependencyAnalyzer.new()

	# Test 1: Analyze a simple script
	print("Test 1: Analyzing script_scanner.gd")
	var dep_info := analyzer.analyze_script("tools/analyzer/script_scanner.gd")
	if dep_info:
		print("  File: %s" % dep_info.file_path)
		print("  Imports: %d" % dep_info.imports.size())
		print("  Node references: %d" % dep_info.node_references.size())
		print("  Autoload references: %d" % dep_info.autoload_references.size())

		if dep_info.imports.size() > 0:
			print("  First import: %s" % dep_info.imports[0])
	else:
		print("  ERROR: Failed to analyze script")

	print()

	# Test 2: Generate dependency graph
	print("Test 2: Generating dependency graph")
	var scripts := [
		"tools/analyzer/script_scanner.gd",
		"tools/analyzer/dependency_analyzer.gd"
	]
	var dep_infos := analyzer.analyze_scripts(scripts)
	var graph := analyzer.generate_graph(dep_infos)

	print("  Graph nodes: %d" % graph.nodes.size())
	for node in graph.get_all_nodes():
		print("  - %s (deps: %d, dependents: %d)" % [
			node.file_path.get_file(),
			node.dependencies.size(),
			node.dependents.size()
		])

	print()

	# Test 3: Test import detection
	print("Test 3: Testing import detection")
	var test_script := "tools/analyzer/dependency_analyzer.gd"
	var test_info := analyzer.analyze_script(test_script)
	if test_info:
		print("  Detected %d imports" % test_info.imports.size())
		for import_dep in test_info.imports:
			if import_dep is DependencyAnalyzer.ImportDependency:
				print("    - %s: %s (line %d)" % [
					import_dep.import_type,
					import_dep.import_path,
					import_dep.line_number
				])

	print()

	# Test 4: Test autoload detection
	print("Test 4: Testing autoload detection")
	if test_info:
		print("  Detected %d autoload references" % test_info.autoload_references.size())
		var unique_autoloads := {}
		for autoload_dep in test_info.autoload_references:
			if autoload_dep is DependencyAnalyzer.AutoloadDependency:
				unique_autoloads[autoload_dep.autoload_name] = true
		print("  Unique autoloads: %s" % str(unique_autoloads.keys()))

	print()
	print("=== Tests Complete ===")

	quit()
