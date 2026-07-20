extends SceneTree

## Professional Showcase Map Generator V2
## Features: Proper isolation, working mechanics, vertical gameplay, multiple rooms

const ENEMY_SCENE_PATH: String = "res://game/entities/enemies/enemy.tscn"
const TELEPORTER_ACTOR_PATH = "res://shared/editor_core/actors/teleporter_actor.gd"
const JUMP_PAD_ACTOR_PATH = "res://shared/editor_core/actors/jump_pad_actor.gd"
const HAZARD_VOLUME_ACTOR_PATH = "res://shared/editor_core/actors/hazard_volume_actor.gd"
const PICKUP_SPAWNER_ACTOR_PATH = "res://shared/editor_core/actors/pickup_spawner_actor.gd"
const PLATFORM_ACTOR_PATH = "res://shared/editor_core/actors/platform_actor.gd"
const SWITCH_ACTOR_PATH = "res://shared/editor_core/actors/switch_actor.gd"
const DOOR_ACTOR_PATH = "res://shared/editor_core/actors/door_actor.gd"
const SECRET_WALL_ACTOR_PATH = "res://shared/editor_core/actors/secret_wall_actor.gd"
const COLLAPSABLE_FLOOR_ACTOR_PATH = "res://shared/editor_core/actors/collapsable_floor_actor.gd"
const SPIKE_ACTOR_PATH = "res://shared/editor_core/actors/spike_actor.gd"
const TIMER_ACTOR_PATH = "res://shared/editor_core/actors/timer_actor.gd"
const TRIGGER_ZONE_ACTOR_PATH = "res://shared/editor_core/actors/trigger_zone_actor.gd"
const COUNTER_ACTOR_PATH = "res://shared/editor_core/actors/counter_actor.gd"
const ENEMY_SPAWNER_ACTOR_PATH = "res://shared/editor_core/actors/enemy_spawner_actor.gd"
const WEATHER_CONTROLLER_PATH = "res://game/world/actors/weather/weather_controller.tscn"
const ENV_VOLUME_PATH = "res://game/world/actors/volumes/environment_volume.tscn"
const LIQUID_WATER_MAT = "res://game/art/materials/liquids/retro_water.tres"
const LIQUID_LAVA_MAT = "res://game/art/materials/liquids/retro_lava.tres"
const LIQUID_POISON_MAT = "res://game/art/materials/liquids/retro_poison.tres"
const LIQUID_BLOOD_MAT = "res://game/art/materials/liquids/retro_blood.tres"
const TEXTURE_WALL = "res://shared/editor_core/textures/retro/wall_concrete_01.png"
const TEXTURE_METAL = "res://shared/editor_core/textures/retro/wall_metal_01.png"
const TEXTURE_FLOOR = "res://shared/editor_core/textures/retro/floor_tile_01.png"
const TEXTURE_GRATING = "res://shared/editor_core/textures/retro/floor_grating_01.png"
const WORLD_SCRIPT_PATH: String = "res://game/world/world.gd"
const HUD_SCENE_PATH: String = "res://game/ui/hud/progression_hud.tscn"


func _init() -> void:
	print("Generating Professional Showcase Level V2...")
	_generate()


func _generate() -> void:
	var level_root: Node = Node.new()
	level_root.name = "ShowcaseWorld"

	# Set script path directly (works better in headless mode)
	level_root.set_script(load(WORLD_SCRIPT_PATH))

	# MultiplayerSpawner
	var spawner: MultiplayerSpawner = MultiplayerSpawner.new()
	spawner.name = "MultiplayerSpawner"
	spawner.spawn_path = NodePath("..")
	level_root.add_child(spawner)
	spawner.owner = level_root

	# Environment
	_create_environment(level_root)

	# Navigation Region
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	level_root.add_child(nav_region)
	nav_region.owner = level_root

	# CSG Map Geometry
	var csg_root: CSGCombiner3D = CSGCombiner3D.new()
	csg_root.name = "map"
	csg_root.use_collision = true
	nav_region.add_child(csg_root)
	csg_root.owner = level_root

	# Build the complete map
	_build_complete_map(csg_root, level_root)

	# Player Spawn
	var spawn: Marker3D = Marker3D.new()
	spawn.name = "PlayerSpawn_01"
	spawn.position = Vector3(0, 1, 0)
	spawn.add_to_group("player_spawn")
	level_root.add_child(spawn)
	spawn.owner = level_root

	# HUD
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "GameHUD"
	level_root.add_child(hud_layer)
	hud_layer.owner = level_root

	if ResourceLoader.exists(HUD_SCENE_PATH):
		var hud_inst: Control = load(HUD_SCENE_PATH).instantiate()
		hud_inst.name = "ProgressionHUD"
		hud_layer.add_child(hud_inst)
		hud_inst.owner = level_root

	# Save
	var packed: PackedScene = PackedScene.new()
	if packed.pack(level_root) == OK:
		if ResourceSaver.save(packed, "res://game/world/maps/showcase.tscn") == OK:
			print("Success: Generated res://game/world/maps/showcase.tscn")

	quit()


func _create_environment(level_root: Node) -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.add_to_group("world_environment")

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY

	# Create sky with scrolling clouds (Quake-style)
	var sky: Sky = Sky.new()

	# Create cloud noise texture
	var cloud_noise := NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.01
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	cloud_noise.noise = noise
	cloud_noise.width = 512
	cloud_noise.height = 512
	cloud_noise.seamless = true

	# Use ProceduralSkyMaterial (GLES3 compatible)
	# Sky shaders are not supported in gl_compatibility renderer
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.385, 0.454, 0.55)
	sky_mat.sky_horizon_color = Color(0.646, 0.656, 0.67)
	sky_mat.ground_horizon_color = Color(0.646, 0.656, 0.67)
	sky_mat.ground_bottom_color = Color(0.2, 0.169, 0.133)
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.15

	# Add cloud texture to sky
	sky_mat.sky_cover = cloud_noise
	sky_mat.sky_cover_modulate = Color(1.0, 1.0, 1.0, 0.4)  # Semi-transparent clouds

	sky_mat.use_debanding = true
	sky.sky_material = sky_mat

	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# Simple atmospheric fog (no volumetric)
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.8)
	env.fog_light_energy = 0.8
	env.fog_sun_scatter = 0.15
	env.fog_density = 0.0005
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.6
	env.fog_height = 0.0
	env.fog_height_density = 0.0

	# Volumetric fog explicitly disabled
	env.volumetric_fog_enabled = false

	# Ambient light
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.3

	world_env.environment = env
	level_root.add_child(world_env)
	world_env.owner = level_root

	# Directional light (sun)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.position = Vector3(10, 20, 10)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 100.0
	level_root.add_child(sun)
	sun.owner = level_root

	# Weather Controller
	if ResourceLoader.exists(WEATHER_CONTROLLER_PATH):
		var weather: Node = load(WEATHER_CONTROLLER_PATH).instantiate()
		weather.name = "WeatherController"
		weather.add_to_group("weather_controller")
		level_root.add_child(weather)
		weather.owner = level_root


