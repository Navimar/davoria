extends Node2D

const GRID := preload("res://scripts/grid_config.gd")
const HERO_PICKER := preload("res://scripts/hero_picker.gd")
const CONTACT_SHADOW := preload("res://scripts/contact_shadow.gd")
const COMBAT := preload("res://scripts/strength_combat.gd")
const TURN_QUEUE := preload("res://scripts/turn_queue.gd")
const GOBLIN_AI := preload("res://scripts/goblin_ai.gd")
const ACTOR_SIGHT := preload("res://scripts/actor_sight.gd")
const STARTER_LEVEL := preload("res://scripts/starter_level.gd")
const GOBLIN_PATH := "res://assets/actors/pixel_monsters/series_05/06_hobgoblin_captain.png"
const STRENGTH_LABEL_Z_INDEX := 50
const GOBLIN_START_CELL := STARTER_LEVEL.FIRST_GOBLIN_CELL
const HERO_START_CELL := STARTER_LEVEL.HERO_START_CELL
const HERO_MOVE_DURATION := 0.16
const HERO_SIGHT_RADIUS := ACTOR_SIGHT.RADIUS
const CELL_SIZE := float(GRID.TILE_SIZE)
const VIEW_CELL_COUNT := 11
const TILE_STITCHING_ENABLED := false
const TILE_BASE_OVERLAP := CELL_SIZE * 0.125
const TILE_OVERLAP := TILE_BASE_OVERLAP if TILE_STITCHING_ENABLED else 0.0
const FOG_OVERLAP := CELL_SIZE * 0.0625
const FOG_FADE_DURATION := 0.2
const TILE_BLEND_WIDTH_UV := 0.2
const TILE_DIFFUSION_WIDTH_UV := 0.07
const TILE_DIFFUSION_START_UV := 0.045
const TILE_OUTLINE_WIDTH_UV := 0.035
const TILE_OUTLINE_JITTER_UV := 0.012
const FOG_BLEND_WIDTH_UV := 0.078
const INVENTORY_SIZE := 8
const ITEM_SCALE := 1.0
const INVENTORY_SLOT_PADDING := 14.0
const UI_PANEL_MARGIN := 18.0
const OUTER_VIEW_COLOR := Color(0.075, 0.082, 0.088)

enum TileType {
	FLOOR,
	WALL,
	WATER,
	DOOR,
}

const TILE_DIFFUSION_SHADER_PATH := "res://assets/shaders/tile_diffusion.gdshader"
const FOG_SHADER_PATH := "res://assets/shaders/fog_cell.gdshader"
const TILE_FLOOR_PATH := "res://assets/tiles/dungeon/floor.png"
const TILE_WALL_PATH := "res://assets/tiles/dungeon/wall.png"
const TILE_WATER_PATH := "res://assets/tiles/dungeon/water.png"
const TILE_DOOR_PATH := "res://assets/tiles/dungeon/door.png"
const TILE_VARIANT_COUNT := 8
const TILE_VARIANT_PATH_TEMPLATE := "res://assets/tiles/dungeon/variants/%s_%02d.png"
const CHUNK_PATH_TEMPLATE := STARTER_LEVEL.CHUNK_PATH_TEMPLATE
const CHUNK_SIZE := Vector2i(64, 64)

const HERO_PATH := "res://assets/actors/hero_mage_rogue.png"
const HERO_VARIANTS := [
	{"name": "Маг-разбойник", "path": "res://assets/actors/heroes/series_01/01_mage_rogue.png"},
	{"name": "Рыцарь", "path": "res://assets/actors/heroes/series_01/02_knight.png"},
	{"name": "Следопыт", "path": "res://assets/actors/heroes/series_01/03_ranger.png"},
	{"name": "Варвар", "path": "res://assets/actors/heroes/series_01/04_barbarian.png"},
	{"name": "Маг огня", "path": "res://assets/actors/heroes/series_01/05_fire_mage.png"},
	{"name": "Маг льда", "path": "res://assets/actors/heroes/series_01/06_frost_mage.png"},
	{"name": "Паладин", "path": "res://assets/actors/heroes/series_01/07_paladin.png"},
	{"name": "Воин-гном", "path": "res://assets/actors/heroes/series_01/08_dwarf_warrior.png"},
	{"name": "Эльфийка", "path": "res://assets/actors/heroes/series_01/09_elf_huntress.png"},
	{"name": "Дуэлянт", "path": "res://assets/actors/heroes/series_01/10_duelist.png"},
	{"name": "Друид", "path": "res://assets/actors/heroes/series_01/11_druid.png"},
	{"name": "Разбойница", "path": "res://assets/actors/heroes/series_01/12_rogue.png"},
	{"name": "Жрец", "path": "res://assets/actors/heroes/series_01/13_cleric.png"},
	{"name": "Монах", "path": "res://assets/actors/heroes/series_01/14_monk.png"},
	{"name": "Алхимик", "path": "res://assets/actors/heroes/series_01/15_alchemist.png"},
	{"name": "Полурослик", "path": "res://assets/actors/heroes/series_01/16_halfling.png"},
]
const HERO_GHOST_PATH := "res://assets/actors/hero_ghost_form.png"
const SWORD_PATH := "res://assets/items/iron_sword.png"
const GHOST_RING_PATH := "res://assets/items/ghost_ring.png"
const ITEM_ID_SWORD := "sword"
const ITEM_ID_GHOST_RING := "ghost_ring"

