@tool
extends Node2D

const CELL_SIZE := 128
const TILE_OVERLAP := 16.0
const CAMERA_ZOOM := Vector2(1.25, 1.25)
const MAP_SIZE := Vector2i(18, 11)
const HERO_START_CELL := Vector2i(8, 5)
const HERO_MOVE_DURATION := 0.16

enum TileType {
	FLOOR,
	WALL,
	WATER,
	DOOR,
}

const TILE_DIFFUSION_SHADER_PATH := "res://assets/shaders/tile_diffusion.gdshader"
const TILE_FLOOR_PATH := "res://assets/tiles/dungeon/floor.png"
const TILE_WALL_PATH := "res://assets/tiles/dungeon/wall.png"
const TILE_WATER_PATH := "res://assets/tiles/dungeon/water.png"
const TILE_DOOR_PATH := "res://assets/tiles/dungeon/door.png"

const HERO_PATH := "res://assets/actors/hero_mage_rogue.png"
const GOBLIN_PATH := "res://assets/actors/goblin.png"
const MINOTAUR_PATH := "res://assets/actors/minotaur.png"
const SPIDER_PATH := "res://assets/actors/spider.png"
const SKELETON_PATH := "res://assets/actors/skeleton.png"
const SWORD_PATH := "res://assets/items/iron_sword.png"

var _built := false
var _hero: Sprite2D
var _camera: Camera2D
var _hero_cell := HERO_START_CELL
var _enemies: Array[Sprite2D] = []
var _actor_base_flip: Dictionary = {}
var _is_moving := false
var _queued_direction := Vector2i.ZERO
var _terrain_cells: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _tile_textures: Dictionary = {}
var _tile_materials: Dictionary = {}


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
	_terrain_cells.clear()
	_tile_materials.clear()
	_enemies.clear()
	_actor_base_flip.clear()
	_is_moving = false
	_queued_direction = Vector2i.ZERO
	_hero = null
	_camera = null

	_load_tile_textures()
	var hero_texture := _load_texture(HERO_PATH)
	var goblin_texture := _load_texture(GOBLIN_PATH)
	var minotaur_texture := _load_texture(MINOTAUR_PATH)
	var spider_texture := _load_texture(SPIDER_PATH)
	var skeleton_texture := _load_texture(SKELETON_PATH)
	var sword_texture := _load_texture(SWORD_PATH)

	_build_terrain_data()
	_set_terrain_cell(Vector2i(8, 0), TileType.DOOR)
	_set_terrain_cell(Vector2i(MAP_SIZE.x - 1, 5), TileType.DOOR)

	for cell in [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5),
		Vector2i(13, 7), Vector2i(14, 7), Vector2i(15, 7),
	]:
		_set_terrain_cell(cell, TileType.WATER)

	_build_tile_sprites()

	for cell in [
		Vector2i(1, 1), Vector2i(5, 1), Vector2i(11, 2),
		Vector2i(15, 3), Vector2i(4, 5), Vector2i(8, 9),
	]:
		_add_actor(sword_texture, cell, 0.50, 10)

	_hero_cell = HERO_START_CELL
	_hero = _add_actor(hero_texture, _hero_cell, 0.50, 20)
	_add_blocking_actor(goblin_texture, Vector2i(4, 3), 0.48, 20)
	_add_blocking_actor(goblin_texture, Vector2i(13, 4), 0.45, 20)
	_add_blocking_actor(goblin_texture, Vector2i(8, 1), 0.46, 20)
	_add_blocking_actor(minotaur_texture, Vector2i(2, 6), 0.52, 20)
	_add_blocking_actor(spider_texture, Vector2i(12, 2), 0.50, 20, true)
	_add_blocking_actor(spider_texture, Vector2i(15, 9), 0.44, 20, true)
	_add_blocking_actor(skeleton_texture, Vector2i(16, 5), 0.49, 20)
	_add_blocking_actor(skeleton_texture, Vector2i(3, 9), 0.43, 20)
	_update_enemy_facing()

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position = _cell_center(_hero_cell)
	_camera.zoom = CAMERA_ZOOM
	_camera.enabled = true
	add_child(_camera)


