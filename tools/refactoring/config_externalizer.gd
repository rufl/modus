class_name ConfigExternalizer
extends RefCounted

## Configuration Externalizer for Refactoring Engine
##
## Replaces hardcoded values with GameManager.get_config() calls
## and generates JSON5 configuration files with extracted values.
##
## Used to externalize magic numbers and constants to configuration files.

const MagicNumberDetector = preload("res://tools/analyzer/magic_number_detector.gd")


## Result of configuration externalization
class ExternalizationResult:
	var source_file: String = ""
	var replacements: Array = []  # Array of Replacement
	var config_entries: Dictionary = {}  # config_path -> value
	var modified_content: String = ""
	
	func _to_string() -> String:
		return "ExternalizationResult(%s, %d replacements)" % [
			source_file, replacements.size()
		]


## A single value replacement
class Replacement:
	var line_number: int = 0
	var original_value: Variant = null
	var config_path: String = ""
	var context: String = ""
	
	func _to_string() -> String:
		return "Replacement(line %d: %s -> %s)" % [
			line_number, str(original_value), config_path
		]


## Externalize hardcoded values in a script file
## Returns ExternalizationResult on success, null on failure
## Always check for null before using the result
func externalize_config(file_path: String, config_prefix: String = "") -> ExternalizationResult:
	if not FileAccess.file_exists(file_path):
		push_error("[ConfigExternalizer] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[ConfigExternalizer] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var result := ExternalizationResult.new()
	result.source_file = file_path
	
	# Detect magic numbers using MagicNumberDetector
	var detector := MagicNumberDetector.new()
	var magic_result := detector.analyze_script(file_path)
	
	if not magic_result:
		push_warning("[ConfigExternalizer] Magic number detection failed for: %s" % file_path)
		return result
	
	# Generate config paths and replacements
	var lines := content.split("\n")
	var modified_lines := lines.duplicate()
	
	for magic in magic_result.magic_numbers:
		if magic is MagicNumberDetector.MagicNumber:
			var config_path := _generate_config_path(file_path, magic, config_prefix)
			var replacement := Replacement.new()
			replacement.line_number = magic.line_number
			replacement.original_value = magic.value
			replacement.config_path = config_path
			replacement.context = magic.context
			
			result.replacements.append(replacement)
			result.config_entries[config_path] = magic.value
			
			# Replace in the line
			var line_idx: int = magic.line_number - 1
			if line_idx >= 0 and line_idx < modified_lines.size():
				modified_lines[line_idx] = _replace_value_in_line(
					modified_lines[line_idx],
					magic.value,
					config_path
				)
	
	result.modified_content = "\n".join(modified_lines)
	
	return result


## Apply externalization to a file (write modified content)
func apply_externalization(result: ExternalizationResult) -> bool:
	if not result or result.modified_content.is_empty():
		return false
	
	var file := FileAccess.open(result.source_file, FileAccess.WRITE)
	if not file:
		push_error("[ConfigExternalizer] Failed to write file: %s" % result.source_file)
		return false
	
	file.store_string(result.modified_content)
	file.close()
	
	return true


## Generate JSON5 configuration file from externalization results
func generate_config_file(results: Array, output_path: String) -> bool:
	var config_data := {}
	
	# Collect all config entries from all results
	for result in results:
		if result is ExternalizationResult:
			for config_path in result.config_entries.keys():
				var value = result.config_entries[config_path]
				_set_nested_value(config_data, config_path, value)
	
	# Convert to JSON5 format
	var json5_content := _dict_to_json5(config_data, 0)
	
	# Write to file
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_error("[ConfigExternalizer] Failed to create config file: %s" % output_path)
		return false
	
	file.store_string(json5_content)
	file.close()
	
	return true


## Generate a configuration path for a magic number
func _generate_config_path(file_path: String, magic: MagicNumberDetector.MagicNumber, prefix: String) -> String:
	# Extract meaningful context from the line
	var context := magic.context.strip_edges()
	var var_name := _extract_variable_name(context)
	
	# Determine category based on file path
	var category := _determine_category(file_path)
	
	# Build config path
	var path_parts: Array[String] = []
	
	if not prefix.is_empty():
		path_parts.append(prefix)
	
	if not category.is_empty():
		path_parts.append(category)
	
	if not var_name.is_empty():
		path_parts.append(var_name)
	else:
		# Generate a generic name based on value type
		if magic.value_type == "numeric":
			path_parts.append("value_" + str(magic.line_number))
		else:
			path_parts.append("text_" + str(magic.line_number))
	
	return ".".join(path_parts)


## Extract variable name from a line of code
func _extract_variable_name(line: String) -> String:
	# Try to find variable assignment pattern: var_name = value
	var regex := RegEx.new()
	regex.compile("(?:var\\s+)?([a-z_][a-z0-9_]*)\\s*[=:]")
	
	var match_result := regex.search(line)
	if match_result:
		return match_result.get_string(1)
	
	# Try to find property access: object.property = value
	regex.compile("([a-z_][a-z0-9_]*)\\s*=")
	match_result = regex.search(line)
	if match_result:
		return match_result.get_string(1)
	
	return ""


## Determine configuration category from file path
func _determine_category(file_path: String) -> String:
	var path_lower := file_path.to_lower()
	
	if "combat" in path_lower:
		return "combat"
	elif "movement" in path_lower or "player" in path_lower:
		return "movement"
	elif "audio" in path_lower or "sound" in path_lower:
		return "audio"
	elif "graphics" in path_lower or "visual" in path_lower:
		return "graphics"
	elif "network" in path_lower:
		return "network"
	elif "ui" in path_lower or "interface" in path_lower:
		return "ui"
	elif "inventory" in path_lower:
		return "inventory"
	elif "loot" in path_lower:
		return "loot"
	else:
		return "gameplay"


## Replace a value in a line with a config lookup
func _replace_value_in_line(line: String, value: Variant, config_path: String) -> String:
	var value_str := _value_to_string(value)
	var replacement := "GameManager.get_config(\"%s\", %s)" % [config_path, value_str]
	
	# Find and replace the value
	# For strings, we need to match with quotes
	if value is String:
		var patterns := [
			"\"" + value + "\"",
			"'" + value + "'"
		]
		for pattern in patterns:
			if pattern in line:
				return line.replace(pattern, replacement)
	else:
		# For numbers, use word boundaries
		var regex := RegEx.new()
		regex.compile("\\b" + value_str + "\\b")
		return regex.sub(line, replacement, true)
	
	return line


## Convert value to string representation
func _value_to_string(value: Variant) -> String:
	if value is String:
		return "\"" + value + "\""
	elif value is float:
		return str(value)
	elif value is int:
		return str(value)
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)


