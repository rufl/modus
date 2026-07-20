extends RefCounted
class_name DebugSystem

## DebugSystem
## Saves intermediate generation states for debugging and troubleshooting
## Includes grid state, minimap images, and context metadata

const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var debug_enabled: bool = false
var debug_output_dir: String = "res://debug/map_generator/"
var current_seed: String = ""


## Initialize debug system
func initialize(enabled: bool, seed_str: String) -> void:
	debug_enabled = enabled
	current_seed = seed_str

	if debug_enabled:
		_create_debug_directory()


## Save debug state after a phase completes
func save_phase_state(phase_name: String, context: RefCounted) -> void:
	if not debug_enabled:
		return

	var phase_dir := _get_phase_directory(phase_name)
	DirAccess.make_dir_recursive_absolute(phase_dir)

	# Save grid state
	_save_grid_state(phase_dir, context)

	# Save minimap image
	_save_minimap_image(phase_dir, context)

	# Save context metadata
	_save_context_metadata(phase_dir, phase_name, context)

	print("DebugSystem: Saved state for phase '%s' to: %s" % [phase_name, phase_dir])


## Create debug directory structure
func _create_debug_directory() -> void:
	var seed_dir := debug_output_dir + current_seed + "/"
	DirAccess.make_dir_recursive_absolute(seed_dir)
	print("DebugSystem: Debug mode enabled. Output directory: %s" % seed_dir)


## Get directory for a specific phase
func _get_phase_directory(phase_name: String) -> String:
	return debug_output_dir + current_seed + "/" + phase_name + "/"


## Save grid state as JSON
func _save_grid_state(output_dir: String, context: RefCounted) -> void:
	if not context.has("grid") or not context.grid:
		return

	var grid_data := _serialize_grid(context.grid)
	var file_path := output_dir + "grid_state.json"

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_warning("DebugSystem: Failed to save grid state to: %s" % file_path)
		return

	file.store_string(JSON.stringify(grid_data, "\t"))
	file.close()


## Serialize grid to JSON-compatible format
func _serialize_grid(grid: Array) -> Dictionary:
	var grid_data := {
		"width": grid[0].size() if not grid.is_empty() else 0, "height": grid.size(), "cells": []
	}

	for y in range(grid.size()):
		var row: Array = []
		for x in range(grid[y].size()):
			var cell: Cell = grid[y][x]
			row.append(
				{
					"type": Cell.Type.keys()[cell.type],
					"room_id": cell.room_id,
					"height": cell.height
				}
			)
		grid_data["cells"].append(row)

	return grid_data


## Save minimap image
func _save_minimap_image(output_dir: String, context: RefCounted) -> void:
	if not context.has("grid") or not context.grid:
		return

	var minimap_image := _render_minimap(context.grid)
	var file_path := output_dir + "minimap.png"

	var err := minimap_image.save_png(file_path)
	if err != OK:
		push_warning("DebugSystem: Failed to save minimap to: %s (error: %d)" % [file_path, err])


## Render minimap from grid
func _render_minimap(grid: Array) -> Image:
	if grid.is_empty():
		return Image.create(1, 1, false, Image.FORMAT_RGB8)

	var width: int = grid[0].size()
	var height: int = grid.size()
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)

	for y in range(height):
		for x in range(width):
			var cell: Cell = grid[y][x]
			var color := _get_cell_color(cell)
			image.set_pixel(x, y, color)

	return image


## Get color for cell type
func _get_cell_color(cell: Cell) -> Color:
	match cell.type:
		Cell.Type.ROOM:
			return Color.WHITE
		Cell.Type.HALLWAY:
			return Color.GRAY
		Cell.Type.OUTDOOR:
			return Color.GREEN
		Cell.Type.CAVE:
			return Color(0.6, 0.4, 0.2)  # Brown
		Cell.Type.BOSS_ARENA:
			return Color.RED
		Cell.Type.SECRET:
			return Color.YELLOW
		_:
			return Color.BLACK