func _load_tile_textures() -> void:
	_tile_textures = {
		TileType.FLOOR: _load_texture(TILE_FLOOR_PATH),
		TileType.WALL: _load_texture(TILE_WALL_PATH),
		TileType.WATER: _load_texture(TILE_WATER_PATH),
		TileType.DOOR: _load_texture(TILE_DOOR_PATH),
	}


func _build_terrain_data() -> void:
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			_set_terrain_cell(Vector2i(x, y), TileType.FLOOR)
	for x in range(MAP_SIZE.x):
		_set_terrain_cell(Vector2i(x, 0), TileType.WALL)
		_set_terrain_cell(Vector2i(x, MAP_SIZE.y - 1), TileType.WALL)
	for y in range(MAP_SIZE.y):
		_set_terrain_cell(Vector2i(0, y), TileType.WALL)
		_set_terrain_cell(Vector2i(MAP_SIZE.x - 1, y), TileType.WALL)


func _set_terrain_cell(cell: Vector2i, tile_type: TileType) -> void:
	_terrain_cells[cell] = tile_type
	if tile_type == TileType.WALL or tile_type == TileType.DOOR:
		_blocked_cells[cell] = true
	else:
		_blocked_cells.erase(cell)


func _build_tile_sprites() -> void:
	var diffusion_root := Node2D.new()
	diffusion_root.name = "Tiles"
	diffusion_root.z_index = 0
	add_child(diffusion_root)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			diffusion_root.add_child(_create_tile_sprite(cell))


func _create_tile_sprite(cell: Vector2i) -> Sprite2D:
	var tile_type: TileType = _terrain_type(cell)
	var texture := _tile_texture(tile_type)
	var sprite := Sprite2D.new()
	sprite.name = "Tile_%d_%d" % [cell.x, cell.y]
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(cell) * CELL_SIZE - Vector2(TILE_OVERLAP, TILE_OVERLAP)
	sprite.scale = _scale_to_size(texture, Vector2.ONE * (CELL_SIZE + TILE_OVERLAP * 2.0))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = _create_tile_diffusion_material(cell)
	return sprite


func _create_tile_diffusion_material(cell: Vector2i) -> ShaderMaterial:
	var diffuse_left := _can_diffuse_to(cell, Vector2i.LEFT)
	var diffuse_right := _can_diffuse_to(cell, Vector2i.RIGHT)
	var diffuse_top := _can_diffuse_to(cell, Vector2i.UP)
	var diffuse_bottom := _can_diffuse_to(cell, Vector2i.DOWN)
	var outline_left := _needs_walkability_outline(cell, Vector2i.LEFT)
	var outline_right := _needs_walkability_outline(cell, Vector2i.RIGHT)
	var outline_top := _needs_walkability_outline(cell, Vector2i.UP)
	var outline_bottom := _needs_walkability_outline(cell, Vector2i.DOWN)
	var cache_key := "%d%d%d%d:%d%d%d%d" % [
		int(diffuse_left),
		int(diffuse_right),
		int(diffuse_top),
		int(diffuse_bottom),
		int(outline_left),
		int(outline_right),
		int(outline_top),
		int(outline_bottom),
	]
	if _tile_materials.has(cache_key):
		return _tile_materials[cache_key]

	var texture_size := CELL_SIZE + TILE_OVERLAP * 2.0
	var material := ShaderMaterial.new()
	material.shader = load(TILE_DIFFUSION_SHADER_PATH) as Shader
	material.set_shader_parameter("overlap_width", TILE_OVERLAP / texture_size)
	material.set_shader_parameter("blend_width", (TILE_OVERLAP * 2.0) / texture_size)
	material.set_shader_parameter("diffusion_width", 14.0 / texture_size)
	material.set_shader_parameter("diffusion_start", 9.0 / texture_size)
	material.set_shader_parameter("grain_strength", 0.28)
	material.set_shader_parameter("tone_steps", 6.0)
	material.set_shader_parameter("diffuse_left", diffuse_left)
	material.set_shader_parameter("diffuse_right", diffuse_right)
	material.set_shader_parameter("diffuse_top", diffuse_top)
	material.set_shader_parameter("diffuse_bottom", diffuse_bottom)
	material.set_shader_parameter("outline_width", 7.0 / texture_size)
	material.set_shader_parameter("outline_jitter", 2.4 / texture_size)
	material.set_shader_parameter("outline_color", Color(0.015, 0.012, 0.01, 0.52))
	material.set_shader_parameter("outline_left", outline_left)
	material.set_shader_parameter("outline_right", outline_right)
	material.set_shader_parameter("outline_top", outline_top)
	material.set_shader_parameter("outline_bottom", outline_bottom)
	_tile_materials[cache_key] = material
	return material