var _built := false
var _hero: Sprite2D
var _hero_normal_texture: Texture2D
var _hero_ghost_texture: Texture2D
var _selected_hero_index := 0
var _hero_picker: HERO_PICKER
var _camera: Camera2D
var _hero_cell := HERO_START_CELL
var _loaded_chunks: Dictionary = {}
var _enemies: Array[Sprite2D] = []
var _actor_base_flip: Dictionary = {}
var _actor_blocked_cells: Dictionary = {}
var _goblins: Dictionary = {}
var _goblins_by_cell: Dictionary = {}
var _goblin_tweens: Dictionary = {}
var _next_goblin_id := 0
var _turn_queue := TURN_QUEUE.new()
var _rng := RandomNumberGenerator.new()
var _hero_strength := COMBAT.START_STRENGTH
var _hero_max_strength := COMBAT.START_STRENGTH
var _hero_strength_label: Label
var _game_over := false
var _is_ghost_mode := false
var _is_moving := false
var _hero_move_tween: Tween
var _held_move_keys: Array[Key] = []
var _inventory: Array[Texture2D] = []
var _inventory_item_ids: Array[String] = []
var _inventory_slot_icons: Array[TextureRect] = []
var _items_by_cell: Dictionary = {}
var _selected_tile_type := TileType.FLOOR
var _editor_status_label: Label
var _hero_coords_label: Label
var _hovered_cell := Vector2i.ZERO
var _is_painting := false
var _last_painted_cell := Vector2i(2147483647, 2147483647)
var _terrain_cells: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _tile_root: Node2D
var _tile_sprites: Dictionary = {}
var _fog_root: Node2D
var _fog_cells: Dictionary = {}
var _visible_cells: Dictionary = {}
var _fog_cells_pending_hide: Dictionary = {}
var _fog_target_alpha: Dictionary = {}
var _fog_tweens: Dictionary = {}
var _fog_sight_origin := HERO_START_CELL
var _fog_sight_initialized := false
var _tile_textures: Dictionary = {}
var _tile_variants: Dictionary = {}
var _tile_materials: Dictionary = {}
var _fog_material: ShaderMaterial
var _view_mask_layer: CanvasLayer
var _view_mask_rects: Array[ColorRect] = []


func _ready() -> void:
	_rng.randomize()
	get_window().focus_exited.connect(_clear_held_movement)
	if not _built:
		_built = true
		_build_scene()


func _process(_delta: float) -> void:
	if _built:
		_update_view_mask()
		_hide_fog_cells_outside_view()
		_update_strength_label_visibility()
		_hovered_cell = _cell_from_world(get_global_mouse_position())
		if _is_painting and (_hero_picker == null or not _hero_picker.is_open()) and _hovered_cell != _last_painted_cell:
			_paint_selected_tile(_hovered_cell)
		_continue_held_movement()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or event.echo:
		return
	if _game_over:
		if event.pressed and event.physical_keycode == KEY_R:
			_build_scene()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_H:
		if event.pressed:
			_build_hero_picker()
			_hero_picker.toggle()
		get_viewport().set_input_as_handled()
		return
	if _hero_picker != null and _hero_picker.is_open():
		if event.pressed and event.physical_keycode == KEY_ESCAPE:
			_hero_picker.hide_picker()
		get_viewport().set_input_as_handled()
		return

	if event.physical_keycode == KEY_F:
		_is_painting = event.pressed
		if _is_painting:
			_paint_selected_tile(_hovered_cell)
		else:
			_last_painted_cell = Vector2i(2147483647, 2147483647)
		get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		_held_move_keys.erase(event.physical_keycode)
		return

	if event.physical_keycode == KEY_SPACE:
		_wait_hero_turn()
		get_viewport().set_input_as_handled()
		return

	var direction := _movement_direction_for_key(event.physical_keycode)
	if direction != Vector2i.ZERO:
		_held_move_keys.erase(event.physical_keycode)
		_held_move_keys.append(event.physical_keycode)
		_try_move_hero(direction)
		get_viewport().set_input_as_handled()


func _movement_direction_for_key(keycode: Key) -> Vector2i:
	match keycode:
		KEY_W:
			return Vector2i.UP
		KEY_A:
			return Vector2i.LEFT
		KEY_S:
			return Vector2i.DOWN
		KEY_D:
			return Vector2i.RIGHT
	return Vector2i.ZERO


func _continue_held_movement() -> void:
	if _hero == null or _game_over or _is_moving or (_hero_picker != null and _hero_picker.is_open()):
		return
	for index in range(_held_move_keys.size() - 1, -1, -1):
		var keycode := _held_move_keys[index]
		if not Input.is_physical_key_pressed(keycode):
			_held_move_keys.remove_at(index)
			continue
		_try_move_hero(_movement_direction_for_key(keycode))
		return


func _clear_held_movement() -> void:
	_held_move_keys.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _hero_picker != null and _hero_picker.is_open():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_paint_selected_tile(_cell_from_world(get_global_mouse_position()))
		get_viewport().set_input_as_handled()


func _build_scene() -> void:
	_clear_held_movement()
	_finish_goblin_animations()
	_goblins.clear()
	_goblins_by_cell.clear()
	_next_goblin_id = 0
	_turn_queue = TURN_QUEUE.new()
	_hero_strength = COMBAT.START_STRENGTH
	_hero_max_strength = COMBAT.START_STRENGTH
	_hero_strength_label = null
	_game_over = false
	if _hero_move_tween != null:
		_hero_move_tween.kill()
		_hero_move_tween = null
	for tween: Tween in _fog_tweens.values():
		tween.kill()
	_fog_tweens.clear()
	_fog_target_alpha.clear()
	_fog_sight_origin = HERO_START_CELL
	_fog_sight_initialized = false
	for child in get_children():
		child.queue_free()
	_blocked_cells.clear()
	_terrain_cells.clear()
	_loaded_chunks.clear()
	_tile_sprites.clear()
	_fog_cells.clear()
	_visible_cells.clear()
	_fog_cells_pending_hide.clear()
	_tile_materials.clear()
	_enemies.clear()
	_actor_base_flip.clear()
	_actor_blocked_cells.clear()
	_is_ghost_mode = false
	_is_moving = false
	_inventory.clear()
	_inventory_item_ids.clear()
	_inventory_slot_icons.clear()
	_items_by_cell.clear()
	_selected_tile_type = TileType.FLOOR
	_editor_status_label = null
	_hero_coords_label = null
	_hovered_cell = Vector2i.ZERO
	_is_painting = false
	_last_painted_cell = Vector2i(2147483647, 2147483647)
	_hero = null
	_hero_normal_texture = null
	_hero_ghost_texture = null
	_hero_picker = null
	_camera = null
	_tile_root = null
	_fog_root = null
	_fog_material = null
	_view_mask_layer = null
	_view_mask_rects.clear()

	_load_tile_textures()
	_fog_material = _create_fog_material()
	_hero_normal_texture = _load_texture(str(HERO_VARIANTS[_selected_hero_index]["path"]))
	_hero_ghost_texture = _load_texture(HERO_GHOST_PATH)
	var sword_texture := _load_texture(SWORD_PATH)
	var ghost_ring_texture := _load_texture(GHOST_RING_PATH)

	_build_tile_sprites()

	for cell in STARTER_LEVEL.SWORD_CELLS:
		_add_item(sword_texture, cell, ITEM_SCALE, 10, ITEM_ID_SWORD)

	_hero_cell = HERO_START_CELL
	_hero = _add_actor(_hero_normal_texture, _hero_cell, 1.0, 40)
	_hero.offset = GRID.ACTOR_DRAW_OFFSET
	_hero.add_child(CONTACT_SHADOW.new())
	_hero_strength_label = _add_strength_label(_hero)
	for spawn in STARTER_LEVEL.GOBLINS:
		_spawn_goblin(spawn.cell, spawn.strength)
	_sync_active_goblins()
	_update_enemy_facing()

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position = _cell_center(_hero_cell)
	_camera.zoom = Vector2.ONE
	_camera.enabled = true
	add_child(_camera)
	_build_view_mask()
	_build_inventory_panel()
	_add_inventory_item(ghost_ring_texture, ITEM_ID_GHOST_RING)
	_build_editor_panel()
	_refresh_combat_labels()
	_build_hero_picker()
	if not get_viewport().size_changed.is_connected(_update_view_layout):
		get_viewport().size_changed.connect(_update_view_layout)
	_update_view_layout()
	_update_editor_coords()