## Save context metadata
func _save_context_metadata(output_dir: String, phase_name: String, context: RefCounted) -> void:
	var metadata := {"phase": phase_name, "timestamp": Time.get_ticks_msec(), "seed": current_seed}

	# Add room count
	if context.has("rooms"):
		metadata["room_count"] = context.rooms.size()

	# Add hallway count
	if context.has("hallways"):
		metadata["hallway_count"] = context.hallways.size()

	# Add outdoor area count
	if context.has("outdoor_areas"):
		metadata["outdoor_area_count"] = context.outdoor_areas.size()

	# Add cave area count
	if context.has("cave_areas"):
		metadata["cave_area_count"] = context.cave_areas.size()

	# Add spawn counts
	if context.has("monster_spawns"):
		metadata["monster_spawn_count"] = context.monster_spawns.size()

	if context.has("item_spawns"):
		metadata["item_spawn_count"] = context.item_spawns.size()

	# Add phase times
	if context.has("phase_times"):
		metadata["phase_times"] = context.phase_times

	# Add configuration
	if context.has("config") and context.config:
		metadata["config"] = _serialize_config(context.config)

	# Save to file
	var file_path := output_dir + "metadata.json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_warning("DebugSystem: Failed to save metadata to: %s" % file_path)
		return

	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()


## Serialize configuration to JSON-compatible format
func _serialize_config(config: RefCounted) -> Dictionary:
	var config_data := {}

	if config.has("map_size"):
		config_data["map_size"] = [config.map_size.x, config.map_size.y]

	if config.has("outdoor_bias"):
		config_data["outdoor_bias"] = config.outdoor_bias

	if config.has("cave_bias"):
		config_data["cave_bias"] = config.cave_bias

	if config.has("theme"):
		config_data["theme"] = config.theme

	if config.has("monster_density"):
		config_data["monster_density"] = config.monster_density

	if config.has("item_density"):
		config_data["item_density"] = config.item_density

	if config.has("prefab_detail_level"):
		config_data["prefab_detail_level"] = config.prefab_detail_level

	return config_data


## Save room details for debugging
func save_room_details(output_dir: String, rooms: Array) -> void:
	if not debug_enabled:
		return

	var rooms_data := []

	for room_data: Variant in rooms:
		var room: Room = room_data as Room
		if not room:
			continue

		rooms_data.append(
			{
				"id": room.id,
				"center": [room.center.x, room.center.y],
				"cell_count": room.cells.size(),
				"type": Room.RoomType.keys()[room.type],
				"connections": room.connections,
				"entrance_count": room.entrance_points.size()
			}
		)

	var file_path := output_dir + "rooms.json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_warning("DebugSystem: Failed to save room details to: %s" % file_path)
		return

	file.store_string(JSON.stringify(rooms_data, "\t"))
	file.close()


## Create summary report of entire generation
func create_generation_summary(context: RefCounted) -> Dictionary:
	var summary := {
		"seed": current_seed, "timestamp": Time.get_ticks_msec(), "total_generation_time_ms": 0
	}

	if context.has("generation_start_time"):
		summary["total_generation_time_ms"] = Time.get_ticks_msec() - context.generation_start_time

	if context.has("phase_times"):
		summary["phase_times"] = context.phase_times

	if context.has("rooms"):
		summary["room_count"] = context.rooms.size()

	if context.has("hallways"):
		summary["hallway_count"] = context.hallways.size()

	if context.has("monster_spawns"):
		summary["monster_spawn_count"] = context.monster_spawns.size()

	if context.has("item_spawns"):
		summary["item_spawn_count"] = context.item_spawns.size()

	if context.has("skipped_prefabs"):
		summary["skipped_prefab_count"] = context.skipped_prefabs.size()

	return summary


## Save generation summary
func save_generation_summary(context: RefCounted) -> void:
	if not debug_enabled:
		return

	var summary := create_generation_summary(context)
	var file_path := debug_output_dir + current_seed + "/generation_summary.json"

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_warning("DebugSystem: Failed to save generation summary to: %s" % file_path)
		return

	file.store_string(JSON.stringify(summary, "\t"))
	file.close()

	print("DebugSystem: Generation summary saved to: %s" % file_path)
