extends Node

## Example usage of the migration tools
## This script demonstrates a complete migration workflow

const MigrationTracker = preload("res://tools/migration/migration_tracker.gd")
const ProgressReporter = preload("res://tools/migration/progress_reporter.gd")
const ReferenceUpdater = preload("res://tools/migration/reference_updater.gd")
const MigrationCleanup = preload("res://tools/migration/cleanup.gd")


func _ready() -> void:
	print("=== Migration Tools Example ===\n")
	
	# Example 1: Basic tracking
	example_basic_tracking()
	
	# Example 2: Progress reporting
	example_progress_reporting()
	
	# Example 3: Reference updating
	example_reference_updating()
	
	# Example 4: Cleanup
	example_cleanup()


func example_basic_tracking() -> void:
	print("\n--- Example 1: Basic Tracking ---")
	
	var tracker = MigrationTracker.new()
	tracker.clear_all()  # Start fresh for example
	
	# Register files that need to be migrated
	tracker.register_file("res://game/core/autoload/game_core.gd")
	tracker.register_file("res://game/core/services/audio_service.gd")
	tracker.register_file("res://game/core/components/health.gd")
	
	print("Registered %d files for migration" % tracker.get_total_files())
	
	# Mark some files as migrated
	tracker.mark_migrated(
		"res://game/core/autoload/game_core.gd",
		"res://game/scripts/core/game_core.gd"
	)
	
	print("Migrated: %d/%d files (%.2f%%)" % [
		tracker.get_migrated_count(),
		tracker.get_total_files(),
		tracker.get_migration_percentage()
	])
	
	# Check individual file status
	if tracker.is_migrated("res://game/core/autoload/game_core.gd"):
		var new_path = tracker.get_new_path("res://game/core/autoload/game_core.gd")
		print("game_core.gd migrated to: %s" % new_path)
	
	tracker.clear_all()  # Cleanup


func example_progress_reporting() -> void:
	print("\n--- Example 2: Progress Reporting ---")
	
	var tracker = MigrationTracker.new()
	tracker.clear_all()
	
	# Simulate a migration in progress
	for i in range(10):
		var file_path = "res://game/test/file_%d.gd" % i
		tracker.register_file(file_path)
		if i < 6:  # Migrate 60% of files
			tracker.mark_migrated(file_path, "res://game/scripts/test/file_%d.gd" % i)
	
	var reporter = ProgressReporter.new(tracker)
	
	# Print compact summary
	print(reporter.generate_summary())
	
	# Generate JSON report for automation
	var json_report = reporter.generate_json_report()
	print("\nJSON Report:")
	print("  Total: %d" % json_report["summary"]["total_files"])
	print("  Migrated: %d" % json_report["summary"]["migrated_files"])
	print("  Remaining: %d" % json_report["summary"]["remaining_files"])
	print("  Progress: %.2f%%" % json_report["summary"]["percentage"])
	
	# You can also save reports to files:
	# reporter.save_report_to_file("user://migration_report.txt")
	# reporter.save_json_report_to_file("user://migration_report.json")
	# reporter.save_markdown_report_to_file("docs/migration_progress.md")
	
	tracker.clear_all()


func example_reference_updating() -> void:
	print("\n--- Example 3: Reference Updating ---")
	
	var tracker = MigrationTracker.new()
	tracker.clear_all()
	
	# Register migrations
	tracker.register_file("res://game/core/autoload/game_core.gd")
	tracker.mark_migrated(
		"res://game/core/autoload/game_core.gd",
		"res://game/scripts/core/game_core.gd"
	)
	
	var updater = ReferenceUpdater.new(tracker)
	
	# In a real scenario, you would update all references:
	# var results = updater.update_all_references()
	# print("Updated %d references in %d files" % [
	#     results["total_updates"],
	#     results["scenes"]["scenes_updated"] + results["scripts"]["scripts_updated"]
	# ])
	
	# Validate all references
	# var validation = updater.validate_all_references()
	# if validation["total_broken"] > 0:
	#     print("WARNING: Found %d broken references!" % validation["total_broken"])
	#     for broken_ref in validation["broken_references"]:
	#         print("  %s -> %s (%s)" % [
	#             broken_ref["source_file"],
	#             broken_ref["referenced_path"],
	#             broken_ref["type"]
	#         ])
	# else:
	#     print("All references are valid!")
	
	print("Reference updater ready (commented out for safety)")
	
	tracker.clear_all()


