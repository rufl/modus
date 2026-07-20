class_name SoundGenerator
extends RefCounted

const SAMPLE_RATE: int = 44100


static func _create_stream_with_buffer(length: float) -> Dictionary:
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)  # 2 bytes per 16-bit sample
	buffer.fill(0)
	return {"buffer": buffer, "num_samples": num_samples, "length": length}


# Helper to finalize stream from buffer


static func _finalize_stream(buffer: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = buffer
	return stream


static func generate_shoot_sound(pitch_scale: float = 1.0) -> AudioStreamWAV:
	var length: float = 0.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	var frequency: float = 400.0 * pitch_scale

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var current_freq := frequency * maxf(0.0, 1.0 - (t * 4.0))
		phase += current_freq / float(SAMPLE_RATE)
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var noisy := randf() * 2.0 - 1.0
		var signal_val := lerpf(saw, noisy, 0.5)
		var decay := pow(maxf(0.0, 1.0 - (t / length)), 2.0)
		var sample := int(clampf(signal_val * decay * 0.5 * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_hit_sound() -> AudioStreamWAV:
	var length := 0.1
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var signal_val := (randf() * 2.0 - 1.0) * (1.0 - t / length) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_crit_sound() -> AudioStreamWAV:
	var length := 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var freq := 1200.0 if fmod(t, 0.05) < 0.025 else 800.0
		phase += freq / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * (1.0 - t / length) * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_footstep_sound(material: String = "concrete") -> AudioStreamWAV:
	var length := 0.08
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var low_pass: float = 0.0
	var filter: float = 0.5
	var vol: float = 0.2
	match material:
		"metal":
			filter = 0.2
			vol = 0.25
		"wood":
			filter = 0.7
			vol = 0.3
		"grass", "dirt":
			filter = 0.8
			vol = 0.4

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		low_pass = lerpf(low_pass, randf() * 2.0 - 1.0, 1.0 - filter)
		var signal_val := low_pass * (1.0 - t / length) * vol
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_jump_sound() -> AudioStreamWAV:
	var length := 0.15
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (100.0 + t * 600.0) / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * (1.0 - t / length) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_land_sound() -> AudioStreamWAV:
	var length := 0.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.1)
		var signal_val := lp * (1.0 - t / length) * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_ui_sound(type: String = "click") -> AudioStreamWAV:
	var length := 0.05 if type == "click" else 0.02
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	var freq := 1200.0 if type == "click" else 800.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += freq / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * (1.0 - t / length) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_weapon_switch_sound() -> AudioStreamWAV:
	var length := 0.1
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (200.0 if t < 0.05 else 400.0) / float(SAMPLE_RATE)
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var noisy := randf() * 2.0 - 1.0
		var mixture := lerpf(saw, noisy, 0.5)
		var signal_val := mixture * (1.0 - t / length) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_reload_sound(weapon_name: String = "pistol") -> AudioStreamWAV:
	var length := 0.6
	var w_lower := weapon_name.to_lower()
	if "shotgun" in w_lower:
		length = 0.8
	elif "rocket" in w_lower:
		length = 1.0
	elif "machine" in w_lower:
		length = 1.2

	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var signal_val := 0.0
		var noise := randf() * 2.0 - 1.0

		# 1. Mag out / slide open (start) - Metallic scrape
		if t < 0.15:
			var sub_t := t / 0.15
			signal_val += noise * (1.0 - sub_t) * 0.2
			phase += 800.0 / float(SAMPLE_RATE)
			signal_val += sin(phase * TAU) * 0.1 * (1.0 - sub_t)

		# 2. Mag in / Shell load (middle) - Thump
		var mid_start := length * 0.4
		var mid_end := length * 0.6
		if t > mid_start and t < mid_end:
			var sub_t := (t - mid_start) / (mid_end - mid_start)
			signal_val += noise * sin(sub_t * PI) * 0.3
			phase += 150.0 / float(SAMPLE_RATE)
			signal_val += sin(phase * TAU) * 0.2 * sin(sub_t * PI)

		# 3. Slide release / bolt snap (end) - Sharp click
		var end_time := length - 0.12
		if t > end_time:
			var sub_t := (t - end_time) / 0.12
			phase += 3000.0 / float(SAMPLE_RATE)
			signal_val += (noise * 0.3 + sin(phase * TAU) * 0.7) * exp(-sub_t * 30.0) * 0.6

		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_pickup_sound() -> AudioStreamWAV:
	var length := 0.25
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (523.0 + t * 2000.0) / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * (1.0 - t / length) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_enemy_alert_sound() -> AudioStreamWAV:
	var length := 0.3
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (400.0 + t * 800.0) / float(SAMPLE_RATE)
		var signal_val := (fmod(phase, 1.0) * 2.0 - 1.0) * (1.0 - t / length) * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_enemy_nearby_sound() -> AudioStreamWAV:
	var length := 0.8
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.05 + 0.04 * sin(t * TAU * 1.5))
		var signal_val := lp * sin(t / length * PI) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_flesh_impact_sound() -> AudioStreamWAV:
	var length := 0.15
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.1)
		var noise := (randf() * 2.0 - 1.0) * 0.1 * maxf(0.0, 1.0 - t * 10.0)
		var signal_val := (lp + noise) * (1.0 - t / length) * 0.6
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_whoosh_sound() -> AudioStreamWAV:
	var length := 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var bp: float = 0.0
	var bpv: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var sweep := sin(t / length * PI)
		bpv += (randf() * 2.0 - 1.0 - bp) * (0.05 + 0.15 * sweep)
		bp += bpv
		bpv *= 0.8
		var signal_val := bp * sweep * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_dash_sound() -> AudioStreamWAV:
	var length := 0.25
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.1 + 0.4 * (1.0 - t / length))
		var signal_val := lp * pow(1.0 - t / length, 1.5) * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_rocket_launch_sound() -> AudioStreamWAV:
	var length := 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.05)
		phase += (120.0 * maxf(0.01, 1.0 - t * 2.5)) / float(SAMPLE_RATE)
		var signal_val := lerpf(sin(phase * TAU), lp, 0.6) * (1.0 - t / length) * 0.7
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_grenade_launch_sound() -> AudioStreamWAV:
	var length := 0.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (200.0 * (1.0 + sin(t * 100.0) * 0.1)) / float(SAMPLE_RATE)
		var noise := randf() * 2.0 - 1.0
		var decay_noise := 0.3 * maxf(0.0, 1.0 - t * 15.0)
		var mixture := lerpf(sin(phase * TAU), noise, decay_noise)
		var signal_val := mixture * (1.0 - t / length) * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_grenade_bounce_sound() -> AudioStreamWAV:
	var length := 0.06
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += 1500.0 / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * (1.0 - t / length) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_hurt_sound(is_enemy: bool = false) -> AudioStreamWAV:
	var length := 0.25 if not is_enemy else 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var freq: float = (80.0 + t * 40.0) if is_enemy else (150.0 - t * 50.0)
		phase += freq / float(SAMPLE_RATE)
		var noise := (randf() * 2.0 - 1.0) * (0.5 if is_enemy else 0.2)
		var signal_val := (sin(phase * TAU) + noise) * sin(t / length * PI) * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_explosion_sound(is_rocket: bool = false) -> AudioStreamWAV:
	var length := 1.5 if is_rocket else 1.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	var lp_mid: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := randf() * 2.0 - 1.0

		# Sharp initial transient (distorted crack)
		var crackle := 0.0
		if t < 0.05:
			crackle = clampf(noise * 10.0, -1.0, 1.0) * (1.0 - t / 0.05)

		# Heavy thumping punch (Low frequency)
		lp = lerpf(lp, noise, 0.2 * exp(-t * 10.0) + 0.01)

		# Mid-range blast noise
		lp_mid = lerpf(lp_mid, noise, 0.1 * exp(-t * 2.0) + 0.05)

		var blast := lp_mid * 0.6
		var thump := lp * 0.8

		var signal_val := crackle * 0.4 + blast + thump

		# Master envelope
		var env := pow(maxf(0.0, 1.0 - t / length), 1.5)
		signal_val *= env * 0.8

		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_rocket_impact_sound(material: String = "generic") -> AudioStreamWAV:
	var length := 1.8
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := randf() * 2.0 - 1.0

		# Base explosion component
		lp = lerpf(lp, noise, 0.1 * exp(-t * 2.0) + 0.02)
		var base := lp * pow(maxf(0.0, 1.0 - t / length), 2.0)

		# Material specific impact "ring" or "crunch"
		var specific := 0.0
		match material:
			"metal":
				phase += 1200.0 / float(SAMPLE_RATE)
				specific = sin(phase * TAU) * exp(-t * 15.0) * 0.4
			"stone", "concrete":
				specific = (randf() * 2.0 - 1.0) * exp(-t * 8.0) * 0.6
			"wood":
				phase += 300.0 / float(SAMPLE_RATE)
				specific = sin(phase * TAU) * exp(-t * 10.0) * 0.5

		var signal_val := (base + specific) * 0.8
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_impact_sound(material: String = "generic") -> AudioStreamWAV:
	var length := 0.15
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	var filter: float = 0.4
	if material == "metal":
		filter = 0.2
	elif material == "stone":
		filter = 0.6

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 1.0 - filter)
		var signal_val := lp * (1.0 - t / length) * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_grenade_ping_sound() -> AudioStreamWAV:
	var length := 0.05
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += 2500.0 / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * (1.0 - t / length) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_projectile_pass_sound(is_enemy: bool = false) -> AudioStreamWAV:
	var length := 0.6
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var bp: float = 0.0
	var bpv: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		# Doppler-like sweep (high to low)
		var sweep := 1.0 - (t / length)
		var freq := (0.1 if not is_enemy else 0.05) + (0.3 * sweep)
		bpv += (randf() * 2.0 - 1.0 - bp) * freq
		bp += bpv
		bpv *= 0.85
		var env := sin(t / length * PI)
		var signal_val := bp * env * 0.6
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_projectile_loop_sound(is_enemy: bool = false) -> AudioStreamWAV:
	var length := 0.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var filter := 0.05 if not is_enemy else 0.02
		lp = lerpf(lp, randf() * 2.0 - 1.0, filter)
		var signal_val := lp * (0.3 if not is_enemy else 0.5)
		if is_enemy:
			signal_val += sin(t * 80.0 * TAU) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	var stream := _finalize_stream(buffer)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream


static func generate_player_death_sound() -> AudioStreamWAV:
	var length := 1.0
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.05)
		phase += (150.0 * maxf(0.1, 1.0 - t)) / float(SAMPLE_RATE)
		var signal_val := (sin(phase * TAU) + lp * 0.3) * (1.0 - t / length) * 0.6
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_downed_sound() -> AudioStreamWAV:
	var length := 1.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var pulse := 0.5 + 0.5 * sin(t * TAU * 2.0)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.01)
		var signal_val := (lp + sin(t * 1000.0 * TAU) * 0.05) * pulse * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_enemy_death_sound() -> AudioStreamWAV:
	var length := 0.6
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.2 * (1.0 - t / length))
		var signal_val := lp * pow(1.0 - t / length, 2.0) * 0.7
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_heartbeat_sound() -> AudioStreamWAV:
	var length := 1.0
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var pulse := 0.0
		if fmod(t, 1.0) < 0.1:
			pulse = sin((t / 0.1) * PI)
		elif fmod(t, 1.0) < 0.3 and fmod(t, 1.0) > 0.2:
			pulse = sin(((t - 0.2) / 0.1) * PI) * 0.7

		phase += 60.0 / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * pulse * 0.8
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_ammo_low_sound() -> AudioStreamWAV:
	var length := 0.05
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var signal_val := (randf() * 2.0 - 1.0) * (1.0 - t / length) * 0.1
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_teleport_sound() -> AudioStreamWAV:
	var length := 0.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (1000.0 * sin(t * TAU * 10.0) + 2000.0) / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * sin(t / length * PI) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_gib_sound() -> AudioStreamWAV:
	var length := 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := randf() * 2.0 - 1.0
		lp = lerpf(lp, noise, 0.15)
		var squelch := randf() * 0.4 * maxf(0.0, 1.0 - t * 8.0)
		var signal_val := (lp + squelch) * pow(1.0 - t / length, 1.2) * 0.9
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_teleport_hum_sound(is_slipgate: bool = false) -> AudioStreamWAV:
	var length := 1.0
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase_base: float = 0.0
	var phase_mod: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var base_freq := 40.0 if is_slipgate else 60.0
		phase_base += base_freq / float(SAMPLE_RATE)

		var hum := sin(phase_base * TAU) * 0.4
		hum += sin(phase_base * 2.0 * TAU) * 0.2

		var lfo_freq := 0.2 if is_slipgate else 0.5
		var lfo := sin(t * TAU * lfo_freq)
		var res_freq := 400.0 if is_slipgate else 800.0
		var res_mod := 100.0 if is_slipgate else 200.0

		phase_mod += (res_freq + lfo * res_mod) / float(SAMPLE_RATE)
		var shimmer := sin(phase_mod * TAU) * (0.15 if is_slipgate else 0.1)

		var signal_val := (hum + shimmer) * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	var stream := _finalize_stream(buffer)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream


