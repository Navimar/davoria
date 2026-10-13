extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const PROFILE := preload("res://tools/monster_profile_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const HERO := Vector2i(5, 5)
var _errors: Array[String] = []
var _folders: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_bookcase()
	await _check_encounter_cache()
	await _check_local_fog()
	for folder in _folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("BOOKCASE AND PERFORMANCE OK: separate scroll loot, native book groups/shelf depletion, bump pickup, break/restart/source Save, automatic editor, no repeated global sight scans, terrain/opaque-prop cache invalidation and local fog updates")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _fixture(objects: Dictionary, terrain: Dictionary = {}) -> Node2D:
	var folder := "/private/tmp/davoria_bookcases_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_folders.append(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			row += terrain.get(Vector2i(x, y), "." if x >= 2 and x <= 20 and y >= 2 and y <= 20 else "#")
		file.store_line(row)
	file.close()
	var map := objects.duplicate()
	map[HERO] = "hero_start"
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(template), map), "Isolated bookcase map is saved")
	var scene: Node2D = SCENE.instantiate()
	scene.set_script(PROFILE)
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	return scene


func _check_bookcase() -> void:
	var cell := HERO + Vector2i.LEFT
	var scene := await _fixture({cell: "bookcase"})
	var cabinet: Dictionary = scene.get("_cabinets")[cell]
	_check(CATALOG.loot_pool("scrolls") == ["push_scroll"] and not CATALOG.loot_pool("tools").has("push_scroll"), "Bookcases and tool cabinets have separate loot groups")
	_check(cabinet.contents.size() in [1, 2, 3] and cabinet.contents.all(func(id: String) -> bool: return id == "push_scroll"), "Bookcase generates one to three registered scrolls")
	_check(cabinet.sprite.texture.resource_path == CATALOG.BOOKCASE_PATH and cabinet.sprite.scale == Vector2.ONE and not scene.call("_is_walkable", cell) and scene.call("_is_terrain_visible_through", cell), "Native bookcase blocks movement while passing sight")
	_check(scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == "bookcase"), "Editor discovers the registered bookcase automatically")
	var definition := CATALOG.definition("bookcase")
	var full: Image = cabinet.sprite.texture.get_image()
	var empty: Image = scene.get("_cabinet_visual_cache")[CATALOG.BOOKCASE_PATH].empty.get_image()
	for y in range(64):
		for x in range(64):
			var point := Vector2i(x, y)
			if not definition.shelf_areas.any(func(area: Rect2i) -> bool: return area.has_point(point)):
				_check(full.get_pixelv(point) == empty.get_pixelv(point), "Emptying shelves preserves all bookcase frame/board pixels")
	cabinet.contents.assign(["push_scroll", "push_scroll", "push_scroll"])
	scene.call("_update_cabinet_visual", cell)
	for remaining in range(3, -1, -1):
		var occupied := 0
		for patch: Sprite2D in cabinet.empty_shelves:
			if not patch.visible:
				occupied += 1
		_check(occupied == remaining and cabinet.sprite.texture.resource_path == CATALOG.BOOKCASE_PATH, "Whole original groups of books represent remaining scroll count")
		if remaining > 0:
			scene.call("_try_move_hero", Vector2i.LEFT)
			scene.call("_finish_hero_move", false)
	_check(scene.get("_inventory_item_ids").count("push_scroll") == 3 and scene.get("_turn_queue").current_turn == 3 and scene.get("_hero_cell") == HERO, "Each bump transfers one scroll for one action without moving")
	scene.call("_try_move_hero", Vector2i.LEFT)
	scene.call("_finish_hero_move", false)
	_check(not scene.get("_cabinets").has(cell) and scene.get("_editor_object_changes").is_empty(), "Empty bookcase breaks by normal cabinet rules without editing source")
	scene.call("_save_loaded_chunks")
	_check(OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template"))).objects.get(cell) == "bookcase", "Save remembers only the bookcase type")
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_cabinets")[cell].contents.size() in [1, 2, 3], "Restart restores the bookcase with freshly generated scrolls")
	scene.free()


func _check_encounter_cache() -> void:
	var wall: Dictionary = {}
	for y in range(2, 21):
		wall[Vector2i(7, y)] = "#"
	var creature := Vector2i(9, 5)
	var scene := await _fixture({creature: "cockatrice"}, wall)
	scene.get("measurements").clear()
	for index in range(100):
		scene.call("_check_enemy_encounters")
	_check(not scene.get("_encounter_prompt").is_open() and scene.get("measurements").get("full_sight", {}).get("calls", 0) <= 1, "Repeated hidden encounters reuse one sight calculation")
	scene.call("_set_terrain_cell", Vector2i(7, 5), PROFILE.TileType.FLOOR)
	scene.call("_check_enemy_encounters")
	_check(scene.get("_encounter_prompt").is_open() and scene.get("measurements").get("full_sight", {}).get("calls", 0) == 1, "Opening terrain invalidates cached sight before the next fog refresh")
	scene.get("_encounter_prompt").call("_accept")
	scene.get("measurements").clear()
	for index in range(100):
		scene.call("_check_enemy_encounters")
	_check(not scene.get("measurements").has("full_sight"), "Once acknowledged, the creature causes no further sight calculations")
	CATALOG.definitions().append({"id": "fixture_bookcase_smoke", "name_key": "FIXTURE_BOOKCASE_SMOKE", "category": "prop", "path": CATALOG.GHOST_RING_PATH, "blocks_movement": false, "blocks_sight": true})
	scene.get("_seen_encounters").clear()
	scene.call("_set_editor_map_object", creature, "cockatrice")
	scene.call("_set_editor_map_object", Vector2i(7, 5), "fixture_bookcase_smoke")
	scene.call("_check_enemy_encounters")
	_check(not scene.get("_encounter_prompt").is_open(), "A newly placed opaque prop invalidates encounter sight")
	scene.call("_set_editor_map_object", Vector2i(7, 5), "")
	scene.call("_check_enemy_encounters")
	_check(scene.get("_encounter_prompt").is_open(), "Removing opaque prop reveals the unseen creature immediately")
	scene.free()


func _check_local_fog() -> void:
	var first := HERO + Vector2i.DOWN
	var second := HERO + Vector2i.RIGHT
	var scene := await _fixture({first: "weak_club", second: "weak_club"})
	var by_cell: Dictionary = scene.get("_goblins_by_cell")
	var actors: Dictionary = scene.get("_goblins")
	var other: Sprite2D = actors[by_cell[second]].sprite
	other.modulate.a = 0.37
	scene.call("_set_fog_visibility", first, true, false)
	scene.call("_update_visibility_at_cell", first)
	_check(not actors[by_cell[first]].sprite.visible and is_equal_approx(other.modulate.a, 0.37), "Fog completion updates only the actor in its cell")
	scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
