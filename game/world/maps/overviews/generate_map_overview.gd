@tool
extends EditorScript

const CAPTURE_SIZE: int = 2048  # Resolution of output image
const CAPTURE_HEIGHT: float = 200.0  # Camera height above capture center
const OUTPUT_DIR: String = "res://game/levels/overviews/"


func _run() -> void:
	GameManager.get_core_system("logger").info(
		"[MapOverviewGenerator] Starting overview generation...", "World"
	)

	# Get current edited scene
	var root: Node = get_editor_interface().get_edited_scene_root()
	if not root:
		push_error("[MapOverviewGenerator] No scene open in editor!")
		return

	var level_name: String = root.scene_file_path.get_file().get_basename()
	if level_name.is_empty():
		level_name = root.name

	GameManager.get_core_system("logger").info(
		"[MapOverviewGenerator] Generating overview for: %s" % level_name, "World"
	)

	# Calculate level bounds
	var bounds: AABB = _calculate_level_bounds(root)
	if bounds.size == Vector3.ZERO:
		push_error("[MapOverviewGenerator] Could not calculate level bounds!")
		return

	GameManager.get_core_system("logger").info(
		"[MapOverviewGenerator] Level bounds: %s" % bounds, "World"
	)

	# Create capture viewport
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CAPTURE_SIZE, CAPTURE_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Create orthographic camera
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL

	# Calculate camera settings
	var center := bounds.get_center()
	var max_extent: float = max(bounds.size.x, bounds.size.z) * 1.1  # 10% padding
	camera.size = max_extent
	camera.global_position = Vector3(center.x, center.y + CAPTURE_HEIGHT, center.z)
	camera.rotation_degrees = Vector3(-90, 0, 0)  # Look straight down
	camera.cull_mask = 1  # World geometry only

	viewport.add_child(camera)
	root.add_child(viewport)

	# Force render
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Wait for viewport to render (must use call_deferred in EditorScript)
	await get_editor_interface().get_base_control().get_tree().process_frame
	await get_editor_interface().get_base_control().get_tree().process_frame
	await get_editor_interface().get_base_control().get_tree().process_frame

	# Get the rendered image
	var image: Image = viewport.get_texture().get_image()

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	# Save as PNG
	var output_path: String = OUTPUT_DIR + level_name + "_overview.png"
	var err: Error = image.save_png(output_path)

	if err == OK:
		GameManager.get_core_system("logger").info(
			"[MapOverviewGenerator] ✓ Saved overview to: %s" % output_path, "World"
		)
		GameManager.get_core_system("logger").info(
			"[MapOverviewGenerator] Capture size: %.1f world units" % max_extent, "World"
		)
		GameManager.get_core_system("logger").info(
			"[MapOverviewGenerator] Center: %s" % center, "World"
		)
		GameManager.get_core_system("logger").info("", "World")
		GameManager.get_core_system("logger").info(
			"[MapOverviewGenerator] Add to gameplay.json5:", "World"
		)
		GameManager.get_core_system("logger").info('    "map_settings": {', "World")
		GameManager.get_core_system("logger").info(
			'        "map_texture_path": "%s",' % output_path, "World"
		)
		GameManager.get_core_system("logger").info(
			'        "minimap_capture_size": %.1f,' % max_extent, "World"
		)
		GameManager.get_core_system("logger").info(
			'        "minimap_center": [%.1f, %.1f, %.1f]' % [center.x, center.y, center.z], "World"
		)
		GameManager.get_core_system("logger").info("    }", "World")
	else:
		push_error("[MapOverviewGenerator] Failed to save: %s (Error: %d)" % [output_path, err])

	# Cleanup
	viewport.queue_free()


func _calculate_level_bounds(root: Node) -> AABB:
	var bounds := AABB()
	var first := true

	_find_meshes_recursive(
		root,
		func(mesh: MeshInstance3D) -> void:
			var aabb: AABB = mesh.get_aabb()
			# Transform to global space
			var global_aabb := aabb
			global_aabb.position = mesh.global_transform * aabb.position
			global_aabb.size = aabb.size * mesh.global_transform.basis.get_scale()

			if first:
				bounds = global_aabb
				first = false
			else:
				bounds = bounds.merge(global_aabb)
	)

	return bounds


func _find_meshes_recursive(node: Node, callback: Callable) -> void:
	if node is MeshInstance3D:
		callback.call(node)

	for child in node.get_children():
		_find_meshes_recursive(child, callback)
