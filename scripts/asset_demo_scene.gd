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
const ADVENTURE_PROMPT := preload("res://scripts/adventure_prompt.gd")
const FIELD_TARGET := preload("res://scripts/field_target.gd")
const ACTOR_SINK := preload("res://scripts/actor_sink.gd")
const PREVIOUS_RUN := preload("res://scripts/previous_run.gd")
const INVENTORY_SLOT := preload("res://scripts/inventory_slot.gd")
const FLOATING_TEXT := preload("res://scripts/floating_text.gd")
const PICKUP_FLIGHT := preload("res://scripts/pickup_flight.gd")
const MAX_FLOATING_TEXTS := 4
const MAX_PICKUP_FLIGHTS := 16
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
	EARTH,
	EARTH_FLOOR,
	BEDROCK,
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
	{"name_key": "HERO_NAME_MAGE_ROGUE", "path": "res://assets/actors/heroes/series_01/01_mage_rogue.png"},
	{"name_key": "HERO_NAME_KNIGHT", "path": "res://assets/actors/heroes/series_01/02_knight.png"},
	{"name_key": "HERO_NAME_RANGER", "path": "res://assets/actors/heroes/series_01/03_ranger.png"},
	{"name_key": "HERO_NAME_BARBARIAN", "path": "res://assets/actors/heroes/series_01/04_barbarian.png"},
	{"name_key": "HERO_NAME_FIRE_MAGE", "path": "res://assets/actors/heroes/series_01/05_fire_mage.png"},
	{"name_key": "HERO_NAME_FROST_MAGE", "path": "res://assets/actors/heroes/series_01/06_frost_mage.png"},
	{"name_key": "HERO_NAME_PALADIN", "path": "res://assets/actors/heroes/series_01/07_paladin.png"},
	{"name_key": "HERO_NAME_DWARF_WARRIOR", "path": "res://assets/actors/heroes/series_01/08_dwarf_warrior.png"},
	{"name_key": "HERO_NAME_ELF_HUNTRESS", "path": "res://assets/actors/heroes/series_01/09_elf_huntress.png"},
	{"name_key": "HERO_NAME_DUELIST", "path": "res://assets/actors/heroes/series_01/10_duelist.png"},
	{"name_key": "HERO_NAME_DRUID", "path": "res://assets/actors/heroes/series_01/11_druid.png"},
	{"name_key": "HERO_NAME_ROGUE", "path": "res://assets/actors/heroes/series_01/12_rogue.png"},
	{"name_key": "HERO_NAME_CLERIC", "path": "res://assets/actors/heroes/series_01/13_cleric.png"},
	{"name_key": "HERO_NAME_MONK", "path": "res://assets/actors/heroes/series_01/14_monk.png"},
	{"name_key": "HERO_NAME_ALCHEMIST", "path": "res://assets/actors/heroes/series_01/15_alchemist.png"},
	{"name_key": "HERO_NAME_HALFLING", "path": "res://assets/actors/heroes/series_01/16_halfling.png"},
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
const HEALTH_POTION_MAGIC_FACTOR := 2
const MELEE_KILL_STRENGTH_GAIN := 1
const ITEM_ID_SWORD := "sword"
const ITEM_ID_GHOST_RING := "ghost_ring"
const ITEM_ID_STRENGTH_CRYSTAL := "strength_crystal"
const ITEM_ID_HEALTH_POTION := "health_potion"
const ITEM_ID_STRENGTH_POTION := "strength_potion"
const ITEM_ID_WATER_BREATHING_POTION := "water_breathing_potion"
const ITEM_ID_SPEED_POTION := "speed_potion"
const ITEM_ID_MAGIC_KEY := "magic_key"
const ITEM_ID_PICKAXE := "pickaxe"
const ITEM_ID_BOMB := "bomb"
const ITEM_ID_PUSH_SCROLL := "push_scroll"
const PUSH_DISTANCE := 5
const BOMB_FUSE_TURNS := 3
const BOMB_DAMAGE := 100

var _built := false
var _hero: Sprite2D
var _hero_normal_texture: Texture2D
var _hero_ghost_texture: Texture2D
var _selected_hero_index := 0
var _hero_picker: HERO_PICKER
var _door_prompt: DOOR_UNLOCK_PROMPT
var _encounter_prompt: ADVENTURE_PROMPT
var _field_target: FIELD_TARGET
var _seen_encounters: Dictionary = {}
var _encounter_candidates: Dictionary = {}
var _sight_revision := 0
var _encounter_sight_revision := -1
var _encounter_sight_origin := Vector2i.ZERO
var _encounter_sight_cache: Dictionary = {}
var _pending_target_slot := -1
var _pending_target_item_id := ""
var _pending_target_revision := -1
var _pending_world_action: Dictionary = {}
var _world_turn_pending := false
var _pending_encounter_attack := -1
var _petrified := false
var _remains_save_path := ""
var _previous_remains: Dictionary = {}
var _previous_remains_sprite: Sprite2D
var _death_recorded := false
var _pending_door_cell: Variant = null
var _pending_door_direction := Vector2i.ZERO
var _pending_tool_item_id := ""
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
var _push_tweens: Dictionary = {}
var _sinking_actors: Dictionary = {}
var _prone_texture_cache: Dictionary = {}
var _next_goblin_id := 0
var _turn_queue := TURN_QUEUE.new()
var _rng := RandomNumberGenerator.new()
var _hero_strength := COMBAT.START_STRENGTH
var _floating_texts: Dictionary = {}
var _floating_canvas: CanvasLayer
var _exhaustion_popup: FLOATING_TEXT
var _hero_max_strength := COMBAT.START_STRENGTH
var _hero_magic := START_MAGIC
var _strength_boost_turns := 0
var _speed_boost_turns := 0
var _speed_actions_this_turn := 0
var _effects_started_this_turn: Dictionary = {}
var _hero_breath := MAX_BREATH
var _was_in_water := false
var _water_breathing_turns := 0
var _petrification_protection_turns := 0
var _money := 0
var _stats_money_label: Label
var _stats_petrification_label: Label
var _hero_breath_label: Label
var _stats_breath_label: Label
var _stats_water_breathing_label: Label
var _hero_water_material: ShaderMaterial
var _potion_flash_tween: Tween
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
var _pickup_canvas: CanvasLayer
var _pickup_flights: Dictionary = {}
var _items_by_cell: Dictionary = {}
var _ground_extras: Dictionary = {}
var _equipped_weapon_id := ""
var _equipped_weapon_texture: Texture2D
var _inventory_revision := 0
var _weapon_slot: INVENTORY_SLOT
var _weapon_icon: TextureRect
var _inventory_panel: PanelContainer
var _inventory_scroll: ScrollContainer
var _stats_panel: PanelContainer
var _floor_grid: GridContainer
var _floor_entries: Array[Dictionary] = []
var _floor_signature := ""
var _blast_depth := 0
var _pending_enemy_loot: Array[Dictionary] = []
var _cabinets: Dictionary = {}
var _props_by_cell: Dictionary = {}
var _cabinet_empty_texture: Texture2D
var _cabinet_visual_cache: Dictionary = {}
var _bombs_by_cell: Dictionary = {}
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
var _earth_cells: Dictionary = {}
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
		_update_item_panel_layout()
		_hovered_cell = _cell_from_world(get_global_mouse_position())
		if _is_painting and not _player_controls_are_locked() and not _game_over and (_hero_picker == null or not _hero_picker.is_open()) and _hovered_cell != _last_painted_cell:
			_paint_selected_tile(_hovered_cell)
		_continue_held_movement()


