extends GutTest

## Property-based tests for MigrationTracker
## **Property 26: Migration tracking accuracy**
## **Validates: Requirements 8.4**

const MigrationTracker = preload("res://tools/migration/migration_tracker.gd")

var tracker: MigrationTracker


func before_each() -> void:
	tracker = MigrationTracker.new()
	tracker.clear_all()


func after_each() -> void:
	if tracker:
		tracker.clear_all()
	tracker = null


## Property 26: Migration tracking accuracy
## For any file in the project, the Migration_Tool should correctly track
## whether it has been migrated to the new structure or remains in the old structure.
func test_property_migration_tracking_accuracy() -> void:
	# Generate random file paths
	var test_files = _generate_random_file_paths(50)
	
	# Register all files
	for file_path in test_files:
		tracker.register_file(file_path)
	
	# Randomly migrate some files
	var migrated_set = {}
	for i in range(test_files.size()):
		if randf() > 0.5:
			var old_path = test_files[i]
			var new_path = _transform_to_new_path(old_path)
			tracker.mark_migrated(old_path, new_path)
			migrated_set[old_path] = new_path
	
	# Property: For any file, is_migrated() should return true if and only if
	# the file was marked as migrated
	for file_path in test_files:
		var expected_migrated = migrated_set.has(file_path)
		var actual_migrated = tracker.is_migrated(file_path)
		
		assert_eq(
			actual_migrated,
			expected_migrated,
			"File '%s' migration status should be %s but was %s" % [
				file_path,
				expected_migrated,
				actual_migrated
			]
		)
		
		# If migrated, verify new path is correct
		if expected_migrated:
			var expected_new_path = migrated_set[file_path]
			var actual_new_path = tracker.get_new_path(file_path)
			assert_eq(
				actual_new_path,
				expected_new_path,
				"File '%s' new path should be '%s' but was '%s'" % [
					file_path,
					expected_new_path,
					actual_new_path
				]
			)


func test_property_migration_count_consistency() -> void:
	# Property: migrated_count + unmigrated_count should always equal total_files
	var test_files = _generate_random_file_paths(30)
	
	for file_path in test_files:
		tracker.register_file(file_path)
	
	# Check initial state
	assert_eq(
		tracker.get_migrated_count() + tracker.get_unmigrated_count(),
		tracker.get_total_files(),
		"Initial: migrated + unmigrated should equal total"
	)
	
	# Migrate random files and check after each migration
	for i in range(test_files.size()):
		if randf() > 0.5:
			var old_path = test_files[i]
			var new_path = _transform_to_new_path(old_path)
			tracker.mark_migrated(old_path, new_path)
			
			assert_eq(
				tracker.get_migrated_count() + tracker.get_unmigrated_count(),
				tracker.get_total_files(),
				"After migration %d: migrated + unmigrated should equal total" % i
			)


func test_property_persistence_accuracy() -> void:
	# Property: After save and load, all migration statuses should be preserved
	var test_files = _generate_random_file_paths(20)
	var expected_statuses = {}
	
	# Register and migrate files
	for file_path in test_files:
		tracker.register_file(file_path)
		if randf() > 0.5:
			var new_path = _transform_to_new_path(file_path)
			tracker.mark_migrated(file_path, new_path)
			expected_statuses[file_path] = {
				"migrated": true,
				"new_path": new_path
			}
		else:
			expected_statuses[file_path] = {
				"migrated": false,
				"new_path": ""
			}
	
	# Save status
	var save_result = tracker.save_status()
	assert_true(save_result, "Save should succeed")
	
	# Create new tracker and load
	var new_tracker = MigrationTracker.new()
	
	# Verify all statuses match
	for file_path in test_files:
		var expected = expected_statuses[file_path]
		var actual_migrated = new_tracker.is_migrated(file_path)
		var actual_new_path = new_tracker.get_new_path(file_path)
		
		assert_eq(
			actual_migrated,
			expected["migrated"],
			"After reload: File '%s' migration status should be preserved" % file_path
		)
		
		if expected["migrated"]:
			assert_eq(
				actual_new_path,
				expected["new_path"],
				"After reload: File '%s' new path should be preserved" % file_path
			)
	
	# Cleanup
	new_tracker.clear_all()


