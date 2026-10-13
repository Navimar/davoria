extends Node2D

const GRID := preload("res://scripts/grid_config.gd")
const HERO_PICKER := preload("res://scripts/hero_picker.gd")
const CONTACT_SHADOW := preload("res://scripts/contact_shadow.gd")
const COMBAT := preload("res://scripts/strength_combat.gd")
const TURN_QUEUE := preload("res://scripts/turn_queue.gd")
const GOBLIN_AI := preload("res://scripts/goblin_ai.gd")
const GOBLIN_TYPES := preload("res://scripts/goblin_types.gd")
const ACTOR_SIGHT := preload("res://scripts/actor_sight.gd")
const STARTER_LEVEL := preload("res://scripts/starter_level.gd")
const CHUNK_LOADER := preload("res://scripts/chunk_loader.gd")
const OBJECT_CATALOG := preload("res://scripts/game_objects.gd")
const MAP_OBJECTS := preload("res://scripts/map_objects.gd")
const CABINET_VISUAL := preload("res://scripts/cabinet_visual.gd")
const CRYSTAL_SCATTER := preload("res://scripts/crystal_scatter.gd")
const DOOR_UNLOCK_PROMPT := preload("res://scripts/door_unlock_prompt.gd")
const BOSS_PATH := OBJECT_CATALOG.BOSS_PATH
const WATER_ELEMENTAL_PATH := OBJECT_CATALOG.WATER_ELEMENTAL_PATH
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
const CABINET_SHELF_COUNT := 3
const CABINET_SHELF_AREAS := CABINET_VISUAL.SHELF_AREAS
const INVENTORY_COLUMNS := 4
const INVENTORY_ROWS := 8
const INVENTORY_SIZE := INVENTORY_COLUMNS * INVENTORY_ROWS
const ITEM_SCALE := 1.0
const INVENTORY_SLOT_PADDING := 14.0
const STATS_ROW_HEIGHT := 24.0
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
const TILE_FLOOR_PATH := OBJECT_CATALOG.TILE_FLOOR_PATH
const TILE_WALL_PATH := OBJECT_CATALOG.TILE_WALL_PATH
const TILE_WATER_PATH := OBJECT_CATALOG.TILE_WATER_PATH
const TILE_DOOR_PATH := OBJECT_CATALOG.TILE_DOOR_PATH
const TILE_VARIANT_COUNT := 8
const TILE_VARIANT_PATH_TEMPLATE := "res://assets/tiles/dungeon/variants/%s_%02d.png"
const CHUNK_PATH_TEMPLATE := STARTER_LEVEL.CHUNK_PATH_TEMPLATE
const CHUNK_SIZE := Vector2i(64, 64)
const RENDER_CORE_RADIUS := HERO_SIGHT_RADIUS + 1
const RENDER_PADDING_CELLS := 2
const TILE_BUILD_BATCH_SIZE := 32
const TILE_BUILD_BUDGET_USEC := 1000

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
const SWORD_PATH := OBJECT_CATALOG.SWORD_PATH
const GHOST_RING_PATH := OBJECT_CATALOG.GHOST_RING_PATH
const STRENGTH_CRYSTAL_PATH := OBJECT_CATALOG.STRENGTH_CRYSTAL_PATH
const HEALTH_POTION_PATH := OBJECT_CATALOG.HEALTH_POTION_PATH
const CABINET_FULL_PATH := OBJECT_CATALOG.CABINET_FULL_PATH
const STRENGTH_POTION_PATH := OBJECT_CATALOG.STRENGTH_POTION_PATH
const WATER_BREATHING_POTION_PATH := OBJECT_CATALOG.WATER_BREATHING_POTION_PATH
const SPEED_POTION_PATH := OBJECT_CATALOG.SPEED_POTION_PATH
const MAGIC_KEY_PATH := OBJECT_CATALOG.MAGIC_KEY_PATH
const WATER_SUBMERGE_SHADER := preload("res://assets/shaders/water_submerge.gdshader")
const MAX_BREATH := 30
const MAX_SUBMERGE_FRACTION := 0.75
const DROWNING_STRENGTH_LOSS := 1
const WATER_BREATHING_MAGIC_FACTOR := 3
const BREATH_COLOR := Color(0.35, 0.8, 1.0)
const START_MAGIC := 10
const HEALTH_POTION_MAGIC_FACTOR := 3
const ENEMY_KILL_STRENGTH_GAIN := 1
const ITEM_ID_SWORD := "sword"
const ITEM_ID_GHOST_RING := "ghost_ring"
const ITEM_ID_STRENGTH_CRYSTAL := "strength_crystal"
const ITEM_ID_HEALTH_POTION := "health_potion"
const ITEM_ID_STRENGTH_POTION := "strength_potion"
const ITEM_ID_WATER_BREATHING_POTION := "water_breathing_potion"
const ITEM_ID_SPEED_POTION := "speed_potion"
const ITEM_ID_MAGIC_KEY := "magic_key"

var _built := false
var _hero: Sprite2D
var _hero_normal_texture: Texture2D
var _hero_ghost_texture: Texture2D
var _selected_hero_index := 0
var _hero_picker: HERO_PICKER
var _door_prompt: DOOR_UNLOCK_PROMPT
var _pending_door_cell: Variant = null
var _pending_door_direction := Vector2i.ZERO
var _camera: Camera2D
var _hero_cell := HERO_START_CELL
var _chunk_path_template := CHUNK_PATH_TEMPLATE
var _loaded_chunks: Dictionary = {}
var _saved_chunk_cells: Dictionary = {}
var _editor_changes: Dictionary = {}
var _saved_map_objects: Dictionary = {}
var _editor_object_changes: Dictionary = {}
var _spawned_map_objects: Dictionary = {}
var _objects_ready := false
var _crystal_seed := 0
var _crystal_chunks: Dictionary = {}
var _crystal_texture: Texture2D
var _map_objects_valid := true
var _chunk_loader: CHUNK_LOADER
var _render_rect := Rect2i()
var _tile_build_queue: Array[Vector2i] = []
var _tile_build_index := 0
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
var _hero_magic := START_MAGIC
var _strength_boost_turns := 0
var _speed_boost_turns := 0
var _speed_actions_this_turn := 0
var _effects_started_this_turn: Dictionary = {}
var _hero_breath := MAX_BREATH
var _was_in_water := false
var _water_breathing_turns := 0
var _hero_breath_label: Label
var _stats_breath_label: Label
var _stats_water_breathing_label: Label
var _hero_water_material: ShaderMaterial
var _stats_magic_label: Label
var _stats_boost_label: Label
var _stats_speed_label: Label
var _hero_strength_label: Label
var _stats_strength_label: Label
var _game_over := false
var _is_ghost_mode := false
var _is_moving := false
var _hero_move_tween: Tween
var _held_move_keys: Array[Key] = []
var _inventory: Array[Texture2D] = []
var _inventory_item_ids: Array[String] = []
var _inventory_slot_icons: Array[TextureRect] = []
var _items_by_cell: Dictionary = {}
var _cabinets: Dictionary = {}
var _props_by_cell: Dictionary = {}
var _cabinet_full_texture: Texture2D
var _cabinet_empty_texture: Texture2D
var _cabinet_empty_shelf_textures: Array[Texture2D] = []
var _selected_tile_type := TileType.FLOOR
var _selected_object_id := "floor"
var _editor_palette: GridContainer
var _editor_canvas: CanvasLayer
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
		_build_queued_tiles()
		_update_view_mask()
		_hide_fog_cells_outside_view()
		_update_enemy_visibility()
		_hovered_cell = _cell_from_world(get_global_mouse_position())
		if _is_painting and (_hero_picker == null or not _hero_picker.is_open()) and _hovered_cell != _last_painted_cell:
			_paint_selected_tile(_hovered_cell)
		_continue_held_movement()