func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img: Image = Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null


func _build_complete_map(csg_root: CSGCombiner3D, owner_node: Node) -> void:
	# Materials
	var mat_floor := _create_material(TEXTURE_FLOOR)
	var mat_wall := _create_material(TEXTURE_WALL)
	var mat_metal := _create_material(TEXTURE_METAL)
	var mat_grating := _create_material(TEXTURE_GRATING)

	# ROOM 1: Spawn/Lobby (0, 0, 0)
	_build_room_lobby(csg_root, owner_node, Vector3.ZERO, mat_floor, mat_wall)

	# OUTDOOR COURTYARD: Central outdoor area (0, 0, 15) - NO CEILING
	_build_outdoor_courtyard(
		csg_root, owner_node, Vector3(0, 0, 15), mat_floor, mat_wall, mat_metal
	)

	# ROOM 2: Weapon Gallery (30, 0, 0) - Connected via corridor
	_build_corridor(csg_root, owner_node, Vector3(15, 0, 0), Vector3(10, 1, 6), mat_floor, mat_wall)
	_build_room_weapon_gallery(csg_root, owner_node, Vector3(30, 0, 0), mat_floor, mat_wall)

	# ROOM 3: Vertical Arena (0, 0, 30) - OPEN TOP for skybox view
	_build_corridor(
		csg_root, owner_node, Vector3(0, 0, 22.5), Vector3(6, 1, 5), mat_floor, mat_wall
	)
	_build_room_vertical_arena_open(
		csg_root, owner_node, Vector3(0, 0, 30), mat_floor, mat_wall, mat_metal
	)

	# ROOFTOP ACCESS: Elevated platform (0, 10, 0) - NO CEILING
	_build_rooftop_platform(csg_root, owner_node, Vector3(0, 10, 0), mat_metal, mat_wall)

	# ROOM 4: Hazard Zone (-30, 0, 0) - Connected via corridor
	_build_corridor(
		csg_root, owner_node, Vector3(-15, 0, 0), Vector3(10, 1, 6), mat_floor, mat_wall
	)
	_build_room_hazard_zone(csg_root, owner_node, Vector3(-30, 0, 0), mat_grating, mat_wall)

	# ROOM 5: Monster Zoo (0, 0, -30) - GLASS CEILING for sky view
	_build_corridor(
		csg_root, owner_node, Vector3(0, 0, -15), Vector3(6, 1, 10), mat_floor, mat_wall
	)
	_build_room_monster_zoo_glass(csg_root, owner_node, Vector3(0, 0, -30), mat_floor, mat_wall)

	# Add interactive elements
	_add_teleporters(owner_node)
	_add_jump_pads(owner_node)
	_add_elevators(owner_node, csg_root, mat_metal)
	_add_climbing_elements(owner_node, csg_root, mat_metal)
	_add_switches_and_buttons(owner_node)
	_add_doors_and_secrets(owner_node, csg_root, mat_wall)
	_add_traps_and_hazards(owner_node, csg_root)
	_add_liquid_surfaces(owner_node, csg_root)
	_add_timers_and_triggers(owner_node)
	_add_weather_zones(owner_node)
	_add_pickups(owner_node)
	_add_enemy_spawners(owner_node)
	_add_enemies(owner_node)


