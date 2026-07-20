class_name BossVisualEffects
extends Node

signal effects_applied

const BOSS_TIER: int = 4
const ELITE_TIER: int = 3

var size_multiplier: float = 1.5
var glow_enabled: bool = true
var glow_color: Color = Color(1.0, 0.3, 1.0, 0.8)  # Magenta for boss
var glow_intensity: float = 2.0
var aura_enabled: bool = true
var aura_color: Color = Color(0.8, 0.2, 0.8, 0.5)

var _enemy: Node3D
var _original_scale: Vector3
var _glow_material: ShaderMaterial
var _aura_particles: GPUParticles3D


func setup(enemy: Node3D, tier: int) -> void:
	_enemy = enemy
	_original_scale = enemy.scale

	# Load config
	_load_config()

	# Only apply effects for boss tier
	if tier >= BOSS_TIER:
		_apply_boss_effects()
	elif tier >= ELITE_TIER:
		_apply_elite_effects()

	effects_applied.emit()


func _load_config() -> void:
	if not GameManager.get_core_system("config"):
		return

	var cfg: Dictionary = GameManager.get_core_system("config").get_value(
		"visuals.boss_effects", {}
	)
	if cfg.is_empty():
		return

	size_multiplier = cfg.get("size_multiplier", size_multiplier)
	glow_enabled = cfg.get("glow_enabled", glow_enabled)
	glow_intensity = cfg.get("glow_intensity", glow_intensity)
	aura_enabled = cfg.get("aura_enabled", aura_enabled)

	# Parse colors
	if cfg.has("glow_color"):
		var c: Dictionary = cfg.glow_color
		glow_color = Color(c.get("r", 1.0), c.get("g", 0.3), c.get("b", 1.0), c.get("a", 0.8))
	if cfg.has("aura_color"):
		var c: Dictionary = cfg.aura_color
		aura_color = Color(c.get("r", 0.8), c.get("g", 0.2), c.get("b", 0.8), c.get("a", 0.5))


func _apply_boss_effects() -> void:
	# 1. Scale up
	_apply_size_scaling(size_multiplier)

	# 2. Glow effect
	if glow_enabled:
		_apply_glow_effect(glow_color, glow_intensity)

	# 3. Aura particles
	if aura_enabled:
		_create_aura_particles(aura_color)

	GameManager.get_core_system("logger").info(
		"[BossVisualEffects] Applied boss effects to %s" % _enemy.name, "BossEffects"
	)


func _apply_elite_effects() -> void:
	# Smaller scaling for elite
	_apply_size_scaling(1.2)

	# Subtle glow
	if glow_enabled:
		_apply_glow_effect(Color(1.0, 0.8, 0.2, 0.5), glow_intensity * 0.5)


func _apply_size_scaling(multiplier: float) -> void:
	if not _enemy:
		return

	# Smooth scale with tween for dramatic entrance
	var tween: Tween = _enemy.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(_enemy, "scale", _original_scale * multiplier, 0.5)


func _apply_glow_effect(color: Color, intensity: float) -> void:
	if not _enemy:
		return

	# Find visual mesh children
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(_enemy, meshes)

	# Create glow shader material
	_glow_material = _create_glow_material(color, intensity)

	# Apply as overlay to each mesh
	for mesh: MeshInstance3D in meshes:
		# Add glow as next pass
		var base_mat: Material = mesh.get_active_material(0)
		if base_mat:
			base_mat.next_pass = _glow_material


func _create_glow_material(color: Color, intensity: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()

	# Simple rim/fresnel glow shader
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 1.0, 0.8);
uniform float intensity : hint_range(0.0, 5.0) = 2.0;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

void fragment() {
	float rim = pow(1.0 - dot(NORMAL, VIEW), rim_power);
	ALBEDO = glow_color.rgb * intensity;
	ALPHA = rim * glow_color.a;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("intensity", intensity)

	return mat


func _create_aura_particles(color: Color) -> void:
	if not _enemy:
		return

	_aura_particles = GPUParticles3D.new()
	_aura_particles.name = "BossAura"
	_aura_particles.amount = 30
	_aura_particles.lifetime = 2.0
	_aura_particles.emitting = true
	_aura_particles.local_coords = false

	# Create process material
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5
	pm.gravity = Vector3(0, 0.5, 0)  # Slow rise
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.scale_min = 0.1
	pm.scale_max = 0.3
	pm.color = color

	_aura_particles.process_material = pm

	# Use simple quad mesh for particles
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	_aura_particles.draw_pass_1 = mesh

	_enemy.add_child(_aura_particles)


func _find_mesh_instances(node: Node, results: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		results.append(node)
	for child: Node in node.get_children():
		_find_mesh_instances(child, results)


func remove_effects() -> void:
	# Restore original scale
	if _enemy:
		_enemy.scale = _original_scale

	# Remove aura
	if is_instance_valid(_aura_particles):
		_aura_particles.queue_free()
