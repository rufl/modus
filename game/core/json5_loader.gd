class_name JSON5Loader
extends RefCounted

const JSONHelperClass = preload("res://game/core/json_helper.gd")


static func load_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[JSON5] Failed to open: %s - %s" % [path, FileAccess.get_open_error()])
		return null

	var content := file.get_as_text()
	file.close()
	return parse_string(content)


## Parse a JSON5 string into a Variant (Dictionary, Array, etc.)


static func parse_string(text: String) -> Variant:
	# Strip comments first
	text = _strip_comments(text)
	# Fix trailing commas
	text = _fix_trailing_commas(text)
	# Parse through JSON's non-emitting parser so callers can report errors
	# through their own contract without also generating an engine error.
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		push_error("[JSON5] Parse error - check for syntax errors")
		return null
	return parser.data


## Remove single-line and block comments


static func _strip_comments(text: String) -> String:
	var result := ""
	var i := 0
	var in_string := false
	var string_char := ""

	while i < text.length():
		var c := text[i]
		var next := text[i + 1] if i + 1 < text.length() else ""

		# Track string state (to avoid stripping // inside strings)
		if not in_string and (c == '"' or c == "'"):
			in_string = true
			string_char = c
			result += c
			i += 1
			continue
		elif in_string and c == string_char and (i == 0 or text[i - 1] != "\\"):
			in_string = false
			result += c
			i += 1
			continue

		# If inside string, copy as-is
		if in_string:
			result += c
			i += 1
			continue

		# Check for single-line comment
		if c == "/" and next == "/":
			# Skip until newline
			while i < text.length() and text[i] != "\n":
				i += 1
			continue

		# Check for block comment
		if c == "/" and next == "*":
			i += 2
			# Skip until */
			while i + 1 < text.length():
				if text[i] == "*" and text[i + 1] == "/":
					i += 2
					break
				i += 1
			continue

		result += c
		i += 1

	return result


## Remove trailing commas before ] or }


static func _fix_trailing_commas(text: String) -> String:
	var regex := RegEx.new()
	var err := regex.compile(",\\s*([\\]\\}])")
	if err != OK:
		push_error("[JSON5] Failed to compile trailing comma regex")
		return text
	return regex.sub(text, "$1", true)


## Check if a file exists and is readable as JSON5


static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Save a Dictionary/Array to a JSON5 file with optional header comment


static func save_file(path: String, data: Variant, header_comment: String = "") -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[JSON5] Failed to write: %s" % path)
		return false

	if header_comment != "":
		file.store_line("// " + header_comment)
		file.store_line("")

	var json_string := JSONHelperClass.safe_stringify(data, "  ")
	file.store_string(json_string)
	file.close()
	return true
