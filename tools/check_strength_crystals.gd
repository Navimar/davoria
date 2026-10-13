extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const SCATTER := preload("res://scripts/crystal_scatter.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const FIXED_SEED := 20261012
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DEMO.STRENGTH_CRYSTAL_PATH))
	_check(image != null and image.get_size() == Vector2i(64, 64), "Crystal uses the native 64px canvas")
	if image != null:
		for y in range(64):
			for x in range(64):
				_check(image.get_pixel(x, y).a in [0.0, 1.0], "Crystal opacity is binary")
	_check(not OBJECTS.defaults().values().has(DEMO.ITEM_ID_STRENGTH_CRYSTAL), "Default map contains no crystals")
	var quarters := [0, 0, 0, 0]
	for cy in range(-2, 2):
		for cx in range(-2, 2):
			var chunk := Vector2i(cx, cy)
			var cells := SCATTER.candidates(chunk, DEMO.CHUNK_SIZE, FIXED_SEED)
			_check(cells == SCATTER.candidates(chunk, DEMO.CHUNK_SIZE, FIXED_SEED), "Scatter is stable, including negative chunks")
			_check(cells != SCATTER.candidates(chunk, DEMO.CHUNK_SIZE, FIXED_SEED + 1), "A different seed produces new scatter")
			quarters[(cy + 2) / 2 * 2 + (cx + 2) / 2] += cells.size()
	for count: int in quarters:
		_check(count > 16384 * 0.04 and count < 16384 * 0.06, "Every map quarter has approximately five-percent density")
	# Use isolated files, preserving the user's map and concurrent editor changes.
	var folder := "/private/tmp/davoria_crystal_scatter_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	for cx in [-1, 0, 1]:
		var file := FileAccess.open(template % [cx, 0], FileAccess.WRITE)
		for y in range(64):
			file.store_line("#".repeat(64) if y in [0, 63] else ("D".repeat(64) if y == 10 else ".".repeat(32) + "~".repeat(32)))
		file.close()
	var map_path := OBJECTS.path_for_chunks(template)
	var file := FileAccess.open(map_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"objects": [
		{"type": "hero_start", "cell": [20, 20]}, {"type": "sword", "cell": [21, 20]},
		{"type": "potion_cabinet", "cell": [22, 20]}, {"type": "weak_club", "cell": [23, 20]},
		{"type": "strength_crystal", "cell": [20, 21]}
	]}))
	file.close()
	_check(not OBJECTS.read_map(map_path).objects.values().has(DEMO.ITEM_ID_STRENGTH_CRYSTAL), "Legacy hand-placed crystals are ignored")
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	scene.get("_rng").seed = FIXED_SEED
	scene.call("_build_scene")
	await process_frame
	var seed: int = scene.get("_crystal_seed")
	scene.call("_load_chunk", Vector2i(1, 0))
	scene.call("_load_chunk", Vector2i(-1, 0))
	var original := _crystal_cells(scene)
	_check(original == _expected_cells(scene), "Only selected unoccupied passable cells get crystals")
	var floor_count := 0
	var water_count := 0
	for cell: Vector2i in original:
		var item: Sprite2D = scene.get("_items_by_cell")[cell]
		_check(scene.call("_is_walkable", cell) and item.scale == Vector2.ONE and not item.has_meta("map_origin"), "Crystals retain native scale, do not block and have no authored origin")
		if scene.call("_terrain_type", cell) == DEMO.TileType.WATER:
			water_count += 1
		else:
			floor_count += 1
	_check(floor_count > 5856 * 0.035 and floor_count < 5856 * 0.065 and water_count > 5856 * 0.035 and water_count < 5856 * 0.065, "Floor and water have the same approximately five-percent density")
	scene.get("_rng").seed = FIXED_SEED
	scene.call("_build_scene")
	scene.call("_load_chunk", Vector2i(-1, 0))
	scene.call("_load_chunk", Vector2i(1, 0))
	_check(scene.get("_crystal_seed") == seed and _crystal_cells(scene) == original, "Chunk loading order does not change scatter")
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	scene.call("_add_inventory_item", load(DEMO.SWORD_PATH), DEMO.ITEM_ID_SWORD)
	for index in range(scene.get("_inventory").size(), DEMO.INVENTORY_SIZE):
		scene.call("_add_inventory_item", load(DEMO.GHOST_RING_PATH), DEMO.ITEM_ID_GHOST_RING)
	var crystal_cell := _stand_beside_crystal(scene)
	var crystal: Sprite2D = scene.get("_items_by_cell")[crystal_cell]
	var queue: RefCounted = scene.get("_turn_queue")
	var turn: int = queue.current_turn
	scene.call("_try_move_hero", crystal_cell - scene.get("_hero_cell"))
	_check(scene.get("_hero_strength") == 11 and scene.get("_hero_max_strength") == 11 and scene.get("_inventory").size() == DEMO.INVENTORY_SIZE, "Pickup grants one current and maximum strength even with full inventory")
	_check(not scene.get("_items_by_cell").has(crystal_cell) and not crystal.visible and queue.current_turn == turn + 1, "Pickup removes the crystal within one movement turn")
	_check(scene.get("_hero_strength_label").text == "16" and scene.get("_stats_strength_label").text == "Сила: 11/11+5", "Pickup updates strength without changing weapon bonus")
	scene.call("_finish_hero_move", false)
	scene.call("_try_pickup_item", crystal_cell)
	scene.call("_spawn_chunk_objects", scene.call("_chunk_coord_for_cell", crystal_cell))
	scene.call("_load_chunk", scene.call("_chunk_coord_for_cell", crystal_cell))
	_check(not scene.get("_items_by_cell").has(crystal_cell) and scene.get("_hero_strength") == 11 and queue.current_turn == turn + 1, "Animation and repeated chunk access never regenerate or reward a collected crystal")
	scene.call("_try_pickup_item", Vector2i(21, 20))
	_check(scene.get("_items_by_cell").has(Vector2i(21, 20)), "Ordinary items still require an inventory slot")
	crystal_cell = _stand_beside_crystal(scene)
	scene.set("_hero_strength", 0)
	var maximum: int = scene.get("_hero_max_strength")
	scene.call("_try_move_hero", crystal_cell - scene.get("_hero_cell"))
	_check(scene.get("_hero_strength") == 1 and scene.get("_hero_max_strength") == maximum + 1, "An exhausted hero can recover by collecting a crystal")
	scene.call("_finish_hero_move", false)
	var cells := _crystal_cells(scene).keys().filter(func(cell: Vector2i) -> bool: return scene.call("_terrain_type", cell) == DEMO.TileType.FLOOR)
	var replacement: Vector2i = cells[0]
	scene.call("_set_editor_map_object", replacement, "sword")
	_check(scene.get("_items_by_cell")[replacement].get_meta("item_id") == "sword", "Editor objects replace procedural crystals immediately")
	var wall_cell: Vector2i = cells[1]
	scene.call("_set_editor_terrain_cell", wall_cell, DEMO.TileType.WALL)
	_check(not scene.get("_items_by_cell").has(wall_cell), "Painting a wall clears its procedural crystal")
	scene.call("_set_editor_map_object", Vector2i(22, 20), "empty_cabinet")
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(map_path)
	_check(saved.error.is_empty() and not saved.objects.values().has(DEMO.ITEM_ID_STRENGTH_CRYSTAL) and saved.objects[replacement] == "sword", "Actual Save excludes scatter and removes legacy crystal records")
	var attempted: Dictionary = saved.objects.duplicate()
	attempted[Vector2i(25, 25)] = DEMO.ITEM_ID_STRENGTH_CRYSTAL
	_check(OBJECTS.save_map(map_path, attempted) and not OBJECTS.read_map(map_path).objects.has(Vector2i(25, 25)), "Map serialization itself excludes procedural records")
	var buttons: Array[Node] = scene.get("_editor_palette").get_children()
	_check(not buttons.any(func(button: Button) -> bool: return button.get_meta("object_type", "") == DEMO.ITEM_ID_STRENGTH_CRYSTAL), "The generated palette excludes procedural crystals")
	scene.call("_set_editor_map_object", Vector2i(26, 25), DEMO.ITEM_ID_STRENGTH_CRYSTAL)
	_check(not scene.get("_editor_object_changes").has(Vector2i(26, 25)), "Crystals cannot be authored by direct editor selection")
	scene.call("_build_scene")
	_check(scene.get("_crystal_seed") != seed and scene.get("_hero_strength") == 10 and _crystal_cells(scene) == _expected_cells(scene), "New game resets strength and creates fresh valid scatter")
	scene.free()
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("CRYSTAL CHECK OK: uniform 1/20 floor/water scatter, loading order, no respawn, legacy migration, editor-only Save, native pixels, full-inventory pickup, exhaustion and new game")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _crystal_cells(scene: Node2D) -> Dictionary:
	var cells: Dictionary = {}
	for cell: Vector2i in scene.get("_items_by_cell"):
		if scene.get("_items_by_cell")[cell].get_meta("item_id") == DEMO.ITEM_ID_STRENGTH_CRYSTAL:
			cells[cell] = true
	return cells


func _expected_cells(scene: Node2D) -> Dictionary:
	var cells: Dictionary = {}
	var objects: Dictionary = scene.call("_authored_map_objects")
	for chunk: Vector2i in scene.get("_loaded_chunks"):
		for cell in SCATTER.candidates(chunk, DEMO.CHUNK_SIZE, scene.get("_crystal_seed")):
			if not CATALOG.terrain_definition(scene.call("_terrain_type", cell)).get("blocks_movement", false) and not objects.has(cell) and cell != scene.get("_hero_cell"):
				cells[cell] = true
	return cells


func _stand_beside_crystal(scene: Node2D) -> Vector2i:
	for cell: Vector2i in _crystal_cells(scene):
		if scene.call("_terrain_type", cell) != DEMO.TileType.FLOOR:
			continue
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := cell + direction
			if scene.call("_terrain_type", neighbor) == DEMO.TileType.FLOOR and scene.call("_is_walkable", neighbor) and not scene.get("_items_by_cell").has(neighbor):
				scene.set("_hero_cell", neighbor)
				scene.call("_finish_hero_move", false)
				return cell
	_check(false, "A natural crystal has an empty adjacent floor cell")
	return Vector2i.ZERO


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