func _exit_tree() -> void:
	if _chunk_loader != null:
		_chunk_loader.close()
		_chunk_loader = null


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or event.echo:
		return
	if _game_over:
		get_viewport().set_input_as_handled()
		return
	if _door_prompt_is_open():
		_door_prompt.handle_key(event)
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

	if event.physical_keycode == KEY_E:
		if event.pressed:
			_toggle_editor()
		get_viewport().set_input_as_handled()
		return

	if event.physical_keycode == KEY_F:
		if _editor_canvas == null or not _editor_canvas.visible:
			return
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
	if _hero == null or _game_over or _is_moving or _door_prompt_is_open() or (_hero_picker != null and _hero_picker.is_open()):
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
	if _door_prompt_is_open() or (_hero_picker != null and _hero_picker.is_open()):
		get_viewport().set_input_as_handled()
		return
	if _game_over or _editor_canvas == null or not _editor_canvas.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_paint_selected_tile(_cell_from_world(get_global_mouse_position()))
		get_viewport().set_input_as_handled()


func _build_scene() -> void:
	if _door_prompt != null:
		_door_prompt.hide_prompt()
	if _chunk_loader != null:
		_chunk_loader.close()
	_chunk_loader = CHUNK_LOADER.new(_chunk_path_template, CHUNK_SIZE)
	_render_rect = Rect2i()
	_tile_build_queue.clear()
	_tile_build_index = 0
	_clear_held_movement()
	_finish_goblin_animations()
	_goblins.clear()
	_goblins_by_cell.clear()
	_next_goblin_id = 0
	_turn_queue = TURN_QUEUE.new()
	_hero_strength = COMBAT.START_STRENGTH
	_hero_max_strength = COMBAT.START_STRENGTH
	_hero_magic = START_MAGIC
	_strength_boost_turns = 0
	_speed_boost_turns = 0
	_speed_actions_this_turn = 0
	_effects_started_this_turn.clear()
	_hero_breath = MAX_BREATH
	_was_in_water = false
	_water_breathing_turns = 0
	_hero_breath_label = null
	_stats_breath_label = null
	_stats_water_breathing_label = null
	_hero_water_material = null
	_stats_magic_label = null
	_stats_boost_label = null
	_stats_speed_label = null
	_objects_ready = false
	_spawned_map_objects.clear()
	_crystal_chunks.clear()
	_crystal_seed = _rng.randi()
	_editor_object_changes.clear()
	_hero_strength_label = null
	_stats_strength_label = null
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
	_saved_chunk_cells.clear()
	_editor_changes.clear()
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
	_cabinets.clear()
	_props_by_cell.clear()
	_selected_tile_type = TileType.FLOOR
	_selected_object_id = "floor"
	_editor_palette = null
	_editor_canvas = null
	_editor_status_label = null
	_hero_coords_label = null
	_hovered_cell = Vector2i.ZERO
	_is_painting = false
	_last_painted_cell = Vector2i(2147483647, 2147483647)
	_hero = null
	_hero_normal_texture = null
	_hero_ghost_texture = null
	_hero_picker = null
	_door_prompt = null
	_pending_door_cell = null
	_pending_door_direction = Vector2i.ZERO
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
	var ghost_ring_texture := _load_texture(GHOST_RING_PATH)
	_crystal_texture = _load_texture(STRENGTH_CRYSTAL_PATH)
	_cabinet_full_texture = _load_texture(CABINET_FULL_PATH)
	_cabinet_empty_shelf_textures = CABINET_VISUAL.empty_shelf_textures(_cabinet_full_texture)
	_cabinet_empty_texture = CABINET_VISUAL.empty_preview(_cabinet_full_texture, _cabinet_empty_shelf_textures)
	var map_data := MAP_OBJECTS.read_map(MAP_OBJECTS.path_for_chunks(_chunk_path_template))
	_map_objects_valid = map_data.error.is_empty()
	if not _map_objects_valid:
		push_error(map_data.error)
	_saved_map_objects = map_data.objects
	_hero_cell = HERO_START_CELL
	for cell: Vector2i in _saved_map_objects:
		if _saved_map_objects[cell] == "hero_start":
			_hero_cell = cell
			break
	_load_chunk(_chunk_coord_for_cell(_hero_cell))
	_build_tile_sprites()
	_hero = _add_actor(_hero_normal_texture, _hero_cell, 1.0, 40)
	_hero.offset = GRID.ACTOR_DRAW_OFFSET
	_hero.add_child(CONTACT_SHADOW.new())
	_hero_strength_label = _add_strength_label(_hero)
	_hero_breath_label = _add_strength_label(_hero)
	_hero_breath_label.name = "Breath"
	_hero_breath_label.position = _hero_strength_label.position + Vector2(0.0, -22.0)
	_hero_breath_label.modulate = BREATH_COLOR
	_hero_water_material = ShaderMaterial.new()
	_hero_water_material.shader = WATER_SUBMERGE_SHADER
	_hero.material = _hero_water_material
	_objects_ready = true
	for chunk: Vector2i in _loaded_chunks.keys():
		_spawn_chunk_objects(chunk)
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
	_build_stats_panel()
	_add_inventory_item(ghost_ring_texture, ITEM_ID_GHOST_RING)
	_build_editor_panel()
	_door_prompt = DOOR_UNLOCK_PROMPT.new()
	_door_prompt.name = "DoorUnlockPrompt"
	_door_prompt.decided.connect(_on_door_unlock_decided)
	add_child(_door_prompt)
	_refresh_combat_labels()
	_build_hero_picker()
	if not get_viewport().size_changed.is_connected(_update_view_layout):
		get_viewport().size_changed.connect(_update_view_layout)
	_update_view_layout()
	_update_editor_coords()


func _authored_map_objects() -> Dictionary:
	var objects := _saved_map_objects.duplicate()
	for cell: Vector2i in _editor_object_changes:
		if _editor_object_changes[cell].is_empty():
			objects.erase(cell)
		else:
			objects[cell] = _editor_object_changes[cell]
	return objects


func _spawn_chunk_objects(chunk: Vector2i) -> void:
	var objects := _authored_map_objects()
	for cell: Vector2i in objects:
		if _chunk_coord_for_cell(cell) == chunk and not _spawned_map_objects.has(cell):
			_spawn_map_object(cell, objects[cell])
	_spawn_chunk_crystals(chunk, objects)


func _spawn_chunk_crystals(chunk: Vector2i, authored: Dictionary) -> void:
	if _crystal_chunks.has(chunk):
		return
	_crystal_chunks[chunk] = true
	for cell in CRYSTAL_SCATTER.candidates(chunk, CHUNK_SIZE, _crystal_seed):
		# Use real terrain passability, including water, without loading neighboring
		# chunks or allowing ghost mode to turn walls into scatter destinations.
		if _blocked_cells.has(cell) or _actor_blocked_cells.has(cell) or _objects_block_cell(cell, "blocks_movement"):
			continue
		if cell == _hero_cell or authored.has(cell) or _items_by_cell.has(cell):
			continue
		_add_item(_crystal_texture, cell, ITEM_SCALE, 10, ITEM_ID_STRENGTH_CRYSTAL)


