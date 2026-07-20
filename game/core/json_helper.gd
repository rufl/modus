class_name JSONHelper
extends RefCounted

## Helper class for JSON operations with safety features (e.g. NaN handling)


static func safe_stringify(data: Variant, indent: String = "") -> String:
	# Debug: Log the first few calls to see what's being serialized
	if OS.is_debug_build():
		var stack_trace: Array = get_stack()
		if stack_trace.size() > 1:
			var caller: Dictionary = stack_trace[1]
			print(
				(
					"[JSONHelper] Called from: %s:%d in %s()"
					% [caller.source, caller.line, caller.function]
				)
			)

	var clean_data: Variant = _sanitize_data(data)

	# Pre-stringify validation to catch any remaining NaN values
	if _deep_contains_nan(clean_data):
		push_error("[JSONHelper] CRITICAL: NaN values still present after sanitization!")
		print("[JSONHelper] Problematic data: " + " " + str(clean_data))
		print("[JSONHelper] Call stack:")
		print(str(get_stack()))
		# Force replace with a safe fallback
		clean_data = {"error": "Data contained NaN values and was sanitized"}

	# Additional safety check - if JSON.stringify still encounters NaN,
	# we'll catch it and provide more debugging info
	var result: String

	# Wrap JSON.stringify in a try-catch equivalent by checking the result
	result = JSON.stringify(clean_data, indent)

	# Check if Godot replaced NaN with null (the result will contain "null")
	if result.contains("null"):
		push_warning("[JSONHelper] JSON.stringify encountered NaN values despite sanitization!")
		push_warning("[JSONHelper] Original data type: %s" % typeof(data))
		push_warning("[JSONHelper] Sanitized data type: %s" % typeof(clean_data))

		if OS.is_debug_build():
			print("[JSONHelper] Original data: " + " " + str(data))
			print("[JSONHelper] Sanitized data: " + " " + str(clean_data))
			print("[JSONHelper] JSON result: " + " " + str(result))

			# Try to identify which part contains null
			if clean_data is Dictionary:
				for key: Variant in clean_data:
					var value_json: String = JSON.stringify(clean_data[key])
					if value_json.contains("null"):
						print("[JSONHelper] Key '%s' contains null: %s" % [key, value_json])

	# If the result contains "null" where we might have had NaN, log it
	if result.contains("null") and _contains_suspicious_nulls(data):
		push_warning(
			"[JSONHelper] Potential NaN values detected and replaced with null in JSON output"
		)
		# Optionally log the original data structure for debugging
		if OS.is_debug_build():
			print("[JSONHelper] Original data type: " + " " + str(typeof(data)))
			if data is Dictionary and data.size() < 10:  # Only log small dictionaries
				print("[JSONHelper] Data keys: " + " " + str(data.keys()))

	return result


static func _sanitize_data(data: Variant) -> Variant:
	match typeof(data):
		TYPE_DICTIONARY:
			var dict: Dictionary = {}
			for k: Variant in data:
				var clean_key: Variant = _sanitize_data(k)
				dict[clean_key] = _sanitize_data(data[k])
			return dict
		TYPE_ARRAY:
			var arr: Array = []
			arr.resize(data.size())
			for i: int in range(data.size()):
				arr[i] = _sanitize_data(data[i])
			return arr
		TYPE_FLOAT:
			return _fix_float(data)
		TYPE_PACKED_FLOAT32_ARRAY:
			var arr: Array = []
			for val: float in data:
				arr.append(_fix_float(val))
			return arr
		TYPE_PACKED_FLOAT64_ARRAY:
			var arr: Array = []
			for val: float in data:
				arr.append(_fix_float(val))
			return arr
		TYPE_PACKED_VECTOR2_ARRAY:
			var arr: Array = []
			for val: Vector2 in data:
				arr.append(_sanitize_data(val))
			return arr
		TYPE_PACKED_VECTOR3_ARRAY:
			var arr: Array = []
			for val: Vector3 in data:
				arr.append(_sanitize_data(val))
			return arr
		TYPE_PACKED_COLOR_ARRAY:
			var arr: Array = []
			for val: Color in data:
				arr.append(_sanitize_data(val))
			return arr
		TYPE_PACKED_VECTOR4_ARRAY:
			var arr: Array = []
			for val: Vector4 in data:
				arr.append(_sanitize_data(val))
			return arr
		TYPE_VECTOR2:
			return Vector2(_fix_float(data.x), _fix_float(data.y))
		TYPE_VECTOR3:
			return Vector3(_fix_float(data.x), _fix_float(data.y), _fix_float(data.z))
		TYPE_VECTOR4:
			return Vector4(
				_fix_float(data.x), _fix_float(data.y), _fix_float(data.z), _fix_float(data.w)
			)
		TYPE_QUATERNION:
			return Quaternion(
				_fix_float(data.x), _fix_float(data.y), _fix_float(data.z), _fix_float(data.w)
			)
		TYPE_COLOR:
			return Color(
				_fix_float(data.r), _fix_float(data.g), _fix_float(data.b), _fix_float(data.a)
			)
		TYPE_RECT2:
			return Rect2(_sanitize_data(data.position), _sanitize_data(data.size))
		TYPE_AABB:
			return AABB(_sanitize_data(data.position), _sanitize_data(data.size))
		TYPE_TRANSFORM2D:
			return Transform2D(
				_sanitize_data(data.x), _sanitize_data(data.y), _sanitize_data(data.origin)
			)
		TYPE_TRANSFORM3D:
			return Transform3D(_sanitize_data(data.basis), _sanitize_data(data.origin))
		TYPE_BASIS:
			return Basis(_sanitize_data(data.x), _sanitize_data(data.y), _sanitize_data(data.z))
		TYPE_PLANE:
			return Plane(_sanitize_data(data.normal), _fix_float(data.d))
		TYPE_PROJECTION:
			return Projection(
				_sanitize_data(data.x),
				_sanitize_data(data.y),
				_sanitize_data(data.z),
				_sanitize_data(data.w)
			)
		_:
			# Handle any unrecognized types more safely
			# Check if it's a numeric type that might contain NaN
			if data is float:
				return _fix_float(data)
			if data is int:
				# Ints shouldn't be NaN, but check for overflow
				if data == 0x7FFFFFFF or data == -0x80000000:
					return 0  # Replace potential overflow values
				return data
			return data


