extends SceneTree

const GRID := preload("res://scripts/grid_config.gd")
const DEMO_SCRIPT := preload("res://scripts/asset_demo_scene.gd")
const DEMO_SCENE := preload("res://scenes/asset_demo.tscn")

var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_resources()
	_check_diagonal_sight()
	var scene: Node2D = DEMO_SCENE.instantiate()
	root.add_child(scene)
	await process_frame

	for cell in [Vector2i.ZERO, Vector2i(8, 5), Vector2i(-1, -1), Vector2i(-64, 64)]:
		var center: Vector2 = scene.call("_cell_center", cell)
		_check(center == (Vector2(cell) + Vector2(0.5, 0.5)) * GRID.TILE_SIZE, "Cell center: %s" % cell)
		_check(scene.call("_cell_from_world", center) == cell, "Cell round trip: %s" % cell)
	_check(scene.call("_cell_from_world", Vector2(-0.1, -0.1)) == Vector2i(-1, -1), "Negative cell boundary")
	_check(scene.call("_cell_from_world", Vector2(64.0, 64.0)) == Vector2i(1, 1), "Positive cell boundary")
	_check(scene.call("_chunk_coord_for_cell", Vector2i(-1, -1)) == Vector2i(-1, -1), "Negative chunk boundary")

	var enemies: Array = scene.get("_enemies")
	var expected_enemies := 0
	var authored: Dictionary = scene.call("_authored_map_objects")
	for cell: Vector2i in authored:
		if DEMO_SCRIPT.OBJECT_CATALOG.definition(authored[cell]).category == "enemy" and scene.get("_loaded_chunks").has(scene.call("_chunk_coord_for_cell", cell)) and DEMO_SCRIPT.OBJECT_CATALOG.can_place_on(authored[cell], scene.call("_terrain_type", cell)):
			expected_enemies += 1
	_check(enemies.size() == expected_enemies and scene.get("_actor_blocked_cells").size() == enemies.size(), "Only live level goblins are instantiated and block cells")
	for enemy: Sprite2D in enemies:
		_check(enemy.scale == Vector2.ONE and enemy.offset == GRID.ACTOR_DRAW_OFFSET, "Native monster scale and raised drawing: %s" % enemy.name)
		_check(enemy.texture.get_size() == Vector2.ONE * GRID.TILE_SIZE, "Monster texture: %s" % enemy.name)
	var hero: Sprite2D = scene.get("_hero")
	_check(hero.scale == Vector2.ONE and hero.offset == GRID.ACTOR_DRAW_OFFSET, "Native hero scale and raised drawing")
	var slots: Array = scene.get("_inventory_slot_icons")
	_check(slots[0].custom_minimum_size == Vector2.ONE * GRID.TILE_SIZE, "Inventory icon size")
	_check_view_layout(scene)
	var original_window_size := root.size
	for window_size in [Vector2i(1280, 720), Vector2i(800, 1200)]:
		root.size = window_size
		await process_frame
		_check_view_layout(scene)
	root.size = original_window_size
	await process_frame

	_check_hero_choices(scene, hero)
	# Movement fixtures test controls and pickups independently of live encounters.
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	await _check_movement(scene, hero)
	await _check_responsive_movement(scene, hero)
	await _check_held_movement(scene, hero)
	_check_ghost_mode(scene, hero)
	await _check_fog_fades(scene)
	await _check_fog_edges(scene)
	await _check_legacy_scene()
	scene.free()

	if _errors.is_empty():
		print("GRID CHECK OK: 64px resources, 16 hero choices, responsive and held movement, camera, collision, ghost mode, diagonal sight, fog fades, edge sliding and view")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_resources() -> void:
	var paths: Array[String] = []
	for goblin_type in DEMO_SCRIPT.GOBLIN_TYPES.TYPES:
		paths.append(goblin_type.path)
	paths.append(DEMO_SCRIPT.BOSS_PATH)
	for variant in DEMO_SCRIPT.HERO_VARIANTS:
		paths.append(str(variant["path"]))
	for folder in ["res://assets/actors", "res://assets/items", "res://assets/tiles/dungeon"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".png") and file != "atlas.png":
				paths.append(folder.path_join(file))
	for path in paths:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and image.get_size() == Vector2i.ONE * GRID.TILE_SIZE, "64px PNG: %s" % path)
		var texture := load(path) as Texture2D
		_check(texture != null and texture.get_size() == Vector2.ONE * GRID.TILE_SIZE, "64px imported texture: %s" % path)
		if image != null and (path.contains("/pixel_monsters/") or path.contains("/goblins/") or path.contains("/heroes/") or path == DEMO_SCRIPT.HERO_PATH):
			var silhouette := image.get_used_rect()
			_check(silhouette.end.y == GRID.PIXEL_BASELINE, "Sprite baseline: %s" % path)
			_check(maxi(silhouette.size.x, silhouette.size.y) == GRID.TILE_SIZE, "Silhouette fills the cell: %s" % path)
	var tileset := load("res://assets/tiles/dungeon/tileset.tres") as TileSet
	_check(tileset.tile_size == Vector2i.ONE * GRID.TILE_SIZE, "TileSet tile size")
	var source := tileset.get_source(0) as TileSetAtlasSource
	_check(source.texture_region_size == tileset.tile_size, "Atlas region size")
	_check(source.texture.get_size() == Vector2(272, 68), "Atlas dimensions include 2px extrusion")
	for x in range(4):
		_check(source.has_tile(Vector2i(x, 0)), "Atlas tile %d" % x)


