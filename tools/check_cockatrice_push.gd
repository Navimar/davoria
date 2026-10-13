extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const HERO := Vector2i(10, 10)
var _errors: Array[String] = []
var _folders: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_notice()
	await _check_turn_resume()
	await _check_petrification()
	await _check_push_controls()
	await _check_target_input_mode()
	await _check_scroll_magic()
	await _check_speed()
	await _check_obstacles()
	await _check_cabinet_push()
	await _check_cabinet_obstacles()
	await _check_bomb_delivery()
	for folder in _folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("COCKATRICE AND PUSH OK: 5-15 strength, first logical sight notice, exact paused-turn resume, held-input safety, permanent lethal petrification, explicit new run, on-field WASD/Space targeting without a modal, GUI focus and input safety, adjacent-only directional push, cabinets with preserved loot/shelves and editor origins, obstacles and forced lethal immersion, native item, weighted loot/editor, bomb delivery/fuse/reward and source-only Save")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _fixture(objects: Dictionary = {}, terrain: Dictionary = {}) -> Node2D:
	var folder := "/private/tmp/davoria_cockatrice_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), _folders.size()]
	_folders.append(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			row += terrain.get(Vector2i(x, y), "." if x >= 2 and x <= 25 and y >= 2 and y <= 25 else "#")
		file.store_line(row)
	file.close()
	var map := objects.duplicate()
	map[HERO] = "hero_start"
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(template), map), "An isolated map is created")
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	return scene


func _check_notice() -> void:
	var barrier: Dictionary = {}
	for y in range(2, 26):
		barrier[Vector2i(12, y)] = "#"
	var scene := await _fixture({Vector2i(14, 10): "cockatrice"}, barrier)
	var notice: CanvasLayer = scene.get("_encounter_prompt")
	_check(not notice.is_open() and scene.get("_seen_encounters").is_empty(), "A cockatrice hidden by a wall does not trigger a notice")
	var enemy_id: int = scene.get("_goblins_by_cell")[Vector2i(14, 10)]
	var enemy: Dictionary = scene.get("_goblins")[enemy_id]
	_check(enemy.strength >= 5 and enemy.strength <= 15 and enemy.sprite.texture.resource_path == CATALOG.COCKATRICE_PATH and enemy.sprite.scale == Vector2.ONE, "Cockatrice uses native art and rolls 5-15 strength")
	scene.get("_held_move_keys").append(KEY_D)
	scene.call("_set_terrain_cell", Vector2i(12, 10), DEMO.TileType.FLOOR)
	scene.call("_update_fog")
	_check(notice.is_open() and scene.get("_held_move_keys").is_empty(), "First logical sight opens a modal and clears held movement")
	_check(notice.find_child("Title", true, false).text == "Кокатрис" and notice.find_child("Picture", true, false).texture.resource_path == CATALOG.COCKATRICE_PATH and notice.find_child("Description", true, false).text == tr(CATALOG.definition("cockatrice").encounter_text_key), "Notice shows the cockatrice picture and exact approved Astar text")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_wait_hero_turn")
	scene.call("_advance_world_turn")
	scene.call("_activate_inventory_slot", 0)
	_check(scene.get("_hero_cell") == HERO and scene.get("_turn_queue").current_turn == 0 and not scene.get("_is_ghost_mode"), "Movement, waiting, world clock and inventory are blocked during notice")
	var held := InputEventKey.new()
	held.physical_keycode = KEY_D
	held.keycode = KEY_D
	held.pressed = true
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	_key(scene, KEY_SPACE)
	await create_timer(DEMO.HERO_MOVE_DURATION * 1.2).timeout
	_check(scene.get("_hero_cell") == HERO and scene.get("_turn_queue").current_turn == 0, "A physically held direction never continues after closing the notice")
	held.pressed = false
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	_check(not notice.is_open() and scene.get("_turn_queue").current_turn == 0, "Acknowledging an idle notice spends no action")
	scene.call("_update_fog")
	var another: int = scene.call("_spawn_enemy", HERO + Vector2i.DOWN, "cockatrice")
	scene.call("_update_fog")
	_check(not notice.is_open(), "Another cockatrice in the same run does not repeat the warning")
	var rolled: Dictionary = {}
	for index in range(80):
		scene.call("_remove_goblin", another)
		another = scene.call("_spawn_enemy", HERO + Vector2i.DOWN, "cockatrice")
		var strength: int = scene.get("_goblins")[another].strength
		rolled[strength] = true
		_check(strength >= 5 and strength <= 15, "All cockatrice strength rolls stay in range")
	_check(rolled.has(5) and rolled.has(15), "Strength range includes both endpoints")
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_seen_encounters").is_empty(), "A new run resets first encounters while the creature remains hidden")
	scene.free()


