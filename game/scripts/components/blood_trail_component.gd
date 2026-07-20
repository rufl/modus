extends Node
class_name BloodTrailComponent

## Component for entities that leave blood trails
## Attach to characters/enemies that should bleed when moving

@export var enabled: bool = true
@export var spawn_distance: float = 0.5  ## Distance between blood drops
@export var intensity: float = 1.0  ## Blood intensity multiplier
@export var only_when_damaged: bool = true  ## Only bleed when health is low

var _last_blood_position: Vector3 = Vector3.ZERO
var _parent: Node3D
var _effects_service: Node


func _ready() -> void:
	_parent = get_parent() as Node3D
	if not _parent:
		push_error("[BloodTrailComponent] Must be child of Node3D")
		set_process(false)
		return

	_last_blood_position = _parent.global_position

	# Get effects service
	await get_tree().process_frame
	_effects_service = GameManager.get_core_system("effects")


func _physics_process(_delta: float) -> void:
	if not enabled or not _parent or not _effects_service:
		return

	# Check if should bleed
	if only_when_damaged and not _should_bleed():
		return

	# Check distance traveled
	var current_pos: Vector3 = _parent.global_position
	var distance: float = current_pos.distance_to(_last_blood_position)

	if distance >= spawn_distance:
		_spawn_blood(current_pos)
		_last_blood_position = current_pos


func _should_bleed() -> bool:
	# Check if parent has health component
	if _parent.has_method("get_health_percentage"):
		var health_pct: float = _parent.get_health_percentage()
		return health_pct < 0.5  # Bleed when below 50% health

	# Check for health property
	if "health" in _parent and "max_health" in _parent:
		var health_pct: float = float(_parent.health) / float(_parent.max_health)
		return health_pct < 0.5

	# If no health system, always bleed when enabled
	return true


func _spawn_blood(position: Vector3) -> void:
	if _effects_service and _effects_service.has_method("spawn_blood_pool"):
		_effects_service.spawn_blood_pool(position)


## Manually trigger blood spawn
func spawn_blood_at_position(position: Vector3) -> void:
	_spawn_blood(position)


## Enable/disable blood trail
func set_enabled(value: bool) -> void:
	enabled = value


## Set intensity (affects blood amount)
func set_intensity(value: float) -> void:
	intensity = clamp(value, 0.0, 2.0)