func _exit_tree() -> void:
	if _chunk_loader != null:
		_chunk_loader.close()
		_chunk_loader = null


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _field_target_is_active():
		return
	if event is InputEventKey:
		_handle_field_target_key(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		# Inventory/editor buttons must not change the chosen scroll or map.
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or event.echo:
		return
	if _encounter_prompt != null and _encounter_prompt.is_open():
		_encounter_prompt.handle_key(event)
		get_viewport().set_input_as_handled()
		return
	if _field_target_is_active():
		_handle_field_target_key(event)
		get_viewport().set_input_as_handled()
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
	if _hero == null or _game_over or _is_moving or _player_controls_are_locked() or (_hero_picker != null and _hero_picker.is_open()):
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
	if _player_controls_are_locked() or (_hero_picker != null and _hero_picker.is_open()):
		get_viewport().set_input_as_handled()
		return
	if _game_over or _editor_canvas == null or not _editor_canvas.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_paint_selected_tile(_cell_from_world(get_global_mouse_position()))
		get_viewport().set_input_as_handled()


func _build_scene() -> void:
	for flight: PICKUP_FLIGHT in _pickup_flights.keys():
		flight.cancel()
	_pickup_flights.clear()
	_pickup_canvas = null
	for popup: FLOATING_TEXT in _floating_texts.keys():
		popup.cancel()
	_floating_texts.clear()
	_floating_canvas = null
	_exhaustion_popup = null
	if _potion_flash_tween != null:
		_potion_flash_tween.kill()
		_potion_flash_tween = null
	if _door_prompt != null:
		_door_prompt.hide_prompt()
	if _encounter_prompt != null:
		_encounter_prompt.hide_prompt()
	_cancel_field_target()
	_seen_encounters.clear()
	_encounter_candidates.clear()
	_sight_revision = 0
	_encounter_sight_revision = -1
	_encounter_sight_cache.clear()
	_pending_target_slot = -1
	_pending_world_action.clear()
	_world_turn_pending = false
	_pending_encounter_attack = -1
	_petrified = false
	_petrification_protection_turns = 0
	_money = 0
	_stats_money_label = null
	_stats_petrification_label = null
	_equipped_weapon_id = ""
	_equipped_weapon_texture = null
	_inventory_revision += 1
	_weapon_slot = null
	_weapon_icon = null
	_inventory_panel = null
	_inventory_scroll = null
	_stats_panel = null
	_floor_grid = null
	_floor_entries.clear()
	_floor_signature = ""
	_blast_depth = 0
	_pending_enemy_loot.clear()
	_death_recorded = false
	_previous_remains_sprite = null
	var hero_paths: Array[String] = [HERO_PATH, HERO_GHOST_PATH]
	for variant in HERO_VARIANTS:
		hero_paths.append(variant.path)
	_previous_remains = PREVIOUS_RUN.read_record(_previous_run_path(), _chunk_path_template, hero_paths)
	if _chunk_loader != null:
		_chunk_loader.close()
	_chunk_loader = CHUNK_LOADER.new(_chunk_path_template, CHUNK_SIZE)
	_render_rect = Rect2i()
	_tile_build_queue.clear()
	_tile_build_index = 0
	_clear_held_movement()
	_finish_goblin_animations()
	for actor: Sprite2D in _sinking_actors:
		actor.queue_free()
	_sinking_actors.clear()
	_prone_texture_cache.clear()
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
	_earth_cells.clear()
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
	_ground_extras.clear()
	_cabinets.clear()
	_cabinet_visual_cache.clear()
	_bombs_by_cell.clear()
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
	_encounter_prompt = null
	_field_target = null
	_pending_door_cell = null
	_pending_door_direction = Vector2i.ZERO
	_pending_tool_item_id = ""
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
	_cabinet_empty_texture = _cabinet_visuals(OBJECT_CATALOG.definition("empty_cabinet")).empty
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
	_encounter_prompt = ADVENTURE_PROMPT.new()
	_encounter_prompt.name = "CreatureNotice"
	_encounter_prompt.acknowledged.connect(_on_encounter_acknowledged)
	add_child(_encounter_prompt)
	_field_target = FIELD_TARGET.new()
	_field_target.name = "FieldTarget"
	add_child(_field_target)
	_refresh_combat_labels()
	_build_hero_picker()
	if not get_viewport().size_changed.is_connected(_update_view_layout):
		get_viewport().size_changed.connect(_update_view_layout)
	_update_view_layout()
	_update_editor_coords()
	_check_enemy_encounters()


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
	_spawn_previous_remains(chunk)
	_spawn_chunk_crystals(chunk, objects)


func _previous_run_path() -> String:
	if not _remains_save_path.is_empty():
		return _remains_save_path
	# The exported game writes user data. Custom maps and isolated checks keep
	# their own single record beside the map, without touching the real run.
	if _chunk_path_template.begins_with("res://"):
		return "user://previous_run.json"
	return _chunk_path_template.get_base_dir().path_join("previous_run.json")


func _record_hero_death(kind: String) -> void:
	if _death_recorded:
		return
	var candidates: Array[String] = []
	for item_id in _inventory_item_ids:
		if OBJECT_CATALOG.definition(item_id).get("category", "") == "item":
			candidates.append(item_id)
	if not _equipped_weapon_id.is_empty():
		candidates.append(_equipped_weapon_id)
	var item_id := candidates[_rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else ""
	var record := {"kind": kind, "cell": _hero_cell, "item_id": item_id,
		"hero_path": _hero.texture.resource_path, "flip_h": _hero.flip_h, "destroyed": false}
	_death_recorded = PREVIOUS_RUN.write_record(_previous_run_path(), _chunk_path_template, record)
	if not _death_recorded:
		push_warning("Не удалось сохранить останки предыдущего героя.")


func _spawn_previous_remains(chunk: Vector2i) -> void:
	if _previous_remains.is_empty() or _previous_remains.destroyed or is_instance_valid(_previous_remains_sprite) or _chunk_coord_for_cell(_previous_remains.cell) != chunk or not _terrain_cells.has(_previous_remains.cell):
		return
	var statue: bool = _previous_remains.kind == "statue"
	var type_id := "hero_statue" if statue else "hero_grave"
	var texture := _load_texture(_previous_remains.hero_path if statue else OBJECT_CATALOG.HERO_GRAVE_PATH)
	_previous_remains_sprite = _add_actor(texture, _previous_remains.cell, 1.0, 18)
	_previous_remains_sprite.name = "PreviousHeroStatue" if statue else "PreviousHeroGrave"
	_previous_remains_sprite.set_meta("object_type", type_id)
	_apply_object_flags(_previous_remains_sprite, OBJECT_CATALOG.definition(type_id))
	if statue:
		_previous_remains_sprite.flip_h = _previous_remains.flip_h
		_previous_remains_sprite.offset = GRID.ACTOR_DRAW_OFFSET
		_previous_remains_sprite.add_child(CONTACT_SHADOW.new())
		_previous_remains_sprite.get_node("ContactShadow").visible = _terrain_type(_previous_remains.cell) != TileType.WATER
		var stone := ShaderMaterial.new()
		stone.shader = WATER_SUBMERGE_SHADER
		stone.set_shader_parameter("petrified", true)
		_previous_remains_sprite.material = stone
	_update_enemy_visibility()


func _try_loot_previous_remains(cell: Vector2i, manual := false) -> bool:
	if _game_over or not is_instance_valid(_previous_remains_sprite) or _previous_remains.kind != "grave" or _previous_remains.cell != cell or _previous_remains.item_id.is_empty() or _inventory.size() >= INVENTORY_SIZE:
		return false
	var item_id: String = _previous_remains.item_id
	var definition := OBJECT_CATALOG.definition(item_id)
	if not manual and not definition.get("auto_pickup", true):
		return false
	if not _can_handle_item(item_id, manual):
		return false
	var texture := _load_texture(definition.path)
	if texture == null:
		return false
	var emptied := _previous_remains.duplicate()
	emptied.item_id = ""
	if not PREVIOUS_RUN.write_record(_previous_run_path(), _chunk_path_template, emptied):
		push_warning("Не удалось сохранить подбор предмета из останков героя.")
		return false
	_previous_remains = emptied
	_add_inventory_item(texture, item_id)
	_fly_pickup_to_inventory(texture, _previous_remains_sprite, _inventory.size() - 1)
	_refresh_floor_panel()
	return true


func _is_previous_hero_statue(cell: Vector2i) -> bool:
	return is_instance_valid(_previous_remains_sprite) and _previous_remains.kind == "statue" and _previous_remains.cell == cell and not _previous_remains.destroyed


func _destroy_previous_remains(cell: Vector2i, release_statue_loot := true) -> bool:
	if _game_over or _previous_remains.is_empty() or _previous_remains.cell != cell or _previous_remains.destroyed:
		return false
	var loot := {"cell": cell, "item_id": _previous_remains.item_id if release_statue_loot and _previous_remains.kind == "statue" else ""}
	var destroyed := _previous_remains.duplicate()
	destroyed.destroyed = true
	destroyed.item_id = ""
	if not PREVIOUS_RUN.write_record(_previous_run_path(), _chunk_path_template, destroyed):
		push_warning("Не удалось сохранить разрушение останков героя.")
		return false
	_previous_remains = destroyed
	if is_instance_valid(_previous_remains_sprite):
		_previous_remains_sprite.hide()
		_previous_remains_sprite.queue_free()
	_previous_remains_sprite = null
	# Release only after persisting removal. The existing blast queue keeps
	# trapped loot safe until all cells and chained explosions have finished.
	if _blast_depth > 0:
		_pending_enemy_loot.append(loot)
	else:
		_spawn_enemy_loot(loot)
	_refresh_floor_panel()
	return true


func _spawn_chunk_crystals(chunk: Vector2i, authored: Dictionary) -> void:
	if _crystal_chunks.has(chunk):
		return
	_crystal_chunks[chunk] = true
	for cell in CRYSTAL_SCATTER.candidates(chunk, CHUNK_SIZE, _crystal_seed):
		# Use real terrain passability, including water, without loading neighboring
		# chunks or allowing ghost mode to turn walls into scatter destinations.
		if _blocked_cells.has(cell) or _actor_blocked_cells.has(cell) or _objects_block_cell(cell, "blocks_movement"):
			continue
		if cell == _hero_cell or authored.has(cell) or _items_by_cell.has(cell) or (is_instance_valid(_previous_remains_sprite) and _previous_remains.cell == cell):
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
			_add_cabinet(cell, type_id)
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
	_sight_revision += 1
	for actor_id: int in _goblins.keys():
		if _goblins[actor_id].sprite.has_meta("map_origin") and _goblins[actor_id].sprite.get_meta("map_origin") == origin:
			_remove_goblin(actor_id)
	for cell: Vector2i in _items_by_cell.keys():
		for item: Sprite2D in _ground_items_at(cell):
			if item.has_meta("map_origin") and item.get_meta("map_origin") == origin:
				_remove_ground_item(item)
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
	if definition.has("encounter_text_key") and not _seen_encounters.has(type_id):
		_encounter_candidates[actor_id] = type_id
	_goblins[actor_id].tier = definition.get("tier", "")
	_goblins[actor_id].habitat = definition.get("habitat", "floor")
	_goblins[actor_id].can_swim = bool(definition.get("can_swim", false))
	_goblins[actor_id].requires_water = bool(definition.get("requires_water", false))
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
	_tile_textures.clear()
	_tile_variants.clear()
	for definition: Dictionary in OBJECT_CATALOG.definitions():
		if definition.category != "terrain":
			continue
		_tile_textures[definition.tile] = _load_texture(definition.path)
		if definition.has("variant_paths"):
			var variants: Array[Texture2D] = []
			for path: String in definition.variant_paths:
				variants.append(_load_texture(path))
			_tile_variants[definition.tile] = variants
	for tile_type in [TileType.FLOOR, TileType.WALL]:
		var variants: Array[Texture2D] = [_tile_textures[tile_type]]
		var prefix := "floor" if tile_type == TileType.FLOOR else "wall"
		for index in range(1, TILE_VARIANT_COUNT + 1):
			variants.append(_load_texture(TILE_VARIANT_PATH_TEMPLATE % [prefix, index]))
		_tile_variants[tile_type] = variants
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OBJECT_CATALOG.EARTH_PATH_PREFIX + "manifest.json"))
	for tile_type in [TileType.EARTH, TileType.EARTH_FLOOR]:
		var variants: Array[Texture2D] = []
		for asset: Dictionary in manifest.assets:
			if asset.type == ("wall" if tile_type == TileType.EARTH else "floor"):
				variants.append(_load_texture(OBJECT_CATALOG.EARTH_PATH_PREFIX + asset.file))
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
			if data.get("earth", PackedByteArray()).size() > 0 and data.earth[y * CHUNK_SIZE.x + x] == 1:
				_earth_cells[origin + Vector2i(x, y)] = true
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
		TileType.EARTH:
			return "%"
		TileType.EARTH_FLOOR:
			return ":"
		TileType.BEDROCK:
			return "B"
		_:
			return "."


func _set_terrain_cell(cell: Vector2i, tile_type: TileType) -> void:
	_sight_revision += 1
	_terrain_cells[cell] = tile_type
	_earth_cells.erase(cell)
	if bool(OBJECT_CATALOG.terrain_definition(tile_type).get("blocks_movement", false)):
		_blocked_cells[cell] = true
	else:
		_blocked_cells.erase(cell)
	if tile_type == TileType.WATER:
		_extinguish_bomb(cell)


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
	if _earth_cells.has(cell) and _terrain_cells.get(cell) == TileType.WALL:
		return TileType.EARTH
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
	item.set_meta("auto_pickup", OBJECT_CATALOG.definition(item_id).get("auto_pickup", true))
	_apply_object_flags(item, OBJECT_CATALOG.definition(item_id))
	_attach_ground_item(item, cell)
	return item


func _ground_items_at(cell: Vector2i) -> Array[Sprite2D]:
	var items: Array[Sprite2D] = []
	if _items_by_cell.has(cell) and is_instance_valid(_items_by_cell[cell]):
		items.append(_items_by_cell[cell])
	for item: Sprite2D in _ground_extras.get(cell, []):
		if is_instance_valid(item):
			items.append(item)
	return items


func _attach_ground_item(item: Sprite2D, cell: Vector2i) -> void:
	item.set_meta("ground_cell", cell)
	if not _items_by_cell.has(cell):
		_items_by_cell[cell] = item
	else:
		if not _ground_extras.has(cell):
			_ground_extras[cell] = []
		_ground_extras[cell].append(item)
	_refresh_floor_panel()


func _detach_ground_item(item: Sprite2D) -> void:
	var cell: Vector2i = item.get_meta("ground_cell")
	if _items_by_cell.get(cell) == item:
		_items_by_cell.erase(cell)
		if _ground_extras.has(cell) and not _ground_extras[cell].is_empty():
			_items_by_cell[cell] = _ground_extras[cell].pop_front()
	elif _ground_extras.has(cell):
		_ground_extras[cell].erase(item)
	if _ground_extras.has(cell) and _ground_extras[cell].is_empty():
		_ground_extras.erase(cell)
	_refresh_floor_panel()


func _remove_ground_item(item: Sprite2D) -> void:
	if _push_tweens.has(item):
		_push_tweens[item].tween.kill()
		_push_tweens.erase(item)
	if item.get_meta("blocks_sight", false):
		_sight_revision += 1
	_detach_ground_item(item)
	item.hide()
	item.queue_free()


func _spawn_enemy_loot(loot: Dictionary) -> void:
	if loot.get("item_id", "").is_empty():
		return
	var item_id: String = loot.item_id
	_add_item(_load_texture(OBJECT_CATALOG.definition(item_id).path), loot.cell, ITEM_SCALE, 10, item_id)


func _enemy_loot(enemy: Dictionary) -> Dictionary:
	var type_id := str(enemy.get("type", ""))
	var definition := OBJECT_CATALOG.definition(type_id)
	var item_id := ""
	if definition.has("goblin_type"):
		item_id = {"weak": "gold_small", "medium": "gold_medium", "strong": "gold_large"}.get(definition.tier, "gold_small")
	elif type_id == "cockatrice":
		item_id = "cockatrice_corpse"
	return {"cell": enemy.cell, "item_id": item_id}