func _check_diagonal_sight() -> void:
	var diagonals: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	# Orthogonal blockers must not prevent sight along an open diagonal.
	for blocking_type in [DEMO_SCRIPT.TileType.WALL, DEMO_SCRIPT.TileType.DOOR]:
		var fixture := DEMO_SCRIPT.new()
		fixture.call("_set_terrain_cell", Vector2i.ZERO, DEMO_SCRIPT.TileType.FLOOR)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			fixture.call("_set_terrain_cell", direction, blocking_type)
		for direction in diagonals:
			fixture.call("_set_terrain_cell", direction, DEMO_SCRIPT.TileType.WATER)
			fixture.call("_set_terrain_cell", direction * 2, blocking_type)
			fixture.call("_set_terrain_cell", direction * 3, DEMO_SCRIPT.TileType.FLOOR)
		var visible: Dictionary = fixture.call("_calculate_visible_cells", Vector2i.ZERO)
		_check(visible.has(Vector2i.ZERO), "Hero's own cell stays visible")
		for direction in diagonals:
			_check(visible.has(direction), "Open diagonal reveals water: %s" % direction)
			_check(visible.has(direction * 2), "Diagonal reveals the blocking wall or door: %s" % direction)
			_check(not visible.has(direction * 3), "Wall or door stops diagonal sight: %s" % direction)
		fixture.free()

	var fixture := DEMO_SCRIPT.new()
	var origin := Vector2i(-1, -1)
	for direction in diagonals:
		for distance in range(DEMO_SCRIPT.HERO_SIGHT_RADIUS + 2):
			fixture.call("_set_terrain_cell", origin + direction * distance, DEMO_SCRIPT.TileType.FLOOR)
	var visible: Dictionary = fixture.call("_calculate_visible_cells", origin)
	for direction in diagonals:
		_check(visible.has(origin + direction * DEMO_SCRIPT.HERO_SIGHT_RADIUS), "Diagonal reaches the same sight radius across chunk boundaries: %s" % direction)
		_check(not visible.has(origin + direction * (DEMO_SCRIPT.HERO_SIGHT_RADIUS + 1)), "Diagonal respects the sight radius: %s" % direction)
	fixture.free()


