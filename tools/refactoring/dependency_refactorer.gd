class_name DependencyRefactorer
extends RefCounted

## Dependency Refactorer for Refactoring Engine
##
## Replaces direct references with interfaces and implements dependency injection.
## Reduces tight coupling between systems.
##
## Used to refactor dependencies for better modularity and testability.


## Result of dependency refactoring
class RefactoringResult:
	var source_file: String = ""
	var dependencies_found: Array = []  # Array of Dependency
	var refactored_dependencies: Array = []  # Array of RefactoredDependency
	var modified_content: String = ""
	var interface_definitions: Array = []  # Array of InterfaceDefinition
	
	func _to_string() -> String:
		return "RefactoringResult(%s, %d dependencies)" % [
			source_file, dependencies_found.size()
		]


## A detected dependency
class Dependency:
	var type: String = ""  # "direct_reference", "singleton", "autoload", "get_node"
	var target: String = ""  # The class/node being referenced
	var line_number: int = 0
	var context: String = ""
	
	func _to_string() -> String:
		return "Dependency(%s: %s at line %d)" % [type, target, line_number]


## A refactored dependency with injection
class RefactoredDependency:
	var original: Dependency
	var injection_method: String = ""  # "constructor", "property", "method"
	var interface_name: String = ""
	var replacement_code: String = ""
	
	func _to_string() -> String:
		return "RefactoredDependency(%s -> %s)" % [
			original.target, interface_name
		]


## Interface definition to be created
class InterfaceDefinition:
	var interface_name: String = ""
	var file_path: String = ""
	var methods: Array[String] = []
	var description: String = ""
	
	func _to_string() -> String:
		return "InterfaceDefinition(%s, %d methods)" % [
			interface_name, methods.size()
		]