func _can_diffuse_to(cell: Vector2i, direction: Vector2i) -> bool:
	var neighbor := cell + direction
	if not _is_inside_map(neighbor):
		return false
	return _is_terrain_walkable(cell) == _is_terrain_walkable(neighbor)


func _needs_walkability_outline(cell: Vector2i, direction: Vector2i) -> bool:
	var neighbor := cell + direction
	if not _is_inside_map(neighbor):
		return false
	return not _is_terrain_walkable(cell) and _is_terrain_walkable(neighbor)


func _is_terrain_walkable(cell: Vector2i) -> bool:
	var tile_type := _terrain_type(cell)
	return tile_type != TileType.WALL and tile_type != TileType.DOOR


func _terrain_type(cell: Vector2i) -> TileType:
	return _terrain_cells.get(cell, TileType.FLOOR)


func _tile_texture(tile_type: TileType) -> Texture2D:
	return _tile_textures[tile_type]


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


func _add_blocking_actor(
	texture: Texture2D,
	cell: Vector2i,
	scale_value: float,
	z_index: int,
	base_flip_h := false
) -> Sprite2D:
	var actor := _add_actor(texture, cell, scale_value, z_index)
	actor.flip_h = base_flip_h
	_actor_base_flip[actor] = base_flip_h
	_enemies.append(actor)
	_blocked_cells[cell] = true
	return actor


func _try_move_hero(direction: Vector2i) -> void:
	if _is_moving:
		_queued_direction = direction
		return

	var next_cell := _hero_cell + direction
	if not _is_walkable(next_cell):
		return

	_hero_cell = next_cell
	var target_position := _cell_center(_hero_cell)
	if direction.x != 0:
		_hero.flip_h = direction.x < 0
	_is_moving = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_hero, "position", target_position, HERO_MOVE_DURATION)
	if _camera != null:
		tween.tween_property(_camera, "position", target_position, HERO_MOVE_DURATION)
	tween.finished.connect(_finish_hero_move)
	_update_enemy_facing(target_position)


func _finish_hero_move() -> void:
	_is_moving = false
	if _queued_direction == Vector2i.ZERO:
		return

	var direction := _queued_direction
	_queued_direction = Vector2i.ZERO
	_try_move_hero(direction)


func _update_enemy_facing(target_position: Variant = null) -> void:
	if _hero == null:
		return

	var hero_position: Vector2 = _hero.position if target_position == null else target_position
	for enemy in _enemies:
		if enemy == null:
			continue
		if is_equal_approx(enemy.position.x, hero_position.x):
			continue
		var face_left := hero_position.x < enemy.position.x
		enemy.flip_h = face_left != _actor_base_flip.get(enemy, false)


func _is_walkable(cell: Vector2i) -> bool:
	if not _is_inside_map(cell):
		return false
	return not _blocked_cells.has(cell)


func _is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _scale_to_cell(texture: Texture2D) -> Vector2:
	return _scale_to_size(texture, Vector2.ONE * CELL_SIZE)


func _scale_to_size(texture: Texture2D, target_size: Vector2) -> Vector2:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	return Vector2(target_size.x / size.x, target_size.y / size.y)


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Could not load demo texture: %s" % path)
		return PlaceholderTexture2D.new()
	return texture
