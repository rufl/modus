extends Node3D
class_name HighlightComponent

# Red - targeted by crosshair, Yellow - in AoE skill range, Green - friendly/allied
enum HighlightType { NONE = 0, CROSSHAIR = 1, AOE = 2, ALLY = 4 }

const COLOR_CROSSHAIR: Color = Color(1.0, 0.2, 0.2, 1.0)  # Red
const COLOR_AOE: Color = Color(1.0, 0.9, 0.2, 1.0)  # Yellow
const COLOR_ALLY: Color = Color(0.2, 1.0, 0.2, 1.0)  # Green
const COLOR_CROSSHAIR_CB: Color = Color(1.0, 0.5, 0.0, 1.0)  # Orange
const COLOR_AOE_CB: Color = Color(0.0, 0.7, 1.0, 1.0)  # Cyan
const COLOR_ALLY_CB: Color = Color(0.5, 1.0, 0.5, 1.0)  # Light Green

@export var fade_duration: float = 0.1
@export var glow_intensity: float = 0.5
@export var glow_range: float = 2.0

var colorblind_mode: bool = false
var intensity_multiplier: float = 1.0
var highlights_enabled: bool = true
var active_highlights: int = 0  # Bitfield of active HighlightType flags
var current_color: Color = Color.TRANSPARENT
var target_color: Color = Color.TRANSPARENT
var glow_light: OmniLight3D = null
var outline_material: ShaderMaterial = null
var enemy_meshes: Array[MeshInstance3D] = []
var fade_tween: Tween = null


func _ready() -> void:
	_setup_glow_light()
	_find_enemy_meshes()
	_setup_outline_shader()


func _setup_glow_light() -> void:
	## Create OmniLight3D for glow effect
	glow_light = OmniLight3D.new()
	glow_light.name = "HighlightGlow"
	glow_light.light_energy = 0.0
	glow_light.omni_range = glow_range
	glow_light.light_color = Color.WHITE
	glow_light.omni_attenuation = 2.0
	add_child(glow_light)


func _find_enemy_meshes() -> void:
	## Find all MeshInstance3D nodes in parent enemy
	var parent_node: Node = get_parent()
	if not parent_node:
		return

	_recursive_find_meshes(parent_node)


func _recursive_find_meshes(node: Node) -> void:
	## Recursively find all MeshInstance3D nodes
	if node is MeshInstance3D:
		enemy_meshes.append(node)

	for child: Node in node.get_children():
		_recursive_find_meshes(child)


func _setup_outline_shader() -> void:
	## Setup outline shader for enemy meshes
	# Create shader material
	outline_material = ShaderMaterial.new()
	outline_material.shader = _create_outline_shader()

	# Apply to all meshes as overlay
	for mesh: MeshInstance3D in enemy_meshes:
		if mesh.material_overlay:
			continue
		mesh.material_overlay = outline_material.duplicate()