## Analyze and refactor dependencies in a script
## Returns RefactoringResult on success, null on failure
## Always check for null before using the result
func refactor_dependencies(file_path: String) -> RefactoringResult:
	if not FileAccess.file_exists(file_path):
		push_error("[DependencyRefactorer] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[DependencyRefactorer] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var result := RefactoringResult.new()
	result.source_file = file_path
	
	# Detect dependencies
	result.dependencies_found = _detect_dependencies(content)
	
	# Generate refactoring plan
	for dependency in result.dependencies_found:
		if dependency is Dependency:
			var refactored := _refactor_dependency(dependency)
			if refactored:
				result.refactored_dependencies.append(refactored)
	
	# Generate interface definitions
	result.interface_definitions = _generate_interfaces(result.refactored_dependencies)
	
	# Apply refactoring to content
	result.modified_content = _apply_refactoring(content, result.refactored_dependencies)
	
	return result


## Apply refactoring to a file (write modified content)
func apply_refactoring(result: RefactoringResult) -> bool:
	if not result or result.modified_content.is_empty():
		return false
	
	var file := FileAccess.open(result.source_file, FileAccess.WRITE)
	if not file:
		push_error("[DependencyRefactorer] Failed to write file: %s" % result.source_file)
		return false
	
	file.store_string(result.modified_content)
	file.close()
	
	return true


## Generate interface files from definitions
func generate_interface_files(interfaces: Array, output_dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(output_dir):
		var err := DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("[DependencyRefactorer] Failed to create output directory: %s" % output_dir)
			return false
	
	for interface_def in interfaces:
		if interface_def is InterfaceDefinition:
			var interface_path := output_dir.path_join(interface_def.file_path)
			var interface_code := _generate_interface_code(interface_def)
			
			var file := FileAccess.open(interface_path, FileAccess.WRITE)
			if not file:
				push_error("[DependencyRefactorer] Failed to create interface file: %s" % interface_path)
				return false
			
			file.store_string(interface_code)
			file.close()
	
	return true


## Detect dependencies in script content
func _detect_dependencies(content: String) -> Array:
	var dependencies: Array = []
	var lines := content.split("\n")
	var line_number := 0
	
	for line in lines:
		line_number += 1
		var stripped := line.strip_edges()
		
		# Skip comments and empty lines
		if stripped.begins_with("#") or stripped.is_empty():
			continue
		
		# Detect direct class references (preload, load, new)
		var direct_refs := _detect_direct_references(stripped, line_number)
		dependencies.append_array(direct_refs)
		
		# Detect singleton/autoload access
		var singletons := _detect_singleton_access(stripped, line_number)
		dependencies.append_array(singletons)
		
		# Detect get_node calls
		var node_refs := _detect_get_node_calls(stripped, line_number)
		dependencies.append_array(node_refs)
	
	return dependencies


## Detect direct class references
func _detect_direct_references(line: String, line_number: int) -> Array:
	var dependencies: Array = []
	
	# Pattern: preload("path/to/script.gd")
	var preload_regex := RegEx.new()
	preload_regex.compile("preload\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	var preload_matches := preload_regex.search_all(line)
	
	for match_result in preload_matches:
		var path := match_result.get_string(1)
		var dep := Dependency.new()
		dep.type = "direct_reference"
		dep.target = path.get_file().get_basename()
		dep.line_number = line_number
		dep.context = line
		dependencies.append(dep)
	
	# Pattern: ClassName.new()
	var new_regex := RegEx.new()
	new_regex.compile("([A-Z][a-zA-Z0-9_]*)\\.new\\s*\\(")
	var new_matches := new_regex.search_all(line)
	
	for match_result in new_matches:
		var target_class_name := match_result.get_string(1)
		var dep := Dependency.new()
		dep.type = "direct_reference"
		dep.target = target_class_name
		dep.line_number = line_number
		dep.context = line
		dependencies.append(dep)
	
	return dependencies


## Detect singleton/autoload access
func _detect_singleton_access(line: String, line_number: int) -> Array:
	var dependencies: Array = []
	
	# Common autoload patterns
	var autoload_names := [
		"GameCore", "EventBus", "GameDatabase", "GameManager",
		"AudioManager", "NetworkManager", "InputManager"
	]
	
	for autoload_name in autoload_names:
		if autoload_name in line:
			var dep := Dependency.new()
			dep.type = "autoload"
			dep.target = autoload_name
			dep.line_number = line_number
			dep.context = line
			dependencies.append(dep)
			break  # Only one autoload per line typically
	
	return dependencies


## Detect get_node calls
func _detect_get_node_calls(line: String, line_number: int) -> Array:
	var dependencies: Array = []
	
	var get_node_regex := RegEx.new()
	get_node_regex.compile("get_node\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	var matches := get_node_regex.search_all(line)
	
	for match_result in matches:
		var node_path := match_result.get_string(1)
		var dep := Dependency.new()
		dep.type = "get_node"
		dep.target = node_path
		dep.line_number = line_number
		dep.context = line
		dependencies.append(dep)
	
	return dependencies


## Refactor a single dependency
func _refactor_dependency(dependency: Dependency) -> RefactoredDependency:
	var refactored := RefactoredDependency.new()
	refactored.original = dependency
	
	match dependency.type:
		"direct_reference":
			refactored.injection_method = "constructor"
			refactored.interface_name = "I" + dependency.target
			refactored.replacement_code = _generate_constructor_injection(dependency)
		
		"autoload":
			refactored.injection_method = "property"
			refactored.interface_name = "I" + dependency.target
			refactored.replacement_code = _generate_property_injection(dependency)
		
		"get_node":
			refactored.injection_method = "property"
			refactored.interface_name = "INode"
			refactored.replacement_code = _generate_node_injection(dependency)
	
	return refactored


## Generate constructor injection code
func _generate_constructor_injection(dependency: Dependency) -> String:
	var interface_name := "I" + dependency.target
	var var_name: String = dependency.target.to_snake_case()
	
	var code := ""
	code += "# Injected dependency\n"
	code += "var " + var_name + ": " + interface_name + "\n\n"
	code += "func _init(injected_" + var_name + ": " + interface_name + ") -> void:\n"
	code += "\t" + var_name + " = injected_" + var_name + "\n"
	
	return code


## Generate property injection code
func _generate_property_injection(dependency: Dependency) -> String:
	var interface_name := "I" + dependency.target
	var var_name: String = dependency.target.to_snake_case()
	
	var code := ""
	code += "# Injected dependency\n"
	code += "var " + var_name + ": " + interface_name + "\n\n"
	code += "func set_" + var_name + "(value: " + interface_name + ") -> void:\n"
	code += "\t" + var_name + " = value\n"
	
	return code


## Generate node injection code
func _generate_node_injection(dependency: Dependency) -> String:
	var code := ""
	code += "# Injected node reference\n"
	code += "@export var " + dependency.target.to_snake_case() + "_path: NodePath\n"
	code += "var " + dependency.target.to_snake_case() + ": Node\n\n"
	code += "func _ready() -> void:\n"
	code += "\tif " + dependency.target.to_snake_case() + "_path:\n"
	code += "\t\t" + dependency.target.to_snake_case() + " = get_node(" + dependency.target.to_snake_case() + "_path)\n"
	
	return code


## Generate interface definitions from refactored dependencies
func _generate_interfaces(refactored_deps: Array) -> Array:
	var interfaces: Dictionary = {}  # interface_name -> InterfaceDefinition
	
	for refactored in refactored_deps:
		if refactored is RefactoredDependency:
			var interface_name: String = refactored.interface_name
			
			if not interfaces.has(interface_name):
				var interface_def := InterfaceDefinition.new()
				interface_def.interface_name = interface_name
				interface_def.file_path = interface_name.to_snake_case() + ".gd"
				interface_def.description = "Interface for " + refactored.original.target
				interface_def.methods = _infer_interface_methods(refactored.original)
				interfaces[interface_name] = interface_def
	
	return interfaces.values()


## Infer interface methods from dependency usage
func _infer_interface_methods(dependency: Dependency) -> Array[String]:
	var methods: Array[String] = []
	
	# Extract method calls from context
	var regex := RegEx.new()
	regex.compile("\\.([a-z_][a-z0-9_]*)\\s*\\(")
	var matches := regex.search_all(dependency.context)
	
	for match_result in matches:
		var method_name := match_result.get_string(1)
		if not methods.has(method_name):
			methods.append(method_name)
	
	# If no methods found, add a generic method
	if methods.is_empty():
		methods.append("execute")
	
	return methods


## Apply refactoring to content
func _apply_refactoring(content: String, refactored_deps: Array) -> String:
	var lines := content.split("\n")
	
	# Replace direct references with injected dependencies
	for refactored in refactored_deps:
		if refactored is RefactoredDependency:
			var dep: Dependency = refactored.original
			var line_idx := dep.line_number - 1
			
			if line_idx >= 0 and line_idx < lines.size():
				var original_line: String = lines[line_idx]
				var modified_line := _replace_dependency_in_line(
					original_line,
					dep,
					refactored
				)
				lines[line_idx] = modified_line
	
	return "\n".join(lines)


## Replace dependency in a single line
func _replace_dependency_in_line(line: String, dep: Dependency, refactored: RefactoredDependency) -> String:
	var var_name := dep.target.to_snake_case()
	
	match dep.type:
		"direct_reference":
			# Replace ClassName.new() with injected variable
			var pattern := dep.target + ".new()"
			if pattern in line:
				return line.replace(pattern, var_name)
		
		"autoload":
			# Replace Autoload.method() with injected.method()
			return line.replace(dep.target + ".", var_name + ".")
		
		"get_node":
			# Replace get_node("path") with injected variable
			var pattern := "get_node(\"" + dep.target + "\")"
			if pattern in line:
				return line.replace(pattern, var_name)
	
	return line


## Generate interface code
func _generate_interface_code(interface_def: InterfaceDefinition) -> String:
	var code := "class_name " + interface_def.interface_name + "\n"
	code += "extends RefCounted\n\n"
	code += "## " + interface_def.description + "\n"
	code += "## This is an interface - implement this in concrete classes\n\n"
	
	for method_name in interface_def.methods:
		code += "func " + method_name + "() -> void:\n"
		code += "\tassert(false, \"" + interface_def.interface_name + "." + method_name + "() must be implemented\")\n\n"
	
	return code


## Generate a report of refactoring results
func generate_report(results: Array) -> String:
	var total_dependencies := 0
	var total_refactored := 0
	var total_interfaces := 0
	
	for result in results:
		if result is RefactoringResult:
			total_dependencies += result.dependencies_found.size()
			total_refactored += result.refactored_dependencies.size()
			total_interfaces += result.interface_definitions.size()
	
	var report := "Dependency Refactoring Report\n"
	report += "=" .repeat(50) + "\n\n"
	report += "Dependencies found: %d\n" % total_dependencies
	report += "Dependencies refactored: %d\n" % total_refactored
	report += "Interfaces to create: %d\n\n" % total_interfaces
	
	if total_dependencies == 0:
		report += "No dependencies found to refactor.\n"
	else:
		report += "Refactoring by File:\n"
		report += "-" .repeat(50) + "\n"
		
		for result in results:
			if result is RefactoringResult and result.dependencies_found.size() > 0:
				report += "\n%s\n" % result.source_file
				report += "  Dependencies: %d\n" % result.dependencies_found.size()
				report += "  Refactored: %d\n" % result.refactored_dependencies.size()
				
				# Group by type
				var type_counts := {}
				for dep in result.dependencies_found:
					if dep is Dependency:
						var type_name: String = dep.type
						type_counts[type_name] = type_counts.get(type_name, 0) + 1
				
				for dep_type in type_counts.keys():
					report += "    %s: %d\n" % [dep_type, type_counts[dep_type]]
	
	return report


## Batch refactor multiple files
func refactor_multiple_files(file_paths: Array) -> Array:
	var results: Array = []
	
	for file_path in file_paths:
		var result := refactor_dependencies(file_path)
		if result:
			results.append(result)
	
	return results
