class_name DependencyAnalyzer
extends RefCounted

## Dependency Analyzer for Architecture Analyzer
##
## Analyzes GDScript files to detect dependencies:
## - Imports (preload, load, class_name references)
## - get_node calls and autoload references
## - Generates dependency graphs
##
## Used to understand coupling and plan refactoring.


## Dependency information for a script
class DependencyInfo:
	var file_path: String = ""
	var imports: Array = []  # Array of ImportDependency
	var node_references: Array = []  # Array of NodeDependency
	var autoload_references: Array = []  # Array of AutoloadDependency

	func get_all_dependencies() -> Array:
		var all_deps: Array = []
		all_deps.append_array(imports)
		all_deps.append_array(node_references)
		all_deps.append_array(autoload_references)
		return all_deps

	func _to_string() -> String:
		return "DependencyInfo(%s, %d imports, %d nodes, %d autoloads)" % [
			file_path, imports.size(), node_references.size(), autoload_references.size()
		]


## Import dependency (preload, load, class_name reference)
class ImportDependency:
	var import_path: String = ""
	var import_type: String = ""  # "preload", "load", "class_name"
	var line_number: int = 0

	func _to_string() -> String:
		return "Import(%s: %s)" % [import_type, import_path]


## Node reference dependency (get_node, $, etc.)
class NodeDependency:
	var node_path: String = ""
	var reference_type: String = ""  # "get_node", "$", "find_child", etc.
	var line_number: int = 0

	func _to_string() -> String:
		return "Node(%s: %s)" % [reference_type, node_path]


## Autoload reference dependency
class AutoloadDependency:
	var autoload_name: String = ""
	var line_number: int = 0

	func _to_string() -> String:
		return "Autoload(%s)" % autoload_name


## Dependency graph node
class DependencyGraphNode:
	var file_path: String = ""
	var dependencies: Array = []  # Array of file paths this node depends on
	var dependents: Array = []  # Array of file paths that depend on this node

	func _to_string() -> String:
		return "DependencyGraphNode(%s, %d deps, %d dependents)" % [
			file_path, dependencies.size(), dependents.size()
		]


## Dependency graph
class DependencyGraph:
	var nodes: Dictionary = {}  # file_path -> DependencyGraphNode

	func add_node(file_path: String) -> DependencyGraphNode:
		if not nodes.has(file_path):
			var node := DependencyGraphNode.new()
			node.file_path = file_path
			nodes[file_path] = node
		return nodes[file_path]

	func add_dependency(from_path: String, to_path: String) -> void:
		var from_node := add_node(from_path)
		var to_node := add_node(to_path)

		if not to_path in from_node.dependencies:
			from_node.dependencies.append(to_path)

		if not from_path in to_node.dependents:
			to_node.dependents.append(from_path)

	func get_node(file_path: String) -> DependencyGraphNode:
		return nodes.get(file_path)

	func get_all_nodes() -> Array:
		return nodes.values()

	func _to_string() -> String:
		return "DependencyGraph(%d nodes)" % nodes.size()


# Known autoloads - can be extended by loading from project.godot
var _known_autoloads: Array = [
	"GameCore",
	"EventBus",
	"GameDatabase",
	"GameManager",
	"AudioManager",
	"InputManager",
	"NetworkManager",
	"SaveManager",
	"SceneManager",
	"UIManager"
]