func _spawn_goblin(cell: Vector2i, strength: int) -> int:
	var actor := _add_blocking_actor(_load_texture(GOBLIN_PATH), cell, 1.0, 20)
	actor.name = "Goblin"
	return _register_goblin(actor, cell, strength)


func _build_hero_picker() -> void:
	if _hero_picker != null:
		return
	_hero_picker = HERO_PICKER.new(HERO_VARIANTS, _selected_hero_index)
	_hero_picker.name = "HeroPicker"
	_hero_picker.hero_selected.connect(_select_hero)
	_hero_picker.picker_toggled.connect(_on_hero_picker_toggled)
	add_child(_hero_picker)


func _select_hero(index: int) -> void:
	if index < 0 or index >= HERO_VARIANTS.size():
		return
	_selected_hero_index = index
	_hero_normal_texture = _load_texture(str(HERO_VARIANTS[index]["path"]))
	if _hero != null and not _is_ghost_mode:
		_hero.texture = _hero_normal_texture
	if _hero_picker != null:
		_hero_picker.set_selected(index)


func _on_hero_picker_toggled(_open: bool) -> void:
	_is_painting = false


func _load_tile_textures() -> void:
	_tile_textures = {
		TileType.FLOOR: _load_texture(TILE_FLOOR_PATH),
		TileType.WALL: _load_texture(TILE_WALL_PATH),
		TileType.WATER: _load_texture(TILE_WATER_PATH),
		TileType.DOOR: _load_texture(TILE_DOOR_PATH),
	}
	_tile_variants.clear()
	for tile_type in [TileType.FLOOR, TileType.WALL]:
		var variants: Array[Texture2D] = [_tile_textures[tile_type]]
		var prefix := "floor" if tile_type == TileType.FLOOR else "wall"
		for index in range(1, TILE_VARIANT_COUNT + 1):
			variants.append(_load_texture(TILE_VARIANT_PATH_TEMPLATE % [prefix, index]))
		_tile_variants[tile_type] = variants


func _load_chunk(chunk_coord: Vector2i) -> void:
	if _loaded_chunks.has(chunk_coord):
		return

	var rows := _read_chunk_rows(chunk_coord)
	if rows.is_empty():
		rows = _create_empty_chunk_rows()
	if rows.is_empty():
		push_error("Could not load or create chunk %s" % str(chunk_coord))
		return

	if Vector2i(rows[0].length(), rows.size()) != CHUNK_SIZE:
		push_error("Chunk %s has size %s, expected %s" % [
			str(chunk_coord),
			str(Vector2i(rows[0].length(), rows.size())),
			str(CHUNK_SIZE),
		])
		return

	var origin := chunk_coord * CHUNK_SIZE
	for y in range(CHUNK_SIZE.y):
		if rows[y].length() != CHUNK_SIZE.x:
			push_error("Chunk %s row %d has width %d, expected %d" % [
				str(chunk_coord),
				y,
				rows[y].length(),
				CHUNK_SIZE.x,
			])
			continue
		for x in range(CHUNK_SIZE.x):
			_set_terrain_cell(origin + Vector2i(x, y), _tile_type_from_map_char(rows[y][x]))

	_loaded_chunks[chunk_coord] = true
	if _tile_root != null:
		_build_chunk_sprites(chunk_coord)
		_refresh_tile_materials()
		_update_fog()


func _read_chunk_rows(chunk_coord: Vector2i) -> Array[String]:
	var path := CHUNK_PATH_TEMPLATE % [chunk_coord.x, chunk_coord.y]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []

	var rows: Array[String] = []
	while not file.eof_reached():
		var row := file.get_line()
		if row.is_empty():
			continue
		rows.append(row)
	return rows


func _create_empty_chunk_rows() -> Array[String]:
	var rows: Array[String] = []
	var row := "#".repeat(CHUNK_SIZE.x)
	for y in range(CHUNK_SIZE.y):
		rows.append(row)
	return rows


func _tile_type_from_map_char(value: String) -> TileType:
	match value:
		"#":
			return TileType.WALL
		"~":
			return TileType.WATER
		"D":
			return TileType.DOOR
		_:
			return TileType.FLOOR


func _map_char_from_tile_type(tile_type: TileType) -> String:
	match tile_type:
		TileType.WALL:
			return "#"
		TileType.WATER:
			return "~"
		TileType.DOOR:
			return "D"
		_:
			return "."


func _set_terrain_cell(cell: Vector2i, tile_type: TileType) -> void:
	_terrain_cells[cell] = tile_type
	if tile_type == TileType.WALL or tile_type == TileType.DOOR:
		_blocked_cells[cell] = true
	else:
		_blocked_cells.erase(cell)


func _is_terrain_visible_through(cell: Vector2i) -> bool:
	var tile_type := _terrain_type(cell)
	return tile_type != TileType.WALL and tile_type != TileType.DOOR