func _spawn_map_object(cell: Vector2i, type_id: String) -> void:
	var definition := OBJECT_CATALOG.definition(type_id)
	if definition.is_empty() or definition.category == "hero" or definition.get("procedural", false):
		return
	if not OBJECT_CATALOG.can_place_on(type_id, _terrain_type(cell)) or cell == _hero_cell or _goblins_by_cell.has(cell) or _cabinets.has(cell) or _items_by_cell.has(cell) or _props_by_cell.has(cell):
		return
	var sprite: Sprite2D
	match definition.category:
		"prop":
			sprite = _add_actor(_load_texture(definition.path), cell, 1.0, 18)
			_props_by_cell[cell] = sprite
		"item":
			sprite = _add_item(_load_texture(definition.path), cell, ITEM_SCALE, 10, type_id)
		"cabinet":
			_add_potion_cabinet(cell, bool(definition.get("empty", false)))
			sprite = _cabinets[cell].sprite
		"enemy":
			var actor_id := _spawn_enemy(cell, type_id)
			if actor_id >= 0:
				sprite = _goblins[actor_id].sprite
	if sprite != null:
		_apply_object_flags(sprite, definition)
		sprite.set_meta("map_origin", cell)
		sprite.set_meta("object_type", type_id)
		_spawned_map_objects[cell] = true


func _erase_live_map_object(origin: Vector2i) -> void:
	for actor_id: int in _goblins.keys():
		if _goblins[actor_id].sprite.has_meta("map_origin") and _goblins[actor_id].sprite.get_meta("map_origin") == origin:
			_remove_goblin(actor_id)
	for cell: Vector2i in _items_by_cell.keys():
		var item: Sprite2D = _items_by_cell[cell]
		if item.has_meta("map_origin") and item.get_meta("map_origin") == origin:
			_items_by_cell.erase(cell)
			item.hide()
			item.queue_free()
	for cell: Vector2i in _props_by_cell.keys():
		var prop: Sprite2D = _props_by_cell[cell]
		if prop.has_meta("map_origin") and prop.get_meta("map_origin") == origin:
			_props_by_cell.erase(cell)
			prop.hide()
			prop.queue_free()
	for cell: Vector2i in _cabinets.keys():
		var cabinet: Dictionary = _cabinets[cell]
		if cabinet.sprite.has_meta("map_origin") and cabinet.sprite.get_meta("map_origin") == origin:
			_cabinets.erase(cell)
			cabinet.sprite.hide()
			cabinet.sprite.queue_free()


func _spawn_goblin(cell: Vector2i, type_id: String) -> int:
	if GOBLIN_TYPES.definition(type_id).is_empty():
		push_error("Unknown goblin type: %s" % type_id)
		return -1
	return _spawn_enemy(cell, type_id)


func _spawn_enemy(cell: Vector2i, type_id: String) -> int:
	var definition := OBJECT_CATALOG.definition(type_id)
	if definition.get("category") != "enemy" or not OBJECT_CATALOG.can_place_on(type_id, _terrain_type(cell)):
		return -1
	var strength: int = definition.get("strength", COMBAT.START_STRENGTH)
	if definition.has("strength_range"):
		var limits: Vector2i = definition.strength_range
		strength = _rng.randi_range(limits.x, limits.y)
	var actor := _add_blocking_actor(_load_texture(definition.path), cell, 1.0, 20)
	actor.name = "Enemy_" + type_id
	actor.set_meta("object_type", type_id)
	var actor_id := _register_goblin(actor, cell, strength)
	_goblins[actor_id].type = type_id
	_goblins[actor_id].tier = definition.get("tier", "")
	_goblins[actor_id].habitat = definition.get("habitat", "floor")
	_goblins[actor_id].retaliates_only = bool(definition.get("retaliates_only", false))
	actor.set_meta("retaliates_only", _goblins[actor_id].retaliates_only)
	_apply_object_flags(actor, definition)
	if _goblins[actor_id].habitat == "water":
		actor.get_node("ContactShadow").hide()
	return actor_id


func _spawn_boss(cell: Vector2i, strength: int, texture_path := BOSS_PATH) -> int:
	var actor := _add_blocking_actor(_load_texture(texture_path), cell, 1.0, 20)
	actor.name = "SkeletalHorseBoss"
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
	var data := _chunk_loader.take_ready(chunk_coord) if _chunk_loader != null else {}
	if data.is_empty():
		# Unexpected jumps and editor clicks still need collision data immediately.
		# This fallback reads only data; it never constructs a complete chunk scene.
		data = CHUNK_LOADER.read_chunk(chunk_coord, _chunk_path_template, CHUNK_SIZE)
	if not data.error.is_empty():
		push_error(data.error)
		return
	var cells: PackedByteArray = data.cells
	# Keep the persisted terrain separate from the live field. Gameplay changes
	# (doors, destruction) must never become the source of a map-editor save.
	_saved_chunk_cells[chunk_coord] = cells.duplicate()
	var origin := chunk_coord * CHUNK_SIZE
	for y in range(CHUNK_SIZE.y):
		for x in range(CHUNK_SIZE.x):
			_set_terrain_cell(origin + Vector2i(x, y), cells[y * CHUNK_SIZE.x + x])
	_loaded_chunks[chunk_coord] = true
	if _objects_ready:
		_spawn_chunk_objects(chunk_coord)
	# Only drawn cells touching the new data can acquire different outlines.
	var affected := Rect2i(origin, CHUNK_SIZE).grow(1)
	for cell: Vector2i in _tile_sprites:
		if affected.has_point(cell):
			_tile_sprites[cell].material = _create_tile_diffusion_material(cell)


func _prefetch_nearby_chunks(center_chunk: Vector2i) -> void:
	if _chunk_loader == null:
		return
	for y in range(-1, 2):
		for x in range(-1, 2):
			var chunk_coord := center_chunk + Vector2i(x, y)
			if not _loaded_chunks.has(chunk_coord):
				_chunk_loader.request(chunk_coord)


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
	if bool(OBJECT_CATALOG.terrain_definition(tile_type).get("blocks_movement", false)):
		_blocked_cells[cell] = true
	else:
		_blocked_cells.erase(cell)


func _is_terrain_visible_through(cell: Vector2i) -> bool:
	var tile_type := _terrain_type(cell)
	return not bool(OBJECT_CATALOG.terrain_definition(tile_type).get("blocks_sight", false)) and not _objects_block_cell(cell, "blocks_sight")


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


func _ensure_tile_sprite(cell: Vector2i) -> void:
	if _tile_sprites.has(cell) or not _terrain_cells.has(cell):
		return
	var sprite := _create_tile_sprite(cell)
	_tile_sprites[cell] = sprite
	_tile_root.add_child(sprite)
	var fog := _create_fog_cell(cell)
	_fog_cells[cell] = fog
	_fog_root.add_child(fog)
	var covered := not _is_ghost_mode and not _visible_cells.has(cell) and not _fog_cells_pending_hide.has(cell)
	_set_fog_visibility(cell, covered, false)


func _release_tile_sprite(cell: Vector2i) -> void:
	if _fog_tweens.has(cell):
		_fog_tweens[cell].kill()
		_fog_tweens.erase(cell)
	_tile_sprites[cell].queue_free()
	_fog_cells[cell].queue_free()
	_tile_sprites.erase(cell)
	_fog_cells.erase(cell)
	_fog_target_alpha.erase(cell)
	_fog_cells_pending_hide.erase(cell)


