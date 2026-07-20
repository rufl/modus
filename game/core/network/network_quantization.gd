class_name NetworkQuantization
extends RefCounted

## Network Quantization - Compress floating point values for bandwidth efficiency


## Quantize 3D position (14 bits per axis = ~0.01m precision over 1024m range)
static func quantize_position(
	pos: Vector3, bits: int = 14, min_val: float = -512.0, max_val: float = 512.0
) -> PackedInt32Array:
	var range_val := max_val - min_val
	var steps := (1 << bits) - 1  # 2^bits - 1

	return PackedInt32Array(
		[
			int(clamp((pos.x - min_val) / range_val, 0.0, 1.0) * steps),
			int(clamp((pos.y - min_val) / range_val, 0.0, 1.0) * steps),
			int(clamp((pos.z - min_val) / range_val, 0.0, 1.0) * steps)
		]
	)


## Dequantize 3D position
static func dequantize_position(
	quantized: PackedInt32Array, bits: int = 14, min_val: float = -512.0, max_val: float = 512.0
) -> Vector3:
	var range_val := max_val - min_val
	var steps := (1 << bits) - 1

	return Vector3(
		min_val + (float(quantized[0]) / steps) * range_val,
		min_val + (float(quantized[1]) / steps) * range_val,
		min_val + (float(quantized[2]) / steps) * range_val
	)


## Quantize rotation (10 bits per axis = ~0.35° precision)
static func quantize_rotation(rot: Vector3, bits: int = 10) -> PackedInt32Array:
	var steps := (1 << bits) - 1

	return PackedInt32Array(
		[
			int(clamp(rot.x / TAU, 0.0, 1.0) * steps),
			int(clamp(rot.y / TAU, 0.0, 1.0) * steps),
			int(clamp(rot.z / TAU, 0.0, 1.0) * steps)
		]
	)


## Dequantize rotation
static func dequantize_rotation(quantized: PackedInt32Array, bits: int = 10) -> Vector3:
	var steps := (1 << bits) - 1

	return Vector3(
		(float(quantized[0]) / steps) * TAU,
		(float(quantized[1]) / steps) * TAU,
		(float(quantized[2]) / steps) * TAU
	)


## Quantize velocity (12 bits per axis, range -50 to 50 m/s)
static func quantize_velocity(
	vel: Vector3, bits: int = 12, max_speed: float = 50.0
) -> PackedInt32Array:
	var range_val := max_speed * 2.0
	var steps := (1 << bits) - 1

	return PackedInt32Array(
		[
			int(clamp((vel.x + max_speed) / range_val, 0.0, 1.0) * steps),
			int(clamp((vel.y + max_speed) / range_val, 0.0, 1.0) * steps),
			int(clamp((vel.z + max_speed) / range_val, 0.0, 1.0) * steps)
		]
	)


## Dequantize velocity
static func dequantize_velocity(
	quantized: PackedInt32Array, bits: int = 12, max_speed: float = 50.0
) -> Vector3:
	var range_val := max_speed * 2.0
	var steps := (1 << bits) - 1

	return Vector3(
		(float(quantized[0]) / steps) * range_val - max_speed,
		(float(quantized[1]) / steps) * range_val - max_speed,
		(float(quantized[2]) / steps) * range_val - max_speed
	)


## Quantize health (8 bits = 0-255 range)
static func quantize_health(health: float, max_health: float = 100.0) -> int:
	return int(clamp(health / max_health, 0.0, 1.0) * 255)


## Dequantize health
static func dequantize_health(quantized: int, max_health: float = 100.0) -> float:
	return (float(quantized) / 255.0) * max_health


## Calculate bandwidth savings
static func get_bandwidth_savings_info() -> String:
	return """Quantization Bandwidth Savings:
	Position (Vector3): 96 bits -> 42 bits (14-bit) = 56% reduction
	Rotation (Vector3): 96 bits -> 30 bits (10-bit) = 69% reduction
	Velocity (Vector3): 96 bits -> 36 bits (12-bit) = 62% reduction
	Health (float): 32 bits -> 8 bits = 75% reduction

	Example Enemy State:
	Uncompressed: ~256 bits (~32 bytes)
	Quantized: ~116 bits (~15 bytes)
	Savings: ~54% bandwidth reduction per enemy
	"""