func _build_tile_sprites() -> void:
	_tile_root = Node2D.new()
	_tile_root.name = "Tiles"
	_tile_root.z_index = 0
	add_child(_tile_root)

	_fog_root = Node2D.new()
	_fog_root.name = "Fog"
	_fog_root.z_index = 30
	add_child(_fog_root)

	_load_chunk(Vector2i.ZERO)

func _build_chunk_sprites(chunk_coord: Vector2i) -> void:
	var origin := chunk_coord * CHUNK_SIZE
	for y in range(CHUNK_SIZE.y):
		for x in range(CHUNK_SIZE.x):
			var cell := origin + Vector2i(x, y)
			if _tile_sprites.has(cell):
				continue
			var sprite := _create_tile_sprite(cell)
			_tile_sprites[cell] = sprite
			_tile_root.add_child(sprite)
			var fog := _create_fog_cell(cell)
			_fog_cells[cell] = fog
			_fog_root.add_child(fog)


func _refresh_tile_materials() -> void:
	_tile_materials.clear()
	for cell in _tile_sprites:
		_tile_sprites[cell].material = _create_tile_diffusion_material(cell)


func _refresh_tile_and_neighbors(cell: Vector2i) -> void:
	_tile_materials.clear()
	var cells: Array[Vector2i] = [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]
	for target_cell in cells:
		if not _tile_sprites.has(target_cell):
			continue
		var sprite := _tile_sprites[target_cell] as Sprite2D
		sprite.texture = _tile_texture_for_cell(target_cell)
		sprite.material = _create_tile_diffusion_material(target_cell)


func _create_tile_sprite(cell: Vector2i) -> Sprite2D:
	var texture := _tile_texture_for_cell(cell)
	var sprite := Sprite2D.new()
	sprite.name = "Tile_%d_%d" % [cell.x, cell.y]
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(cell) * CELL_SIZE - Vector2(TILE_OVERLAP, TILE_OVERLAP)
	sprite.scale = _scale_to_size(texture, Vector2.ONE * (CELL_SIZE + TILE_OVERLAP * 2.0))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if TILE_STITCHING_ENABLED else CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = _create_tile_diffusion_material(cell)
	return sprite


