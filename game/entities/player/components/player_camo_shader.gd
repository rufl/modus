class_name PlayerCamoShader
extends GameComponent

## Applies dark camo pattern shader to player character
## Replaces solid color with procedural military camouflage

const CAMO_SHADER = preload("res://game/art/shaders/dark_camo.gdshader")

var _player: Node3D
var _visuals: SkeletalCharacterVisuals
var _original_materials: Dictionary = {}
var _camo_materials: Array[ShaderMaterial] = []


func _exit_tree() -> void:
	# Clean up created shader materials
	_camo_materials.clear()
	_original_materials.clear()


func setup(player: Node3D, visuals: SkeletalCharacterVisuals) -> void:
	_player = player
	_visuals = visuals

	if not _visuals:
		push_warning("[PlayerCamoShader] No visuals provided")
		return

	# Wait for visuals to be fully ready
	await _player.ready
	call_deferred("_apply_camo_shader")


func _apply_camo_shader() -> void:
	if not _visuals or not _visuals.mannequin_root:
		push_warning("[PlayerCamoShader] Visuals not ready")
		return

	# Find all mesh instances in the mannequin
	var meshes := _find_all_meshes(_visuals.mannequin_root)

	if meshes.is_empty():
		push_warning("[PlayerCamoShader] No meshes found in mannequin")
		return

	GameManager.get_core_system("logger").info(
		"[PlayerCamoShader] Applying camo shader to %d meshes" % meshes.size(), "Player"
	)

	for mesh_inst in meshes:
		_apply_camo_to_mesh(mesh_inst)


func _apply_camo_to_mesh(mesh_inst: MeshInstance3D) -> void:
	# Store original material for potential restoration
	if mesh_inst.material_override:
		_original_materials[mesh_inst.get_instance_id()] = mesh_inst.material_override

	# Create camo shader material
	var camo_mat := ShaderMaterial.new()
	camo_mat.shader = CAMO_SHADER

	# Configure camo colors (dark military palette)
	camo_mat.set_shader_parameter("base_color", Vector3(0.15, 0.18, 0.12))  # Dark olive
	camo_mat.set_shader_parameter("camo_color_1", Vector3(0.08, 0.10, 0.06))  # Very dark green
	camo_mat.set_shader_parameter("camo_color_2", Vector3(0.12, 0.14, 0.10))  # Medium dark
	camo_mat.set_shader_parameter("camo_color_3", Vector3(0.18, 0.16, 0.12))  # Lighter brown-green

	# Pattern settings
	camo_mat.set_shader_parameter("pattern_scale", 2.5)
	camo_mat.set_shader_parameter("pattern_complexity", 3.0)
	camo_mat.set_shader_parameter("roughness_value", 0.8)  # Matte fabric
	camo_mat.set_shader_parameter("metallic_value", 0.0)  # No metal

	# Apply to mesh
	mesh_inst.material_override = camo_mat
	_camo_materials.append(camo_mat)

	GameManager.get_core_system("logger").info(
		"[PlayerCamoShader] Applied camo to mesh: %s" % mesh_inst.name, "Player"
	)


func _find_all_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []

	if root is MeshInstance3D:
		meshes.append(root)

	for child in root.get_children():
		meshes.append_array(_find_all_meshes(child))

	return meshes


## Restore original materials (for customization/skins)
func restore_original_materials() -> void:
	if not _visuals or not _visuals.mannequin_root:
		return

	var meshes := _find_all_meshes(_visuals.mannequin_root)

	for mesh_inst in meshes:
		var id := mesh_inst.get_instance_id()
		if _original_materials.has(id):
			mesh_inst.material_override = _original_materials[id]


## Change camo color scheme
func set_camo_colors(base: Color, dark: Color, medium: Color, light: Color) -> void:
	if not _visuals or not _visuals.mannequin_root:
		return

	var meshes := _find_all_meshes(_visuals.mannequin_root)

	for mesh_inst in meshes:
		if mesh_inst.material_override and mesh_inst.material_override is ShaderMaterial:
			var mat := mesh_inst.material_override as ShaderMaterial
			if mat.shader == CAMO_SHADER:
				mat.set_shader_parameter("base_color", Vector3(base.r, base.g, base.b))
				mat.set_shader_parameter("camo_color_1", Vector3(dark.r, dark.g, dark.b))
				mat.set_shader_parameter("camo_color_2", Vector3(medium.r, medium.g, medium.b))
				mat.set_shader_parameter("camo_color_3", Vector3(light.r, light.g, light.b))


## Adjust pattern scale
func set_pattern_scale(scale: float) -> void:
	if not _visuals or not _visuals.mannequin_root:
		return

	var meshes := _find_all_meshes(_visuals.mannequin_root)

	for mesh_inst in meshes:
		if mesh_inst.material_override and mesh_inst.material_override is ShaderMaterial:
			var mat := mesh_inst.material_override as ShaderMaterial
			if mat.shader == CAMO_SHADER:
				mat.set_shader_parameter("pattern_scale", scale)
