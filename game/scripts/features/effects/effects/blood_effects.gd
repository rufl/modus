extends Node

## Global blood effects autoload
## Automatically enables blood pools and configures retro effects
## Add to Project Settings > Autoload as "BloodEffects"

var blood_pool_manager: BloodPoolManager = null
var enabled: bool = true
var retro_mode: bool = true  # Enable Quake-style retro effects


func _ready() -> void:
	# Wait for services to initialize
	await get_tree().create_timer(1.0).timeout
	_initialize_blood_system()


func _initialize_blood_system() -> void:
	GameManager.get_core_system("logger").info(
		"[BloodEffects] Initializing blood pool system...", "Core"
	)

	# Get effects service
	var effects_service: Node = GameManager.get_core_system("effects")
	if not effects_service:
		push_warning("[BloodEffects] EffectsService not found, will retry on scene change")
		get_tree().node_added.connect(_on_node_added)
		return

	# Get blood pool manager
	if "blood_pool_manager" in effects_service:
		blood_pool_manager = effects_service.blood_pool_manager

	# Enable blood pools in gore system
	if "gore_system" in effects_service and effects_service.gore_system:
		effects_service.gore_system.enable_blood_pools = true
		effects_service.gore_system.blood_pool_intensity = 1.5
		effects_service.gore_system.blood_trail_enabled = true
		effects_service.gore_system.blood_trail_density = 3
		GameManager.get_core_system("logger").info(
			"[BloodEffects] Blood pools enabled in gore system", "Core"
		)

	# Setup retro effects
	if retro_mode:
		_setup_retro_effects()

	# Auto-setup blood pools in current scene
	_setup_scene_blood_pools()

	GameManager.get_core_system("logger").info(
		"[BloodEffects] Blood pool system initialized!", "Core"
	)


func _on_node_added(node: Node) -> void:
	# Check if effects service was added
	if node.name == "EffectsService":
		get_tree().node_added.disconnect(_on_node_added)
		_initialize_blood_system()


func _setup_retro_effects() -> void:
	GameManager.get_core_system("logger").info(
		"[BloodEffects] Configuring retro/Quake-style effects...", "Core"
	)

	# Find all blood pools and configure for retro look
	await get_tree().process_frame
	var pools: Array[Node] = get_tree().get_nodes_in_group("blood_pool")

	for pool: Node in pools:
		if pool is BloodPool:
			_configure_retro_blood_pool(pool)

	GameManager.get_core_system("logger").info(
		"[BloodEffects] Configured %d blood pool(s) for retro mode" % pools.size(), "Core"
	)


func _configure_retro_blood_pool(pool: BloodPool) -> void:
	var mat: ShaderMaterial = pool.get_active_material(0)
	if not mat:
		return

	# Check if using retro shader
	var shader_path: String = mat.shader.resource_path if mat.shader else ""
	var is_retro_shader: bool = "retro" in shader_path

	# Generate retro blood texture
	var blood_tex: Texture2D = BloodTextureGeneratorRetro.create_quake_style_blood_texture(64)
	mat.set_shader_parameter("blood_texture", blood_tex)

	# Set retro blood color (darker, more saturated)
	mat.set_shader_parameter("blood_color", Color(0.4, 0.0, 0.0))
	mat.set_shader_parameter("blood_merge_factor", 0.3)

	# Configure retro shader parameters if available
	if is_retro_shader:
		mat.set_shader_parameter("enable_pixelation", true)
		mat.set_shader_parameter("pixelation_amount", 8.0)
		mat.set_shader_parameter("enable_color_banding", true)
		mat.set_shader_parameter("color_bands", 8.0)


func _setup_scene_blood_pools() -> void:
	# Auto-setup blood pools when scene changes
	get_tree().node_added.connect(_on_scene_node_added)


func _on_scene_node_added(node: Node) -> void:
	# Check if it's a blood pool
	if node.is_in_group("blood_pool") and node is BloodPool:
		if retro_mode:
			_configure_retro_blood_pool(node)
		else:
			_configure_standard_blood_pool(node)


func _configure_standard_blood_pool(pool: BloodPool) -> void:
	var mat: ShaderMaterial = pool.get_active_material(0)
	if not mat:
		return

	# Generate standard blood texture
	var blood_tex: Texture2D = BloodTextureGenerator.create_blood_gradient_texture(256)
	mat.set_shader_parameter("blood_texture", blood_tex)
	mat.set_shader_parameter("blood_color", Color(0.35, 0.05, 0.05))
	mat.set_shader_parameter("blood_merge_factor", 0.25)


## Spawn blood at a world position
func spawn_blood(position: Vector3) -> bool:
	if not enabled or not blood_pool_manager:
		return false
	return blood_pool_manager.spawn_blood_at_world_position(position)


## Spawn blood trail between two positions
func spawn_trail(start: Vector3, end: Vector3, drops: int = 5) -> void:
	if not enabled or not blood_pool_manager:
		return
	blood_pool_manager.spawn_blood_trail(start, end, drops)


## Spawn blood splatter (multiple drops in radius)
func spawn_splatter(position: Vector3, intensity: float = 1.0) -> void:
	if not enabled or not blood_pool_manager:
		return
	var radius: float = 0.3 + (intensity * 0.5)
	var drops: int = int(5 + (intensity * 10))
	blood_pool_manager.spawn_blood_splatter(position, radius, drops)


## Enable or disable blood effects globally
func set_enabled(value: bool) -> void:
	enabled = value


## Enable or disable retro mode
func set_retro_mode(value: bool) -> void:
	retro_mode = value
	if is_inside_tree():
		_setup_retro_effects()


## Check if blood effects are available
func is_available() -> bool:
	return enabled and blood_pool_manager != null
