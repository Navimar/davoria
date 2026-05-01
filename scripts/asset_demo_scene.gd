@tool
extends Node2D

const CELL_SIZE := 128
const CAMERA_ZOOM := Vector2(1.25, 1.25)
const MAP_SIZE := Vector2i(18, 11)
const HERO_START_CELL := Vector2i(8, 5)

const TILE_SOURCE_DUNGEON := 0
const TILE_FLOOR := Vector2i(0, 0)
const TILE_WALL := Vector2i(1, 0)
const TILE_WATER := Vector2i(2, 0)
const TILE_DOOR := Vector2i(3, 0)

const TILE_SET_PATH := "res://assets/tileset/dungeon_tileset.tres"

const HERO_PATH := "res://assets/generation/processed/creatures/hero_mage_rogue_generated_shadow_palette.png"
const GOBLIN_PATH := "res://assets/generation/processed/creatures/goblin_02_generated_shadow_palette_refit.png"
const GOBLIN_OLD_PATH := "res://assets/generation/processed/creatures/goblin_01.png"
const MINOTAUR_PATH := "res://assets/generation/processed/creatures/minotaur_02_prompt_palette.png"
const SPIDER_PATH := "res://assets/generation/processed/creatures/spider_02_prompt_palette.png"
const SKELETON_PATH := "res://assets/generation/processed/creatures/skeleton_02_prompt_palette.png"
const SWORD_PATH := "res://assets/generation/processed/items/iron_sword_01.png"

var _built := false
var _hero: Sprite2D
var _camera: Camera2D
var _hero_cell := HERO_START_CELL
var _blocked_cells: Dictionary = {}


func _ready() -> void:
	if not _built:
		_built = true
		_build_scene()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.pressed or event.echo:
		return

	var direction := Vector2i.ZERO
	match event.physical_keycode:
		KEY_W:
			direction = Vector2i.UP
		KEY_A:
			direction = Vector2i.LEFT
		KEY_S:
			direction = Vector2i.DOWN
		KEY_D:
			direction = Vector2i.RIGHT

	if direction != Vector2i.ZERO:
		_try_move_hero(direction)
		get_viewport().set_input_as_handled()


func _build_scene() -> void:
	for child in get_children():
		child.queue_free()
	_blocked_cells.clear()
	_hero = null
	_camera = null

	var tile_set := _load_tile_set(TILE_SET_PATH)
	var hero_texture := _load_texture(HERO_PATH)
	var goblin_texture := _load_texture(GOBLIN_PATH)
	var old_goblin_texture := _load_texture(GOBLIN_OLD_PATH)
	var minotaur_texture := _load_texture(MINOTAUR_PATH)
	var spider_texture := _load_texture(SPIDER_PATH)
	var skeleton_texture := _load_texture(SKELETON_PATH)
	var sword_texture := _load_texture(SWORD_PATH)

	var ground_layer := _add_tile_map_layer("GroundTileMap", tile_set, 0)
	var terrain_layer := _add_tile_map_layer("TerrainTileMap", tile_set, 1)
	_paint_ground(ground_layer)
	_paint_terrain(terrain_layer)

	_set_map_cell(terrain_layer, Vector2i(8, 0), TILE_DOOR, false)
	_set_map_cell(terrain_layer, Vector2i(MAP_SIZE.x - 1, 5), TILE_DOOR, false)

	for cell in [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5),
		Vector2i(13, 7), Vector2i(14, 7), Vector2i(15, 7),
	]:
		_set_map_cell(terrain_layer, cell, TILE_WATER, true)

	for cell in [
		Vector2i(1, 1), Vector2i(5, 1), Vector2i(11, 2),
		Vector2i(15, 3), Vector2i(4, 5), Vector2i(8, 9),
	]:
		_add_actor(sword_texture, cell, 0.50, 10)

	_hero_cell = HERO_START_CELL
	_hero = _add_actor(hero_texture, _hero_cell, 0.50, 20)
	_add_blocking_actor(goblin_texture, Vector2i(4, 3), 0.48, 20)
	_add_blocking_actor(goblin_texture, Vector2i(13, 4), 0.45, 20)
	_add_blocking_actor(old_goblin_texture, Vector2i(8, 1), 0.46, 20)
	_add_blocking_actor(minotaur_texture, Vector2i(2, 6), 0.52, 20)
	_add_blocking_actor(spider_texture, Vector2i(12, 2), 0.50, 20)
	_add_blocking_actor(spider_texture, Vector2i(15, 9), 0.44, 20)
	_add_blocking_actor(skeleton_texture, Vector2i(16, 5), 0.49, 20)
	_add_blocking_actor(skeleton_texture, Vector2i(3, 9), 0.43, 20)

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position = _cell_center(_hero_cell)
	_camera.zoom = CAMERA_ZOOM
	_camera.enabled = true
	add_child(_camera)


func _add_tile_map_layer(layer_name: String, tile_set: TileSet, z_index: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = z_index
	add_child(layer)
	return layer


func _paint_ground(layer: TileMapLayer) -> void:
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			layer.set_cell(Vector2i(x, y), TILE_SOURCE_DUNGEON, TILE_FLOOR)


func _paint_terrain(layer: TileMapLayer) -> void:
	for x in range(MAP_SIZE.x):
		_set_map_cell(layer, Vector2i(x, 0), TILE_WALL, true)
		_set_map_cell(layer, Vector2i(x, MAP_SIZE.y - 1), TILE_WALL, true)
	for y in range(MAP_SIZE.y):
		_set_map_cell(layer, Vector2i(0, y), TILE_WALL, true)
		_set_map_cell(layer, Vector2i(MAP_SIZE.x - 1, y), TILE_WALL, true)


func _set_map_cell(layer: TileMapLayer, cell: Vector2i, atlas_coords: Vector2i, blocks_movement: bool) -> void:
	layer.set_cell(cell, TILE_SOURCE_DUNGEON, atlas_coords)
	if blocks_movement:
		_blocked_cells[cell] = true
	else:
		_blocked_cells.erase(cell)


func _add_actor(texture: Texture2D, cell: Vector2i, scale_value: float, z_index: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = _cell_center(cell)
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.z_index = z_index
	add_child(sprite)
	return sprite


func _add_blocking_actor(texture: Texture2D, cell: Vector2i, scale_value: float, z_index: int) -> void:
	_add_actor(texture, cell, scale_value, z_index)
	_blocked_cells[cell] = true


func _try_move_hero(direction: Vector2i) -> void:
	var next_cell := _hero_cell + direction
	if not _is_walkable(next_cell):
		return

	_hero_cell = next_cell
	var target_position := _cell_center(_hero_cell)
	_hero.position = target_position
	if _camera != null:
		_camera.position = target_position


func _is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return false
	return not _blocked_cells.has(cell)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Could not load demo texture: %s" % path)
		return PlaceholderTexture2D.new()
	return texture


func _load_tile_set(path: String) -> TileSet:
	var tile_set := load(path) as TileSet
	if tile_set == null:
		push_error("Could not load tile set: %s" % path)
		return TileSet.new()
	return tile_set