func _create_fog_cell(cell: Vector2i) -> ColorRect:
	var fog := ColorRect.new()
	fog.name = "Fog_%d_%d" % [cell.x, cell.y]
	fog.color = Color.BLACK
	fog.position = Vector2(cell) * CELL_SIZE - Vector2(FOG_OVERLAP, FOG_OVERLAP)
	fog.size = Vector2.ONE * (CELL_SIZE + FOG_OVERLAP * 2.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.material = _fog_material
	_fog_target_alpha[cell] = 1.0
	return fog


func _create_fog_material() -> ShaderMaterial:
	var fog_size := CELL_SIZE + FOG_OVERLAP * 2.0
	var material := ShaderMaterial.new()
	material.shader = load(FOG_SHADER_PATH) as Shader
	material.set_shader_parameter("blend_width", FOG_BLEND_WIDTH_UV)
	material.set_shader_parameter("grain_strength", 0.28)
	material.set_shader_parameter("grain_scale", fog_size)
	material.set_shader_parameter("tone_steps", 6.0)
	material.set_shader_parameter("fog_color", Color.BLACK)
	return material


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
	var outline_scale := (CELL_SIZE + TILE_BASE_OVERLAP * 2.0) / texture_size
	var material := ShaderMaterial.new()
	material.shader = load(TILE_DIFFUSION_SHADER_PATH) as Shader
	material.set_shader_parameter("overlap_width", TILE_OVERLAP / texture_size)
	material.set_shader_parameter("blend_width", TILE_BLEND_WIDTH_UV)
	material.set_shader_parameter("diffusion_width", TILE_DIFFUSION_WIDTH_UV)
	material.set_shader_parameter("diffusion_start", TILE_DIFFUSION_START_UV)
	material.set_shader_parameter("grain_strength", 0.28)
	material.set_shader_parameter("grain_scale", texture_size)
	material.set_shader_parameter("tone_steps", 6.0)
	material.set_shader_parameter("diffuse_left", diffuse_left)
	material.set_shader_parameter("diffuse_right", diffuse_right)
	material.set_shader_parameter("diffuse_top", diffuse_top)
	material.set_shader_parameter("diffuse_bottom", diffuse_bottom)
	material.set_shader_parameter("outline_width", TILE_OUTLINE_WIDTH_UV * outline_scale)
	material.set_shader_parameter("outline_jitter", TILE_OUTLINE_JITTER_UV * outline_scale)
	material.set_shader_parameter("outline_color", Color(0.015, 0.012, 0.01, 0.52))
	material.set_shader_parameter("outline_left", outline_left)
	material.set_shader_parameter("outline_right", outline_right)
	material.set_shader_parameter("outline_top", outline_top)
	material.set_shader_parameter("outline_bottom", outline_bottom)
	_tile_materials[cache_key] = material
	return material


func _can_diffuse_to(cell: Vector2i, direction: Vector2i) -> bool:
	if not TILE_STITCHING_ENABLED:
		return false
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


func _tile_texture_for_cell(cell: Vector2i) -> Texture2D:
	var tile_type := _terrain_type(cell)
	if not _tile_variants.has(tile_type):
		return _tile_texture(tile_type)
	var variants: Array = _tile_variants[tile_type]
	# Coordinate mixing keeps variants stable across chunk loads, painting and restarts.
	var mixed: int = ((cell.x * 73856093) ^ (cell.y * 19349663) ^ (int(tile_type) * 83492791)) & 0x7fffffff
	mixed = ((mixed ^ (mixed >> 13)) * 1274126177) & 0x7fffffff
	var alternative_count := variants.size() - 1
	if alternative_count == 0:
		return variants[0] as Texture2D
	# Four base slots per alternative slot: 80% base, 20% shared equally by alternatives.
	var base_slots := alternative_count * 4
	var selection := mixed % (base_slots + alternative_count)
	var index := 0 if selection < base_slots else 1 + selection - base_slots
	return variants[index] as Texture2D


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


func _add_item(texture: Texture2D, cell: Vector2i, scale_value: float, z_index: int, item_id: String) -> Sprite2D:
	var item := _add_actor(texture, cell, scale_value, z_index)
	item.set_meta("item_id", item_id)
	_items_by_cell[cell] = item
	return item


func _add_blocking_actor(
	texture: Texture2D,
	cell: Vector2i,
	scale_value: float,
	z_index: int,
	base_flip_h := false
) -> Sprite2D:
	var actor := _add_actor(texture, cell, scale_value, z_index)
	actor.offset = GRID.ACTOR_DRAW_OFFSET
	actor.add_child(CONTACT_SHADOW.new())
	actor.flip_h = base_flip_h
	_actor_base_flip[actor] = base_flip_h
	_enemies.append(actor)
	_actor_blocked_cells[cell] = true
	return actor


func _try_move_hero(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO or _game_over:
		return
	if _is_moving:
		_finish_hero_move(false)

	_finish_goblin_animations()
	var next_cell := _hero_cell + direction
	_load_chunk(_chunk_coord_for_cell(next_cell))
	if _try_open_shortcut(next_cell, direction):
		return
	if _goblins_by_cell.has(next_cell):
		if _hero_strength <= 0:
			_refresh_combat_labels()
			return
		if direction.x != 0:
			_hero.flip_h = direction.x < 0
		_start_hero_action(direction)
		_resolve_combat(int(_goblins_by_cell[next_cell]))
		_advance_world_turn()
		return
	if not _is_walkable(next_cell):
		return

	_hero_cell = next_cell
	var target_position := _cell_center(_hero_cell)
	if direction.x != 0:
		_hero.flip_h = direction.x < 0
	_is_moving = true
	var tween := create_tween()
	_hero_move_tween = tween
	tween.set_parallel(true)
	tween.tween_property(_hero, "position", target_position, HERO_MOVE_DURATION)
	if _camera != null:
		tween.tween_property(_camera, "position", target_position, HERO_MOVE_DURATION)
	tween.finished.connect(_finish_hero_move)
	# Logical actions resolve once, before their visual movement completes.
	_try_pickup_item(_hero_cell)
	_update_visible_chunks(target_position)
	_advance_world_turn()
	_update_enemy_facing(target_position)
	_update_fog()
	_update_editor_coords()


func _finish_hero_move(continue_held := true) -> void:
	if _hero_move_tween != null:
		_hero_move_tween.kill()
		_hero_move_tween = null
	_hero.position = _cell_center(_hero_cell)
	if _camera != null:
		_camera.position = _hero.position
		_camera.force_update_scroll()
	_is_moving = false
	_finish_goblin_animations()
	_try_pickup_item(_hero_cell)
	_update_visible_chunks()
	_update_fog()
	_update_editor_coords()
	if continue_held:
		_continue_held_movement()


func _try_open_shortcut(cell: Vector2i, direction: Vector2i) -> bool:
	if cell != STARTER_LEVEL.SHORTCUT_DOOR or _hero_cell != STARTER_LEVEL.SHORTCUT_INSIDE_CELL:
		return false
	if _terrain_type(cell) != TileType.DOOR:
		return false
	_start_hero_action(direction)
	_set_terrain_cell(cell, TileType.FLOOR)
	_refresh_tile_and_neighbors(cell)
	_advance_world_turn()
	_update_fog()
	return true


func _wait_hero_turn() -> void:
	if _game_over or _hero == null:
		return
	if _is_moving:
		_finish_hero_move(false)
	_finish_goblin_animations()
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn()


func _start_hero_action(direction: Vector2i) -> void:
	_is_moving = true
	_hero_move_tween = create_tween()
	var center := _cell_center(_hero_cell)
	if direction == Vector2i.ZERO:
		_hero_move_tween.tween_interval(HERO_MOVE_DURATION)
	else:
		_hero_move_tween.tween_property(_hero, "position", center + Vector2(direction) * CELL_SIZE * 0.5, HERO_MOVE_DURATION * 0.5)
		_hero_move_tween.tween_property(_hero, "position", center, HERO_MOVE_DURATION * 0.5)
	_hero_move_tween.finished.connect(_finish_hero_move)


func _register_goblin(actor: Sprite2D, cell: Vector2i, strength: int) -> int:
	var actor_id := _next_goblin_id
	_next_goblin_id += 1
	_goblins[actor_id] = {"sprite": actor, "cell": cell, "strength": strength,
		"last_seen": null, "active": false, "label": _add_strength_label(actor)}
	_goblins_by_cell[cell] = actor_id
	return actor_id


func _sync_active_goblins() -> void:
	var hero_chunk := _chunk_coord_for_cell(_hero_cell)
	for actor_id: int in _goblins:
		var goblin: Dictionary = _goblins[actor_id]
		var delta := _chunk_coord_for_cell(goblin.cell) - hero_chunk
		var active := absi(delta.x) <= 1 and absi(delta.y) <= 1
		if active == bool(goblin.active):
			continue
		goblin.active = active
		if active:
			# Resume from a future turn; never catch up turns spent outside the area.
			_turn_queue.schedule_after(actor_id, 1)
		else:
			_turn_queue.cancel(actor_id)


func _advance_world_turn() -> void:
	_sync_active_goblins()
	_turn_queue.advance()
	var actor_id := _turn_queue.pop_due()
	while actor_id != -1:
		if _goblins.has(actor_id) and not _game_over:
			_take_goblin_turn(actor_id)
			if _goblins.has(actor_id):
				_turn_queue.schedule_after(actor_id, GOBLIN_AI.next_delay(_rng))
		actor_id = _turn_queue.pop_due()
	_refresh_combat_labels()
	_update_enemy_facing(_cell_center(_hero_cell))


func _take_goblin_turn(actor_id: int) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	var cell: Vector2i = goblin.cell
	var plan := GOBLIN_AI.plan(cell, _hero_cell, goblin.last_seen,
		_goblin_can_step, _actor_can_see, _rng)
	goblin.last_seen = plan.last_seen
	if plan.attack:
		_animate_goblin(actor_id, _cell_center(_hero_cell), true)
		_resolve_combat(actor_id)
	elif plan.target != cell and plan.target != _hero_cell:
		_actor_blocked_cells.erase(cell)
		_goblins_by_cell.erase(cell)
		goblin.cell = plan.target
		_actor_blocked_cells[plan.target] = true
		_goblins_by_cell[plan.target] = actor_id
		_animate_goblin(actor_id, _cell_center(plan.target))


func _goblin_can_step(cell: Vector2i) -> bool:
	return _terrain_cells.has(cell) and _is_terrain_walkable(cell) and (
		cell == _hero_cell or not _actor_blocked_cells.has(cell))


func _actor_can_see(origin: Vector2i, target: Vector2i) -> bool:
	return _calculate_visible_cells(origin).has(target)


func _animate_goblin(actor_id: int, target: Vector2, attack := false) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	var sprite: Sprite2D = goblin.sprite
	var center := _cell_center(goblin.cell)
	var tween := create_tween()
	_goblin_tweens[actor_id] = tween
	if attack:
		tween.tween_property(sprite, "position", center.lerp(target, 0.5), HERO_MOVE_DURATION * 0.5)
		tween.tween_property(sprite, "position", center, HERO_MOVE_DURATION * 0.5)
	else:
		tween.tween_property(sprite, "position", target, HERO_MOVE_DURATION)
	tween.finished.connect(func():
		if _goblin_tweens.get(actor_id) == tween:
			_goblin_tweens.erase(actor_id)
	)


func _finish_goblin_animations() -> void:
	for tween: Tween in _goblin_tweens.values():
		tween.kill()
	_goblin_tweens.clear()
	for goblin: Dictionary in _goblins.values():
		var sprite: Sprite2D = goblin.sprite
		sprite.position = _cell_center(goblin.cell)


func _resolve_combat(actor_id: int) -> void:
	if not _goblins.has(actor_id):
		return
	var goblin: Dictionary = _goblins[actor_id]
	var total := maxi(_hero_strength, 0) + maxi(int(goblin.strength), 0)
	var roll := _rng.randi_range(0, total - 1) if total > 0 else 0
	var result := COMBAT.exchange(_hero_strength, int(goblin.strength), _sword_damage_bonus(), roll)
	_hero_strength = result.player
	goblin.strength = result.enemy
	if result.killed:
		_hero_max_strength += 1
		_remove_goblin(actor_id)
	if _hero_strength < COMBAT.DEATH_THRESHOLD:
		_game_over = true
		_clear_held_movement()
	_refresh_combat_labels()


func _sword_damage_bonus() -> int:
	return 1 if _inventory_item_ids.has(ITEM_ID_SWORD) else 0


func _remove_goblin(actor_id: int) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	var sprite: Sprite2D = goblin.sprite
	if _goblin_tweens.has(actor_id):
		_goblin_tweens[actor_id].kill()
		_goblin_tweens.erase(actor_id)
	_turn_queue.cancel(actor_id)
	_goblins_by_cell.erase(goblin.cell)
	_actor_blocked_cells.erase(goblin.cell)
	_actor_base_flip.erase(sprite)
	_enemies.erase(sprite)
	_goblins.erase(actor_id)
	sprite.position = _cell_center(goblin.cell)
	goblin.label.hide()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "position:y", sprite.position.y + CELL_SIZE * 0.5, 0.3)
	tween.finished.connect(sprite.queue_free)


func _add_strength_label(actor: Sprite2D) -> Label:
	var label := Label.new()
	label.name = "Strength"
	# Keep world labels above every actor, independent of the parent sprite.
	label.z_as_relative = false
	label.z_index = STRENGTH_LABEL_Z_INDEX
	label.position = Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.83)
	label.size = Vector2(CELL_SIZE, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.02, 0.025))
	label.add_theme_constant_override("outline_size", 4)
	actor.add_child(label)
	return label


