extends RigidBody3D
class_name PickupBase

const TOOLTIP_RANGE: float = 8.0
const RAY_ALWAYS_VISIBLE: bool = true

@export var pickup_name: String = "Item"
@export var description: String = "A useful item"
@export var pickup_sound: AudioStream
@export var owner_peer_id: int = 0
@export var rarity_tier: int = -1:
	set(value):
		rarity_tier = value
		if value < 0:
			rarity = null
		elif not rarity or rarity.tier != value:
			rarity = ItemRarity.from_tier(value)
		if is_node_ready():
			_apply_rarity_visuals()
@export var use_icon: bool = false
@export var icon_text: String = ""
@export var icon_color: Color = Color.WHITE

var collected: bool = false
var vertical_ray: GPUParticles3D = null
var base_glow: OmniLight3D = null
var label_node: Label3D = null
var icon_node: Label3D = null
var pickup_area: Area3D = null
var rarity: ItemRarity
var item_data: Dictionary = {}


func _enter_tree() -> void:
	# Spawn fields are restored when the child synchronizer enters the tree.
	# Configure it first so authored and dynamically-created pickups share the
	# same property order before any derived _ready() consumes restored state.
	_setup_synchronizer()


func _setup_synchronizer() -> void:
	var synchronizer: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	if not synchronizer:
		synchronizer = MultiplayerSynchronizer.new()
		synchronizer.name = "MultiplayerSynchronizer"

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property(".:collected")
	config.add_property(".:owner_peer_id")
	config.add_property(".:rarity_tier")

	_extend_synchronizer_config(config)
	synchronizer.replication_config = config
	if not synchronizer.get_parent():
		add_child(synchronizer)


## Virtual method for subclasses to add more properties


func _extend_synchronizer_config(config: SceneReplicationConfig) -> void:
	config.add_property(".:item_data")


# -------------------------------------------------------------------------------------------------


func _ready() -> void:
	# Physics setup
	collision_layer = 16
	collision_mask = 1
	mass = 1.0
	gravity_scale = 1.0
	linear_damp = 3.0
	angular_damp = 5.0

	add_to_group("pushable")
	add_to_group("items")

	# Owner visibility check
	if owner_peer_id > 0:
		var my_id: int = multiplayer.get_unique_id()
		if my_id != owner_peer_id and my_id != 1:
			hide()
			set_process(false)
			return

	_create_pickup_area()
	_create_vertical_ray()
	_create_tooltip()

	if rarity:
		_apply_rarity_visuals()


func set_rarity(new_rarity: ItemRarity) -> void:
	rarity = new_rarity
	rarity_tier = new_rarity.tier if new_rarity else -1
	if is_inside_tree():
		_apply_rarity_visuals()


func _apply_rarity_visuals() -> void:
	if not rarity:
		return

	var beam_color: Color = rarity.color
	var beam_height: float = rarity.beam_height

	# Update vertical ray
	if vertical_ray:
		_update_ray_color(beam_color, beam_height)

	# Update base glow
	if base_glow:
		base_glow.light_color = beam_color
		base_glow.light_energy = 0.5 + (beam_height * 0.1)

	# Update label color
	if label_node:
		label_node.modulate = beam_color
		label_node.outline_modulate = beam_color.darkened(0.7)


## Create Area3D for pickup detection


func _create_pickup_area() -> void:
	pickup_area = Area3D.new()
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 2

	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	pickup_area.add_child(shape)

	add_child(pickup_area)
	pickup_area.body_entered.connect(_on_body_entered)


## Create vertical particle ray


func _create_vertical_ray() -> void:
	var default_color: Color = Color.WHITE
	var default_height: float = 2.0

	if rarity:
		default_color = rarity.color
		default_height = rarity.beam_height

	# Create particle system for vertical ray
	vertical_ray = GPUParticles3D.new()
	vertical_ray.name = "VerticalRay"
	vertical_ray.emitting = true
	vertical_ray.amount = 30
	vertical_ray.lifetime = 1.5
	vertical_ray.explosiveness = 0.0
	vertical_ray.randomness = 0.1
	vertical_ray.visibility_aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, default_height + 2, 1))

	# Particle material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 1, 0)
	material.spread = 3.0
	material.initial_velocity_min = default_height * 0.8
	material.initial_velocity_max = default_height * 1.2
	material.gravity = Vector3.ZERO
	material.scale_min = 0.03
	material.scale_max = 0.06
	material.damping_min = 0.5
	material.damping_max = 1.0

	# Color gradient
	var gradient := Gradient.new()
	gradient.add_point(0.0, default_color)
	gradient.add_point(0.5, default_color * 1.2)
	gradient.add_point(1.0, Color(default_color.r, default_color.g, default_color.b, 0.0))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	vertical_ray.process_material = material

	# Draw pass
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.albedo_color = default_color
	draw_mat.emission_enabled = true
	draw_mat.emission = default_color
	draw_mat.emission_energy_multiplier = 2.0
	quad.material = draw_mat
	vertical_ray.draw_pass_1 = quad

	add_child(vertical_ray)

	# Base glow light
	base_glow = OmniLight3D.new()
	base_glow.name = "BaseGlow"
	base_glow.light_color = default_color
	base_glow.light_energy = 0.5
	base_glow.omni_range = 2.0
	base_glow.omni_attenuation = 2.0
	base_glow.position = Vector3(0, 0.1, 0)
	add_child(base_glow)


