class_name EnemyAnimationComponent
extends Node

## Enemy animation component using LocomotionBlendTree
## Integrates with enemy AI states for smooth animation transitions

var _enemy: CharacterBody3D
var _anim_player: AnimationPlayer
var _locomotion: LocomotionBlendTree


func setup(enemy: CharacterBody3D) -> void:
	_enemy = enemy
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[EnemyAnimComp] Setting up for enemy: " + " " + str(enemy.name), "Enemy")

	# Wait for visuals to be ready
	await enemy.ready

	# Get animation player from visuals
	if enemy.has_method("get") and "visuals" in enemy and enemy.visuals:
		_anim_player = enemy.visuals.anim_player
		if _anim_player:
			var logger2: Node = GameManager.get_core_system("logger")
			if logger2 and logger2.has_method("info"):
				logger2.info(
					"[EnemyAnimComp] Got anim_player: " + " " + str(_anim_player.get_path()),
					"Enemy"
				)

			# Setup locomotion blend tree
			_locomotion = LocomotionBlendTree.new()
			_locomotion.name = "LocomotionBlendTree"
			add_child(_locomotion)

			# Get skeleton from visuals
			var skeleton: Skeleton3D = enemy.visuals.skeleton if enemy.visuals else null
			# CRITICAL: Pass visuals so LocomotionBlendTree uses AnimationTree
			# (direct anim_player.play() is silently ignored when AnimationTree is active)
			_locomotion.setup(_anim_player, skeleton, enemy.visuals)

			var logger3: Node = GameManager.get_core_system("logger")
			if logger3 and logger3.has_method("info"):
				logger3.info("[EnemyAnimComp] LocomotionBlendTree initialized", "Enemy")
		else:
			var logger4: Node = GameManager.get_core_system("logger")
			if logger4 and logger4.has_method("info"):
				logger4.info("[EnemyAnimComp] anim_player is null - visuals not ready yet", "Enemy")
	else:
		var logger5: Node = GameManager.get_core_system("logger")
		if logger5 and logger5.has_method("info"):
			logger5.info("[EnemyAnimComp] Enemy doesn't have visuals", "Enemy")

	if not _anim_player:
		push_warning("EnemyAnimationComponent: AnimationPlayer not available from enemy")


func _process(delta: float) -> void:
	if not _enemy:
		return

	# Lazy-load anim_player if not ready during setup
	if not _anim_player and _enemy.has_method("get") and "visuals" in _enemy and _enemy.visuals:
		_anim_player = _enemy.visuals.anim_player
		if _anim_player and not _locomotion:
			var logger = GameManager.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info(
					(
						"[EnemyAnimComp] Lazy-loaded anim_player: "
						+ " "
						+ str(_anim_player.get_path())
					),
					"Enemy"
				)

			# Setup locomotion blend tree
			_locomotion = LocomotionBlendTree.new()
			_locomotion.name = "LocomotionBlendTree"
			add_child(_locomotion)

			# Get skeleton from visuals
			var skeleton: Skeleton3D = _enemy.visuals.skeleton if _enemy.visuals else null
			# CRITICAL: Pass visuals so LocomotionBlendTree uses AnimationTree
			_locomotion.setup(_anim_player, skeleton, _enemy.visuals)

	if not _anim_player or not _locomotion:
		return

	_update_locomotion(delta)


func _update_locomotion(_delta: float) -> void:
	# Don't interrupt priority animations (attacks, pain, death)
	var current_anim: String = _anim_player.current_animation
	if (
		current_anim
		in [
			"Punch_Jab",
			"Punch_Cross",
			"Kick",
			"Sword_Attack",
			"Sword_Attack_RM",
			"Hit_Chest",
			"Hit_Head",
			"Hit_Stomach",
			"Hit_Shoulder_L",
			"Hit_Shoulder_R",
			"Death01",
			"Death02"
		]
	):
		return

	# Calculate movement parameters
	var h_velocity: Vector2 = Vector2(_enemy.velocity.x, _enemy.velocity.z)
	var h_speed: float = h_velocity.length()

	# Calculate movement direction (normalized, relative to enemy facing)
	var move_dir: Vector2 = Vector2.ZERO
	if h_speed > 0.1:
		# Get forward direction in XZ plane
		var forward: Vector3 = -_enemy.global_transform.basis.z
		var forward_2d: Vector2 = Vector2(forward.x, forward.z).normalized()

		# Get velocity direction in XZ plane
		var vel_2d: Vector2 = h_velocity.normalized()

		# Calculate relative direction (-1 to 1 for forward/back, left/right)
		# Forward is negative Y in direction space
		move_dir.y = -vel_2d.dot(forward_2d)
		# Right is positive X
		var right_2d: Vector2 = Vector2(forward_2d.y, -forward_2d.x)
		move_dir.x = vel_2d.dot(right_2d)

	# Determine if enemy is crouching (some enemies might crouch in cover)
	var is_crouching: bool = false
	if _enemy.has_method("get") and "is_in_cover" in _enemy:
		is_crouching = _enemy.is_in_cover

	# Enemies don't sprint by default (could be added for special enemy types)
	var is_sprinting: bool = false

	# Update locomotion system
	_locomotion.update_locomotion(
		h_speed, move_dir, _enemy.is_on_floor(), is_crouching, is_sprinting, _enemy.velocity.y
	)


## Play one-shot animation (attacks, pain, etc.)
func play_oneshot(anim_name: String, blend_time: float = 0.1) -> void:
	if _locomotion:
		_locomotion.play_oneshot(anim_name, blend_time)
	elif _anim_player:
		_anim_player.play(anim_name, blend_time)


## Play attack animation
func play_attack(attack_type: String = "melee") -> void:
	match attack_type:
		"melee":
			# Alternate between jab and cross
			if randf() > 0.5:
				play_oneshot("Punch_Jab", 0.05)
			else:
				play_oneshot("Punch_Cross", 0.05)
		"sword":
			play_oneshot("Sword_Attack", 0.05)
		"kick":
			play_oneshot("Kick", 0.05)
		_:
			play_oneshot("Punch_Jab", 0.05)


## Play pain/hit animation
func play_pain(hit_location: String = "chest") -> void:
	var anim_name: String = "Hit_Chest"

	match hit_location.to_lower():
		"head":
			anim_name = "Hit_Head"
		"stomach", "gut":
			anim_name = "Hit_Stomach"
		"shoulder_left", "arm_left":
			anim_name = "Hit_Shoulder_L"
		"shoulder_right", "arm_right":
			anim_name = "Hit_Shoulder_R"
		_:
			anim_name = "Hit_Chest"

	play_oneshot(anim_name, 0.05)


## Play death animation
func play_death() -> void:
	# Random death animation
	var death_anims: Array[String] = ["Death01", "Death02"]
	play_oneshot(death_anims[randi() % death_anims.size()], 0.05)


## Get current locomotion state for debugging
func get_current_state() -> String:
	if _locomotion:
		return _locomotion.get_current_state_name()
	return "Unknown"


## Stop all animations
func stop() -> void:
	if _anim_player:
		_anim_player.stop()
