class_name ShowcaseSignage
extends RefCounted

## Procedurally spawns Label3D signs at showcase map zones.
## Called once from world.gd after the map loads.

# Sign definition: [position, rotation_y_deg, title, description]
const SIGNS: Array = [
	# ── Lobby ──
	[Vector3(0, 3.5, 14.5), 0.0, "SPAWN LOBBY", "Player spawn area\nType ~ to open console"],
	# ── Weapons (north wall) ──
	[Vector3(-0.5, 2.5, 9), 0.0, "WEAPON RACK", "Shotgun • Rocket Launcher\ngive_weapon <name>"],
	# ── Health Spawners (central south) ──
	[Vector3(0, 2.5, -4), 0.0, "HEALTH PICKUPS", "Health packs respawn every 30s"],
	# ── Teleporter Pair ──
	[Vector3(-12.5, 2.5, -19), 0.0, "TELEPORTERS", "Step on to warp\nBidirectional link"],
	# ── Jump Pad ──
	[Vector3(-5, 2.5, -19), 0.0, "JUMP PAD", "Vertical launch\n20 m/s velocity"],
	# ── Hazard Zone ──
	[Vector3(5, 2.5, -16), 0.0, "HAZARD ZONE", "Lava damage: 20 DPS\nTest god mode here"],
	# ── Powerup Row ──
	[
		Vector3(-0.5, 2.5, -27),
		0.0,
		"POWERUPS",
		"Health Potion • Armor Shard\nSpeed Boost • Damage Boost"
	],
	# ── Enemy Zoo ──
	[
		Vector3(0, 3.5, -32),
		0.0,
		"ENEMY ZOO",
		"All enemy types on display\nkill_all_enemies • spawn_enemy"
	],
	# ── Side Arena (east) ──
	[Vector3(20, 2.5, -4.5), 0.0, "ARENA", "Open combat area\nTry: set_enemy_ai 0"],
]

# Visual styling
const TITLE_FONT_SIZE: int = 32
const DESC_FONT_SIZE: int = 18
const TITLE_COLOR := Color(0.95, 0.85, 0.55, 1.0)  # Warm gold
const DESC_COLOR := Color(0.75, 0.78, 0.82, 1.0)  # Cool grey
const SIGN_SPACING: float = 0.6  # Vertical gap between title and desc


static func spawn_signs(parent: Node) -> void:
	var container := Node3D.new()
	container.name = "ShowcaseSigns"
	parent.add_child(container)

	for sign_data: Variant in SIGNS:
		var pos: Vector3 = sign_data[0]
		var rot_y: float = sign_data[1]
		var title: String = sign_data[2]
		var desc: String = sign_data[3]

		# Title label
		var title_label := Label3D.new()
		title_label.name = "Sign_" + title.replace(" ", "_")
		title_label.text = title
		title_label.font_size = TITLE_FONT_SIZE
		title_label.modulate = TITLE_COLOR
		title_label.outline_modulate = Color(0, 0, 0, 0.8)
		title_label.outline_size = 4
		title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title_label.no_depth_test = true
		title_label.position = pos
		title_label.rotation_degrees.y = rot_y
		container.add_child(title_label)

		# Description label (below title)
		var desc_label := Label3D.new()
		desc_label.name = "Desc_" + title.replace(" ", "_")
		desc_label.text = desc
		desc_label.font_size = DESC_FONT_SIZE
		desc_label.modulate = DESC_COLOR
		desc_label.outline_modulate = Color(0, 0, 0, 0.6)
		desc_label.outline_size = 3
		desc_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		desc_label.no_depth_test = true
		desc_label.position = pos - Vector3(0, SIGN_SPACING, 0)
		desc_label.rotation_degrees.y = rot_y
		container.add_child(desc_label)