func _update_ray_color(new_color: Color, new_height: float) -> void:
	if not vertical_ray:
		return

	vertical_ray.visibility_aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, new_height + 2, 1))

	var material := vertical_ray.process_material as ParticleProcessMaterial
	if material:
		material.initial_velocity_min = new_height * 0.8
		material.initial_velocity_max = new_height * 1.2

		var gradient := Gradient.new()
		gradient.add_point(0.0, new_color)
		gradient.add_point(0.5, new_color * 1.2)
		gradient.add_point(1.0, Color(new_color.r, new_color.g, new_color.b, 0.0))
		var gradient_texture := GradientTexture1D.new()
		gradient_texture.gradient = gradient
		material.color_ramp = gradient_texture

	# Update draw pass material
	if vertical_ray.draw_pass_1:
		var mesh := vertical_ray.draw_pass_1 as QuadMesh
		if mesh and mesh.material:
			var draw_mat := mesh.material as StandardMaterial3D
			if draw_mat:
				draw_mat.albedo_color = new_color
				draw_mat.emission = new_color


## Create tooltip label or icon


func _create_tooltip() -> void:
	# Load typography config
	var typo_config: Dictionary = _get_tooltip_config()

	if use_icon and icon_text != "":
		# Create icon-only display
		icon_node = Label3D.new()
		icon_node.text = icon_text
		icon_node.font_size = typo_config.get("font_size", 48)
		icon_node.pixel_size = typo_config.get("pixel_size", 0.01)
		icon_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon_node.no_depth_test = true
		icon_node.position = Vector3(0, 1.5, 0)
		icon_node.modulate = icon_color
		icon_node.outline_size = typo_config.get("outline_size", 4)
		icon_node.outline_modulate = _parse_color(
			typo_config.get("outline_color", {"r": 0, "g": 0, "b": 0, "a": 1})
		)
		add_child(icon_node)
	else:
		# Create text tooltip
		label_node = Label3D.new()
		# Translate pickup name
		var localization: Node = GameManager.get_core_system("localization")
		var display_name: String = pickup_name
		if localization and localization.has_method("translate"):
			display_name = localization.translate(pickup_name)
		label_node.text = display_name + "\n" + description
		label_node.font_size = typo_config.get("font_size", 24)
		label_node.pixel_size = typo_config.get("pixel_size", 0.01)
		label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_node.no_depth_test = true
		label_node.position = Vector3(0, 2.5, 0)
		label_node.modulate = _parse_color(
			typo_config.get("text_color", {"r": 1, "g": 1, "b": 0.8, "a": 1})
		)
		label_node.outline_size = typo_config.get("outline_size", 8)
		label_node.outline_modulate = _parse_color(
			typo_config.get("outline_color", {"r": 0, "g": 0, "b": 0, "a": 1})
		)
		add_child(label_node)
		label_node.hide()


func _get_tooltip_config() -> Dictionary:
	## Load tooltip configuration from hud.json5 typography section
	var config_system = GameManager.get_core_system("config")
	if not config_system or not config_system.has_method("get_value"):
		return {}

	var hud_config: Variant = config_system.get_value("visuals.hud")
	if not hud_config is Dictionary or hud_config.is_empty() or not hud_config.has("typography"):
		return {}

	var typo: Dictionary = hud_config.typography
	if use_icon:
		return typo.get("pickup_icon", {})

	return typo.get("pickup_tooltip", {})


func _parse_color(color_dict: Dictionary) -> Color:
	## Convert dictionary to Color
	return Color(
		color_dict.get("r", 1.0),
		color_dict.get("g", 1.0),
		color_dict.get("b", 1.0),
		color_dict.get("a", 1.0)
	)


func _process(_delta: float) -> void:
	_update_tooltip()


