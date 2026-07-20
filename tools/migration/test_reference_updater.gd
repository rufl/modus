extends GutTest

## Property-based tests for ReferenceUpdater
## **Property 10: Reference update completeness**
## **Validates: Requirements 3.5**

const MigrationTracker = preload("res://tools/migration/migration_tracker.gd")
const ReferenceUpdater = preload("res://tools/migration/reference_updater.gd")

var tracker: MigrationTracker
var updater: ReferenceUpdater
var temp_dir: String = "user://test_reference_updater/"


func before_each() -> void:
	tracker = MigrationTracker.new()
	tracker.clear_all()
	updater = ReferenceUpdater.new(tracker)
	
	# Create temp directory for test files
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("test_reference_updater"):
		dir.make_dir("test_reference_updater")


func after_each() -> void:
	# Cleanup temp files
	_cleanup_temp_dir()
	
	if tracker:
		tracker.clear_all()
	tracker = null
	updater = null


## Property 10: Reference update completeness
## For any file that is moved during refactoring, all references to that file
## in .tscn files and GDScript imports should be updated to the new path,
## with zero broken references remaining.
func test_property_reference_update_completeness() -> void:
	# Create test migration mappings
	var migrations = [
		["game/core/autoload/game_core.gd", "game/scripts/core/game_core.gd"],
		["game/core/services/audio_service.gd", "game/scripts/features/audio_service.gd"],
		["game/core/components/health.gd", "game/scripts/components/health.gd"]
	]
	
	# Register migrations
	for migration in migrations:
		tracker.register_file("res://" + migration[0])
		tracker.mark_migrated("res://" + migration[0], "res://" + migration[1])
	
	# Create test script with references
	var test_script_content = """extends Node

const GameCore = preload("res://game/scripts/core/game_core.gd")
const AudioService = preload("res://game/scripts/features/audio/audio_service.gd")
var health_component = load("res://game/core/components/health.gd")

func test() -> void:
	var resource = ResourceLoader.load("res://game/scripts/core/game_core.gd")
"""
	
	var test_script_path = temp_dir + "test_script.gd"
	_write_file(test_script_path, test_script_content)
	
	# Property: After updating, all old paths should be replaced with new paths
	var update_count = updater._update_references_in_script(test_script_path)
	
	# Verify updates were made
	assert_gt(update_count, 0, "Should have updated at least one reference")
	
	# Read updated content
	var updated_content = _read_file(test_script_path)
	
	# Verify old paths are gone
	for migration in migrations:
		var old_path = "res://" + migration[0]
		assert_false(
			updated_content.contains(old_path),
			"Old path '%s' should not exist in updated script" % old_path
		)
	
	# Verify new paths are present
	for migration in migrations:
		var new_path = "res://" + migration[1]
		assert_true(
			updated_content.contains(new_path),
			"New path '%s' should exist in updated script" % new_path
		)


func test_property_no_false_positives() -> void:
	# Property: Files that haven't been migrated should not be modified
	var unmigrated_path = "res://game/core/utils/helper.gd"
	
	# Don't register this file as migrated
	tracker.register_file(unmigrated_path)
	
	var test_script_content = """extends Node

const Helper = preload("res://game/core/utils/helper.gd")
"""
	
	var test_script_path = temp_dir + "test_no_change.gd"
	_write_file(test_script_path, test_script_content)
	
	var original_content = test_script_content
	var update_count = updater._update_references_in_script(test_script_path)
	var updated_content = _read_file(test_script_path)
	
	# Property: Content should remain unchanged
	assert_eq(update_count, 0, "Should not update unmigrated files")
	assert_eq(updated_content, original_content, "Content should be unchanged")


func test_property_idempotent_updates() -> void:
	# Property: Running update multiple times should produce the same result
	tracker.register_file("res://game/core/test.gd")
	tracker.mark_migrated("res://game/core/test.gd", "res://game/scripts/core/test.gd")
	
	var test_script_content = """extends Node
const Test = preload("res://game/core/test.gd")
"""
	
	var test_script_path = temp_dir + "test_idempotent.gd"
	_write_file(test_script_path, test_script_content)
	
	# First update
	var first_update_count = updater._update_references_in_script(test_script_path)
	var first_content = _read_file(test_script_path)
	
	# Second update (should do nothing)
	var second_update_count = updater._update_references_in_script(test_script_path)
	var second_content = _read_file(test_script_path)
	
	# Property: Second update should make no changes
	assert_eq(second_update_count, 0, "Second update should find nothing to update")
	assert_eq(second_content, first_content, "Content should be identical after second update")


