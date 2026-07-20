extends Node

signal lod_changed(new_lod: LODLevel)

# Close range: Full processing
# Medium range: Reduced tick rate / simplified FX
# Far range: Minimal processing / no animations
# Very far: Disabled/Hidden (careful with network sync!)
enum LODLevel { HIGH, MEDIUM, LOW, CULL }

@export_group("LOD Settings")
@export var distance_medium: float = 20.0
@export var distance_low: float = 50.0
@export var distance_cull: float = 100.0
@export var check_interval: float = 0.5
@export_group("Optimization Targets")
@export var target_node: Node3D
@export var optimize_physics: bool = true
@export var optimize_process: bool = true
@export var optimize_visibility: bool = false
@export_group("Frustum Culling")
@export var use_frustum_culling: bool = false
@export var frustum_margin: Vector3 = Vector3(1, 1, 1)
@export_group("Visibility Range (HLOD)")
@export var auto_set_visibility_range: bool = false
@export var visibility_range_fade_mode: GeometryInstance3D.VisibilityRangeFadeMode = (
	GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
)

var current_lod: LODLevel = LODLevel.HIGH

var _timer: float = 0.0
var _camera: Camera3D
var _screen_notifier: VisibleOnScreenNotifier3D
var _is_on_screen: bool = true


func _ready() -> void:
	if not target_node:
		var parent: Node = get_parent()
		if parent is Node3D:
			target_node = parent

	# Setup Frustum Culling
	if use_frustum_culling:
		_screen_notifier = VisibleOnScreenNotifier3D.new()
		_screen_notifier.name = "FrustumCuller"
		_screen_notifier.aabb = AABB(-frustum_margin, frustum_margin * 2.0)
		add_child(_screen_notifier)
		_screen_notifier.screen_entered.connect(_on_screen_entered)
		_screen_notifier.screen_exited.connect(_on_screen_exited)

		# Initial state (assume visible until proven otherwise or check)
		# _is_on_screen = _screen_notifier.is_on_screen() # Can't rely on this in _ready immediately

	# Setup Visibility Range (Engine HLOD)
	if auto_set_visibility_range and target_node is GeometryInstance3D and distance_cull > 0:
		target_node.visibility_range_end = distance_cull
		target_node.visibility_range_end_margin = 5.0  # Smooth fade
		target_node.visibility_range_fade_mode = visibility_range_fade_mode

	# Randomize initial timer to spread load
	_timer = randf_range(0.0, check_interval)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= check_interval:
		_timer = 0.0
		_update_lod()


func _on_screen_entered() -> void:
	_is_on_screen = true
	_update_lod(true)  # Force update


func _on_screen_exited() -> void:
	_is_on_screen = false
	_update_lod(true)  # Force update


func _update_lod(force: bool = false) -> void:
	if not is_inside_tree():
		return

	# specific for multiplayer: handle server-side LOD?
	if not multiplayer.has_multiplayer_peer():
		pass
	elif multiplayer.is_server() and not OS.has_feature("dedicated_server"):
		pass
	elif multiplayer.is_server():
		return

	# Logic: If using frustum culling and off-screen, force CULL state
	if use_frustum_culling and not _is_on_screen:
		if current_lod != LODLevel.CULL:
			current_lod = LODLevel.CULL
			_apply_lod(LODLevel.CULL)
			lod_changed.emit(LODLevel.CULL)
		return

	if not _camera:
		_camera = get_viewport().get_camera_3d()
		if not _camera:
			return

	if not is_instance_valid(target_node):
		return

	var dist_sq: float = target_node.global_position.distance_squared_to(_camera.global_position)
	var new_lod: LODLevel = LODLevel.HIGH

	if distance_cull > 0 and dist_sq > distance_cull * distance_cull:
		new_lod = LODLevel.CULL
	elif dist_sq > distance_low * distance_low:
		new_lod = LODLevel.LOW
	elif dist_sq > distance_medium * distance_medium:
		new_lod = LODLevel.MEDIUM

	if new_lod != current_lod or force:
		current_lod = new_lod
		_apply_lod(new_lod)
		lod_changed.emit(new_lod)


func _apply_lod(level: LODLevel) -> void:
	if not is_instance_valid(target_node):
		return

	match level:
		LODLevel.HIGH:
			if optimize_process:
				target_node.process_mode = Node.PROCESS_MODE_INHERIT
			if optimize_physics and target_node is CollisionObject3D:
				pass
			if optimize_visibility:
				target_node.visible = true

		LODLevel.MEDIUM, LODLevel.LOW:
			if optimize_process:
				target_node.process_mode = Node.PROCESS_MODE_INHERIT
			if optimize_visibility:
				target_node.visible = true

		LODLevel.CULL:
			if optimize_visibility:
				target_node.visible = false
			# If culled by distance/frustum, we might want to pause processing if safe
			# But for network sync, we usually keep processing processing mode INHERIT
			# and let logic scripts throttle themselves via the signal.
