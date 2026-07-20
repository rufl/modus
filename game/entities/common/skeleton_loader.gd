class_name SkeletonLoader
extends Node

## Handles loading and validation of skeleton from GLB files
## Extracted from SkeletalCharacterVisuals for better separation

const DEBUG_SKELETON_SETUP: bool = false

var skeleton: Skeleton3D
var mannequin_instance: Node3D


func load_skeleton(glb_path: String) -> bool:
	if DEBUG_SKELETON_SETUP:
		GameManager.get_core_system("logger").info(
			"[SkeletonLoader] Loading mannequin from: %s" % glb_path, "Game"
		)

	if not ResourceLoader.exists(glb_path):
		push_error("[SkeletonLoader] Mannequin GLB not found at: %s" % glb_path)
		return false

	var mesh_scene: PackedScene = load(glb_path)
	if not mesh_scene:
		push_error("[SkeletonLoader] Failed to load mannequin scene")
		return false

	mannequin_instance = mesh_scene.instantiate()
	if not mannequin_instance:
		push_error("[SkeletonLoader] Failed to instantiate mannequin scene")
		return false

	var imported_skeleton: Skeleton3D = _find_skeleton_in_scene(mannequin_instance)
	if not imported_skeleton:
		push_error("[SkeletonLoader] No Skeleton3D found in mannequin GLB")
		mannequin_instance.queue_free()
		return false

	skeleton = imported_skeleton
	skeleton.name = "GeneralSkeleton"

	if DEBUG_SKELETON_SETUP:
		GameManager.get_core_system("logger").info(
			(
				"[SkeletonLoader] Successfully loaded skeleton with %d bones"
				% skeleton.get_bone_count()
			),
			"Game"
		)
		_log_bone_names()

	return true


func get_skeleton() -> Skeleton3D:
	return skeleton


func get_mannequin_instance() -> Node3D:
	return mannequin_instance


func find_bone_index(bone_name: String) -> int:
	if not skeleton:
		return -1
	return skeleton.find_bone(bone_name)


func get_bone_count() -> int:
	if not skeleton:
		return 0
	return skeleton.get_bone_count()


func _find_skeleton_in_scene(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root

	# Common paths
	var common_paths: Array[String] = [
		"Rig/Skeleton3D",
		"Armature/Skeleton3D",
		"Skeleton3D",
		"Root/Skeleton3D",
	]

	for path in common_paths:
		var node: Node = root.get_node_or_null(path)
		if node is Skeleton3D:
			if DEBUG_SKELETON_SETUP:
				GameManager.get_core_system("logger").info(
					"[SkeletonLoader] Found skeleton at path: %s" % path, "Game"
				)
			return node

	# Breadth-first search
	var queue: Array[Node] = [root]
	while queue.size() > 0:
		var current: Node = queue.pop_front()
		for child in current.get_children():
			if child is Skeleton3D:
				if DEBUG_SKELETON_SETUP:
					GameManager.get_core_system("logger").info(
						"[SkeletonLoader] Found skeleton via search: %s" % child.name, "Game"
					)
				return child
			queue.append(child)

	return null


func _log_bone_names() -> void:
	if not skeleton:
		return

	GameManager.get_core_system("logger").info("[SkeletonLoader] Skeleton bone list:", "Game")
	for i in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(i)
		var parent_idx: int = skeleton.get_bone_parent(i)
		var parent_name: String = skeleton.get_bone_name(parent_idx) if parent_idx >= 0 else "ROOT"
		GameManager.get_core_system("logger").info(
			"  [%d] %s (parent: %s)" % [i, bone_name, parent_name], "Game"
		)
