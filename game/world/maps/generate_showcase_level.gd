extends SceneTree

const ENEMY_SCENE_PATH: String = "res://game/entities/enemies/enemy.tscn"
const TELEPORTER_ACTOR_PATH = "res://shared/editor_core/actors/teleporter_actor.gd"
const JUMP_PAD_ACTOR_PATH = "res://shared/editor_core/actors/jump_pad_actor.gd"
const HAZARD_VOLUME_ACTOR_PATH = "res://shared/editor_core/actors/hazard_volume_actor.gd"
const PICKUP_SPAWNER_ACTOR_PATH = "res://shared/editor_core/actors/pickup_spawner_actor.gd"
const TEXTURE_WALL = "res://shared/editor_core/textures/retro/wall_concrete_01.png"
const TEXTURE_METAL = "res://shared/editor_core/textures/retro/wall_metal_01.png"
const TEXTURE_FLOOR = "res://shared/editor_core/textures/retro/floor_tile_01.png"
const TEXTURE_GRATING = "res://shared/editor_core/textures/retro/floor_grating_01.png"
const WORLD_SCRIPT_PATH: String = "res://game/world/world.gd"
const HUD_SCENE_PATH: String = "res://game/ui/hud/progression_hud.tscn"
const PAUSE_MENU_PATH: String = "res://game/ui/menus/pause_menu.tscn"  # If exists


func _init() -> void:
	GameManager.get_core_system("logger").info(
		"Generating Benchmark/Showcase Level (Editor Compatible)... ", "World"
	)
	_generate()


func _generate() -> void:
	# 1. Root Node (World)
	var level_root: Node = Node.new()
	level_root.name = "ShowcaseWorld"
	# Attach World script
	var world_script: Script = load(WORLD_SCRIPT_PATH)
	if world_script:
		level_root.set_script(world_script)
	else:
		push_error("World script not found! Level will not function correctly.")

	# 2. MultiplayerSpawner (Required by World for replication)
	var spawner: MultiplayerSpawner = MultiplayerSpawner.new()
	spawner.name = "MultiplayerSpawner"
	spawner.spawn_path = NodePath("..")  # Spawns into World
	level_root.add_child(spawner)
	spawner.owner = level_root

	# 3. Environment (WorldEnvironment & Sun)
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	level_root.add_child(world_env)
	world_env.owner = level_root

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.position = Vector3(5, 10, 5)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	level_root.add_child(sun)
	sun.owner = level_root

	# 4. Navigation Region (Holds the Map Geometry)
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	level_root.add_child(nav_region)
	nav_region.owner = level_root

	# Weather Interaction
	var weather_scn_path: String = "res://game/world/actors/weather/weather_controller.tscn"
	if ResourceLoader.exists(weather_scn_path):
		var wc: Node3D = load(weather_scn_path).instantiate()
		wc.name = "WeatherController"
		level_root.add_child(wc)
		wc.owner = level_root

	# 5. CSG Map Geometry (Child of NavRegion)
	var csg_root: CSGCombiner3D = CSGCombiner3D.new()
	csg_root.name = "map"  # Canonical name often used
	csg_root.use_collision = true
	nav_region.add_child(csg_root)
	csg_root.owner = level_root

	# --- GEOMETRY CONSTRUCTION ---
	_build_geometry(csg_root, level_root)

	# --- ENTITIES & SPAWNS ---

	# Player Spawns (Group needed)
	var spawn_marker: Marker3D = Marker3D.new()
	spawn_marker.name = "PlayerSpawn_01"
	spawn_marker.position = Vector3(0, 2, 0)
	spawn_marker.add_to_group("player_spawn")  # CRITICALLY IMPORTANT GROUP
	level_root.add_child(spawn_marker)
	spawn_marker.owner = level_root

	# 6. UI / HUD
	# Typically spawned by World or GameManager, but we can add the HUD layer placeholders
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "GameHUD"
	level_root.add_child(hud_layer)
	hud_layer.owner = level_root

	# Attempt to add ProgressionHUD if available
	if ResourceLoader.exists(HUD_SCENE_PATH):
		var hud_scn: PackedScene = load(HUD_SCENE_PATH)
		var hud_inst: Control = hud_scn.instantiate()
		hud_inst.name = "ProgressionHUD"
		hud_layer.add_child(hud_inst)
		hud_inst.owner = level_root

	# --- INTERACTIVE ZONES ---
	_create_pickup_gallery(level_root, csg_root)
	_create_telefrag_arena(level_root, csg_root)
	_create_feature_museum(level_root, csg_root)
	_create_item_spawner_demo(level_root, csg_root)
	_create_monster_zoo(level_root, csg_root)

	# --- SAVE SCENE ---
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(level_root)
	if result == OK:
		var err: Error = ResourceSaver.save(packed, "res://game/world/maps/showcase.tscn")
		if err == OK:
			GameManager.get_core_system("logger").info(
				"Success: Generated res://game/world/maps/showcase.tscn", "World"
			)
		else:
			GameManager.get_core_system("logger").info(
				"Error saving scene: " + " " + str(err), "World"
			)
	else:
		GameManager.get_core_system("logger").info(
			"Error packing scene: " + " " + str(result), "World"
		)

	# Exit app after generation
	quit()


