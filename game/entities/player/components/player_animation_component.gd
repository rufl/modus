class_name PlayerAnimationComponent
extends GameComponent

var _player: CharacterBody3D
var _anim_player: AnimationPlayer
var _locomotion: LocomotionBlendTree


func _log(message: String, category: String = "PlayerAnimationComponent") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func setup(player: CharacterBody3D) -> void:
	_player = player
	_log("[PlayerAnimComp] Setting up for player: " + str(player.name), "Player")

	# Wait for visuals to be ready
	await player.ready
	# Use the player's anim_player property which delegates to visuals
	if player.has_method("get") and "anim_player" in player:
		_anim_player = player.anim_player
		if _anim_player:
			_log("[PlayerAnimComp] Got anim_player: " + str(_anim_player.get_path()), "Player")
			_log(
				"[PlayerAnimComp] Available animations: " + str(_anim_player.get_animation_list()),
				"Player"
			)

			# Setup locomotion blend tree
			_locomotion = LocomotionBlendTree.new()
			_locomotion.name = "LocomotionBlendTree"
			add_child(_locomotion)

			# Get skeleton and visuals from player
			var skeleton: Skeleton3D = null
			var visuals: Node3D = null
			if player.has_method("get") and "visuals" in player and player.visuals:
				visuals = player.visuals
				skeleton = player.visuals.skeleton

			_locomotion.setup(_anim_player, skeleton, visuals)
			_log("[PlayerAnimComp] LocomotionBlendTree initialized", "Player")
		else:
			_log("[PlayerAnimComp] anim_player is null - visuals not ready yet", "Player")
	else:
		_log("[PlayerAnimComp] Player doesn't have anim_player property", "Player")

	if not _anim_player:
		push_warning("PlayerAnimationComponent: AnimationPlayer not available from player")


func _process(delta: float) -> void:
	if not _player:
		return

	# Refresh anim_player reference if needed (visuals might not have been ready during setup)
	if not _anim_player and _player.has_method("get") and "anim_player" in _player:
		_anim_player = _player.anim_player
		if _anim_player and not _locomotion:
			_log(
				"[PlayerAnimComp] Lazy-loaded anim_player: " + str(_anim_player.get_path()),
				"Player"
			)

			# Setup locomotion blend tree
			_locomotion = LocomotionBlendTree.new()
			_locomotion.name = "LocomotionBlendTree"
			add_child(_locomotion)

			# Get skeleton and visuals from player
			var skeleton: Skeleton3D = null
			var visuals: Node3D = null
			if _player.has_method("get") and "visuals" in _player and _player.visuals:
				visuals = _player.visuals
				skeleton = _player.visuals.skeleton

			_locomotion.setup(_anim_player, skeleton, visuals)

	if not _anim_player or not _locomotion:
		return

	_update_locomotion(delta)


func _update_locomotion(_delta: float) -> void:
	# Don't interrupt priority animations like melee
	if _anim_player.current_animation in ["Punch_Jab", "Punch_Cross", "Kick"]:
		return

	# Calculate movement parameters
	var h_velocity: Vector2 = Vector2(_player.velocity.x, _player.velocity.z)
	var h_speed: float = h_velocity.length()

	# Calculate movement direction (normalized, relative to player facing)
	var move_dir: Vector2 = Vector2.ZERO
	if h_speed > 0.1:
		# Get forward direction in XZ plane
		var forward: Vector3 = -_player.global_transform.basis.z
		var forward_2d: Vector2 = Vector2(forward.x, forward.z).normalized()

		# Get velocity direction in XZ plane
		var vel_2d: Vector2 = h_velocity.normalized()

		# Calculate relative direction (-1 to 1 for forward/back, left/right)
		# Forward is negative Y in direction space
		move_dir.y = -vel_2d.dot(forward_2d)
		# Right is positive X
		var right_2d: Vector2 = Vector2(forward_2d.y, -forward_2d.x)
		move_dir.x = vel_2d.dot(right_2d)

	# Update locomotion system
	_locomotion.update_locomotion(
		h_speed,
		move_dir,
		_player.is_on_floor(),
		_player.is_crouching,
		_player.is_sprinting,
		_player.velocity.y,
		_player.can_fly  # Pass flying state
	)


## Wrapper to play animations safely (for one-shot animations like melee)
func play(
	anim_name: String, custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false
) -> void:
	if not _anim_player:
		return

	if _anim_player.current_animation == anim_name:
		return

	_log("[PlayerAnimComp] Playing one-shot animation: " + str(anim_name), "Player")
	_anim_player.play(anim_name, custom_blend, custom_speed, from_end)


## Play one-shot animation through locomotion system (preferred method)
func play_oneshot(anim_name: String, blend_time: float = 0.1) -> void:
	if _locomotion:
		_locomotion.play_oneshot(anim_name, blend_time)
	else:
		play(anim_name, blend_time)


## Stop animations
func stop() -> void:
	if _anim_player:
		_anim_player.stop()