func example_cleanup() -> void:
	print("\n--- Example 4: Cleanup ---")
	
	var tracker = MigrationTracker.new()
	tracker.clear_all()
	
	# Simulate complete migration
	tracker.register_file("res://game/core/autoload/game_core.gd")
	tracker.register_file("res://game/core/services/audio_service.gd")
	tracker.mark_migrated(
		"res://game/core/autoload/game_core.gd",
		"res://game/scripts/core/game_core.gd"
	)
	tracker.mark_migrated(
		"res://game/core/services/audio_service.gd",
		"res://game/scripts/features/audio_service.gd"
	)
	
	var cleanup = MigrationCleanup.new(tracker)
	
	# Verify migration is complete
	var verification = cleanup.verify_migration_complete()
	print("Migration complete: %s" % ("Yes" if verification["is_complete"] else "No"))
	print("Progress: %.2f%%" % verification["percentage"])
	print("Unmigrated files: %d" % verification["unmigrated_count"])
	
	if verification["is_complete"]:
		print("\nReady for cleanup!")
		
		# In a real scenario, you would:
		# 1. Create backup
		# var backup_result = cleanup.create_backup()
		# print("Backed up %d files" % backup_result["backed_up_files"])
		
		# 2. Perform cleanup
		# var results = cleanup.cleanup_all()
		# print("Deleted %d files and %d directories" % [
		#     results["total_files_deleted"],
		#     results["total_dirs_deleted"]
		# ])
		
		# 3. Generate report
		# print(cleanup.generate_cleanup_report())
		
		print("(Cleanup operations commented out for safety)")
	else:
		print("\nMigration not complete yet. Remaining files:")
		for file_path in verification["unmigrated_files"]:
			print("  - %s" % file_path)
	
	tracker.clear_all()


## Example: Scan and register all files in a directory
func example_scan_directory() -> void:
	print("\n--- Example: Scan Directory ---")
	
	var tracker = MigrationTracker.new()
	tracker.clear_all()
	
	# Scan and register all .gd and .tscn files in game/core
	var registered_count = tracker.scan_and_register("res://game/core", ["*.gd", "*.tscn"])
	print("Registered %d files from game/core/" % registered_count)
	
	tracker.clear_all()


## Example: Complete workflow
func example_complete_workflow() -> void:
	print("\n--- Example: Complete Workflow ---")
	
	# Step 1: Initialize
	var tracker = MigrationTracker.new()
	tracker.clear_all()
	var reporter = ProgressReporter.new(tracker)
	var updater = ReferenceUpdater.new(tracker)
	var cleanup = MigrationCleanup.new(tracker)
	
	# Step 2: Scan and register files
	print("Step 1: Scanning files...")
	tracker.scan_and_register("res://game/core/autoload", ["*.gd"])
	print("  Registered %d files" % tracker.get_total_files())
	
	# Step 3: Migrate files (in real scenario, you'd actually move files)
	print("\nStep 2: Migrating files...")
	var files = tracker.get_unmigrated_files()
	for file_path in files:
		# Simulate migration
		var new_path = file_path.replace("game/core/autoload", "game/scripts/core")
		tracker.mark_migrated(file_path, new_path)
	print("  Migrated %d files" % tracker.get_migrated_count())
	
	# Step 4: Update references
	print("\nStep 3: Updating references...")
	# updater.update_all_references()
	print("  (Skipped for safety)")
	
	# Step 5: Validate
	print("\nStep 4: Validating...")
	# var validation = updater.validate_all_references()
	print("  (Skipped for safety)")
	
	# Step 6: Cleanup
	print("\nStep 5: Cleanup...")
	var verification = cleanup.verify_migration_complete()
	if verification["is_complete"]:
		print("  Migration complete! Ready for cleanup.")
		# cleanup.create_backup()
		# cleanup.cleanup_all()
	else:
		print("  Migration incomplete: %.2f%%" % verification["percentage"])
	
	# Step 7: Final report
	print("\nStep 6: Final Report")
	print(reporter.generate_summary())
	
	tracker.clear_all()