## Set a nested value in a dictionary using dot notation
func _set_nested_value(dict: Dictionary, path: String, value: Variant) -> void:
	var parts := path.split(".")
	var current := dict
	
	for i in range(parts.size() - 1):
		var part := parts[i]
		if not current.has(part):
			current[part] = {}
		current = current[part]
	
	var last_part := parts[parts.size() - 1]
	current[last_part] = value


## Convert dictionary to JSON5 format with comments
func _dict_to_json5(dict: Dictionary, indent_level: int) -> String:
	var indent := "\t".repeat(indent_level)
	var next_indent := "\t".repeat(indent_level + 1)
	var json5 := "{\n"
	
	var keys := dict.keys()
	for i in range(keys.size()):
		var key = keys[i]
		var value = dict[key]
		
		json5 += next_indent + key + ": "
		
		if value is Dictionary:
			json5 += _dict_to_json5(value, indent_level + 1)
		elif value is Array:
			json5 += _array_to_json5(value, indent_level + 1)
		elif value is String:
			json5 += "\"" + value + "\""
		elif value is float:
			json5 += str(value)
		elif value is int:
			json5 += str(value)
		elif value is bool:
			json5 += "true" if value else "false"
		else:
			json5 += str(value)
		
		if i < keys.size() - 1:
			json5 += ","
		json5 += "\n"
	
	json5 += indent + "}"
	return json5


## Convert array to JSON5 format
func _array_to_json5(arr: Array, indent_level: int) -> String:
	var json5 := "["
	
	for i in range(arr.size()):
		var value = arr[i]
		
		if value is Dictionary:
			json5 += _dict_to_json5(value, indent_level)
		elif value is Array:
			json5 += _array_to_json5(value, indent_level)
		elif value is String:
			json5 += "\"" + value + "\""
		else:
			json5 += str(value)
		
		if i < arr.size() - 1:
			json5 += ", "
	
	json5 += "]"
	return json5


## Generate a report of externalization results
func generate_report(results: Array) -> String:
	var total_replacements := 0
	var total_files := 0
	var total_config_entries := 0
	
	for result in results:
		if result is ExternalizationResult:
			if result.replacements.size() > 0:
				total_files += 1
				total_replacements += result.replacements.size()
				total_config_entries += result.config_entries.size()
	
	var report := "Configuration Externalization Report\n"
	report += "=" .repeat(50) + "\n\n"
	report += "Files processed: %d\n" % total_files
	report += "Total replacements: %d\n" % total_replacements
	report += "Config entries created: %d\n\n" % total_config_entries
	
	if total_replacements == 0:
		report += "No hardcoded values found to externalize.\n"
	else:
		report += "Externalization by File:\n"
		report += "-" .repeat(50) + "\n"
		
		for result in results:
			if result is ExternalizationResult and result.replacements.size() > 0:
				report += "\n%s\n" % result.source_file
				report += "  Replacements: %d\n" % result.replacements.size()
				report += "  Config entries: %d\n" % result.config_entries.size()
				
				# Show first few examples
				var examples_shown := 0
				var max_examples := 5
				
				for replacement in result.replacements:
					if replacement is Replacement and examples_shown < max_examples:
						report += "    Line %d: %s -> %s\n" % [
							replacement.line_number,
							str(replacement.original_value),
							replacement.config_path
						]
						examples_shown += 1
				
				if result.replacements.size() > max_examples:
					report += "    ... and %d more\n" % (result.replacements.size() - max_examples)
	
	return report


## Batch externalize multiple files
func externalize_multiple_files(file_paths: Array, config_prefix: String = "") -> Array:
	var results: Array = []
	
	for file_path in file_paths:
		var result := externalize_config(file_path, config_prefix)
		if result:
			results.append(result)
	
	return results
