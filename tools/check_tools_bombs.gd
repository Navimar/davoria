extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const HERO := Vector2i(5, 5)
var _errors: Array[String] = []
var _folders: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pool := CATALOG.loot_pool("tools")
	_check(pool.size() == 6 and pool.count("pickaxe") == 3 and pool.count("magic_key") == 2 and pool.count("bomb") == 1 and not pool.has("push_scroll"), "Tool weights are exactly 3/2/1, without containers, scrolls or potions")
	_check(CATALOG.potion_pool().size() == 8 and not CATALOG.potion_pool().has("bomb"), "Potion and tool loot remain separate")
	await _check_cabinet_and_pickaxe()
	await _check_explosion()
	await _check_speed_and_chain()
	await _check_death()
	for folder in _folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("TOOLS AND BOMBS OK: 3/2/1 loot, generic cabinet/editor, native icons, shelf depletion, pickaxe field targeting and terrain restriction, key compatibility, 3 world-turn fuse, blocked/modal actions, speed, 3x3 destruction and 100 damage, rewards, chain reaction, water, source-only Save and death/restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _fixture(objects: Dictionary, terrain: Dictionary = {}) -> Node2D:
	var folder := "/private/tmp/davoria_tools_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), _folders.size()]
	_folders.append(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			var cell := Vector2i(x, y)
			row += terrain.get(cell, "." if x >= 2 and x <= 20 and y >= 2 and y <= 20 else "#")
		file.store_line(row)
	file.close()
	var map := objects.duplicate()
	map[HERO] = "hero_start"
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(template), map), "Isolated tool map is created")
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	return scene


func _check_cabinet_and_pickaxe() -> void:
	var cabinet_cell := HERO + Vector2i.LEFT
	var wall := HERO + Vector2i.UP
	var door := HERO + Vector2i.DOWN
	var scene := await _fixture({cabinet_cell: "tool_cabinet"}, {wall: "#", door: "D"})
	var cabinet: Dictionary = scene.get("_cabinets")[cabinet_cell]
	_check(cabinet.contents.size() in [1, 2, 3] and cabinet.contents.all(func(id: String) -> bool: return CATALOG.loot_pool("tools").has(id)), "Tool cabinet rolls one to three weighted tools")
	var texture: Texture2D = cabinet.sprite.texture
	_check(texture.resource_path == CATALOG.TOOL_CABINET_PATH and texture.get_size() == Vector2(64, 64) and cabinet.sprite.scale == Vector2.ONE, "Tool cabinet uses its native generated asset")
	_check(not scene.call("_is_walkable", cabinet_cell) and scene.call("_is_terrain_visible_through", cabinet_cell), "Tool cabinet blocks movement while passing sight")
	for id in ["tool_cabinet", "pickaxe", "magic_key", "bomb"]:
		_check(scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == id), "All tools and their cabinet appear automatically in the editor")
	cabinet.contents.assign(["pickaxe", "magic_key", "bomb"])
	scene.call("_update_cabinet_visual", cabinet_cell)
	var ids: Array = scene.get("_inventory_item_ids")
	for id in ["pickaxe", "magic_key", "bomb"]:
		scene.call("_try_move_hero", Vector2i.LEFT)
		scene.call("_finish_hero_move", false)
		_check(ids.back() == id and scene.get("_inventory_slot_icons")[ids.size() - 1].texture.resource_path == CATALOG.definition(id).path, "Real looting preserves tool ID and GUI icon")
	_check(cabinet.contents.is_empty() and cabinet.sprite.texture == texture and cabinet.empty_shelves.all(func(patch: Sprite2D) -> bool: return patch.visible), "All shelves empty without changing the cabinet body")
	var queue: RefCounted = scene.get("_turn_queue")
	var before: int = queue.current_turn
	scene.call("_try_move_hero", Vector2i.UP)
	var prompt: CanvasLayer = scene.get("_door_prompt")
	_check(not prompt.is_open() and not scene.call("_field_target_is_active") and queue.current_turn == before, "Walking into a wall never invokes a pickaxe modal or auto-target")
	scene.call("_activate_inventory_slot", ids.find("pickaxe"))
	_check(scene.call("_field_target_is_active") and not prompt.is_open(), "Clicking a pickaxe opens the shared field target")
	scene.call("_wait_hero_turn")
	_key(scene, KEY_SPACE)
	_key(scene, KEY_ESCAPE)
	_check(queue.current_turn == before and ids.count("pickaxe") == 1 and scene.call("_terrain_type", wall) == DEMO.TileType.WALL, "Cancel and a missing target consume neither tool nor turn")
	scene.set("_hero_strength", 0)
	scene.call("_activate_inventory_slot", ids.find("pickaxe"))
	_key(scene, KEY_W)
	_key(scene, KEY_SPACE)
	scene.call("_finish_hero_move", false)
	_check(ids.count("pickaxe") == 0 and scene.call("_terrain_type", wall) == DEMO.TileType.FLOOR and scene.get("_hero_cell") == HERO and queue.current_turn == before + 1 and scene.get("_hero_magic") == 10, "Field targeting mines one wall for one pickaxe and action without magic gain, even with exhausted strength")
	scene.call("_consume_inventory_slot", ids.find("magic_key"))
	_add(scene, "pickaxe")
	before = queue.current_turn
	scene.call("_activate_inventory_slot", ids.find("pickaxe"))
	_key(scene, KEY_S)
	_key(scene, KEY_SPACE)
	_check(not prompt.is_open() and queue.current_turn == before and ids.count("pickaxe") == 1 and scene.call("_terrain_type", door) == DEMO.TileType.DOOR and scene.get("_field_target").get("_blocked"), "A pickaxe marks a door invalid and cannot substitute for a key")
	_key(scene, KEY_ESCAPE)
	_add(scene, "magic_key")
	scene.call("_try_move_hero", Vector2i.DOWN)
	_check(prompt.is_open() and prompt.find_child("DoorUnlockQuestion", true, false).text.contains("волшебный ключ"), "Key still presents its own door question after mining")
	_key(scene, KEY_W)
	_key(scene, KEY_SPACE)
	scene.call("_finish_hero_move", false)
	_check(scene.call("_terrain_type", door) == DEMO.TileType.FLOOR and ids.count("magic_key") == 0, "Key remains single-use and opens only the door")
	scene.call("_set_editor_map_object", Vector2i(7, 6), "bomb")
	scene.call("_set_editor_terrain_cell", Vector2i(14, 14), DEMO.TileType.WATER)
	scene.call("_save_loaded_chunks")
	var path: String = OBJECTS.path_for_chunks(scene.get("_chunk_path_template"))
	var saved := OBJECTS.read_map(path)
	_check(saved.objects[cabinet_cell] == "tool_cabinet" and saved.objects[Vector2i(7, 6)] == "bomb", "Save stores cabinet/item types, not generated contents")
	scene.call("_build_scene")
	await process_frame
	_check(scene.call("_terrain_type", wall) == DEMO.TileType.WALL and scene.call("_terrain_type", door) == DEMO.TileType.DOOR and scene.call("_terrain_type", Vector2i(14, 14)) == DEMO.TileType.WATER, "Save retains explicit editing but excludes mined walls and opened doors")
	_check(scene.get("_cabinets")[cabinet_cell].contents.size() in [1, 2, 3], "Restart refills the tool cabinet from its type")
	scene.free()