func _check_turn_resume() -> void:
	var scene := await _fixture({HERO + Vector2i.RIGHT * 6: "cockatrice"})
	var enemy: Dictionary = scene.get("_goblins").values()[0]
	enemy.retaliates_only = true
	scene.call("_sync_active_goblins")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_encounter_prompt").is_open() and scene.get("_turn_queue").current_turn == 0 and not scene.get("_pending_world_action").is_empty(), "A move revealing the first cockatrice pauses its committed world action")
	scene.call("_finish_hero_move", false)
	_key(scene, KEY_SPACE)
	_check(scene.get("_hero_cell") == HERO + Vector2i.RIGHT and scene.get("_turn_queue").current_turn == 1 and scene.get("_pending_world_action").is_empty(), "Acknowledgement finishes the already committed action exactly once")
	scene.call("_on_encounter_acknowledged")
	_check(scene.get("_turn_queue").current_turn == 1, "Repeated acknowledgement cannot duplicate the world turn")
	scene.free()
	var other_cell := HERO + Vector2i.DOWN * 4
	scene = await _fixture({HERO + Vector2i.RIGHT * 6: "cockatrice", other_cell: "weak_club"})
	var other_id: int = scene.get("_goblins_by_cell")[other_cell]
	scene.set("_hero_cell", HERO + Vector2i.RIGHT)
	scene.call("_advance_world_turn")
	_check(scene.get("_encounter_prompt").is_open() and scene.get("_world_turn_pending") and scene.get("_goblins")[other_id].cell == other_cell, "A notice raised during the enemy queue pauses remaining enemies")
	_key(scene, KEY_SPACE)
	_check(not scene.get("_world_turn_pending") and scene.get("_turn_queue").current_turn == 1 and scene.get("_goblins")[other_id].cell != other_cell, "Remaining enemies resume in the same world turn")
	scene.free()


func _check_petrification() -> void:
	var cell := HERO + Vector2i.RIGHT
	var scene := await _fixture({cell: "cockatrice"})
	_key(scene, KEY_SPACE)
	var actor_id: int = scene.get("_goblins_by_cell")[cell]
	var enemy: Dictionary = scene.get("_goblins")[actor_id]
	enemy.retaliates_only = true
	enemy.strength = 15
	scene.set("_hero_strength", 1)
	scene.call("_sync_active_goblins")
	_force_roll(scene, 16, false, 1)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	await process_frame
	_check(scene.get("_petrified") and scene.get("_game_over") and scene.get("_hero_strength") == 0 and scene.get("_hero_strength_label").text == "Камень", "One successful retaliation kills by petrification even above the ordinary death threshold")
	_check(scene.get("_hero_water_material").get_shader_parameter("petrified") and scene.get("_encounter_prompt").find_child("Title", true, false).text == "Окаменение", "Hero and end-of-run portrait become stone")
	var turn: int = scene.get("_turn_queue").current_turn
	scene.call("_wait_hero_turn")
	scene.call("_try_move_hero", Vector2i.LEFT)
	scene.call("_activate_inventory_slot", 0)
	scene.call("_restart_after_death")
	await create_timer(0.25).timeout
	_check(scene.get("_petrified") and scene.get("_hero_cell") == HERO and scene.get("_turn_queue").current_turn == turn, "Petrification never expires or automatically resumes this run")
	_key(scene, KEY_SPACE)
	await process_frame
	_check(not scene.get("_petrified") and not scene.get("_game_over") and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 0 and scene.get("_encounter_prompt").find_child("Title", true, false).text == "Кокатрис", "Explicit restart creates a new run and resets its encounter notice")
	_key(scene, KEY_SPACE)
	actor_id = scene.get("_goblins_by_cell")[cell]
	enemy = scene.get("_goblins")[actor_id]
	enemy.strength = 1
	_force_roll(scene, 11, true, 10)
	scene.call("_resolve_combat", actor_id)
	_check(not scene.get("_petrified") and not scene.get("_goblins").has(actor_id) and scene.get("_hero_strength") == 11, "A successful player hit can kill the cockatrice normally and grant its reward")
	scene.free()


