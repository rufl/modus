@tool
extends SceneTree

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
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
	noise.seed = 123
	noise.frequency = 0.05

	for y in 256:
		for x in 256:
			var v: float = (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var c: float = 0.4 + v * 0.2
			img.set_pixel(x, y, Color(c, c, c))

	img.save_png(TEXTURE_DIR + "wall_concrete_01.png")


func _generate_metal() -> void:
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var is_border: bool = x < 4 or x > 252 or y < 4 or y > 252
			var c: float = 0.3 if is_border else 0.5
			if x % 64 < 2 or y % 64 < 2:
				c -= 0.1  # Rivets/Panels
			img.set_pixel(x, y, Color(c, c, c + 0.05))

	img.save_png(TEXTURE_DIR + "wall_metal_01.png")


func _generate_tiles() -> void:
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			# Use float to avoid integer division warning, then cast to int
			var tx: int = int(float(x) / 64.0)
			var ty: int = int(float(y) / 64.0)
			var is_check: bool = (tx + ty) % 2 == 0
			var c: float = 0.2 if is_check else 0.4
			if x % 64 < 2 or y % 64 < 2:
				c = 0.1  # Grout
			img.set_pixel(x, y, Color(c, c, c))

	img.save_png(TEXTURE_DIR + "floor_tile_01.png")


func _generate_grating() -> void:
	var img: Image = Image.create(256, 256, true, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var is_hole: bool = (x % 16 < 8) and (y % 16 < 8)
			if is_hole:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(0.2, 0.2, 0.23, 1.0))

	img.save_png(TEXTURE_DIR + "floor_grating_01.png")