func _build_queued_tiles() -> void:
	var started := Time.get_ticks_usec()
	var built := 0
	while _tile_build_index < _tile_build_queue.size():
		var cell := _tile_build_queue[_tile_build_index]
		_tile_build_index += 1
		if _render_rect.has_point(cell):
			_ensure_tile_sprite(cell)
			built += 1
		if built >= TILE_BUILD_BATCH_SIZE or Time.get_ticks_usec() - started >= TILE_BUILD_BUDGET_USEC:
			break
	if _tile_build_index == _tile_build_queue.size():
		_tile_build_queue.clear()
		_tile_build_index = 0


func _refresh_tile_and_neighbors(cell: Vector2i) -> void:
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
	return not bool(OBJECT_CATALOG.terrain_definition(tile_type).get("blocks_movement", false))


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
	_apply_object_flags(item, OBJECT_CATALOG.definition(item_id))
	_items_by_cell[cell] = item
	return item


func _add_potion_cabinet(cell: Vector2i, empty := false) -> void:
	_load_chunk(_chunk_coord_for_cell(cell))
	if _terrain_type(cell) != TileType.FLOOR:
		return
	var contents: Array[String] = []
	if not empty:
		var potion_pool := OBJECT_CATALOG.potion_pool()
		if not potion_pool.is_empty():
			for index in range(_rng.randi_range(1, 3)):
				contents.append(potion_pool[_rng.randi_range(0, potion_pool.size() - 1)])
	var sprite := _add_actor(_cabinet_full_texture, cell, 1.0, 18)
	sprite.name = "PotionCabinet_%d_%d" % [cell.x, cell.y]
	_apply_object_flags(sprite, OBJECT_CATALOG.definition("empty_cabinet" if contents.is_empty() else "potion_cabinet"))
	var empty_shelves: Array[Sprite2D] = []
	for row in range(CABINET_SHELF_COUNT):
		# A filled shelf retains the original group of bottles. The native
		# background patch covers only that group's interior when it is empty.
		var patch := Sprite2D.new()
		patch.name = "EmptyShelf_%d" % (row + 1)
		var area := Rect2(CABINET_SHELF_AREAS[row])
		patch.position = area.get_center() - Vector2.ONE * CELL_SIZE * 0.5
		patch.texture = _cabinet_empty_shelf_textures[row]
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.add_child(patch)
		empty_shelves.append(patch)
	_cabinets[cell] = {"sprite": sprite, "contents": contents, "empty_shelves": empty_shelves}
	_update_cabinet_visual(cell)


func _update_cabinet_visual(cell: Vector2i) -> void:
	var cabinet: Dictionary = _cabinets[cell]
	var count: int = cabinet.contents.size()
	# One occupied shelf represents one potion. Original groups of bottles
	# stay unchanged on occupied shelves; looting empties shelves top to bottom.
	for row in range(CABINET_SHELF_COUNT):
		cabinet.empty_shelves[row].visible = row < CABINET_SHELF_COUNT - count
	_apply_object_flags(cabinet.sprite, OBJECT_CATALOG.definition("empty_cabinet" if count == 0 else "potion_cabinet"))


func _try_loot_cabinet(cell: Vector2i, direction: Vector2i) -> void:
	if _game_over or not _cabinets.has(cell) or _hero_cell + direction != cell or absi(direction.x) + absi(direction.y) != 1:
		return
	var cabinet: Dictionary = _cabinets[cell]
	if cabinet.contents.is_empty():
		if _hero_strength <= 0:
			return
		_cabinets.erase(cell)
		cabinet.sprite.hide()
		cabinet.sprite.queue_free()
	else:
		var item_id: String = cabinet.contents[0]
		var definition := OBJECT_CATALOG.definition(item_id)
		if not _add_inventory_item(_load_texture(definition.path), item_id):
			return
		cabinet.contents.pop_front()
		_update_cabinet_visual(cell)
	if direction.x != 0:
		_hero.flip_h = direction.x < 0
	# Loot and destruction are runtime state; Save keeps the authored cabinet type.
	_start_hero_action(direction)
	_advance_world_turn()
	_update_fog()


func _add_blocking_actor(
	texture: Texture2D,
	cell: Vector2i,
	scale_value: float,
	z_index: int,
	base_flip_h := false
) -> Sprite2D:
	var actor := _add_actor(texture, cell, scale_value, z_index)
	actor.set_meta("blocks_movement", true)
	actor.set_meta("blocks_sight", false)
	actor.offset = GRID.ACTOR_DRAW_OFFSET
	actor.add_child(CONTACT_SHADOW.new())
	actor.flip_h = base_flip_h
	_actor_base_flip[actor] = base_flip_h
	_enemies.append(actor)
	_actor_blocked_cells[cell] = true
	return actor


func _try_move_hero(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO or _game_over or _door_prompt_is_open():
		return
	if _is_moving:
		_finish_hero_move(false)

	_finish_goblin_animations()
	var next_cell := _hero_cell + direction
	_load_chunk(_chunk_coord_for_cell(next_cell))
	if _terrain_type(next_cell) == TileType.DOOR and not _is_ghost_mode:
		if _inventory_item_ids.has(ITEM_ID_MAGIC_KEY):
			_pending_door_cell = next_cell
			_pending_door_direction = direction
			_clear_held_movement()
			_is_painting = false
			_door_prompt.show_prompt()
		return
	if _cabinets.has(next_cell) and bool(_cabinets[next_cell].sprite.get_meta("blocks_movement", false)):
		_try_loot_cabinet(next_cell, direction)
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


func _wait_hero_turn() -> void:
	if _game_over or _hero == null or _door_prompt_is_open():
		return
	if _is_moving:
		_finish_hero_move(false)
	_finish_goblin_animations()
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn()


func _door_prompt_is_open() -> bool:
	return _door_prompt != null and _door_prompt.is_open()


func _on_door_unlock_decided(confirmed: bool) -> void:
	var cell: Variant = _pending_door_cell
	var direction := _pending_door_direction
	_pending_door_cell = null
	_pending_door_direction = Vector2i.ZERO
	_clear_held_movement()
	if not confirmed or _game_over or cell == null or _hero_cell + direction != cell or absi(direction.x) + absi(direction.y) != 1 or _terrain_type(cell) != TileType.DOOR:
		return
	var key_slot := _inventory_item_ids.find(ITEM_ID_MAGIC_KEY)
	if key_slot < 0:
		return
	_inventory.remove_at(key_slot)
	_inventory_item_ids.remove_at(key_slot)
	_set_terrain_cell(cell, TileType.FLOOR)
	_refresh_tile_and_neighbors(cell)
	_start_hero_action(direction)
	_advance_world_turn()
	_update_fog()


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
		"last_seen": null, "active": false, "habitat": "floor", "retaliates_only": false, "label": _add_strength_label(actor)}
	_goblins_by_cell[cell] = actor_id
	_apply_enemy_visibility(_goblins[actor_id])
	return actor_id


func _sync_active_goblins() -> void:
	var hero_chunk := _chunk_coord_for_cell(_hero_cell)
	for actor_id: int in _goblins:
		var goblin: Dictionary = _goblins[actor_id]
		if goblin.retaliates_only:
			# Rooted flora never participates in autonomous turns, even beside the hero.
			goblin.active = false
			_turn_queue.cancel(actor_id)
			continue
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


