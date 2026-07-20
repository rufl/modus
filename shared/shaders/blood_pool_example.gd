extends Node3D

## Example script showing how to integrate blood pools with gameplay
## This demonstrates spawning blood from character movement and combat

@export var blood_pool_manager: BloodPoolManager
@export var spawn_on_click: bool = true

var last_position: Vector3
var is_tracking: bool = false


func _ready() -> void:
	# Setup blood pool manager if not assigned
	if not blood_pool_manager:
		blood_pool_manager = get_node_or_null("BloodPoolManager")

	# Generate blood texture if needed
	_setup_blood_textures()


func _setup_blood_textures() -> void:
	# Find all blood pools and assign textures if they don't have one
	var pools: Array[Node] = get_tree().get_nodes_in_group("blood_pool")
	for pool in pools:
		if pool is BloodPool:
			var mat: ShaderMaterial = pool.get_active_material(0)
			if mat and not mat.get_shader_parameter("blood_texture"):
				var blood_tex: Texture2D = BloodTextureGenerator.create_blood_gradient_texture(256)
				mat.set_shader_parameter("blood_texture", blood_tex)


func _input(event: InputEvent) -> void:
	if not spawn_on_click:
		return

	# Click to spawn blood
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var from: Vector3 = camera.project_ray_origin(event.position)
			var to: Vector3 = from + camera.project_ray_normal(event.position) * 100.0

			var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
			var result: Dictionary = space_state.intersect_ray(query)

			if result:
				spawn_blood_at(result.position)

	# Hold right mouse to create trail
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_tracking = true
			last_position = _get_mouse_world_position()
		else:
			is_tracking = false


func _process(_delta: float) -> void:
	if is_tracking:
		var current_pos: Vector3 = _get_mouse_world_position()
		if current_pos != Vector3.ZERO and last_position != Vector3.ZERO:
			if current_pos.distance_to(last_position) > 0.1:
				blood_pool_manager.spawn_blood_trail(last_position, current_pos, 3)
				last_position = current_pos


func _get_mouse_world_position() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 100.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = space_state.intersect_ray(query)

	return result.position if result else Vector3.ZERO


## Spawn blood at a specific world position
func spawn_blood_at(position: Vector3) -> void:
	if blood_pool_manager:
		blood_pool_manager.spawn_blood_at_world_position(position)


## Spawn blood trail (e.g., from character movement)
func spawn_blood_trail_from_to(start: Vector3, end: Vector3, density: int = 5) -> void:
	if blood_pool_manager:
		blood_pool_manager.spawn_blood_trail(start, end, density)


## Spawn blood splatter (e.g., from bullet impact)
func spawn_blood_splatter_at(position: Vector3, intensity: float = 1.0) -> void:
	if blood_pool_manager:
		var radius: float = 0.3 + (intensity * 0.5)
		var drops: int = int(5 + (intensity * 10))
		blood_pool_manager.spawn_blood_splatter(position, radius, drops)


## Example: Character bleeding while moving
func simulate_bleeding_character(
	character_position: Vector3, velocity: Vector3, delta: float
) -> void:
	# Spawn blood based on movement speed
	var speed: float = velocity.length()
	if speed > 0.1:
		# More blood when moving faster
		var spawn_chance: float = min(speed * delta * 2.0, 1.0)
		if randf() < spawn_chance:
			spawn_blood_at(character_position)


## Example: Blood from weapon hit
func on_weapon_hit(hit_position: Vector3, damage: float) -> void:
	# Spawn blood splatter based on damage
	var intensity: float = clamp(damage / 50.0, 0.5, 2.0)
	spawn_blood_splatter_at(hit_position, intensity)