func _check_push_controls() -> void:
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var origin := HERO + direction
		var scene := await _fixture({origin: "magic_key"})
		_add(scene, "push_scroll")
		var slot: int = scene.get("_inventory_item_ids").find("push_scroll")
		scene.call("_activate_inventory_slot", slot)
		var target: Node2D = scene.get("_field_target")
		_check(target.is_active() and target.direction == Vector2i.ZERO and target.position == scene.call("_cell_center", HERO) and not scene.call("_any_prompt_is_open") and scene.find_child("PushDirectionPrompt", true, false) == null, "Using a scroll shows an on-field target centered on the hero, without a modal or default direction")
		_key(scene, KEY_SPACE)
		_check(target.is_active() and scene.get("_turn_queue").current_turn == 0 and scene.get("_hero_magic") == 10, "Space without a direction cannot consume a scroll or act")
		_key(scene, KEY_ESCAPE)
		_check(not target.is_active() and scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_hero_magic") == 10, "Cancelling hides the field target and retains the scroll")
		scene.call("_activate_inventory_slot", slot)
		var key: Key = {Vector2i.UP: KEY_W, Vector2i.LEFT: KEY_A, Vector2i.DOWN: KEY_S, Vector2i.RIGHT: KEY_D}[direction]
		_key(scene, key)
		_check(target.direction == direction and scene.get("_hero_cell") == HERO and scene.get("_held_move_keys").is_empty(), "WASD selects an adjacent target without movement or held-step leakage")
		_key(scene, KEY_SPACE)
		var earned_magic: int = scene.get("_hero_magic")
		scene.call("_confirm_field_target")
		_check(scene.get("_hero_magic") == earned_magic and scene.get("_stats_magic_label").text == "Магия: 11", "Completed scroll cannot reward twice, and the visible magic panel refreshes immediately")
		_check(not target.is_active() and not target.find_child("TargetHint", true, false).visible, "Successful casting hides both reticle and controls hint")
		scene.call("_finish_hero_move", false)
		var destination := origin + direction * 5
		_check(scene.get("_items_by_cell").has(destination) and not scene.get("_items_by_cell").has(origin) and scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_hero_magic") == 11, "Direction pushes exactly five cells for one scroll/action and grants one magic")
		_check(scene.get("_items_by_cell")[destination].get_meta("map_origin") == origin, "Pushed item retains its authored origin")
		scene.call("_save_loaded_chunks")
		var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
		_check(saved.objects.get(origin) == "magic_key" and not saved.objects.has(destination), "Save excludes runtime displacement")
		if direction == Vector2i.RIGHT:
			scene.get("_editor_canvas").visible = true
			scene.call("_select_editor_object", "erase")
			scene.call("_paint_selected_tile", destination)
			scene.call("_save_loaded_chunks")
			saved = OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
			_check(not scene.get("_items_by_cell").has(destination) and not saved.objects.has(origin), "Explicit editor erasure of a pushed item deletes its authored source")
		_check(scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == "push_scroll"), "Scroll is automatically present in the editor")
		scene.free()
	var image := Image.load_from_file(ProjectSettings.globalize_path(CATALOG.PUSH_SCROLL_PATH))
	_check(image != null and image.get_size() == Vector2i(64, 64), "Selected generated scroll has a native 64px canvas")
	_check(CATALOG.loot_pool("scrolls").count("push_scroll") == 1 and not CATALOG.loot_pool("tools").has("push_scroll") and not CATALOG.potion_pool().has("push_scroll"), "Scroll enters bookcases with weight one, outside tool and potion loot")


func _check_target_input_mode() -> void:
	var origin := HERO + Vector2i.RIGHT
	var scene := await _fixture({origin: "magic_key"})
	_add(scene, "bomb")
	_add(scene, "push_scroll")
	_add(scene, "health_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	scene.call("_finish_hero_move", false)
	var turn: int = scene.get("_turn_queue").current_turn
	var bomb: Dictionary = scene.get("_bombs_by_cell")[HERO]
	var fuse: int = bomb.turns
	scene.set("_hero_strength", 1)
	scene.set("_strength_boost_turns", 7)
	scene.get("_held_move_keys").append(KEY_D)
	var slot: int = scene.get("_inventory_item_ids").find("push_scroll")
	scene.call("_activate_inventory_slot", slot)
	var target: Node2D = scene.get("_field_target")
	_check(target.is_active() and scene.get("_held_move_keys").is_empty(), "Entering targeting clears an unfinished held movement")
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_input_key(scene, key, true)
		_input_key(scene, key, false)
		_check(target.direction == scene.call("_movement_direction_for_key", key) and scene.get("_hero_cell") == HERO, "Input-phase controls select all four field directions without taking a step")
	_input_key(scene, KEY_A, true, true)
	_check(target.direction == Vector2i.RIGHT, "Key echo does not change the target")
	_key(scene, KEY_H)
	_key(scene, KEY_E)
	_check(not scene.get("_hero_picker").is_open() and not scene.get("_editor_canvas").visible, "Target controls cannot open hero choice or editor")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_wait_hero_turn")
	scene.call("_advance_world_turn")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("health_potion"))
	scene.call("_activate_inventory_slot", 0)
	scene.call("_continue_held_movement")
	scene.get("_editor_canvas").visible = true
	scene.call("_select_editor_object", "erase")
	scene.call("_paint_selected_tile", origin)
	_check(scene.get("_hero_cell") == HERO and scene.get("_turn_queue").current_turn == turn and bomb.turns == fuse and scene.get("_hero_strength") == 1 and scene.get("_hero_magic") == 10 and scene.get("_strength_boost_turns") == 7 and scene.get("_inventory_item_ids").has("health_potion") and not scene.get("_is_ghost_mode") and scene.get("_items_by_cell").has(origin), "Target selection freezes actions, bomb fuse, potion durations, inventory and editor painting")
	scene.get("_editor_canvas").visible = false
	# Exercise the real input pipeline: a focused button normally accepts Space.
	var button: Button = scene.get("_hero_picker").find_child("ChooseHeroButton", true, false)
	button.grab_focus()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	scene.call("_finish_hero_move", false)
	_check(not target.is_active() and not scene.get("_hero_picker").is_open() and scene.get("_items_by_cell").has(origin + Vector2i.RIGHT * 5) and scene.get("_turn_queue").current_turn == turn + 1 and bomb.turns == fuse - 1, "Space casts through GUI focus exactly once, advances fuse once, and does not open the focused button")
	scene.free()

	scene = await _fixture({origin: "magic_key"})
	_add(scene, "push_scroll")
	# Opening from a moving hero first settles the accepted step and camera.
	scene.call("_try_move_hero", Vector2i.LEFT)
	turn = scene.get("_turn_queue").current_turn
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("push_scroll"))
	target = scene.get("_field_target")
	_check(target.is_active() and not scene.get("_is_moving") and target.position == scene.get("_hero").position and target.position == scene.get("_camera").position and scene.get("_turn_queue").current_turn == turn, "Starting a target during movement settles the old animation without spending another action")
	_key(scene, KEY_ESCAPE)
	_check(scene.get("_pending_target_slot") == -1 and not target.find_child("TargetHint", true, false).visible and scene.get("_inventory_item_ids").has("push_scroll"), "Escape clears target state and hint without consuming the item")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("push_scroll"))
	scene.call("_build_scene")
	await process_frame
	_check(not scene.call("_field_target_is_active") and scene.get("_pending_target_slot") == -1 and scene.get("_turn_queue").current_turn == 0, "New runs clear a pending field target")
	scene.free()