func test_property_idempotent_migration() -> void:
	# Property: Marking a file as migrated multiple times should not change the count
	var file_path = "game/core/test.gd"
	var new_path = "game/scripts/core/test.gd"
	
	tracker.register_file(file_path)
	
	var initial_count = tracker.get_migrated_count()
	
	# Mark as migrated multiple times
	for i in range(5):
		tracker.mark_migrated(file_path, new_path)
		assert_eq(
			tracker.get_migrated_count(),
			initial_count + 1,
			"Migrated count should only increase by 1 regardless of multiple marks"
		)


func test_property_rollback_accuracy() -> void:
	# Property: After marking as not migrated, the file should appear in unmigrated list
	var test_files = _generate_random_file_paths(15)
	
	# Register and migrate all files
	for file_path in test_files:
		tracker.register_file(file_path)
		var new_path = _transform_to_new_path(file_path)
		tracker.mark_migrated(file_path, new_path)
	
	assert_eq(tracker.get_migrated_count(), test_files.size(), "All files should be migrated")
	
	# Rollback random files
	var rolled_back = []
	for file_path in test_files:
		if randf() > 0.5:
			tracker.mark_not_migrated(file_path)
			rolled_back.append(file_path)
	
	# Verify rolled back files are not migrated
	for file_path in rolled_back:
		assert_false(
			tracker.is_migrated(file_path),
			"Rolled back file '%s' should not be migrated" % file_path
		)
		assert_eq(
			tracker.get_new_path(file_path),
			"",
			"Rolled back file '%s' should have empty new path" % file_path
		)
	
	# Verify count is correct
	var expected_migrated = test_files.size() - rolled_back.size()
	assert_eq(
		tracker.get_migrated_count(),
		expected_migrated,
		"Migrated count should be %d after rollback" % expected_migrated
	)


func test_property_bidirectional_path_lookup() -> void:
	# Property: If get_new_path(old) returns new, then get_old_path(new) should return old
	var test_files = _generate_random_file_paths(10)
	
	for file_path in test_files:
		tracker.register_file(file_path)
		var new_path = _transform_to_new_path(file_path)
		tracker.mark_migrated(file_path, new_path)
		
		# Forward lookup
		var looked_up_new = tracker.get_new_path(file_path)
		assert_eq(looked_up_new, new_path, "Forward lookup should work")
		
		# Reverse lookup
		var looked_up_old = tracker.get_old_path(new_path)
		assert_eq(looked_up_old, file_path, "Reverse lookup should work")


func test_property_percentage_calculation() -> void:
	# Property: percentage should equal (migrated / total) * 100
	var test_files = _generate_random_file_paths(25)
	
	for file_path in test_files:
		tracker.register_file(file_path)
	
	# Migrate a specific number of files
	var migrate_count = 10
	for i in range(migrate_count):
		var old_path = test_files[i]
		var new_path = _transform_to_new_path(old_path)
		tracker.mark_migrated(old_path, new_path)
	
	var expected_percentage = (migrate_count / float(test_files.size())) * 100.0
	var actual_percentage = tracker.get_migration_percentage()
	
	assert_almost_eq(
		actual_percentage,
		expected_percentage,
		0.01,
		"Migration percentage should be %.2f%% but was %.2f%%" % [
			expected_percentage,
			actual_percentage
		]
	)


## Helper: Generate random file paths
func _generate_random_file_paths(count: int) -> Array[String]:
	var paths: Array[String] = []
	var directories = [
		"game/core/autoload",
		"game/core/services",
		"game/core/systems",
		"game/core/components",
		"game/entities",
		"game/weapons"
	]
	
	for i in range(count):
		var dir = directories[randi() % directories.size()]
		var filename = "file_%d.gd" % i
		paths.append(dir + "/" + filename)
	
	return paths


## Helper: Transform old path to new path
func _transform_to_new_path(old_path: String) -> String:
	# Simulate the path transformation logic
	if old_path.begins_with("game/core/autoload"):
		return old_path.replace("game/core/autoload", "game/scripts/core")
	elif old_path.begins_with("game/core/services"):
		return old_path.replace("game/core/services", "game/scripts/features")
	elif old_path.begins_with("game/core/systems"):
		return old_path.replace("game/core/systems", "game/scripts/features")
	elif old_path.begins_with("game/core/components"):
		return old_path.replace("game/core/components", "game/scripts/components")
	elif old_path.begins_with("game/entities"):
		return old_path.replace("game/entities", "game/scripts/entities")
	else:
		return old_path