func _defeat_enemy(actor_id: int, petrify := false) -> void:
	if not _goblins.has(actor_id):
		return
	var enemy: Dictionary = _goblins[actor_id]
	var loot := _enemy_loot(enemy)
	if petrify:
		var statue := _add_actor(enemy.standing_texture, enemy.cell, 1.0, 18)
		statue.name = "EnemyStatue"
		statue.offset = GRID.ACTOR_DRAW_OFFSET
		statue.flip_h = enemy.sprite.flip_h
		statue.set_meta("object_type", "enemy_statue")
		statue.set_meta("trapped_loot", loot)
		if enemy.sprite.has_meta("map_origin"):
			statue.set_meta("map_origin", enemy.sprite.get_meta("map_origin"))
		_apply_object_flags(statue, OBJECT_CATALOG.definition("enemy_statue"))
		var stone := ShaderMaterial.new()
		stone.shader = WATER_SUBMERGE_SHADER
		stone.set_shader_parameter("petrified", true)
		statue.material = stone
		statue.add_child(CONTACT_SHADOW.new())
		_props_by_cell[enemy.cell] = statue
	else:
		if _blast_depth > 0:
			_pending_enemy_loot.append(loot)
		else:
			_spawn_enemy_loot(loot)
	_remove_goblin(actor_id)
	_update_enemy_visibility()
	_refresh_floor_panel()


func _destroy_enemy_statue(cell: Vector2i) -> void:
	if not _is_enemy_statue(cell):
		return
	var statue: Sprite2D = _props_by_cell[cell]
	var loot: Dictionary = statue.get_meta("trapped_loot", {})
	_props_by_cell.erase(cell)
	statue.hide()
	statue.queue_free()
	if _blast_depth > 0:
		_pending_enemy_loot.append(loot)
	else:
		_spawn_enemy_loot(loot)
	_refresh_floor_panel()


func _is_enemy_statue(cell: Vector2i) -> bool:
	return _props_by_cell.has(cell) and _props_by_cell[cell].get_meta("object_type", "") == "enemy_statue"


func _add_potion_cabinet(cell: Vector2i, empty := false) -> void:
	_add_cabinet(cell, "empty_cabinet" if empty else "potion_cabinet")


func _cabinet_visuals(definition: Dictionary) -> Dictionary:
	var path: String = definition.path
	if not _cabinet_visual_cache.has(path):
		var full := _load_texture(path)
		var areas: Array = definition.get("shelf_areas", CABINET_SHELF_AREAS)
		var interiors := CABINET_VISUAL.empty_shelf_textures(full, areas, definition.get("shelf_background", CABINET_VISUAL.BACKGROUND_PIXEL))
		_cabinet_visual_cache[path] = {"full": full, "interiors": interiors, "areas": areas, "empty": CABINET_VISUAL.empty_preview(full, interiors, areas)}
	return _cabinet_visual_cache[path]


func _add_cabinet(cell: Vector2i, type_id: String) -> void:
	_load_chunk(_chunk_coord_for_cell(cell))
	if not _is_dry_land_type(_terrain_type(cell)):
		return
	var definition := OBJECT_CATALOG.definition(type_id)
	var visuals := _cabinet_visuals(definition)
	var contents: Array[String] = []
	if not definition.get("empty", false):
		var pool := OBJECT_CATALOG.loot_pool(definition.get("loot_group", "potions"))
		if not pool.is_empty():
			for index in range(_rng.randi_range(1, 3)):
				contents.append(pool[_rng.randi_range(0, pool.size() - 1)])
	var sprite := _add_actor(visuals.full, cell, 1.0, 18)
	sprite.name = "Cabinet_%s_%d_%d" % [type_id, cell.x, cell.y]
	_apply_object_flags(sprite, definition)
	var empty_shelves: Array[Sprite2D] = []
	for row in range(visuals.areas.size()):
		# A filled shelf retains the original group of bottles. The native
		# background patch covers only that group's interior when it is empty.
		var patch := Sprite2D.new()
		patch.name = "EmptyShelf_%d" % (row + 1)
		var area := Rect2(visuals.areas[row])
		patch.position = area.get_center() - Vector2.ONE * CELL_SIZE * 0.5
		patch.texture = visuals.interiors[row]
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.add_child(patch)
		empty_shelves.append(patch)
	_cabinets[cell] = {"sprite": sprite, "contents": contents, "empty_shelves": empty_shelves, "type": type_id}
	_update_cabinet_visual(cell)


func _update_cabinet_visual(cell: Vector2i) -> void:
	var cabinet: Dictionary = _cabinets[cell]
	var count: int = cabinet.contents.size()
	# One occupied shelf represents one potion. Original groups of bottles
	# stay unchanged on occupied shelves; looting empties shelves top to bottom.
	for row in range(cabinet.empty_shelves.size()):
		cabinet.empty_shelves[row].visible = row < cabinet.empty_shelves.size() - count
	_apply_object_flags(cabinet.sprite, OBJECT_CATALOG.definition(cabinet.type))


func _try_loot_cabinet(cell: Vector2i, direction: Vector2i) -> void:
	if _game_over or not _cabinets.has(cell) or _hero_cell + direction != cell or absi(direction.x) + absi(direction.y) != 1:
		return
	var cabinet: Dictionary = _cabinets[cell]
	if cabinet.contents.is_empty():
		if _hero_strength <= 0:
			_show_exhaustion_warning()
			return
		_cabinets.erase(cell)
		if cabinet.sprite.get_meta("blocks_sight", false):
			_sight_revision += 1
		cabinet.sprite.hide()
		cabinet.sprite.queue_free()
	else:
		var item_id: String = cabinet.contents[0]
		var definition := OBJECT_CATALOG.definition(item_id)
		var texture := _load_texture(definition.path)
		if not _add_inventory_item(texture, item_id):
			return
		_fly_pickup_to_inventory(texture, cabinet.sprite, _inventory.size() - 1)
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
	if direction == Vector2i.ZERO or _game_over or _player_controls_are_locked():
		return
	if _is_moving:
		_finish_hero_move(false)
	if _game_over or _player_controls_are_locked():
		return

	_finish_goblin_animations()
	var next_cell := _hero_cell + direction
	_load_chunk(_chunk_coord_for_cell(next_cell))
	if _check_enemy_encounters():
		return
	var tool := OBJECT_CATALOG.tool_for_terrain(_terrain_type(next_cell))
	if not tool.is_empty() and tool.get("item_action", "") != "dig" and not _is_ghost_mode:
		if _inventory_item_ids.has(tool.id):
			_pending_door_cell = next_cell
			_pending_door_direction = direction
			_pending_tool_item_id = tool.id
			_clear_held_movement()
			_is_painting = false
			_door_prompt.show_prompt(tr(tool.confirmation_key))
		return
	if _cabinets.has(next_cell) and bool(_cabinets[next_cell].sprite.get_meta("blocks_movement", false)):
		_try_loot_cabinet(next_cell, direction)
		return
	if _goblins_by_cell.has(next_cell):
		if _show_enemy_encounter(str(_goblins[_goblins_by_cell[next_cell]].get("type", ""))):
			return
		if _hero_strength <= 0:
			_show_exhaustion_warning()
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
	if _game_over or _hero == null or _player_controls_are_locked():
		return
	if _is_moving:
		_finish_hero_move(false)
	if _game_over or _player_controls_are_locked():
		return
	_finish_goblin_animations()
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn()


func _door_prompt_is_open() -> bool:
	return _door_prompt != null and _door_prompt.is_open()


func _any_prompt_is_open() -> bool:
	return _door_prompt_is_open() or (_encounter_prompt != null and _encounter_prompt.is_open())


func _field_target_is_active() -> bool:
	return _field_target != null and _field_target.is_active()


func _player_controls_are_locked() -> bool:
	return _any_prompt_is_open() or _field_target_is_active()


func _check_enemy_encounters() -> bool:
	if _encounter_candidates.is_empty() or _encounter_prompt == null or _game_over or _player_controls_are_locked():
		return false
	var nearby: Array[Dictionary] = []
	for actor_id: int in _encounter_candidates.keys():
		if not _goblins.has(actor_id) or _seen_encounters.has(_encounter_candidates[actor_id]):
			_encounter_candidates.erase(actor_id)
			continue
		var enemy: Dictionary = _goblins[actor_id]
		if ACTOR_SIGHT.contains(enemy.cell, _hero_cell):
			nearby.append(enemy)
	if nearby.is_empty():
		return false
	if _encounter_sight_revision != _sight_revision or _encounter_sight_origin != _hero_cell:
		_encounter_sight_cache = _calculate_visible_cells(_hero_cell)
		_encounter_sight_revision = _sight_revision
		_encounter_sight_origin = _hero_cell
	for enemy: Dictionary in nearby:
		if _encounter_sight_cache.has(enemy.cell) and _show_enemy_encounter(str(enemy.get("type", ""))):
			return true
	return false


func _show_enemy_encounter(type_id: String) -> bool:
	var definition := OBJECT_CATALOG.definition(type_id)
	if _encounter_prompt == null or _game_over or _seen_encounters.has(type_id) or not definition.has("encounter_text_key") or _player_controls_are_locked():
		return false
	_seen_encounters[type_id] = true
	for actor_id: int in _encounter_candidates.keys():
		if _encounter_candidates[actor_id] == type_id:
			_encounter_candidates.erase(actor_id)
	_clear_held_movement()
	_is_painting = false
	_encounter_prompt.show_notice(tr(definition.name_key), _load_texture(definition.path), tr(definition.encounter_text_key))
	return true


func _on_encounter_acknowledged() -> void:
	_clear_held_movement()
	if _petrified:
		_build_scene()
		return
	var actor_id := _pending_encounter_attack
	_pending_encounter_attack = -1
	if actor_id >= 0 and _goblins.has(actor_id):
		_animate_goblin(actor_id, _cell_center(_hero_cell), true)
		_resolve_combat(actor_id)
	if _game_over:
		return
	if _world_turn_pending:
		_finish_world_turn()
	elif not _pending_world_action.is_empty():
		var action := _pending_world_action.duplicate()
		_pending_world_action.clear()
		_advance_world_turn(action.boost, action.breathing, action.speed, action.force)
	_check_enemy_encounters()


func _on_door_unlock_decided(confirmed: bool) -> void:
	var cell: Variant = _pending_door_cell
	var direction := _pending_door_direction
	var item_id := _pending_tool_item_id
	_pending_door_cell = null
	_pending_door_direction = Vector2i.ZERO
	_pending_tool_item_id = ""
	_clear_held_movement()
	var definition := OBJECT_CATALOG.definition(item_id)
	if not confirmed or _game_over or cell == null or _hero_cell + direction != cell or absi(direction.x) + absi(direction.y) != 1:
		return
	if definition.get("item_action", "") == "dig" or OBJECT_CATALOG.tool_for_terrain(_terrain_type(cell)).get("id", "") != item_id:
		return
	var slot := _inventory_item_ids.find(item_id)
	if slot < 0:
		return
	_consume_inventory_slot(slot)
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
		"last_seen": null, "active": false, "habitat": "floor", "can_swim": false,
		"requires_water": false, "retaliates_only": false, "knocked_down": false,
		"standing_texture": actor.texture, "label": _add_strength_label(actor)}
	_goblins_by_cell[cell] = actor_id
	_apply_enemy_visibility(_goblins[actor_id])
	return actor_id


func _sync_active_goblins() -> void:
	var hero_chunk := _chunk_coord_for_cell(_hero_cell)
	for actor_id: int in _goblins:
		var goblin: Dictionary = _goblins[actor_id]
		if goblin.retaliates_only and not goblin.knocked_down:
			# Passive creatures only enter the turn queue while they need to stand up.
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
	if _game_over:
		return
	if _encounter_prompt != null and _encounter_prompt.is_open():
		# A committed player action waits for the first-sight warning. Resume
		# exactly once after acknowledgement, before accepting another action.
		if not _world_turn_pending and _is_moving:
			_pending_world_action = {"boost": skip_boost_tick, "breathing": skip_water_breathing_tick, "speed": skip_speed_tick, "force": force_world_turn}
		return
	if _player_controls_are_locked() or _world_turn_pending:
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
	_world_turn_pending = true
	_finish_world_turn()


