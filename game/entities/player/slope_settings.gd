extends Resource
class_name SlopeSettings

@export_group("Slope Limits")
@export_range(0.0, 90.0, 1.0) var max_angle: float = 45.0
@export_group("Movement Penalties")
@export_range(0.0, 1.0, 0.05) var speed_penalty: float = 0.5
@export_range(0.0, 1.0, 0.05) var jump_penalty: float = 0.3
@export_group("Slide Mechanics")
@export_range(0.0, 1.0, 0.05) var slide_threshold: float = 0.1
@export var enable_slide_on_steep: bool = true
@export var slide_acceleration: float = 10.0
@export_group("Advanced")
@export var stamina_cost_per_second: float = 0.0
@export var enable_debug_visualization: bool = false


func get_speed_multiplier(current_angle: float) -> float:
	## Calculate speed multiplier for given slope angle
	## Returns 1.0 for flat ground, decreases based on angle
	if current_angle <= 0.0:
		return 1.0

	# Calculate how steep this slope is relative to max
	var angle_factor: float = current_angle / max_angle
	var multiplier: float = 1.0 - (angle_factor * speed_penalty)

	return clamp(multiplier, 0.3, 1.0)


func get_jump_multiplier(current_angle: float) -> float:
	## Calculate jump height multiplier for given slope angle
	## Returns 1.0 for flat ground, decreases based on angle
	if current_angle <= 0.0:
		return 1.0

	var angle_factor: float = current_angle / max_angle
	var multiplier: float = 1.0 - (angle_factor * jump_penalty)

	return clamp(multiplier, 0.5, 1.0)


func is_climbable(angle: float) -> bool:
	## Check if a slope angle is climbable
	return angle <= max_angle


func should_slide(angle: float, velocity_magnitude: float) -> bool:
	## Check if player should slide on current slope
	if not enable_slide_on_steep:
		return false

	return angle > max_angle and velocity_magnitude < slide_threshold


func get_slide_velocity(current_velocity: Vector3, floor_normal: Vector3, delta: float) -> Vector3:
	## Calculate slide velocity down a steep slope
	if not enable_slide_on_steep:
		return current_velocity

	# Calculate slide direction (downhill)
	var slide_direction: Vector3 = Vector3.DOWN - floor_normal * Vector3.DOWN.dot(floor_normal)
	slide_direction = slide_direction.normalized()

	# Accelerate in slide direction
	var new_velocity: Vector3 = current_velocity + slide_direction * slide_acceleration * delta

	return new_velocity


func get_stamina_cost(angle: float, delta: float) -> float:
	## Calculate stamina cost for climbing at given angle
	if stamina_cost_per_second <= 0.0:
		return 0.0

	if angle <= 0.0:
		return 0.0

	# Scale cost by slope steepness
	var angle_factor: float = clamp(angle / max_angle, 0.0, 1.0)
	return stamina_cost_per_second * angle_factor * delta


func calculate_floor_angle(floor_normal: Vector3) -> float:
	## Calculate the angle of a floor from its normal (in degrees)
	if floor_normal == Vector3.ZERO:
		return 0.0

	# Angle between floor normal and straight up
	var dot: float = floor_normal.normalized().dot(Vector3.UP)
	return rad_to_deg(acos(clamp(dot, -1.0, 1.0)))


static func create_default() -> SlopeSettings:
	## Create default slope settings
	var settings: SlopeSettings = SlopeSettings.new()
	return settings


static func create_for_heavy_character() -> SlopeSettings:
	## Create settings for heavy characters (lower mobility on slopes)
	var settings: SlopeSettings = SlopeSettings.new()
	settings.max_angle = 35.0
	settings.speed_penalty = 0.6
	settings.jump_penalty = 0.4
	settings.slide_acceleration = 12.0
	return settings


static func create_for_nimble_character() -> SlopeSettings:
	## Create settings for nimble characters (better slope mobility)
	var settings: SlopeSettings = SlopeSettings.new()
	settings.max_angle = 55.0
	settings.speed_penalty = 0.3
	settings.jump_penalty = 0.2
	settings.slide_acceleration = 8.0
	return settings