func _check_explosion() -> void:
	var catalog := CATALOG.definitions()
	catalog.append({"id": "fixture_blast_prop", "name_key": "FIXTURE_BLAST_PROP", "category": "prop", "path": CATALOG.CABINET_FULL_PATH, "blocks_movement": true})
	var scene := await _fixture({Vector2i(4, 4): "red_mushroom", Vector2i(6, 4): "skeletal_horse", Vector2i(4, 5): "tool_cabinet", Vector2i(4, 6): "magic_key", Vector2i(6, 6): "fixture_blast_prop", Vector2i(7, 6): "bomb"}, {Vector2i(5, 4): "#", Vector2i(5, 6): "D", Vector2i(7, 5): "~"})
	for actor: Dictionary in scene.get("_goblins").values():
		actor.retaliates_only = true
	scene.set("_hero_strength", 300)
	scene.set("_hero_max_strength", 300)
	var boss_id: int = scene.get("_goblins_by_cell")[Vector2i(6, 4)]
	var fungus_id: int = scene.get("_goblins_by_cell")[Vector2i(4, 4)]
	_add(scene, "bomb")
	var ids: Array = scene.get("_inventory_item_ids")
	var queue: RefCounted = scene.get("_turn_queue")
	scene.call("_activate_inventory_slot", ids.find("bomb"))
	scene.call("_finish_hero_move", false)
	_check(scene.get("_bombs_by_cell")[HERO].turns == 3 and scene.get("_bombs_by_cell")[HERO].label.text == "3" and ids.count("bomb") == 0 and queue.current_turn == 1 and scene.get("_hero_magic") == 10, "Planting spends one bomb/action, starts a visible three-turn fuse and grants no magic")
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", ids.find("bomb"))
	_check(ids.count("bomb") == 1 and queue.current_turn == 1, "A second bomb cannot stack in the occupied cell or spend an action")
	_wait(scene)
	_check(scene.get("_bombs_by_cell")[HERO].turns == 2, "First later world turn reduces fuse to two")
	_add(scene, "pickaxe")
	scene.call("_activate_inventory_slot", ids.find("pickaxe"))
	scene.call("_advance_world_turn")
	_check(queue.current_turn == 2 and scene.get("_bombs_by_cell")[HERO].turns == 2, "Field target selection freezes the bomb's world clock")
	_key(scene, KEY_SPACE)
	_key(scene, KEY_ESCAPE)
	_wait(scene)
	_check(scene.get("_bombs_by_cell")[HERO].turns == 1, "Second later turn reduces fuse to one")
	scene.call("_try_move_hero", Vector2i.DOWN)
	_check(queue.current_turn == 3 and scene.get("_bombs_by_cell")[HERO].turns == 1, "Blocked movement spends no bomb tick")
	_wait(scene)
	_check(scene.get("_bombs_by_cell").is_empty(), "Third later world turn detonates and removes the armed bomb")
	_check(scene.get("_hero_strength") == 200 and scene.get("_hero_max_strength") == 300 and scene.get("_goblins")[boss_id].strength == 100 and not scene.get("_goblins").has(fungus_id), "Blast deals one hundred own strength, leaves a two-hundred-strength boss alive without granting strength")
	_check(scene.call("_terrain_type", Vector2i(5, 4)) == DEMO.TileType.FLOOR and scene.call("_terrain_type", Vector2i(5, 6)) == DEMO.TileType.FLOOR and not scene.get("_cabinets").has(Vector2i(4, 5)) and not scene.get("_items_by_cell").has(Vector2i(4, 6)) and not scene.get("_props_by_cell").has(Vector2i(6, 6)), "Blast destroys walls, doors, furniture and items throughout the diagonal-inclusive three-by-three area")
	_check(scene.get("_items_by_cell").has(Vector2i(7, 6)) and scene.call("_terrain_type", Vector2i(7, 5)) == DEMO.TileType.WATER, "Outside objects and water remain intact")
	scene.call("_set_editor_map_object", Vector2i(14, 14), "pickaxe")
	scene.call("_set_editor_terrain_cell", Vector2i(15, 14), DEMO.TileType.WATER)
	scene.call("_save_loaded_chunks")
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_cabinets").has(Vector2i(4, 5)) and scene.get("_items_by_cell").has(Vector2i(4, 6)) and scene.get("_props_by_cell").has(Vector2i(6, 6)) and scene.call("_terrain_type", Vector2i(5, 4)) == DEMO.TileType.WALL, "Save/restart excludes bomb damage, destruction and armed state while restoring authored objects")
	_check(scene.get("_goblins")[scene.get("_goblins_by_cell")[Vector2i(6, 4)]].strength == 200, "Saved boss type restarts with its full strength")
	scene.free()
	catalog.pop_back()


