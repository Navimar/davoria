extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const LOADER := preload("res://scripts/chunk_loader.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const TYPES := preload("res://scripts/goblin_types.gd")
const BLASTED_WALL := Vector2i(6, 27)
const WATER_EDIT := Vector2i(7, 29)
const DOOR_EDIT := Vector2i(8, 29)
const RUNTIME_DOOR := Vector2i(8, 28)
var _errors: Array[String] = []
var _folder: String
var _template: String


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Exercise the real Save button against isolated files, never the user's map.
	_folder = "/private/tmp/davoria_editor_save_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_template = _folder.path_join("chunk_%d_%d.txt")
	DirAccess.make_dir_recursive_absolute(_folder)
	var expected := FileAccess.get_file_as_string(DEMO.CHUNK_PATH_TEMPLATE % [0, 0]).strip_edges().split("\n")
	_replace_cell(expected, RUNTIME_DOOR, "D")
	_replace_cell(expected, BLASTED_WALL, "#")
	_replace_cell(expected, WATER_EDIT, ".")
	_replace_cell(expected, DOOR_EDIT, ".")
	var original := "\n".join(expected) + "\n"
	var file := FileAccess.open(_template % [0, 0], FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", _template)
	root.add_child(scene)
	await process_frame
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	scene.call("_toggle_editor")
	var cabinet_cell: Vector2i = LEVEL.POTION_CABINETS[0].cell
	scene.get("_cabinets")[cabinet_cell].contents.assign([DEMO.ITEM_ID_HEALTH_POTION])
	scene.set("_hero_cell", cabinet_cell + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.UP)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_cabinets")[cabinet_cell].contents.is_empty() and scene.get("_editor_changes").is_empty(), "Looting a cabinet is gameplay state, not an authored map edit")

	# Simulate runtime terrain changes independently of interaction mechanics.
	scene.call("_set_terrain_cell", RUNTIME_DOOR, DEMO.TileType.FLOOR)
	scene.call("_set_terrain_cell", BLASTED_WALL, DEMO.TileType.FLOOR)
	var distant_chunk := Vector2i(3, 2)
	var distant_cell := distant_chunk * DEMO.CHUNK_SIZE
	scene.call("_load_chunk", distant_chunk)
	scene.call("_set_terrain_cell", distant_cell, DEMO.TileType.FLOOR)
	_click_save(scene)
	_check(_read(Vector2i.ZERO) == original, "Save without editor changes does not persist an open door or destroyed wall")
	_check(DirAccess.get_files_at(_folder).size() == 1, "Exploring and changing gameplay terrain never creates chunk files")

	_paint(scene, WATER_EDIT, DEMO.TileType.WATER)
	_paint(scene, DOOR_EDIT, DEMO.TileType.DOOR)
	# Runtime changes can happen even to cells with unsaved editor modifications.
	scene.call("_set_terrain_cell", WATER_EDIT, DEMO.TileType.FLOOR)
	scene.call("_set_terrain_cell", DOOR_EDIT, DEMO.TileType.FLOOR)
	_click_save(scene)
	_replace_cell(expected, WATER_EDIT, "~")
	_replace_cell(expected, DOOR_EDIT, "D")
	_check(_read(Vector2i.ZERO) == "\n".join(expected) + "\n", "Save persists editor intent and the complete original chunk, excluding every gameplay mutation")
	_check(scene.get("_editor_changes").is_empty(), "Successful Save clears only the editor's pending changes")
	_check(scene.call("_terrain_type", RUNTIME_DOOR) == DEMO.TileType.FLOOR and scene.call("_terrain_type", BLASTED_WALL) == DEMO.TileType.FLOOR, "Saving the map does not undo the current game session")
	_check(scene.call("_terrain_type", WATER_EDIT) == DEMO.TileType.FLOOR, "A runtime change to an edited cell remains live after Save")
	_check(DirAccess.get_files_at(_folder).size() == 1, "Only the edited chunk is written, without temporary-file leftovers")

	var saved := _read(Vector2i.ZERO)
	scene.call("_set_terrain_cell", WATER_EDIT, DEMO.TileType.WALL)
	_click_save(scene)
	_check(_read(Vector2i.ZERO) == saved, "A repeated Save cannot promote later gameplay changes into the authored map")
	_paint(scene, WATER_EDIT, DEMO.TileType.WALL)
	_check(scene.get("_editor_changes").has(WATER_EDIT), "A new editor change is recorded relative to the last successful Save")
	_paint(scene, WATER_EDIT, DEMO.TileType.WATER)
	_check(scene.get("_editor_changes").is_empty(), "Repainting the last saved tile cancels the pending edit")
	_click_save(scene)
	_check(_read(Vector2i.ZERO) == saved, "Reverting an edit does not write the runtime state")

	var negative_cell := Vector2i(-1, 30)
	_paint(scene, negative_cell, DEMO.TileType.FLOOR)
	scene.call("_set_terrain_cell", Vector2i(-2, 30), DEMO.TileType.FLOOR)
	_paint(scene, distant_cell, DEMO.TileType.WATER)
	scene.call("_set_terrain_cell", distant_cell, DEMO.TileType.FLOOR)
	_click_save(scene)
	var negative := LOADER.read_chunk(Vector2i(-1, 0), _template, DEMO.CHUNK_SIZE)
	var distant := LOADER.read_chunk(distant_chunk, _template, DEMO.CHUNK_SIZE)
	var negative_cells: PackedByteArray = negative.cells
	var distant_cells: PackedByteArray = distant.cells
	for index in range(64 * 64):
		_check(negative_cells[index] == (DEMO.TileType.FLOOR if index == 30 * 64 + 63 else DEMO.TileType.WALL), "New negative chunk contains only its one explicit editor change")
		_check(distant_cells[index] == (DEMO.TileType.WATER if index == 0 else DEMO.TileType.WALL), "New distant chunk contains editor water rather than its gameplay floor")
	_check(DirAccess.get_files_at(_folder).size() == 3 and _read(Vector2i.ZERO) == saved, "Saving multiple edited chunks leaves the untouched existing chunk unchanged")

	# Painting a floor over an already-open runtime door is still an explicit edit.
	_paint(scene, RUNTIME_DOOR, DEMO.TileType.FLOOR)
	_click_save(scene)
	_replace_cell(expected, RUNTIME_DOOR, ".")
	_check(_read(Vector2i.ZERO) == "\n".join(expected) + "\n", "An explicit editor opening can be saved even if gameplay already opened that door")
	scene.call("_build_scene")
	_check(not scene.get("_cabinets")[cabinet_cell].contents.is_empty(), "Saving other map edits cannot persist a looted cabinet")
	_check(scene.call("_terrain_type", WATER_EDIT) == DEMO.TileType.WATER and scene.call("_terrain_type", DOOR_EDIT) == DEMO.TileType.DOOR, "Restart reloads the saved editor values")
	_check(scene.call("_terrain_type", BLASTED_WALL) == DEMO.TileType.WALL and scene.call("_terrain_type", RUNTIME_DOOR) == DEMO.TileType.FLOOR, "Restart restores gameplay destruction while retaining an intentional editor opening")
	_check(scene.get("_editor_changes").is_empty(), "Restart starts with no pending editor changes")
	_check_object_edits(scene)
	scene.free()
	for filename in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(filename))
	DirAccess.remove_absolute(_folder)
	if _errors.is_empty():
		print("EDITOR SAVE CHECK OK: real Save button, editor-only changes, gameplay doors/destruction, same-cell conflicts, no-op saves, reverts, negative/new chunks and object placement/removal/source-only persistence/reload")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_object_edits(scene: Node2D) -> void:
	scene.call("_toggle_editor")
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	var potion_cell := Vector2i(5, 29)
	var empty_cell := Vector2i(4, 29)
	var enemy_cell := Vector2i(-1, 30)
	_paint(scene, potion_cell, DEMO.TileType.FLOOR)
	_paint(scene, empty_cell, DEMO.TileType.FLOOR)
	var catalog: Array[Dictionary] = DEMO.OBJECT_CATALOG.definitions()
	catalog.append({"id": "test_catalog_item", "name": "Тестовый предмет", "category": "item", "path": DEMO.STRENGTH_POTION_PATH})
	scene.call("_rebuild_editor_palette")
	_place_object(scene, potion_cell, "test_catalog_item")
	_check(scene.get("_items_by_cell")[potion_cell].get_meta("item_id") == "test_catalog_item", "A newly registered type gets both a palette button and working spawn without editor changes")
	_place_object(scene, potion_cell, DEMO.ITEM_ID_STRENGTH_POTION)
	catalog.pop_back()
	scene.call("_rebuild_editor_palette")
	_place_object(scene, empty_cell, "empty_cabinet")
	_place_object(scene, enemy_cell, "strong_guard")
	_check(scene.get("_items_by_cell")[potion_cell].get_meta("item_id") == DEMO.ITEM_ID_STRENGTH_POTION, "Palette places a registered item with its real pickup behavior")
	_check(scene.get("_cabinets")[empty_cell].contents.is_empty(), "Editor can place an empty breakable cabinet")
	var actor_id: int = scene.get("_goblins_by_cell")[enemy_cell]
	var enemy: Dictionary = scene.get("_goblins")[actor_id]
	var limits := TYPES.strength_range("strong_guard")
	_check(enemy.type == "strong_guard" and enemy.strength >= limits.x and enemy.strength <= limits.y, "Palette places a goblin type with freshly rolled strength")
	# Change every live state before Save: pickup, cabinet loot/destruction, enemy health/movement.
	scene.call("_try_pickup_item", potion_cell)
	var cabinet_cell: Vector2i = LEVEL.POTION_CABINETS[0].cell
	scene.get("_cabinets")[cabinet_cell].contents.assign([DEMO.ITEM_ID_HEALTH_POTION])
	scene.set("_hero_cell", cabinet_cell + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.UP)
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.UP)
	scene.call("_finish_hero_move", false)
	enemy.strength = 1
	scene.get("_goblins_by_cell").erase(enemy_cell)
	scene.get("_actor_blocked_cells").erase(enemy_cell)
	enemy.cell = enemy_cell + Vector2i.LEFT
	scene.get("_goblins_by_cell")[enemy.cell] = actor_id
	scene.get("_actor_blocked_cells")[enemy.cell] = true
	_click_save(scene)
	var path := OBJECTS.path_for_chunks(_template)
	var data := OBJECTS.read_map(path)
	_check(data.error.is_empty() and data.objects[potion_cell] == DEMO.ITEM_ID_STRENGTH_POTION and data.objects[empty_cell] == "empty_cabinet" and data.objects[enemy_cell] == "strong_guard", "Object Save retains edited types and authored spawn positions")
	_check(data.objects[cabinet_cell] == "potion_cabinet" and not scene.get("_cabinets").has(cabinet_cell), "Save keeps the authored full-cabinet type after its live destruction")
	var text := FileAccess.get_file_as_string(path)
	var json = JSON.parse_string(text)
	for record: Dictionary in json.objects:
		_check(record.size() == 2 and record.has("type") and record.has("cell"), "Saved object records contain only type and cell, never loot, strength or current state")
	_check(scene.get("_editor_object_changes").is_empty(), "Successful object Save clears authoring changes")
	_click_save(scene)
	_check(FileAccess.get_file_as_string(path) == text, "Repeated Save does not promote gameplay state into object data")
	scene.call("_build_scene")
	_check(scene.get("_items_by_cell").has(potion_cell) and scene.get("_cabinets").has(cabinet_cell) and scene.get("_cabinets")[empty_cell].contents.is_empty(), "Restart reloads authored pickups and cabinets independently of previous loot/destruction")
	# The negative chunk lies outside the initial view: its object spawns when its terrain loads.
	scene.call("_load_chunk", Vector2i(-1, 0))
	_check(scene.get("_goblins_by_cell").has(enemy_cell), "Saved objects in another chunk load with its terrain")
	actor_id = scene.get("_goblins_by_cell")[enemy_cell]
	enemy = scene.get("_goblins")[actor_id]
	_check(enemy.type == "strong_guard" and enemy.strength >= limits.x and enemy.strength <= limits.y, "Reload rolls the saved enemy type rather than saving one hit point")
	scene.call("_toggle_editor")
	_place_object(scene, potion_cell, "erase")
	_place_object(scene, enemy_cell, "erase")
	_check(not scene.get("_items_by_cell").has(potion_cell) and not scene.get("_goblins_by_cell").has(enemy_cell), "Object eraser immediately removes item and NPC collision")
	# Explicit changes can be reverted before saving.
	_place_object(scene, empty_cell, "potion_cabinet")
	_place_object(scene, empty_cell, "empty_cabinet")
	_check(not scene.get("_editor_object_changes").has(empty_cell), "Restoring the saved object type cancels its pending edit")
	var hero_cell := Vector2i(5, 28)
	_paint(scene, hero_cell, DEMO.TileType.FLOOR)
	_place_object(scene, hero_cell, "hero_start")
	_check(scene.get("_hero_cell") == hero_cell, "Hero start brush relocates the hero without a world turn")
	_click_save(scene)
	scene.call("_build_scene")
	data = OBJECTS.read_map(path)
	_check(not data.objects.has(potion_cell) and not data.objects.has(enemy_cell) and data.objects[hero_cell] == "hero_start" and not data.objects.has(LEVEL.HERO_START_CELL), "Removal and one relocated hero spawn survive Save/reload")
	_check(scene.get("_hero_cell") == hero_cell and scene.get("_hero_magic") == 10 and scene.get("_turn_queue").current_turn == 0, "Restart honors editor hero start while resetting runtime stats")


