extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const RECORD := preload("res://scripts/previous_run.gd")
const HERO := Vector2i(5, 5)
var _errors: Array[String] = []
var _folders: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_deaths_and_reopen()
	await _check_inventory_and_priority()
	await _check_empty_and_drowning()
	await _check_destruction_and_source_save()
	await _check_statue_destruction_and_loot()
	_check_validation()
	for folder in _folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("PREVIOUS RUN OK: one grave/statue, death-time random carried item, durable one-time loot, full inventory and pickup priority, selected hero/stone appearance, last-death replacement, reopening, drowning, empty inventory, fog, blocking hero statue with locked loot, pickaxe/bomb/chain release once, persistence failure safety, editor-only map Save, isolated atomic record and culture text")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _fixture(objects: Dictionary = {}) -> Node2D:
	var folder := "/private/tmp/davoria_previous_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), _folders.size()]
	_folders.append(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		file.store_line("##" + ".".repeat(18) + "#".repeat(44) if y >= 2 and y <= 20 else "#".repeat(64))
	file.close()
	var map := objects.duplicate()
	map[HERO] = "hero_start"
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(template), map), "Isolated remains map is created")
	return await _open_scene(template)


func _open_scene(template: String) -> Node2D:
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	_clear_crystals(scene)
	return scene


func _clear_crystals(scene: Node2D) -> void:
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)


func _inventory(scene: Node2D, items: Array[String]) -> void:
	scene.get("_inventory").clear()
	scene.get("_inventory_item_ids").clear()
	for id in items:
		scene.call("_add_inventory_item", load(CATALOG.definition(id).path), id)
	scene.call("_refresh_inventory_panel")


func _saved(scene: Node2D) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.call("_previous_run_path")))
	data.cell = Vector2i(int(data.cell[0]), int(data.cell[1]))
	return data


func _die(scene: Node2D, cell: Vector2i, items: Array[String]) -> void:
	scene.set("_hero_cell", cell)
	_inventory(scene, items)
	scene.set("_hero_strength", -11)
	scene.call("_check_hero_death")
	await process_frame


