extends SceneTree

const CELL_SIZE := 128
const TILE_SOURCE_DUNGEON := 0
const TILE_FLOOR := Vector2i(0, 0)
const TILE_WALL := Vector2i(1, 0)
const TILE_WATER := Vector2i(2, 0)
const TILE_DOOR := Vector2i(3, 0)

const TILE_SET_PATH := "res://assets/tileset/dungeon_tileset.tres"
const TILE_ATLAS_PATH := "res://assets/tileset/dungeon_tiles.png"
const FLOOR_PATH := "res://assets/tileset/floor.png"
const WALL_PATH := "res://assets/tileset/wall.png"
const WATER_PATH := "res://assets/tileset/water.png"
const DOOR_PATH := "res://assets/tileset/door.png"


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
	var atlas := Image.create(CELL_SIZE * 4, CELL_SIZE, false, Image.FORMAT_RGBA8)
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
	atlas.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(CELL_SIZE, CELL_SIZE)), atlas_coords * CELL_SIZE)


func _add_dungeon_source(tile_set: TileSet) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(TILE_ATLAS_PATH) as Texture2D
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	source.create_tile(TILE_FLOOR)
	source.create_tile(TILE_WALL)
	source.create_tile(TILE_WATER)
	source.create_tile(TILE_DOOR)
	tile_set.add_source(source, TILE_SOURCE_DUNGEON)