func _finish_world_turn() -> void:
	while not _game_over:
		var actor_id := _turn_queue.pop_due()
		if actor_id == -1:
			break
		if _goblins.has(actor_id):
			_take_goblin_turn(actor_id)
			if _goblins.has(actor_id) and not _game_over and not _goblins[actor_id].retaliates_only:
				_turn_queue.schedule_after(actor_id, GOBLIN_AI.next_delay(_rng))
		if not _game_over:
			_check_enemy_encounters()
			if _encounter_prompt.is_open():
				return
	_world_turn_pending = false
	if not _game_over:
		_advance_bomb_turn()
	if not _game_over:
		_advance_water_turn()
		if not _effects_started_this_turn.has("strength") and _strength_boost_turns > 0:
			_strength_boost_turns -= 1
		if not _effects_started_this_turn.has("water_breathing") and _water_breathing_turns > 0:
			_water_breathing_turns -= 1
		if not _effects_started_this_turn.has("speed") and _speed_boost_turns > 0:
			_speed_boost_turns -= 1
		if not _effects_started_this_turn.has("petrification_protection") and _petrification_protection_turns > 0:
			_petrification_protection_turns -= 1
			if _petrification_protection_turns == 0 and OBJECT_CATALOG.definition(_equipped_weapon_id).get("dangerous_to_handle", false):
				_petrify_hero()
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
	if goblin.knocked_down:
		_stand_up_enemy(actor_id)
		return
	if goblin.retaliates_only:
		return
	var cell: Vector2i = goblin.cell
	var plan := GOBLIN_AI.plan(cell, _hero_cell, goblin.last_seen,
		_enemy_can_step.bind(str(goblin.habitat), bool(goblin.can_swim)), _actor_can_see, _rng)
	goblin.last_seen = plan.last_seen
	if plan.attack:
		if _show_enemy_encounter(str(goblin.get("type", ""))):
			_pending_encounter_attack = actor_id
			return
		_animate_goblin(actor_id, _cell_center(_hero_cell), true)
		_resolve_combat(actor_id)
	elif plan.target != cell and plan.target != _hero_cell:
		if goblin.sprite.get_meta("blocks_sight", false):
			_sight_revision += 1
		_actor_blocked_cells.erase(cell)
		_goblins_by_cell.erase(cell)
		goblin.cell = plan.target
		_actor_blocked_cells[plan.target] = true
		_goblins_by_cell[plan.target] = actor_id
		_animate_goblin(actor_id, _cell_center(plan.target))


func _goblin_can_step(cell: Vector2i) -> bool:
	return _enemy_can_step(cell, "floor")


func _enemy_can_step(cell: Vector2i, habitat: String, can_swim := false) -> bool:
	var allowed_terrain := TileType.WATER if habitat == "water" else TileType.FLOOR
	var terrain := _terrain_type(cell)
	var allowed := (terrain == allowed_terrain if habitat == "water" else _is_dry_land_type(terrain)) or (habitat != "water" and can_swim and terrain == TileType.WATER)
	return _terrain_cells.has(cell) and allowed and not _objects_block_cell(cell, "blocks_movement") and (
		cell == _hero_cell or not _actor_blocked_cells.has(cell))


func _actor_can_see(origin: Vector2i, target: Vector2i) -> bool:
	return _calculate_visible_cells(origin).has(target)


func _animate_goblin(actor_id: int, target: Vector2, attack := false) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	_apply_enemy_visibility(goblin)
	var sprite: Sprite2D = goblin.sprite
	if _push_tweens.has(sprite):
		_push_tweens[sprite].tween.kill()
		_push_tweens.erase(sprite)
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
	for sprite in _push_tweens:
		var move: Dictionary = _push_tweens[sprite]
		move.tween.kill()
		if is_instance_valid(sprite):
			sprite.position = _cell_center(move.cell)
	_push_tweens.clear()
	for tween: Tween in _goblin_tweens.values():
		tween.kill()
	_goblin_tweens.clear()
	for goblin: Dictionary in _goblins.values():
		var sprite: Sprite2D = goblin.sprite
		sprite.position = _cell_center(goblin.cell)
		if not goblin.knocked_down:
			_restore_enemy_pose(goblin)


func _resolve_combat(actor_id: int) -> void:
	if _game_over or not _goblins.has(actor_id):
		return
	var goblin: Dictionary = _goblins[actor_id]
	var strength_before := _hero_strength
	var enemy_strength_before: int = goblin.strength
	var weapon_bonus := _weapon_strength_bonus()
	var total := COMBAT.effective_strength(_hero_strength, weapon_bonus, _strength_multiplier()) + maxi(int(goblin.strength), 0)
	var roll := _rng.randi_range(0, total - 1) if total > 0 else 0
	var result := COMBAT.exchange(_hero_strength, int(goblin.strength), weapon_bonus, roll, _strength_multiplier())
	if goblin.knocked_down and not result.player_hit:
		# A missed attack keeps the usual hit chance, but a prone defender cannot counterattack.
		result.player = strength_before
		result.damage = 0
	_hero_strength = result.player
	goblin.strength = result.enemy
	if goblin.retaliates_only and _hero_strength < strength_before:
		_animate_goblin(actor_id, _cell_center(_hero_cell), true)
	if result.player_hit and result.damage > 0 and OBJECT_CATALOG.definition(_equipped_weapon_id).get("weapon_petrifies_on_hit", false):
		_defeat_enemy(actor_id, true)
	elif result.killed:
		_defeat_enemy(actor_id)
		# Learning strength belongs only to a finishing ordinary combat hit.
		# Generic deaths (bombs, immersion and future hazards) only release loot.
		if result.player_hit and result.damage > 0 and enemy_strength_before > 0:
			_gain_hero_strength(MELEE_KILL_STRENGTH_GAIN)
	elif not result.player_hit and result.damage > 0 and OBJECT_CATALOG.definition(str(goblin.get("type", ""))).get("petrifies_on_hit", false):
		_petrify_hero()
	_check_hero_death()
	_refresh_combat_labels()


func _petrify_hero() -> void:
	if _petrification_protection_turns > 0 or _game_over:
		return
	_petrified = true
	_game_over = true
	_cancel_field_target()
	_world_turn_pending = false
	_pending_world_action.clear()
	_clear_held_movement()
	if _hero_move_tween != null:
		_hero_move_tween.kill()
		_hero_move_tween = null
	_is_moving = false
	_hero.position = _cell_center(_hero_cell)
	if _camera != null:
		_camera.position = _hero.position
	_finish_goblin_animations()
	_hero_water_material.set_shader_parameter("petrified", true)
	_record_hero_death("statue")
	_encounter_prompt.show_notice(tr("DEATH_PETRIFICATION_TITLE"), _hero.texture, tr("DEATH_PETRIFICATION_TEXT"), tr("UI_NEW_RUN"), _hero_water_material)


func _check_hero_death() -> void:
	if not _game_over and _hero_strength < COMBAT.DEATH_THRESHOLD:
		_game_over = true
		_cancel_field_target()
		_clear_held_movement()
		_record_hero_death("grave")
		# Combat and drowning share the same deferred restart.
		_restart_after_death.call_deferred()


func _restart_after_death() -> void:
	if _game_over and not _petrified:
		_build_scene()


func _gain_hero_strength(amount: int) -> void:
	_hero_strength += amount
	_hero_max_strength += amount
	if amount > 0:
		_show_floating_text(tr("POPUP_STRENGTH_GAIN") % amount, Color(0.65, 1.0, 0.55))


func _show_exhaustion_warning() -> void:
	# Held movement retries blocked attacks every frame. Keep one warning alive
	# without restarting its fade or covering the field in repeated text.
	if is_instance_valid(_exhaustion_popup) and not _exhaustion_popup.is_queued_for_deletion():
		return
	_exhaustion_popup = _show_floating_text(tr("POPUP_EXHAUSTED"), Color(1.0, 0.45, 0.35))


func _show_floating_text(message: String, color: Color) -> FLOATING_TEXT:
	if not is_instance_valid(_hero) or _game_over:
		return null
	if _floating_texts.size() >= MAX_FLOATING_TEXTS:
		var oldest: FLOATING_TEXT = _floating_texts.keys()[0]
		for candidate: FLOATING_TEXT in _floating_texts:
			if candidate.text == message:
				oldest = candidate
				break
		oldest.cancel()
	if not is_instance_valid(_floating_canvas):
		_floating_canvas = CanvasLayer.new()
		_floating_canvas.name = "FloatingTextCanvas"
		_floating_canvas.layer = 26
		add_child(_floating_canvas)
	var occupied: Dictionary = {}
	for existing: FLOATING_TEXT in _floating_texts:
		for row in range(existing.lane, existing.lane + existing.lane_count):
			occupied[row] = true
	var popup := FLOATING_TEXT.new()
	popup.name = "FloatingText"
	_floating_canvas.add_child(popup)
	_floating_texts[popup] = true
	popup.finished.connect(func():
		_floating_texts.erase(popup)
		if _exhaustion_popup == popup:
			_exhaustion_popup = null
	)
	# Only the initial screen position comes from the field. Camera changes,
	# movement interruption and later messages never reposition existing text.
	popup.begin(_hero.get_global_transform_with_canvas().origin, message, color, FLOATING_TEXT.BOTTOM_OFFSET)
	var lane := 0
	while true:
		var available := true
		for row in range(lane, lane + popup.lane_count):
			if occupied.has(row):
				available = false
				break
		if available:
			break
		lane += 1
	popup.lane = lane
	popup.set_bottom_offset(FLOATING_TEXT.BOTTOM_OFFSET - lane * FLOATING_TEXT.LANE_HEIGHT)
	return popup


func _weapon_strength_bonus() -> int:
	return int(OBJECT_CATALOG.definition(_equipped_weapon_id).get("weapon_bonus", 0))


func _remove_goblin(actor_id: int) -> void:
	var goblin: Dictionary = _goblins[actor_id]
	var sprite: Sprite2D = goblin.sprite
	_encounter_candidates.erase(actor_id)
	if sprite.get_meta("blocks_sight", false):
		_sight_revision += 1
	if _push_tweens.has(sprite):
		_push_tweens[sprite].tween.kill()
		_push_tweens.erase(sprite)
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


func _knock_down_enemy(actor_id: int) -> void:
	var enemy: Dictionary = _goblins[actor_id]
	enemy.knocked_down = true
	var sprite: Sprite2D = enemy.sprite
	var path: String = OBJECT_CATALOG.definition(str(enemy.get("type", ""))).get("prone_path", "")
	if not path.is_empty():
		sprite.texture = _load_texture(path)
	else:
		# Types without a supplied pose use an exact quarter-turn of their native
		# image, cached once. The root, label and shadow never rotate or resize.
		var standing: Texture2D = enemy.standing_texture
		if not _prone_texture_cache.has(standing):
			var image: Image = standing.get_image().duplicate()
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			image.rotate_90(CLOCKWISE)
			_prone_texture_cache[standing] = ImageTexture.create_from_image(image)
		sprite.texture = _prone_texture_cache[standing]
	sprite.set_meta("prone", true)


func _stand_up_enemy(actor_id: int) -> void:
	var enemy: Dictionary = _goblins[actor_id]
	enemy.knocked_down = false
	# If this turn is the immediate response to the scroll, keep the fallen
	# picture through its travel animation, then finish the spent stand-up turn.
	if not _push_tweens.has(enemy.sprite):
		_restore_enemy_pose(enemy)
	if enemy.retaliates_only:
		enemy.active = false
		_turn_queue.cancel(actor_id)


func _restore_enemy_pose(enemy: Dictionary) -> void:
	var sprite: Sprite2D = enemy.sprite
	if sprite.get_meta("prone", false):
		sprite.texture = enemy.standing_texture
		sprite.set_meta("prone", false)


func _enemy_terrain_is_lethal(enemy: Dictionary, cell: Vector2i) -> bool:
	var terrain := _terrain_type(cell)
	return (terrain == TileType.WATER and not enemy.can_swim) or (_is_dry_land_type(terrain) and enemy.requires_water)


func _is_dry_land_type(terrain: int) -> bool:
	return terrain in [TileType.FLOOR, TileType.EARTH_FLOOR]