func _create_material(texture_path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _load_texture(texture_path)
	mat.uv1_triplanar = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _build_room_lobby(
	csg: CSGCombiner3D, owner: Node, center: Vector3, mat_floor: Material, mat_wall: Material
) -> void:
	# Floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(20, 1, 20), mat_floor)

	# Walls with openings for corridors (4 exits: North, South, East, West)
	# North wall (back) - opening for Arena corridor
	_add_box(csg, owner, center + Vector3(-7, 2.5, 10), Vector3(6, 5, 1), mat_wall)  # Left part
	_add_box(csg, owner, center + Vector3(7, 2.5, 10), Vector3(6, 5, 1), mat_wall)  # Right part

	# South wall (front) - opening for Zoo corridor
	_add_box(csg, owner, center + Vector3(-7, 2.5, -10), Vector3(6, 5, 1), mat_wall)  # Left part
	_add_box(csg, owner, center + Vector3(7, 2.5, -10), Vector3(6, 5, 1), mat_wall)  # Right part

	# East wall (right) - opening for Weapon Gallery corridor
	_add_box(csg, owner, center + Vector3(10, 2.5, -7), Vector3(1, 5, 6), mat_wall)  # Front part
	_add_box(csg, owner, center + Vector3(10, 2.5, 7), Vector3(1, 5, 6), mat_wall)  # Back part

	# West wall (left) - opening for Hazard Zone corridor
	_add_box(csg, owner, center + Vector3(-10, 2.5, -7), Vector3(1, 5, 6), mat_wall)  # Front part
	_add_box(csg, owner, center + Vector3(-10, 2.5, 7), Vector3(1, 5, 6), mat_wall)  # Back part

	# Ceiling
	_add_box(csg, owner, center + Vector3(0, 5.5, 0), Vector3(20, 1, 20), mat_wall)


func _build_corridor(
	csg: CSGCombiner3D,
	owner: Node,
	center: Vector3,
	size: Vector3,
	mat_floor: Material,
	mat_wall: Material
) -> void:
	# Floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), size, mat_floor)
	# Walls
	var is_horizontal := size.x > size.z
	if is_horizontal:
		_add_box(csg, owner, center + Vector3(0, 2.5, size.z / 2), Vector3(size.x, 5, 1), mat_wall)
		_add_box(csg, owner, center + Vector3(0, 2.5, -size.z / 2), Vector3(size.x, 5, 1), mat_wall)
	else:
		_add_box(csg, owner, center + Vector3(size.x / 2, 2.5, 0), Vector3(1, 5, size.z), mat_wall)
		_add_box(csg, owner, center + Vector3(-size.x / 2, 2.5, 0), Vector3(1, 5, size.z), mat_wall)
	# Ceiling
	_add_box(csg, owner, center + Vector3(0, 5.5, 0), size + Vector3(0, 1, 0), mat_wall)


func _build_room_weapon_gallery(
	csg: CSGCombiner3D, owner: Node, center: Vector3, mat_floor: Material, mat_wall: Material
) -> void:
	# Floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(25, 1, 20), mat_floor)

	# Walls with opening on west side for corridor from lobby
	_add_box(csg, owner, center + Vector3(0, 2.5, 10), Vector3(25, 5, 1), mat_wall)  # North
	_add_box(csg, owner, center + Vector3(0, 2.5, -10), Vector3(25, 5, 1), mat_wall)  # South
	_add_box(csg, owner, center + Vector3(12.5, 2.5, 0), Vector3(1, 5, 20), mat_wall)  # East

	# West wall with opening for corridor (split into two parts)
	_add_box(csg, owner, center + Vector3(-12.5, 2.5, -7), Vector3(1, 5, 6), mat_wall)  # South part
	_add_box(csg, owner, center + Vector3(-12.5, 2.5, 7), Vector3(1, 5, 6), mat_wall)  # North part

	# Ceiling
	_add_box(csg, owner, center + Vector3(0, 5.5, 0), Vector3(25, 1, 20), mat_wall)


func _build_room_vertical_arena(
	csg: CSGCombiner3D,
	owner: Node,
	center: Vector3,
	mat_floor: Material,
	mat_wall: Material,
	mat_metal: Material
) -> void:
	# Ground floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(20, 1, 20), mat_floor)
	# Walls
	_add_box(csg, owner, center + Vector3(0, 7.5, 10), Vector3(20, 15, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(0, 7.5, -10), Vector3(20, 15, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(10, 7.5, 0), Vector3(1, 15, 20), mat_wall)
	_add_box(csg, owner, center + Vector3(-10, 7.5, 0), Vector3(1, 15, 20), mat_wall)
	# Ceiling
	_add_box(csg, owner, center + Vector3(0, 15.5, 0), Vector3(20, 1, 20), mat_wall)

	# Platforms at different heights
	_add_box(csg, owner, center + Vector3(-5, 3.5, -5), Vector3(6, 1, 6), mat_metal)
	_add_box(csg, owner, center + Vector3(5, 6.5, 5), Vector3(6, 1, 6), mat_metal)
	_add_box(csg, owner, center + Vector3(0, 9.5, 0), Vector3(6, 1, 6), mat_metal)


func _build_room_vertical_arena_open(
	csg: CSGCombiner3D,
	owner: Node,
	center: Vector3,
	mat_floor: Material,
	mat_wall: Material,
	mat_metal: Material
) -> void:
	# Ground floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(20, 1, 20), mat_floor)

	# Walls (tall for open-top arena) with opening on south side for corridor
	_add_box(csg, owner, center + Vector3(0, 7.5, 10), Vector3(20, 15, 1), mat_wall)  # North
	_add_box(csg, owner, center + Vector3(10, 7.5, 0), Vector3(1, 15, 20), mat_wall)  # East
	_add_box(csg, owner, center + Vector3(-10, 7.5, 0), Vector3(1, 15, 20), mat_wall)  # West

	# South wall with opening for corridor (split into two parts)
	_add_box(csg, owner, center + Vector3(-7, 7.5, -10), Vector3(6, 15, 1), mat_wall)  # West part
	_add_box(csg, owner, center + Vector3(7, 7.5, -10), Vector3(6, 15, 1), mat_wall)  # East part

	# NO CEILING - Open to sky for skybox view

	# Platforms at different heights
	_add_box(csg, owner, center + Vector3(-5, 3.5, -5), Vector3(6, 1, 6), mat_metal)
	_add_box(csg, owner, center + Vector3(5, 6.5, 5), Vector3(6, 1, 6), mat_metal)
	_add_box(csg, owner, center + Vector3(0, 9.5, 0), Vector3(6, 1, 6), mat_metal)


func _build_outdoor_courtyard(
	csg: CSGCombiner3D,
	owner: Node,
	center: Vector3,
	mat_floor: Material,
	mat_wall: Material,
	mat_metal: Material
) -> void:
	# Large outdoor floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(25, 1, 15), mat_floor)

	# Low perimeter walls (not full height)
	_add_box(csg, owner, center + Vector3(0, 1, 7.5), Vector3(25, 2, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(0, 1, -7.5), Vector3(25, 2, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(12.5, 1, 0), Vector3(1, 2, 15), mat_wall)
	_add_box(csg, owner, center + Vector3(-12.5, 1, 0), Vector3(1, 2, 15), mat_wall)
	# NO CEILING - Completely open to sky

	# Central fountain/feature
	_add_box(csg, owner, center + Vector3(0, 0.5, 0), Vector3(4, 1, 4), mat_metal)

	# Decorative pillars
	_add_box(csg, owner, center + Vector3(-8, 3, -5), Vector3(1, 6, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(8, 3, -5), Vector3(1, 6, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(-8, 3, 5), Vector3(1, 6, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(8, 3, 5), Vector3(1, 6, 1), mat_wall)


func _build_rooftop_platform(
	csg: CSGCombiner3D, owner: Node, center: Vector3, mat_floor: Material, mat_wall: Material
) -> void:
	# Elevated platform floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(12, 1, 12), mat_floor)

	# Safety railings (low walls)
	_add_box(csg, owner, center + Vector3(0, 0.5, 6), Vector3(12, 1, 0.2), mat_wall)
	_add_box(csg, owner, center + Vector3(0, 0.5, -6), Vector3(12, 1, 0.2), mat_wall)
	_add_box(csg, owner, center + Vector3(6, 0.5, 0), Vector3(0.2, 1, 12), mat_wall)
	_add_box(csg, owner, center + Vector3(-6, 0.5, 0), Vector3(0.2, 1, 12), mat_wall)
	# NO CEILING - Open rooftop

	# Note: Access to rooftop via slipgates/elevators, not stairs


func _build_room_hazard_zone(
	csg: CSGCombiner3D, owner: Node, center: Vector3, mat_floor: Material, mat_wall: Material
) -> void:
	# Floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(20, 1, 20), mat_floor)

	# Walls with opening on east side for corridor from lobby
	_add_box(csg, owner, center + Vector3(0, 2.5, 10), Vector3(20, 5, 1), mat_wall)  # North
	_add_box(csg, owner, center + Vector3(0, 2.5, -10), Vector3(20, 5, 1), mat_wall)  # South
	_add_box(csg, owner, center + Vector3(-10, 2.5, 0), Vector3(1, 5, 20), mat_wall)  # West

	# East wall with opening for corridor (split into two parts)
	_add_box(csg, owner, center + Vector3(10, 2.5, -7), Vector3(1, 5, 6), mat_wall)  # South part
	_add_box(csg, owner, center + Vector3(10, 2.5, 7), Vector3(1, 5, 6), mat_wall)  # North part

	# Ceiling
	_add_box(csg, owner, center + Vector3(0, 5.5, 0), Vector3(20, 1, 20), mat_wall)

	# Hazard pit with BOTTOM
	var pit_center := center + Vector3(0, 0, 5)
	_add_box(csg, owner, pit_center + Vector3(0, -2.5, 0), Vector3(10, 1, 10), mat_floor)  # Bottom
	_add_box(csg, owner, pit_center + Vector3(0, -1, 5), Vector3(10, 2, 1), mat_wall)  # Pit walls
	_add_box(csg, owner, pit_center + Vector3(0, -1, -5), Vector3(10, 2, 1), mat_wall)
	_add_box(csg, owner, pit_center + Vector3(5, -1, 0), Vector3(1, 2, 10), mat_wall)
	_add_box(csg, owner, pit_center + Vector3(-5, -1, 0), Vector3(1, 2, 10), mat_wall)


func _build_room_monster_zoo(
	csg: CSGCombiner3D, owner: Node, center: Vector3, mat_floor: Material, mat_wall: Material
) -> void:
	# Large floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(40, 1, 20), mat_floor)
	# Walls
	_add_box(csg, owner, center + Vector3(0, 2.5, 10), Vector3(40, 5, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(0, 2.5, -10), Vector3(40, 5, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(20, 2.5, 0), Vector3(1, 5, 20), mat_wall)
	_add_box(csg, owner, center + Vector3(-20, 2.5, 0), Vector3(1, 5, 20), mat_wall)
	# Ceiling
	_add_box(csg, owner, center + Vector3(0, 5.5, 0), Vector3(40, 1, 20), mat_wall)


func _build_room_monster_zoo_glass(
	csg: CSGCombiner3D, owner: Node, center: Vector3, mat_floor: Material, mat_wall: Material
) -> void:
	# Large floor
	_add_box(csg, owner, center + Vector3(0, -0.5, 0), Vector3(40, 1, 20), mat_floor)

	# Walls with opening on north side for corridor from lobby
	_add_box(csg, owner, center + Vector3(0, 2.5, -10), Vector3(40, 5, 1), mat_wall)  # South
	_add_box(csg, owner, center + Vector3(20, 2.5, 0), Vector3(1, 5, 20), mat_wall)  # East
	_add_box(csg, owner, center + Vector3(-20, 2.5, 0), Vector3(1, 5, 20), mat_wall)  # West

	# North wall with opening for corridor (split into two parts)
	_add_box(csg, owner, center + Vector3(-7, 2.5, 10), Vector3(26, 5, 1), mat_wall)  # West part
	_add_box(csg, owner, center + Vector3(7, 2.5, 10), Vector3(26, 5, 1), mat_wall)  # East part

	# Glass ceiling (semi-transparent) - using regular material for now
	_add_box(csg, owner, center + Vector3(0, 5.5, 0), Vector3(40, 1, 20), mat_wall)
	_add_box(csg, owner, center + Vector3(0, 2.5, 10), Vector3(40, 5, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(0, 2.5, -10), Vector3(40, 5, 1), mat_wall)
	_add_box(csg, owner, center + Vector3(20, 2.5, 0), Vector3(1, 5, 20), mat_wall)
	_add_box(csg, owner, center + Vector3(-20, 2.5, 0), Vector3(1, 5, 20), mat_wall)

	# Glass ceiling (transparent material for sky view)
	var glass_ceiling := CSGBox3D.new()
	glass_ceiling.name = "GlassCeiling_Zoo"
	glass_ceiling.size = Vector3(40, 0.2, 20)
	glass_ceiling.position = center + Vector3(0, 5.5, 0)

	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.7, 0.8, 0.9, 0.3)  # Light blue tint, mostly transparent
	glass_mat.metallic = 0.1
	glass_mat.roughness = 0.1
	glass_mat.refraction_enabled = true
	glass_mat.refraction_scale = 0.05

	glass_ceiling.material = glass_mat
	glass_ceiling.set_meta("level_editor_placed", true)
	csg.add_child(glass_ceiling)
	glass_ceiling.owner = owner


func _add_box(csg: CSGCombiner3D, owner: Node, pos: Vector3, size: Vector3, mat: Material) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.position = pos
	box.material = mat
	box.set_meta("level_editor_placed", true)
	csg.add_child(box)
	box.owner = owner


func _add_teleporters(owner: Node) -> void:
	# Slipgate pair 1: Lobby <-> Vertical Arena (top platform)
	var tel1: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	tel1.name = "Slipgate_Lobby"
	tel1.position = Vector3(5, 0.5, 5)
	tel1.set("target_teleporter_name", "Slipgate_Arena_Top")
	owner.add_child(tel1)
	tel1.owner = owner

	var tel2: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	tel2.name = "Slipgate_Arena_Top"
	tel2.position = Vector3(0, 10, 30)
	tel2.set("target_teleporter_name", "Slipgate_Lobby")
	owner.add_child(tel2)
	tel2.owner = owner

	# Slipgate pair 2: Weapon Gallery <-> Monster Zoo
	var tel3: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	tel3.name = "Slipgate_Weapons"
	tel3.position = Vector3(35, 0.5, 5)
	tel3.set("target_teleporter_name", "Slipgate_Zoo")
	owner.add_child(tel3)
	tel3.owner = owner

	var tel4: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	tel4.name = "Slipgate_Zoo"
	tel4.position = Vector3(10, 0.5, -30)
	tel4.set("target_teleporter_name", "Slipgate_Weapons")
	owner.add_child(tel4)
	tel4.owner = owner

	# Slipgate pair 3: Hazard Zone <-> Arena Ground
	var tel5: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	tel5.name = "Slipgate_Hazard"
	tel5.position = Vector3(-25, 0.5, -5)
	tel5.set("target_teleporter_name", "Slipgate_Arena_Ground")
	owner.add_child(tel5)
	tel5.owner = owner

	var tel6: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	tel6.name = "Slipgate_Arena_Ground"
	tel6.position = Vector3(-7, 0.5, 35)
	tel6.set("target_teleporter_name", "Slipgate_Hazard")
	owner.add_child(tel6)
	tel6.owner = owner


func _add_jump_pads(owner: Node) -> void:
	# Jump pad in vertical arena (ground to first platform)
	var jump1: Node3D = (load(JUMP_PAD_ACTOR_PATH) as GDScript).new()
	jump1.name = "JumpPad_Arena_1"
	jump1.position = Vector3(-5, 0.5, 25)
	jump1.set("launch_velocity", 15.0)
	owner.add_child(jump1)
	jump1.owner = owner

	# Jump pad to second platform
	var jump2: Node3D = (load(JUMP_PAD_ACTOR_PATH) as GDScript).new()
	jump2.name = "JumpPad_Arena_2"
	jump2.position = Vector3(-5, 4, 25)
	jump2.set("launch_velocity", 12.0)
	owner.add_child(jump2)
	jump2.owner = owner


func _add_hazards(owner: Node, _csg: CSGCombiner3D) -> void:
	# Lava hazard in hazard zone pit
	var haz: Node3D = (load(HAZARD_VOLUME_ACTOR_PATH) as GDScript).new()
	haz.name = "Hazard_Lava_Pit"
	haz.position = Vector3(-30, -1.5, 5)
	haz.set("hazard_type", 0)  # LAVA
	haz.set("volume_size", Vector3(9, 1, 9))
	owner.add_child(haz)
	haz.owner = owner


func _add_pickups(owner: Node) -> void:
	# Weapon spawners in weapon gallery (only supported weapons)
	var weapons: Array = ["shotgun", "rocket_launcher"]
	for i in range(weapons.size()):
		var spawner: Node3D = (load(PICKUP_SPAWNER_ACTOR_PATH) as GDScript).new()
		spawner.name = "WeaponSpawner_" + weapons[i]
		spawner.position = Vector3(30 + (i * 8) - 4, 0.5, 0)
		spawner.set("pickup_category", 3)  # WEAPON
		spawner.set("weapon_id", weapons[i])
		owner.add_child(spawner)
		spawner.owner = owner

	# Health pickups in lobby
	for i in range(3):
		var spawner: Node3D = (load(PICKUP_SPAWNER_ACTOR_PATH) as GDScript).new()
		spawner.name = "HealthSpawner_%d" % i
		spawner.position = Vector3(-5 + (i * 3), 0.5, -5)
		spawner.set("pickup_category", 0)  # HEALTH
		owner.add_child(spawner)
		spawner.owner = owner


func _add_enemies(owner: Node) -> void:
	# Monster zoo
	var roster: Array = [
		"bot_crash",
		"bot_sarge",
		"bot_doom",
		"bot_hunter",
		"grunt_basic",
		"imp",
		"swarmling",
		"healer"
	]

	for i in range(roster.size()):
		var enemy_scn: PackedScene = load(ENEMY_SCENE_PATH)
		if enemy_scn:
			var enemy: Node = enemy_scn.instantiate()
			enemy.name = "Zoo_" + roster[i]
			enemy.position = Vector3(-15 + (i * 4), 1, -30)
			enemy.enemy_id = roster[i]
			enemy.is_ai_active = false
			owner.add_child(enemy)
			enemy.owner = owner

			var label: Label3D = Label3D.new()
			label.text = roster[i]
			label.position = Vector3(0, 2.5, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 20
			enemy.add_child(label)
			label.owner = owner


func _add_elevators(owner: Node, _csg: CSGCombiner3D, _mat_metal: Material) -> void:
	# Elevator 1: Lobby vertical lift
	var elev1: Node3D = (load(PLATFORM_ACTOR_PATH) as GDScript).new()
	elev1.name = "Elevator_Lobby"
	elev1.position = Vector3(-7, 0, -7)
	elev1.set("platform_mode", 2)  # PING_PONG
	elev1.set("platform_size", Vector3(4, 0.5, 4))
	elev1.set("move_speed", 2.5)
	elev1.set("wait_at_points", 2.0)
	elev1.set("waypoints", PackedVector3Array([Vector3.ZERO, Vector3(0, 8, 0)]))
	elev1.set("start_moving", true)
	elev1.set("carry_passengers", true)
	owner.add_child(elev1)
	elev1.owner = owner

	# Elevator 2: Weapon Gallery lift
	var elev2: Node3D = (load(PLATFORM_ACTOR_PATH) as GDScript).new()
	elev2.name = "Elevator_Weapons"
	elev2.position = Vector3(25, 0, -7)
	elev2.set("platform_mode", 2)  # PING_PONG
	elev2.set("platform_size", Vector3(4, 0.5, 4))
	elev2.set("move_speed", 3.0)
	elev2.set("wait_at_points", 1.5)
	elev2.set("waypoints", PackedVector3Array([Vector3.ZERO, Vector3(0, 6, 0)]))
	elev2.set("start_moving", true)
	elev2.set("carry_passengers", true)
	owner.add_child(elev2)
	elev2.owner = owner

	# Elevator 3: Arena express elevator
	var elev3: Node3D = (load(PLATFORM_ACTOR_PATH) as GDScript).new()
	elev3.name = "Elevator_Arena_Express"
	elev3.position = Vector3(7, 0, 30)
	elev3.set("platform_mode", 2)  # PING_PONG
	elev3.set("platform_size", Vector3(4, 0.5, 4))
	elev3.set("move_speed", 4.0)
	elev3.set("wait_at_points", 1.0)
	elev3.set("waypoints", PackedVector3Array([Vector3.ZERO, Vector3(0, 12, 0)]))
	elev3.set("start_moving", true)
	elev3.set("carry_passengers", true)
	owner.add_child(elev3)
	elev3.owner = owner


func _create_elevator_platform(
	csg: CSGCombiner3D, owner: Node, pos: Vector3, size: Vector3, mat: Material
) -> CSGBox3D:
	var platform := CSGBox3D.new()
	platform.name = "ElevatorPlatform_" + str(pos)
	platform.size = size
	platform.position = pos
	platform.material = mat
	platform.use_collision = true
	platform.set_meta("level_editor_placed", true)
	csg.add_child(platform)
	platform.owner = owner
	return platform


func _add_climbing_elements(owner: Node, csg: CSGCombiner3D, mat_metal: Material) -> void:
	# Climbing stairs in vertical arena (ground to first platform)
	_create_stairs(csg, owner, Vector3(-8, 0, 27), 7, 0.5, 1.5, mat_metal)

	# Climbing stairs from first to second platform
	_create_stairs(csg, owner, Vector3(2, 3.5, 32), 6, 0.5, 1.5, mat_metal)

	# Rope/ladder in arena (visual representation with climbable area)
	_create_rope_ladder(owner, Vector3(7, 0.5, 25), 10.0)

	# Spiral stairs in weapon gallery
	_create_spiral_stairs(csg, owner, Vector3(35, 0, -5), 8, mat_metal)

	# Climbing wall with ledges in hazard zone
	_create_climbing_wall(csg, owner, Vector3(-35, 0, 0), mat_metal)


func _create_stairs(
	csg: CSGCombiner3D,
	owner: Node,
	start_pos: Vector3,
	step_count: int,
	step_height: float,
	step_depth: float,
	mat: Material
) -> void:
	for i in range(step_count):
		var step := CSGBox3D.new()
		step.name = "Stair_Step_%d" % i
		step.size = Vector3(3, step_height, step_depth)
		step.position = start_pos + Vector3(0, i * step_height, i * step_depth)
		step.material = mat
		step.set_meta("level_editor_placed", true)
		csg.add_child(step)
		step.owner = owner


func _create_spiral_stairs(
	csg: CSGCombiner3D, owner: Node, center: Vector3, step_count: int, mat: Material
) -> void:
	var radius := 3.0
	var height_per_step := 0.4
	var angle_per_step := TAU / 12.0  # 30 degrees per step

	for i in range(step_count):
		var angle := i * angle_per_step
		var x := center.x + cos(angle) * radius
		var z := center.z + sin(angle) * radius
		var y := center.y + i * height_per_step

		var step := CSGBox3D.new()
		step.name = "Spiral_Step_%d" % i
		step.size = Vector3(2, 0.3, 1.5)
		step.position = Vector3(x, y, z)
		step.rotation.y = angle + PI / 2
		step.material = mat
		step.set_meta("level_editor_placed", true)
		csg.add_child(step)
		step.owner = owner


func _create_rope_ladder(owner: Node, pos: Vector3, height: float) -> void:
	# Create a climbable area marker
	var ladder := Area3D.new()
	ladder.name = "RopeLadder_" + str(pos)
	ladder.position = pos
	ladder.add_to_group("climbable")
	owner.add_child(ladder)
	ladder.owner = owner

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, height, 0.5)
	collision.shape = shape
	collision.position = Vector3(0, height / 2, 0)
	ladder.add_child(collision)
	collision.owner = owner

	# Visual representation with mesh
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, height, 0.1)
	mesh_inst.mesh = mesh
	mesh_inst.position = Vector3(0, height / 2, 0)
	ladder.add_child(mesh_inst)
	mesh_inst.owner = owner

	# Add rungs
	var rung_count := int(height / 0.5)
	for i in range(rung_count):
		var rung := MeshInstance3D.new()
		var rung_mesh := BoxMesh.new()
		rung_mesh.size = Vector3(0.8, 0.05, 0.05)
		rung.mesh = rung_mesh
		rung.position = Vector3(0, i * 0.5, 0)
		ladder.add_child(rung)
		rung.owner = owner


func _create_climbing_wall(csg: CSGCombiner3D, owner: Node, pos: Vector3, mat: Material) -> void:
	# Main wall
	_add_box(csg, owner, pos + Vector3(0, 3, 0), Vector3(1, 6, 8), mat)

	# Ledges at different heights
	var ledge_positions := [
		Vector3(0.5, 1.5, 0), Vector3(0.5, 3.0, 2), Vector3(0.5, 4.5, -2), Vector3(0.5, 6.0, 0)
	]

	for ledge_pos: Vector3 in ledge_positions:
		var ledge := CSGBox3D.new()
		ledge.name = "Climbing_Ledge"
		ledge.size = Vector3(0.8, 0.2, 1.5)
		ledge.position = pos + ledge_pos
		ledge.material = mat
		ledge.set_meta("level_editor_placed", true)
		csg.add_child(ledge)
		ledge.owner = owner

		# Add climbable area marker
		var climb_area := Area3D.new()
		climb_area.name = "ClimbArea"
		climb_area.position = pos + ledge_pos
		climb_area.add_to_group("climbable")
		owner.add_child(climb_area)
		climb_area.owner = owner

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1, 0.5, 2)
		collision.shape = shape
		climb_area.add_child(collision)
		collision.owner = owner


func _add_switches_and_buttons(owner: Node) -> void:
	# Switch 1: Lobby - Controls elevator
	var switch1: Node3D = (load(SWITCH_ACTOR_PATH) as GDScript).new()
	switch1.name = "Switch_Lobby_Elevator"
	switch1.position = Vector3(-5, 1.5, -7)
	switch1.set("switch_type", 0)  # TOGGLE
	switch1.set("target_actor_names", ["Elevator_Lobby"])
	owner.add_child(switch1)
	switch1.owner = owner

	# Switch 2: Weapon Gallery - Controls lights/effects
	var switch2: Node3D = (load(SWITCH_ACTOR_PATH) as GDScript).new()
	switch2.name = "Switch_Weapons"
	switch2.position = Vector3(35, 1.5, 7)
	switch2.set("switch_type", 0)  # TOGGLE
	owner.add_child(switch2)
	switch2.owner = owner

	# Button 1: Arena - Momentary switch for jump pad boost
	var button1: Node3D = (load(SWITCH_ACTOR_PATH) as GDScript).new()
	button1.name = "Button_Arena_Boost"
	button1.position = Vector3(-7, 1.5, 35)
	button1.set("switch_type", 1)  # MOMENTARY
	button1.set("momentary_duration", 2.0)
	owner.add_child(button1)
	button1.owner = owner

	# Button 2: Hazard Zone - Emergency stop for hazards
	var button2: Node3D = (load(SWITCH_ACTOR_PATH) as GDScript).new()
	button2.name = "Button_Hazard_Stop"
	button2.position = Vector3(-25, 1.5, 0)
	button2.set("switch_type", 1)  # MOMENTARY
	button2.set("momentary_duration", 5.0)
	button2.set("target_actor_names", ["Hazard_Lava_Pit"])
	owner.add_child(button2)
	button2.owner = owner

	# Button 3: Monster Zoo - Shootable target
	var button3: Node3D = (load(SWITCH_ACTOR_PATH) as GDScript).new()
	button3.name = "Button_Zoo_Target"
	button3.position = Vector3(-15, 2.5, -25)
	button3.set("switch_type", 0)  # TOGGLE
	owner.add_child(button3)
	button3.owner = owner

	# Hold Switch: Arena top platform
	var hold_switch: Node3D = (load(SWITCH_ACTOR_PATH) as GDScript).new()
	hold_switch.name = "HoldSwitch_Arena_Top"
	hold_switch.position = Vector3(0, 11, 30)
	hold_switch.set("switch_type", 2)  # HOLD
	owner.add_child(hold_switch)
	hold_switch.owner = owner


func _add_weather_zones(owner: Node) -> void:
	# Weather Zone 1: Lobby - Clear weather
	if ResourceLoader.exists(ENV_VOLUME_PATH):
		var zone1: Area3D = load(ENV_VOLUME_PATH).instantiate()
		zone1.name = "WeatherZone_Lobby_Clear"
		zone1.position = Vector3(0, 3, 0)
		zone1.scale = Vector3(20, 6, 20)
		zone1.set("weather_override", 0)  # CLEAR
		zone1.set("debug_color", Color(0.5, 0.8, 1.0, 0.15))
		owner.add_child(zone1)
		zone1.owner = owner

	# Weather Zone 2: Weapon Gallery - Windy
	if ResourceLoader.exists(ENV_VOLUME_PATH):
		var zone2: Area3D = load(ENV_VOLUME_PATH).instantiate()
		zone2.name = "WeatherZone_Weapons_Windy"
		zone2.position = Vector3(30, 3, 0)
		zone2.scale = Vector3(25, 6, 20)
		zone2.set("weather_override", 4)  # WINDY
		zone2.set("enable_wind_zone", true)
		zone2.set("wind_force", Vector3(2, 0, 0))
		zone2.set("wind_turbulence", 0.5)
		zone2.set("debug_color", Color(0.8, 0.8, 0.5, 0.15))
		owner.add_child(zone2)
		zone2.owner = owner

	# Weather Zone 3: Vertical Arena - Storm
	if ResourceLoader.exists(ENV_VOLUME_PATH):
		var zone3: Area3D = load(ENV_VOLUME_PATH).instantiate()
		zone3.name = "WeatherZone_Arena_Storm"
		zone3.position = Vector3(0, 7.5, 30)
		zone3.scale = Vector3(20, 15, 20)
		zone3.set("weather_override", 3)  # STORM
		zone3.set("enable_atmospheric_zone", true)
		zone3.set("atmospheric_density", 0.05)
		zone3.set("fog_color", Color(0.3, 0.3, 0.4))
		zone3.set("debug_color", Color(0.3, 0.3, 0.6, 0.15))
		owner.add_child(zone3)
		zone3.owner = owner

	# Weather Zone 4: Hazard Zone - Rain
	if ResourceLoader.exists(ENV_VOLUME_PATH):
		var zone4: Area3D = load(ENV_VOLUME_PATH).instantiate()
		zone4.name = "WeatherZone_Hazard_Rain"
		zone4.position = Vector3(-30, 3, 0)
		zone4.scale = Vector3(20, 6, 20)
		zone4.set("weather_override", 1)  # RAIN
		zone4.set("enable_atmospheric_zone", true)
		zone4.set("fog_enabled", true)
		zone4.set("fog_color", Color(0.5, 0.5, 0.6))
		zone4.set("debug_color", Color(0.4, 0.5, 0.8, 0.15))
		owner.add_child(zone4)
		zone4.owner = owner

	# Weather Zone 5: Monster Zoo - Snow
	if ResourceLoader.exists(ENV_VOLUME_PATH):
		var zone5: Area3D = load(ENV_VOLUME_PATH).instantiate()
		zone5.name = "WeatherZone_Zoo_Snow"
		zone5.position = Vector3(0, 3, -30)
		zone5.scale = Vector3(40, 6, 20)
		zone5.set("weather_override", 2)  # SNOW
		zone5.set("enable_atmospheric_zone", true)
		zone5.set("atmospheric_color", Color(0.9, 0.9, 1.0))
		zone5.set("fog_color", Color(0.8, 0.8, 0.9))
		zone5.set("debug_color", Color(0.9, 0.9, 1.0, 0.15))
		owner.add_child(zone5)
		zone5.owner = owner


func _add_doors_and_secrets(owner: Node, csg: CSGCombiner3D, mat_wall: Material) -> void:
	# Door 1: Lobby to Weapons corridor
	var door1: Node3D = (load(DOOR_ACTOR_PATH) as GDScript).new()
	door1.name = "Door_Lobby_Weapons"
	door1.position = Vector3(10, 0, 0)
	door1.set("door_size", Vector3(3, 4, 0.3))
	door1.set("open_direction", Vector3(0, 1, 0))  # Slides up
	door1.set("open_speed", 2.0)
	door1.set("auto_close", true)
	door1.set("auto_close_delay", 3.0)
	owner.add_child(door1)
	door1.owner = owner

	# Door 2: Lobby to Arena corridor
	var door2: Node3D = (load(DOOR_ACTOR_PATH) as GDScript).new()
	door2.name = "Door_Lobby_Arena"
	door2.position = Vector3(0, 0, 10)
	door2.set("door_size", Vector3(3, 4, 0.3))
	door2.set("open_direction", Vector3(0, 1, 0))
	door2.set("open_speed", 2.5)
	door2.set("auto_close", false)
	owner.add_child(door2)
	door2.owner = owner

	# Secret Wall 1: Hidden passage in Weapon Gallery
	_add_box(csg, owner, Vector3(38, 2.5, 0), Vector3(1, 5, 4), mat_wall)
	var secret1: Node3D = (load(SECRET_WALL_ACTOR_PATH) as GDScript).new()
	secret1.name = "SecretWall_Weapons"
	secret1.position = Vector3(38, 2.5, 0)
	secret1.set("wall_size", Vector3(1, 5, 4))
	secret1.set("reveal_method", 0)  # PUSH
	secret1.set("move_direction", Vector3(1, 0, 0))
	secret1.set("move_distance", 2.0)
	owner.add_child(secret1)
	secret1.owner = owner

	# Secret Wall 2: Shootable secret in Arena
	_add_box(csg, owner, Vector3(-9, 2.5, 30), Vector3(1, 5, 3), mat_wall)
	var secret2: Node3D = (load(SECRET_WALL_ACTOR_PATH) as GDScript).new()
	secret2.name = "SecretWall_Arena_Shootable"
	secret2.position = Vector3(-9, 2.5, 30)
	secret2.set("wall_size", Vector3(1, 5, 3))
	secret2.set("reveal_method", 1)  # SHOOT
	secret2.set("move_direction", Vector3(0, -1, 0))  # Drops down
	secret2.set("move_distance", 5.0)
	owner.add_child(secret2)
	secret2.owner = owner


func _add_traps_and_hazards(owner: Node, _csg: CSGCombiner3D) -> void:
	# Collapsable Floor 1: Arena trap
	var collapse1: Node3D = (load(COLLAPSABLE_FLOOR_ACTOR_PATH) as GDScript).new()
	collapse1.name = "CollapsableFloor_Arena"
	collapse1.position = Vector3(3, 0, 27)
	collapse1.set("floor_size", Vector3(3, 0.2, 3))
	collapse1.set("collapse_delay", 0.5)
	collapse1.set("respawn_time", 5.0)
	owner.add_child(collapse1)
	collapse1.owner = owner

	# Collapsable Floor 2: Hazard zone trap
	var collapse2: Node3D = (load(COLLAPSABLE_FLOOR_ACTOR_PATH) as GDScript).new()
	collapse2.name = "CollapsableFloor_Hazard"
	collapse2.position = Vector3(-30, 0, -3)
	collapse2.set("floor_size", Vector3(4, 0.2, 4))
	collapse2.set("collapse_delay", 1.0)
	collapse2.set("respawn_time", 8.0)
	owner.add_child(collapse2)
	collapse2.owner = owner

	# Spike Trap 1: Timed spikes in corridor
	var spikes1: Node3D = (load(SPIKE_ACTOR_PATH) as GDScript).new()
	spikes1.name = "SpikeTrap_Corridor"
	spikes1.position = Vector3(15, 0, 0)
	spikes1.set("spike_pattern", 0)  # TIMED
	spikes1.set("extend_time", 1.0)
	spikes1.set("retract_time", 2.0)
	spikes1.set("damage_amount", 25.0)
	owner.add_child(spikes1)
	spikes1.owner = owner

	# Spike Trap 2: Triggered spikes in Zoo
	var spikes2: Node3D = (load(SPIKE_ACTOR_PATH) as GDScript).new()
	spikes2.name = "SpikeTrap_Zoo"
	spikes2.position = Vector3(-5, 0, -30)
	spikes2.set("spike_pattern", 1)  # TRIGGERED
	spikes2.set("damage_amount", 30.0)
	owner.add_child(spikes2)
	spikes2.owner = owner

	# Lava hazard (existing)
	var haz: Node3D = (load(HAZARD_VOLUME_ACTOR_PATH) as GDScript).new()
	haz.name = "Hazard_Lava_Pit"
	haz.position = Vector3(-30, -1.5, 5)
	haz.set("hazard_type", 0)  # LAVA
	haz.set("volume_size", Vector3(9, 1, 9))
	owner.add_child(haz)
	haz.owner = owner


func _add_liquid_surfaces(owner: Node, csg: CSGCombiner3D) -> void:
	# Water pool in Lobby
	var water_mesh := CSGBox3D.new()
	water_mesh.name = "WaterPool_Lobby"
	water_mesh.size = Vector3(6, 0.5, 6)
	water_mesh.position = Vector3(-5, 0.25, 5)
	if ResourceLoader.exists(LIQUID_WATER_MAT):
		water_mesh.material = load(LIQUID_WATER_MAT)
	water_mesh.set_meta("level_editor_placed", true)
	csg.add_child(water_mesh)
	water_mesh.owner = owner

	# Lava surface in Hazard Zone
	var lava_mesh := CSGBox3D.new()
	lava_mesh.name = "LavaSurface_Hazard"
	lava_mesh.size = Vector3(9, 0.3, 9)
	lava_mesh.position = Vector3(-30, -1.35, 5)
	if ResourceLoader.exists(LIQUID_LAVA_MAT):
		lava_mesh.material = load(LIQUID_LAVA_MAT)
	lava_mesh.set_meta("level_editor_placed", true)
	csg.add_child(lava_mesh)
	lava_mesh.owner = owner

	# Poison pool in Weapon Gallery
	var poison_mesh := CSGBox3D.new()
	poison_mesh.name = "PoisonPool_Weapons"
	poison_mesh.size = Vector3(4, 0.4, 4)
	poison_mesh.position = Vector3(25, 0.2, 5)
	if ResourceLoader.exists(LIQUID_POISON_MAT):
		poison_mesh.material = load(LIQUID_POISON_MAT)
	poison_mesh.set_meta("level_editor_placed", true)
	csg.add_child(poison_mesh)
	poison_mesh.owner = owner

	# Blood pool in Monster Zoo
	var blood_mesh := CSGBox3D.new()
	blood_mesh.name = "BloodPool_Zoo"
	blood_mesh.size = Vector3(5, 0.2, 5)
	blood_mesh.position = Vector3(5, 0.1, -30)
	if ResourceLoader.exists(LIQUID_BLOOD_MAT):
		blood_mesh.material = load(LIQUID_BLOOD_MAT)
	blood_mesh.set_meta("level_editor_placed", true)
	csg.add_child(blood_mesh)
	blood_mesh.owner = owner


func _add_timers_and_triggers(owner: Node) -> void:
	# Timer 1: Controls spike trap timing
	var timer1: Node3D = (load(TIMER_ACTOR_PATH) as GDScript).new()
	timer1.name = "Timer_SpikeControl"
	timer1.position = Vector3(15, 2, 0)
	timer1.set("duration", 3.0)
	timer1.set("auto_start", true)
	timer1.set("loop", true)
	timer1.set("target_actor_names", ["SpikeTrap_Corridor"])
	owner.add_child(timer1)
	timer1.owner = owner

	# Timer 2: Door auto-close timer
	var timer2: Node3D = (load(TIMER_ACTOR_PATH) as GDScript).new()
	timer2.name = "Timer_DoorClose"
	timer2.position = Vector3(10, 2, 0)
	timer2.set("duration", 5.0)
	timer2.set("auto_start", false)
	timer2.set("loop", false)
	owner.add_child(timer2)
	timer2.owner = owner

	# Trigger Zone 1: Activates door when player enters
	var trigger1: Node3D = (load(TRIGGER_ZONE_ACTOR_PATH) as GDScript).new()
	trigger1.name = "TriggerZone_DoorOpen"
	trigger1.position = Vector3(8, 1, 0)
	trigger1.set("trigger_size", Vector3(4, 3, 4))
	trigger1.set("trigger_once", false)
	trigger1.set("target_actor_names", ["Door_Lobby_Weapons"])
	owner.add_child(trigger1)
	trigger1.owner = owner

	# Trigger Zone 2: Secret area trigger
	var trigger2: Node3D = (load(TRIGGER_ZONE_ACTOR_PATH) as GDScript).new()
	trigger2.name = "TriggerZone_SecretReveal"
	trigger2.position = Vector3(36, 1, 0)
	trigger2.set("trigger_size", Vector3(3, 3, 3))
	trigger2.set("trigger_once", true)
	trigger2.set("target_actor_names", ["SecretWall_Weapons"])
	owner.add_child(trigger2)
	trigger2.owner = owner

	# Counter: Tracks button presses
	var counter: Node3D = (load(COUNTER_ACTOR_PATH) as GDScript).new()
	counter.name = "Counter_ButtonPresses"
	counter.position = Vector3(0, 3, 0)
	counter.set("target_count", 3)
	counter.set("reset_on_complete", false)
	owner.add_child(counter)
	counter.owner = owner


func _add_enemy_spawners(owner: Node) -> void:
	# Enemy Spawner 1: Arena combat spawner
	var spawner1: Node3D = (load(ENEMY_SPAWNER_ACTOR_PATH) as GDScript).new()
	spawner1.name = "EnemySpawner_Arena"
	spawner1.position = Vector3(-5, 1, 35)
	spawner1.set("enemy_types", ["grunt_basic", "imp"])
	spawner1.set("max_enemies", 3)
	spawner1.set("spawn_interval", 5.0)
	spawner1.set("auto_spawn", false)
	owner.add_child(spawner1)
	spawner1.owner = owner

	# Enemy Spawner 2: Hazard zone spawner
	var spawner2: Node3D = (load(ENEMY_SPAWNER_ACTOR_PATH) as GDScript).new()
	spawner2.name = "EnemySpawner_Hazard"
	spawner2.position = Vector3(-35, 1, 0)
	spawner2.set("enemy_types", ["swarmling"])
	spawner2.set("max_enemies", 5)
	spawner2.set("spawn_interval", 3.0)
	spawner2.set("auto_spawn", false)
	owner.add_child(spawner2)
	spawner2.owner = owner
