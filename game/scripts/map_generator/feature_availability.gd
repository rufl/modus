extends RefCounted
class_name FeatureAvailability

## FeatureAvailability
## Detects and manages graceful degradation for optional features
## Provides fallback mechanisms when optional dependencies are unavailable

## Feature availability flags
var voxel_tools_available: bool = false
var advanced_geometry_available: bool = true  # CSG always available in Godot
var multimesh_available: bool = true  # MultiMesh always available in Godot
var occlusion_culling_available: bool = true  # OccluderInstance3D always available


## Initialize and detect all optional features
func initialize() -> void:
	_detect_voxel_tools()
	_log_feature_availability()


## Detect Voxel Tools addon availability
func _detect_voxel_tools() -> void:
	# Check for VoxelTerrain class (core class from Voxel Tools)
	if ClassDB.class_exists("VoxelTerrain"):
		voxel_tools_available = true
		return

	# Fallback: Check for addon script files
	if ResourceLoader.exists("res://addons/voxel/voxel_terrain.gd"):
		voxel_tools_available = true
		return

	voxel_tools_available = false


## Log feature availability status
func _log_feature_availability() -> void:
	print("MapGenerator Feature Availability:")
	print(
		(
			"  - Voxel Tools: %s"
			% ("Available" if voxel_tools_available else "Not Available (using CSG fallback)")
		)
	)
	print("  - Advanced Geometry (CSG): Available")
	print("  - MultiMesh Batching: Available")
	print("  - Occlusion Culling: Available")


## Get cave generation method based on availability
func get_cave_generation_method() -> String:
	if voxel_tools_available:
		return "voxel"
	return "csg"


## Check if a feature is available
func is_feature_available(feature_name: String) -> bool:
	match feature_name:
		"voxel_tools":
			return voxel_tools_available
		"advanced_geometry":
			return advanced_geometry_available
		"multimesh":
			return multimesh_available
		"occlusion_culling":
			return occlusion_culling_available
		_:
			push_warning("Unknown feature: %s" % feature_name)
			return false


## Get fallback method for a feature
func get_fallback_method(feature_name: String) -> String:
	match feature_name:
		"voxel_tools":
			return "csg_geometry"
		"advanced_geometry":
			return "basic_geometry"
		"multimesh":
			return "individual_instances"
		"occlusion_culling":
			return "no_culling"
		_:
			return "none"


## Handle missing prefab gracefully
func handle_missing_prefab(prefab_path: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: Prefab not found: %s (skipping)" % prefab_path)

	# Track skipped prefabs in context
	if context and context.has("skipped_prefabs"):
		context.skipped_prefabs.append(
			{"path": prefab_path, "reason": "File not found", "timestamp": Time.get_ticks_msec()}
		)

	return false  # Prefab cannot be loaded


## Handle invalid prefab metadata gracefully
func handle_invalid_prefab_metadata(
	prefab_path: String, error: String, context: RefCounted
) -> bool:
	push_warning(
		"MapGenerator: Invalid prefab metadata for '%s': %s (skipping)" % [prefab_path, error]
	)

	# Track skipped prefabs in context
	if context and context.has("skipped_prefabs"):
		context.skipped_prefabs.append(
			{
				"path": prefab_path,
				"reason": "Invalid metadata: %s" % error,
				"timestamp": Time.get_ticks_msec()
			}
		)

	return false  # Prefab cannot be used


## Handle missing theme gracefully
func handle_missing_theme(theme_name: String, context: RefCounted) -> String:
	push_warning("MapGenerator: Theme '%s' not found, using default 'tech' theme" % theme_name)

	# Track theme fallback in context
	if context and context.has("metadata"):
		if not context.metadata.has("fallbacks"):
			context.metadata["fallbacks"] = []
		context.metadata["fallbacks"].append(
			{
				"type": "theme",
				"requested": theme_name,
				"fallback": "tech",
				"timestamp": Time.get_ticks_msec()
			}
		)

	return "tech"  # Default fallback theme


## Handle navigation mesh baking failure gracefully
func handle_navmesh_baking_failure(error: String, context: RefCounted) -> bool:
	push_error("MapGenerator: Navigation mesh baking failed: %s" % error)

	# Track failure in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{"type": "navmesh_baking_failed", "error": error, "timestamp": Time.get_ticks_msec()}
		)

	# Navigation mesh is critical - return false to indicate failure
	return false


## Handle CSG baking failure gracefully
func handle_csg_baking_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: CSG baking failed: %s (using unbaked CSG)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "csg_baking_failed",
				"error": error,
				"fallback": "unbaked_csg",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# CSG baking is optional - can continue with unbaked CSG
	return true


## Handle LOD generation failure gracefully
func handle_lod_generation_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: LOD generation failed: %s (disabling LOD)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "lod_generation_failed",
				"error": error,
				"fallback": "no_lod",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# LOD is optional - can continue without it
	return true


## Handle MultiMesh batching failure gracefully
func handle_multimesh_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: MultiMesh batching failed: %s (using individual instances)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "multimesh_failed",
				"error": error,
				"fallback": "individual_instances",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# MultiMesh is optional - can continue with individual instances
	return true


## Handle occlusion culling failure gracefully
func handle_occlusion_culling_failure(error: String, context: RefCounted) -> bool:
	push_warning("MapGenerator: Occlusion culling failed: %s (disabling occlusion)" % error)

	# Track warning in context
	if context and context.has("metadata"):
		if not context.metadata.has("warnings"):
			context.metadata["warnings"] = []
		context.metadata["warnings"].append(
			{
				"type": "occlusion_culling_failed",
				"error": error,
				"fallback": "no_occlusion",
				"timestamp": Time.get_ticks_msec()
			}
		)

	# Occlusion culling is optional - can continue without it
	return true


## Create feature availability report
func create_availability_report() -> Dictionary:
	return {
		"voxel_tools":
		{
			"available": voxel_tools_available,
			"fallback": "csg_geometry" if not voxel_tools_available else "none"
		},
		"advanced_geometry": {"available": advanced_geometry_available, "fallback": "none"},
		"multimesh": {"available": multimesh_available, "fallback": "none"},
		"occlusion_culling": {"available": occlusion_culling_available, "fallback": "none"}
	}


## Get recommended configuration based on feature availability
func get_recommended_config() -> Dictionary:
	var config := {}

	# Recommend disabling features that aren't available
	if not voxel_tools_available:
		config["cave_bias"] = 0.0  # Suggest lower cave bias if voxel tools unavailable
		config["cave_generation_note"] = "Using CSG fallback (Voxel Tools not available)"

	return config
