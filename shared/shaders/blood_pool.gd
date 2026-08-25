extends MeshInstance3D
class_name BloodPoolShader

## Shader-based blood pool system with animated blood drops
## Based on the Bloody Pool shader from godotshaders.com by dip000
## Content rephrased for compliance with licensing restrictions

@export var pool_size: int = 64  ## Must match TOTAL_BLOOD_DROPS in shader
@export var growing_time: float = 0.2  ## Time for blood drop to grow
@export var drying_time: float = 4.0  ## Time for blood drop to dry
@export var delay_until_drying_starts: float = 0.2  ## Idle time when fully grown

@onready var _mat: ShaderMaterial = get_active_material(0)
var _bloody_pool: Array[BloodDrop]


func _ready() -> void:
	if not _mat:
		push_error("[BloodPoolShader] A ShaderMaterial is required on surface 0")
		return

	# Initialize shader arrays
	var positions: PackedVector2Array = []
	positions.resize(pool_size)
	_mat.set_shader_parameter("positions", positions)

	var scales: PackedFloat32Array = []
	scales.resize(pool_size)
	_mat.set_shader_parameter("scales", scales)

	# Setup blood drop pool
	for i in pool_size:
		_bloody_pool.append(BloodDrop.new(i, _mat))


## Spawn a blood drop at the given 2D position (UV coordinates)
func drop_at(pos: Vector2) -> void:
	# Find inactive blood drop to reuse
	for blood_drop in _bloody_pool:
		if not blood_drop.active:
			blood_drop.start(pos)
			var tween: Tween = get_tree().create_tween()
			tween.tween_method(blood_drop.animate, 0.0, growing_time, growing_time)
			tween.tween_method(blood_drop.animate, growing_time, 0.0, drying_time).set_delay(
				delay_until_drying_starts
			)
			tween.finished.connect(blood_drop.end)
			break


class BloodDrop:
	var active: bool
	var _index: int
	var mat: ShaderMaterial

	func _init(index: int, material: ShaderMaterial) -> void:
		_index = index
		mat = material

	func start(pos: Vector2) -> void:
		active = true
		var positions: PackedVector2Array = mat.get_shader_parameter("positions")
		if positions.size() > _index:
			positions[_index] = pos
			mat.set_shader_parameter("positions", positions)

	func animate(value: float) -> void:
		var scales: PackedFloat32Array = mat.get_shader_parameter("scales")
		if scales.size() > _index:
			scales[_index] = value
			mat.set_shader_parameter("scales", scales)

	func end() -> void:
		active = false