func _create_outline_shader() -> Shader:
	## Create outline shader
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Expand vertices along normals for outline effect
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_alpha;
}
"""
	return shader


func _process(delta: float) -> void:
	## Update color transitions
	if current_color.is_equal_approx(target_color):
		return

	# Smooth color transition
	var t: float = delta / fade_duration
	current_color = current_color.lerp(target_color, t)

	_apply_color(current_color)


func _apply_color(color: Color) -> void:
	## Apply color to outline and glow
	# Update glow light
	if glow_light:
		glow_light.light_color = color
		glow_light.light_energy = color.a * glow_intensity

	# Update outline shader
	for mesh: MeshInstance3D in enemy_meshes:
		if not mesh or not mesh.material_overlay:
			continue

		var mat: ShaderMaterial = mesh.material_overlay as ShaderMaterial
		if mat:
			mat.set_shader_parameter("outline_color", color)
			mat.set_shader_parameter("outline_alpha", color.a)


func add_highlight(type: HighlightType) -> void:
	## Add a highlight type (can have multiple active)
	if type == HighlightType.NONE:
		return

	# Add to bitfield
	active_highlights |= type

	# Update color based on priority
	_update_target_color()

	# Animate fade-in
	_animate_fade_in()


func remove_highlight(type: HighlightType) -> void:
	## Remove a highlight type
	if type == HighlightType.NONE:
		return

	# Remove from bitfield
	active_highlights &= ~type

	# Update color based on remaining highlights
	_update_target_color()

	# Animate fade-out if no highlights remain
	if active_highlights == 0:
		_animate_fade_out()


func clear_all_highlights() -> void:
	## Remove all highlights
	active_highlights = 0
	_update_target_color()
	_animate_fade_out()


func has_highlight(type: HighlightType) -> bool:
	## Check if a specific highlight type is active
	return (active_highlights & type) != 0


func _update_target_color() -> void:
	## Update target color based on active highlights (priority order)
	if not highlights_enabled or active_highlights == 0:
		target_color = Color.TRANSPARENT
		return

	# Select color based on priority and colorblind mode
	var base_color: Color = Color.TRANSPARENT

	# Priority: Crosshair > AoE > Ally
	if has_highlight(HighlightType.CROSSHAIR):
		base_color = COLOR_CROSSHAIR_CB if colorblind_mode else COLOR_CROSSHAIR
	elif has_highlight(HighlightType.AOE):
		base_color = COLOR_AOE_CB if colorblind_mode else COLOR_AOE
	elif has_highlight(HighlightType.ALLY):
		base_color = COLOR_ALLY_CB if colorblind_mode else COLOR_ALLY

	# Apply intensity multiplier
	target_color = base_color
	target_color.a *= intensity_multiplier


func _animate_fade_in() -> void:
	## Animate fade-in transition
	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.set_ease(Tween.EASE_OUT)

	fade_tween.tween_property(self, "current_color", target_color, fade_duration)
	fade_tween.tween_callback(_on_fade_complete)


func _animate_fade_out() -> void:
	## Animate fade-out transition
	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.set_ease(Tween.EASE_IN)

	var end_color: Color = current_color
	end_color.a = 0.0

	fade_tween.tween_property(self, "current_color", end_color, fade_duration)
	fade_tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	## Called when fade animation completes
	fade_tween = null


# Public API


func set_crosshair_highlight(enabled: bool) -> void:
	## Enable/disable crosshair highlight (red)
	if enabled:
		add_highlight(HighlightType.CROSSHAIR)
	else:
		remove_highlight(HighlightType.CROSSHAIR)


func set_aoe_highlight(enabled: bool) -> void:
	## Enable/disable AoE highlight (yellow)
	if enabled:
		add_highlight(HighlightType.AOE)
	else:
		remove_highlight(HighlightType.AOE)


func set_ally_highlight(enabled: bool) -> void:
	## Enable/disable ally highlight (green)
	if enabled:
		add_highlight(HighlightType.ALLY)
	else:
		remove_highlight(HighlightType.ALLY)


func is_highlighted() -> bool:
	## Check if any highlight is active
	return active_highlights != 0


func get_active_highlight_types() -> Array[HighlightType]:
	## Get list of active highlight types
	var types: Array[HighlightType] = []

	if has_highlight(HighlightType.CROSSHAIR):
		types.append(HighlightType.CROSSHAIR)
	if has_highlight(HighlightType.AOE):
		types.append(HighlightType.AOE)
	if has_highlight(HighlightType.ALLY):
		types.append(HighlightType.ALLY)

	return types


# Settings API


func set_colorblind_mode(enabled: bool) -> void:
	## Enable/disable colorblind-friendly colors
	colorblind_mode = enabled
	_update_target_color()


func set_intensity_multiplier(multiplier: float) -> void:
	## Set highlight intensity multiplier (0.0 to 1.0)
	intensity_multiplier = clamp(multiplier, 0.0, 1.0)
	_update_target_color()


func set_highlights_enabled(enabled: bool) -> void:
	## Enable/disable highlights
	highlights_enabled = enabled
	if not enabled:
		clear_all_highlights()
	_update_target_color()