func _advance_world_turn(skip_boost_tick := false, skip_water_breathing_tick := false, skip_speed_tick := false, force_world_turn := false) -> void:
	if _game_over or _door_prompt_is_open():
		return
	# Starting a potion in the first half of a fast turn protects its duration
	# through the whole pair. Renewing speed must never reset the pair's phase.
	if skip_boost_tick:
		_effects_started_this_turn["strength"] = true
	if skip_water_breathing_tick:
		_effects_started_this_turn["water_breathing"] = true
	if skip_speed_tick:
		_effects_started_this_turn["speed"] = true
	if _speed_boost_turns > 0 and not force_world_turn:
		_speed_actions_this_turn += 1
		if _speed_actions_this_turn < 2:
			# Reaching dry land restores breath immediately, even on a free action.
			if not _hero_is_in_water():
				_hero_breath = MAX_BREATH
				_was_in_water = false
			_refresh_inventory_panel()
			_update_enemy_facing(_cell_center(_hero_cell))
			return
	_speed_actions_this_turn = 0
	_sync_active_goblins()
	_turn_queue.advance()
	var actor_id := _turn_queue.pop_due()
	while actor_id != -1 and not _game_over:
		if _goblins.has(actor_id):
			_take_goblin_turn(actor_id)
			if _goblins.has(actor_id) and not _game_over and not _goblins[actor_id].retaliates_only:
				_turn_queue.schedule_after(actor_id, GOBLIN_AI.next_delay(_rng))
		actor_id = _turn_queue.pop_due()
	if not _game_over:
		_advance_water_turn()
		if not _effects_started_this_turn.has("strength") and _strength_boost_turns > 0:
			_strength_boost_turns -= 1
		if not _effects_started_this_turn.has("water_breathing") and _water_breathing_turns > 0:
			_water_breathing_turns -= 1
		if not _effects_started_this_turn.has("speed") and _speed_boost_turns > 0:
			_speed_boost_turns -= 1
	_effects_started_this_turn.clear()
	_refresh_inventory_panel()
	_update_enemy_facing(_cell_center(_hero_cell))


func _hero_is_in_water() -> bool:
	return _terrain_type(_hero_cell) == TileType.WATER


func _advance_water_turn() -> void:
	if not _hero_is_in_water():
		_hero_breath = MAX_BREATH
		_was_in_water = false
		return
	if not _was_in_water:
		# Entry itself shows a full reserve; subsequent actions spend it.
		_was_in_water = true
		_hero_breath = MAX_BREATH
		return
	if _water_breathing_turns > 0:
		return
	if _hero_breath > 0:
		_hero_breath -= 1
	else:
		_hero_strength -= DROWNING_STRENGTH_LOSS
		_check_hero_death()


func _update_hero_water_visual() -> void:
	if _hero == null or _hero_water_material == null:
		return
	var in_water := _hero_is_in_water()
	var fraction := MAX_SUBMERGE_FRACTION * (1.0 - float(_hero_breath) / MAX_BREATH) if in_water else 0.0
	var pixels := roundf(_hero.texture.get_height() * fraction)
	_hero.offset = GRID.ACTOR_DRAW_OFFSET + Vector2(0.0, pixels)
	_hero_water_material.set_shader_parameter("submerged_pixels", pixels)
	_hero.get_node("ContactShadow").visible = not in_water


func _take_goblin_turn(actor_id: int) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	if goblin.retaliates_only:
		return
	var cell: Vector2i = goblin.cell
	var plan := GOBLIN_AI.plan(cell, _hero_cell, goblin.last_seen,
		_enemy_can_step.bind(str(goblin.habitat)), _actor_can_see, _rng)
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
	return _enemy_can_step(cell, "floor")


func _enemy_can_step(cell: Vector2i, habitat: String) -> bool:
	var allowed_terrain := TileType.WATER if habitat == "water" else TileType.FLOOR
	return _terrain_cells.has(cell) and _terrain_type(cell) == allowed_terrain and not _objects_block_cell(cell, "blocks_movement") and (
		cell == _hero_cell or not _actor_blocked_cells.has(cell))


func _actor_can_see(origin: Vector2i, target: Vector2i) -> bool:
	return _calculate_visible_cells(origin).has(target)


func _animate_goblin(actor_id: int, target: Vector2, attack := false) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	_apply_enemy_visibility(goblin)
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
	if _game_over or not _goblins.has(actor_id):
		return
	var goblin: Dictionary = _goblins[actor_id]
	var strength_before := _hero_strength
	var weapon_bonus := _weapon_strength_bonus()
	var total := COMBAT.effective_strength(_hero_strength, weapon_bonus, _strength_multiplier()) + maxi(int(goblin.strength), 0)
	var roll := _rng.randi_range(0, total - 1) if total > 0 else 0
	var result := COMBAT.exchange(_hero_strength, int(goblin.strength), weapon_bonus, roll, _strength_multiplier())
	_hero_strength = result.player
	goblin.strength = result.enemy
	if goblin.retaliates_only and _hero_strength < strength_before:
		_animate_goblin(actor_id, _cell_center(_hero_cell), true)
	if result.killed:
		_gain_hero_strength(ENEMY_KILL_STRENGTH_GAIN)
		_remove_goblin(actor_id)
	_check_hero_death()
	_refresh_combat_labels()


func _check_hero_death() -> void:
	if not _game_over and _hero_strength < COMBAT.DEATH_THRESHOLD:
		_game_over = true
		_clear_held_movement()
		# Combat and drowning share the same deferred restart.
		_restart_after_death.call_deferred()


func _restart_after_death() -> void:
	if _game_over:
		_build_scene()


func _gain_hero_strength(amount: int) -> void:
	_hero_strength += amount
	_hero_max_strength += amount


func _weapon_strength_bonus() -> int:
	# A weapon supplies a permanent bonus; carrying duplicate swords does not stack it.
	var bonus := 0
	for item_id in _inventory_item_ids:
		bonus = maxi(bonus, int(OBJECT_CATALOG.definition(item_id).get("weapon_bonus", 0)))
	return bonus


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
	sprite.hide()
	sprite.queue_free()


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
	var strength_color := Color(1.0, 0.4, 0.35) if _hero_strength <= 0 else Color.WHITE
	var weapon_bonus := _weapon_strength_bonus()
	var in_water := _hero_is_in_water()
	if _hero_breath_label != null:
		_hero_breath_label.text = str(_hero_breath)
		_hero_breath_label.visible = in_water
	if _stats_breath_label != null:
		_stats_breath_label.text = "Дыхание: %d" % _hero_breath
		_stats_breath_label.visible = in_water
	if _stats_water_breathing_label != null:
		_stats_water_breathing_label.text = "Водное дыхание: %d ход." % _water_breathing_turns
		_stats_water_breathing_label.visible = _water_breathing_turns > 0
	_update_hero_water_visual()
	if _hero_strength_label != null:
		_hero_strength_label.text = str(_hero_strength * _strength_multiplier() + weapon_bonus)
		_hero_strength_label.modulate = strength_color
	if _stats_strength_label != null:
		_stats_strength_label.text = "Сила: %d/%d" % [_hero_strength, _hero_max_strength]
		if _strength_boost_turns > 0:
			_stats_strength_label.text += "×2"
		if weapon_bonus > 0:
			_stats_strength_label.text += "+%d" % weapon_bonus
		_stats_strength_label.modulate = strength_color
	if _stats_magic_label != null:
		_stats_magic_label.text = "Магия: %d" % _hero_magic
	if _stats_boost_label != null:
		_stats_boost_label.text = "Усиление силы: %d ход." % _strength_boost_turns if _strength_boost_turns > 0 else ""
		_stats_boost_label.visible = _strength_boost_turns > 0
	if _stats_speed_label != null:
		_stats_speed_label.text = "Скорость: %d ход." % _speed_boost_turns
		_stats_speed_label.visible = _speed_boost_turns > 0
	for goblin: Dictionary in _goblins.values():
		goblin.label.text = str(goblin.strength)
	_update_enemy_visibility()


