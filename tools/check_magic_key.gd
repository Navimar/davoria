extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const DOOR := Vector2i(7, 5)
const OTHER_DOOR := Vector2i(7, 7)
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DEMO.MAGIC_KEY_PATH))
	_check(image.get_size() == Vector2i(64, 64), "Key uses the native 64px canvas")
	_check(not DEMO.OBJECT_CATALOG.potion_pool().has(DEMO.ITEM_ID_MAGIC_KEY), "Valuable keys are authored items, not random potion loot")
	var folder := "/private/tmp/davoria_magic_key_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := "#".repeat(64)
		if y >= 2 and y < 16:
			row = "##" + ".".repeat(14) + "#".repeat(48)
		if y == DOOR.y or y == OTHER_DOOR.y:
			row = row.substr(0, 7) + "D" + row.substr(8)
		file.store_line(row)
	file.close()
	OBJECTS.save_map(OBJECTS.path_for_chunks(template), {Vector2i(5, 5): "hero_start", Vector2i(6, 5): DEMO.ITEM_ID_MAGIC_KEY})
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	_check(scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == DEMO.ITEM_ID_MAGIC_KEY), "Key appears in the catalog-driven editor")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	var ids: Array = scene.get("_inventory_item_ids")
	_check(ids.count(DEMO.ITEM_ID_MAGIC_KEY) == 1 and not scene.get("_items_by_cell").has(Vector2i(6, 5)), "A real map key enters the inventory")
	var queue: RefCounted = scene.get("_turn_queue")
	var before: int = queue.current_turn
	var prompt: CanvasLayer = scene.get("_door_prompt")
	# Real event dispatch checks that modal Space cannot also trigger a wait.
	_dispatch(KEY_D, true)
	await process_frame
	_check(prompt.is_open() and prompt.get("_selected_index") == 1 and prompt.get("_buttons")[1].has_focus(), "Attempting a closed door opens the question with No focused")
	_check(queue.current_turn == before and ids.count(DEMO.ITEM_ID_MAGIC_KEY) == 1 and scene.get("_held_move_keys").is_empty(), "Opening the question spends nothing and clears held movement")
	_check(prompt.find_child("DoorUnlockQuestion", true, false).text.replace("\n", " ") == "Потратить волшебный ключ, чтобы отпереть дверь?", "Question uses the requested text")
	scene.call("_wait_hero_turn")
	scene.call("_advance_world_turn")
	scene.call("_try_move_hero", Vector2i.DOWN)
	scene.call("_activate_inventory_slot", 0)
	_check(queue.current_turn == before and scene.get("_hero_cell") == Vector2i(6, 5) and not scene.get("_is_ghost_mode"), "The open modal blocks game actions and inventory activation")
	_dispatch(KEY_SPACE, true)
	await process_frame
	await process_frame
	_check(not prompt.is_open() and queue.current_turn == before and ids.count(DEMO.ITEM_ID_MAGIC_KEY) == 1 and scene.call("_terrain_type", DOOR) == DEMO.TileType.DOOR, "Default No preserves the key, door and turn and does not reopen while D is held")
	_dispatch(KEY_D, false)
	_dispatch(KEY_SPACE, false)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	for pair in [[KEY_W, 0], [KEY_S, 1], [KEY_A, 0], [KEY_D, 1], [KEY_W, 0]]:
		_key(scene, pair[0])
		_check(prompt.get("_selected_index") == pair[1] and prompt.get("_buttons")[pair[1]].has_focus(), "WASD chooses the actual focused Yes/No button")
	_dispatch(KEY_SPACE, true)
	await process_frame
	_dispatch(KEY_SPACE, false)
	_check(not prompt.is_open() and ids.count(DEMO.ITEM_ID_MAGIC_KEY) == 0 and queue.current_turn == before + 1 and scene.get("_hero_cell") == Vector2i(6, 5), "Confirming Yes consumes one key and one action without moving or adding a Space wait")
	_check(scene.call("_terrain_type", DOOR) == DEMO.TileType.FLOOR and scene.call("_is_walkable", DOOR) and scene.call("_is_terrain_visible_through", DOOR), "Unlocking updates movement and sight immediately")
	prompt.get("_buttons")[0].pressed.emit()
	scene.call("_on_door_unlock_decided", true)
	scene.call("_finish_hero_move", false)
	_check(queue.current_turn == before + 1, "Duplicate confirmation and animation completion cannot spend another turn")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_cell") == DOOR and queue.current_turn == before + 2, "The next action enters the unlocked door")
	# Every direction obeys the same rule and cancellation is free.
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		scene.set("_hero_cell", OTHER_DOOR - direction)
		scene.call("_finish_hero_move", false)
		before = queue.current_turn
		scene.call("_try_move_hero", direction)
		_check(not prompt.is_open() and queue.current_turn == before and scene.call("_terrain_type", OTHER_DOOR) == DEMO.TileType.DOOR, "No key means no free opening from any side")
		scene.call("_add_inventory_item", load(DEMO.MAGIC_KEY_PATH), DEMO.ITEM_ID_MAGIC_KEY)
		scene.call("_try_move_hero", direction)
		_check(prompt.is_open(), "A key can request unlocking from any side")
		if direction == Vector2i.UP:
			prompt.get("_buttons")[1].pressed.emit()
		else:
			_key(scene, KEY_ESCAPE)
		_check(not prompt.is_open() and queue.current_turn == before and ids.count(DEMO.ITEM_ID_MAGIC_KEY) == 1, "No button and Escape cancel without spending the key or action")
		var slot: int = ids.find(DEMO.ITEM_ID_MAGIC_KEY)
		scene.get("_inventory").remove_at(slot)
		ids.remove_at(slot)
	scene.call("_add_inventory_item", load(DEMO.MAGIC_KEY_PATH), DEMO.ITEM_ID_MAGIC_KEY)
	scene.set("_speed_boost_turns", 5)
	scene.set("_speed_actions_this_turn", 1)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_key(scene, KEY_SPACE)
	_check(queue.current_turn == before and scene.get("_speed_boost_turns") == 5 and scene.get("_speed_actions_this_turn") == 1, "No preserves a pending fast half-turn")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_key(scene, KEY_A)
	prompt.get("_buttons")[0].pressed.emit()
	_check(queue.current_turn == before + 1 and scene.get("_speed_boost_turns") == 4 and scene.get("_speed_actions_this_turn") == 0 and ids.count(DEMO.ITEM_ID_MAGIC_KEY) == 0, "Unlocking is exactly one accepted action under speed too")
	scene.call("_finish_hero_move", false)
	# Save writes only intentional editor data, restoring unopened doors/key on restart.
	scene.call("_set_editor_terrain_cell", Vector2i(11, 5), DEMO.TileType.WATER)
	scene.call("_save_loaded_chunks")
	var rows := FileAccess.get_file_as_string(template % [0, 0]).strip_edges().split("\n")
	_check(rows[DOOR.y][DOOR.x] == "D" and rows[OTHER_DOOR.y][OTHER_DOOR.x] == "D" and OBJECTS.read_map(OBJECTS.path_for_chunks(template)).objects[Vector2i(6, 5)] == DEMO.ITEM_ID_MAGIC_KEY, "Save excludes opened doors and consumed authored keys")
	scene.call("_build_scene")
	await process_frame
	prompt = scene.get("_door_prompt")
	_check(not prompt.is_open() and scene.get("_pending_door_cell") == null and scene.call("_terrain_type", DOOR) == DEMO.TileType.DOOR and scene.get("_items_by_cell").has(Vector2i(6, 5)), "Restart restores closed doors and the map key and clears modal state")
	# Revalidate at confirmation; stale keys or changed doors never consume resources.
	scene.set("_hero_cell", Vector2i(6, 5))
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	var slot: int = scene.get("_inventory_item_ids").find(DEMO.ITEM_ID_MAGIC_KEY)
	scene.get("_inventory").remove_at(slot)
	scene.get("_inventory_item_ids").remove_at(slot)
	_key(scene, KEY_A)
	_key(scene, KEY_SPACE)
	_check(scene.call("_terrain_type", DOOR) == DEMO.TileType.DOOR and scene.get("_turn_queue").current_turn == 0, "Missing key at confirmation cannot open the door or spend a turn")
	scene.call("_add_inventory_item", load(DEMO.MAGIC_KEY_PATH), DEMO.ITEM_ID_MAGIC_KEY)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_set_terrain_cell", DOOR, DEMO.TileType.FLOOR)
	_key(scene, KEY_A)
	_key(scene, KEY_SPACE)
	_check(scene.get("_inventory_item_ids").count(DEMO.ITEM_ID_MAGIC_KEY) == 1 and scene.get("_turn_queue").current_turn == 0, "A changed door at confirmation cannot waste a key")
	# Modal controls remain onscreen at different window sizes.
	var original_size := root.size
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720)]:
		root.size = size
		prompt.show_prompt()
		await process_frame
		var panel: Control = prompt.find_child("DoorUnlockPanel", true, false)
		_check(scene.get_viewport_rect().encloses(panel.get_global_rect()), "The complete modal fits the viewport")
		prompt.hide_prompt()
	root.size = original_size
	scene.free()
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("MAGIC KEY OK: native item, automatic editor, real pickup, WASD/Space and mouse controls, safe default/cancel, modal input freeze, one-use unlock from every side, no double turn/held repeat, speed, Save/restart and stale-state revalidation")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _key(scene: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	scene.call("_unhandled_key_input", event)


func _dispatch(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
