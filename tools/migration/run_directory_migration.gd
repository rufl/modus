extends SceneTree

## Script to run directory reorganization migration
## This registers all file moves and updates references

const MigrationTracker = preload("res://tools/migration/migration_tracker.gd")
const ReferenceUpdater = preload("res://tools/migration/reference_updater.gd")
const ProgressReporter = preload("res://tools/migration/progress_reporter.gd")


func _init() -> void:
	print("=== Directory Reorganization Migration ===\n")
	
	var tracker = MigrationTracker.new()
	tracker.clear_all()
	
	# Register all file migrations
	register_migrations(tracker)
	
	# Update references
	update_references(tracker)
	
	# Generate report
	generate_report(tracker)
	
	quit()


func register_migrations(tracker: MigrationTracker) -> void:
	print("Registering file migrations...")
	
	# Core autoload files
	register_file_move(tracker, "res://game/core/autoload/event_bus.gd", "res://game/scripts/core/event_bus.gd")
	register_file_move(tracker, "res://game/core/autoload/game_core.gd", "res://game/scripts/core/game_core.gd")
	register_file_move(tracker, "res://game/core/autoload/game_database.gd", "res://game/scripts/core/game_database.gd")
	register_file_move(tracker, "res://game/core/autoload/event_bus_adapter.gd", "res://game/scripts/core/event_bus_adapter.gd")
	register_file_move(tracker, "res://game/core/autoload/game_core_adapter.gd", "res://game/scripts/core/game_core_adapter.gd")
	register_file_move(tracker, "res://game/core/autoload/game_database_adapter.gd", "res://game/scripts/core/game_database_adapter.gd")
	
	# Utils
	register_file_move(tracker, "res://game/core/utils/timer_utils.gd", "res://game/scripts/utils/timer_utils.gd")
	
	# Core services (moved to core)
	register_file_move(tracker, "res://game/core/services/event_service.gd", "res://game/scripts/core/event_service.gd")
	register_file_move(tracker, "res://game/core/services/log_service.gd", "res://game/scripts/core/log_service.gd")
	register_file_move(tracker, "res://game/core/services/global_state.gd", "res://game/scripts/core/global_state.gd")
	register_file_move(tracker, "res://game/core/services/system_service.gd", "res://game/scripts/core/system_service.gd")
	
	# Feature services
	register_file_move(tracker, "res://game/core/services/audio_service.gd", "res://game/scripts/features/audio/audio_service.gd")
	register_file_move(tracker, "res://game/core/services/combat_service.gd", "res://game/scripts/features/combat/combat_service.gd")
	register_file_move(tracker, "res://game/core/services/effects_service.gd", "res://game/scripts/features/effects/effects_service.gd")
	register_file_move(tracker, "res://game/core/services/decal_spawner.gd", "res://game/scripts/features/effects/decal_spawner.gd")
	register_file_move(tracker, "res://game/core/services/particle_spawner.gd", "res://game/scripts/features/effects/particle_spawner.gd")
	register_file_move(tracker, "res://game/core/services/tracer_renderer.gd", "res://game/scripts/features/effects/tracer_renderer.gd")
	register_file_move(tracker, "res://game/core/services/gore_system.gd", "res://game/scripts/features/gore/gore_system.gd")
	register_file_move(tracker, "res://game/core/services/blood_pool_setup.gd", "res://game/scripts/features/gore/blood_pool_setup.gd")
	register_file_move(tracker, "res://game/core/services/loot_service.gd", "res://game/scripts/features/loot/loot_service.gd")
	register_file_move(tracker, "res://game/core/services/match_service.gd", "res://game/scripts/features/match/match_service.gd")
	register_file_move(tracker, "res://game/core/services/network_service.gd", "res://game/scripts/features/network/network_service.gd")
	register_file_move(tracker, "res://game/core/services/chat_service.gd", "res://game/scripts/features/network/chat_service.gd")
	register_file_move(tracker, "res://game/core/services/performance_service.gd", "res://game/scripts/features/performance/performance_service.gd")
	register_file_move(tracker, "res://game/core/services/pool_service.gd", "res://game/scripts/features/performance/pool_service.gd")
	register_file_move(tracker, "res://game/core/services/player_service.gd", "res://game/scripts/features/player/player_service.gd")
	register_file_move(tracker, "res://game/core/services/player_state_manager.gd", "res://game/scripts/features/player/player_state_manager.gd")
	register_file_move(tracker, "res://game/core/services/ui_service.gd", "res://game/scripts/features/ui/ui_service.gd")
	register_file_move(tracker, "res://game/core/services/damage_indicator_service.gd", "res://game/scripts/features/ui/damage_indicator_service.gd")
	register_file_move(tracker, "res://game/core/services/gameplay_service.gd", "res://game/scripts/features/gameplay/gameplay_service.gd")
	register_file_move(tracker, "res://game/core/services/game_state_manager.gd", "res://game/scripts/features/gameplay/game_state_manager.gd")
	register_file_move(tracker, "res://game/core/services/input_service.gd", "res://game/scripts/features/gameplay/input_service.gd")
	register_file_move(tracker, "res://game/core/services/entity_service.gd", "res://game/scripts/features/gameplay/entity_service.gd")
	register_file_move(tracker, "res://game/core/services/data_service.gd", "res://game/scripts/features/data/data_service.gd")
	register_file_move(tracker, "res://game/core/services/config_service.gd", "res://game/scripts/features/data/config_service.gd")
	register_file_move(tracker, "res://game/core/services/asset_manager.gd", "res://game/scripts/features/data/asset_manager.gd")
	register_file_move(tracker, "res://game/core/services/localization_manager.gd", "res://game/scripts/features/localization/localization_manager.gd")
	register_file_move(tracker, "res://game/core/services/save_service.gd", "res://game/scripts/features/save/save_service.gd")
	
	# Components
	register_file_move(tracker, "res://game/core/components/blood_impact_handler.gd", "res://game/scripts/components/blood_impact_handler.gd")
	register_file_move(tracker, "res://game/core/components/blood_trail_component.gd", "res://game/scripts/components/blood_trail_component.gd")
	register_file_move(tracker, "res://game/core/components/game_component.gd", "res://game/scripts/components/game_component.gd")
	register_file_move(tracker, "res://game/core/components/game_component_3d.gd", "res://game/scripts/components/game_component_3d.gd")
	register_file_move(tracker, "res://game/entities/components/combat_component.gd", "res://game/scripts/components/combat_component.gd")
	register_file_move(tracker, "res://game/entities/components/health_component.gd", "res://game/scripts/components/health_component.gd")
	register_file_move(tracker, "res://game/entities/components/interactable.gd", "res://game/scripts/components/interactable.gd")
	register_file_move(tracker, "res://game/entities/components/movement_component.gd", "res://game/scripts/components/movement_component.gd")
	register_file_move(tracker, "res://game/entities/components/pain_system.gd", "res://game/scripts/components/pain_system.gd")
	register_file_move(tracker, "res://game/entities/components/perception_component.gd", "res://game/scripts/components/perception_component.gd")
	register_file_move(tracker, "res://game/entities/components/status_effect_manager.gd", "res://game/scripts/components/status_effect_manager.gd")
	
	print("Registered %d file migrations\n" % tracker.get_total_files())


