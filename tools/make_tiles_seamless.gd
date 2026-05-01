extends SceneTree

const CELL_SIZE := 128
const SEAM_BLEND_WIDTH := 24

const TILE_JOBS := [
	{
		"source": "res://assets/generation/processed/tiles/dungeon_floor_01.png",
		"target": "res://assets/tileset/floor.png",
	},
	{
		"source": "res://assets/generation/processed/tiles/dungeon_wall_01.png",
		"target": "res://assets/tileset/wall.png",
	},
	{
		"source": "res://assets/generation/processed/tiles/dungeon_water_01.png",
		"target": "res://assets/tileset/water.png",
	},
	{
		"source": "res://assets/generation/processed/tiles/dungeon_door_01.png",
		"target": "res://assets/tileset/door.png",
	},
]


func _init() -> void:
	for job in TILE_JOBS:
		_process_tile(job.source, job.target)
	quit()


func _process_tile(source_path: String, target_path: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if image == null:
		push_error("Could not load tile image: %s" % source_path)
		quit(1)
		return

	image.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_LANCZOS)
	image = _offset_wrapped(image, CELL_SIZE / 2, CELL_SIZE / 2)
	_blend_center_seams(image)
	_match_outer_edges(image)

	var err := image.save_png(ProjectSettings.globalize_path(target_path))
	if err != OK:
		push_error("Could not save seamless tile: %s" % error_string(err))
		quit(1)


func _offset_wrapped(source: Image, offset_x: int, offset_y: int) -> Image:
	var output := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(CELL_SIZE):
		for x in range(CELL_SIZE):
			var source_x := wrapi(x + offset_x, 0, CELL_SIZE)
			var source_y := wrapi(y + offset_y, 0, CELL_SIZE)
			output.set_pixel(x, y, source.get_pixel(source_x, source_y))
	return output


func _blend_center_seams(image: Image) -> void:
	var copy := image.duplicate()
	var center := CELL_SIZE / 2
	var half_width := SEAM_BLEND_WIDTH / 2

	for y in range(CELL_SIZE):
		for x in range(center - half_width, center + half_width):
			var t := float(x - (center - half_width)) / float(SEAM_BLEND_WIDTH - 1)
			var left_sample: Color = copy.get_pixel(wrapi(x - half_width, 0, CELL_SIZE), y)
			var right_sample: Color = copy.get_pixel(wrapi(x + half_width, 0, CELL_SIZE), y)
			image.set_pixel(x, y, left_sample.lerp(right_sample, t))

	copy = image.duplicate()
	for y in range(center - half_width, center + half_width):
		var t := float(y - (center - half_width)) / float(SEAM_BLEND_WIDTH - 1)
		for x in range(CELL_SIZE):
			var top_sample: Color = copy.get_pixel(x, wrapi(y - half_width, 0, CELL_SIZE))
			var bottom_sample: Color = copy.get_pixel(x, wrapi(y + half_width, 0, CELL_SIZE))
			image.set_pixel(x, y, top_sample.lerp(bottom_sample, t))


func _match_outer_edges(image: Image) -> void:
	for y in range(CELL_SIZE):
		var left: Color = image.get_pixel(0, y)
		var right: Color = image.get_pixel(CELL_SIZE - 1, y)
		var average := left.lerp(right, 0.5)
		image.set_pixel(0, y, average)
		image.set_pixel(CELL_SIZE - 1, y, average)

	for x in range(CELL_SIZE):
		var top: Color = image.get_pixel(x, 0)
		var bottom: Color = image.get_pixel(x, CELL_SIZE - 1)
		var average := top.lerp(bottom, 0.5)
		image.set_pixel(x, 0, average)
		image.set_pixel(x, CELL_SIZE - 1, average)