func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		push_error("Texture file not found: " + path)
		return null

	var img: Image = Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null


func _build_geometry(csg_root: CSGCombiner3D, owner_node: Node) -> void:
	# Floor (Lobby)
	var floor_lobby: CSGBox3D = CSGBox3D.new()
	floor_lobby.name = "Floor_Lobby"
	floor_lobby.size = Vector3(30, 1, 30)
	floor_lobby.position = Vector3(0, -0.5, 0)
	floor_lobby.set_meta("level_editor_placed", true)
	csg_root.add_child(floor_lobby)
	floor_lobby.owner = owner_node

	# Retro Floor Material
	var mat_floor: StandardMaterial3D = StandardMaterial3D.new()
	mat_floor.albedo_texture = _load_texture(TEXTURE_FLOOR)
	mat_floor.uv1_triplanar = true
	mat_floor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_lobby.material = mat_floor

	# Walls
	var mat_wall: StandardMaterial3D = StandardMaterial3D.new()
	mat_wall.albedo_texture = _load_texture(TEXTURE_WALL)
	mat_wall.uv1_triplanar = true
	mat_wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_create_wall(csg_root, owner_node, Vector3(0, 2, 15), Vector3(30, 4, 1), mat_wall)  # Back
	_create_wall(csg_root, owner_node, Vector3(0, 2, -15), Vector3(30, 4, 1), mat_wall)  # Front
	_create_wall(csg_root, owner_node, Vector3(-15, 2, 0), Vector3(1, 4, 30), mat_wall)  # Left
	_create_wall(csg_root, owner_node, Vector3(15, 2, 0), Vector3(1, 4, 30), mat_wall)  # Right


func _create_wall(
	parent: Node, owner_node: Node, pos: Vector3, size: Vector3, mat: Material
) -> void:
	var wall: CSGBox3D = CSGBox3D.new()
	wall.size = size
	wall.position = pos
	wall.material = mat
	wall.set_meta("level_editor_placed", true)
	parent.add_child(wall)
	wall.owner = owner_node


func _create_pickup_gallery(level_root: Node, _csg_root: CSGCombiner3D) -> void:
	# Pickup Area
	var start_x: int = -10
	var start_z: int = 10

	# Use PickupSpawnerActor for Health
	for i in range(3):
		var spawner: Node3D = (load(PICKUP_SPAWNER_ACTOR_PATH) as GDScript).new()
		spawner.name = "HealthSpawner_%d" % i
		spawner.position = Vector3(start_x + (i * 2), 0, start_z)
		spawner.set("pickup_category", 0)  # HEALTH
		level_root.add_child(spawner)
		spawner.owner = level_root

	# Weapons Spawners
	var weapons: Array[String] = ["shotgun", "rocket_launcher"]
	for i in range(weapons.size()):
		var spawner: Node3D = (load(PICKUP_SPAWNER_ACTOR_PATH) as GDScript).new()
		spawner.name = "WeaponSpawner_%s" % weapons[i]
		spawner.position = Vector3(start_x + 8 + (i * 3), 0, start_z)
		spawner.set("pickup_category", 3)  # WEAPON
		spawner.set("weapon_id", weapons[i])
		level_root.add_child(spawner)
		spawner.owner = level_root


func _create_telefrag_arena(level_root: Node, csg_root: CSGCombiner3D) -> void:
	# Simple arena box attached to main area
	var arena: CSGBox3D = CSGBox3D.new()
	arena.size = Vector3(10, 1, 10)
	arena.position = Vector3(20, -0.5, 0)
	arena.set_meta("level_editor_placed", true)

	var mat_arena: StandardMaterial3D = StandardMaterial3D.new()
	mat_arena.albedo_texture = _load_texture(TEXTURE_METAL)
	mat_arena.uv1_triplanar = true
	mat_arena.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	arena.material = mat_arena

	csg_root.add_child(arena)
	arena.owner = level_root