func register_file_move(tracker: MigrationTracker, old_path: String, new_path: String) -> void:
	tracker.register_file(old_path)
	tracker.mark_migrated(old_path, new_path)


func update_references(tracker: MigrationTracker) -> void:
	print("Updating references in .tscn and .gd files...")
	
	var updater = ReferenceUpdater.new(tracker)
	
	# Update scene references
	print("\nUpdating scene files...")
	var scene_results = updater.update_scene_references()
	print("  Total scenes scanned: %d" % scene_results["total_scenes"])
	print("  Scenes updated: %d" % scene_results["scenes_updated"])
	print("  Total references updated: %d" % scene_results["total_references_updated"])
	
	# Update script references
	print("\nUpdating script files...")
	var script_results = updater.update_script_references()
	print("  Total scripts scanned: %d" % script_results["total_scripts"])
	print("  Scripts updated: %d" % script_results["scripts_updated"])
	print("  Total references updated: %d" % script_results["total_references_updated"])
	
	# Validate references
	print("\nValidating all references...")
	var validation = updater.validate_all_references()
	print("  Total broken references: %d" % validation["total_broken"])
	
	if validation["total_broken"] > 0:
		print("\n  WARNING: Found broken references:")
		for broken_ref in validation["broken_references"]:
			print("    %s -> %s (%s)" % [
				broken_ref["source_file"],
				broken_ref["referenced_path"],
				broken_ref["type"]
			])
	else:
		print("  All references are valid!")


func generate_report(tracker: MigrationTracker) -> void:
	print("\n=== Migration Report ===")
	
	var reporter = ProgressReporter.new(tracker)
	print(reporter.generate_summary())
	
	# Save reports
	reporter.save_report_to_file("user://directory_migration_report.txt")
	reporter.save_json_report_to_file("user://directory_migration_report.json")
	
	print("\nReports saved to:")
	print("  - user://directory_migration_report.txt")
	print("  - user://directory_migration_report.json")
