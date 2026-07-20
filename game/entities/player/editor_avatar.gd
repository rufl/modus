extends CharacterBody3D

const EDITOR_RUNTIME_PATH: String = "res://game/editor/embedded_level_editor.tscn"

@export var fly_speed: float = 15.0
@export var sprint_speed: float = 30.0
@export var acceleration: float = 10.0
@export var friction: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var move_speed: float = 15.0  # For validation
@export var max_speed: float = 40.0  # Absolute max

var input_dir: Vector2 = Vector2.ZERO
var vertical_input: float = 0.0
var is_dead: bool = false

@onready var camera: Camera3D = $Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var _rotation: Vector2 = Vector2.ZERO
var _editor_instance: Control = null


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect signals to prevent memory leaks ===
	var cm := GameManager.get_core_system("config")
	if cm and cm.config_reloaded.is_connected(_load_config):
		cm.config_reloaded.disconnect(_load_config)


func _ready() -> void:
	# Local player setup - in single player (no peer), always setup
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if is_local:
		_load_config()
		var cm: Node = GameManager.get_core_system("config")
		if cm:
			cm.config_reloaded.connect(_load_config)

		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		# Hide own mesh
		mesh.visible = false

		# Broadcast EDIT status to scoreboard
		# Broadcast EDIT status to scoreboard
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.match_service:
			gs.match_service.update_player_status.rpc(0, "EDIT")

		# Enable Editor Mode automatically
		call_deferred("_enable_editor_interface")
	else:
		# Remote player: disable camera and physics processing
		camera.current = false
		set_physics_process(false)
		set_process_input(false)

		# Ensure mesh is visible
		mesh.visible = true


func _load_config(_file_path: String = "") -> void:
	var cm := GameManager.get_core_system("config")
	if not cm:
		return

	var cfg: Dictionary = cm.get_value("player_modes.editor", {})
	if cfg.is_empty():
		return

	fly_speed = cfg.get("fly_speed", fly_speed)
	sprint_speed = cfg.get("sprint_speed", sprint_speed)
	acceleration = cfg.get("acceleration", acceleration)
	friction = cfg.get("friction", friction)
	mouse_sensitivity = cfg.get("mouse_sensitivity", mouse_sensitivity)


func _enable_editor_interface() -> void:
	# Use new embedded level editor from game/editor/
	var editor_scn: PackedScene = load(EDITOR_RUNTIME_PATH)
	if editor_scn:
		_editor_instance = editor_scn.instantiate()
		add_child(_editor_instance)

		# Open the editor immediately
		if _editor_instance.has_method("open"):
			_editor_instance.open()

		# Note: EditorRuntime drives the camera. Avatar syncs to the camera position.


func _physics_process(_delta: float) -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if not is_local:
		return

	# Handle movement similar to Spectator "Free" mode

	_handle_movement(_delta)
	move_and_slide()

	# Sync editor camera if needed
	# (Logic to be refined based on how EditorRuntime is integrated)


func _handle_movement(_delta: float) -> void:
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else fly_speed

	var input_vec: Vector2 = Input.get_vector("left", "right", "up", "down")
	var dir: Vector3 = Vector3.ZERO
	dir += global_transform.basis.z * input_vec.y
	dir += global_transform.basis.x * input_vec.x

	if Input.is_action_pressed("jump"):
		dir.y += 1.0
	if Input.is_action_pressed("crouch"):
		dir.y -= 1.0

	if dir.length() > 0:
		dir = dir.normalized()

	velocity = velocity.move_toward(dir * speed, acceleration * _delta)


func _input(_event: InputEvent) -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if not is_local:
		return

	if _event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotation.x -= _event.relative.y * mouse_sensitivity
		_rotation.y -= _event.relative.x * mouse_sensitivity
		_rotation.x = clamp(_rotation.x, -PI / 2, PI / 2)

		rotation.y = _rotation.y
		camera.rotation.x = _rotation.x

	# Toggle Mouse for UI
	if _event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# F6 Toggle handled by Spectator usually, but here we ARE the editor.
	# Maybe F6 toggles the "Tool UI" on/off?
	if _event is InputEventKey and _event.pressed and _event.keycode == KEY_F6:
		_toggle_editor_ui()


func _toggle_editor_ui() -> void:
	if _editor_instance:
		_editor_instance.queue_free()
		_editor_instance = null

		# Restore control
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		set_physics_process(true)
	else:
		var editor_scn: PackedScene = load(EDITOR_RUNTIME_PATH)
		if editor_scn:
			_editor_instance = editor_scn.instantiate()
			add_child(_editor_instance)

			# NOTE: EditorRuntime manages its own camera.
			# We disable our own movement processing while the editor is active
			# to prevent conflicts.
			set_physics_process(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Networking: Is Dead? (Never)
