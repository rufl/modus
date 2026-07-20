extends Node2D

## Manual Test for Cave System Generator
## Visualizes cave generation with edge smoothing and connections
## Run this scene to see cave generation in action

# Global classes are already available via class_name declarations

@onready var grid_display: ColorRect = $GridDisplay
@onready var info_label: Label = $InfoLabel
@onready var regenerate_button: Button = $RegenerateButton
@onready var cave_bias_slider: HSlider = $CaveBiasSlider
@onready var cave_bias_label: Label = $CaveBiasLabel

var cave_generator: CaveSystemGenerator
var context: GenerationContext
var cell_size := 8  # Pixels per cell for visualization
var current_seed := 0


func _ready() -> void:
	cave_generator = CaveSystemGenerator.new()
	regenerate_button.pressed.connect(_on_regenerate_pressed)
	cave_bias_slider.value_changed.connect(_on_cave_bias_changed)

	# Initialize with default bias
	_on_cave_bias_changed(cave_bias_slider.value)

	# Generate initial caves
	_generate_and_display()


func _generate_and_display() -> void:
	# Initialize context
	context = GenerationContext.new()
	context.grid_size = Vector2i(96, 96)
	context.config = GenerationConfig.new()
	context.config.cave_bias = cave_bias_slider.value
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = current_seed

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		for x in range(context.grid_size.x):
			var cell := Cell.new()
			cell.type = Cell.Type.EMPTY
			row.append(cell)
		context.grid.append(row)

	# Add some rooms to connect to
	_add_test_rooms()

	# Generate caves
	var start_time := Time.get_ticks_msec()
	var cave_areas := cave_generator.generate_cave_areas(context)
	var end_time := Time.get_ticks_msec()

	# Display results
	_render_grid()
	_update_info_label(cave_areas, end_time - start_time)


func _add_test_rooms() -> void:
	# Add a few test rooms for caves to connect to
	# Room 1 (top-left)
	for y in range(10, 20):
		for x in range(10, 20):
			context.grid[y][x].type = Cell.Type.ROOM

	# Room 2 (bottom-right)
	for y in range(70, 80):
		for x in range(70, 80):
			context.grid[y][x].type = Cell.Type.ROOM

	# Hallway connecting them
	for y in range(20, 70):
		for x in range(44, 46):
			context.grid[y][x].type = Cell.Type.HALLWAY


func _render_grid() -> void:
	var image := Image.create(context.grid_size.x, context.grid_size.y, false, Image.FORMAT_RGB8)

	for y in range(context.grid_size.y):
		for x in range(context.grid_size.x):
			var color := _get_cell_color(context.grid[y][x])
			image.set_pixel(x, y, color)

	var texture := ImageTexture.create_from_image(image)

	# Update display
	if grid_display.material == null:
		var canvas_material := CanvasItemMaterial.new()
		canvas_material.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid_display.material = canvas_material

	grid_display.texture = texture
	grid_display.custom_minimum_size = Vector2(
		context.grid_size.x * cell_size, context.grid_size.y * cell_size
	)


func _get_cell_color(cell: Cell) -> Color:
	match cell.type:
		Cell.Type.EMPTY:
			return Color.BLACK
		Cell.Type.ROOM:
			return Color.WHITE
		Cell.Type.HALLWAY:
			return Color.GRAY
		Cell.Type.CAVE:
			# Check if it's a cave entrance
			if cell.metadata.has("is_cave_entrance") and cell.metadata["is_cave_entrance"]:
				return Color.ORANGE  # Highlight cave entrances
			return Color(0.6, 0.4, 0.2)  # Brown for caves
		_:
			return Color.MAGENTA  # Unexpected type


func _update_info_label(cave_areas: Array, generation_time_ms: int) -> void:
	var cave_cell_count := 0
	var entrance_count := 0

	for y in range(context.grid_size.y):
		for x in range(context.grid_size.x):
			if context.grid[y][x].type == Cell.Type.CAVE:
				cave_cell_count += 1
				if context.grid[y][x].metadata.has("is_cave_entrance"):
					if context.grid[y][x].metadata["is_cave_entrance"]:
						entrance_count += 1

	var info_text := "Cave System Generator Test\n"
	info_text += "Seed: %d\n" % current_seed
	info_text += "Cave Bias: %.2f\n" % context.config.cave_bias
	info_text += "Cave Regions: %d\n" % cave_areas.size()
	info_text += "Cave Cells: %d\n" % cave_cell_count
	info_text += "Cave Entrances: %d\n" % entrance_count
	info_text += "Generation Time: %d ms\n" % generation_time_ms
	info_text += "\nColors:\n"
	info_text += "  White = Rooms\n"
	info_text += "  Gray = Hallways\n"
	info_text += "  Brown = Caves\n"
	info_text += "  Orange = Cave Entrances\n"
	info_text += "  Black = Empty"

	info_label.text = info_text


func _on_regenerate_pressed() -> void:
	current_seed += 1
	_generate_and_display()


func _on_cave_bias_changed(value: float) -> void:
	cave_bias_label.text = "Cave Bias: %.2f" % value
