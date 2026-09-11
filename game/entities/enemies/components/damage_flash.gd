extends Node
class_name DamageFlash

signal flash_started
signal flash_ended

@export var flash_color: Color = Color(1.0, 0.2, 0.2)
@export var flash_duration: float = 0.15
@export var use_tween: bool = true

var sprite_manager: Node = null
var original_modulate: Color = Color.WHITE
var is_flashing: bool = false
var flash_tween: Tween = null


func _ready() -> void:
	# Find sprite manager
	var parent_node: Node = get_parent()
	if parent_node.has_node("SpriteManager"):
		sprite_manager = parent_node.get_node("SpriteManager")


## Trigger damage flash effect - can be called via RPC for sync

@rpc("authority", "call_local", "reliable")
func trigger_flash() -> void:
	if is_flashing:
		return

	if not sprite_manager:
		# Try to find mesh instance directly
		_flash_mesh_directly()
		return

	# Get the sprite to flash
	var sprite: Node3D = _get_current_sprite()
	if not sprite:
		return

	is_flashing = true
	flash_started.emit()

	# Store original color
	if sprite is Sprite3D:
		original_modulate = sprite.modulate
	elif sprite is MeshInstance3D:
		var material: Material = sprite.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var std_mat: StandardMaterial3D = material as StandardMaterial3D
			original_modulate = std_mat.albedo_color

	if use_tween:
		_flash_with_tween(sprite)
	else:
		_flash_with_timer(sprite)


func _flash_with_tween(sprite: Node3D) -> void:
	## Flash using tween for smooth transition
	if flash_tween:
		flash_tween.kill()

	flash_tween = create_tween()

	# Flash to color
	_apply_flash_color(sprite, flash_color)

	# Return to normal after duration
	flash_tween.tween_interval(flash_duration)
	flash_tween.tween_callback(
		func() -> void:
			_apply_flash_color(sprite, original_modulate)
			is_flashing = false
			flash_ended.emit()
	)


func _flash_with_timer(sprite: Node3D) -> void:
	## Flash using timer (simpler method)
	_apply_flash_color(sprite, flash_color)

	await get_tree().create_timer(flash_duration).timeout
	_apply_flash_color(sprite, original_modulate)
	is_flashing = false
	flash_ended.emit()


func _flash_mesh_directly() -> void:
	## Flash mesh when no sprite manager exists
	var parent_node: Node = get_parent()
	var mesh: MeshInstance3D = parent_node.get_node_or_null("MeshInstance3D")
	if not mesh:
		return

	is_flashing = true
	flash_started.emit()

	var material: Material = mesh.get_surface_override_material(0)
	if not material:
		material = mesh.mesh.surface_get_material(0) if mesh.mesh else null

	if material and material is StandardMaterial3D:
		var std_mat: StandardMaterial3D = material as StandardMaterial3D
		original_modulate = std_mat.albedo_color
		std_mat.albedo_color = flash_color

		await get_tree().create_timer(flash_duration).timeout
		std_mat.albedo_color = original_modulate

	is_flashing = false
	flash_ended.emit()


func _get_current_sprite() -> Node3D:
	## Get the current sprite from sprite manager
	if not sprite_manager:
		return null

	# Try to get current sprite
	if sprite_manager.has_method("get_current_sprite"):
		return sprite_manager.get_current_sprite()

	# Fallback: find first Sprite3D or MeshInstance3D child
	for child: Node in sprite_manager.get_children():
		if child is Sprite3D or child is MeshInstance3D:
			return child

	return null


func _apply_flash_color(sprite: Node3D, color: Color) -> void:
	## Apply color to sprite
	if not sprite:
		return

	if sprite is Sprite3D:
		sprite.modulate = color
	elif sprite is MeshInstance3D:
		var material: Material = sprite.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var std_mat: StandardMaterial3D = material as StandardMaterial3D
			std_mat.albedo_color = color


## Set flash color dynamically


func set_flash_color(color: Color) -> void:
	flash_color = color


## Set flash duration dynamically


func set_flash_duration(duration: float) -> void:
	flash_duration = max(0.01, duration)