func _update_enemy_visibility() -> void:
	for goblin: Dictionary in _goblins.values():
		_apply_enemy_visibility(goblin)


func _apply_enemy_visibility(goblin: Dictionary) -> void:
	var sprite: Sprite2D = goblin.sprite
	var label: Label = goblin.label
	var fog := _fog_cells.get(goblin.cell) as ColorRect
	var alpha := 1.0 - fog.self_modulate.a if fog != null else (1.0 if _is_ghost_mode else 0.0)
	# Fade the whole actor by its own cell, including protruding pixels and children.
	# modulate is inherited by the shadow and the label, even with absolute z_index.
	sprite.modulate.a = alpha
	sprite.visible = alpha > 0.0
	label.self_modulate.a = 1.0
	label.visible = alpha > 0.0


func _update_enemy_facing(target_position: Variant = null) -> void:
	if _hero == null:
		return

	var hero_position: Vector2 = _hero.position if target_position == null else target_position
	for enemy in _enemies:
		if enemy == null:
			continue
		if bool(enemy.get_meta("retaliates_only", false)):
			continue
		if is_equal_approx(enemy.position.x, hero_position.x):
			continue
		var face_left := hero_position.x < enemy.position.x
		enemy.flip_h = face_left != _actor_base_flip.get(enemy, false)


func _try_pickup_item(cell: Vector2i) -> void:
	if not _items_by_cell.has(cell):
		return

	var item := _items_by_cell[cell] as Sprite2D
	if not is_instance_valid(item):
		_items_by_cell.erase(cell)
		return

	var item_id := str(item.get_meta("item_id", ITEM_ID_SWORD))
	var definition := OBJECT_CATALOG.definition(item_id)
	if definition.has("strength_gain"):
		# Strength pickups take effect immediately and never need an inventory slot.
		_gain_hero_strength(int(definition.strength_gain))
	elif not _add_inventory_item(item.texture, item_id):
		return
	_items_by_cell.erase(cell)
	item.hide()
	item.queue_free()
	_refresh_combat_labels()


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
	var panel_height := slot_size * INVENTORY_ROWS + 8.0 * (INVENTORY_ROWS - 1) + 10.0
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
	panel.offset_right = UI_PANEL_MARGIN + slot_size * INVENTORY_COLUMNS + 8.0 * (INVENTORY_COLUMNS - 1) + 16.0
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.052, 0.047, 0.86), 2, Color(0.18, 0.16, 0.13, 0.95)))
	canvas.add_child(panel)

	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = INVENTORY_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)

	for i in range(INVENTORY_SIZE):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _slot_style())
		slot.gui_input.connect(_on_inventory_slot_gui_input.bind(i))
		grid.add_child(slot)

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


func _build_stats_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "StatsCanvas"
	canvas.layer = 20
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	panel.position = Vector2(UI_PANEL_MARGIN, UI_PANEL_MARGIN)
	panel.custom_minimum_size.x = 240.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.052, 0.047, 0.86), 2, Color(0.18, 0.16, 0.13, 0.95)))
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_stats_breath_label = Label.new()
	_stats_breath_label.name = "HeroBreath"
	_stats_breath_label.add_theme_font_size_override("font_size", 18)
	_stats_breath_label.modulate = BREATH_COLOR
	_stats_breath_label.tooltip_text = "Запас дыхания в воде. После исчерпания каждый ход в воде отнимает 1 собственной силы."
	column.add_child(_stats_breath_label)
	_stats_strength_label = Label.new()
	_stats_strength_label.name = "HeroStrength"
	_stats_strength_label.custom_minimum_size.y = STATS_ROW_HEIGHT
	_stats_strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats_strength_label.add_theme_font_size_override("font_size", 18)
	_stats_strength_label.tooltip_text = "Своя сила / максимум + постоянный бонус оружия"
	column.add_child(_stats_strength_label)
	_stats_magic_label = Label.new()
	_stats_magic_label.name = "HeroMagic"
	_stats_magic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats_magic_label.add_theme_font_size_override("font_size", 18)
	_stats_magic_label.tooltip_text = "Лечение: 3 × Магия. Сила и скорость: Магия ходов мира. Применение зелья даёт +1 магию."
	column.add_child(_stats_magic_label)
	_stats_boost_label = Label.new()
	_stats_boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats_boost_label.add_theme_font_size_override("font_size", 15)
	_stats_boost_label.modulate = Color(0.65, 1.0, 0.55)
	column.add_child(_stats_boost_label)
	_stats_speed_label = Label.new()
	_stats_speed_label.name = "HeroSpeed"
	_stats_speed_label.add_theme_font_size_override("font_size", 15)
	_stats_speed_label.modulate = Color(1.0, 0.78, 0.35)
	column.add_child(_stats_speed_label)
	_stats_water_breathing_label = Label.new()
	_stats_water_breathing_label.add_theme_font_size_override("font_size", 15)
	_stats_water_breathing_label.modulate = BREATH_COLOR
	column.add_child(_stats_water_breathing_label)

	_refresh_combat_labels()


func _refresh_inventory_panel() -> void:
	var icon_size := _inventory_icon_size()
	for i in range(_inventory_slot_icons.size()):
		var icon := _inventory_slot_icons[i]
		icon.texture = _inventory[i] if i < _inventory.size() else null
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = Vector2(icon_size, icon_size)
		var slot := icon.get_parent().get_parent() as Control
		slot.tooltip_text = ""
		if i < _inventory_item_ids.size():
			var definition := OBJECT_CATALOG.definition(_inventory_item_ids[i])
			slot.tooltip_text = definition.get("name", "")
			if _inventory_item_ids[i] == ITEM_ID_MAGIC_KEY:
				slot.tooltip_text += "\nОдноразовый. При попытке пройти в закрытую дверь можно подтвердить расход ключа."
			match definition.get("potion_effect", ""):
				"heal":
					slot.tooltip_text += "\nВосстанавливает до %d силы (3 × Магия), +1 магия. Нажмите, чтобы выпить." % (_hero_magic * HEALTH_POTION_MAGIC_FACTOR)
				"strength":
					slot.tooltip_text += "\nУдваивает свою силу на %d ходов, +1 магия. Повторное применение обновляет срок." % _hero_magic
				"water_breathing":
					slot.tooltip_text += "\nСохраняет дыхание и защищает от утопления на %d ходов (3 × Магия), +1 магия." % (_hero_magic * WATER_BREATHING_MAGIC_FACTOR)
				"speed":
					slot.tooltip_text += "\nДаёт 2 действия на ход мира на %d ходов, +1 магия. Повторное применение обновляет срок." % _hero_magic
	_refresh_combat_labels()


func _on_inventory_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate_inventory_slot(slot_index)
		get_viewport().set_input_as_handled()


func _activate_inventory_slot(slot_index: int) -> void:
	if _game_over or _door_prompt_is_open() or (_hero_picker != null and _hero_picker.is_open()) or slot_index < 0 or slot_index >= _inventory_item_ids.size():
		return
	var item_id := _inventory_item_ids[slot_index]
	if item_id == ITEM_ID_GHOST_RING:
		_set_ghost_mode(not _is_ghost_mode)
		return
	var definition := OBJECT_CATALOG.definition(item_id)
	match definition.get("potion_effect", ""):
		"heal":
			_drink_health_potion(slot_index)
		"strength":
			_drink_strength_potion(slot_index)
		"water_breathing":
			_drink_water_breathing_potion(slot_index)
		"speed":
			_drink_speed_potion(slot_index)