func _create_feature_museum(level_root: Node, csg_root: CSGCombiner3D) -> void:
	# Create a new hall for features
	var hall_z_start: float = -20.0
	var hall: CSGBox3D = CSGBox3D.new()
	hall.size = Vector3(40, 1, 10)
	hall.position = Vector3(0, -0.5, hall_z_start)
	hall.set_meta("level_editor_placed", true)

	var mat_hall: StandardMaterial3D = StandardMaterial3D.new()
	mat_hall.albedo_texture = _load_texture(TEXTURE_GRATING)
	mat_hall.uv1_triplanar = true
	mat_hall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hall.material = mat_hall

	csg_root.add_child(hall)
	hall.owner = level_root

	# 1. Teleporter Demo (Using Editor Actor)
	var t1: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	t1.position = Vector3(-15, 0, hall_z_start)
	t1.name = "Tel_Sender"
	t1.set("target_teleporter_name", "Tel_Receiver")
	level_root.add_child(t1)
	t1.owner = level_root

	var t2: Node3D = (load(TELEPORTER_ACTOR_PATH) as GDScript).new()
	t2.position = Vector3(-10, 0, hall_z_start)
	t2.name = "Tel_Receiver"
	t2.set("target_teleporter_name", "Tel_Sender")
	level_root.add_child(t2)
	t2.owner = level_root

	# 2. Jump Pad (Using Editor Actor)
	var jump: Node3D = (load(JUMP_PAD_ACTOR_PATH) as GDScript).new()
	jump.position = Vector3(-5, 0, hall_z_start)
	jump.set("launch_velocity", 20.0)
	level_root.add_child(jump)
	jump.owner = level_root

	# 3. Hazard Pit (Lava) (Using Editor Actor)
	var haz_pos: Vector3 = Vector3(5, 0, hall_z_start)
	var haz: Node3D = (load(HAZARD_VOLUME_ACTOR_PATH) as GDScript).new()
	haz.position = haz_pos
	haz.set("hazard_type", 0)  # LAVA
	haz.set("volume_size", Vector3(8, 1, 8))
	level_root.add_child(haz)
	haz.owner = level_root

	# Add a visual pit for context
	var pit: CSGBox3D = CSGBox3D.new()
	pit.operation = CSGShape3D.OPERATION_SUBTRACTION
	pit.size = Vector3(8.2, 2, 8.2)
	pit.position = haz_pos
	pit.set_meta("level_editor_placed", true)
	csg_root.add_child(pit)
	pit.owner = level_root

	# 4. Feature: Weather Sync (Info Label)
	var label: Label3D = Label3D.new()
	var features: String = (
		"Environment Features:\n- Weather (Rain/Snow Sync)\n"
		+ "- Retro Post-Process (Dither)\n- Interactive Hazards\n"
		+ "- 100% Editor Compatible"
	)
	label.text = features
	label.position = Vector3(15, 3, hall_z_start)
	label.font_size = 32
	level_root.add_child(label)
	label.owner = level_root


func _create_item_spawner_demo(level_root: Node, csg_root: CSGCombiner3D) -> void:
	# ---------------------------------------------------------
	# ITEM SPAWNER DEMO (Using Editor Actors)
	# ---------------------------------------------------------
	var z_pos: float = -28.0
	var x_start: float = -5.0

	var items: Array[String] = ["health_potion", "armor_shard", "speed_boost", "damage_boost"]

	# Platform
	var platform: CSGBox3D = CSGBox3D.new()
	platform.size = Vector3(20, 1, 4)
	platform.position = Vector3(0, -0.5, z_pos)
	platform.set_meta("level_editor_placed", true)
	csg_root.add_child(platform)
	platform.owner = level_root

	for i in range(items.size()):
		var spawner: Node3D = (load(PICKUP_SPAWNER_ACTOR_PATH) as GDScript).new()
		spawner.name = "Spawner_" + items[i]
		spawner.set("pickup_category", 1 if "armor" in items[i] else 0)  # Simple mapping
		spawner.set("item_id", items[i])
		spawner.position = Vector3(x_start + (i * 3.0), 0, z_pos)
		level_root.add_child(spawner)
		spawner.owner = level_root


func _create_monster_zoo(level_root: Node, csg_root: CSGCombiner3D) -> void:
	# ---------------------------------------------------------
	# MONSTER ZOO - Visual Roster Verification
	# ---------------------------------------------------------
	var zoo_z: float = -35.0

	# Platform
	var platform: CSGBox3D = CSGBox3D.new()
	platform.size = Vector3(40, 1, 10)
	platform.position = Vector3(0, -0.5, zoo_z)
	csg_root.add_child(platform)
	platform.owner = level_root

	# Roster to display (Including all 8 new Bot types)
	var roster: Array = [
		"bot_crash",
		"bot_sarge",
		"bot_doom",
		"bot_hunter",
		"bot_slash",
		"bot_visor",
		"bot_xaero",
		"bot_grunt",
		"dummy_bot",
		"grunt_basic",
		"imp",
		"swarmling",
		"healer",
		"assassin",
		"rally",
		"summoner",
		"warlord",
		"infernal_lord"
	]

	var start_x: float = -15.0
	var spacing: float = 3.5

	for i in range(roster.size()):
		var enemy_id: String = roster[i]
		var enemy_scn: PackedScene = load(ENEMY_SCENE_PATH)
		if enemy_scn:
			var enemy: Node = enemy_scn.instantiate()
			enemy.name = "Zoo_" + enemy_id.capitalize()
			# Position in line
			enemy.position = Vector3(start_x + (i * spacing), 1.0, zoo_z)
			# Set ID
			enemy.enemy_id = enemy_id

			# Disable AI for inspection
			enemy.is_ai_active = false

			level_root.add_child(enemy)
			enemy.owner = level_root

			# Label
			var label: Label3D = Label3D.new()
			label.text = enemy_id
			label.position = Vector3(0, 2.5, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 24
			enemy.add_child(label)
			label.owner = level_root