static func _fix_float(val: float) -> float:
	if is_nan(val) or is_inf(val):
		return 0.0
	return val


static func _contains_suspicious_nulls(data: Variant) -> bool:
	# Quick heuristic to detect if we might have had NaN values
	# This is not perfect but helps with debugging
	match typeof(data):
		TYPE_DICTIONARY:
			for key: Variant in data:
				if _contains_suspicious_nulls(data[key]):
					return true
		TYPE_ARRAY:
			for item: Variant in data:
				if _contains_suspicious_nulls(item):
					return true
		TYPE_FLOAT:
			return is_nan(data) or is_inf(data)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			# Check if any component is NaN
			var components: Array = []
			if data is Vector2:
				components = [data.x, data.y]
			elif data is Vector3:
				components = [data.x, data.y, data.z]
			elif data is Vector4:
				components = [data.x, data.y, data.z, data.w]

			for comp: float in components:
				if is_nan(comp) or is_inf(comp):
					return true

	return false


static func _deep_contains_nan(data: Variant) -> bool:
	# Comprehensive NaN detection that checks all possible data types
	match typeof(data):
		TYPE_FLOAT:
			return is_nan(data) or is_inf(data)
		TYPE_DICTIONARY:
			for key: Variant in data:
				if _deep_contains_nan(key) or _deep_contains_nan(data[key]):
					return true
		TYPE_ARRAY:
			for item: Variant in data:
				if _deep_contains_nan(item):
					return true
		TYPE_VECTOR2:
			return is_nan(data.x) or is_nan(data.y) or is_inf(data.x) or is_inf(data.y)
		TYPE_VECTOR3:
			return (
				is_nan(data.x)
				or is_nan(data.y)
				or is_nan(data.z)
				or is_inf(data.x)
				or is_inf(data.y)
				or is_inf(data.z)
			)
		TYPE_VECTOR4:
			return (
				is_nan(data.x)
				or is_nan(data.y)
				or is_nan(data.z)
				or is_nan(data.w)
				or is_inf(data.x)
				or is_inf(data.y)
				or is_inf(data.z)
				or is_inf(data.w)
			)
		TYPE_QUATERNION:
			return (
				is_nan(data.x)
				or is_nan(data.y)
				or is_nan(data.z)
				or is_nan(data.w)
				or is_inf(data.x)
				or is_inf(data.y)
				or is_inf(data.z)
				or is_inf(data.w)
			)
		TYPE_COLOR:
			return (
				is_nan(data.r)
				or is_nan(data.g)
				or is_nan(data.b)
				or is_nan(data.a)
				or is_inf(data.r)
				or is_inf(data.g)
				or is_inf(data.b)
				or is_inf(data.a)
			)
		TYPE_RECT2:
			return _deep_contains_nan(data.position) or _deep_contains_nan(data.size)
		TYPE_AABB:
			return _deep_contains_nan(data.position) or _deep_contains_nan(data.size)
		TYPE_TRANSFORM2D:
			return (
				_deep_contains_nan(data.x)
				or _deep_contains_nan(data.y)
				or _deep_contains_nan(data.origin)
			)
		TYPE_TRANSFORM3D:
			return _deep_contains_nan(data.basis) or _deep_contains_nan(data.origin)
		TYPE_BASIS:
			return (
				_deep_contains_nan(data.x)
				or _deep_contains_nan(data.y)
				or _deep_contains_nan(data.z)
			)
		TYPE_PLANE:
			return _deep_contains_nan(data.normal) or is_nan(data.d) or is_inf(data.d)
		TYPE_PROJECTION:
			return (
				_deep_contains_nan(data.x)
				or _deep_contains_nan(data.y)
				or _deep_contains_nan(data.z)
				or _deep_contains_nan(data.w)
			)
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			for val: float in data:
				if is_nan(val) or is_inf(val):
					return true

	return false