func _check_deaths_and_reopen() -> void:
	var scene := await _fixture()
	var first := HERO + Vector2i.RIGHT
	var carried: Array[String] = ["sword", "health_potion", "pickaxe", "bomb"]
	await _die(scene, first, carried)
	var saved := _saved(scene)
	var loot: String = saved.item_id
	_check(saved.kind == "grave" and saved.cell == first and carried.has(loot), "Ordinary death records its exact cell and one actually carried item")
	_check(not saved.has("inventory") and not saved.has("runs") and not saved.has("history"), "Only a single minimal last-death record is persisted")
	var marker: Sprite2D = scene.get("_previous_remains_sprite")
	_check(is_instance_valid(marker) and marker.name == "PreviousHeroGrave" and marker.texture.resource_path == CATALOG.HERO_GRAVE_PATH and marker.texture.get_size() == Vector2(64, 64) and marker.scale == Vector2.ONE, "Next run spawns the native generated grave")
	var template: String = scene.get("_chunk_path_template")
	_check(scene.call("_previous_run_path") == template.get_base_dir().path_join("previous_run.json"), "Isolated maps never write the real game's previous run")
	scene.free()
	scene = await _open_scene(template)
	_check(_saved(scene).item_id == loot and scene.get("_previous_remains").item_id == loot, "Closing and reopening does not reroll the grave's item")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_inventory_item_ids").size() == 2 and scene.get("_inventory_item_ids").back() == loot and _saved(scene).item_id == "" and is_instance_valid(scene.get("_previous_remains_sprite")), "Entering grave takes exactly one item, marks it collected and keeps the memorial")
	scene.call("_try_pickup_item", first)
	_check(scene.get("_inventory_item_ids").size() == 2, "Rechecking same grave cannot duplicate its item")
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_previous_remains").item_id == "", "Restart cannot restore previously collected loot")
	var second := HERO + Vector2i.RIGHT * 3
	scene.set("_hero_cell", second)
	scene.call("_select_hero", 3)
	scene.get("_hero").flip_h = true
	_inventory(scene, ["push_scroll"])
	scene.call("_petrify_hero")
	saved = _saved(scene)
	_check(saved.kind == "statue" and saved.cell == second and saved.item_id == "push_scroll" and saved.hero_path == DEMO.HERO_VARIANTS[3].path and saved.flip_h, "Petrification saves the actual hero, facing and carried item immediately")
	_check(scene.get("_encounter_prompt").find_child("Description", true, false).text == "Вы стали каменной статуей.\n\nПодземелье получает +1 к уровню культуры.", "Petrification uses the new culture joke")
	scene.get("_encounter_prompt").call("_accept")
	await process_frame
	marker = scene.get("_previous_remains_sprite")
	_check(scene.get("_previous_remains").cell == second and marker.name == "PreviousHeroStatue" and marker.texture.resource_path == DEMO.HERO_VARIANTS[3].path and marker.flip_h and marker.material.get_shader_parameter("petrified"), "The newest statue replaces the older grave and uses the correct stone hero")
	_check(scene.find_children("PreviousHero*", "Sprite2D", true, false).size() == 1 and not scene.get("_items_by_cell").has(second), "Only one memorial is spawned and procedural crystals never cover it")
	scene.call("_set_fog_visibility", second, true, false)
	scene.call("_update_enemy_visibility")
	_check(not marker.visible and not marker.get_node("ContactShadow").is_visible_in_tree(), "Statue and its shadow are logically hidden by their own fog cell")
	scene.call("_select_hero", 4)
	scene.free()
	scene = await _open_scene(template)
	_check(scene.get("_previous_remains_sprite").texture.resource_path == DEMO.HERO_VARIANTS[3].path and scene.get("_previous_remains").item_id == "push_scroll", "Reopened statue keeps previous hero's appearance and original loot")
	_check(not scene.call("_is_walkable", second) and scene.call("_is_terrain_visible_through", second) and not scene.call("_enemy_can_step", second, "floor", false), "The previous hero's statue blocks hero and enemies while passing sight")
	scene.set("_hero_cell", second - Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_hero_cell") == second - Vector2i.RIGHT and scene.get("_turn_queue").current_turn == 0 and not scene.call("_push_adjacent", Vector2i.RIGHT), "Bumping or pushing cannot enter, move, attack or loot a hero statue")
	scene.set("_hero_cell", second)
	scene.call("_set_ghost_mode", true)
	scene.call("_try_pickup_item", second)
	scene.call("_manual_pickup_floor", {"remains": true, "cell": second})
	_check(_saved(scene).item_id == "push_scroll" and not scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_floor_entries").is_empty() and scene.get("_turn_queue").current_turn == 0, "Even forced overlap/ghost mode and stale manual entries cannot expose or collect trapped statue loot")
	scene.call("_set_ghost_mode", false)
	await _die(scene, HERO + Vector2i.DOWN, ["magic_key"])
	_check(_saved(scene).kind == "grave" and scene.find_children("PreviousHero*", "Sprite2D", true, false).size() == 1 and scene.get("_previous_remains").item_id == "magic_key", "A subsequent ordinary death replaces the statue with just one new grave")
	var files := DirAccess.get_files_at(template.get_base_dir())
	_check(files.count("previous_run.json") == 1 and not Array(files).any(func(name: String) -> bool: return name.contains(".tmp-")), "Replacement leaves one record and no temporary files")
	scene.free()


func _check_inventory_and_priority() -> void:
	var cell := HERO + Vector2i.RIGHT
	var scene := await _fixture({cell: "health_potion"})
	await _die(scene, cell, ["sword"])
	var filler: Array[String] = []
	for index in range(DEMO.INVENTORY_SIZE):
		filler.append("ghost_ring")
	_inventory(scene, filler)
	scene.set("_hero_cell", cell)
	scene.call("_try_pickup_item", cell)
	_check(_saved(scene).item_id == "sword" and scene.get("_items_by_cell").has(cell), "Full inventory preserves both grave loot and a ground item")
	scene.call("_consume_inventory_slot", 0)
	scene.call("_try_pickup_item", cell)
	_check(scene.get("_inventory_item_ids").size() == DEMO.INVENTORY_SIZE and scene.get("_inventory_item_ids").back() == "sword" and scene.get("_items_by_cell").has(cell) and _saved(scene).item_id == "", "With one free slot, last hero's item has pickup priority")
	scene.call("_consume_inventory_slot", 0)
	scene.call("_try_pickup_item", cell)
	_check(scene.get("_inventory_item_ids").back() == "health_potion" and not scene.get("_items_by_cell").has(cell), "Ordinary ground item remains collectible afterward")
	scene.free()


func _check_empty_and_drowning() -> void:
	var scene := await _fixture()
	await _die(scene, HERO + Vector2i.DOWN, [])
	_check(_saved(scene).item_id == "" and is_instance_valid(scene.get("_previous_remains_sprite")), "Death with an empty inventory creates an empty grave")
	scene.set("_hero_cell", HERO + Vector2i.DOWN)
	scene.call("_try_pickup_item", scene.get("_hero_cell"))
	_check(scene.get("_inventory_item_ids") == ["ghost_ring"], "Empty grave does not invent an item")
	scene.set("_hero_cell", HERO)
	scene.call("_set_terrain_cell", HERO, DEMO.TileType.WATER)
	scene.set("_was_in_water", true)
	scene.set("_hero_breath", 0)
	scene.set("_hero_strength", -10)
	_inventory(scene, ["water_breathing_potion"])
	scene.call("_advance_water_turn")
	await process_frame
	_check(_saved(scene).kind == "grave" and _saved(scene).cell == HERO and _saved(scene).item_id == "water_breathing_potion", "Drowning records ordinary remains before automatic restart")
	scene.free()


func _check_destruction_and_source_save() -> void:
	var scene := await _fixture()
	var cell := HERO + Vector2i.RIGHT * 3
	await _die(scene, cell, ["bomb"])
	scene.call("_save_loaded_chunks")
	var authored := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
	_check(authored.objects == {HERO: "hero_start"}, "Map Save never serializes grave/statue or their loot")
	for id in ["hero_grave", "hero_statue"]:
		_check(CATALOG.definition(id).procedural and not scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == id), "Runtime memorials are automatically excluded from authored placement")
	scene.set("_hero_cell", cell)
	_inventory(scene, ["bomb"])
	scene.call("_plant_bomb", 0)
	scene.set("_hero_strength", 300)
	scene.call("_explode_bomb", cell)
	_check(_saved(scene).destroyed and _saved(scene).item_id == "" and not is_instance_valid(scene.get("_previous_remains_sprite")), "Bomb destroys the old memorial and its remaining loot")
	scene.call("_build_scene")
	await process_frame
	_check(not is_instance_valid(scene.get("_previous_remains_sprite")), "Destroyed remains never reappear on reopen/restart")
	await _die(scene, HERO + Vector2i.DOWN, ["pickaxe"])
	scene.get("_editor_canvas").visible = true
	scene.call("_select_editor_object", "erase")
	scene.call("_paint_selected_tile", HERO + Vector2i.DOWN)
	scene.call("_save_loaded_chunks")
	_check(_saved(scene).destroyed and OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template"))).objects == {HERO: "hero_start"}, "Explicit editor erasure updates runtime remains without polluting map data")
	scene.free()


func _check_statue_destruction_and_loot() -> void:
	var cell := HERO + Vector2i.RIGHT * 3
	for method: String in ["pickaxe", "bomb", "chain", "empty"]:
		var scene := await _fixture()
		var item_id := "cockatrice_corpse" if method == "chain" else ("" if method == "empty" else "sword")
		scene.set("_hero_cell", cell)
		var carried: Array[String] = []
		if not item_id.is_empty():
			carried.append(item_id)
		_inventory(scene, carried)
		scene.call("_petrify_hero")
		scene.get("_encounter_prompt").call("_accept")
		await process_frame
		_clear_crystals(scene)
		_check(scene.call("_is_previous_hero_statue", cell) and not scene.call("_is_walkable", cell) and scene.call("_ground_items_at", cell).is_empty(), "Both occupied and empty hero statues block their cell with no exposed loot")
		scene.set("_hero_cell", cell - Vector2i.RIGHT)
		scene.call("_finish_hero_move", false)
		if method in ["pickaxe", "empty"]:
			var full: Array[String] = ["pickaxe"]
			for slot in range(DEMO.INVENTORY_SIZE - 1):
				full.append("ghost_ring")
			_inventory(scene, full)
			var existing: Sprite2D = scene.call("_add_item", load(CATALOG.MAGIC_KEY_PATH), cell, 1.0, 10, "magic_key")
			existing.set_meta("auto_pickup", false)
			scene.call("_activate_inventory_slot", 0)
			_key(scene, KEY_D)
			if method == "pickaxe":
				# A failed record write must leave both the statue and the tool intact.
				var saved_path: String = scene.call("_previous_run_path")
				scene.set("_remains_save_path", (scene.get("_chunk_path_template") % [0, 0]).path_join("record.json"))
				_key(scene, KEY_SPACE)
				scene.set("_remains_save_path", saved_path)
				_check(scene.call("_is_previous_hero_statue", cell) and scene.get("_inventory_item_ids")[0] == "pickaxe" and _saved(scene).item_id == item_id and scene.get("_turn_queue").current_turn == 0 and scene.call("_field_target_is_active"), "Failed durable removal neither drops loot nor spends the pickaxe/action")
			_key(scene, KEY_SPACE)
			scene.call("_finish_hero_move", false)
			_check(scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has("pickaxe") and scene.get("_inventory_item_ids").size() == DEMO.INVENTORY_SIZE - 1 and scene.call("_ground_items_at", cell).has(existing), "Pickaxe destroys one adjacent statue for one action even with a full inventory, preserving other floor items")
		else:
			var bombs: Array[String] = ["bomb"]
			if method == "chain":
				bombs.append("bomb")
			_inventory(scene, bombs)
			var origin := cell - Vector2i.RIGHT
			scene.call("_activate_inventory_slot", 0)
			scene.call("_finish_hero_move", false)
			if method == "chain":
				scene.set("_hero_cell", origin + Vector2i.UP)
				scene.call("_finish_hero_move", false)
				scene.call("_activate_inventory_slot", 0)
				scene.call("_finish_hero_move", false)
			scene.set("_hero_cell", HERO)
			scene.call("_finish_hero_move", false)
			scene.call("_explode_bomb", origin)
			_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_pending_enemy_loot").is_empty(), "All chained blasts finish before releasing the trapped item")
		var drops: Array = scene.call("_ground_items_at", cell).filter(func(item: Sprite2D): return item.get_meta("item_id", "") == item_id)
		_check(not scene.call("_is_previous_hero_statue", cell) and scene.call("_is_walkable", cell) and _saved(scene).destroyed and _saved(scene).item_id == "" and scene.get("_hero_strength") == 10 and scene.get("_hero_magic") == 10, "Destruction durably releases collision without giving strength or magic: " + method)
		_check(drops.size() == (0 if item_id.is_empty() else 1), "Exactly the saved item drops on the statue cell, surviving every blast: " + method)
		if method == "chain" and not drops.is_empty():
			_check(not drops[0].get_meta("auto_pickup", true) and not scene.get("_petrified"), "Releasing a dangerous corpse preserves manual pickup and does not touch the hero")
		var count: int = scene.call("_ground_items_at", cell).size()
		_check(not scene.call("_destroy_previous_remains", cell) and scene.call("_ground_items_at", cell).size() == count, "Repeated destruction cannot duplicate loot")
		scene.call("_save_loaded_chunks")
		_check(OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template"))).objects == {HERO: "hero_start"}, "Neither the statue nor released loot enter map Save")
		scene.call("_build_scene")
		await process_frame
		_clear_crystals(scene)
		_check(not is_instance_valid(scene.get("_previous_remains_sprite")) and scene.call("_ground_items_at", cell).is_empty(), "Restart cannot restore or redrop a destroyed statue")
		scene.free()


func _key(scene: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	scene.call("_unhandled_key_input", event)


func _check_validation() -> void:
	var folder: String = _folders[0]
	var path := folder.path_join("previous_run.json")
	var map_key := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(RECORD.read_record(path, map_key, [DEMO.HERO_PATH]).is_empty(), "Corrupt record is safely ignored")
	_check(RECORD.write_record(path, map_key, {"kind": "grave", "cell": HERO, "item_id": "removed_item", "hero_path": "removed_hero"}), "Record is written atomically")
	var parsed := RECORD.read_record(path, map_key, [DEMO.HERO_PATH])
	_check(parsed.item_id == "" and parsed.hero_path == DEMO.HERO_PATH and RECORD.read_record(path, "another_map", [DEMO.HERO_PATH]).is_empty(), "Removed items/hero paths are handled and records never leak between maps")


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
