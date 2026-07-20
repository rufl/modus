class_name VisualTweakingLab
extends Node3D

signal config_applied
signal enemy_spawned(enemy: Node3D)
signal projectile_fired(projectile: Node3D)

const ENEMY_SCENE: String = "res://game/entities/enemies/enemy.tscn"
const PROJECTILE_SCENES: Dictionary = {
	"rocket": "res://game/entities/projectiles/rocket.tscn",
	"grenade": "res://game/entities/projectiles/grenade.tscn",
	"plasma": "res://game/entities/projectiles/plasma.tscn",
}

@export var enemy_spawn_point: Marker3D
@export var projectile_spawn_point: Marker3D
@export var particle_preview: GPUParticles3D
@export var status_label: Label3D
@export var reload_button_area: Area3D

var _preview_enemy: Node3D = null
var _current_projectile_type: String = "rocket"


func _ready() -> void:
	# Connect to GameManager.get_core_system("config") reload signal
	if GameManager.get_core_system("config"):
		GameManager.get_core_system("config").config_reloaded.connect(_on_config_reloaded)

	# Setup reload button if present
	if reload_button_area:
		reload_button_area.body_entered.connect(_on_reload_button_pressed)

	# Find nodes if not exported
	_find_nodes()

	# Initial status
	_update_status("Ready - Edit JSON5 and press Reload")

	# Spawn initial preview enemy
	call_deferred("_spawn_preview_enemy")


func _find_nodes() -> void:
	if not enemy_spawn_point:
		enemy_spawn_point = get_node_or_null("EnemySpawnPoint")
	if not projectile_spawn_point:
		projectile_spawn_point = get_node_or_null("ProjectileSpawnPoint")
	if not particle_preview:
		particle_preview = get_node_or_null("ParticlePreview")
	if not status_label:
		status_label = get_node_or_null("StatusLabel")
	if not reload_button_area:
		reload_button_area = get_node_or_null("ReloadButtonArea")


func _on_config_reloaded(_file_path: String = "") -> void:
	_update_status("Config Reloaded!")

	# Apply visual changes to preview enemy
	if is_instance_valid(_preview_enemy):
		_apply_enemy_visuals()

	# Update particle preview from config
	_apply_particle_config()

	# Flash feedback
	_flash_reload_feedback()

	config_applied.emit()

	# Reset status after delay
	await get_tree().create_timer(2.0).timeout
	_update_status("Ready - Edit JSON5 and press Reload")


func _spawn_preview_enemy() -> void:
	if not enemy_spawn_point:
		push_warning("[VisualTweakingLab] No enemy spawn point set")
		return

	# Clear existing
	if is_instance_valid(_preview_enemy):
		_preview_enemy.queue_free()
		_preview_enemy = null

	# Load and spawn
	if not ResourceLoader.exists(ENEMY_SCENE):
		push_warning("[VisualTweakingLab] Enemy scene not found: %s" % ENEMY_SCENE)
		return

	var scene: PackedScene = load(ENEMY_SCENE)
	_preview_enemy = scene.instantiate()

	# Configure as passive demo
	if "is_ai_active" in _preview_enemy:
		_preview_enemy.is_ai_active = false
	if "ai_state_name" in _preview_enemy:
		_preview_enemy.ai_state_name = "Idle"
	if "enemy_id" in _preview_enemy:
		_preview_enemy.enemy_id = "dummy_bot"

	add_child(_preview_enemy)
	_preview_enemy.global_position = enemy_spawn_point.global_position

	_apply_enemy_visuals()
	enemy_spawned.emit(_preview_enemy)


func _apply_enemy_visuals() -> void:
	if not is_instance_valid(_preview_enemy):
		return

	# Read visual settings from config
	var gore_config: Dictionary = GameManager.get_core_system("config").get_value(
		"visuals.gore", {}
	)
	var _enemy_config: Dictionary = GameManager.get_core_system("config").get_value(
		"gameplay.enemies", {}
	)

	# Apply any configurable visual properties
	# This is where designers can hook in custom visual properties
	if _preview_enemy.has_method("apply_visual_config"):
		_preview_enemy.apply_visual_config(gore_config)


func _apply_particle_config() -> void:
	if not particle_preview:
		return

	# Read particle settings from config
	var gore: Dictionary = GameManager.get_core_system("config").get_value("visuals.gore", {})

	# Apply particle count
	if gore.has("blood_spray_intensity"):
		var intensity: float = gore.get("blood_spray_intensity", 1.0)
		particle_preview.amount_ratio = clampf(intensity, 0.1, 2.0)

	# Restart particles to show changes
	particle_preview.restart()


func fire_projectile() -> void:
	if not projectile_spawn_point:
		push_warning("[VisualTweakingLab] No projectile spawn point set")
		return

	var scene_path: String = PROJECTILE_SCENES.get(_current_projectile_type, "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("[VisualTweakingLab] Projectile scene not found: %s" % scene_path)
		return

	var scene: PackedScene = load(scene_path)
	var projectile: Node3D = scene.instantiate()

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = projectile_spawn_point.global_position
	projectile.global_rotation = projectile_spawn_point.global_rotation

	# Apply velocity if it has one
	if projectile is RigidBody3D:
		var forward: Vector3 = -projectile_spawn_point.global_transform.basis.z
		projectile.linear_velocity = forward * 20.0

	projectile_fired.emit(projectile)


func cycle_projectile_type() -> void:
	var types: Array = PROJECTILE_SCENES.keys()
	var current_idx: int = types.find(_current_projectile_type)
	var next_idx: int = (current_idx + 1) % types.size()
	_current_projectile_type = types[next_idx]
	_update_status("Projectile: %s" % _current_projectile_type.capitalize())


func reload_config() -> void:
	_update_status("Reloading configs...")

	if GameManager.get_core_system("config"):
		GameManager.get_core_system("config").reload_configs()
	else:
		_update_status('ERROR: GameManager.get_core_system("config") not found')


func respawn_enemy() -> void:
	_spawn_preview_enemy()
	_update_status("Enemy respawned")


func _on_reload_button_pressed(body: Node3D) -> void:
	if body.is_in_group("player"):
		reload_config()


func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text

	if GameManager and GameManager.get_core_system("logger"):
		GameManager.get_core_system("logger").info(
			"[VisualTweakingLab] %s" % text, "VisualTweakingLab"
		)


func _flash_reload_feedback() -> void:
	if not status_label:
		return

	# Flash the label green briefly
	var original_color: Color = status_label.modulate
	status_label.modulate = Color.GREEN

	await get_tree().create_timer(0.5).timeout

	if is_instance_valid(status_label):
		status_label.modulate = original_color


## Get current state for debugging


func get_lab_state() -> Dictionary:
	return {
		"has_enemy": is_instance_valid(_preview_enemy),
		"projectile_type": _current_projectile_type,
		"particle_active": particle_preview.emitting if particle_preview else false
	}
