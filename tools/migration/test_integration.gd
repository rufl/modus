extends GutTest

## Integration tests for the complete migration tool suite

const MigrationTracker = preload("res://tools/migration/migration_tracker.gd")
const ProgressReporter = preload("res://tools/migration/progress_reporter.gd")
const ReferenceUpdater = preload("res://tools/migration/reference_updater.gd")
const MigrationCleanup = preload("res://tools/migration/cleanup.gd")

var tracker: MigrationTracker
var reporter: ProgressReporter
var updater: ReferenceUpdater
var cleanup: MigrationCleanup


func before_each() -> void:
	tracker = MigrationTracker.new()
	tracker.clear_all()
	reporter = ProgressReporter.new(tracker)
	updater = ReferenceUpdater.new(tracker)
	cleanup = MigrationCleanup.new(tracker)


func after_each() -> void:
	if tracker:
		tracker.clear_all()
	tracker = null
	reporter = null
	updater = null
	cleanup = null


func test_complete_migration_workflow() -> void:
	# Step 1: Register files for migration
	var files_to_migrate = [
		"res://game/core/autoload/game_core.gd",
		"res://game/core/services/audio_service.gd",
		"res://game/core/components/health.gd"
	]
	
	for file_path in files_to_migrate:
		tracker.register_file(file_path)
	
	assert_eq(tracker.get_total_files(), 3, "Should have 3 files registered")
	assert_eq(tracker.get_migration_percentage(), 0.0, "Initial progress should be 0%")
	
	# Step 2: Generate initial progress report
	var initial_summary = reporter.generate_summary()
	assert_true(initial_summary.contains("0/3"), "Summary should show 0/3 files")
	
	# Step 3: Mark files as migrated
	tracker.mark_migrated(
		"res://game/core/autoload/game_core.gd",
		"res://game/scripts/core/game_core.gd"
	)
	tracker.mark_migrated(
		"res://game/core/services/audio_service.gd",
		"res://game/scripts/features/audio_service.gd"
	)
	
	assert_eq(tracker.get_migrated_count(), 2, "Should have 2 migrated files")
	assert_almost_eq(tracker.get_migration_percentage(), 66.67, 0.1, "Progress should be ~66.67%")
	
	# Step 4: Generate progress report
	var progress_summary = reporter.generate_summary()
	assert_true(progress_summary.contains("2/3"), "Summary should show 2/3 files")
	
	# Step 5: Complete migration
	tracker.mark_migrated(
		"res://game/core/components/health.gd",
		"res://game/scripts/components/health.gd"
	)
	
	assert_eq(tracker.get_migration_percentage(), 100.0, "Progress should be 100%")
	
	# Step 6: Verify migration is complete
	var verification = cleanup.verify_migration_complete()
	assert_true(verification["is_complete"], "Migration should be complete")
	assert_eq(verification["unmigrated_count"], 0, "Should have no unmigrated files")
	
	# Step 7: Generate final report
	var final_report = reporter.generate_report()
	assert_true(final_report.contains("100.00%"), "Final report should show 100%")


func test_progress_reporter_integration() -> void:
	# Register and migrate some files
	for i in range(10):
		var file_path = "res://game/test/file_%d.gd" % i
		tracker.register_file(file_path)
		if i < 5:
			tracker.mark_migrated(file_path, "res://game/scripts/test/file_%d.gd" % i)
	
	# Test summary generation
	var summary = reporter.generate_summary()
	assert_true(summary.contains("5/10"), "Summary should show 5/10 files")
	assert_true(summary.contains("50.00%"), "Summary should show 50%")
	
	# Test full report generation
	var report = reporter.generate_report()
	assert_true(report.contains("Total Files:      10"), "Report should show 10 total files")
	assert_true(report.contains("Migrated:         5"), "Report should show 5 migrated")
	assert_true(report.contains("Remaining:        5"), "Report should show 5 remaining")
	
	# Test JSON report generation
	var json_report = reporter.generate_json_report()
	assert_eq(json_report["summary"]["total_files"], 10, "JSON should have 10 total files")
	assert_eq(json_report["summary"]["migrated_files"], 5, "JSON should have 5 migrated files")
	assert_eq(json_report["summary"]["percentage"], 50.0, "JSON should show 50%")


func test_cleanup_verification() -> void:
	# Test with incomplete migration
	tracker.register_file("res://game/core/test1.gd")
	tracker.register_file("res://game/core/test2.gd")
	tracker.mark_migrated("res://game/core/test1.gd", "res://game/scripts/test1.gd")
	
	var verification = cleanup.verify_migration_complete()
	assert_false(verification["is_complete"], "Migration should not be complete")
	assert_eq(verification["unmigrated_count"], 1, "Should have 1 unmigrated file")
	
	# Complete migration
	tracker.mark_migrated("res://game/core/test2.gd", "res://game/scripts/test2.gd")
	
	verification = cleanup.verify_migration_complete()
	assert_true(verification["is_complete"], "Migration should be complete")
	assert_eq(verification["unmigrated_count"], 0, "Should have no unmigrated files")


func test_bidirectional_path_lookup() -> void:
	# Register and migrate files
	var migrations = {
		"res://game/core/old1.gd": "res://game/scripts/new1.gd",
		"res://game/core/old2.gd": "res://game/scripts/new2.gd",
		"res://game/core/old3.gd": "res://game/scripts/new3.gd"
	}
	
	for old_path in migrations:
		tracker.register_file(old_path)
		tracker.mark_migrated(old_path, migrations[old_path])
	
	# Test forward lookup (old -> new)
	for old_path in migrations:
		var new_path = tracker.get_new_path(old_path)
		assert_eq(new_path, migrations[old_path], "Forward lookup should work for " + old_path)
	
	# Test reverse lookup (new -> old)
	for old_path in migrations:
		var new_path = migrations[old_path]
		var looked_up_old = tracker.get_old_path(new_path)
		assert_eq(looked_up_old, old_path, "Reverse lookup should work for " + new_path)


func test_migration_persistence() -> void:
	# Create and populate tracker
	tracker.register_file("res://game/core/test1.gd")
	tracker.register_file("res://game/core/test2.gd")
	tracker.mark_migrated("res://game/core/test1.gd", "res://game/scripts/test1.gd")
	
	var original_percentage = tracker.get_migration_percentage()
	
	# Save and create new tracker
	tracker.save_status()
	var new_tracker = MigrationTracker.new()
	
	# Verify data persisted
	assert_eq(new_tracker.get_total_files(), 2, "Total files should persist")
	assert_eq(new_tracker.get_migrated_count(), 1, "Migrated count should persist")
	assert_eq(new_tracker.get_migration_percentage(), original_percentage, "Percentage should persist")
	assert_true(new_tracker.is_migrated("res://game/core/test1.gd"), "Migration status should persist")
	assert_false(new_tracker.is_migrated("res://game/core/test2.gd"), "Non-migrated status should persist")
	
	# Cleanup
	new_tracker.clear_all()