func _update_tooltip() -> void:
	if use_icon:
		# Icons always visible, no proximity check needed
		return

	var show_tooltip: bool = false
	var local_player: Node3D = null

	# Find local player
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D and node.is_multiplayer_authority():
			local_player = node
			break

	if local_player:
		var dist: float = global_position.distance_to(local_player.global_position)
		if dist < TOOLTIP_RANGE:
			# Occlusion check
			show_tooltip = _check_visibility(local_player)

	if label_node:
		label_node.visible = show_tooltip


## Check if item is visible to player (not occluded)


func _check_visibility(player: Node3D) -> bool:
	var world_3d := get_world_3d()
	if not world_3d:
		return true

	var space_state := world_3d.direct_space_state
	var from := player.global_position + Vector3(0, 1.5, 0)  # Player eye level
	var to := global_position + Vector3(0, 0.5, 0)

	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])  # World only (mask 1)

	var result := space_state.intersect_ray(query)
	return result.is_empty()


## Override in subclasses to apply pickup effect


func _on_pickup(player: CharacterBody3D) -> void:
	_add_to_inventory(player)


## Subclasses with fallible transfers can leave the pickup available.
func _apply_pickup(player: CharacterBody3D) -> bool:
	_on_pickup(player)
	return true


func _add_to_inventory(player: CharacterBody3D) -> bool:
	if item_data.is_empty():
		return false
	var manager := InventoryMgr.get_instance()
	var peer_id: int = player.get_multiplayer_authority()
	var inventory: Inventory = player.inventory if "inventory" in player else null
	if not inventory:
		return false
	var item := InventoryItem.from_dict(item_data)
	if not inventory.add_item(item):
		return false
	if manager and multiplayer.has_multiplayer_peer() and peer_id != multiplayer.get_unique_id():
		manager._sync_full_inventory.rpc_id(peer_id, inventory.to_dict())
	return true


func _on_body_entered(body: Node3D) -> void:
	if collected:
		return

	if body is CharacterBody3D and not body is Enemy:
		if "health" in body:
			# Visual Feedback (Local)
			if body.is_multiplayer_authority() and body.has_method("trigger_screen_flash"):
				var flash_color: Color = icon_color
				if not use_icon and rarity:
					flash_color = rarity.color
				body.trigger_screen_flash(flash_color, 0.2)

			if body.is_multiplayer_authority():
				if multiplayer.is_server():
					_request_pickup(body.get_path())
				else:
					_request_pickup.rpc_id(1, body.get_path())


## Request pickup from server

@rpc("any_peer", "reliable")
func _request_pickup(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return

	if collected:
		return

	var player := get_node_or_null(player_path) as CharacterBody3D
	if not player:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	collect_for_player(player, sender_id)


## Shared server gate for overlap RPCs and the loot service's tracked pickups.
func collect_for_player(player: CharacterBody3D, sender_id: int) -> bool:
	if not multiplayer.is_server() or collected or not is_instance_valid(player):
		return false
	if player.get_multiplayer_authority() != sender_id:
		return false
	if owner_peer_id > 0 and sender_id != owner_peer_id:
		return false
	if player.global_position.distance_to(global_position) > LootSvc.MAX_PICKUP_DISTANCE * 1.5:
		return false
	if not _apply_pickup(player):
		return false
	collected = true
	if multiplayer.has_multiplayer_peer():
		_sync_collected.rpc(sender_id)
	else:
		_sync_collected(sender_id)
	return true


## Sync collection state to all clients

@rpc("authority", "call_local", "reliable")
func _sync_collected(picker_id: int) -> void:
	collected = true
	_play_sound()

	# Emit pickup signal for statistics, achievements, etc.
	var item_id: String = item_data.get("id", pickup_name)
	var rarity_tier: int = 0
	if rarity:
		rarity_tier = rarity.tier
	# Emit pickup signal via EventBus
	GameManager.emit_event(
		"item_picked_up",
		{
			"item_id": item_id,
			"peer_id": picker_id,
			"position": global_position,
			"rarity": rarity_tier
		}
	)

	queue_free()


## Apply explosion push force


func apply_explosion_force(explosion_pos: Vector3, force: float) -> void:
	var dir: Vector3 = (global_position - explosion_pos).normalized()
	dir.y = max(dir.y, 0.3)
	apply_central_impulse(dir * force * 0.5)


func _play_sound() -> void:
	if pickup_sound:
		var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio.stream = pickup_sound
		audio.autoplay = true
		get_tree().current_scene.add_child(audio)
		audio.global_position = global_position
		audio.finished.connect(audio.queue_free)
