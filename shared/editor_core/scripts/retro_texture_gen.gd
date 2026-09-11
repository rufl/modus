@tool
extends SceneTree


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	print("[%s] %s" % [category, message])


const TEXTURE_DIR: String = "res://shared/editor_core/textures/retro/"


func _init() -> void:
	var dir: DirAccess = DirAccess.open("res://")
	if not dir.dir_exists(TEXTURE_DIR):
		dir.make_dir_recursive(TEXTURE_DIR)

	_generate_concrete()
	_generate_metal()
	_generate_tiles()
	_generate_grating()

	_log("Textures generated successfully as PNG.", "Log")
	quit()


func _generate_concrete() -> void:
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 712
	noise.frequency = 0.045

	for y in 256:
		for x in 256:
			var v: float = (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var base := Color(0.16, 0.19, 0.22)
			var shade: float = 0.06 + v * 0.10
			var seam: bool = x % 64 == 0 or y % 64 == 0
			img.set_pixel(
				x,
				y,
				(
					Color(base.r + shade, base.g + shade, base.b + shade, 1.0)
					if not seam
					else Color(0.07, 0.09, 0.11)
				)
			)

	img.save_png(TEXTURE_DIR + "wall_concrete_01.png")


func _generate_metal() -> void:
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var panel_x: int = x % 64
			var panel_y: int = y % 64
			var seam: bool = panel_x < 3 or panel_y < 3
			var rivet: bool = (panel_x == 8 or panel_x == 56) and (panel_y == 8 or panel_y == 56)
			var base := (
				Color(0.11, 0.16, 0.19)
				if (int(x / 64) + int(y / 64)) % 2 == 0
				else Color(0.14, 0.19, 0.22)
			)
			img.set_pixel(
				x,
				y,
				Color(0.05, 0.08, 0.10) if seam else Color(0.42, 0.30, 0.12) if rivet else base
			)

	img.save_png(TEXTURE_DIR + "wall_metal_01.png")


func _generate_tiles() -> void:
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var tx: int = int(float(x) / 64.0)
			var ty: int = int(float(y) / 64.0)
			var seam: bool = x % 64 < 3 or y % 64 < 3
			var tile := Color(0.12, 0.18, 0.20) if (tx + ty) % 2 == 0 else Color(0.15, 0.22, 0.23)
			img.set_pixel(x, y, Color(0.04, 0.08, 0.09) if seam else tile)

	img.save_png(TEXTURE_DIR + "floor_tile_01.png")


func _generate_grating() -> void:
	var img: Image = Image.create(256, 256, true, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var cell_x: int = x % 16
			var cell_y: int = y % 16
			var is_hole: bool = cell_x >= 5 and cell_x < 13 and cell_y >= 5 and cell_y < 13
			var bar: bool = cell_x < 2 or cell_y < 2
			if is_hole:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif bar:
				img.set_pixel(x, y, Color(0.34, 0.25, 0.12, 1.0))
			else:
				img.set_pixel(x, y, Color(0.15, 0.19, 0.20, 1.0))

	img.save_png(TEXTURE_DIR + "floor_grating_01.png")
