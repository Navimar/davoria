extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node2D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	var cell: Vector2i = LEVEL.POTION_CABINETS[0].cell
	var cabinet: Dictionary = scene.get("_cabinets")[cell]
	var contents: Array[String] = [DEMO.ITEM_ID_HEALTH_POTION, DEMO.ITEM_ID_STRENGTH_POTION, DEMO.ITEM_ID_WATER_BREATHING_POTION]
	cabinet.contents.assign(contents)
	scene.call("_update_cabinet_visual", cell)
	scene.set("_hero_cell", cell + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	var body: Texture2D = cabinet.sprite.texture
	var last_positions: Array[Vector2] = []
	for shelf: Sprite2D in cabinet.empty_shelves:
		last_positions.append(shelf.position)
	_check(_occupied(cabinet) == [true, true, true], "Three bottles occupy all three shelves")
	for index in range(3):
		var shelf: Sprite2D = cabinet.empty_shelves[index]
		_check(shelf.scale == Vector2.ONE and shelf.texture.get_size() == Vector2(DEMO.CABINET_SHELF_AREAS[index].size), "Empty shelf interiors occupy only the native bottle areas")
	var queue: RefCounted = scene.get("_turn_queue")
	var turn: int = queue.current_turn
	for expected in [[false, true, true], [false, false, true], [false, false, false]]:
		scene.call("_try_move_hero", Vector2i.UP)
		turn += 1
		_check(_occupied(cabinet) == expected and cabinet.sprite.texture == body, "Taking one potion empties one complete shelf without replacing the original cabinet body, even at zero")
		_check(queue.current_turn == turn and scene.get("_hero_cell") == cell + Vector2i.DOWN, "Shelf change belongs to one ordinary looting action")
		scene.call("_finish_hero_move", false)
		_check(_occupied(cabinet) == expected and queue.current_turn == turn, "Animation completion never empties another shelf")
		for index in range(3):
			_check(cabinet.empty_shelves[index].position == last_positions[index], "Shelf interiors stay at their original positions")
	_check(cabinet.contents.is_empty() and scene.call("_is_terrain_visible_through", cell) and not scene.call("_is_walkable", cell), "Zero bottles leave a transparent-for-sight but blocking empty cabinet")
	# A full inventory preserves both the logical contents and the visible shelves.
	cabinet.contents.assign([DEMO.ITEM_ID_STRENGTH_POTION])
	scene.call("_update_cabinet_visual", cell)
	for index in range(scene.get("_inventory").size(), DEMO.INVENTORY_SIZE):
		scene.call("_add_inventory_item", load(DEMO.GHOST_RING_PATH), DEMO.ITEM_ID_GHOST_RING)
	scene.call("_try_move_hero", Vector2i.UP)
	_check(cabinet.contents.size() == 1 and _occupied(cabinet) == [false, false, true] and queue.current_turn == turn, "Failed looting with full inventory cannot remove a visible bottle")
	# Mechanical preview of the actual scene sprites, without modifying the source assets.
	var preview := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.12, 0.14, 0.15))
	var empty_frame: Image
	for count in range(4):
		cabinet.contents.assign(contents.slice(3 - count, 3))
		scene.call("_update_cabinet_visual", cell)
		var frame: Image = cabinet.sprite.texture.get_image().duplicate()
		frame.convert(Image.FORMAT_RGBA8)
		for shelf: Sprite2D in cabinet.empty_shelves:
			if shelf.visible:
				var interior := shelf.texture.get_image()
				var position := Vector2i(Vector2(32, 32) + shelf.position - Vector2(interior.get_size()) * 0.5)
				frame.blit_rect(interior, Rect2i(Vector2i.ZERO, interior.get_size()), position)
		var original: Image = body.get_image()
		for y in range(64):
			for x in range(64):
				var in_empty_interior := false
				for row in range(DEMO.CABINET_SHELF_COUNT - count):
					in_empty_interior = in_empty_interior or DEMO.CABINET_SHELF_AREAS[row].has_point(Vector2i(x, y))
				if not in_empty_interior:
					_check(frame.get_pixel(x, y) == original.get_pixel(x, y), "The original frame, shelves and every filled shelf pixel remain unchanged")
		if count == 0:
			empty_frame = frame
		preview.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(count * 64, 0))
	preview.resize(1024, 256, Image.INTERPOLATE_NEAREST)
	var folder := "res://assets/generation/cabinet_shelves_2026-10-12"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var ignored := FileAccess.open(folder.path_join(".gdignore"), FileAccess.WRITE)
	ignored.close()
	preview.save_png(ProjectSettings.globalize_path(folder.path_join("preview_0_1_2_3.png")))
	var empty_icon: Image = scene.get("_cabinet_empty_texture").get_image()
	_check(empty_icon.get_size() == Vector2i(64, 64) and empty_icon.get_data() == empty_frame.get_data(), "The editor shows exactly the same emptied full cabinet at native size")
	_check(not FileAccess.file_exists("res://assets/props/furniture/series_01/03_cabinet_empty.png"), "The old separate empty cabinet asset is removed")
	cabinet.contents.clear()
	scene.call("_update_cabinet_visual", cell)
	scene.call("_try_move_hero", Vector2i.UP)
	_check(not scene.get("_cabinets").has(cell), "An empty cabinet remains breakable even with a full inventory")
	_check(scene.get("_editor_object_changes").is_empty(), "Visible shelf state never becomes an authored map edit")
	scene.call("_build_scene")
	for record: Dictionary in scene.get("_cabinets").values():
		var occupied := 0
		for visible in _occupied(record):
			if visible:
				occupied += 1
		_check(occupied == record.contents.size(), "Restart shows exactly the newly rolled number of bottles")
	scene.free()
	if _errors.is_empty():
		print("CABINET SHELVES OK: 3/2/1/0 occupancy, original filled rows, native shelf interiors/positions, one shelf per looting action, full inventory, breakage, authoring separation and restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _occupied(cabinet: Dictionary) -> Array[bool]:
	var result: Array[bool] = []
	for shelf: Sprite2D in cabinet.empty_shelves:
		result.append(cabinet.sprite.texture.resource_path == DEMO.CABINET_FULL_PATH and not shelf.visible)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