func _refresh_combat_labels() -> void:
	if _hero_strength_label != null:
		_hero_strength_label.text = "%d/%d" % [_hero_strength, _hero_max_strength]
		_hero_strength_label.modulate = Color(1.0, 0.4, 0.35) if _hero_strength <= 0 else Color.WHITE
	for goblin: Dictionary in _goblins.values():
		goblin.label.text = str(goblin.strength)
	_update_strength_label_visibility()


func _update_strength_label_visibility() -> void:
	for goblin: Dictionary in _goblins.values():
		var label: Label = goblin.label
		var fog := _fog_cells.get(goblin.cell) as ColorRect
		# Labels are above sprites and fog, so follow the owner's fog opacity explicitly.
		var alpha := 1.0 - fog.self_modulate.a if fog != null else 0.0
		label.self_modulate.a = alpha
		label.visible = alpha > 0.0


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


func _try_pickup_item(cell: Vector2i) -> void:
	if not _items_by_cell.has(cell) or _inventory.size() >= INVENTORY_SIZE:
		return

	var item := _items_by_cell[cell] as Sprite2D
	if item == null:
		_items_by_cell.erase(cell)
		return

	_add_inventory_item(item.texture, str(item.get_meta("item_id", ITEM_ID_SWORD)))
	_items_by_cell.erase(cell)
	item.queue_free()


func _add_inventory_item(texture: Texture2D, item_id: String) -> bool:
	if texture == null or _inventory.size() >= INVENTORY_SIZE:
		return false

	_inventory.append(texture)
	_inventory_item_ids.append(item_id)
	_refresh_inventory_panel()
	return true


func _build_view_mask() -> void:
	_view_mask_layer = CanvasLayer.new()
	_view_mask_layer.name = "ViewMaskCanvas"
	_view_mask_layer.layer = 10
	add_child(_view_mask_layer)

	for i in range(4):
		var rect := ColorRect.new()
		rect.name = "ViewMask_%d" % i
		rect.color = OUTER_VIEW_COLOR
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view_mask_layer.add_child(rect)
		_view_mask_rects.append(rect)
	_update_view_mask()


func _view_screen_rect(viewport_size: Vector2) -> Rect2:
	var view_size := Vector2.ONE * minf(viewport_size.x, viewport_size.y)
	return Rect2((viewport_size - view_size) * 0.5, view_size)


func _update_view_layout() -> void:
	if _camera == null:
		return
	var screen_rect := _view_screen_rect(get_viewport_rect().size)
	if screen_rect.size.x <= 0.0:
		return
	var zoom_value := screen_rect.size.x / (float(VIEW_CELL_COUNT) * CELL_SIZE)
	_camera.zoom = Vector2.ONE * zoom_value
	_camera.force_update_scroll()
	_update_view_mask()
	_update_visible_chunks()
	_hide_fog_cells_outside_view()


