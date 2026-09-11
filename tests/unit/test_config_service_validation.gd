extends GutTest

const ConfigServiceScript = preload("res://game/scripts/features/data/config_service.gd")

var config_service: Node


func before_each() -> void:
	config_service = add_child_autofree(ConfigServiceScript.new())


func test_nested_schema_accepts_valid_configuration() -> void:
	var schema := {
		"type": "object",
		"required": ["enabled", "limits"],
		"properties":
		{
			"enabled": {"type": "boolean"},
			"limits": {"type": "array", "items": {"type": "integer", "min": 1, "max": 10}}
		}
	}

	assert_true(
		config_service._validate_data({"enabled": true, "limits": [1, 5, 10]}, schema, "test")
	)


func test_schema_rejects_missing_required_and_invalid_nested_values() -> void:
	var schema := {
		"type": "object", "required": ["enabled"], "properties": {"enabled": {"type": "boolean"}}
	}

	assert_false(config_service._validate_data({}, schema, "test"))
	assert_false(config_service._validate_data({"enabled": "yes"}, schema, "test"))


func test_schema_rejects_out_of_range_array_values() -> void:
	var schema := {"type": "array", "items": {"type": "integer", "min": 1, "max": 3}}

	assert_false(config_service._validate_data([0], schema, "test"))
	assert_false(config_service._validate_data([4], schema, "test"))