func _check_view_layout(scene: Node2D) -> void:
	var viewport_size := scene.get_viewport_rect().size
	var side := minf(viewport_size.x, viewport_size.y)
	var bounds: Rect2 = scene.call("_view_screen_rect", viewport_size)
	_check(bounds.size == Vector2.ONE * side, "View fills the viewport's shorter side")
	_check(bounds.get_center().is_equal_approx(viewport_size * 0.5), "View remains centered")
	var masks: Array = scene.get("_view_mask_rects")
	_check(is_equal_approx(masks[2].size.y, side), "Mask uses the complete viewport height")
	_check(is_equal_approx(masks[2].size.x, bounds.position.x), "Mask follows resized view bounds")
	var camera: Camera2D = scene.get("_camera")
	var world_size := bounds.size / camera.zoom
	_check(world_size.is_equal_approx(Vector2.ONE * DEMO_SCRIPT.VIEW_CELL_COUNT * GRID.TILE_SIZE), "Camera keeps eleven 64px cells visible")
	var world_rect := scene.get_viewport().get_canvas_transform().affine_inverse() * bounds
	_check(world_rect.size.is_equal_approx(world_size), "Canvas transform matches the camera zoom")
	for size in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(800, 1200), Vector2(640, 480)]:
		var expected_side := minf(size.x, size.y)
		var expected_size := Vector2.ONE * expected_side
		_check(scene.call("_view_screen_rect", size) == Rect2((size - expected_size) * 0.5, expected_size), "View bounds for %s" % size)


func _check_hero_choices(scene: Node2D, hero: Sprite2D) -> void:
	var picker: CanvasLayer = scene.get("_hero_picker")
	var buttons: Array = picker.get("_buttons")
	_check(buttons.size() == 16, "Sixteen hero selection buttons")
	var start_position := hero.position
	var start_cell: Vector2i = scene.get("_hero_cell")
	var was_flipped := hero.flip_h
	for index in range(DEMO_SCRIPT.HERO_VARIANTS.size()):
		scene.call("_select_hero", index)
		_check(hero.texture.resource_path == DEMO_SCRIPT.HERO_VARIANTS[index]["path"], "Hero choice %d uses its sheet sprite" % index)
		_check(hero.position == start_position and scene.get("_hero_cell") == start_cell, "Hero choice preserves the cell")
		_check(hero.flip_h == was_flipped, "Hero choice preserves facing")
	var previous_texture := hero.texture
	scene.call("_select_hero", -1)
	scene.call("_select_hero", DEMO_SCRIPT.HERO_VARIANTS.size())
	_check(hero.texture == previous_texture, "Invalid hero choice is ignored")

	scene.set("_is_painting", true)
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_H
	shortcut.pressed = true
	scene.call("_unhandled_key_input", shortcut)
	_check(picker.call("is_open"), "Hero picker opens")
	_check(not scene.get("_is_painting"), "Picker stops painting")
	var panel: PanelContainer = picker.get("_panel")
	_check(panel.get_rect().get_center().is_equal_approx(scene.get_viewport_rect().size * 0.5), "Hero picker remains centered")
	var movement := InputEventKey.new()
	movement.physical_keycode = KEY_D
	movement.pressed = true
	scene.call("_unhandled_key_input", movement)
	_check(scene.get("_hero_cell") == start_cell, "World movement is blocked while choosing a hero")
	buttons[3].emit_signal("pressed")
	_check(scene.get("_selected_hero_index") == 3 and not picker.call("is_open"), "Button selects a hero and closes the picker")

	scene.call("_set_ghost_mode", true)
	var ghost_texture := hero.texture
	scene.call("_select_hero", 8)
	_check(hero.texture == ghost_texture, "Selecting a hero preserves ghost form")
	scene.call("_set_ghost_mode", false)
	_check(hero.texture.resource_path == DEMO_SCRIPT.HERO_VARIANTS[8]["path"], "Leaving ghost mode restores the chosen hero")
	scene.call("_unhandled_key_input", shortcut)
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	scene.call("_unhandled_key_input", cancel)
	_check(not picker.call("is_open"), "Escape closes the hero picker")
	scene.call("_select_hero", 0)


