class_name ScriptScanner
extends RefCounted

## Script Scanner for Architecture Analyzer
##
## Recursively scans directories for .gd files and extracts:
## - Class names
## - Methods (with parameters and return types)
## - Signals
## - Variables (with types and export status)
##
## Used by the Architecture Analyzer to understand the codebase structure.


## Result structure for a scanned script
class ScriptInfo:
	var file_path: String = ""
	var class_name_val: String = ""
	var extends_class: String = ""
	var methods: Array = []
	var signals_list: Array = []
	var variables: Array = []
	var line_count: int = 0
	var imports: Array = []
	
	func _to_string() -> String:
		return "ScriptInfo(%s, %d lines, %d methods)" % [file_path, line_count, methods.size()]


## Information about a method
class MethodInfo:
	var name: String = ""
	var parameters: Array = []
	var return_type: String = ""
	var is_static: bool = false
	var is_virtual: bool = false
	var line_number: int = 0
	
	func _to_string() -> String:
		return "Method(%s)" % name


## Information about a signal
class SignalInfo:
	var name: String = ""
	var parameters: Array = []
	var line_number: int = 0
	
	func _to_string() -> String:
		return "Signal(%s)" % name


## Information about a variable
class VariableInfo:
	var name: String = ""
	var var_type: String = ""
	var is_exported: bool = false
	var is_const: bool = false
	var is_static: bool = false
	var default_value: String = ""
	var line_number: int = 0
	
	func _to_string() -> String:
		return "Variable(%s: %s)" % [name, var_type]


## Scan a directory recursively for .gd files
func scan_directory(dir_path: String) -> Array:
	var results: Array = []
	_scan_recursive(dir_path, results)
	return results


