@tool
class_name Rope
extends Node3D

signal rope_broken(break_position: Vector3)
signal player_attached(player: Node3D, segment: RigidBody3D)
signal player_detached(player: Node3D)

@export_group("Rope Properties")
@export var length: float = 5.0
@export var segment_count: int = 5
@export var segment_mass: float = 0.5
@export var damping: float = 0.5
@export var rope_thickness: float = 0.05
@export var rope_color: Color = Color(0.6, 0.4, 0.2)
@export_group("Breakable Properties")
@export var is_breakable: bool = true
@export var max_health: float = 50.0
@export var break_at_segment: int = -1  # -1 = any segment, otherwise specific
@export_group("Swing Properties")
@export var swing_force_multiplier: float = 15.0
@export var idle_sway_enabled: bool = true
@export var idle_sway_force: float = 0.3
@export var idle_sway_interval: float = 2.0

var segments: Array[RigidBody3D] = []
var current_health: float = 50.0
var is_broken: bool = false
var attached_player: Node3D = null
var attached_segment: RigidBody3D = null

var _sway_timer: float = 0.0


func _ready() -> void:
	current_health = max_health
	_generate_rope()

	# Setup sync after rope is generated
	if segments.size() > 0:
		_setup_synchronizer()

	add_to_group("ropes")
	add_to_group("damageable")


func _physics_process(delta: float) -> void:
	# Only run physics on server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Idle sway animation
	if idle_sway_enabled and not is_broken and segments.size() > 0:
		_sway_timer += delta
		if _sway_timer >= idle_sway_interval:
			_sway_timer = 0.0
			_apply_idle_sway()


func _setup_synchronizer() -> void:
	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"
	add_child(synchronizer)

	var config: SceneReplicationConfig = SceneReplicationConfig.new()

	# Sync each segment's position and rotation
	for i: int in range(segments.size()):
		var seg_pos_path: String = "Segment" + str(i) + ":global_position"
		var seg_rot_path: String = "Segment" + str(i) + ":global_rotation"
		config.add_property(seg_pos_path)
		config.add_property(seg_rot_path)

	# Sync health and broken state
	config.add_property(":current_health")
	config.add_property(":is_broken")

	synchronizer.replication_config = config


func _generate_rope() -> void:
	var segment_len: float = length / segment_count
	var prev_body: PhysicsBody3D = StaticBody3D.new()  # Anchor
	prev_body.name = "Anchor"
	add_child(prev_body)
	prev_body.position = Vector3.ZERO

	for i: int in range(segment_count):
		var seg: RigidBody3D = RigidBody3D.new()
		seg.name = "Segment" + str(i)
		seg.mass = segment_mass
		seg.linear_damp = damping
		seg.angular_damp = damping
		add_child(seg)
		seg.position = Vector3(0, -(i + 1) * segment_len, 0)

		# Collision shape
		var col: CollisionShape3D = CollisionShape3D.new()
		var caps: CapsuleShape3D = CapsuleShape3D.new()
		caps.height = segment_len
		caps.radius = rope_thickness
		col.shape = caps
		seg.add_child(col)

		# Visual mesh
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "Mesh"
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.height = segment_len
		cyl.top_radius = rope_thickness
		cyl.bottom_radius = rope_thickness
		mesh.mesh = cyl

		# Apply rope material
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = rope_color
		material.roughness = 0.8
		mesh.set_surface_override_material(0, material)
		seg.add_child(mesh)

		# Joint connecting to previous segment
		var joint: PinJoint3D = PinJoint3D.new()
		joint.name = "Joint" + str(i)
		add_child(joint)
		joint.position = Vector3(0, -i * segment_len, 0)
		joint.node_a = prev_body.get_path()
		joint.node_b = seg.get_path()

		# Interaction area on segment
		var area: Area3D = Area3D.new()
		area.name = "GrabArea"
		seg.add_child(area)
		var area_col: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.5
		area_col.shape = sphere
		area.add_child(area_col)

		area.body_entered.connect(func(body: Node) -> void: _on_segment_entered(body, seg))
		area.body_exited.connect(func(body: Node) -> void: _on_segment_exited(body, seg))

		prev_body = seg
		segments.append(seg)


