extends SceneTree


func _init() -> void:
	# This reference contains only the exported hierarchy, not the runtime mannequin rig.
	# Keep it independent of SkeletalCharacterVisuals and its removed procedural builders.
	var document: Dictionary = {
		"asset":
		{
			"generator": "MODUS procedural hierarchy reference exporter",
			"version": "2.0",
		},
		"extensionsUsed": ["GODOT_single_root"],
		"nodes":
		[
			{"children": [1], "name": "ProceduralCharacter"},
			{"name": "SkeletalVisuals"},
		],
		"scene": 0,
		"scenes": [{"nodes": [0]}],
	}
	# A hierarchy has no binary data: omit buffers and the optional BIN chunk entirely.
	# Writing this JSON-only GLB avoids the engine exporter's empty-buffer metadata.
	var json_bytes: PackedByteArray = JSON.stringify(document).to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)

	var output_path: String = "res://game/art/models/skel/procedural_reference.glb"
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("[Exporter] Cannot open reference output: %s" % FileAccess.get_open_error())
		quit(1)
		return

	file.store_32(0x46546C67)  # glTF magic, little-endian.
	file.store_32(2)
	file.store_32(20 + json_bytes.size())  # 12-byte header and 8-byte JSON chunk header.
	file.store_32(json_bytes.size())
	file.store_32(0x4E4F534A)  # JSON chunk; no BIN chunk follows.
	file.store_buffer(json_bytes)
	file.flush()
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		push_error("[Exporter] Cannot write reference output: %s" % err)
		quit(1)
		return

	print("[Exporter] Wrote hierarchy reference: " + output_path)
	quit(0)
