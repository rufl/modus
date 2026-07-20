extends MeshInstance3D
class_name BloodPool

@export var pool_size: int = 64
@export var growing_time: float = 0.2
@export var drying_time: float = 4.0
@export var delay_until_drying_starts: float = 0.2

var _mat: ShaderMaterial
var _bloody_pool: Array[BloodDrop]


func _ready() -> void:
	_mat = get_active_material(0) as ShaderMaterial
	if not _mat:
		push_warning("[BloodPool] No ShaderMaterial found")
		return

	var positions: PackedVector2Array = []
	positions.resize(pool_size)
	_mat.set_shader_parameter("positions", positions)

	var scales: PackedFloat32Array = []
	scales.resize(pool_size)
	_mat.set_shader_parameter("scales", scales)

	BloodDrop.mat = _mat
	for i in pool_size:
		_bloody_pool.append(BloodDrop.new(i))


func drop_at(pos: Vector2) -> void:
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


func drop_at_world(world_pos: Vector3) -> void:
	var local_pos: Vector3 = to_local(world_pos)
	var plane_mesh: PlaneMesh = mesh as PlaneMesh
	if plane_mesh:
		var uv_x: float = (local_pos.x / plane_mesh.size.x) + 0.5
		var uv_y: float = (local_pos.z / plane_mesh.size.y) + 0.5
		drop_at(Vector2(uv_x, uv_y))
	else:
		drop_at(Vector2(0.5, 0.5))


class BloodDrop:
	var active: bool
	var _index: int
	static var mat: ShaderMaterial

	func _init(index: int) -> void:
		_index = index

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
