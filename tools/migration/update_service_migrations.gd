@tool
extends SceneTree

## Script to update migration tracker for service to feature module migrations
## Run this script to mark services as migrated to feature modules

func _init() -> void:
	var tracker := MigrationTracker.new()
	
	# Mark AudioService as migrated to AudioFeature
	tracker.mark_migrated(
		"game/scripts/features/audio/audio_service.gd",
		"game/scripts/features/audio/audio_feature.gd"
	)
	print("✓ Marked AudioService as migrated to AudioFeature")
	
	# Mark NetworkService as migrated to NetworkFeature
	tracker.mark_migrated(
		"game/scripts/features/network/network_service.gd",
		"game/scripts/features/network/network_feature.gd"
	)
	print("✓ Marked NetworkService as migrated to NetworkFeature")
	
	# Mark EffectsService as migrated to EffectsFeature
	tracker.mark_migrated(
		"game/scripts/features/effects/effects_service.gd",
		"game/scripts/features/effects/effects_feature.gd"
	)
	print("✓ Marked EffectsService as migrated to EffectsFeature")
	
	# Mark UIService as migrated to UIFeature
	tracker.mark_migrated(
		"game/scripts/features/ui/ui_service.gd",
		"game/scripts/features/ui/ui_feature.gd"
	)
	print("✓ Marked UIService as migrated to UIFeature")
	
	# Mark PerformanceService as migrated to PerformanceFeature
	tracker.mark_migrated(
		"game/scripts/features/performance/performance_service.gd",
		"game/scripts/features/performance/performance_feature.gd"
	)
	print("✓ Marked PerformanceService as migrated to PerformanceFeature")
	
	# Generate migration report
	print("\n=== Migration Report ===")
	print("Total files tracked: %d" % tracker.get_total_files())
	print("Migrated files: %d" % tracker.get_migrated_count())
	print("Unmigrated files: %d" % tracker.get_unmigrated_count())
	print("Migration progress: %.1f%%" % tracker.get_migration_percentage())
	
	print("\nMigrated services:")
	var migrated := tracker.get_migrated_files()
	for file in migrated:
		var new_path := tracker.get_new_path(file)
		print("  %s -> %s" % [file, new_path])
	
	quit()