func _check_speed_and_chain() -> void:
	var scene := await _fixture({})
	_add(scene, "speed_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	scene.call("_finish_hero_move", false)
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 1 and scene.get("_bombs_by_cell")[HERO].turns == 3, "Fast planting uses the first half-action without ticking the fuse")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_bombs_by_cell")[HERO].turns == 3, "The placement pair's world turn protects the new fuse")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	for action in range(5):
		_wait(scene)
	_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 5, "Six later fast actions equal three fuse ticks, and escaping beyond radius one prevents damage")
	scene.free()
	scene = await _fixture({})
	scene.set("_hero_strength", 500)
	for action in range(2):
		_add(scene, "bomb")
		scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
		scene.call("_finish_hero_move", false)
		scene.call("_try_move_hero", Vector2i.RIGHT)
		scene.call("_finish_hero_move", false)
	_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_hero_strength") == 400, "One explosion ignites the adjacent newer bomb; only the nearby blast damages the escaped hero")
	scene.free()


func _check_death() -> void:
	var scene := await _fixture({})
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	scene.call("_finish_hero_move", false)
	for turn in range(3):
		_wait(scene)
	await process_frame
	await process_frame
	_check(not scene.get("_game_over") and scene.get("_hero_strength") == 10 and scene.get("_bombs_by_cell").is_empty() and scene.get("_turn_queue").current_turn == 0, "Lethal self-blast uses ordinary automatic death restart and clears all armed bombs")
	scene.free()


func _add(scene: Node2D, id: String) -> void:
	_check(scene.call("_add_inventory_item", load(CATALOG.definition(id).path), id), "Tool/potion enters the live inventory")


func _wait(scene: Node2D) -> void:
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)


func _key(scene: Node2D, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	scene.call("_unhandled_key_input", event)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
