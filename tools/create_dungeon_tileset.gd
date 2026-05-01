extends SceneTree

const CELL_SIZE := 128
const TILE_EXTRUSION := 2
const TILE_SOURCE_DUNGEON := 0
const TILE_FLOOR := Vector2i(0, 0)
const TILE_WALL := Vector2i(1, 0)
const TILE_WATER := Vector2i(2, 0)
const TILE_DOOR := Vector2i(3, 0)

const TILE_SET_PATH := "res://assets/tiles/dungeon/tileset.tres"
const TILE_ATLAS_PATH := "res://assets/tiles/dungeon/atlas.png"
const FLOOR_PATH := "res://assets/tiles/dungeon/floor.png"
const WALL_PATH := "res://assets/tiles/dungeon/wall.png"
const WATER_PATH := "res://assets/tiles/dungeon/water.png"
const DOOR_PATH := "res://assets/tiles/dungeon/door.png"


func _init() -> void:
	_save_atlas()

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	_add_dungeon_source(tile_set)

	var err := ResourceSaver.save(tile_set, TILE_SET_PATH)
	if err != OK:
		push_error("Could not save tile set: %s" % error_string(err))
		quit(1)
		return

	quit()


func _save_atlas() -> void:
	var atlas_size := Vector2i(
		TILE_EXTRUSION * 2 + CELL_SIZE * 4 + TILE_EXTRUSION * 2 * 3,
		TILE_EXTRUSION * 2 + CELL_SIZE
	)
	var atlas := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	_blit_tile(atlas, FLOOR_PATH, TILE_FLOOR)
	_blit_tile(atlas, WALL_PATH, TILE_WALL)
	_blit_tile(atlas, WATER_PATH, TILE_WATER)
	_blit_tile(atlas, DOOR_PATH, TILE_DOOR)

	var err := atlas.save_png(TILE_ATLAS_PATH)
	if err != OK:
		push_error("Could not save tile atlas: %s" % error_string(err))
		quit(1)


func _blit_tile(atlas: Image, texture_path: String, atlas_coords: Vector2i) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
	if image == null:
		push_error("Could not load tile image: %s" % texture_path)
		quit(1)
		return

	if image.get_size() != Vector2i(CELL_SIZE, CELL_SIZE):
		image.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_LANCZOS)
	var target_position := Vector2i(TILE_EXTRUSION, TILE_EXTRUSION)
	target_position += atlas_coords * (CELL_SIZE + TILE_EXTRUSION * 2)
	_blit_extruded_tile(atlas, image, target_position)


func _blit_extruded_tile(atlas: Image, tile: Image, target_position: Vector2i) -> void:
	atlas.blit_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(CELL_SIZE, CELL_SIZE)), target_position)

	for x in range(CELL_SIZE):
		var top: Color = tile.get_pixel(x, 0)
		var bottom: Color = tile.get_pixel(x, CELL_SIZE - 1)
		for offset in range(1, TILE_EXTRUSION + 1):
			atlas.set_pixel(target_position.x + x, target_position.y - offset, top)
			atlas.set_pixel(target_position.x + x, target_position.y + CELL_SIZE - 1 + offset, bottom)

	for y in range(CELL_SIZE):
		var left: Color = tile.get_pixel(0, y)
		var right: Color = tile.get_pixel(CELL_SIZE - 1, y)
		for offset in range(1, TILE_EXTRUSION + 1):
			atlas.set_pixel(target_position.x - offset, target_position.y + y, left)
			atlas.set_pixel(target_position.x + CELL_SIZE - 1 + offset, target_position.y + y, right)

	for offset_y in range(1, TILE_EXTRUSION + 1):
		for offset_x in range(1, TILE_EXTRUSION + 1):
			atlas.set_pixel(target_position.x - offset_x, target_position.y - offset_y, tile.get_pixel(0, 0))
			atlas.set_pixel(target_position.x + CELL_SIZE - 1 + offset_x, target_position.y - offset_y, tile.get_pixel(CELL_SIZE - 1, 0))
			atlas.set_pixel(target_position.x - offset_x, target_position.y + CELL_SIZE - 1 + offset_y, tile.get_pixel(0, CELL_SIZE - 1))
			atlas.set_pixel(target_position.x + CELL_SIZE - 1 + offset_x, target_position.y + CELL_SIZE - 1 + offset_y, tile.get_pixel(CELL_SIZE - 1, CELL_SIZE - 1))


func _add_dungeon_source(tile_set: TileSet) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(TILE_ATLAS_PATH) as Texture2D
	source.margins = Vector2i(TILE_EXTRUSION, TILE_EXTRUSION)
	source.separation = Vector2i(TILE_EXTRUSION * 2, TILE_EXTRUSION * 2)
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	source.create_tile(TILE_FLOOR)
	source.create_tile(TILE_WALL)
	source.create_tile(TILE_WATER)
	source.create_tile(TILE_DOOR)
	tile_set.add_source(source, TILE_SOURCE_DUNGEON)
