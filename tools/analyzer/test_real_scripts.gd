extends SceneTree

const GodScriptDetector = preload("res://tools/analyzer/god_script_detector.gd")

func _init() -> void:
	print("\n=== Testing GodScriptDetector on Real Scripts ===\n")

	var detector := GodScriptDetector.new()

	# Test on the analyzer scripts themselves
	var test_files := [
		"res://tools/analyzer/script_scanner.gd",
		"res://tools/analyzer/dependency_analyzer.gd",
		"res://tools/analyzer/god_script_detector.gd"
	]

	var results := detector.analyze_scripts(test_files)

	var dash_line := "-"
	dash_line = dash_line.repeat(60)

	print("Analysis Results:")
	print(dash_line)
	for result in results:
		print("\nFile: %s" % result.file_path)
		print("  Lines: %d" % result.line_count)
		print("  Public Methods: %d" % result.public_method_count)
		print("  Is God Script: %s" % ("YES" if result.is_god_script else "NO"))
		if result.is_god_script:
			print("  Reasons: %s" % ", ".join(result.reasons))

	var separator := "="
	separator = separator.repeat(60)
	print("\n" + separator)
	print("\nGenerated Report:")
	print(detector.generate_report(results))

	quit()