func _place_object(scene: Node2D, cell: Vector2i, type_id: String) -> void:
	# Use the generated real palette button instead of directly setting its selection.
	if type_id == "erase":
		scene.call("_select_editor_object", type_id)
	else:
		var found := false
		for button: Button in scene.get("_editor_canvas").find_children("*", "Button", true, false):
			if button.get_meta("object_type", "") == type_id:
				button.pressed.emit()
				found = true
				break
		_check(found, "Automatically generated palette button exists: " + type_id)
	scene.call("_paint_selected_tile", cell)


func _paint(scene: Node2D, cell: Vector2i, tile_type: int) -> void:
	scene.call("_select_editor_tile", tile_type)
	scene.call("_paint_selected_tile", cell)


func _click_save(scene: Node2D) -> void:
	var editor: CanvasLayer = scene.get("_editor_canvas")
	for button: Button in editor.find_children("*", "Button", true, false):
		if button.text == "Save":
			button.pressed.emit()
			return
	_check(false, "The map editor has its real Save button")


func _read(chunk: Vector2i) -> String:
	return FileAccess.get_file_as_string(_template % [chunk.x, chunk.y])


func _replace_cell(rows: PackedStringArray, cell: Vector2i, value: String) -> void:
	rows[cell.y] = rows[cell.y].substr(0, cell.x) + value + rows[cell.y].substr(cell.x + 1)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
