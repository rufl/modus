class_name FirstPersonBodyShader
extends GameComponent

## GTA V-style first-person body rendering
## Applies shader-based transparency to prevent clipping while keeping full body visible

const FP_SHADER = preload("res://game/art/shaders/first_person_body.gdshader")

var camera: Camera3D
var visuals: SkeletalCharacterVisuals
var shader_materials: Array[ShaderMaterial] = []
var is_first_person: bool = true
var player: Node = null  # Reference to player for camera mode detection


func _log(message: String, category: String = "FirstPersonBodyShader") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func setup(
	player_camera: Camera3D, player_visuals: SkeletalCharacterVisuals, player_node: Node = null
) -> void:
	camera = player_camera
	visuals = player_visuals
	player = player_node

	# Wait for visuals to be ready
	if not visuals.mannequin_root:
		await get_tree().process_frame

	_apply_shader_to_meshes()

	# Listen for camera mode changes if player has camera component
	if player:
		var cam_comp: Node = player.get_node_or_null("CameraComponent")
		if cam_comp and cam_comp.has_signal("camera_mode_changed"):
			safe_connect(cam_comp.camera_mode_changed, _on_camera_mode_changed)


func _apply_shader_to_meshes() -> void:
	if not visuals or not visuals.mannequin_root:
		push_warning("[FirstPersonBodyShader] Visuals not ready")
		return

	# Find all MeshInstance3D nodes in the mannequin
	var meshes := _find_all_mesh_instances(visuals.mannequin_root)

	_log("[FirstPersonBodyShader] Applying shader to " + str(meshes.size()) + " meshes", "Player")
	_log("[FirstPersonBodyShader] Character color: " + str(visuals.character_color), "Player")

	for mesh_inst in meshes:
		# Create shader material
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = FP_SHADER

		# CRITICAL FIX: ALWAYS use character color from visuals (never use existing material color)
		var char_color := visuals.character_color

		# Copy OTHER properties from existing material if present (but NOT color)
		# Check both material_override AND the mesh's surface material
		var existing_mat := mesh_inst.material_override
		if not existing_mat and mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			existing_mat = mesh_inst.mesh.surface_get_material(0)

		if existing_mat and existing_mat is StandardMaterial3D:
			var std_mat := existing_mat as StandardMaterial3D
			shader_mat.set_shader_parameter("roughness", std_mat.roughness)
			shader_mat.set_shader_parameter("metallic", std_mat.metallic)

			# Copy texture if present
			if std_mat.albedo_texture:
				shader_mat.set_shader_parameter("texture_albedo", std_mat.albedo_texture)
				_log(
					(
						"[FirstPersonBodyShader] Copied texture from material for "
						+ str(mesh_inst.name)
					),
					"Player"
				)
			else:
				_log(
					(
						"[FirstPersonBodyShader] No albedo texture found in material for "
						+ str(mesh_inst.name)
					),
					"Player"
				)
		else:
			_log(
				"[FirstPersonBodyShader] No StandardMaterial3D found for " + str(mesh_inst.name),
				"Player"
			)

		# Set albedo color (CRITICAL: This must be set!)
		shader_mat.set_shader_parameter("albedo", char_color)
		_log(
			(
				"[FirstPersonBodyShader] Set albedo for "
				+ str(mesh_inst.name)
				+ " to "
				+ str(char_color)
			),
			"Player"
		)

		# Set initial camera position
		if camera:
			shader_mat.set_shader_parameter("camera_position", camera.global_position)

		# Enable transparency by default for first-person
		shader_mat.set_shader_parameter("enable_fp_transparency", is_first_person)

		# Apply shader material
		mesh_inst.material_override = shader_mat
		shader_materials.append(shader_mat)

		# CRITICAL: Enable transparency in mesh rendering
		mesh_inst.transparency = 1.0  # ALPHA blend mode


func _process(_delta: float) -> void:
	if not camera or shader_materials.is_empty():
		return

	# Update camera position in all shader materials
	var cam_pos := camera.global_position
	for mat in shader_materials:
		if mat:
			mat.set_shader_parameter("camera_position", cam_pos)


func set_first_person_mode(enabled: bool) -> void:
	is_first_person = enabled

	for mat in shader_materials:
		if mat:
			mat.set_shader_parameter("enable_fp_transparency", enabled)


func set_fade_distances(fade_start: float, fade_end: float) -> void:
	for mat in shader_materials:
		if mat:
			mat.set_shader_parameter("fade_start_distance", fade_start)
			mat.set_shader_parameter("fade_end_distance", fade_end)


func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var results: Array[MeshInstance3D] = []

	# Skip weapon attachments - we don't want the body shader on weapons!
	if node is BoneAttachment3D and node.name.begins_with("WeaponAttachment"):
		return results

	if node is MeshInstance3D:
		results.append(node)

	for child in node.get_children():
		results.append_array(_find_all_mesh_instances(child))

	return results


## Update character color (called when visuals color changes)
func update_character_color(new_color: Color) -> void:
	for mat in shader_materials:
		if mat:
			mat.set_shader_parameter("albedo", new_color)


## Handle camera mode changes (for third-person support)
func _on_camera_mode_changed(new_mode: int) -> void:
	# CameraMode enum: FIRST_PERSON = 0, THIRD_PERSON = 1, OVER_SHOULDER = 2
	var is_fp := new_mode == 0  # FIRST_PERSON
	set_first_person_mode(is_fp)

	if OS.is_debug_build():
		_log(
			(
				"Camera mode changed to: %s - FP transparency: %s"
				% [["FIRST_PERSON", "THIRD_PERSON", "OVER_SHOULDER"][new_mode], is_fp]
			),
			"FirstPersonBodyShader"
		)