func test_property_all_reference_types_updated() -> void:
	# Property: All types of references (preload, load, ResourceLoader.load) should be updated
	tracker.register_file("res://game/core/resource.gd")
	tracker.mark_migrated("res://game/core/resource.gd", "res://game/scripts/core/resource.gd")
	
	var test_script_content = """extends Node

const Resource1 = preload("res://game/core/resource.gd")
var resource2 = load("res://game/core/resource.gd")
var resource3 = ResourceLoader.load("res://game/core/resource.gd")
"""
	
	var test_script_path = temp_dir + "test_all_types.gd"
	_write_file(test_script_path, test_script_content)
	
	var update_count = updater._update_references_in_script(test_script_path)
	var updated_content = _read_file(test_script_path)
	
	# Property: All three reference types should be updated
	assert_eq(update_count, 3, "Should update all three reference types")
	assert_false(updated_content.contains("res://game/core/resource.gd"), "Old path should be gone")
	assert_true(updated_content.contains("res://game/scripts/core/resource.gd"), "New path should exist")
	
	# Verify each type was updated
	assert_true(updated_content.contains('preload("res://game/scripts/core/resource.gd")'), "preload should be updated")
	assert_true(updated_content.contains('load("res://game/scripts/core/resource.gd")'), "load should be updated")
	assert_true(updated_content.contains('ResourceLoader.load("res://game/scripts/core/resource.gd")'), "ResourceLoader.load should be updated")


func test_property_validation_detects_broken_references() -> void:
	# Property: Validation should detect all broken references
	
	# Create a script with a reference to a non-existent file
	var test_script_content = """extends Node

const Missing = preload("res://game/nonexistent/missing.gd")
"""
	
	var test_script_path = temp_dir + "test_broken.gd"
	_write_file(test_script_path, test_script_content)
	
	# Run validation
	updater._validate_references_in_script(test_script_path)
	var broken_refs = updater.get_broken_references()
	
	# Property: Should detect the broken reference
	assert_gt(broken_refs.size(), 0, "Should detect at least one broken reference")
	
	var found_broken = false
	for broken_ref in broken_refs:
		if broken_ref["referenced_path"] == "res://game/nonexistent/missing.gd":
			found_broken = true
			assert_eq(broken_ref["source_file"], test_script_path, "Should identify correct source file")
			assert_eq(broken_ref["type"], "preload", "Should identify correct reference type")
	
	assert_true(found_broken, "Should find the specific broken reference")


func test_property_multiple_references_same_file() -> void:
	# Property: If a file is referenced multiple times, all references should be updated
	tracker.register_file("res://game/core/common.gd")
	tracker.mark_migrated("res://game/core/common.gd", "res://game/scripts/core/common.gd")
	
	var test_script_content = """extends Node

const Common1 = preload("res://game/core/common.gd")
const Common2 = preload("res://game/core/common.gd")
var common3 = load("res://game/core/common.gd")
"""
	
	var test_script_path = temp_dir + "test_multiple.gd"
	_write_file(test_script_path, test_script_content)
	
	var update_count = updater._update_references_in_script(test_script_path)
	var updated_content = _read_file(test_script_path)
	
	# Property: All references should be updated
	assert_eq(update_count, 3, "Should update all three references")
	
	# Count occurrences of old and new paths
	var old_count = _count_occurrences(updated_content, "res://game/core/common.gd")
	var new_count = _count_occurrences(updated_content, "res://game/scripts/core/common.gd")
	
	assert_eq(old_count, 0, "Old path should not appear")
	assert_eq(new_count, 3, "New path should appear three times")


func test_property_preserves_non_path_content() -> void:
	# Property: Updating references should not modify other content
	tracker.register_file("res://game/core/test.gd")
	tracker.mark_migrated("res://game/core/test.gd", "res://game/scripts/core/test.gd")
	
	var test_script_content = """extends Node

# This is a comment about res://game/core/test.gd
const Test = preload("res://game/core/test.gd")
var description = "This loads res://game/core/test.gd"

func test() -> void:
	print("Testing res://game/core/test.gd")
"""
	
	var test_script_path = temp_dir + "test_preserve.gd"
	_write_file(test_script_path, test_script_content)
	
	updater._update_references_in_script(test_script_path)
	var updated_content = _read_file(test_script_path)
	
	# Property: Only the preload statement should be updated
	# Comments and strings should remain unchanged
	assert_true(updated_content.contains('# This is a comment about res://game/core/test.gd'), "Comment should be preserved")
	assert_true(updated_content.contains('var description = "This loads res://game/core/test.gd"'), "String should be preserved")
	assert_true(updated_content.contains('print("Testing res://game/core/test.gd")'), "Print string should be preserved")
	assert_true(updated_content.contains('preload("res://game/scripts/core/test.gd")'), "Preload should be updated")


## Helper: Write content to file
func _write_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()


## Helper: Read content from file
func _read_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	return ""


## Helper: Count occurrences of substring in string
func _count_occurrences(text: String, substring: String) -> int:
	var count = 0
	var pos = 0
	while true:
		pos = text.find(substring, pos)
		if pos == -1:
			break
		count += 1
		pos += substring.length()
	return count


## Helper: Cleanup temp directory
func _cleanup_temp_dir() -> void:
	var dir = DirAccess.open(temp_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
