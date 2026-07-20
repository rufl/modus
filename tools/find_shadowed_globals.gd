#!/usr/bin/env -S godot --headless --script
## Script to find all SHADOWED_GLOBAL_IDENTIFIER warnings in the codebase
## Usage: godot --headless --script tools/find_shadowed_globals.gd

extends SceneTree

func _init() -> void:
	print("Scanning for SHADOWED_GLOBAL_IDENTIFIER warnings...")
	print("=" .repeat(80))
	
	var files: Array[String] = []
	_scan_directory("res://game", files)
	_scan_directory("res://shared", files)
	_scan_directory("res://tests", files)
	
	print("\nFound %d GDScript files to check" % files.size())
	print("=".repeat(80))
	
	var issues: Array[Dictionary] = []
	
	for file_path in files:
		var script: Script = load(file_path)
		if script:
			var source: String = script.source_code
			var lines: PackedStringArray = source.split("\n")
			
			# Check for common shadowed globals
			for line_num in range(lines.size()):
				var line: String = lines[line_num]
				var shadowed: String = _check_line_for_shadowing(line)
				if shadowed != "":
					issues.append({
						"file": file_path,
						"line": line_num + 1,
						"content": line.strip_edges(),
						"shadowed": shadowed
					})
	
	print("\n\nFOUND %d POTENTIAL SHADOWING ISSUES:" % issues.size())
	print("=".repeat(80))
	
	for issue in issues:
		print("\n%s:%d" % [issue.file, issue.line])
		print("  Shadows: %s" % issue.shadowed)
		print("  Code: %s" % issue.content)
	
	print("\n" + "=".repeat(80))
	print("Scan complete!")
	quit()

func _scan_directory(path: String, files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path: String = path + "/" + file_name
		
		if dir.current_is_dir():
			_scan_directory(full_path, files)
		elif file_name.ends_with(".gd"):
			files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _check_line_for_shadowing(line: String) -> String:
	# Common Godot global identifiers that shouldn't be shadowed
	var globals: Array[String] = [
		"Error", "OK", "FAILED",
		"Vector2", "Vector3", "Vector4",
		"Color", "Transform", "Transform2D", "Transform3D",
		"Basis", "Quaternion", "Plane", "AABB", "Rect2", "Rect2i",
		"Node", "Object", "Resource", "Script", "Shader",
		"Texture", "Material", "Mesh", "Image", "Font", "Theme",
		"Control", "Button", "Label", "Panel", "Container",
		"Timer", "HTTPRequest", "JSON",
		"Dictionary", "Array", "String", "Callable", "Signal",
		"PI", "TAU", "INF", "NAN"
	]
	
	# Check if line declares a variable with a global name
	for global_name in globals:
		# Match patterns like: var Error =, var Error:, var Error\s
		var patterns: Array[String] = [
			"var " + global_name + " =",
			"var " + global_name + ":",
			"var " + global_name + "\t",
			"var " + global_name + " ",
			"func " + global_name + "(",
			"const " + global_name + " =",
			"const " + global_name + ":"
		]
		
		for pattern in patterns:
			if line.contains(pattern):
				return global_name
	
	return ""