static func generate_door_sound(is_opening: bool) -> AudioStreamWAV:
	var length := 1.0 if is_opening else 1.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.05 if is_opening else 0.03)
		var rumble := sin(t * TAU * 40.0) * 0.4
		var env := 1.0 if is_opening else (1.0 if t < 1.0 else maxf(0.0, 1.2 - t) * 10.0)
		var signal_val := (lp + rumble) * env * 0.5
		if not is_opening and t > 0.95:
			signal_val += (randf() * 2.0 - 1.0) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_switch_mechanical_sound() -> AudioStreamWAV:
	var length := 0.15
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (200.0 if t < 0.05 else 50.0) / float(SAMPLE_RATE)
		var signal_val := (fmod(phase, 1.0) * 2.0 - 1.0) * (1.0 - t / length) * 0.5
		signal_val += (randf() * 2.0 - 1.0) * maxf(0.0, 1.0 - t * 20.0) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_secret_found_sound() -> AudioStreamWAV:
	var length := 1.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var signal_val := 0.0
		var note_times := [0.0, 0.1, 0.2, 0.3]
		var notes := [880.0, 1108.7, 1318.5, 1760.0]
		for j in range(4):
			if t >= note_times[j]:
				signal_val += sin(t * notes[j] * TAU) * exp(-(t - note_times[j]) * 15.0) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_liquid_splash_sound() -> AudioStreamWAV:
	var length := 0.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.1)
		var signal_val := lp * pow(1.0 - t / length, 1.5) * 0.6
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_vocal_pain_sound(is_heavy: bool) -> AudioStreamWAV:
	var length := 0.3 if not is_heavy else 0.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var base_f := 100.0 if is_heavy else 150.0
		phase += (base_f + sin(t * TAU * 5.0) * 10.0) / float(SAMPLE_RATE)
		var vox := sin(phase * TAU) + sin(phase * 2.0 * TAU) * 0.5
		var formants := sin(phase * 5.0 * TAU) * 0.3 + sin(phase * 8.0 * TAU) * 0.2
		var decay := 1.0 - t / length
		var signal_val := (vox + formants + randf() * 0.2) * decay * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_low_health_breath_sound() -> AudioStreamWAV:
	var length := 1.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var lp: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(t / length * PI) * maxf(0.0, sin(t * TAU * 0.66))
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.05)
		var signal_val := lp * env * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_powerup_active_loop_sound() -> AudioStreamWAV:
	var length := 0.5
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (60.0 + sin(t * TAU * 2.0) * 20.0) / float(SAMPLE_RATE)
		var signal_val := (sin(phase * TAU) + sin(phase * 1.5 * TAU) * 0.5) * 0.3
		signal_val += (randf() * 2.0 - 1.0) * 0.05
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	var stream := _finalize_stream(buffer)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream


