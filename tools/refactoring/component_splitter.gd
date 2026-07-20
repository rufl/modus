class_name ComponentSplitter
extends RefCounted

## Component Splitter for Refactoring Engine
##
## Analyzes god scripts and splits them into smaller, single-responsibility components.
## Uses responsibility clustering to group related methods and variables.
##
## Used to decompose large scripts into maintainable components.


## Result of component splitting analysis
class SplitResult:
	var source_file: String = ""
	var components: Array = []  # Array of ComponentDefinition
	var composition_code: String = ""  # Code showing how to compose components
	
	func _to_string() -> String:
		return "SplitResult(%s, %d components)" % [source_file, components.size()]


## Definition of a component to be created
class ComponentDefinition:
	var component_name: String = ""
	var file_path: String = ""
	var responsibility: String = ""  # Description of what this component does
	var methods: Array[String] = []  # Method names
	var variables: Array[String] = []  # Variable names
	var signals: Array[String] = []  # Signal names
	var dependencies: Array[String] = []  # Other components this depends on
	
	func _to_string() -> String:
		return "ComponentDefinition(%s: %d methods, %d vars)" % [
			component_name, methods.size(), variables.size()
		]


## Analyze a god script and generate component split recommendations
## Returns SplitResult on success, null on failure
## Always check for null before using the result
func analyze_and_split(file_path: String) -> SplitResult:
	if not FileAccess.file_exists(file_path):
		push_error("[ComponentSplitter] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[ComponentSplitter] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var result := SplitResult.new()
	result.source_file = file_path
	
	# Parse the script to extract structure
	var script_structure := _parse_script_structure(content)
	
	# Cluster responsibilities
	var clusters := _cluster_responsibilities(script_structure)
	
	# Generate component definitions
	result.components = _generate_component_definitions(clusters, file_path)
	
	# Generate composition code
	result.composition_code = _generate_composition_code(result.components, file_path)
	
	return result


## Generate actual component files from split result
func generate_component_files(split_result: SplitResult, output_dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(output_dir):
		var err := DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("[ComponentSplitter] Failed to create output directory: %s" % output_dir)
			return false
	
	for component_def in split_result.components:
		if component_def is ComponentDefinition:
			var component_path := output_dir.path_join(component_def.file_path)
			var component_code := _generate_component_code(component_def)
			
			var file := FileAccess.open(component_path, FileAccess.WRITE)
			if not file:
				push_error("[ComponentSplitter] Failed to create component file: %s" % component_path)
				return false
			
			file.store_string(component_code)
			file.close()
	
	return true


## Parse script structure to extract methods, variables, signals
func _parse_script_structure(content: String) -> Dictionary:
	var structure := {
		"class_name": "",
		"extends": "",
		"methods": [],  # Array of {name, lines, calls, accesses}
		"variables": [],  # Array of {name, type, exported}
		"signals": [],  # Array of {name, params}
		"constants": []  # Array of {name, value}
	}
	
	var lines := content.split("\n")
	var current_method := ""
	var method_lines: Array[String] = []
	var in_method := false
	var indent_level := 0
	
	for line in lines:
		var stripped := line.strip_edges()
		
		# Skip comments and empty lines
		if stripped.begins_with("#") or stripped.is_empty():
			continue
		
		# Extract class_name
		if stripped.begins_with("class_name "):
			structure["class_name"] = stripped.substr(11).strip_edges()
			continue
		
		# Extract extends
		if stripped.begins_with("extends "):
			structure["extends"] = stripped.substr(8).strip_edges()
			continue
		
		# Extract signals
		if stripped.begins_with("signal "):
			var signal_def := stripped.substr(7).strip_edges()
			var signal_name := signal_def.split("(")[0].strip_edges()
			structure["signals"].append({"name": signal_name, "definition": signal_def})
			continue
		
		# Extract constants
		if stripped.begins_with("const "):
			var const_parts := stripped.substr(6).split("=")
			if const_parts.size() >= 2:
				var const_name_parts := const_parts[0].strip_edges().split(":")
				var const_name: String = const_name_parts[0].strip_edges()
				structure["constants"].append({"name": const_name, "line": stripped})
			continue
		
		# Extract variables (var, @export var, @onready var)
		if stripped.begins_with("var ") or stripped.begins_with("@export var ") or stripped.begins_with("@onready var "):
			var is_exported := stripped.begins_with("@export")
			var var_start := stripped.find("var ") + 4
			var var_def := stripped.substr(var_start).strip_edges()
			var var_name_parts: PackedStringArray = var_def.split(":")
			var var_name_with_equals: String = var_name_parts[0] if var_name_parts.size() > 0 else var_def
			var var_name_final_parts: PackedStringArray = var_name_with_equals.split("=")
			var var_name: String = var_name_final_parts[0].strip_edges() if var_name_final_parts.size() > 0 else var_name_with_equals.strip_edges()
			structure["variables"].append({
				"name": var_name,
				"exported": is_exported,
				"line": stripped
			})
			continue
		
		# Detect method start
		if stripped.begins_with("func "):
			if in_method and not method_lines.is_empty():
				# Save previous method
				_save_method(structure, current_method, method_lines)
			
			in_method = true
			current_method = _extract_method_name(stripped)
			method_lines = [stripped]
			indent_level = _count_leading_tabs(line)
			continue
		
		# Collect method lines
		if in_method:
			method_lines.append(line)
			
			# Check if method ended (next line at same or lower indent level with content)
			var line_indent := _count_leading_tabs(line)
			if line_indent <= indent_level and not stripped.is_empty():
				if not stripped.begins_with("\t") and not stripped.begins_with(" "):
					# Method ended
					_save_method(structure, current_method, method_lines)
					in_method = false
					method_lines = []
	
	# Save last method if any
	if in_method and not method_lines.is_empty():
		_save_method(structure, current_method, method_lines)
	
	return structure


## Save method information to structure
func _save_method(structure: Dictionary, method_name: String, method_lines: Array) -> void:
	var method_info: Dictionary = {
		"name": method_name,
		"lines": method_lines.size(),
		"calls": _extract_method_calls(method_lines),
		"accesses": _extract_variable_accesses(method_lines)
	}
	structure["methods"].append(method_info)


## Extract method name from func declaration
func _extract_method_name(func_line: String) -> String:
	var name_start := func_line.find("func ") + 5
	var name_end := func_line.find("(", name_start)
	if name_end == -1:
		name_end = func_line.length()
	return func_line.substr(name_start, name_end - name_start).strip_edges()


## Extract method calls from method lines
func _extract_method_calls(method_lines: Array) -> Array[String]:
	var calls: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")
	
	for line in method_lines:
		if line is String:
			var matches := regex.search_all(line)
			for match_result in matches:
				var call_name := match_result.get_string(1)
				if not calls.has(call_name):
					calls.append(call_name)
	
	return calls


## Extract variable accesses from method lines
func _extract_variable_accesses(method_lines: Array) -> Array[String]:
	var accesses: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\\b(_?[a-z][a-z0-9_]*)\\b")
	
	for line in method_lines:
		if line is String:
			var matches := regex.search_all(line)
			for match_result in matches:
				var var_name := match_result.get_string(1)
				# Filter out keywords and common names
				if not _is_keyword(var_name) and not accesses.has(var_name):
					accesses.append(var_name)
	
	return accesses


## Check if a word is a GDScript keyword
func _is_keyword(word: String) -> bool:
	const KEYWORDS := [
		"if", "else", "elif", "for", "while", "match", "break", "continue",
		"return", "pass", "var", "const", "func", "class", "extends", "is",
		"as", "self", "super", "true", "false", "null", "and", "or", "not",
		"in", "await", "signal", "enum", "static", "void"
	]
	return word in KEYWORDS


## Count leading tabs/spaces in a line
func _count_leading_tabs(line: String) -> int:
	var count := 0
	for c in line:
		if c == '\t':
			count += 1
		elif c == ' ':
			count += 1
		else:
			break
	return count


## Cluster responsibilities based on method and variable relationships
func _cluster_responsibilities(structure: Dictionary) -> Array:
	var clusters: Array = []
	var methods: Array = structure["methods"]
	var variables: Array = structure["variables"]
	
	if methods.is_empty():
		return clusters
	
	# Simple clustering: group methods by shared variable access
	var method_groups := {}  # variable_name -> Array of method indices
	
	for i in range(methods.size()):
		var method = methods[i]
		var accesses: Array = method.get("accesses", [])
		
		for var_name in accesses:
			if not method_groups.has(var_name):
				method_groups[var_name] = []
			method_groups[var_name].append(i)
	
	# Create clusters from groups
	var assigned_methods := {}  # method_index -> cluster_index
	var cluster_index := 0
	
	for var_name in method_groups.keys():
		var method_indices: Array = method_groups[var_name]
		
		if method_indices.size() > 1:
			# Multiple methods access this variable - they belong together
			var cluster := {
				"id": cluster_index,
				"key_variable": var_name,
				"methods": [],
				"variables": [var_name]
			}
			
			for method_idx in method_indices:
				if not assigned_methods.has(method_idx):
					cluster["methods"].append(methods[method_idx])
					assigned_methods[method_idx] = cluster_index
			
			if not cluster["methods"].is_empty():
				clusters.append(cluster)
				cluster_index += 1
	
	# Assign remaining methods to individual clusters
	for i in range(methods.size()):
		if not assigned_methods.has(i):
			var method = methods[i]
			var cluster := {
				"id": cluster_index,
				"key_variable": "",
				"methods": [method],
				"variables": method.get("accesses", [])
			}
			clusters.append(cluster)
			cluster_index += 1
	
	return clusters


## Generate component definitions from clusters
func _generate_component_definitions(clusters: Array, source_file: String) -> Array:
	var components: Array = []
	var base_name := source_file.get_file().get_basename()
	
	for i in range(clusters.size()):
		var cluster: Dictionary = clusters[i]
		var component := ComponentDefinition.new()
		
		# Generate component name
		if cluster["key_variable"]:
			var var_name: String = cluster["key_variable"]
			component.component_name = _to_pascal_case(var_name) + "Component"
		else:
			var methods: Array = cluster["methods"]
			if not methods.is_empty():
				var first_method: Dictionary = methods[0]
				var method_name: String = first_method.get("name", "")
				component.component_name = _to_pascal_case(method_name) + "Component"
			else:
				component.component_name = base_name + "Component" + str(i + 1)
		
		# Set file path
		component.file_path = component.component_name.to_snake_case() + ".gd"
		
		# Extract methods
		for method in cluster["methods"]:
			if method is Dictionary:
				component.methods.append(method.get("name", ""))
		
		# Extract variables
		for var_name in cluster["variables"]:
			if var_name is String:
				component.variables.append(var_name)
		
		# Generate responsibility description
		component.responsibility = _generate_responsibility_description(component)
		
		components.append(component)
	
	return components


## Generate responsibility description for a component
func _generate_responsibility_description(component: ComponentDefinition) -> String:
	if component.methods.size() == 1:
		return "Handles " + component.methods[0]
	elif component.methods.size() > 1:
		return "Manages " + component.component_name.replace("Component", "").to_snake_case() + " functionality"
	else:
		return "Component functionality"


## Convert snake_case to PascalCase
func _to_pascal_case(snake_str: String) -> String:
	var parts := snake_str.split("_")
	var result := ""
	for part in parts:
		if not part.is_empty():
			result += part.capitalize()
	return result


## Generate composition code showing how to use components together
func _generate_composition_code(components: Array, source_file: String) -> String:
	var base_name := source_file.get_file().get_basename()
	var code := "# Composition example for " + base_name + "\n\n"
	code += "extends Node\n\n"
	
	# Add component variables
	for component in components:
		if component is ComponentDefinition:
			code += "var " + component.component_name.to_snake_case() + ": " + component.component_name + "\n"
	
	code += "\n\nfunc _ready() -> void:\n"
	
	# Initialize components
	for component in components:
		if component is ComponentDefinition:
			var var_name: String = component.component_name.to_snake_case()
			code += "\t" + var_name + " = " + component.component_name + ".new()\n"
			code += "\tadd_child(" + var_name + ")\n"
	
	return code


## Generate actual GDScript code for a component
func _generate_component_code(component_def: ComponentDefinition) -> String:
	var code := "class_name " + component_def.component_name + "\n"
	code += "extends GameComponent\n\n"
	code += "## " + component_def.responsibility + "\n\n"
	
	# Add signals
	for signal_name in component_def.signals:
		code += "signal " + signal_name + "\n"
	
	if not component_def.signals.is_empty():
		code += "\n"
	
	# Add variables
	for var_name in component_def.variables:
		code += "var " + var_name + "\n"
	
	if not component_def.variables.is_empty():
		code += "\n"
	
	# Add method stubs
	for method_name in component_def.methods:
		code += "\nfunc " + method_name + "() -> void:\n"
		code += "\t# TODO(refactoring): Implement " + method_name + "\n"
		code += "\t# This is a stub generated by ComponentSplitter\n"
		code += "\t# Copy implementation from original script\n"
		code += "\tpass\n"
	
	return code


## Generate a report of the split analysis
func generate_split_report(split_result: SplitResult) -> String:
	var report := "Component Split Analysis\n"
	report += "=" .repeat(50) + "\n\n"
	report += "Source file: " + split_result.source_file + "\n"
	report += "Components to create: " + str(split_result.components.size()) + "\n\n"
	
	report += "Component Breakdown:\n"
	report += "-" .repeat(50) + "\n"
	
	for component in split_result.components:
		if component is ComponentDefinition:
			report += "\n" + component.component_name + "\n"
			report += "  File: " + component.file_path + "\n"
			report += "  Responsibility: " + component.responsibility + "\n"
			report += "  Methods: " + str(component.methods.size()) + "\n"
			report += "  Variables: " + str(component.variables.size()) + "\n"
			
			if not component.methods.is_empty():
				report += "  Method list: " + ", ".join(component.methods) + "\n"
	
	report += "\n\nComposition Code:\n"
	report += "-" .repeat(50) + "\n"
	report += split_result.composition_code + "\n"
	
	return report