func _input_key(scene: Node2D, code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	scene.call("_input", event)


func _check_scroll_magic() -> void:
	# A future scroll using a potion-style effect must inherit the shared reward
	# without receiving it twice or using the increased magic for this effect.
	var entry := {"id": "fixture_heal_scroll", "name_key": "FIXTURE_HEAL_SCROLL", "category": "item", "path": CATALOG.HEALTH_POTION_PATH, "loot_group": "scrolls", "potion_effect": "heal"}
	CATALOG.definitions().append(entry)
	var scene := await _fixture()
	scene.set("_hero_strength", 1)
	scene.set("_hero_max_strength", 100)
	_add(scene, entry.id)
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find(entry.id))
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_magic") == 11 and scene.get("_hero_strength") == 21 and scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has(entry.id), "Any catalog scroll gains magic once through successful consumption while its effect uses pre-use magic")
	_add(scene, "health_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("health_potion"))
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_magic") == 12 and scene.get("_hero_strength") == 43 and scene.get("_turn_queue").current_turn == 2, "The common consumption reward preserves potion growth and pre-use healing")
	scene.free()
	CATALOG.definitions().erase(entry)


func _check_obstacles() -> void:
	var origin := HERO + Vector2i.RIGHT
	for obstacle in ["#", "D"]:
		var scene := await _fixture({origin: "magic_key", HERO + Vector2i.RIGHT * 5: "sword"}, {HERO + Vector2i.RIGHT * 4: obstacle})
		_check(scene.call("_push_adjacent", Vector2i.RIGHT) and scene.get("_items_by_cell").has(HERO + Vector2i.RIGHT * 3) and scene.get("_items_by_cell").has(HERO + Vector2i.RIGHT * 5), "Push stops before a wall/door and leaves distant items untouched")
		scene.free()
	var scene := await _fixture({origin: "magic_key", HERO + Vector2i.RIGHT * 2: "tool_cabinet"})
	_add(scene, "push_scroll")
	_cast(scene, Vector2i.RIGHT)
	_check(scene.get("_items_by_cell").has(origin) and scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_turn_queue").current_turn == 0 and scene.get("_field_target").is_active() and scene.get("_hero_magic") == 10, "An immediately blocked push retains its scroll, action and adjustable field target")
	scene.free()
	scene = await _fixture({HERO + Vector2i.RIGHT * 2: "sword"})
	_check(not scene.call("_push_adjacent", Vector2i.RIGHT) and scene.get("_items_by_cell").has(HERO + Vector2i.RIGHT * 2), "A target two cells away is unaffected when adjacent cell is empty")
	scene.free()
	scene = await _fixture({origin: "weak_club", HERO + Vector2i.RIGHT * 4: "medium_swordsman"})
	var id: int = scene.get("_goblins_by_cell")[origin]
	var blocker: int = scene.get("_goblins_by_cell")[HERO + Vector2i.RIGHT * 4]
	_check(scene.call("_push_adjacent", Vector2i.RIGHT) and scene.get("_goblins")[id].cell == HERO + Vector2i.RIGHT * 3 and scene.get("_goblins")[blocker].cell == HERO + Vector2i.RIGHT * 4 and scene.get("_actor_blocked_cells").has(HERO + Vector2i.RIGHT * 3) and not scene.get("_actor_blocked_cells").has(origin), "Pushed enemy stops before another creature and updates movement occupancy")
	scene.free()
	scene = await _fixture({origin: "weak_club"}, {HERO + Vector2i.RIGHT * 3: "~"})
	id = scene.get("_goblins_by_cell")[origin]
	_check(scene.call("_push_adjacent", Vector2i.RIGHT) and scene.get("_goblins").has(id) and scene.get("_goblins")[id].cell == origin + Vector2i.RIGHT * 5 and scene.get("_sinking_actors").is_empty() and scene.get("_hero_strength") == 10, "Forced land enemy flies across intermediate water and survives a dry landing")
	scene.free()
	var water: Dictionary = {}
	for distance in range(1, 5):
		water[HERO + Vector2i.DOWN * distance] = "~"
	scene = await _fixture({HERO + Vector2i.DOWN: "water_elemental"}, water)
	id = scene.get("_goblins_by_cell")[HERO + Vector2i.DOWN]
	_check(scene.call("_push_adjacent", Vector2i.DOWN) and not scene.get("_goblins").has(id) and scene.get("_sinking_actors").values().has(HERO + Vector2i.DOWN * 6), "Forced water elemental lands on the final dry cell, dies and dissolves into the ground")
	scene.free()


func _check_cabinet_push() -> void:
	var types := ["potion_cabinet", "tool_cabinet", "bookcase", "empty_cabinet"]
	var directions := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
	for index in range(types.size()):
		var type_id: String = types[index]
		var direction: Vector2i = directions[index]
		var origin := HERO + direction
		var destination := origin + direction * 5
		var scene := await _fixture({origin: type_id})
		var cabinet: Dictionary = scene.get("_cabinets")[origin]
		var loot: Array[String] = []
		if type_id != "empty_cabinet":
			var pool := CATALOG.loot_pool(CATALOG.definition(type_id).get("loot_group", "potions"))
			loot.assign([pool[0], pool[pool.size() - 1], pool[0]])
		cabinet.contents.assign(loot)
		scene.call("_update_cabinet_visual", origin)
		var sprite: Sprite2D = cabinet.sprite
		var texture: Texture2D = sprite.texture
		var shelves: Array[Vector2] = []
		var empty: Array[bool] = []
		for shelf: Sprite2D in cabinet.empty_shelves:
			shelves.append(shelf.position)
			empty.append(shelf.visible)
		_add(scene, "push_scroll")
		_cast(scene, direction)
		scene.call("_finish_hero_move", false)
		_check(not scene.get("_cabinets").has(origin) and scene.get("_cabinets").has(destination) and scene.get("_cabinets")[destination].sprite == sprite and sprite.position == scene.call("_cell_center", destination) and sprite.texture == texture and cabinet.contents == loot, "All cabinet types move five cells as the same container without rerolling contents")
		_check(scene.call("_is_walkable", origin) and not scene.call("_is_walkable", destination) and scene.call("_is_terrain_visible_through", destination) and sprite.get_meta("map_origin") == origin, "Moving furniture frees its old cell, blocks the new one, retains sight transparency and authored origin")
		for row in range(cabinet.empty_shelves.size()):
			_check(cabinet.empty_shelves[row].position == shelves[row] and cabinet.empty_shelves[row].visible == empty[row] and cabinet.empty_shelves[row].get_parent() == sprite, "Filled and empty shelf groups travel with their original body")
		_check(scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_hero_magic") == 11 and scene.get("_editor_object_changes").is_empty(), "Moving a cabinet costs one scroll/action, grants one magic and creates no authored map edit")
		scene.call("_save_loaded_chunks")
		var path := OBJECTS.path_for_chunks(scene.get("_chunk_path_template"))
		var saved := OBJECTS.read_map(path)
		_check(saved.objects.get(origin) == type_id and not saved.objects.has(destination), "Save excludes displaced cabinet position and contents")
		# Interact at the new location, including breaking an already empty cabinet.
		scene.set("_hero_cell", destination - direction)
		scene.call("_finish_hero_move", false)
		scene.call("_try_move_hero", direction)
		scene.call("_finish_hero_move", false)
		if loot.is_empty():
			_check(not scene.get("_cabinets").has(destination) and scene.call("_is_walkable", destination), "A pushed empty cabinet can be broken at its new cell")
		else:
			_check(scene.get("_inventory_item_ids").has(loot[0]) and cabinet.contents == loot.slice(1) and cabinet.empty_shelves[0].visible and scene.get("_cabinets")[destination].sprite == sprite, "A pushed full cabinet dispenses its existing loot and empties a whole shelf at the new cell")
		scene.call("_save_loaded_chunks")
		saved = OBJECTS.read_map(path)
		_check(saved.objects.get(origin) == type_id and not saved.objects.has(destination), "Save also excludes looting or breaking displaced cabinets")
		scene.call("_build_scene")
		await process_frame
		_check(scene.get("_cabinets").has(origin) and not scene.get("_cabinets").has(destination), "Restart restores the authored cabinet at its original position")
		for cell: Vector2i in scene.get("_items_by_cell").keys():
			scene.call("_remove_procedural_item", cell)
		_check(scene.call("_push_adjacent", direction), "The restored cabinet can be pushed again")
		scene.call("_finish_hero_move", false)
		scene.get("_editor_canvas").visible = true
		var edit: String = ["erase", "sword", "wall", "erase"][index]
		scene.call("_select_editor_object", edit)
		scene.call("_paint_selected_tile", origin if index == 3 else destination)
		scene.call("_save_loaded_chunks")
		saved = OBJECTS.read_map(path)
		_check(not saved.objects.has(origin) and not scene.get("_cabinets").has(destination), "Editor erase, replacement, incompatible terrain or erasing the authored origin remove the displaced %s and its source" % type_id)
		if edit == "sword":
			_check(saved.objects.get(destination) == "sword" and scene.get("_items_by_cell").has(destination), "Editor replacement of a displaced cabinet creates the requested object at its displayed cell")
		if edit == "wall":
			_check(scene.call("_terrain_type", destination) == DEMO.TileType.WALL, "Editor terrain replacement under a displaced cabinet remains an authored wall edit")
		scene.free()


func _check_cabinet_obstacles() -> void:
	var origin := HERO + Vector2i.RIGHT
	var barrier := HERO + Vector2i.RIGHT * 4
	var destination := barrier + Vector2i.LEFT
	for obstacle in ["#", "D", "bookcase", "weak_club", "magic_key"]:
		var objects := {origin: "potion_cabinet"}
		var terrain: Dictionary = {}
		if obstacle in ["#", "D"]:
			terrain[barrier] = obstacle
		else:
			objects[barrier] = obstacle
		var scene := await _fixture(objects, terrain)
		if obstacle == "weak_club":
			scene.get("_goblins").values()[0].retaliates_only = true
			scene.call("_sync_active_goblins")
		var cabinet: Dictionary = scene.get("_cabinets")[origin]
		_add(scene, "push_scroll")
		_cast(scene, Vector2i.RIGHT)
		scene.call("_finish_hero_move", false)
		_check(scene.get("_cabinets").has(destination) and scene.get("_cabinets")[destination].sprite == cabinet.sprite and not scene.get("_cabinets").has(origin), "Pushed cabinet stops before walls, doors, other cabinets, creatures and ground items")
		if obstacle == "bookcase":
			_check(scene.get("_cabinets")[barrier].type == "bookcase", "A farther cabinet stays in place instead of being pushed or overwritten")
		elif obstacle == "magic_key":
			_check(scene.get("_items_by_cell").has(barrier), "Furniture never covers or removes a loose item")
		elif obstacle == "weak_club":
			_check(scene.get("_goblins_by_cell").has(barrier), "A farther creature is not hit or pushed by furniture")
		scene.free()
	var scene := await _fixture({origin: "empty_cabinet", HERO + Vector2i.RIGHT * 2: "tool_cabinet"})
	_add(scene, "push_scroll")
	_cast(scene, Vector2i.RIGHT)
	_check(scene.get("_cabinets").has(origin) and scene.get("_cabinets").size() == 2 and scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_turn_queue").current_turn == 0 and scene.get("_field_target").is_active(), "An immediately blocked cabinet leaves both containers, the scroll, action and target intact")
	scene.free()

	scene = await _fixture({origin: "tool_cabinet"})
	scene.set("_hero_cell", barrier)
	scene.call("_finish_hero_move", false)
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	scene.call("_finish_hero_move", false)
	var bomb: Dictionary = scene.get("_bombs_by_cell")[barrier]
	scene.set("_hero_cell", HERO)
	scene.call("_finish_hero_move", false)
	_add(scene, "push_scroll")
	_cast(scene, Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_cabinets").has(destination) and scene.get("_bombs_by_cell").has(barrier) and bomb.turns == 2, "A pushed cabinet stops before an armed bomb while casting ticks its fuse once")
	scene.call("_explode_bomb", barrier)
	await process_frame
	scene.call("_finish_hero_move", false)
	_check(not scene.get("_cabinets").has(destination) and scene.get("_bombs_by_cell").is_empty() and scene.call("_is_walkable", destination), "An explosion destroys the displaced cabinet at its new cell and releases movement")
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
	_check(saved.objects.get(origin) == "tool_cabinet" and not saved.objects.has(destination), "Blasting a displaced cabinet does not change the authored map")
	scene.free()


func _check_speed() -> void:
	var scene := await _fixture({HERO + Vector2i.RIGHT: "magic_key"})
	_add(scene, "speed_potion")
	_add(scene, "push_scroll")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	scene.call("_finish_hero_move", false)
	_cast(scene, Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 1 and scene.get("_speed_actions_this_turn") == 1 and scene.get("_speed_boost_turns") == 10 and scene.get("_hero_magic") == 12, "Scroll occupies one half-action under speed and grants one magic without ticking the world")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 2 and scene.get("_speed_actions_this_turn") == 0 and scene.get("_speed_boost_turns") == 9, "Second fast action completes the scroll's ordinary paired world turn")
	scene.free()
	scene = await _fixture({HERO + Vector2i.RIGHT * 6: "cockatrice"})
	scene.get("_goblins").values()[0].retaliates_only = true
	scene.call("_sync_active_goblins")
	_add(scene, "speed_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_encounter_prompt").is_open() and scene.get("_speed_actions_this_turn") == 0, "First-sight notice pauses even a free fast action before its phase is committed")
	_key(scene, KEY_SPACE)
	_check(scene.get("_turn_queue").current_turn == 1 and scene.get("_speed_actions_this_turn") == 1 and scene.get("_speed_boost_turns") == 10, "Notice resumption retains speed phase and duration")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 2 and scene.get("_speed_boost_turns") == 9, "Speed's second action advances the world only once after notice")
	scene.free()


func _check_bomb_delivery() -> void:
	var target := HERO + Vector2i.RIGHT * 3
	var scene := await _fixture({target: "cockatrice"})
	_key(scene, KEY_SPACE)
	var enemy: Dictionary = scene.get("_goblins").values()[0]
	enemy.retaliates_only = true
	scene.call("_sync_active_goblins")
	_add(scene, "bomb")
	_add(scene, "push_scroll")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	scene.call("_finish_hero_move", false)
	var bomb: Dictionary = scene.get("_bombs_by_cell")[HERO]
	_check(not scene.call("_push_adjacent", Vector2i.UP) and scene.get("_bombs_by_cell").has(HERO), "Bomb underfoot is not selected; player must step aside")
	scene.call("_try_move_hero", Vector2i.LEFT)
	scene.call("_finish_hero_move", false)
	_check(bomb.turns == 2, "Stepping beside planted bomb spends one fuse tick")
	_cast(scene, Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_bombs_by_cell").has(target + Vector2i.LEFT) and not scene.get("_bombs_by_cell").has(HERO) and bomb.turns == 1 and enemy.cell == target, "Bomb stops immediately before cockatrice, retaining fuse; enemy itself is not pushed")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_goblins").is_empty() and scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10 and not scene.get("_petrified"), "Delivered bomb kills cockatrice at blast radius one without strength reward or contact petrification")
	scene.free()


func _add(scene: Node2D, id: String) -> void:
	scene.call("_add_inventory_item", load(CATALOG.definition(id).path), id)


func _cast(scene: Node2D, direction: Vector2i) -> void:
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("push_scroll"))
	_key(scene, {Vector2i.UP: KEY_W, Vector2i.LEFT: KEY_A, Vector2i.DOWN: KEY_S, Vector2i.RIGHT: KEY_D}[direction])
	_key(scene, KEY_SPACE)


func _key(scene: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	scene.call("_unhandled_key_input", event)


func _force_roll(scene: Node2D, total: int, player_hit: bool, player_power: int) -> void:
	var rng := RandomNumberGenerator.new()
	for seed in range(100):
		rng.seed = seed
		if (rng.randi_range(0, total - 1) < player_power) == player_hit:
			scene.get("_rng").seed = seed
			return
	_check(false, "A deterministic combat roll is available")


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