static func generate_shell_casing_sound() -> AudioStreamWAV:
	var length := 0.1
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += 3000.0 / float(SAMPLE_RATE)
		var signal_val := sin(phase * TAU) * exp(-t * 40.0) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_energy_loop_sound() -> AudioStreamWAV:
	var length := 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (400.0 + sin(t * TAU * 10.0) * 50.0) / float(SAMPLE_RATE)
		var signal_val := (sin(phase * TAU) * sin(t * TAU * 5.0) + randf() * 0.1) * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	var stream := _finalize_stream(buffer)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream


static func generate_saw_loop_sound() -> AudioStreamWAV:
	var length := 0.3
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		phase += (80.0 + randf() * 10.0) / float(SAMPLE_RATE)
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var signal_val := (saw + (randf() * 2.0 - 1.0) * 0.5) * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	var stream := _finalize_stream(buffer)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream


static func generate_kill_confirm_sound() -> AudioStreamWAV:
	var length := 0.08
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		phase += 1200.0 / float(SAMPLE_RATE)
		var signal_val := (sin(phase * TAU) * (1.0 - t / length) + randf() * 0.1) * 0.3
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_timer_beep_sound(is_final: bool) -> AudioStreamWAV:
	var length := 0.1
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	var freq := 1000.0 if not is_final else 2000.0
	for i in range(num_samples):
		phase += freq / float(SAMPLE_RATE)
		var signal_val := (1.0 if fmod(phase, 1.0) > 0.5 else -1.0) * 0.2
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