func _sink_enemy(actor_id: int) -> void:
	var enemy: Dictionary = _goblins[actor_id]
	var effect := ACTOR_SINK.new()
	effect.name = "SinkingEnemy"
	add_child(effect)
	_sinking_actors[effect] = enemy.cell
	effect.finished.connect(func(): _sinking_actors.erase(effect))
	effect.begin(enemy.sprite, _cell_center(enemy.cell), HERO_MOVE_DURATION)
	# Death is immediate: release collision and cancel AI before the next world turn.
	_defeat_enemy(actor_id)
	_apply_sinking_actor_visibility(effect)


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
		_stats_breath_label.text = tr("STAT_BREATH") % _hero_breath
		_stats_breath_label.visible = in_water
	if _stats_water_breathing_label != null:
		_stats_water_breathing_label.text = tr("STAT_WATER_BREATHING") % _water_breathing_turns
		_stats_water_breathing_label.visible = _water_breathing_turns > 0
	_update_hero_water_visual()
	if _hero_strength_label != null:
		_hero_strength_label.text = tr("STAT_PETRIFIED") if _petrified else str(_hero_strength * _strength_multiplier() + weapon_bonus)
		_hero_strength_label.modulate = strength_color
	if _stats_strength_label != null:
		_stats_strength_label.text = tr("STAT_STRENGTH") % [_hero_strength, _hero_max_strength]
		if _strength_boost_turns > 0:
			_stats_strength_label.text += "×2"
		if weapon_bonus > 0:
			_stats_strength_label.text += "+%d" % weapon_bonus
		_stats_strength_label.modulate = strength_color
	if _stats_magic_label != null:
		_stats_magic_label.text = tr("STAT_MAGIC") % _hero_magic
	if _stats_money_label != null:
		_stats_money_label.text = tr("STAT_MONEY") % _money
	if _stats_petrification_label != null:
		_stats_petrification_label.text = tr("STAT_PETRIFICATION_PROTECTION") % _petrification_protection_turns
		_stats_petrification_label.visible = _petrification_protection_turns > 0
	if _stats_boost_label != null:
		_stats_boost_label.text = tr("STAT_STRENGTH_BOOST") % _strength_boost_turns if _strength_boost_turns > 0 else ""
		_stats_boost_label.visible = _strength_boost_turns > 0
	if _stats_speed_label != null:
		_stats_speed_label.text = tr("STAT_SPEED") % _speed_boost_turns
		_stats_speed_label.visible = _speed_boost_turns > 0
	for goblin: Dictionary in _goblins.values():
		goblin.label.text = str(goblin.strength)
	_update_enemy_visibility()


func _update_enemy_visibility() -> void:
	for goblin: Dictionary in _goblins.values():
		_apply_enemy_visibility(goblin)
	for cell: Vector2i in _bombs_by_cell:
		_apply_bomb_visibility(cell)
	for actor: Sprite2D in _sinking_actors:
		_apply_sinking_actor_visibility(actor)
	_update_previous_remains_visibility()
	for cell: Vector2i in _props_by_cell:
		if _is_enemy_statue(cell):
			_apply_statue_visibility(cell)


func _update_visibility_at_cell(cell: Vector2i) -> void:
	# A completed fog tween affects only the contents of its own cell.
	if _goblins_by_cell.has(cell):
		_apply_enemy_visibility(_goblins[_goblins_by_cell[cell]])
	if _bombs_by_cell.has(cell):
		_apply_bomb_visibility(cell)
	for actor: Sprite2D in _sinking_actors:
		if _sinking_actors[actor] == cell:
			_apply_sinking_actor_visibility(actor)
	if is_instance_valid(_previous_remains_sprite) and _previous_remains.cell == cell:
		_update_previous_remains_visibility()
	if _is_enemy_statue(cell):
		_apply_statue_visibility(cell)


func _apply_statue_visibility(cell: Vector2i) -> void:
	var fog := _fog_cells.get(cell) as ColorRect
	var alpha := 1.0 - fog.self_modulate.a if fog != null else (1.0 if _is_ghost_mode else 0.0)
	_props_by_cell[cell].modulate.a = alpha
	_props_by_cell[cell].visible = alpha > 0.0


func _apply_bomb_visibility(cell: Vector2i) -> void:
	var fog := _fog_cells.get(cell) as ColorRect
	var alpha := 1.0 - fog.self_modulate.a if fog != null else (1.0 if _is_ghost_mode else 0.0)
	_bombs_by_cell[cell].sprite.modulate.a = alpha
	_bombs_by_cell[cell].sprite.visible = alpha > 0.0


func _apply_sinking_actor_visibility(actor: Sprite2D) -> void:
	var cell: Vector2i = _sinking_actors[actor]
	var fog := _fog_cells.get(cell) as ColorRect
	var alpha := 1.0 - fog.self_modulate.a if fog != null else (1.0 if _is_ghost_mode else 0.0)
	actor.modulate.a = alpha
	actor.visible = alpha > 0.0


func _update_previous_remains_visibility() -> void:
	if is_instance_valid(_previous_remains_sprite):
		var cell: Vector2i = _previous_remains.cell
		var fog := _fog_cells.get(cell) as ColorRect
		var alpha := 1.0 - fog.self_modulate.a if fog != null else (1.0 if _is_ghost_mode else 0.0)
		if not _is_ghost_mode and not _is_terrain_walkable(cell):
			alpha = 0.0
		_previous_remains_sprite.modulate.a = alpha
		_previous_remains_sprite.visible = alpha > 0.0


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
		if bool(enemy.get_meta("prone", false)):
			continue
		if is_equal_approx(enemy.position.x, hero_position.x):
			continue
		var face_left := hero_position.x < enemy.position.x
		enemy.flip_h = face_left != _actor_base_flip.get(enemy, false)


func _try_pickup_item(cell: Vector2i) -> void:
	if _game_over:
		return
	_try_loot_previous_remains(cell)
	for item: Sprite2D in _ground_items_at(cell):
		if item.get_meta("auto_pickup", true):
			_collect_ground_item(item)
	_refresh_floor_panel()


func _collect_ground_item(item: Sprite2D, manual := false) -> bool:
	if _game_over or not is_instance_valid(item) or not _ground_items_at(_hero_cell).has(item):
		return false
	var item_id := str(item.get_meta("item_id", ""))
	var definition := OBJECT_CATALOG.definition(item_id)
	if not _can_handle_item(item_id, manual):
		return false
	if definition.has("money_range"):
		# Quantity is rolled once, only when the pile actually leaves the floor.
		var limits: Vector2i = definition.money_range
		_money += _rng.randi_range(limits.x, limits.y)
		_play_pickup_flight(item.texture, item, _stats_money_label)
	elif definition.has("strength_gain"):
		_gain_hero_strength(int(definition.strength_gain))
		_play_pickup_flight(item.texture, item, _stats_strength_label)
	elif not _add_inventory_item(item.texture, item_id):
		return false
	else:
		_fly_pickup_to_inventory(item.texture, item, _inventory.size() - 1)
	_remove_ground_item(item)
	_refresh_inventory_panel()
	return true


func _can_handle_item(item_id: String, show_first_warning := false) -> bool:
	var definition := OBJECT_CATALOG.definition(item_id)
	if not definition.get("dangerous_to_handle", false):
		return true
	if show_first_warning and not _seen_encounters.has("cockatrice_corpse"):
		_seen_encounters["cockatrice_corpse"] = true
		_clear_held_movement()
		_encounter_prompt.show_notice(tr(definition.name_key), _load_texture(definition.path), tr(definition.get("description_key", "ITEM_DANGEROUS")))
		return false
	if _petrification_protection_turns <= 0:
		_petrify_hero()
		return false
	return true


func _manual_pickup_floor(entry: Dictionary) -> void:
	if entry.get("cell") != _hero_cell or not _prepare_inventory_action():
		return
	var collected: bool
	if entry.get("remains", false):
		collected = _try_loot_previous_remains(_hero_cell, true)
	else:
		collected = _collect_ground_item(entry.get("sprite") as Sprite2D, true)
	if collected:
		_finish_item_operation()


func _prepare_inventory_action() -> bool:
	return (_hero_picker == null or not _hero_picker.is_open()) and _prepare_potion_action()


func _finish_item_operation() -> void:
	_clear_held_movement()
	_refresh_inventory_panel()
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn()


func _remove_inventory_item(slot: int) -> void:
	_inventory.remove_at(slot)
	_inventory_item_ids.remove_at(slot)
	_inventory_revision += 1


func _drop_inventory_item(slot: int) -> void:
	if slot < 0 or slot >= _inventory.size() or not _prepare_inventory_action():
		return
	var item_id := _inventory_item_ids[slot]
	if not _can_handle_item(item_id):
		return
	var texture := _inventory[slot]
	_remove_inventory_item(slot)
	_drop_on_floor(item_id, texture)
	_finish_item_operation()


func _drop_equipped_weapon() -> void:
	if _equipped_weapon_id.is_empty() or not _prepare_inventory_action() or not _can_handle_item(_equipped_weapon_id):
		return
	_drop_on_floor(_equipped_weapon_id, _equipped_weapon_texture)
	_equipped_weapon_id = ""
	_equipped_weapon_texture = null
	_inventory_revision += 1
	_finish_item_operation()


func _drop_on_floor(item_id: String, texture: Texture2D) -> void:
	var item := _add_item(texture, _hero_cell, ITEM_SCALE, 10, item_id)
	item.set_meta("auto_pickup", false)
	if item_id == ITEM_ID_GHOST_RING:
		_set_ghost_mode(false)
	_refresh_floor_panel()


func _equip_inventory_item(slot: int) -> void:
	if slot < 0 or slot >= _inventory.size() or not _prepare_inventory_action():
		return
	var item_id := _inventory_item_ids[slot]
	var definition := OBJECT_CATALOG.definition(item_id)
	if not definition.has("weapon_bonus") and not definition.has("potion_effect"):
		return
	if not _can_handle_item(item_id) or not _can_handle_item(_equipped_weapon_id):
		return
	var texture := _inventory[slot]
	_remove_inventory_item(slot)
	if not _equipped_weapon_id.is_empty():
		_add_inventory_item(_equipped_weapon_texture, _equipped_weapon_id)
	if definition.has("potion_effect"):
		item_id = "broken_bottle"
		texture = _load_texture(OBJECT_CATALOG.definition(item_id).path)
	_equipped_weapon_id = item_id
	_equipped_weapon_texture = texture
	_finish_item_operation()


func _unequip_weapon() -> void:
	if _equipped_weapon_id.is_empty() or _inventory.size() >= INVENTORY_SIZE or not _prepare_inventory_action() or not _can_handle_item(_equipped_weapon_id):
		return
	_add_inventory_item(_equipped_weapon_texture, _equipped_weapon_id)
	_equipped_weapon_id = ""
	_equipped_weapon_texture = null
	_inventory_revision += 1
	_finish_item_operation()


func _inventory_drag_payload(slot: int) -> Variant:
	if _game_over or _player_controls_are_locked() or (_hero_picker != null and _hero_picker.is_open()) or slot >= _inventory.size():
		return null
	return {"source": "inventory", "slot": slot, "item_id": _inventory_item_ids[slot], "revision": _inventory_revision}


func _weapon_drag_payload() -> Variant:
	if _game_over or _player_controls_are_locked() or (_hero_picker != null and _hero_picker.is_open()) or _equipped_weapon_id.is_empty():
		return null
	return {"source": "weapon", "item_id": _equipped_weapon_id, "revision": _inventory_revision}


func _valid_item_payload(payload: Variant) -> bool:
	if not payload is Dictionary or payload.get("revision", -1) != _inventory_revision or _game_over or _player_controls_are_locked():
		return false
	if payload.get("source") == "weapon":
		return payload.get("item_id") == _equipped_weapon_id and not _equipped_weapon_id.is_empty()
	var slot: int = payload.get("slot", -1)
	return payload.get("source") == "inventory" and slot >= 0 and slot < _inventory.size() and _inventory_item_ids[slot] == payload.get("item_id")


func _can_equip_payload(payload: Variant) -> bool:
	if not _valid_item_payload(payload) or payload.source != "inventory":
		return false
	var definition := OBJECT_CATALOG.definition(payload.item_id)
	return definition.has("weapon_bonus") or definition.has("potion_effect")


func _receive_weapon_payload(payload: Variant) -> void:
	if _can_equip_payload(payload):
		_equip_inventory_item(payload.slot)


