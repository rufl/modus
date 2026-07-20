class_name GodScriptDetector
extends RefCounted

## God Script Detector for Architecture Analyzer
##
## Detects "god scripts" - scripts with too many responsibilities.
## A script is classified as a god script if it has:
## - More than 300 lines of code, OR
## - More than 10 public methods
##
## Used to identify scripts that should be decomposed into smaller components.


## Classification result for a script
class GodScriptResult:
	var file_path: String = ""
	var is_god_script: bool = false
	var line_count: int = 0
	var public_method_count: int = 0
	var reasons: Array[String] = []

	func _to_string() -> String:
		if is_god_script:
			return "GodScript(%s: %d lines, %d methods - %s)" % [
				file_path, line_count, public_method_count, ", ".join(reasons)
			]
		return "NormalScript(%s: %d lines, %d methods)" % [
			file_path, line_count, public_method_count
		]


# Thresholds for god script detection
const LINE_COUNT_THRESHOLD: int = 300
const PUBLIC_METHOD_THRESHOLD: int = 10


## Analyze a single script file to determine if it's a god script
## Returns GodScriptResult on success, null on failure
## Check for null and handle errors appropriately
func analyze_script(file_path: String) -> GodScriptResult:
	if not FileAccess.file_exists(file_path):
		push_error("[GodScriptDetector] File does not exist: %s" % file_path)
		return null
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[GodScriptDetector] Failed to open file: %s (Error: %s)" % [file_path, error_string(FileAccess.get_open_error())])
		return null

	var content := file.get_as_text()
	file.close()

	var result := GodScriptResult.new()
	result.file_path = file_path

	var lines := content.split("\n")
	result.line_count = lines.size()
	result.public_method_count = _count_public_methods(lines)

	# Classify as god script if exceeds thresholds
	if result.line_count > LINE_COUNT_THRESHOLD:
		result.is_god_script = true
		result.reasons.append("exceeds %d lines" % LINE_COUNT_THRESHOLD)

	if result.public_method_count > PUBLIC_METHOD_THRESHOLD:
		result.is_god_script = true
		result.reasons.append("exceeds %d public methods" % PUBLIC_METHOD_THRESHOLD)

	return result


## Analyze multiple scripts and return classification results
func analyze_scripts(file_paths: Array) -> Array[GodScriptResult]:
	var results: Array[GodScriptResult] = []
	for path in file_paths:
		var result := analyze_script(path)
		if result:
			results.append(result)
	return results


## Get only god scripts from analysis results
func filter_god_scripts(results: Array[GodScriptResult]) -> Array[GodScriptResult]:
	var god_scripts: Array[GodScriptResult] = []
	for result in results:
		if result.is_god_script:
			god_scripts.append(result)
	return god_scripts


## Count public methods in a script
func _count_public_methods(lines: Array) -> int:
	var count := 0
	var in_multiline_comment := false

	for line in lines:
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

		# Detect function declarations
		if stripped.begins_with("func "):
			# Check if it's a public method (doesn't start with _)
			var func_name := _extract_function_name(stripped)
			if func_name and not func_name.begins_with("_"):
				count += 1
		elif stripped.begins_with("static func "):
			# Static functions are also counted
			var func_name := _extract_function_name(stripped.substr(7))  # Remove "static "
			if func_name and not func_name.begins_with("_"):
				count += 1

	return count


## Extract function name from a function declaration line
func _extract_function_name(line: String) -> String:
	# Remove "func " prefix if present
	var func_decl := line
	if func_decl.begins_with("func "):
		func_decl = func_decl.substr(5).strip_edges()

	# Extract name before opening parenthesis
	var paren_pos := func_decl.find("(")
	if paren_pos > 0:
		return func_decl.substr(0, paren_pos).strip_edges()

	return ""


## Generate a summary report of god scripts
func generate_report(results: Array[GodScriptResult]) -> String:
	var god_scripts := filter_god_scripts(results)

	var separator_line := "="
	separator_line = separator_line.repeat(50)

	var report := "God Script Detection Report\n"
	report += separator_line + "\n\n"
	report += "Total scripts analyzed: %d\n" % results.size()
	report += "God scripts found: %d\n\n" % god_scripts.size()

	if god_scripts.is_empty():
		report += "No god scripts detected! All scripts are within acceptable limits.\n"
	else:
		var dash_line := "-"
		dash_line = dash_line.repeat(50)

		report += "God Scripts:\n"
		report += dash_line + "\n"

		for god_script in god_scripts:
			report += "\n%s\n" % god_script.file_path
			report += "  Lines: %d\n" % god_script.line_count
			report += "  Public Methods: %d\n" % god_script.public_method_count
			report += "  Reasons: %s\n" % ", ".join(god_script.reasons)

	return report