func _check_movement(scene: Node2D, hero: Sprite2D) -> void:
	var start_cell: Vector2i = scene.get("_hero_cell")
	var start_position := hero.position
	var direction := Vector2i.ZERO
	for candidate in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if scene.call("_is_walkable", start_cell + candidate):
			direction = candidate
			break
	_check(direction != Vector2i.ZERO, "Hero has a walkable neighboring cell")
	if direction == Vector2i.ZERO:
		return
	scene.call("_try_move_hero", direction)
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(hero.position == start_position + Vector2(direction) * GRID.TILE_SIZE, "Hero moves exactly 64px")
	var camera: Camera2D = scene.get("_camera")
	_check(camera.position == hero.position, "Camera follows grid movement")
	_check(not scene.get("_is_moving"), "Movement completes")
	scene.call("_try_move_hero", -direction)
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(hero.position == start_position, "Hero returns to the original cell")


func _check_responsive_movement(scene: Node2D, hero: Sprite2D) -> void:
	var original_cell: Vector2i = scene.get("_hero_cell")
	var camera := scene.get("_camera") as Camera2D
	var start := Vector2i(20, 20)
	var first := start + Vector2i.RIGHT
	var second := first + Vector2i.DOWN
	var blocked := second + Vector2i.RIGHT
	var original_terrain: Dictionary = {}
	for cell in [start, first, second, blocked]:
		original_terrain[cell] = scene.call("_terrain_type", cell)
		scene.call("_set_terrain_cell", cell, DEMO_SCRIPT.TileType.FLOOR)
	scene.call("_set_terrain_cell", blocked, DEMO_SCRIPT.TileType.WALL)
	scene.set("_hero_cell", start)
	hero.position = scene.call("_cell_center", start)
	camera.position = hero.position
	camera.force_update_scroll()
	var items: Dictionary = scene.get("_items_by_cell")
	var sword := load(DEMO_SCRIPT.SWORD_PATH) as Texture2D
	scene.call("_add_item", sword, first, 1.0, 10, DEMO_SCRIPT.ITEM_ID_SWORD)
	scene.call("_add_item", sword, second, 1.0, 10, DEMO_SCRIPT.ITEM_ID_SWORD)
	var inventory_size: int = scene.get("_inventory").size()

	var input := InputEventKey.new()
	input.pressed = true
	input.physical_keycode = KEY_D
	scene.call("_unhandled_key_input", input)
	var previous_tween: Tween = scene.get("_hero_move_tween")
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 0.25).timeout
	var first_center: Vector2 = scene.call("_cell_center", first)
	_check(scene.get("_is_moving") and hero.position != first_center, "First step is still animating")
	input.physical_keycode = KEY_S
	scene.call("_unhandled_key_input", input)
	_check(hero.position == first_center and camera.position == first_center, "New direction completes the old step immediately")
	_check(scene.get("_hero_cell") == second and scene.get("_is_moving"), "Next step starts immediately from the completed cell")
	_check(not previous_tween.is_running() and scene.get("_hero_move_tween") != previous_tween, "Previous movement tween is cancelled")
	_check(not items.has(first) and not items.has(second), "Logical steps pick up items before the enemy response")
	_check(scene.get("_inventory").size() == inventory_size + 2, "Each accepted step adds its item once")

	input.physical_keycode = KEY_D
	scene.call("_unhandled_key_input", input)
	var second_center: Vector2 = scene.call("_cell_center", second)
	_check(hero.position == second_center and camera.position == second_center, "Even a blocked request finishes the current animation")
	_check(scene.get("_hero_cell") == second and not scene.get("_is_moving"), "Blocked request stays in the completed cell")
	_check(scene.get("_hero_move_tween") == null, "Blocked request leaves no movement tween")
	_check(not items.has(second) and scene.get("_inventory").size() == inventory_size + 2, "Second interrupted arrival picks up its item once")
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(hero.position == second_center and camera.position == second_center, "Cancelled tweens cannot move the hero or camera later")
	_check(not scene.get("_is_moving") and scene.get("_inventory").size() == inventory_size + 2, "Cancelled callbacks cannot restart movement or duplicate pickups")

	for cell in original_terrain:
		scene.call("_set_terrain_cell", cell, original_terrain[cell])
	scene.set("_hero_cell", original_cell)
	hero.position = scene.call("_cell_center", original_cell)
	camera.position = hero.position
	camera.force_update_scroll()
	scene.call("_update_enemy_facing")
	scene.call("_update_visible_chunks")
	scene.call("_update_fog")


