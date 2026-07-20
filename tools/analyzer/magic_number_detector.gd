class_name MagicNumberDetector
extends RefCounted

## Magic Number Detector for Architecture Analyzer
##
## Detects hardcoded numeric and string literals that should be externalized to configuration.
## Excludes common values: 0, 1, -1, true, false, null, empty string
##
## Used to identify values that should be moved to JSON5 configuration files.


## Magic number detection result for a script
class MagicNumberResult:
	var file_path: String = ""
	var magic_numbers: Array = []  # Array of MagicNumber
	
	func _to_string() -> String:
		return "MagicNumberResult(%s, %d magic numbers)" % [
			file_path, magic_numbers.size()
		]


## Individual magic number/literal
class MagicNumber:
	var value: Variant = null
	var value_type: String = ""  # "numeric", "string"
	var line_number: int = 0
	var context: String = ""  # The line where it was found
	
	func _to_string() -> String:
		return "MagicNumber(%s: %s at line %d)" % [value_type, str(value), line_number]


# Common values to exclude from detection
const EXCLUDED_NUMERIC_VALUES: Array = [0, 1, -1, 0.0, 1.0, -1.0]
const EXCLUDED_STRING_VALUES: Array = ["", " ", "\n", "\t"]
const EXCLUDED_KEYWORDS: Array = ["true", "false", "null"]