# Breakable object sounds (consolidated from procedural_sound_generator.gd)


static func generate_glass_shatter() -> AudioStreamWAV:
	var length := 0.3
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := exp(-t * 15.0)  # Fast decay

		# High-frequency noise (2-8 kHz range)
		var noise := randf() * 2.0 - 1.0
		var filtered := noise * envelope

		# Add some tonal component (glass resonance)
		phase += randf_range(3000, 5000) / float(SAMPLE_RATE)
		var tone := sin(phase * TAU) * 0.3

		var signal_val := (filtered + tone * envelope) * 0.5
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_wood_crack() -> AudioStreamWAV:
	var length := 0.4
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := exp(-t * 8.0)  # Medium decay

		# Mid-frequency noise (500-2000 Hz)
		var noise := randf() * 2.0 - 1.0

		# Add crack transient at start
		var crack := 0.0
		if t < 0.05:
			crack = sin(t * TAU * 800) * (1.0 - t / 0.05) * 2.0

		# Wood resonance
		phase += randf_range(400, 800) / float(SAMPLE_RATE)
		var tone := sin(phase * TAU) * 0.4

		var signal_val := (noise * 0.3 + crack + tone * envelope) * envelope * 0.6
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_metal_clang() -> AudioStreamWAV:
	var length := 0.8
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := exp(-t * 3.0)  # Slow decay (metal rings)

		# Impact transient
		var impact := 0.0
		if t < 0.02:
			impact = (randf() * 2.0 - 1.0) * (1.0 - t / 0.02) * 3.0

		# Metal resonance (multiple frequencies)
		phase1 += 1200.0 / float(SAMPLE_RATE)
		phase2 += 2400.0 / float(SAMPLE_RATE)
		phase3 += 3600.0 / float(SAMPLE_RATE)
		var ring := sin(phase1 * TAU) * 0.4 + sin(phase2 * TAU) * 0.3 + sin(phase3 * TAU) * 0.2

		var signal_val := (impact + ring * envelope) * 0.4
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)


static func generate_breakable_explosion() -> AudioStreamWAV:
	var length := 1.2
	var num_samples: int = int(length * SAMPLE_RATE)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(num_samples * 2)

	var phase1: float = 0.0
	var phase2: float = 0.0
	for i in range(num_samples):
		var t := float(i) / float(SAMPLE_RATE)

		# Two-stage envelope: fast attack, slow decay
		var envelope := 0.0
		if t < 0.05:
			envelope = t / 0.05  # Attack
		else:
			envelope = exp(-(t - 0.05) * 2.5)  # Decay

		# Low-frequency boom
		phase1 += 60.0 / float(SAMPLE_RATE)
		var boom := sin(phase1 * TAU) * exp(-t * 10.0) * 0.8

		# Mid rumble
		phase2 += 120.0 / float(SAMPLE_RATE)
		var rumble := sin(phase2 * TAU) * exp(-t * 5.0) * 0.5

		# Noise tail
		var noise := (randf() * 2.0 - 1.0) * 0.3 * envelope

		var signal_val := (boom + rumble + noise) * envelope * 0.7
		var sample := int(clampf(signal_val * 32767.0, -32768, 32767))
		buffer.encode_s16(i * 2, sample)

	return _finalize_stream(buffer)