## Analyze a single script file for dependencies
## Returns DependencyInfo on success, null on failure
## Always check for null before using the result
func analyze_script(file_path: String) -> DependencyInfo:
	if not FileAccess.file_exists(file_path):
		push_error("[DependencyAnalyzer] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[DependencyAnalyzer] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null

	var content := file.get_as_text()
	file.close()

	var info := DependencyInfo.new()
	info.file_path = file_path

	var lines := content.split("\n")
	_analyze_lines(lines, info)

	return info


## Analyze multiple scripts and return dependency information
func analyze_scripts(file_paths: Array) -> Array:
	var results: Array = []
	for path in file_paths:
		var dep_info := analyze_script(path)
		if dep_info:
			results.append(dep_info)
	return results


## Generate dependency graph from dependency information
func generate_graph(dependency_infos: Array) -> DependencyGraph:
	var graph := DependencyGraph.new()

	# First pass: add all nodes
	for dep_info in dependency_infos:
		if dep_info is DependencyInfo:
			graph.add_node(dep_info.file_path)

	# Second pass: add dependencies
	for dep_info in dependency_infos:
		if dep_info is DependencyInfo:
			for import_dep in dep_info.imports:
				if import_dep is ImportDependency:
					var resolved_path := _resolve_import_path(import_dep.import_path, dep_info.file_path)
					if resolved_path:
						graph.add_dependency(dep_info.file_path, resolved_path)

	return graph


## Analyze lines of a script to extract dependencies
func _analyze_lines(lines: Array, info: DependencyInfo) -> void:
	var in_multiline_comment := false
	var line_number := 0

	for line in lines:
		line_number += 1
		var stripped: String = line.strip_edges()

		# Handle multiline comments
		if "\"\"\"" in stripped or "'''" in stripped:
			in_multiline_comment = not in_multiline_comment
			continue

		if in_multiline_comment:
			continue

		# Skip single-line comments
		if stripped.begins_with("#"):
			continue

		# Remove inline comments
		var comment_pos: int = stripped.find("#")
		if comment_pos > 0:
			stripped = stripped.substr(0, comment_pos).strip_edges()

		# Detect imports (preload, load)
		if "preload(" in stripped:
			var import_dep := _extract_preload(stripped, line_number)
			if import_dep:
				info.imports.append(import_dep)

		if "load(" in stripped:
			var import_dep := _extract_load(stripped, line_number)
			if import_dep:
				info.imports.append(import_dep)

		# Detect class_name references (e.g., var x: ClassName)
		var class_refs := _extract_class_references(stripped, line_number)
		for class_ref in class_refs:
			info.imports.append(class_ref)

		# Detect get_node calls
		if "get_node(" in stripped:
			var node_dep := _extract_get_node(stripped, line_number)
			if node_dep:
				info.node_references.append(node_dep)

		# Detect $ syntax
		if "$" in stripped:
			var node_deps := _extract_dollar_syntax(stripped, line_number)
			for node_dep in node_deps:
				info.node_references.append(node_dep)

		# Detect find_child, find_children
		if "find_child(" in stripped or "find_children(" in stripped:
			var node_dep := _extract_find_child(stripped, line_number)
			if node_dep:
				info.node_references.append(node_dep)

		# Detect autoload references
		var autoload_deps := _extract_autoload_references(stripped, line_number)
		for autoload_dep in autoload_deps:
			info.autoload_references.append(autoload_dep)


## Extract preload dependency
## Returns ImportDependency if found, null if no preload statement in line
func _extract_preload(line: String, line_number: int) -> ImportDependency:
	var regex := RegEx.new()
	regex.compile("preload\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	var result := regex.search(line)
	if result:
		var dep := ImportDependency.new()
		dep.import_path = result.get_string(1)
		dep.import_type = "preload"
		dep.line_number = line_number
		return dep
	return null  # No preload found in this line


## Extract load dependency
## Returns ImportDependency if found, null if no load statement in line
func _extract_load(line: String, line_number: int) -> ImportDependency:
	var regex := RegEx.new()
	regex.compile("load\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	var result := regex.search(line)
	if result:
		var dep := ImportDependency.new()
		dep.import_path = result.get_string(1)
		dep.import_type = "load"
		dep.line_number = line_number
		return dep
	return null  # No load found in this line


## Extract class name references from type annotations
func _extract_class_references(line: String, line_number: int) -> Array:
	var results: Array = []

	# Pattern: var name: ClassName or func name() -> ClassName
	var regex := RegEx.new()
	regex.compile(":\\s*([A-Z][A-Za-z0-9_]*)")
	var matches := regex.search_all(line)

	for match_result in matches:
		var class_name_val := match_result.get_string(1)
		# Skip built-in types
		if not _is_builtin_type(class_name_val):
			var dep := ImportDependency.new()
			dep.import_path = class_name_val
			dep.import_type = "class_name"
			dep.line_number = line_number
			results.append(dep)

	return results


## Extract get_node dependency
func _extract_get_node(line: String, line_number: int) -> NodeDependency:
	var regex := RegEx.new()
	regex.compile("get_node\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	var result := regex.search(line)
	if result:
		var dep := NodeDependency.new()
		dep.node_path = result.get_string(1)
		dep.reference_type = "get_node"
		dep.line_number = line_number
		return dep
	return null


## Extract $ syntax node references
func _extract_dollar_syntax(line: String, line_number: int) -> Array:
	var results: Array = []

	# Pattern: $NodePath or $"NodePath"
	var regex := RegEx.new()
	regex.compile("\\$([A-Za-z0-9_/]+|\"[^\"]+\")")
	var matches := regex.search_all(line)

	for match_result in matches:
		var node_path := match_result.get_string(1)
		# Remove quotes if present
		if node_path.begins_with("\"") and node_path.ends_with("\""):
			node_path = node_path.substr(1, node_path.length() - 2)

		var dep := NodeDependency.new()
		dep.node_path = node_path
		dep.reference_type = "$"
		dep.line_number = line_number
		results.append(dep)

	return results


## Extract find_child dependency
func _extract_find_child(line: String, line_number: int) -> NodeDependency:
	var regex := RegEx.new()
	regex.compile("find_child(?:ren)?\\s*\\(\\s*[\"']([^\"']+)[\"']")
	var result := regex.search(line)
	if result:
		var dep := NodeDependency.new()
		dep.node_path = result.get_string(1)
		dep.reference_type = "find_child"
		dep.line_number = line_number
		return dep
	return null


## Extract autoload references
func _extract_autoload_references(line: String, line_number: int) -> Array:
	var results: Array = []

	for autoload_name in _known_autoloads:
		# Check if autoload is referenced (as a word boundary)
		var regex := RegEx.new()
		regex.compile("\\b" + autoload_name + "\\b")
		if regex.search(line):
			var dep := AutoloadDependency.new()
			dep.autoload_name = autoload_name
			dep.line_number = line_number
			results.append(dep)

	return results


## Check if a type name is a built-in Godot type
func _is_builtin_type(type_name: String) -> bool:
	var builtin_types := [
		"int", "float", "bool", "String", "Vector2", "Vector3", "Vector4",
		"Color", "Rect2", "Transform2D", "Transform3D", "Plane", "Quaternion",
		"AABB", "Basis", "Projection", "Array", "Dictionary", "PackedByteArray",
		"PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array",
		"PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedColorArray",
		"Node", "Node2D", "Node3D", "Control", "Resource", "RefCounted", "Object",
		"Variant", "void", "Callable", "Signal", "RID", "NodePath", "StringName"
	]
	return type_name in builtin_types


## Resolve import path to absolute file path
func _resolve_import_path(import_path: String, current_file: String) -> String:
	# If it's a res:// path, return as-is
	if import_path.begins_with("res://"):
		return import_path

	# If it's a relative path, resolve it relative to current file
	if import_path.begins_with("./") or import_path.begins_with("../"):
		var current_dir := current_file.get_base_dir()
		return current_dir.path_join(import_path).simplify_path()

	# If it's a class_name reference, we can't resolve it without more context
	# Return as-is for now
	return import_path


## Load autoloads from project.godot
func load_autoloads_from_project(project_path: String = "res://project.godot") -> void:
	var file := FileAccess.open(project_path, FileAccess.READ)
	if not file:
		push_warning("[DependencyAnalyzer] Failed to open project.godot")
		return

	var content := file.get_as_text()
	file.close()

	var lines := content.split("\n")
	var in_autoload_section := false

	for line in lines:
		var stripped := line.strip_edges()

		if stripped == "[autoload]":
			in_autoload_section = true
			continue

		if in_autoload_section:
			# Check if we've left the autoload section
			if stripped.begins_with("["):
				break

			# Parse autoload entry: name="*res://path/to/script.gd"
			if "=" in stripped:
				var parts := stripped.split("=", false, 1)
				if parts.size() == 2:
					var autoload_name := parts[0].strip_edges()
					if not autoload_name in _known_autoloads:
						_known_autoloads.append(autoload_name)