func _can_unequip_payload(payload: Variant) -> bool:
	return _valid_item_payload(payload) and payload.source == "weapon" and _inventory.size() < INVENTORY_SIZE


func _receive_inventory_payload(payload: Variant) -> void:
	if _can_unequip_payload(payload):
		_unequip_weapon()

func _add_inventory_item(texture: Texture2D, item_id: String) -> bool:
	if texture == null or _inventory.size() >= INVENTORY_SIZE:
		return false

	_inventory.append(texture)
	_inventory_item_ids.append(item_id)
	_inventory_revision += 1
	_refresh_inventory_panel()
	return true


func _fly_pickup_to_inventory(texture: Texture2D, source: Sprite2D, slot: int) -> void:
	if slot >= 0 and slot < _inventory_slot_icons.size():
		_play_pickup_flight(texture, source, _inventory_slot_icons[slot], _inventory_scroll)


func _play_pickup_flight(texture: Texture2D, source: Sprite2D, target: Control, clip: Control = null) -> PICKUP_FLIGHT:
	if _game_over or texture == null or not is_instance_valid(source) or not is_instance_valid(target):
		return null
	# Snapshot the rendered source before removal or the camera's next movement.
	# Both the world transform and HUD controls use viewport canvas coordinates.
	var transform := source.get_global_transform_with_canvas()
	var start_position := transform * source.offset
	var start_scale := transform.get_scale().abs()
	if not is_instance_valid(_pickup_canvas):
		_pickup_canvas = CanvasLayer.new()
		_pickup_canvas.name = "PickupCanvas"
		_pickup_canvas.layer = 25
		add_child(_pickup_canvas)
	if _pickup_flights.size() >= MAX_PICKUP_FLIGHTS:
		var oldest: PICKUP_FLIGHT = _pickup_flights.keys()[0]
		oldest.cancel()
	var flight := PICKUP_FLIGHT.new()
	flight.name = "PickupFlight"
	_pickup_canvas.add_child(flight)
	_pickup_flights[flight] = true
	flight.finished.connect(func(): _pickup_flights.erase(flight))
	flight.begin(texture, start_position, start_scale, target, clip)
	return flight


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
	var canvas := CanvasLayer.new()
	canvas.name = "InventoryCanvas"
	canvas.layer = 20
	add_child(canvas)
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.052, 0.047, 0.92), 2, Color(0.18, 0.16, 0.13, 0.95)))
	canvas.add_child(_inventory_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_inventory_panel.add_child(column)
	var weapon_title := Label.new()
	weapon_title.text = tr("UI_WEAPON")
	column.add_child(weapon_title)
	var weapon_row := HBoxContainer.new()
	column.add_child(weapon_row)
	_weapon_slot = _new_item_slot(weapon_row)
	_weapon_slot.name = "WeaponSlot"
	_weapon_icon = _weapon_slot.icon
	_weapon_slot.payload_provider = _weapon_drag_payload
	_weapon_slot.accepts_payload = _can_equip_payload
	_weapon_slot.receives_payload = _receive_weapon_payload
	_weapon_slot.clicked.connect(func(button: int):
		if button == MOUSE_BUTTON_RIGHT:
			_drop_equipped_weapon()
		else:
			_unequip_weapon()
	)
	var hint := Label.new()
	hint.name = "WeaponControls"
	hint.text = tr("UI_WEAPON_CONTROLS")
	hint.add_theme_font_size_override("font_size", 14)
	weapon_row.add_child(hint)
	var inventory_title := Label.new()
	inventory_title.text = tr("UI_INVENTORY")
	column.add_child(inventory_title)
	var inventory_controls := Label.new()
	inventory_controls.name = "InventoryControls"
	inventory_controls.text = tr("UI_INVENTORY_CONTROLS")
	inventory_controls.add_theme_font_size_override("font_size", 14)
	inventory_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(inventory_controls)
	_inventory_scroll = ScrollContainer.new()
	_inventory_scroll.name = "InventoryScroll"
	_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_inventory_scroll)
	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = INVENTORY_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_inventory_scroll.add_child(grid)
	for index in range(INVENTORY_SIZE):
		var slot := _new_item_slot(grid)
		slot.payload_provider = _inventory_drag_payload.bind(index)
		slot.accepts_payload = _can_unequip_payload
		slot.receives_payload = _receive_inventory_payload
		slot.clicked.connect(_on_inventory_slot_clicked.bind(index))
		_inventory_slot_icons.append(slot.icon)
	var floor_title := Label.new()
	floor_title.text = tr("UI_FLOOR")
	column.add_child(floor_title)
	var floor_controls := Label.new()
	floor_controls.name = "FloorControls"
	floor_controls.text = tr("UI_FLOOR_CONTROLS")
	floor_controls.add_theme_font_size_override("font_size", 14)
	floor_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(floor_controls)
	var floor_scroll := ScrollContainer.new()
	floor_scroll.name = "FloorScroll"
	floor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	floor_scroll.custom_minimum_size.y = _inventory_slot_size() + 10.0
	column.add_child(floor_scroll)
	_floor_grid = GridContainer.new()
	_floor_grid.columns = INVENTORY_COLUMNS
	_floor_grid.add_theme_constant_override("h_separation", 8)
	_floor_grid.add_theme_constant_override("v_separation", 8)
	floor_scroll.add_child(_floor_grid)
	_refresh_inventory_panel()


func _new_item_slot(parent: Control) -> INVENTORY_SLOT:
	var slot := INVENTORY_SLOT.new()
	var slot_size := _inventory_slot_size()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _slot_style())
	parent.add_child(slot)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2.ONE * _inventory_icon_size()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	slot.icon = icon
	return slot


func _update_item_panel_layout() -> void:
	if not is_instance_valid(_inventory_panel):
		return
	var top := UI_PANEL_MARGIN
	if is_instance_valid(_stats_panel):
		top = _stats_panel.position.y + _stats_panel.size.y + 12.0
	var width := _inventory_slot_size() * INVENTORY_COLUMNS + 8.0 * (INVENTORY_COLUMNS - 1) + 34.0
	_inventory_panel.position = Vector2(UI_PANEL_MARGIN, top)
	_inventory_panel.size = Vector2(width, maxf(320.0, get_viewport_rect().size.y - top - UI_PANEL_MARGIN))


func _refresh_floor_panel() -> void:
	if not is_instance_valid(_floor_grid):
		return
	var entries: Array[Dictionary] = []
	var signature := "%s:magic:%d:locale:%s" % [_hero_cell, _hero_magic, TranslationServer.get_locale()]
	for item: Sprite2D in _ground_items_at(_hero_cell):
		var item_id := str(item.get_meta("item_id", ""))
		entries.append({"sprite": item, "cell": _hero_cell, "item_id": item_id, "texture": item.texture})
		signature += ":%d" % item.get_instance_id()
	if is_instance_valid(_previous_remains_sprite) and _previous_remains.kind == "grave" and _previous_remains.cell == _hero_cell and not _previous_remains.item_id.is_empty():
		var item_id: String = _previous_remains.item_id
		entries.append({"remains": true, "cell": _hero_cell, "item_id": item_id, "texture": _load_texture(OBJECT_CATALOG.definition(item_id).path)})
		signature += ":remains:" + item_id
	if signature == _floor_signature:
		return
	_floor_signature = signature
	_floor_entries = entries
	for child in _floor_grid.get_children():
		_floor_grid.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_FLOOR_EMPTY")
		empty.modulate = Color(0.6, 0.6, 0.6)
		_floor_grid.add_child(empty)
	for entry: Dictionary in entries:
		var slot := _new_item_slot(_floor_grid)
		slot.icon.texture = entry.texture
		slot.tooltip_text = _item_tooltip(entry.item_id)
		slot.clicked.connect(func(button: int):
			if button == MOUSE_BUTTON_LEFT:
				_manual_pickup_floor(entry)
		)