## Analyze a single script file for magic numbers
## Returns MagicNumberResult on success, null on failure
## Check for null and use push_error for critical failures
func analyze_script(file_path: String) -> MagicNumberResult:
	if not FileAccess.file_exists(file_path):
		push_error("[MagicNumberDetector] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[MagicNumberDetector] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null
	
	var content := file.get_as_text()
	file.close()
	
	var result := MagicNumberResult.new()
	result.file_path = file_path
	
	var lines := content.split("\n")
	_analyze_lines(lines, result)
	
	return result


## Analyze multiple scripts and return detection results
func analyze_scripts(file_paths: Array) -> Array:
	var results: Array = []
	for path in file_paths:
		var magic_result := analyze_script(path)
		if magic_result:
			results.append(magic_result)
	return results


## Analyze lines of a script to extract magic numbers
func _analyze_lines(lines: Array, result: MagicNumberResult) -> void:
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
		var line_without_comment := stripped
		if comment_pos > 0:
			line_without_comment = stripped.substr(0, comment_pos).strip_edges()
		
		# Skip empty lines
		if line_without_comment.is_empty():
			continue
		
		# Detect numeric literals
		var numeric_literals := _extract_numeric_literals(line_without_comment)
		for literal in numeric_literals:
			if not _is_excluded_numeric(literal):
				var magic := MagicNumber.new()
				magic.value = literal
				magic.value_type = "numeric"
				magic.line_number = line_number
				magic.context = line.strip_edges()
				result.magic_numbers.append(magic)
		
		# Detect string literals
		var string_literals := _extract_string_literals(line_without_comment)
		for literal in string_literals:
			if not _is_excluded_string(literal):
				var magic := MagicNumber.new()
				magic.value = literal
				magic.value_type = "string"
				magic.line_number = line_number
				magic.context = line.strip_edges()
				result.magic_numbers.append(magic)


## Extract numeric literals from a line
func _extract_numeric_literals(line: String) -> Array:
	var literals: Array[Variant] = []
	
	# Regex pattern for numeric literals (integers and floats)
	# Matches: 123, -456, 3.14, -2.5, 1e10, 0x1A (hex), 0b1010 (binary)
	# Note: Don't use \b at start for negative numbers (- is not a word char)
	var regex := RegEx.new()
	regex.compile("(?<![\\w.])-?\\d+\\.?\\d*(?:[eE][+-]?\\d+)?\\b|\\b(?:0x[0-9a-fA-F]+|0b[01]+)\\b")
	
	var matches: Array[RegExMatch] = []
	matches.assign(regex.search_all(line))
	for match_result: RegExMatch in matches:
		var literal_str := match_result.get_string(0)
		var literal_value: Variant = _parse_numeric_literal(literal_str)
		if literal_value != null:
			literals.append(literal_value)
	
	return literals


## Extract string literals from a line
func _extract_string_literals(line: String) -> Array:
	var literals: Array[String] = []
	
	# Regex pattern for string literals (double and single quotes)
	var regex := RegEx.new()
	regex.compile("[\"']([^\"']*)[\"']")
	
	var matches: Array[RegExMatch] = []
	matches.assign(regex.search_all(line))
	for match_result: RegExMatch in matches:
		var literal := match_result.get_string(1)
		literals.append(literal)
	
	return literals


## Parse numeric literal string to appropriate type
func _parse_numeric_literal(literal_str: String) -> Variant:
	# Handle hexadecimal
	if literal_str.begins_with("0x"):
		return literal_str.hex_to_int()
	
	# Handle binary
	if literal_str.begins_with("0b"):
		return literal_str.bin_to_int()
	
	# Handle float (contains . or e/E)
	if "." in literal_str or "e" in literal_str.to_lower():
		return literal_str.to_float()
	
	# Handle integer
	return literal_str.to_int()


## Check if a numeric value should be excluded
func _is_excluded_numeric(value: Variant) -> bool:
	# Check against excluded values
	for excluded in EXCLUDED_NUMERIC_VALUES:
		if value == excluded:
			return true
	
	return false


## Check if a string value should be excluded
func _is_excluded_string(value: String) -> bool:
	# Check against excluded values
	if value in EXCLUDED_STRING_VALUES:
		return true
	
	# Exclude very short strings (likely not configuration)
	if value.length() <= 1:
		return true
	
	return false


## Generate a summary report of magic numbers
func generate_report(results: Array) -> String:
	var total_magic_numbers := 0
	var files_with_magic_numbers := 0
	
	for result in results:
		if result is MagicNumberResult:
			if result.magic_numbers.size() > 0:
				files_with_magic_numbers += 1
				total_magic_numbers += result.magic_numbers.size()
	
	var separator_line := "="
	separator_line = separator_line.repeat(50)
	
	var report := "Magic Number Detection Report\n"
	report += separator_line + "\n\n"
	report += "Total scripts analyzed: %d\n" % results.size()
	report += "Scripts with magic numbers: %d\n" % files_with_magic_numbers
	report += "Total magic numbers found: %d\n\n" % total_magic_numbers
	
	if total_magic_numbers == 0:
		report += "No magic numbers detected! All values are properly configured.\n"
	else:
		var dash_line := "-"
		dash_line = dash_line.repeat(50)
		
		report += "Magic Numbers by File:\n"
		report += dash_line + "\n"
		
		for result in results:
			if result is MagicNumberResult and result.magic_numbers.size() > 0:
				report += "\n%s (%d magic numbers)\n" % [result.file_path, result.magic_numbers.size()]
				
				# Group by type
				var numeric_count := 0
				var string_count := 0
				
				for magic in result.magic_numbers:
					if magic is MagicNumber:
						if magic.value_type == "numeric":
							numeric_count += 1
						elif magic.value_type == "string":
							string_count += 1
				
				report += "  Numeric literals: %d\n" % numeric_count
				report += "  String literals: %d\n" % string_count
				
				# Show first few examples
				var examples_shown := 0
				var max_examples := 5
				
				for magic in result.magic_numbers:
					if magic is MagicNumber and examples_shown < max_examples:
						report += "    Line %d: %s = %s\n" % [
							magic.line_number,
							magic.value_type,
							str(magic.value)
						]
						examples_shown += 1
				
				if result.magic_numbers.size() > max_examples:
					report += "    ... and %d more\n" % (result.magic_numbers.size() - max_examples)
	
	return report


## Get all magic numbers from results
func get_all_magic_numbers(results: Array) -> Array:
	var all_magic: Array = []
	for result in results:
		if result is MagicNumberResult:
			all_magic.append_array(result.magic_numbers)
	return all_magic


## Filter results to only include files with magic numbers
func filter_files_with_magic_numbers(results: Array) -> Array:
	var filtered: Array = []
	for result in results:
		if result is MagicNumberResult and result.magic_numbers.size() > 0:
			filtered.append(result)
	return filtered