func _drink_health_potion(slot_index: int) -> void:
	if _hero_strength >= _hero_max_strength:
		return
	_prepare_potion_action()
	_hero_strength = mini(_hero_max_strength, _hero_strength + _hero_magic * HEALTH_POTION_MAGIC_FACTOR)
	_finish_potion_action(slot_index)


func _drink_strength_potion(slot_index: int) -> void:
	_prepare_potion_action()
	_strength_boost_turns = _hero_magic
	_finish_potion_action(slot_index, true)


func _drink_water_breathing_potion(slot_index: int) -> void:
	_prepare_potion_action()
	_water_breathing_turns = _hero_magic * WATER_BREATHING_MAGIC_FACTOR
	_finish_potion_action(slot_index, false, true)


func _drink_speed_potion(slot_index: int) -> void:
	_prepare_potion_action()
	var starts_speed := _speed_boost_turns == 0
	_speed_boost_turns = _hero_magic
	# Initial drinking costs one ordinary world turn; subsequent renewal uses
	# the current two-action cadence rather than granting another free action.
	_finish_potion_action(slot_index, false, false, true, starts_speed)


func _strength_multiplier() -> int:
	return 2 if _strength_boost_turns > 0 else 1


func _prepare_potion_action() -> void:
	if _is_moving:
		_finish_hero_move(false)
	_finish_goblin_animations()


func _finish_potion_action(slot_index: int, starts_boost := false, starts_water_breathing := false, starts_speed := false, force_world_turn := false) -> void:
	_hero_magic += 1
	_inventory.remove_at(slot_index)
	_inventory_item_ids.remove_at(slot_index)
	_refresh_inventory_panel()
	_try_pickup_item(_hero_cell)
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn(starts_boost, starts_water_breathing, starts_speed, force_world_turn)


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
	_editor_canvas = canvas
	canvas.hide()
	var panel := PanelContainer.new()
	panel.name = "TileEditorPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = UI_PANEL_MARGIN
	panel.offset_bottom = UI_PANEL_MARGIN + 228.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.052, 0.047, 0.94), 2, Color(0.18, 0.16, 0.13, 0.95)))
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_loaded_chunks)
	row.add_child(save_button)
	_editor_status_label = Label.new()
	_editor_status_label.text = "Выбрано: Пол"
	_editor_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_editor_status_label)
	_hero_coords_label = Label.new()
	column.add_child(_hero_coords_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 156.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_editor_palette = GridContainer.new()
	_editor_palette.columns = 9
	_editor_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor_palette)
	_rebuild_editor_palette()


func _rebuild_editor_palette() -> void:
	for child in _editor_palette.get_children():
		child.free()
	for definition in OBJECT_CATALOG.definitions():
		if definition.get("procedural", false):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(66.0, 66.0)
		button.icon = _cabinet_empty_texture if definition.category == "cabinet" and definition.get("empty", false) else _load_texture(definition.path)
		button.expand_icon = true
		button.tooltip_text = definition.name
		button.set_meta("object_type", definition.id)
		button.pressed.connect(_select_editor_object.bind(definition.id))
		_editor_palette.add_child(button)
	var erase_button := Button.new()
	erase_button.text = "Убрать"
	erase_button.custom_minimum_size = Vector2(66.0, 66.0)
	erase_button.tooltip_text = "Удалить объект; пол остаётся"
	erase_button.pressed.connect(_select_editor_object.bind("erase"))
	_editor_palette.add_child(erase_button)


func _select_editor_object(type_id: String) -> void:
	_selected_object_id = type_id
	var definition := OBJECT_CATALOG.definition(type_id)
	if definition.get("category") == "terrain":
		_selected_tile_type = definition.tile
	if _editor_status_label != null:
		_editor_status_label.text = "Выбрано: %s" % definition.get("name", "Убрать объект")


func _toggle_editor() -> void:
	if _editor_canvas == null:
		return
	_editor_canvas.visible = not _editor_canvas.visible
	if _editor_canvas.visible:
		_rebuild_editor_palette()
	_is_painting = false
	_last_painted_cell = Vector2i(2147483647, 2147483647)


func _select_editor_tile(tile_type: TileType) -> void:
	_select_editor_object(OBJECT_CATALOG.definitions()[tile_type].id)


func _paint_selected_tile(cell: Vector2i) -> void:
	if _game_over or _door_prompt_is_open() or _editor_canvas == null or not _editor_canvas.visible:
		return
	_load_chunk(_chunk_coord_for_cell(cell))
	if not _loaded_chunks.has(_chunk_coord_for_cell(cell)):
		return
	var definition := OBJECT_CATALOG.definition(_selected_object_id)
	if definition.get("category") == "terrain":
		_set_editor_terrain_cell(cell, _selected_tile_type)
		if _goblins_by_cell.has(cell):
			var enemy: Dictionary = _goblins[_goblins_by_cell[cell]]
			if not OBJECT_CATALOG.can_place_on(enemy.type, _selected_tile_type):
				_set_editor_map_object(enemy.sprite.get_meta("map_origin", cell), "")
		var authored_type: String = _authored_map_objects().get(cell, "")
		if not authored_type.is_empty() and not OBJECT_CATALOG.can_place_on(authored_type, _selected_tile_type):
			_set_editor_map_object(cell, "")
	else:
		if _selected_object_id != "erase" and (not OBJECT_CATALOG.can_place_on(_selected_object_id, _terrain_type(cell)) or (cell == _hero_cell and _selected_object_id != "hero_start")):
			_editor_status_label.text = "Нужна свободная клетка воды" if definition.get("habitat") == "water" else "Нужна свободная клетка пола"
			return
		# A moving enemy retains its authored origin; explicitly erasing it removes that spawn.
		if _goblins_by_cell.has(cell):
			var actor: Sprite2D = _goblins[_goblins_by_cell[cell]].sprite
			var origin: Vector2i = actor.get_meta("map_origin", cell)
			_set_editor_map_object(origin, "")
		if _selected_object_id == "hero_start":
			for origin: Vector2i in _authored_map_objects():
				if _authored_map_objects()[origin] == "hero_start":
					_set_editor_map_object(origin, "")
			_set_editor_map_object(cell, "hero_start")
			_hero_cell = cell
			_finish_hero_move(false)
		else:
			_set_editor_map_object(cell, "" if _selected_object_id == "erase" else _selected_object_id)
	_last_painted_cell = cell
	_sync_active_goblins()
	_refresh_tile_and_neighbors(cell)
	_update_fog()
	_refresh_combat_labels()
	_update_editor_coords()
	_editor_status_label.text = "Изменено: %s %s" % [definition.get("name", "Удаление"), str(cell)]


func _set_editor_map_object(cell: Vector2i, type_id: String) -> void:
	if OBJECT_CATALOG.definition(type_id).get("procedural", false):
		return
	_remove_procedural_item(cell)
	_erase_live_map_object(cell)
	if type_id == _saved_map_objects.get(cell, ""):
		_editor_object_changes.erase(cell)
	else:
		_editor_object_changes[cell] = type_id
	_spawned_map_objects.erase(cell)
	if not type_id.is_empty():
		_spawn_map_object(cell, type_id)


