extends RefCounted
class_name BatchGenerator

## BatchGenerator - Generates multiple maps in sequence for episodes
## Implements Requirements 23.1-23.6

const GenConfig = preload("res://game/scripts/map_generator/generation_config.gd")

signal batch_progress(current_map: int, total_maps: int)
signal map_completed(map_index: int, output_path: String)

var _map_generator: Node = null
var _is_generating: bool = false
var _should_cancel: bool = false


func initialize(map_generator: Node) -> void:
	_map_generator = map_generator


## Generate episode of multiple maps
func generate_episode(
	base_seed: String, episode_length: int, config: GenConfig, output_directory: String
) -> Array[String]:
	if _is_generating:
		push_warning("BatchGenerator: Batch generation already in progress")
		return []

	_is_generating = true
	_should_cancel = false

	var generated_maps: Array[String] = []

	for i in range(episode_length):
		if _should_cancel:
			break

		# Derive sequential seed
		var map_seed := "%s_map_%d" % [base_seed, i]

		# Scale difficulty for this map
		var map_config := config.duplicate()
		map_config.difficulty_scaling = _scale_difficulty(
			config.difficulty_scaling, i, episode_length
		)

		# Emit progress
		batch_progress.emit(i + 1, episode_length)

		# Generate map
		var output_path := "%s/%s.tscn" % [output_directory, map_seed]
		var success := await _generate_single_map(map_seed, map_config, output_path)

		if success:
			generated_maps.append(output_path)
			map_completed.emit(i, output_path)
		else:
			push_error("BatchGenerator: Failed to generate map %d/%d" % [i + 1, episode_length])
			break

	_is_generating = false
	return generated_maps


## Cancel batch generation
func cancel_generation() -> void:
	_should_cancel = true
	if _map_generator and _map_generator.has_method("cancel_generation"):
		_map_generator.cancel_generation()


## Generate single map in batch
func _generate_single_map(seed_str: String, config: GenConfig, output_path: String) -> bool:
	if not _map_generator:
		push_error("BatchGenerator: MapGenerator not initialized")
		return false

	var result := {"complete": false, "success": false}

	# Connect to completion signal
	var on_completed := func(map_scene: PackedScene, _metadata: Dictionary) -> void:
		result["complete"] = true
		# Export the map
		if _map_generator.has_method("export_map"):
			result["success"] = _map_generator.export_map(
				map_scene, output_path, config.export_format
			)
		else:
			result["success"] = false

	var on_failed := func(_error: String) -> void:
		result["complete"] = true
		result["success"] = false

	_map_generator.generation_completed.connect(on_completed)
	_map_generator.generation_failed.connect(on_failed)

	# Start generation
	_map_generator.generate_map(seed_str, config)

	# Wait for completion
	while not result["complete"] and not _should_cancel:
		await _map_generator.get_tree().process_frame

	# Disconnect signals
	_map_generator.generation_completed.disconnect(on_completed)
	_map_generator.generation_failed.disconnect(on_failed)

	return result["success"]


## Scale difficulty across episode
func _scale_difficulty(
	base_difficulty: GenConfig.DifficultyLevel, map_index: int, total_maps: int
) -> GenConfig.DifficultyLevel:
	# Calculate progression (0.0 to 1.0)
	var progression := float(map_index) / float(total_maps)

	# Scale difficulty based on progression
	match base_difficulty:
		GenConfig.DifficultyLevel.EASY:
			if progression > 0.7:
				return GenConfig.DifficultyLevel.NORMAL
			return GenConfig.DifficultyLevel.EASY
		GenConfig.DifficultyLevel.NORMAL:
			if progression > 0.7:
				return GenConfig.DifficultyLevel.HARD
			return GenConfig.DifficultyLevel.NORMAL
		GenConfig.DifficultyLevel.HARD:
			if progression > 0.7:
				return GenConfig.DifficultyLevel.NIGHTMARE
			return GenConfig.DifficultyLevel.HARD
		GenConfig.DifficultyLevel.NIGHTMARE:
			return GenConfig.DifficultyLevel.NIGHTMARE
		_:
			return base_difficulty
