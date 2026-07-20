extends SceneTree

## Simple test script to verify ScriptScanner functionality
## Run with: godot --headless --script tools/analyzer/test_script_scanner.gd


func _init() -> void:
	print("=== Script Scanner Test ===\n")
	
	var ScriptScannerClass = load("res://tools/analyzer/script_scanner.gd")
	var scanner = ScriptScannerClass.new()
	
	# Test 1: Scan a single file
	print("Test 1: Scanning single file (json5_loader.gd)")
	var single_result = scanner.parse_script("res://game/core/json5_loader.gd")
	if single_result:
		print("  ✓ File: %s" % single_result.file_path)
		print("  ✓ Class: %s" % single_result.class_name_val)
		print("  ✓ Extends: %s" % single_result.extends_class)
		print("  ✓ Lines: %d" % single_result.line_count)
		print("  ✓ Methods: %d" % single_result.methods.size())
		print("  ✓ Variables: %d" % single_result.variables.size())
		print("  ✓ Imports: %d" % single_result.imports.size())
		
		# Show some methods
		if single_result.methods.size() > 0:
			print("\n  Methods found:")
			for method in single_result.methods:
				var params := ", ".join(method.parameters) if method.parameters.size() > 0 else ""
				var return_str := " -> %s" % method.return_type if method.return_type else ""
				print("    - %s(%s)%s" % [method.name, params, return_str])
	else:
		print("  ✗ Failed to parse file")
	
	print("\n" + "=".repeat(50) + "\n")
	
	# Test 2: Scan a directory
	print("Test 2: Scanning directory (game/core/)")
	var dir_results = scanner.scan_directory("res://game/core/")
	print("  ✓ Found %d script files" % dir_results.size())
	
	if dir_results.size() > 0:
		print("\n  Sample of scanned files:")
		var count := 0
		for script_info in dir_results:
			if count >= 5:
				break
			print("    - %s (%d lines, %d methods)" % [
				script_info.file_path.get_file(),
				script_info.line_count,
				script_info.methods.size()
			])
			count += 1
		
		if dir_results.size() > 5:
			print("    ... and %d more files" % (dir_results.size() - 5))
	
	print("\n" + "=".repeat(50) + "\n")
	
	# Test 3: Count total methods and classes
	print("Test 3: Statistics")
	var total_methods := 0
	var total_signals := 0
	var total_variables := 0
	var classes_with_names := 0
	
	for script_info in dir_results:
		total_methods += script_info.methods.size()
		total_signals += script_info.signals_list.size()
		total_variables += script_info.variables.size()
		if not script_info.class_name_val.is_empty():
			classes_with_names += 1
	
	print("  ✓ Total scripts: %d" % dir_results.size())
	print("  ✓ Named classes: %d" % classes_with_names)
	print("  ✓ Total methods: %d" % total_methods)
	print("  ✓ Total signals: %d" % total_signals)
	print("  ✓ Total variables: %d" % total_variables)
	
	print("\n=== All Tests Complete ===")
	quit()