## Internal recursive scanning function
func _scan_recursive(dir_path: String, results: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("[ScriptScanner] Failed to open directory: %s" % dir_path)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			# Skip hidden directories and .godot
			if not file_name.begins_with("."):
				_scan_recursive(full_path, results)
		elif file_name.ends_with(".gd"):
			var script_info := parse_script(full_path)
			if script_info:
				results.append(script_info)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Parse a single script file and extract information
## Returns ScriptInfo on success, null on failure
## Always check for null before using the result
func parse_script(file_path: String) -> ScriptInfo:
	if not FileAccess.file_exists(file_path):
		push_error("[ScriptScanner] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[ScriptScanner] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var info := ScriptInfo.new()
	info.file_path = file_path
	
	var lines := content.split("\n")
	info.line_count = lines.size()
	
	_parse_lines(lines, info)
	
	return info


## Parse lines of a script to extract information
func _parse_lines(lines: Array, info: ScriptInfo) -> void:
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
		
		# Extract class_name
		if stripped.begins_with("class_name "):
			info.class_name_val = _extract_class_name(stripped)
		
		# Extract extends
		elif stripped.begins_with("extends "):
			info.extends_class = _extract_extends(stripped)
		
		# Extract signals
		elif stripped.begins_with("signal "):
			var signal_info := _extract_signal(stripped, line_number)
			if signal_info:
				info.signals_list.append(signal_info)
		
		# Extract methods
		elif stripped.begins_with("func ") or stripped.begins_with("static func "):
			var method_info := _extract_method(stripped, line_number)
			if method_info:
				info.methods.append(method_info)
		
		# Extract variables (var, const, @export)
		elif stripped.begins_with("var ") or stripped.begins_with("const ") or \
			 stripped.begins_with("@export ") or stripped.begins_with("static var "):
			var var_info := _extract_variable(stripped, line_number)
			if var_info:
				info.variables.append(var_info)
		
		# Extract imports (preload, load)
		elif "preload(" in stripped or "load(" in stripped:
			var import_path := _extract_import(stripped)
			if import_path and not import_path in info.imports:
				info.imports.append(import_path)


## Extract class name from class_name declaration
func _extract_class_name(line: String) -> String:
	var parts := line.split(" ", false)
	if parts.size() >= 2:
		return parts[1].strip_edges()
	return ""


## Extract extends class name
func _extract_extends(line: String) -> String:
	var parts := line.split(" ", false)
	if parts.size() >= 2:
		return parts[1].strip_edges()
	return ""


## Extract signal information
func _extract_signal(line: String, line_number: int) -> SignalInfo:
	var signal_info := SignalInfo.new()
	signal_info.line_number = line_number
	
	# Remove "signal " prefix
	var signal_decl := line.substr(7).strip_edges()
	
	# Check for parameters
	var paren_pos := signal_decl.find("(")
	if paren_pos > 0:
		signal_info.name = signal_decl.substr(0, paren_pos).strip_edges()
		var params_str := _extract_between_parens(signal_decl)
		if params_str:
			signal_info.parameters = _parse_parameters(params_str)
	else:
		signal_info.name = signal_decl.strip_edges()
	
	return signal_info


## Extract method information
func _extract_method(line: String, line_number: int) -> MethodInfo:
	var method_info := MethodInfo.new()
	method_info.line_number = line_number
	
	# Check for static
	if line.begins_with("static "):
		method_info.is_static = true
		line = line.substr(7).strip_edges()
	
	# Remove "func " prefix
	var func_decl := line.substr(5).strip_edges()
	
	# Check for virtual methods (starting with _)
	if func_decl.begins_with("_"):
		method_info.is_virtual = true
	
	# Extract method name
	var paren_pos := func_decl.find("(")
	if paren_pos > 0:
		method_info.name = func_decl.substr(0, paren_pos).strip_edges()
		
		# Extract parameters
		var params_str := _extract_between_parens(func_decl)
		if params_str:
			method_info.parameters = _parse_parameters(params_str)
		
		# Extract return type
		var arrow_pos := func_decl.find("->")
		if arrow_pos > 0:
			var return_part := func_decl.substr(arrow_pos + 2).strip_edges()
			var colon_pos := return_part.find(":")
			if colon_pos > 0:
				method_info.return_type = return_part.substr(0, colon_pos).strip_edges()
			else:
				method_info.return_type = return_part.strip_edges()
	
	return method_info


## Extract variable information
func _extract_variable(line: String, line_number: int) -> VariableInfo:
	var var_info := VariableInfo.new()
	var_info.line_number = line_number
	
	var working_line := line
	
	# Check for @export
	if working_line.begins_with("@export"):
		var_info.is_exported = true
		# Remove @export and any parameters
		var space_pos := working_line.find(" ", 7)
		if space_pos > 0:
			working_line = working_line.substr(space_pos + 1).strip_edges()
	
	# Check for static
	if working_line.begins_with("static "):
		var_info.is_static = true
		working_line = working_line.substr(7).strip_edges()
	
	# Check for const
	if working_line.begins_with("const "):
		var_info.is_const = true
		working_line = working_line.substr(6).strip_edges()
	elif working_line.begins_with("var "):
		working_line = working_line.substr(4).strip_edges()
	
	# Extract name, type, and default value
	var colon_pos := working_line.find(":")
	var equals_pos := working_line.find("=")
	
	if colon_pos > 0:
		# Has type annotation
		var_info.name = working_line.substr(0, colon_pos).strip_edges()
		
		if equals_pos > colon_pos:
			# Has default value
			var_info.var_type = working_line.substr(colon_pos + 1, equals_pos - colon_pos - 1).strip_edges()
			var_info.default_value = working_line.substr(equals_pos + 1).strip_edges()
		else:
			var_info.var_type = working_line.substr(colon_pos + 1).strip_edges()
	elif equals_pos > 0:
		# No type annotation, but has default value
		var_info.name = working_line.substr(0, equals_pos).strip_edges()
		var_info.default_value = working_line.substr(equals_pos + 1).strip_edges()
	else:
		# Just a name
		var_info.name = working_line.strip_edges()
	
	return var_info


## Extract import path from preload or load statement
func _extract_import(line: String) -> String:
	var regex := RegEx.new()
	regex.compile("(preload|load)\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	var result := regex.search(line)
	if result:
		return result.get_string(2)
	return ""


## Extract content between parentheses
func _extract_between_parens(text: String) -> String:
	var start := text.find("(")
	var end := text.rfind(")")
	if start >= 0 and end > start:
		return text.substr(start + 1, end - start - 1).strip_edges()
	return ""


## Parse parameter list into array of parameter strings
func _parse_parameters(params_str: String) -> Array:
	var result: Array = []
	if params_str.is_empty():
		return result
	
	var parts := params_str.split(",")
	for part in parts:
		var param := part.strip_edges()
		if not param.is_empty():
			result.append(param)
	
	return result