func _on_segment_entered(body: Node, segment: RigidBody3D) -> void:
	if is_broken:
		return

	if body.is_in_group("player") and body.has_method("set_available_rope"):
		body.set_available_rope(self, segment)


func _on_segment_exited(body: Node, _segment: RigidBody3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_available_rope"):
		body.clear_available_rope(self)


## Apply idle sway forces to create subtle movement


func _apply_idle_sway() -> void:
	if segments.is_empty():
		return

	var sway_direction: Vector3 = (
		Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	)

	# Apply force to bottom segment
	var bottom_seg: RigidBody3D = segments[segments.size() - 1]
	if is_instance_valid(bottom_seg):
		bottom_seg.apply_central_impulse(sway_direction * idle_sway_force)


## Take damage from attacks (server-side)


func take_damage(amount: float, _damage_type: String = "generic", source: Node = null) -> void:
	if not is_breakable or is_broken:
		return

	# Only process on server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	current_health -= amount

	if current_health <= 0:
		_break_rope(source)


## Break the rope (server-side)


func _break_rope(breaker: Node = null) -> void:
	if is_broken:
		return

	is_broken = true

	# Determine break point
	var break_index: int = break_at_segment
	if break_index < 0 or break_index >= segments.size():
		break_index = int(floorf(segments.size() / 2.0))  # Middle of rope

	# Detach any attached player
	if attached_player and attached_player.has_method("detach_from_rope"):
		attached_player.detach_from_rope()

	# Play break effects on all clients
	var break_pos: Vector3
	if break_index < segments.size():
		break_pos = segments[break_index].global_position
	else:
		break_pos = global_position
	_play_break_effects.rpc(break_pos)

	# Emit signal
	rope_broken.emit(break_pos)

	# Emit event for game systems
	if GameManager:
		GameManager.emit_event(
			"rope_broken", {"rope": self, "position": break_pos, "breaker": breaker}
		)

	# Make segments below break point fall freely
	for i: int in range(break_index, segments.size()):
		var seg: RigidBody3D = segments[i]
		if is_instance_valid(seg):
			# Remove joint to parent
			var joint_name: String = "Joint" + str(i)
			var joint: Node = get_node_or_null(joint_name)
			if joint:
				joint.queue_free()

			# Apply downward impulse
			seg.apply_central_impulse(Vector3.DOWN * 5.0)


@rpc("authority", "call_local", "reliable")
func _play_break_effects(break_pos: Vector3) -> void:
	## Play break visual/audio effects (all clients)
	is_broken = true

	# Spawn break particles via GameManager.get_core_system("effects")
	var effects: Node = GameManager.get_core_system("effects")
	if effects and effects.has_method("spawn_break_particles"):
		effects.spawn_break_particles(break_pos, rope_color)

	# Play sound (placeholder)
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.name = "BreakSound"
	audio.global_position = break_pos
	audio.bus = "SFX"
	get_tree().root.add_child(audio)

	# Auto-cleanup after timeout
	get_tree().create_timer(1.0).timeout.connect(audio.queue_free)


## Attach player to a segment (called by player)


func attach_player(player: Node3D, segment: RigidBody3D) -> void:
	attached_player = player
	attached_segment = segment
	player_attached.emit(player, segment)


## Detach player from rope


func detach_player(player: Node3D) -> void:
	if player == attached_player:
		attached_player = null
		attached_segment = null
		player_detached.emit(player)


## Apply swing force (called by player during swing)


func apply_swing_force(direction: Vector3) -> void:
	if not attached_segment or is_broken:
		return

	attached_segment.apply_central_impulse(direction * swing_force_multiplier)


## Get segment at index


func get_segment(index: int) -> RigidBody3D:
	if index >= 0 and index < segments.size():
		return segments[index]
	return null


## Get bottom segment position (for grab point)


func get_bottom_position() -> Vector3:
	if segments.is_empty():
		return global_position + Vector3(0, -length, 0)
	return segments[segments.size() - 1].global_position


## Get rope length


func get_rope_length() -> float:
	return length


## Check if rope is usable


func can_use() -> bool:
	return not is_broken and current_health > 0