func _update_view_mask() -> void:
	if _view_mask_rects.size() != 4:
		return

	var viewport_size := get_viewport_rect().size
	var screen_rect := _view_screen_rect(viewport_size)
	var square_size := screen_rect.size.x
	var left := screen_rect.position.x
	var top := screen_rect.position.y
	var right := screen_rect.end.x
	var bottom := screen_rect.end.y

	_set_mask_rect(_view_mask_rects[0], Rect2(Vector2.ZERO, Vector2(viewport_size.x, top)))
	_set_mask_rect(_view_mask_rects[1], Rect2(Vector2(0.0, bottom), Vector2(viewport_size.x, viewport_size.y - bottom)))
	_set_mask_rect(_view_mask_rects[2], Rect2(Vector2(0.0, top), Vector2(left, square_size)))
	_set_mask_rect(_view_mask_rects[3], Rect2(Vector2(right, top), Vector2(viewport_size.x - right, square_size)))


func _set_mask_rect(rect: ColorRect, bounds: Rect2) -> void:
	rect.position = bounds.position
	rect.size = bounds.size


func _build_inventory_panel() -> void:
	var slot_size := _inventory_slot_size()
	var icon_size := _inventory_icon_size()
	var canvas := CanvasLayer.new()
	canvas.name = "InventoryCanvas"
	canvas.layer = 20
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "InventoryPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = UI_PANEL_MARGIN
	panel.offset_right = UI_PANEL_MARGIN + slot_size + 16.0
	panel.offset_top = -(slot_size * INVENTORY_SIZE + 8.0 * (INVENTORY_SIZE - 1) + 16.0) * 0.5
	panel.offset_bottom = (slot_size * INVENTORY_SIZE + 8.0 * (INVENTORY_SIZE - 1) + 16.0) * 0.5
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.052, 0.047, 0.86), 2, Color(0.18, 0.16, 0.13, 0.95)))
	canvas.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	for i in range(INVENTORY_SIZE):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _slot_style())
		slot.gui_input.connect(_on_inventory_slot_gui_input.bind(i))
		column.add_child(slot)

		var center := CenterContainer.new()
		center.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.add_child(center)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
		_inventory_slot_icons.append(icon)

	_refresh_inventory_panel()


func _refresh_inventory_panel() -> void:
	var icon_size := _inventory_icon_size()
	for i in range(_inventory_slot_icons.size()):
		var icon := _inventory_slot_icons[i]
		icon.texture = _inventory[i] if i < _inventory.size() else null
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = Vector2(icon_size, icon_size)


func _on_inventory_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate_inventory_slot(slot_index)
		get_viewport().set_input_as_handled()


func _activate_inventory_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _inventory_item_ids.size():
		return

	match _inventory_item_ids[slot_index]:
		ITEM_ID_GHOST_RING:
			_set_ghost_mode(not _is_ghost_mode)


func _set_ghost_mode(enabled: bool) -> void:
	if _is_ghost_mode == enabled:
		return

	_is_ghost_mode = enabled
	if _hero != null:
		var was_flipped := _hero.flip_h
		_hero.texture = _hero_ghost_texture if _is_ghost_mode else _hero_normal_texture
		_hero.flip_h = was_flipped
	_update_fog()
	if _editor_status_label != null:
		_editor_status_label.text = "Ghost mode: %s" % ("On" if _is_ghost_mode else "Off")
	_update_editor_coords()


func _build_editor_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EditorCanvas"
	canvas.layer = 30
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "TileEditorPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -382.0
	panel.offset_right = 382.0
	panel.offset_top = UI_PANEL_MARGIN
	panel.offset_bottom = UI_PANEL_MARGIN + 86.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.052, 0.047, 0.88), 2, Color(0.18, 0.16, 0.13, 0.95)))
	canvas.add_child(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	_add_tile_editor_button(row, TileType.FLOOR)
	_add_tile_editor_button(row, TileType.WALL)
	_add_tile_editor_button(row, TileType.WATER)
	_add_tile_editor_button(row, TileType.DOOR)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_loaded_chunks)
	row.add_child(save_button)

	_editor_status_label = Label.new()
	_editor_status_label.text = "Selected: Floor"
	_editor_status_label.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(_editor_status_label)

	_hero_coords_label = Label.new()
	_hero_coords_label.custom_minimum_size = Vector2(210.0, 0.0)
	row.add_child(_hero_coords_label)


func _add_tile_editor_button(parent: Control, tile_type: TileType) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(68.0, 68.0)
	button.icon = _tile_texture(tile_type)
	button.expand_icon = true
	button.tooltip_text = _tile_type_name(tile_type)
	button.pressed.connect(_select_editor_tile.bind(tile_type))
	parent.add_child(button)


func _select_editor_tile(tile_type: TileType) -> void:
	_selected_tile_type = tile_type
	if _editor_status_label != null:
		_editor_status_label.text = "Selected: %s" % _tile_type_name(tile_type)


func _paint_selected_tile(cell: Vector2i) -> void:
	_load_chunk(_chunk_coord_for_cell(cell))
	_set_terrain_cell(cell, _selected_tile_type)
	_last_painted_cell = cell
	_refresh_tile_and_neighbors(cell)
	_update_fog()
	if _editor_status_label != null:
		_editor_status_label.text = "Painted: %s %s" % [_tile_type_name(_selected_tile_type), str(cell)]


func _update_editor_coords() -> void:
	if _hero_coords_label == null:
		return
	_hero_coords_label.text = "Hero: %s  Chunk: %s  %s" % [
		str(_hero_cell),
		str(_chunk_coord_for_cell(_hero_cell)),
		"Ghost" if _is_ghost_mode else "Body",
	]


func _save_loaded_chunks() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHUNK_PATH_TEMPLATE.get_base_dir()))
	var saved_count := 0
	for chunk_coord in _loaded_chunks:
		if _save_chunk(chunk_coord):
			saved_count += 1
	if _editor_status_label != null:
		_editor_status_label.text = "Saved chunks: %d" % saved_count


func _save_chunk(chunk_coord: Vector2i) -> bool:
	var path := ProjectSettings.globalize_path(CHUNK_PATH_TEMPLATE % [chunk_coord.x, chunk_coord.y])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save chunk: %s" % path)
		return false

	var origin := chunk_coord * CHUNK_SIZE
	for y in range(CHUNK_SIZE.y):
		var row := ""
		for x in range(CHUNK_SIZE.x):
			row += _map_char_from_tile_type(_terrain_type(origin + Vector2i(x, y)))
		file.store_line(row)
	return true