func _send_movement_key(keycode: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _wait_for_cell(scene: Node2D, cell: Vector2i) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while scene.get("_hero_cell") != cell and Time.get_ticks_msec() < deadline:
		await process_frame
	return scene.get("_hero_cell") == cell


func _check_held_movement(scene: Node2D, hero: Sprite2D) -> void:
	var original_cell: Vector2i = scene.get("_hero_cell")
	var camera := scene.get("_camera") as Camera2D
	var start := Vector2i(20, 25)
	var original_terrain: Dictionary = {}
	for y in range(22, 27):
		for x in range(19, 27):
			var cell := Vector2i(x, y)
			original_terrain[cell] = scene.call("_terrain_type", cell)
			var border := x == 19 or x == 26 or y == 22 or y == 26
			scene.call("_set_terrain_cell", cell, DEMO_SCRIPT.TileType.WALL if border else DEMO_SCRIPT.TileType.FLOOR)
	scene.call("_set_terrain_cell", Vector2i(24, 25), DEMO_SCRIPT.TileType.WALL)
	scene.set("_hero_cell", start)
	hero.position = scene.call("_cell_center", start)
	camera.position = hero.position
	camera.force_update_scroll()

	_send_movement_key(KEY_D, true)
	await process_frame
	_check(scene.get("_hero_cell") == Vector2i(21, 25), "Key press starts one step")
	var first_tween: Tween = scene.get("_hero_move_tween")
	_send_movement_key(KEY_D, true, true)
	_check(scene.get("_hero_cell") == Vector2i(21, 25) and scene.get("_hero_move_tween") == first_tween, "Keyboard echo cannot accelerate held movement")
	_check(await _wait_for_cell(scene, Vector2i(22, 25)), "Held key automatically starts the next step")
	_send_movement_key(KEY_D, false)
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(scene.get("_hero_cell") == Vector2i(22, 25) and not scene.get("_is_moving"), "Releasing the key finishes the current step without starting another")

	_send_movement_key(KEY_D, true)
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(scene.get("_hero_cell") == Vector2i(23, 25) and not scene.get("_is_moving"), "Held movement stops at a wall")
	var picker := scene.get("_hero_picker") as Node
	picker.call("toggle")
	scene.call("_set_terrain_cell", Vector2i(24, 25), DEMO_SCRIPT.TileType.FLOOR)
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(scene.get("_hero_cell") == Vector2i(23, 25), "Hero picker blocks held movement")
	picker.call("hide_picker")
	_check(await _wait_for_cell(scene, Vector2i(24, 25)), "Held movement resumes after closing the picker")
	_send_movement_key(KEY_W, true)
	_check(scene.get("_hero_cell") == Vector2i(24, 24), "A new direction interrupts the held step immediately")
	_check(await _wait_for_cell(scene, Vector2i(24, 23)), "The most recently pressed held key takes priority")
	_send_movement_key(KEY_W, false)
	_check(await _wait_for_cell(scene, Vector2i(25, 23)), "Releasing the newest key falls back to the remaining held key")
	_send_movement_key(KEY_D, false)
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(hero.position == scene.call("_cell_center", Vector2i(25, 23)) and camera.position == hero.position, "Held movement ends on the grid with the camera aligned")

	_send_movement_key(KEY_A, true)
	scene.get_window().focus_exited.emit()
	await create_timer(DEMO_SCRIPT.HERO_MOVE_DURATION * 2.0).timeout
	_check(scene.get("_hero_cell") == Vector2i(24, 23) and not scene.get("_is_moving"), "Focus loss stops repeated movement after the current step")
	_check(scene.get("_held_move_keys").is_empty(), "Focus loss clears remembered keys")
	_send_movement_key(KEY_A, false)

	for cell in original_terrain:
		scene.call("_set_terrain_cell", cell, original_terrain[cell])
	scene.set("_hero_cell", original_cell)
	hero.position = scene.call("_cell_center", original_cell)
	camera.position = hero.position
	camera.force_update_scroll()
	scene.call("_update_enemy_facing")
	scene.call("_update_visible_chunks")
	scene.call("_update_fog")


func _check_ghost_mode(scene: Node2D, hero: Sprite2D) -> void:
	var blocked: Dictionary = scene.get("_blocked_cells")
	_check(not blocked.is_empty(), "Map contains blocking terrain")
	if blocked.is_empty():
		return
	var wall: Vector2i = blocked.keys()[0]
	_check(not scene.call("_is_walkable", wall), "Walls block the normal hero")
	scene.call("_set_terrain_cell", Vector2i(20, 5), DEMO_SCRIPT.TileType.FLOOR)
	var goblin_id: int = scene.call("_spawn_goblin", Vector2i(20, 5), DEMO_SCRIPT.GOBLIN_TYPES.DEFAULT_TYPE)
	_check(not scene.call("_is_walkable", Vector2i(20, 5)), "Monsters block movement")
	scene.call("_set_ghost_mode", true)
	_check(scene.call("_is_walkable", wall), "Ghost passes through walls")
	_check(not scene.call("_is_walkable", Vector2i(20, 5)), "Ghost still respects monster collision")
	_check(hero.texture.get_size() == Vector2.ONE * GRID.TILE_SIZE, "Ghost texture fits one cell")
	scene.call("_set_ghost_mode", false)
	scene.call("_remove_goblin", goblin_id)


func _check_fog_fades(scene: Node2D) -> void:
	var duration := DEMO_SCRIPT.FOG_FADE_DURATION
	await create_timer(duration * 1.5).timeout
	var hero_cell: Vector2i = scene.get("_hero_cell")
	var fog_cells: Dictionary = scene.get("_fog_cells")
	var fog := fog_cells[hero_cell] as ColorRect
	_check(not fog.visible and is_zero_approx(fog.self_modulate.a), "Revealed cell finishes without fog")

	scene.call("_set_fog_visibility", hero_cell, true)
	_check(fog.visible and is_zero_approx(fog.self_modulate.a), "Covering starts from the current transparency")
	var tween: Tween = scene.get("_fog_tweens")[hero_cell]
	await create_timer(duration * 0.25).timeout
	var intermediate := fog.self_modulate.a
	_check(intermediate > 0.0 and intermediate < 1.0, "Fog opacity changes gradually")
	scene.call("_set_fog_visibility", hero_cell, true)
	_check(scene.get("_fog_tweens")[hero_cell] == tween, "Repeated visibility updates keep the current animation")
	scene.call("_update_fog")
	_check(is_equal_approx(fog.self_modulate.a, intermediate), "Reversing visibility preserves the current opacity")
	await create_timer(duration * 1.5).timeout
	_check(not fog.visible and is_zero_approx(fog.self_modulate.a), "Reversed reveal finishes with the fog hidden")
	_check(not scene.get("_fog_tweens").has(hero_cell), "Completed animation releases its tween")

	scene.call("_set_fog_visibility", hero_cell, true)
	await create_timer(duration * 1.5).timeout
	_check(fog.visible and is_equal_approx(fog.self_modulate.a, 1.0), "Covering finishes with full fog opacity")
	scene.call("_set_ghost_mode", true)
	_check(scene.get("_fog_tweens").size() <= 196, "Ghost mode animates the viewport instead of every loaded cell")
	await create_timer(duration * 1.5).timeout
	for cell in fog_cells:
		var cell_fog := fog_cells[cell] as ColorRect
		_check(not cell_fog.visible and is_zero_approx(cell_fog.self_modulate.a), "Ghost mode clears all fog: %s" % cell)
	scene.call("_set_ghost_mode", false)
	await create_timer(duration * 1.5).timeout
	var visible: Dictionary = scene.get("_visible_cells")
	var pending: Dictionary = scene.get("_fog_cells_pending_hide")
	for cell in fog_cells:
		var cell_fog := fog_cells[cell] as ColorRect
		var covered := not visible.has(cell) and not pending.has(cell)
		_check(cell_fog.visible == covered, "Leaving ghost mode restores fog visibility: %s" % cell)
		_check(is_equal_approx(cell_fog.self_modulate.a, 1.0 if covered else 0.0), "Leaving ghost mode restores fog opacity: %s" % cell)
	_check(scene.get("_fog_tweens").is_empty(), "Finished fog transitions leave no active tweens")

	# The old edge rule keeps a revealed outgoing tile open until it leaves the view mask.
	var edge_cell := hero_cell + Vector2i(6, 0)
	var edge_fog := fog_cells[edge_cell] as ColorRect
	scene.call("_set_fog_visibility", edge_cell, false, false)
	pending[edge_cell] = true
	scene.call("_update_fog")
	_check(pending.has(edge_cell) and not edge_fog.visible, "Outgoing tile stays revealed at the view edge")
	var camera := scene.get("_camera") as Camera2D
	var original_position := camera.position
	camera.position -= Vector2(GRID.TILE_SIZE, 0)
	camera.force_update_scroll()
	await process_frame
	scene.call("_hide_fog_cells_outside_view")
	_check(not pending.has(edge_cell), "Outgoing tile is released after leaving the view")
	_check(edge_fog.visible and is_equal_approx(edge_fog.self_modulate.a, 1.0), "Offscreen tile closes without an unnecessary tween")
	camera.position = original_position
	camera.force_update_scroll()
	await process_frame
	scene.call("_update_fog")


func _check_fog_edges(scene: Node2D) -> void:
	var origin: Vector2i = scene.get("_hero_cell")
	var radius := DEMO_SCRIPT.HERO_SIGHT_RADIUS
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var fixture := DEMO_SCRIPT.new()
		fixture.set("_built", true)
		fixture.set("_hero", scene.get("_hero"))
		fixture.set("_hero_cell", origin)
		root.add_child(fixture)
		var fog_cells: Dictionary = fixture.get("_fog_cells")
		for y in range(-radius - 2, radius + 3):
			for x in range(-radius - 2, radius + 3):
				var cell := origin + Vector2i(x, y)
				fixture.call("_set_terrain_cell", cell, DEMO_SCRIPT.TileType.FLOOR)
				var fog := fixture.call("_create_fog_cell", cell) as ColorRect
				fog_cells[cell] = fog
				fixture.add_child(fog)
		fixture.call("_update_fog")
		_check(fixture.get("_fog_tweens").is_empty(), "Initial view appears without a fade")
		var incoming := origin + direction * (radius + 1)
		var outgoing := origin - direction * radius
		fixture.set("_hero_cell", origin + direction)
		fixture.call("_update_fog")
		var incoming_fog := fog_cells[incoming] as ColorRect
		var outgoing_fog := fog_cells[outgoing] as ColorRect
		_check(not incoming_fog.visible and is_zero_approx(incoming_fog.self_modulate.a), "Incoming edge is fully revealed before sliding into view: %s" % direction)
		_check(not fixture.get("_fog_tweens").has(incoming), "Incoming edge has no reveal animation: %s" % direction)
		_check(not outgoing_fog.visible and fixture.get("_fog_cells_pending_hide").has(outgoing), "Outgoing edge stays revealed while sliding out: %s" % direction)
		_check(fixture.get("_fog_tweens").is_empty(), "Camera movement across open floor creates no fades: %s" % direction)

		if direction == Vector2i.RIGHT:
			var victim := origin + direction + Vector2i(2, 2)
			for neighbor_direction in DEMO_SCRIPT.ACTOR_SIGHT.DIRECTIONS:
				fixture.call("_set_terrain_cell", victim + neighbor_direction, DEMO_SCRIPT.TileType.WALL)
			fixture.call("_update_fog")
			var victim_fog := fog_cells[victim] as ColorRect
			_check(not fixture.get("_visible_cells").has(victim), "Walls change visibility inside the shared view")
			_check(fixture.get("_fog_tweens").has(victim), "Interior occlusion still animates")
			await create_timer(DEMO_SCRIPT.FOG_FADE_DURATION * 0.25).timeout
			var intermediate := victim_fog.self_modulate.a
			_check(intermediate > 0.0 and intermediate < 1.0, "Interior occlusion fades gradually")
			for neighbor_direction in DEMO_SCRIPT.ACTOR_SIGHT.DIRECTIONS:
				fixture.call("_set_terrain_cell", victim + neighbor_direction, DEMO_SCRIPT.TileType.FLOOR)
			fixture.call("_update_fog")
			_check(fixture.get("_fog_tweens").has(victim) and is_equal_approx(victim_fog.self_modulate.a, intermediate), "Interior reveal reverses from the current opacity")
			await create_timer(DEMO_SCRIPT.FOG_FADE_DURATION * 1.5).timeout
			_check(not victim_fog.visible and is_zero_approx(victim_fog.self_modulate.a), "Interior reveal completes without fog")
		fixture.free()


func _check_legacy_scene() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate()
	var hero := scene.get_node("CharacterBody2D")
	_check(hero.get("cell_size") == GRID.TILE_SIZE, "Legacy hero movement uses the same grid")
	_check(hero.get_node("Sprite2D").texture.get_size() == Vector2.ONE * GRID.TILE_SIZE, "Legacy hero texture")
	_check(hero.get_node("CollisionShape2D").shape.size == Vector2.ONE * GRID.TILE_SIZE, "Legacy collision size")
	_check(hero.get_node("Area2D/CollisionShape2D").shape.size == Vector2.ONE * GRID.TILE_SIZE, "Legacy area size")
	hero.call("_ready")
	var start_position: Vector2 = hero.position
	hero.call("_start_move", Vector2.RIGHT)
	var first_target := start_position + Vector2.RIGHT * GRID.TILE_SIZE
	hero.position = start_position + Vector2.RIGHT * (GRID.TILE_SIZE * 0.25)
	hero.call("_start_move", Vector2.UP)
	_check(hero.position == first_target, "Legacy hero completes an interrupted step immediately")
	_check(hero.get("target_position") == first_target + Vector2.UP * GRID.TILE_SIZE, "Legacy hero starts the next step from the completed cell")
	Input.action_press("ui_right")
	hero.call("_read_direction_just_pressed")
	await process_frame
	await process_frame
	var held_start: Vector2 = hero.get("target_position")
	hero.position = held_start
	hero.call("_process", 0.0)
	_check(hero.get("target_position") == held_start + Vector2.RIGHT * GRID.TILE_SIZE, "Legacy arrow key repeats after reaching the target")
	Input.action_release("ui_right")
	var final_target: Vector2 = hero.get("target_position")
	hero.call("_process", 0.1)
	_check(hero.position == final_target and hero.get("target_position") == final_target, "Legacy release completes the current step and stops")
	scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