func _on_inventory_slot_clicked(button: int, slot: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_drop_inventory_item(slot)
	else:
		_activate_inventory_slot(slot)

func _build_stats_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "StatsCanvas"
	canvas.layer = 20
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	_stats_panel = panel
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
	_stats_breath_label.tooltip_text = tr("STAT_BREATH_DESCRIPTION")
	column.add_child(_stats_breath_label)
	_stats_strength_label = Label.new()
	_stats_strength_label.name = "HeroStrength"
	_stats_strength_label.custom_minimum_size.y = STATS_ROW_HEIGHT
	_stats_strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats_strength_label.add_theme_font_size_override("font_size", 18)
	_stats_strength_label.tooltip_text = tr("STAT_STRENGTH_DESCRIPTION")
	column.add_child(_stats_strength_label)
	_stats_magic_label = Label.new()
	_stats_magic_label.name = "HeroMagic"
	_stats_magic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats_magic_label.add_theme_font_size_override("font_size", 18)
	_stats_magic_label.tooltip_text = tr("STAT_MAGIC_DESCRIPTION")
	column.add_child(_stats_magic_label)
	_stats_money_label = Label.new()
	_stats_money_label.name = "HeroMoney"
	_stats_money_label.add_theme_font_size_override("font_size", 18)
	_stats_money_label.modulate = Color(1.0, 0.85, 0.35)
	column.add_child(_stats_money_label)
	_stats_petrification_label = Label.new()
	_stats_petrification_label.name = "PetrificationProtection"
	_stats_petrification_label.add_theme_font_size_override("font_size", 15)
	_stats_petrification_label.modulate = Color(0.85, 0.65, 1.0)
	column.add_child(_stats_petrification_label)
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


func _item_tooltip(item_id: String) -> String:
	var definition := OBJECT_CATALOG.definition(item_id)
	var lines: Array[String] = [tr(definition.get("name_key", item_id))]
	var description_key: String = definition.get("description_key", "")
	var description := tr(description_key) if not description_key.is_empty() else ""
	if not description.is_empty():
		lines.append(description.format({
			"magic": _hero_magic,
			"healing_amount": _hero_magic * HEALTH_POTION_MAGIC_FACTOR,
			"long_duration": _hero_magic * WATER_BREATHING_MAGIC_FACTOR,
			"push_distance": PUSH_DISTANCE,
			"bomb_fuse": BOMB_FUSE_TURNS,
			"bomb_damage": BOMB_DAMAGE,
		}))
	if int(definition.get("weapon_bonus", 0)) > 0:
		lines.append(tr("ITEM_WEAPON_BONUS") % definition.weapon_bonus)
	if definition.has("strength_gain"):
		lines.append(tr("ITEM_STRENGTH_GAIN") % definition.strength_gain)
	if definition.has("money_range"):
		var limits: Vector2i = definition.money_range
		lines.append(tr("ITEM_MONEY_RANGE") % [limits.x, limits.y])
	if definition.has("potion_effect") or definition.get("loot_group", "") == "scrolls":
		lines.append(tr("ITEM_MAGIC_GAIN"))
	if definition.has("potion_effect"):
		var bonus: int = OBJECT_CATALOG.definition("broken_bottle").weapon_bonus
		lines.append(tr("ITEM_POTION_WEAPON") % bonus)
	return "\n".join(lines)


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
			slot.tooltip_text = _item_tooltip(_inventory_item_ids[i])
	if is_instance_valid(_weapon_icon):
		_weapon_icon.texture = _equipped_weapon_texture
		_weapon_slot.tooltip_text = tr("UI_WEAPON_EMPTY") if _equipped_weapon_id.is_empty() else _item_tooltip(_equipped_weapon_id)
	_refresh_floor_panel()
	_refresh_combat_labels()
	_update_item_panel_layout()


func _on_inventory_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	# Kept for input adapters; actual slots handle release so dragging a potion cannot drink it.
	if event is InputEventMouseButton and not event.pressed:
		_on_inventory_slot_clicked(event.button_index, slot_index)

func _activate_inventory_slot(slot_index: int) -> void:
	if _game_over or _player_controls_are_locked() or (_hero_picker != null and _hero_picker.is_open()) or slot_index < 0 or slot_index >= _inventory_item_ids.size():
		return
	var item_id := _inventory_item_ids[slot_index]
	if item_id == ITEM_ID_GHOST_RING:
		_set_ghost_mode(not _is_ghost_mode)
		return
	var definition := OBJECT_CATALOG.definition(item_id)
	if definition.get("item_action", "") == "plant_bomb":
		_plant_bomb(slot_index)
		return
	if definition.get("item_action", "") in ["push", "dig"]:
		_begin_field_target(slot_index)
		return
	match definition.get("potion_effect", ""):
		"heal":
			_drink_health_potion(slot_index)
		"strength":
			_drink_strength_potion(slot_index)
		"water_breathing":
			_drink_water_breathing_potion(slot_index)
		"speed":
			_drink_speed_potion(slot_index)
		"petrification_protection":
			if _prepare_potion_action():
				_petrification_protection_turns = _hero_magic * WATER_BREATHING_MAGIC_FACTOR
				_effects_started_this_turn["petrification_protection"] = true
				_finish_potion_action(slot_index)


func _drink_health_potion(slot_index: int) -> void:
	if _hero_strength >= _hero_max_strength:
		return
	if not _prepare_potion_action():
		return
	_hero_strength = mini(_hero_max_strength, _hero_strength + _hero_magic * HEALTH_POTION_MAGIC_FACTOR)
	_finish_potion_action(slot_index)


func _drink_strength_potion(slot_index: int) -> void:
	if not _prepare_potion_action():
		return
	_strength_boost_turns = _hero_magic
	_finish_potion_action(slot_index, true)


func _drink_water_breathing_potion(slot_index: int) -> void:
	if not _prepare_potion_action():
		return
	_water_breathing_turns = _hero_magic * WATER_BREATHING_MAGIC_FACTOR
	_finish_potion_action(slot_index, false, true)


func _drink_speed_potion(slot_index: int) -> void:
	if not _prepare_potion_action():
		return
	var starts_speed := _speed_boost_turns == 0
	_speed_boost_turns = _hero_magic
	# Initial drinking costs one ordinary world turn; subsequent renewal uses
	# the current two-action cadence rather than granting another free action.
	_finish_potion_action(slot_index, false, false, true, starts_speed)


func _strength_multiplier() -> int:
	return 2 if _strength_boost_turns > 0 else 1


func _prepare_potion_action() -> bool:
	if _game_over or _player_controls_are_locked():
		return false
	if _is_moving:
		_finish_hero_move(false)
	if _game_over or _player_controls_are_locked():
		return false
	_finish_goblin_animations()
	return true


func _finish_potion_action(slot_index: int, starts_boost := false, starts_water_breathing := false, starts_speed := false, force_world_turn := false) -> void:
	_flash_potion(str(OBJECT_CATALOG.definition(_inventory_item_ids[slot_index]).get("potion_effect", "")))
	_consume_inventory_slot(slot_index)
	_refresh_inventory_panel()
	_try_pickup_item(_hero_cell)
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn(starts_boost, starts_water_breathing, starts_speed, force_world_turn)


func _flash_potion(effect: String) -> void:
	var colors := {"heal": Color("ff0044"), "strength": Color("63c74d"), "water_breathing": Color("0099db"), "speed": Color("ffcd75"), "petrification_protection": Color("c285c4")}
	if not colors.has(effect):
		return
	if _potion_flash_tween != null:
		_potion_flash_tween.kill()
	_hero_water_material.set_shader_parameter("potion_flash_color", colors[effect])
	_hero_water_material.set_shader_parameter("potion_flash_strength", 0.8)
	var material := _hero_water_material
	_potion_flash_tween = create_tween()
	_potion_flash_tween.tween_method(func(amount: float): material.set_shader_parameter("potion_flash_strength", amount), 0.8, 0.0, 0.24)


func _consume_inventory_slot(slot_index: int) -> void:
	var definition := OBJECT_CATALOG.definition(_inventory_item_ids[slot_index])
	# Only a successful use reaches consumption. Potions and every scroll share
	# one reward, including items that belong to both groups.
	if definition.has("potion_effect") or definition.get("loot_group", "") == "scrolls":
		_hero_magic += 1
		_show_floating_text(tr("POPUP_MAGIC_GAIN"), Color(0.85, 0.65, 1.0))
	_inventory.remove_at(slot_index)
	_inventory_item_ids.remove_at(slot_index)
	_inventory_revision += 1


func _begin_field_target(slot_index: int) -> void:
	if not _prepare_potion_action():
		return
	if slot_index < 0 or slot_index >= _inventory_item_ids.size():
		return
	var definition := OBJECT_CATALOG.definition(_inventory_item_ids[slot_index])
	var action: String = definition.get("item_action", "")
	if action not in ["push", "dig"]:
		return
	_pending_target_slot = slot_index
	_pending_target_item_id = _inventory_item_ids[slot_index]
	_pending_target_revision = _inventory_revision
	_clear_held_movement()
	_is_painting = false
	_field_target.begin_target(_cell_center(_hero_cell), tr("TARGET_PICKAXE") if action == "dig" else tr("TARGET_PUSH"), tr("TARGET_PICKAXE_BLOCKED") if action == "dig" else tr("TARGET_PUSH_BLOCKED"))

func _handle_field_target_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_cancel_field_target()
	elif event.physical_keycode == KEY_SPACE:
		_confirm_field_target()
	else:
		var direction := _movement_direction_for_key(event.physical_keycode)
		if direction != Vector2i.ZERO:
			_field_target.select_direction(direction)


func _cancel_field_target() -> void:
	_pending_target_slot = -1
	_pending_target_item_id = ""
	_pending_target_revision = -1
	_clear_held_movement()
	if _field_target != null:
		_field_target.end_target()


func _confirm_field_target() -> void:
	if not _field_target_is_active():
		return
	var direction := _field_target.direction
	if direction == Vector2i.ZERO:
		return
	var slot := _pending_target_slot
	if _game_over or _any_prompt_is_open() or slot < 0 or slot >= _inventory_item_ids.size() or _inventory_revision != _pending_target_revision or _inventory_item_ids[slot] != _pending_target_item_id:
		_cancel_field_target()
		return
	var definition := OBJECT_CATALOG.definition(_pending_target_item_id)
	var action: String = definition.get("item_action", "")
	# The scene is settled before targeting. Choosing or correcting a target
	# never changes the field or advances the world.
	var applied := false
	match action:
		"push":
			applied = _push_adjacent(direction)
		"dig":
			applied = _dig_adjacent(direction, definition)
	if not applied:
		_field_target.mark_blocked()
		return
	_cancel_field_target()
	_consume_inventory_slot(slot)
	_start_hero_action(direction if action == "dig" else Vector2i.ZERO)
	_update_fog()
	_advance_world_turn()
	_refresh_inventory_panel()


func _dig_adjacent(direction: Vector2i, definition: Dictionary) -> bool:
	if absi(direction.x) + absi(direction.y) != 1:
		return false
	var cell := _hero_cell + direction
	_load_chunk(_chunk_coord_for_cell(cell))
	if _is_previous_hero_statue(cell):
		if not _destroy_previous_remains(cell):
			return false
	elif _is_enemy_statue(cell):
		_destroy_enemy_statue(cell)
	elif _terrain_cells.has(cell) and definition.get("target_terrains", []).has(_terrain_type(cell)):
		_set_terrain_cell(cell, TileType.EARTH_FLOOR if _terrain_type(cell) == TileType.EARTH else TileType.FLOOR)
	else:
		return false
	_refresh_tile_and_neighbors(cell)
	return true

func _push_adjacent(direction: Vector2i) -> bool:
	if absi(direction.x) + absi(direction.y) != 1:
		return false
	var targets: Array[Dictionary] = []
	var cell := _hero_cell + direction
	_load_chunk(_chunk_coord_for_cell(cell))
	if not _terrain_cells.has(cell) or not _is_terrain_walkable(cell) or _is_previous_hero_statue(cell) or (_props_by_cell.has(cell) and _props_by_cell[cell].get_meta("blocks_movement", false)):
		return false
	if _cabinets.has(cell):
		targets.append({"kind": "cabinet", "cell": cell})
	if _goblins_by_cell.has(cell):
		targets.append({"kind": "enemy", "cell": cell, "id": _goblins_by_cell[cell]})
	if _bombs_by_cell.has(cell):
		targets.append({"kind": "bomb", "cell": cell})
	for item: Sprite2D in _ground_items_at(cell):
		targets.append({"kind": "item", "cell": cell, "sprite": item})
	var moved := false
	# Only the adjacent cell is affected. A creature farther along the path
	# stops a pushed bomb/item; contact-petrifying items hit its occupied cell.
	for index in range(targets.size() - 1, -1, -1):
		var target := targets[index]
		var destination := _push_destination(target, direction)
		if destination == target.cell:
			continue
		if _pushed_item_petrifies(target) and _goblins_by_cell.has(destination):
			_defeat_enemy(_goblins_by_cell[destination], true)
		moved = true
		var sprite: Sprite2D
		match target.kind:
			"cabinet":
				# Preserve the container, loot and shelf children as one object.
				var cabinet: Dictionary = _cabinets[target.cell]
				_cabinets.erase(target.cell)
				_cabinets[destination] = cabinet
				sprite = cabinet.sprite
			"enemy":
				var enemy: Dictionary = _goblins[target.id]
				_goblins_by_cell.erase(target.cell)
				_actor_blocked_cells.erase(target.cell)
				enemy.cell = destination
				_goblins_by_cell[destination] = target.id
				_actor_blocked_cells[destination] = true
				sprite = enemy.sprite
				if _enemy_terrain_is_lethal(enemy, destination):
					_sink_enemy(target.id)
					continue
				_knock_down_enemy(target.id)
			"bomb":
				var bomb: Dictionary = _bombs_by_cell[target.cell]
				_bombs_by_cell.erase(target.cell)
				_bombs_by_cell[destination] = bomb
				sprite = bomb.sprite
				_extinguish_bomb(destination)
			"item":
				sprite = target.sprite
				_detach_ground_item(sprite)
				_attach_ground_item(sprite, destination)
		var tween := sprite.create_tween()
		if sprite.get_meta("blocks_sight", false):
			_sight_revision += 1
		_push_tweens[sprite] = {"tween": tween, "cell": destination}
		tween.tween_property(sprite, "position", _cell_center(destination), HERO_MOVE_DURATION)
		var actor_id: int = target.get("id", -1)
		tween.finished.connect(func():
			if _push_tweens.has(sprite) and _push_tweens[sprite].tween == tween:
				_push_tweens.erase(sprite)
				if _goblins.has(actor_id) and not _goblins[actor_id].knocked_down:
					_restore_enemy_pose(_goblins[actor_id])
		)
	_update_enemy_visibility()
	return moved


func _push_destination(target: Dictionary, direction: Vector2i) -> Vector2i:
	var destination: Vector2i = target.cell
	var petrifies := _pushed_item_petrifies(target)
	for step in range(PUSH_DISTANCE):
		var next_cell := destination + direction
		_load_chunk(_chunk_coord_for_cell(next_cell))
		if not _terrain_cells.has(next_cell) or not _is_terrain_walkable(next_cell) or next_cell == _hero_cell:
			break
		if petrifies and _goblins_by_cell.has(next_cell) and not _objects_block_cell(next_cell, "blocks_movement", false):
			# Contact succeeds even when the victim is immediately beside the
			# corpse. Stop at the first creature within the normal flight range.
			return next_cell
		if _objects_block_cell(next_cell, "blocks_movement") or _goblins_by_cell.has(next_cell):
			break
		if target.kind == "bomb" and _bombs_by_cell.has(next_cell):
			break
		elif target.kind == "item" and _items_by_cell.has(next_cell):
			break
		elif target.kind == "cabinet" and (_cabinets.has(next_cell) or _props_by_cell.has(next_cell) or _items_by_cell.has(next_cell) or _bombs_by_cell.has(next_cell)):
			# Furniture stops before occupied cells; it never covers or replaces loot.
			break
		destination = next_cell
		# A pushed creature flies over intermediate terrain. Habitat is checked
		# only after its final landing cell has been resolved in _push_adjacent.
	return destination


func _pushed_item_petrifies(target: Dictionary) -> bool:
	return target.kind == "item" and OBJECT_CATALOG.definition(str(target.sprite.get_meta("item_id", ""))).get("petrifies_on_collision", false)


func _plant_bomb(slot_index: int) -> void:
	if _game_over or _player_controls_are_locked() or _bombs_by_cell.has(_hero_cell):
		return
	if slot_index < 0 or slot_index >= _inventory_item_ids.size() or _inventory_item_ids[slot_index] != ITEM_ID_BOMB:
		return
	if not _prepare_potion_action():
		return
	var sprite := _add_actor(_load_texture(OBJECT_CATALOG.BOMB_PATH), _hero_cell, ITEM_SCALE, 15)
	sprite.name = "ArmedBomb"
	var label := Label.new()
	label.name = "Fuse"
	label.position = Vector2(-CELL_SIZE * 0.5, 8.0)
	label.size = Vector2(CELL_SIZE, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_as_relative = false
	label.z_index = STRENGTH_LABEL_Z_INDEX
	label.modulate = Color(1.0, 0.76, 0.3)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.text = str(BOMB_FUSE_TURNS)
	sprite.add_child(label)
	# Like potion duration, the placement's world turn does not shorten a new fuse.
	_bombs_by_cell[_hero_cell] = {"sprite": sprite, "label": label, "turns": BOMB_FUSE_TURNS, "first_tick_turn": _turn_queue.current_turn + 1}
	_extinguish_bomb(_hero_cell)
	_consume_inventory_slot(slot_index)
	_start_hero_action(Vector2i.ZERO)
	_advance_world_turn()
	_update_enemy_visibility()
	_refresh_inventory_panel()


func _advance_bomb_turn() -> void:
	var due: Array[Vector2i] = []
	for cell: Vector2i in _bombs_by_cell.keys():
		if _extinguish_bomb(cell):
			continue
		var bomb: Dictionary = _bombs_by_cell[cell]
		if _turn_queue.current_turn <= bomb.first_tick_turn:
			continue
		bomb.turns -= 1
		bomb.label.text = str(bomb.turns)
		if bomb.turns <= 0:
			due.append(cell)
	for cell in due:
		_explode_bomb(cell)
	if not due.is_empty():
		_check_hero_death()
		_refresh_combat_labels()
		_update_fog()


func _extinguish_bomb(cell: Vector2i) -> bool:
	if not _bombs_by_cell.has(cell) or _terrain_type(cell) != TileType.WATER:
		return false
	var bomb: Dictionary = _bombs_by_cell[cell]
	var sprite: Sprite2D = bomb.sprite
	_bombs_by_cell.erase(cell)
	var label := bomb.get("label") as Label
	if is_instance_valid(label):
		sprite.remove_child(label)
		label.queue_free()
	# Preserve the picture and any flight tween; only the armed state ends.
	sprite.name = "ExtinguishedBomb"
	sprite.z_index = 10
	sprite.modulate = Color.WHITE
	sprite.show()
	sprite.set_meta("item_id", ITEM_ID_BOMB)
	sprite.set_meta("auto_pickup", false)
	_apply_object_flags(sprite, OBJECT_CATALOG.definition(ITEM_ID_BOMB))
	_attach_ground_item(sprite, cell)
	return true


func _remove_armed_bomb(cell: Vector2i) -> void:
	if not _bombs_by_cell.has(cell):
		return
	var sprite: Sprite2D = _bombs_by_cell[cell].sprite
	_bombs_by_cell.erase(cell)
	sprite.hide()
	sprite.queue_free()


func _explode_bomb(origin: Vector2i) -> void:
	if not _bombs_by_cell.has(origin) or _extinguish_bomb(origin):
		return
	_sight_revision += 1
	_blast_depth += 1
	_remove_armed_bomb(origin)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := origin + Vector2i(x, y)
			_load_chunk(_chunk_coord_for_cell(cell))
			_extinguish_bomb(cell)
			_destroy_previous_remains(cell)
			if cell == _hero_cell:
				_hero_strength -= BOMB_DAMAGE
			if _goblins_by_cell.has(cell):
				var actor_id: int = _goblins_by_cell[cell]
				var enemy: Dictionary = _goblins[actor_id]
				enemy.strength -= BOMB_DAMAGE
				if enemy.strength <= 0:
					_defeat_enemy(actor_id)
			if _cabinets.has(cell):
				var cabinet: Dictionary = _cabinets[cell]
				_cabinets.erase(cell)
				cabinet.sprite.hide()
				cabinet.sprite.queue_free()
			for item: Sprite2D in _ground_items_at(cell):
				_remove_ground_item(item)
			if _is_enemy_statue(cell):
				_destroy_enemy_statue(cell)
			elif _props_by_cell.has(cell):
				var sprite: Sprite2D = _props_by_cell[cell]
				_props_by_cell.erase(cell)
				sprite.hide()
				sprite.queue_free()
			var blast_result: int = OBJECT_CATALOG.terrain_definition(_terrain_type(cell)).get("blast_result", -1)
			if blast_result >= 0:
				_set_terrain_cell(cell, blast_result)
				_refresh_tile_and_neighbors(cell)
			if _is_ghost_mode or _visible_cells.has(cell):
				var flash := ColorRect.new()
				flash.position = Vector2(cell) * CELL_SIZE + Vector2(2.0, 2.0)
				flash.size = Vector2.ONE * (CELL_SIZE - 4.0)
				flash.color = Color(1.0, 0.65, 0.2, 0.55)
				flash.z_index = 25
				flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(flash)
				var tween := flash.create_tween()
				tween.tween_property(flash, "modulate:a", 0.0, 0.2)
				tween.finished.connect(flash.queue_free)
			# A blast ignites adjacent armed bombs; removal before recursion prevents loops.
			if _bombs_by_cell.has(cell):
				_explode_bomb(cell)
	_blast_depth -= 1
	if _blast_depth == 0:
		for loot: Dictionary in _pending_enemy_loot:
			_spawn_enemy_loot(loot)
		_pending_enemy_loot.clear()


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
		_editor_status_label.text = tr("EDITOR_GHOST_MODE") % (tr("EDITOR_GHOST_ON") if _is_ghost_mode else tr("EDITOR_GHOST_OFF"))
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
	save_button.text = tr("EDITOR_SAVE")
	save_button.pressed.connect(_save_loaded_chunks)
	row.add_child(save_button)
	_editor_status_label = Label.new()
	_editor_status_label.text = tr("EDITOR_SELECTED").format({"object": tr("OBJECT_NAME_FLOOR")})
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
		button.icon = _cabinet_visuals(definition).empty if definition.category == "cabinet" and definition.get("empty", false) else _load_texture(definition.path)
		button.expand_icon = true
		button.tooltip_text = tr(definition.name_key)
		button.set_meta("object_type", definition.id)
		button.pressed.connect(_select_editor_object.bind(definition.id))
		_editor_palette.add_child(button)
	var erase_button := Button.new()
	erase_button.text = tr("EDITOR_ERASE")
	erase_button.custom_minimum_size = Vector2(66.0, 66.0)
	erase_button.tooltip_text = tr("EDITOR_ERASE_DESCRIPTION")
	erase_button.pressed.connect(_select_editor_object.bind("erase"))
	_editor_palette.add_child(erase_button)


func _select_editor_object(type_id: String) -> void:
	_selected_object_id = type_id
	var definition := OBJECT_CATALOG.definition(type_id)
	if definition.get("category") == "terrain":
		_selected_tile_type = definition.tile
	if _editor_status_label != null:
		_editor_status_label.text = tr("EDITOR_SELECTED").format({"object": tr(definition.get("name_key", "EDITOR_ERASE_OBJECT"))})


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
	if _game_over or _player_controls_are_locked() or _editor_canvas == null or not _editor_canvas.visible:
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
		for item: Sprite2D in _ground_items_at(cell):
			if not OBJECT_CATALOG.can_place_on(item.get_meta("item_id", ""), _selected_tile_type) and item.has_meta("map_origin"):
				_set_editor_map_object(item.get_meta("map_origin"), "")
		if _cabinets.has(cell):
			var cabinet: Dictionary = _cabinets[cell]
			if not OBJECT_CATALOG.can_place_on(cabinet.type, _selected_tile_type) and cabinet.sprite.has_meta("map_origin"):
				_set_editor_map_object(cabinet.sprite.get_meta("map_origin"), "")
		var authored_type: String = _authored_map_objects().get(cell, "")
		if not authored_type.is_empty() and not OBJECT_CATALOG.can_place_on(authored_type, _selected_tile_type):
			_set_editor_map_object(cell, "")
	else:
		if _selected_object_id != "erase" and (not OBJECT_CATALOG.can_place_on(_selected_object_id, _terrain_type(cell)) or (cell == _hero_cell and _selected_object_id != "hero_start")):
			_editor_status_label.text = tr("EDITOR_NEED_WATER") if definition.get("habitat") == "water" else tr("EDITOR_NEED_FLOOR")
			return
		if _selected_object_id == "erase":
			_destroy_previous_remains(cell, false)
		# A moving enemy retains its authored origin; explicitly erasing it removes that spawn.
		if _goblins_by_cell.has(cell):
			var actor: Sprite2D = _goblins[_goblins_by_cell[cell]].sprite
			var origin: Vector2i = actor.get_meta("map_origin", cell)
			_set_editor_map_object(origin, "")
		for item: Sprite2D in _ground_items_at(cell):
			if item.has_meta("map_origin"):
				_set_editor_map_object(item.get_meta("map_origin"), "")
			else:
				_remove_ground_item(item)
		if _props_by_cell.has(cell) and _props_by_cell[cell].has_meta("map_origin"):
			_set_editor_map_object(_props_by_cell[cell].get_meta("map_origin"), "")
		if _is_enemy_statue(cell):
			# Editor erasure removes the runtime obstacle without generating loot.
			var statue: Sprite2D = _props_by_cell[cell]
			_props_by_cell.erase(cell)
			statue.queue_free()
		if _cabinets.has(cell) and _cabinets[cell].sprite.has_meta("map_origin"):
			_set_editor_map_object(_cabinets[cell].sprite.get_meta("map_origin"), "")
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
	_editor_status_label.text = tr("EDITOR_CHANGED") % [tr(definition.get("name_key", "EDITOR_ERASING")), str(cell)]


func _set_editor_map_object(cell: Vector2i, type_id: String) -> void:
	if OBJECT_CATALOG.definition(type_id).get("procedural", false):
		return
	_remove_procedural_item(cell)
	_remove_armed_bomb(cell)
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
	for item: Sprite2D in _ground_items_at(cell):
		if OBJECT_CATALOG.definition(item.get_meta("item_id", "")).get("procedural", false):
			_remove_ground_item(item)

func _update_editor_coords() -> void:
	if _hero_coords_label == null:
		return
	_hero_coords_label.text = tr("EDITOR_COORDS") % [
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
			_editor_status_label.text = tr("EDITOR_NO_CHANGES")
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
		_editor_status_label.text = tr("EDITOR_SAVED") % [saved_count, edited_chunks.size(), tr("EDITOR_OK") if objects_saved else tr("EDITOR_ERROR")]


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
	if bool(sprite.get_meta("blocks_sight", false)) != bool(definition.get("blocks_sight", false)):
		_sight_revision += 1
	sprite.set_meta("blocks_sight", bool(definition.get("blocks_sight", false)))


func _objects_block_cell(cell: Vector2i, flag: String, include_enemies := true) -> bool:
	if is_instance_valid(_previous_remains_sprite) and _previous_remains.cell == cell and bool(_previous_remains_sprite.get_meta(flag, false)):
		return true
	if _cabinets.has(cell) and bool(_cabinets[cell].sprite.get_meta(flag, false)):
		return true
	if _props_by_cell.has(cell) and bool(_props_by_cell[cell].get_meta(flag, false)):
		return true
	for item: Sprite2D in _ground_items_at(cell):
		if bool(item.get_meta(flag, false)):
			return true
	if include_enemies and _goblins_by_cell.has(cell):
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
		_check_enemy_encounters()
		return

	var next_visible_cells := _calculate_visible_cells(_hero_cell)
	_encounter_sight_cache = next_visible_cells.duplicate()
	_encounter_sight_origin = _hero_cell
	_encounter_sight_revision = _sight_revision
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
	_check_enemy_encounters()


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
		_update_visibility_at_cell(cell)
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
