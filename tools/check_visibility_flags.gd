extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const ORIGIN := Vector2i(5, 30)
const OBSTACLE := Vector2i(6, 30)
const TARGET := Vector2i(8, 30)
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# A one-cell corridor prevents alternate diagonal sight paths around an obstacle.
	var folder := "/private/tmp/davoria_visibility_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			row += "." if y == 30 and x >= 4 and x <= 10 else "#"
		file.store_line(row)
	file.close()
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	scene.call("_erase_live_map_object", OBSTACLE)
	scene.call("_spawn_map_object", OBSTACLE, "potion_cabinet")
	_check(not scene.call("_is_walkable", OBSTACLE) and not scene.call("_goblin_can_step", OBSTACLE), "Full cabinet blocks both hero and goblin movement")
	_check(scene.call("_is_terrain_visible_through", OBSTACLE) and scene.call("_calculate_visible_cells", ORIGIN).has(TARGET), "Player FOV passes through the full cabinet")
	_check(scene.call("_actor_can_see", TARGET, ORIGIN), "Enemy sight passes through the same cabinet")
	var cabinet: Dictionary = scene.get("_cabinets")[OBSTACLE]
	cabinet.contents.assign([DEMO.ITEM_ID_HEALTH_POTION])
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(cabinet.contents.is_empty() and not scene.call("_is_walkable", OBSTACLE) and scene.call("_calculate_visible_cells", ORIGIN).has(TARGET), "Looting changes the cabinet state while retaining blocked movement and clear sight")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.call("_is_walkable", OBSTACLE) and scene.call("_actor_can_see", TARGET, ORIGIN), "Broken cabinet frees movement and keeps sight clear")
	scene.call("_spawn_map_object", OBSTACLE, "empty_cabinet")
	_check(not scene.call("_is_walkable", OBSTACLE) and scene.call("_actor_can_see", TARGET, ORIGIN), "An authored empty cabinet has the same independent flags")
	scene.call("_erase_live_map_object", OBSTACLE)
	var entries := CATALOG.definitions()
	# A future prop registers once in the catalog, with no special collision/FOV/editor code.
	var prop := {"id": "fixture_visibility_prop", "name_key": "FIXTURE_VISIBILITY_PROP", "category": "prop", "path": DEMO.CABINET_FULL_PATH, "blocks_movement": false, "blocks_sight": false}
	entries.append(prop)
	for movement in [false, true]:
		for sight in [false, true]:
			prop.blocks_movement = movement
			prop.blocks_sight = sight
			scene.call("_spawn_map_object", OBSTACLE, prop.id)
			_check(scene.call("_is_walkable", OBSTACLE) == not movement and scene.call("_goblin_can_step", OBSTACLE) == not movement, "Movement honors the prop flag independently of sight")
			var visible: Dictionary = scene.call("_calculate_visible_cells", ORIGIN)
			_check(visible.has(OBSTACLE) and visible.has(TARGET) == not sight, "FOV reveals the obstacle itself and honors only its sight flag beyond it")
			_check(scene.call("_actor_can_see", TARGET, ORIGIN) == not sight, "Player and enemy sight use the same independent prop flag")
			if not movement and sight:
				scene.call("_try_move_hero", Vector2i.RIGHT)
				scene.call("_finish_hero_move", false)
				_check(scene.get("_hero_cell") == OBSTACLE and scene.get("_props_by_cell").has(OBSTACLE), "A smoke-like prop can be entered without being picked up or removed")
				scene.set("_hero_cell", ORIGIN)
				scene.call("_finish_hero_move", false)
			scene.call("_erase_live_map_object", OBSTACLE)
	scene.call("_toggle_editor")
	var found := false
	for button: Button in scene.get("_editor_canvas").find_children("*", "Button", true, false):
		found = found or button.get_meta("object_type", "") == prop.id
	_check(found, "A registered prop automatically appears in the existing editor palette")
	entries.pop_back()
	# Terrain also supports independent flags; water can stay passable while hiding sight.
	var water := CATALOG.terrain_definition(DEMO.TileType.WATER)
	water.blocks_sight = true
	scene.call("_set_terrain_cell", OBSTACLE, DEMO.TileType.WATER)
	_check(scene.call("_is_walkable", OBSTACLE) and not scene.call("_calculate_visible_cells", ORIGIN).has(TARGET), "Terrain movement and sight flags are independent too")
	water.blocks_sight = false
	_check(scene.call("_calculate_visible_cells", ORIGIN).has(TARGET), "Transparent water restores sight without changing collision")
	for tile_type in [DEMO.TileType.WALL, DEMO.TileType.DOOR]:
		scene.call("_set_terrain_cell", OBSTACLE, tile_type)
		_check(not scene.call("_is_walkable", OBSTACLE) and not scene.call("_calculate_visible_cells", ORIGIN).has(TARGET), "Walls and closed doors retain blocked movement and blocked sight")
	scene.free()
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("VISIBILITY FLAGS OK: full/empty/broken cabinets, independent movement/sight in all four prop combinations, passable smoke-like props, shared FOV, automatic editor and independent terrain flags")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
