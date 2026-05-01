extends SceneTree

const TILE_PATHS := [
	"res://assets/tiles/dungeon/floor.png",
	"res://assets/tiles/dungeon/wall.png",
	"res://assets/tiles/dungeon/water.png",
	"res://assets/tiles/dungeon/door.png",
]


func _init() -> void:
	for path in TILE_PATHS:
		_report(path)
	quit()


func _report(path: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var width := image.get_width()
	var height := image.get_height()
	var horizontal := 0.0
	var vertical := 0.0

	for y in range(height):
		horizontal += _color_distance(image.get_pixel(0, y), image.get_pixel(width - 1, y))
	for x in range(width):
		vertical += _color_distance(image.get_pixel(x, 0), image.get_pixel(x, height - 1))

	print("%s edge mismatch: left/right %.4f, top/bottom %.4f" % [
		path,
		horizontal / height,
		vertical / width,
	])


func _color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
