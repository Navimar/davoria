extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const COMBAT := preload("res://scripts/strength_combat.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [DEMO.HEALTH_POTION_PATH, DEMO.STRENGTH_POTION_PATH, DEMO.WATER_BREATHING_POTION_PATH]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and image.get_size() == Vector2i(64, 64), "All potions have native 64px canvases")
		if image != null:
			for y in range(64):
				for x in range(64):
					var alpha := image.get_pixel(x, y).a
					_check(is_zero_approx(alpha) or is_equal_approx(alpha, 1.0), "Potion alpha is binary")
	var scene: Node2D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	scene.get("_rng").seed = 8329
	scene.call("_build_scene")
	await process_frame
	var cabinets: Dictionary = scene.get("_cabinets")
	var starting_contents: Dictionary = {}
	var seen: Dictionary = {}
	for cabinet_cell: Vector2i in cabinets:
		var cabinet: Dictionary = cabinets[cabinet_cell]
		if cabinet.sprite.get_meta("object_type", "") == "empty_cabinet":
			_check(cabinet.contents.is_empty(), "An authored empty cabinet starts with no potions")
		else:
			_check(cabinet.contents.size() >= 1 and cabinet.contents.size() <= 3, "Every filled cabinet rolls one to three potions")
		for item_id: String in cabinet.contents:
			_check(CATALOG.potion_ids().has(item_id), "Cabinet contents use registered potion types")
			seen[item_id] = true
		starting_contents[cabinet_cell] = cabinet.contents.duplicate()
		_check(cabinet.sprite.texture.resource_path == DEMO.CABINET_FULL_PATH and cabinet.sprite.scale == Vector2.ONE and cabinet.sprite.offset == Vector2.ZERO, "Furniture always retains the original full cabinet body, native pixels and position")
		var shelf_count := 0
		for patch: Sprite2D in cabinet.empty_shelves:
			if not patch.visible and cabinet.sprite.texture.resource_path == DEMO.CABINET_FULL_PATH:
				shelf_count += 1
		_check(shelf_count == cabinet.contents.size(), "Occupied shelves show the actual randomly generated potion count")
		_check(not scene.call("_is_walkable", cabinet_cell) and not scene.call("_goblin_can_step", cabinet_cell), "Cabinets block movement")
	_check(seen.has(DEMO.ITEM_ID_HEALTH_POTION) and seen.has(DEMO.ITEM_ID_STRENGTH_POTION), "Seeded random cabinets distribute both registered potion types")
	_check(scene.get("_hero_magic") == 10 and scene.get("_stats_magic_label").text == "Магия: 10", "Magic starts at ten on the left panel")
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	for index in range(3):
		scene.call("_advance_world_turn")
	for cabinet_cell: Vector2i in cabinets:
		_check(cabinets[cabinet_cell].contents == starting_contents[cabinet_cell], "Turns never reroll an existing cabinet")
	var editor: CanvasLayer = scene.get("_editor_canvas")
	_check(not editor.visible, "Editor starts hidden")
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_E
	toggle.pressed = true
	scene.call("_unhandled_key_input", toggle)
	_check(editor.visible, "E opens the editor")
	var button_ids: Array[String] = []
	for button: Button in editor.find_children("*", "Button", true, false):
		if button.has_meta("object_type"):
			button_ids.append(button.get_meta("object_type"))
	for entry in CATALOG.definitions():
		_check(button_ids.has(entry.id) == not entry.get("procedural", false), "Editor automatically lists authored types and excludes procedural pickups: " + entry.id)
	scene.call("_unhandled_key_input", toggle)
	var cell: Vector2i = LEVEL.POTION_CABINETS[0].cell
	var cabinet: Dictionary = cabinets[cell]
	cabinet.contents.assign([DEMO.ITEM_ID_HEALTH_POTION, DEMO.ITEM_ID_STRENGTH_POTION])
	scene.set("_hero_cell", cell + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	var queue: RefCounted = scene.get("_turn_queue")
	var before: int = queue.current_turn
	scene.call("_try_move_hero", Vector2i.UP)
	_check(cabinet.contents == [DEMO.ITEM_ID_STRENGTH_POTION] and scene.get("_hero_cell") == cell + Vector2i.DOWN and queue.current_turn == before + 1, "Bumping takes exactly one bottle and spends one turn without moving")
	scene.call("_finish_hero_move", false)
	_check(queue.current_turn == before + 1, "Animation completion never duplicates loot or turns")
	scene.call("_try_move_hero", Vector2i.UP)
	scene.call("_finish_hero_move", false)
	var ids: Array = scene.get("_inventory_item_ids")
	_check(ids == [DEMO.ITEM_ID_GHOST_RING, DEMO.ITEM_ID_HEALTH_POTION, DEMO.ITEM_ID_STRENGTH_POTION] and cabinet.contents.is_empty(), "Both bottle types transfer to inventory")
	_check(cabinet.sprite.texture.resource_path == DEMO.CABINET_FULL_PATH and cabinet.empty_shelves.all(func(patch: Sprite2D) -> bool: return patch.visible), "Last potion clears all shelves without replacing the original cabinet")
	scene.set("_hero_strength", 0)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.UP)
	_check(cabinets.has(cell) and queue.current_turn == before, "Exhausted hero cannot break furniture")
	scene.set("_hero_strength", 10)
	scene.call("_try_move_hero", Vector2i.UP)
	_check(not cabinets.has(cell) and not cabinet.sprite.visible and queue.current_turn == before + 1 and scene.get("_hero_cell") == cell + Vector2i.DOWN, "Empty cabinet breaks immediately in one attack turn")
	_check(scene.call("_is_walkable", cell) and scene.call("_is_terrain_visible_through", cell) and scene.get("_editor_object_changes").is_empty(), "Destruction frees movement while preserving clear sight and the authored map")
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.UP)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_cell") == cell, "The next step enters the broken cabinet's floor")
	scene.set("_hero_strength", 3)
	scene.set("_hero_max_strength", 100)
	before = queue.current_turn
	_click_slot(scene, 1)
	_check(scene.get("_hero_strength") == 33 and scene.get("_hero_max_strength") == 100 and scene.get("_hero_magic") == 11, "Healing uses three times pre-use magic and then grants one magic")
	_check(ids == [DEMO.ITEM_ID_GHOST_RING, DEMO.ITEM_ID_STRENGTH_POTION] and queue.current_turn == before + 1, "Healing consumes one bottle and one action")
	scene.call("_finish_hero_move", false)
	scene.call("_add_inventory_item", load(DEMO.SWORD_PATH), DEMO.ITEM_ID_SWORD)
	before = queue.current_turn
	_click_slot(scene, 1)
	_check(scene.get("_strength_boost_turns") == 11 and scene.get("_hero_magic") == 12 and scene.get("_hero_strength") == 33, "Strength potion preserves own reserves, grants twelve magic and lasts eleven subsequent turns")
	_check(scene.get("_hero_strength_label").text == "71" and scene.get("_stats_strength_label").text == "Сила: 33/100×2+5", "Strength displays double own strength and preserve the permanent weapon bonus")
	_check(queue.current_turn == before + 1 and ids == [DEMO.ITEM_ID_GHOST_RING, DEMO.ITEM_ID_SWORD], "Boost drinking consumes one paced world action")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_strength_boost_turns") == 11, "Finishing the drink animation does not shorten the boost")
	for index in range(10):
		scene.call("_wait_hero_turn")
		scene.call("_finish_hero_move", false)
	_check(scene.get("_strength_boost_turns") == 1 and scene.get("_hero_strength_label").text == "71", "Boost stays active through the first ten subsequent turns")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_strength_boost_turns") == 0 and scene.get("_hero_strength_label").text == "38" and scene.get("_hero_strength") == 33, "Boost expires after exactly eleven turns without reducing reserves")
	_add_potion(scene, DEMO.ITEM_ID_STRENGTH_POTION)
	_click_slot(scene, 2)
	scene.call("_finish_hero_move", false)
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_add_potion(scene, DEMO.ITEM_ID_STRENGTH_POTION)
	_click_slot(scene, 2)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_magic") == 14 and scene.get("_strength_boost_turns") == 13 and scene.call("_strength_multiplier") == 2, "Reusing strength potion refreshes duration without stacking the multiplier")
	scene.set("_hero_strength", 0)
	var enemy_id: int = scene.call("_spawn_goblin", cell + Vector2i.DOWN, "weak_club")
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.DOWN)
	_check(queue.current_turn == before and scene.get("_strength_boost_turns") == 13 and COMBAT.effective_strength(0, 5, 2) == 0, "Blocked exhausted attack spends no buff turn and cannot use bonus or boost")
	scene.call("_remove_goblin", enemy_id)
	_add_potion(scene, DEMO.ITEM_ID_HEALTH_POTION)
	var picker: CanvasLayer = scene.get("_hero_picker")
	picker.call("toggle")
	_click_slot(scene, 2)
	_check(scene.get("_hero_magic") == 14 and ids.size() == 3, "Hero picker blocks potion actions")
	picker.call("toggle")
	_click_slot(scene, 2)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_strength") == 42 and scene.get("_hero_magic") == 15 and scene.get("_strength_boost_turns") == 12, "Healing recovers an exhausted hero and consumes one existing boost turn")
	_add_potion(scene, DEMO.ITEM_ID_HEALTH_POTION)
	scene.set("_hero_strength", 100)
	before = queue.current_turn
	_click_slot(scene, 2)
	_check(ids.size() == 3 and scene.get("_hero_magic") == 15 and queue.current_turn == before and scene.get("_strength_boost_turns") == 12, "Full-strength healing is a complete no-op including magic and duration")
	scene.set("_hero_strength", 99)
	_click_slot(scene, 2)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_strength") == 100 and scene.get("_hero_magic") == 16, "Healing caps at own maximum but still grants magic on use")
	for index in range(ids.size(), DEMO.INVENTORY_SIZE):
		scene.call("_add_inventory_item", load(DEMO.GHOST_RING_PATH), DEMO.ITEM_ID_GHOST_RING)
	var waiting_cell: Vector2i = LEVEL.POTION_CABINETS[1].cell
	var waiting: Dictionary = cabinets[waiting_cell]
	var contents: Array = waiting.contents.duplicate()
	scene.set("_hero_cell", waiting_cell + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.UP)
	_check(waiting.contents == contents and queue.current_turn == before and not scene.get("_is_moving"), "Full inventory neither takes loot nor spends a turn")
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_hero_magic") == 10 and scene.get("_strength_boost_turns") == 0 and scene.get("_inventory_item_ids") == [DEMO.ITEM_ID_GHOST_RING], "Restart resets magic, buff and inventory")
	_check(scene.get("_cabinets").has(cell) and not scene.get("_cabinets")[cell].contents.is_empty(), "Restart restores the broken authored cabinet with newly rolled contents")
	# A real held key takes two bottles, then breaks the emptied cabinet and walks in.
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	scene.get("_cabinets")[waiting_cell].contents.assign([DEMO.ITEM_ID_HEALTH_POTION, DEMO.ITEM_ID_STRENGTH_POTION])
	scene.set("_hero_cell", waiting_cell + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	var held := InputEventKey.new()
	held.keycode = KEY_W
	held.physical_keycode = KEY_W
	held.pressed = true
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	await create_timer(DEMO.HERO_MOVE_DURATION * 4.2).timeout
	held.pressed = false
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	_check(not scene.get("_cabinets").has(waiting_cell) and scene.get("_inventory").size() == 3 and scene.get("_hero_cell") == waiting_cell and scene.get("_turn_queue").current_turn == 4, "Held input loots twice, breaks once and steps in at animation pace")
	scene.call("_finish_hero_move", false)
	scene.free()
	if _errors.is_empty():
		print("POTION CHECK OK: native sprites, random stable contents, cabinet loot/destruction, magic, healing, exact buff duration, renewal, exhaustion, inventory, dynamic editor, held actions and restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _add_potion(scene: Node2D, item_id: String) -> void:
	scene.call("_add_inventory_item", load(CATALOG.definition(item_id).path), item_id)


func _click_slot(scene: Node2D, index: int) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene.call("_on_inventory_slot_gui_input", click, index)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
