@tool
extends Node3D
class_name MinimapGenerator

@export_category("Capture Settings")
@export var capture_name: String = "map_overview"
@export var output_path: String = "res://game/art/textures/maps"
@export var capture_size_meters: float = 300.0
@export var map_center: Vector3 = Vector3(0, 0, 0)
@export var capture_height: float = 100.0
@export_category("Actions")
@export var capture: bool = false:
	set(value):
		if value:
			_capture_map()


func _capture_map() -> void:
	GameManager.get_core_system("logger").info(
		"[MinimapGenerator] Initializing capture for '%s'..." % capture_name, "Core"
	)

	# Create SubViewport for off-screen rendering
	var vp: SubViewport = SubViewport.new()
	vp.name = "CaptureViewport"
	vp.size = Vector2i(2048, 2048)  # High resolution
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false

	# Create Camera
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = capture_size_meters
	cam.position = Vector3(map_center.x, capture_height, map_center.z)
	cam.rotation_degrees = Vector3(-90, 0, 0)  # Look straight down
	cam.far = capture_height * 2.0

	# Add to main scene so it sees the world
	add_child(vp)
	vp.add_child(cam)

	GameManager.get_core_system("logger").info("[MinimapGenerator] Rendering frame...", "Core")
	# Wait for rendering to complete (2 frames for safety and lighting update)
	await get_tree().process_frame
	await get_tree().process_frame

	# Grab texture
	var texture: Texture2D = vp.get_texture()
	var image: Image = texture.get_image()

	if not image:
		push_error("[MinimapGenerator] Failed to capture image.")
		vp.queue_free()
		return

	# Save to file
	var full_path: String = output_path.path_join(capture_name + ".png")

	# Make dir if needed
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		var err: Error = dir.make_dir_recursive(output_path)
		if err != OK:
			push_error("[MinimapGenerator] Failed to create directory: %s" % output_path)
			vp.queue_free()
			return

	var err: Error = image.save_png(full_path)
	if err == OK:
		GameManager.get_core_system("logger").info(
			"[MinimapGenerator] SUCCESS! Saved map to: %s" % full_path, "Core"
		)
		print(
			"[MinimapGenerator] Update 'game/config/performance/visuals.json5' -> map_settings -> map_texture_path"
		)
		GameManager.get_core_system("logger").info(
			"[MinimapGenerator] Also set 'minimap_capture_size' to %.1f" % capture_size_meters,
			"Core"
		)
		print(
			(
				"[MinimapGenerator] And 'minimap_center' to [%.1f, %.1f, %.1f]"
				% [map_center.x, map_center.y, map_center.z]
			)
		)
	else:
		push_error("[MinimapGenerator] Error saving PNG: %s" % error_string(err))

	# Cleanup
	vp.queue_free()
