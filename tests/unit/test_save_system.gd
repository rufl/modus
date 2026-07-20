extends ModusGutTestBase

## Unit tests for MODUS Save System
## Tests save file creation, loading, validation, and corruption handling
##
## Requirements: 9 (Save System Testing)

var save_system: Node
var test_save_path: String = "user://test_save.dat"


func before_each() -> void:
	super.before_each()
	
	# Get save system from GameManager
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		save_system = gm.get_core_system("save")
	
	# Clean up any existing test save
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	await get_tree().process_frame


func after_each() -> void:
	# Clean up test save file
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	save_system = null
	super.after_each()


# ============================================================================
# Save File Creation Tests (Requirement 9.1)
# ============================================================================

func test_save_system_exists() -> void:
	assert_not_null(
		save_system,
		"Save system should be available from GameManager"
	)


func test_save_file_creation() -> void:
	assert_not_null(save_system, "Save system should exist")
	
	# Create test save data
	var save_data: Dictionary = {
		"player_health": 100,
		"player_position": Vector3(10, 5, 20),
		"inventory": ["weapon_pistol", "item_medkit"]
	}
	
	# Save to file
	var result: bool = save_system.save_game(test_save_path, save_data)
	
	# Verify save succeeded
	assert_true(result, "Save operation should succeed")
	assert_true(
		FileAccess.file_exists(test_save_path),
		"Save file should exist on disk"
	)


# ============================================================================
# Save File Loading Tests (Requirement 9.2)
# ============================================================================

func test_save_file_loading() -> void:
	assert_not_null(save_system, "Save system should exist")
	
	# Create and save test data
	var original_data: Dictionary = {
		"player_health": 75,
		"player_ammo": 50,
		"level_name": "test_level"
	}
	save_system.save_game(test_save_path, original_data)
	
	# Load the save file
	var loaded_data: Dictionary = save_system.load_game(test_save_path)
	
	# Verify data was loaded correctly
	assert_eq(
		loaded_data["player_health"],
		75,
		"Loaded health should match saved value"
	)
	assert_eq(
		loaded_data["player_ammo"],
		50,
		"Loaded ammo should match saved value"
	)
	assert_eq(
		loaded_data["level_name"],
		"test_level",
		"Loaded level name should match saved value"
	)


# ============================================================================
# Save Data Validation Tests (Requirement 9.3)
# ============================================================================

func test_save_data_validation() -> void:
	assert_not_null(save_system, "Save system should exist")
	
	# Test valid save data
	var valid_data: Dictionary = {
		"version": "1.0",
		"player_health": 100
	}
	assert_true(
		save_system.validate_save_data(valid_data),
		"Valid save data should pass validation"
	)
	
	# Test invalid save data (missing required fields)
	var invalid_data: Dictionary = {}
	assert_false(
		save_system.validate_save_data(invalid_data),
		"Invalid save data should fail validation"
	)


# ============================================================================
# Corruption Handling Tests (Requirement 9.4)
# ============================================================================

func test_save_file_corruption_handling() -> void:
	assert_not_null(save_system, "Save system should exist")
	
	# Create corrupted save file
	var file: FileAccess = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("CORRUPTED DATA !@#$%")
	file.close()
	
	# Attempt to load corrupted file
	var loaded_data: Dictionary = save_system.load_game(test_save_path)
	
	# Verify graceful handling (returns empty dict or default data)
	assert_true(
		loaded_data.is_empty() or loaded_data.has("error"),
		"Corrupted save should be handled gracefully"
	)


# ============================================================================
# Round-Trip Property Tests (Requirement 9.5)
# ============================================================================

func test_save_load_roundtrip_property() -> void:
	assert_not_null(save_system, "Save system should exist")
	
	# Create test data
	var original_data: Dictionary = {
		"player_health": 85,
		"player_position": Vector3(15, 10, 25),
		"inventory": ["weapon_shotgun", "item_armor", "ammo_shells"],
		"stats": {
			"kills": 42,
			"deaths": 3,
			"score": 1337
		}
	}
	
	# Save
	save_system.save_game(test_save_path, original_data)
	
	# Load
	var loaded_data: Dictionary = save_system.load_game(test_save_path)
	
	# Save again
	var roundtrip_path: String = "user://test_save_roundtrip.dat"
	save_system.save_game(roundtrip_path, loaded_data)
	
	# Load again
	var final_data: Dictionary = save_system.load_game(roundtrip_path)
	
	# Verify round-trip preserves data
	assert_eq(
		final_data,
		original_data,
		"Round-trip should produce equivalent data"
	)
	
	# Cleanup
	if FileAccess.file_exists(roundtrip_path):
		DirAccess.remove_absolute(roundtrip_path)