func _tile_type_name(tile_type: TileType) -> String:
	match tile_type:
		TileType.WALL:
			return "Wall"
		TileType.WATER:
			return "Water"
		TileType.DOOR:
			return "Door"
		_:
			return "Floor"


func _panel_style(background: Color, border_width: int, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.085, 0.075, 0.92)
	style.border_color = Color(0.24, 0.21, 0.17, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _inventory_slot_size() -> float:
	return _inventory_icon_size() + INVENTORY_SLOT_PADDING


func _inventory_icon_size() -> float:
	var sword_texture := _load_texture(SWORD_PATH)
	return maxf(sword_texture.get_width(), sword_texture.get_height()) * ITEM_SCALE


func _is_walkable(cell: Vector2i) -> bool:
	_load_chunk(_chunk_coord_for_cell(cell))
	if _actor_blocked_cells.has(cell):
		return false
	if _is_ghost_mode:
		return true
	return not _blocked_cells.has(cell)


func _update_visible_chunks(center_position: Variant = null) -> void:
	var viewport_size := get_viewport_rect().size
	var camera_position: Vector2 = _camera.position if center_position == null else center_position
	var half_view := viewport_size * 0.5 / _camera.zoom
	var min_cell := _cell_from_world(camera_position - half_view) - Vector2i.ONE
	var max_cell := _cell_from_world(camera_position + half_view) + Vector2i.ONE
	var min_chunk := _chunk_coord_for_cell(min_cell)
	var max_chunk := _chunk_coord_for_cell(max_cell)
	for y in range(min_chunk.y, max_chunk.y + 1):
		for x in range(min_chunk.x, max_chunk.x + 1):
			_load_chunk(Vector2i(x, y))


func _update_fog() -> void:
	if _hero == null or _fog_cells.is_empty():
		return

	var screen_rect := _view_screen_rect(get_viewport_rect().size)
	var world_rect := get_viewport().get_canvas_transform().affine_inverse() * screen_rect
	var previous_origin := _fog_sight_origin
	var had_previous_sight := _fog_sight_initialized
	_fog_sight_origin = _hero_cell
	_fog_sight_initialized = true
	if _is_ghost_mode:
		_visible_cells.clear()
		_fog_cells_pending_hide.clear()
		for cell in _fog_cells:
			var fog := _fog_cells[cell] as ColorRect
			_set_fog_visibility(cell, false, world_rect.intersects(fog.get_global_rect()))
		_update_strength_label_visibility()
		return

	var next_visible_cells := _calculate_visible_cells(_hero_cell)
	for cell in _visible_cells:
		if not next_visible_cells.has(cell) and not _is_inside_hero_sight(cell, _hero_cell):
			_fog_cells_pending_hide[cell] = true
	_visible_cells = next_visible_cells
	_hide_fog_cells_outside_view()
	for cell in _fog_cells:
		var fog := _fog_cells[cell] as ColorRect
		var covered := not _visible_cells.has(cell) and not _fog_cells_pending_hide.has(cell)
		# Incoming and outgoing view bands slide with the camera; only interior sight changes fade.
		var inside_shared_sight := had_previous_sight and _is_inside_hero_sight(cell, previous_origin) and _is_inside_hero_sight(cell, _hero_cell)
		_set_fog_visibility(cell, covered, inside_shared_sight and world_rect.intersects(fog.get_global_rect()))
	_update_strength_label_visibility()


func _set_fog_visibility(cell: Vector2i, covered: bool, animate := true) -> void:
	var target_alpha := 1.0 if covered else 0.0
	if _fog_target_alpha.get(cell, -1.0) == target_alpha and (animate or not _fog_tweens.has(cell)):
		return
	_fog_target_alpha[cell] = target_alpha
	if _fog_tweens.has(cell):
		var previous := _fog_tweens[cell] as Tween
		previous.kill()
		_fog_tweens.erase(cell)

	var fog := _fog_cells[cell] as ColorRect
	if not animate or is_equal_approx(fog.self_modulate.a, target_alpha):
		fog.self_modulate.a = target_alpha
		fog.visible = covered
		return

	fog.visible = true
	var tween := create_tween()
	_fog_tweens[cell] = tween
	tween.tween_property(fog, "self_modulate:a", target_alpha, FOG_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		_fog_tweens.erase(cell)
		fog.visible = covered
	)


func _hide_fog_cells_outside_view() -> void:
	if _fog_cells_pending_hide.is_empty():
		return

	var screen_rect := _view_screen_rect(get_viewport_rect().size)
	var world_rect := get_viewport().get_canvas_transform().affine_inverse() * screen_rect
	for cell in _fog_cells_pending_hide.keys():
		if _visible_cells.has(cell):
			_fog_cells_pending_hide.erase(cell)
			continue
		var fog := _fog_cells[cell] as ColorRect
		# Keep the outgoing edge revealed until its fog, including overlap, leaves the view mask.
		if _is_inside_hero_sight(cell, _hero_cell) or not world_rect.intersects(fog.get_global_rect()):
			_set_fog_visibility(cell, true, world_rect.intersects(fog.get_global_rect()))
			_fog_cells_pending_hide.erase(cell)


func _calculate_visible_cells(origin_cell: Vector2i) -> Dictionary:
	return ACTOR_SIGHT.visible_cells(origin_cell, _has_terrain_cell, _is_terrain_visible_through)


func _has_terrain_cell(cell: Vector2i) -> bool:
	return _terrain_cells.has(cell)


func _is_inside_hero_sight(cell: Vector2i, origin_cell: Vector2i) -> bool:
	return ACTOR_SIGHT.contains(cell, origin_cell)


func _is_inside_map(cell: Vector2i) -> bool:
	return true


func _chunk_coord_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(_floor_div(cell.x, CHUNK_SIZE.x), _floor_div(cell.y, CHUNK_SIZE.y))


func _floor_div(value: int, divisor: int) -> int:
	return floori(float(value) / float(divisor))


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _cell_from_world(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CELL_SIZE), floori(world_position.y / CELL_SIZE))


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