func _set_editor_terrain_cell(cell: Vector2i, tile_type: TileType) -> void:
	_set_terrain_cell(cell, tile_type)
	if _blocked_cells.has(cell):
		_remove_procedural_item(cell)
	var chunk_coord := _chunk_coord_for_cell(cell)
	var local_cell := cell - chunk_coord * CHUNK_SIZE
	var saved: PackedByteArray = _saved_chunk_cells[chunk_coord]
	if tile_type == saved[local_cell.y * CHUNK_SIZE.x + local_cell.x]:
		_editor_changes.erase(cell)
	else:
		_editor_changes[cell] = tile_type


func _remove_procedural_item(cell: Vector2i) -> void:
	if not _items_by_cell.has(cell):
		return
	var item: Sprite2D = _items_by_cell[cell]
	if not OBJECT_CATALOG.definition(item.get_meta("item_id", "")).get("procedural", false):
		return
	_items_by_cell.erase(cell)
	item.hide()
	item.queue_free()


func _update_editor_coords() -> void:
	if _hero_coords_label == null:
		return
	_hero_coords_label.text = "Hero: %s  Chunk: %s  %s" % [
		str(_hero_cell),
		str(_chunk_coord_for_cell(_hero_cell)),
		"Ghost" if _is_ghost_mode else "Body",
	]


func _save_loaded_chunks() -> void:
	var edited_chunks: Dictionary = {}
	for cell: Vector2i in _editor_changes:
		edited_chunks[_chunk_coord_for_cell(cell)] = true
	if edited_chunks.is_empty() and _editor_object_changes.is_empty():
		if _editor_status_label != null:
			_editor_status_label.text = "No editor changes to save"
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_chunk_path_template.get_base_dir()))
	var saved_count := 0
	for chunk_coord: Vector2i in edited_chunks:
		if _save_chunk(chunk_coord):
			saved_count += 1
	var objects_saved := true
	if not _editor_object_changes.is_empty():
		var objects := _authored_map_objects()
		objects_saved = saved_count == edited_chunks.size() and _map_objects_valid and MAP_OBJECTS.save_map(MAP_OBJECTS.path_for_chunks(_chunk_path_template), objects)
		if objects_saved:
			_saved_map_objects = objects
			_editor_object_changes.clear()
		else:
			push_error("Could not save map objects")
	if _editor_status_label != null:
		_editor_status_label.text = "Сохранено: %d/%d чанков; объекты %s" % [saved_count, edited_chunks.size(), "OK" if objects_saved else "ошибка"]


func _save_chunk(chunk_coord: Vector2i) -> bool:
	if not _saved_chunk_cells.has(chunk_coord):
		return false
	var cells: PackedByteArray = _saved_chunk_cells[chunk_coord].duplicate()
	var changes: Array[Vector2i] = []
	var origin := chunk_coord * CHUNK_SIZE
	for cell: Vector2i in _editor_changes:
		if _chunk_coord_for_cell(cell) == chunk_coord:
			var local_cell := cell - origin
			cells[local_cell.y * CHUNK_SIZE.x + local_cell.x] = _editor_changes[cell]
			changes.append(cell)
	if changes.is_empty():
		return false
	var path := ProjectSettings.globalize_path(_chunk_path_template % [chunk_coord.x, chunk_coord.y])
	var temporary_path := "%s.tmp-%d" % [path, OS.get_process_id()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save chunk: %s" % path)
		return false
	for y in range(CHUNK_SIZE.y):
		var row := ""
		for x in range(CHUNK_SIZE.x):
			row += _map_char_from_tile_type(cells[y * CHUNK_SIZE.x + x])
		file.store_line(row)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary_path, path) != OK:
		DirAccess.remove_absolute(temporary_path)
		push_error("Could not replace saved chunk: %s" % path)
		return false
	_saved_chunk_cells[chunk_coord] = cells
	for cell in changes:
		_editor_changes.erase(cell)
	return true


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


func _apply_object_flags(sprite: Sprite2D, definition: Dictionary) -> void:
	# Collision and visibility are independent; missing flags default to false.
	sprite.set_meta("blocks_movement", bool(definition.get("blocks_movement", false)))
	sprite.set_meta("blocks_sight", bool(definition.get("blocks_sight", false)))


func _objects_block_cell(cell: Vector2i, flag: String) -> bool:
	if _cabinets.has(cell) and bool(_cabinets[cell].sprite.get_meta(flag, false)):
		return true
	if _props_by_cell.has(cell) and bool(_props_by_cell[cell].get_meta(flag, false)):
		return true
	if _items_by_cell.has(cell) and bool(_items_by_cell[cell].get_meta(flag, false)):
		return true
	if _goblins_by_cell.has(cell):
		return bool(_goblins[_goblins_by_cell[cell]].sprite.get_meta(flag, false))
	return false


func _is_walkable(cell: Vector2i) -> bool:
	_load_chunk(_chunk_coord_for_cell(cell))
	if _actor_blocked_cells.has(cell) or _objects_block_cell(cell, "blocks_movement"):
		return false
	if _is_ghost_mode:
		return true
	return not _blocked_cells.has(cell)


func _update_visible_chunks(center_position: Variant = null) -> void:
	if _camera == null or _tile_root == null:
		return
	var camera_position: Vector2 = _camera.position if center_position == null else center_position
	var center := _cell_from_world(camera_position)
	var core := Rect2i(center - Vector2i.ONE * RENDER_CORE_RADIUS, Vector2i.ONE * (RENDER_CORE_RADIUS * 2 + 1))
	var wanted := core.grow(RENDER_PADDING_CELLS)
	if wanted == _render_rect:
		return
	# The visible area plus one cell is immediate. Its outer margin is prepared
	# over subsequent frames, ahead of the moving camera.
	var data_rect := wanted.grow(1)
	var min_chunk := _chunk_coord_for_cell(data_rect.position)
	var max_chunk := _chunk_coord_for_cell(data_rect.end - Vector2i.ONE)
	for y in range(min_chunk.y, max_chunk.y + 1):
		for x in range(min_chunk.x, max_chunk.x + 1):
			_load_chunk(Vector2i(x, y))
	_prefetch_nearby_chunks(_chunk_coord_for_cell(center))
	_render_rect = wanted
	for cell: Vector2i in _tile_sprites.keys():
		if not wanted.has_point(cell):
			_release_tile_sprite(cell)
	_tile_build_queue.clear()
	_tile_build_index = 0
	for y in range(wanted.position.y, wanted.end.y):
		for x in range(wanted.position.x, wanted.end.x):
			var cell := Vector2i(x, y)
			if core.has_point(cell):
				_ensure_tile_sprite(cell)
			elif not _tile_sprites.has(cell):
				_tile_build_queue.append(cell)
	_update_fog()


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
		_update_enemy_visibility()
		return

	var next_visible_cells := _calculate_visible_cells(_hero_cell)
	for cell in _visible_cells:
		if _fog_cells.has(cell) and not next_visible_cells.has(cell) and not _is_inside_hero_sight(cell, _hero_cell):
			_fog_cells_pending_hide[cell] = true
	_visible_cells = next_visible_cells
	_hide_fog_cells_outside_view()
	for cell in _fog_cells:
		var fog := _fog_cells[cell] as ColorRect
		var covered := not _visible_cells.has(cell) and not _fog_cells_pending_hide.has(cell)
		# Incoming and outgoing view bands slide with the camera; only interior sight changes fade.
		var inside_shared_sight := had_previous_sight and _is_inside_hero_sight(cell, previous_origin) and _is_inside_hero_sight(cell, _hero_cell)
		_set_fog_visibility(cell, covered, inside_shared_sight and world_rect.intersects(fog.get_global_rect()))
	_update_enemy_visibility()


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
		_update_enemy_visibility()
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
