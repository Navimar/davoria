extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_water_placement_and_reuse()
	await _check_push_landing(false)
	await _check_push_landing(true)
	await _check_flyover()
	await _check_flooding_and_guards()
	await _check_chain()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("WATER BOMBS OK: water planting/final landing/flooding, immediate unarmed item and fuse removal, no explosion at last tick or fast half-action, manual pickup/reuse, existing loot, preserved flight, dry flyover/fuse, tick/explosion guards, no wet chain and source-only Save")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _settle(scene: Node2D) -> void:
	scene.call("_finish_hero_move", false)


func _wait(scene: Node2D) -> void:
	scene.call("_wait_hero_turn")
	_settle(scene)


func _plant(scene: Node2D) -> void:
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	_settle(scene)


func _floor_bomb(scene: Node2D, cell: Vector2i) -> Sprite2D:
	for item: Sprite2D in scene.call("_ground_items_at", cell):
		if item.get_meta("item_id", "") == "bomb":
			return item
	return null


func _check_water_placement_and_reuse() -> void:
	var scene := await _fixture({}, {HERO: "~"})
	var original: Sprite2D = scene.call("_add_item", load(CATALOG.MAGIC_KEY_PATH), HERO, 1.0, 10, "magic_key")
	original.set_meta("auto_pickup", false)
	_plant(scene)
	var bomb := _floor_bomb(scene, HERO)
	_check(is_instance_valid(bomb) and scene.get("_bombs_by_cell").is_empty() and scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has("bomb") and scene.get("_hero_magic") == 10, "Water placement spends one item/action and immediately creates an unarmed bomb")
	if not is_instance_valid(bomb):
		scene.free()
		return
	_check(bomb.find_child("Fuse", true, false) == null and bomb.z_index == 10 and bomb.scale == Vector2.ONE and not bomb.get_meta("auto_pickup") and scene.call("_ground_items_at", HERO).has(original) and scene.get("_floor_entries").size() == 2, "Extinguished bomb loses its fuse label, uses normal native item art and preserves existing floor loot")
	for turn in range(6):
		_wait(scene)
	_check(scene.get("_hero_strength") == 10 and scene.get("_bombs_by_cell").is_empty() and scene.call("_ground_items_at", HERO).has(bomb), "Waiting beyond the old fuse cannot detonate or auto-collect the extinguished bomb")
	var before: int = scene.get("_turn_queue").current_turn
	scene.call("_manual_pickup_floor", {"sprite": bomb, "cell": HERO})
	_settle(scene)
	_check(scene.get("_inventory_item_ids").count("bomb") == 1 and scene.get("_turn_queue").current_turn == before + 1 and scene.call("_ground_items_at", HERO) == [original], "Manual pickup recovers exactly one reusable bomb for one action")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_settle(scene)
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	_settle(scene)
	_check(scene.get("_bombs_by_cell").has(ORIGIN) and scene.get("_bombs_by_cell")[ORIGIN].turns == 3 and scene.get("_bombs_by_cell")[ORIGIN].label.text == "3", "Recovered bomb can be armed on dry land with a new full fuse")
	scene.free()


func _check_push_landing(fast: bool) -> void:
	var scene := await _fixture({}, {LANDING: "~"})
	scene.set("_hero_cell", ORIGIN)
	_settle(scene)
	_plant(scene)
	var sprite: Sprite2D = scene.get("_bombs_by_cell")[ORIGIN].sprite
	scene.call("_try_move_hero", Vector2i.LEFT)
	_settle(scene)
	if fast:
		_add(scene, "speed_potion")
		scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
		_settle(scene)
	else:
		_wait(scene)
	_check(scene.get("_bombs_by_cell")[ORIGIN].turns == 1, "The test reaches the last armed fuse tick")
	var before: int = scene.get("_turn_queue").current_turn
	var existing: Sprite2D = scene.call("_add_item", load(CATALOG.MAGIC_KEY_PATH), LANDING, 1.0, 10, "magic_key")
	_cast(scene)
	_check(scene.get("_bombs_by_cell").is_empty() and _floor_bomb(scene, LANDING) == sprite and sprite.find_child("Fuse", true, false) == null and scene.call("_ground_items_at", LANDING).has(existing), "Water landing extinguishes the same sprite before its last fuse tick, preserving destination loot")
	_check(scene.get("_hero_strength") == 10 and not sprite.get_meta("auto_pickup") and scene.get("_turn_queue").current_turn == before + (0 if fast else 1), "Extinguishing is immediate even in a speed half-action, with no extra turn or blast")
	var tween: Tween = scene.get("_push_tweens")[sprite].tween
	tween.pause()
	tween.custom_step(DEMO.HERO_MOVE_DURATION * 0.5)
	_check(sprite.position.x > scene.call("_cell_center", ORIGIN).x and sprite.position.x < scene.call("_cell_center", LANDING).x, "Disarming preserves the in-flight movement animation")
	_settle(scene)
	_check(sprite.position.is_equal_approx(scene.call("_cell_center", LANDING)), "The normal unarmed item completes its flight at the water cell")
	for turn in range(5):
		_wait(scene)
	_check(is_instance_valid(sprite) and scene.get("_bombs_by_cell").is_empty() and scene.get("_hero_strength") == 10, "An old wet fuse never resumes during later world turns")
	scene.free()


func _check_flyover() -> void:
	var scene := await _fixture({}, {SHORE: "~"})
	scene.set("_hero_cell", ORIGIN)
	_settle(scene)
	_plant(scene)
	scene.call("_try_move_hero", Vector2i.LEFT)
	_settle(scene)
	_cast(scene)
	_settle(scene)
	_check(scene.get("_bombs_by_cell").has(LANDING) and scene.get("_bombs_by_cell")[LANDING].turns == 1 and _floor_bomb(scene, LANDING) == null, "Flying over intermediate water keeps a bomb armed when its landing is dry")
	_wait(scene)
	_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_hero_strength") == 10, "Dry landing preserves the old fuse and detonates at its usual time")
	scene.free()


func _check_flooding_and_guards() -> void:
	for mode in ["terrain_change", "tick_guard", "explosion_guard"]:
		var scene := await _fixture({})
		var path: String = scene.get("_chunk_path_template") % [0, 0]
		var source := FileAccess.get_file_as_string(path)
		_plant(scene)
		if mode == "terrain_change":
			scene.call("_set_terrain_cell", HERO, DEMO.TileType.WATER)
		elif mode == "tick_guard":
			scene.get("_terrain_cells")[HERO] = DEMO.TileType.WATER
			scene.get("_bombs_by_cell")[HERO].turns = 1
			scene.get("_bombs_by_cell")[HERO].first_tick_turn = -1
			scene.call("_advance_bomb_turn")
		else:
			scene.get("_terrain_cells")[HERO] = DEMO.TileType.WATER
			scene.call("_explode_bomb", HERO)
		_check(scene.get("_bombs_by_cell").is_empty() and is_instance_valid(_floor_bomb(scene, HERO)) and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 1, "Water disarms without damage or an extra action: " + mode)
		_check(not scene.call("_extinguish_bomb", HERO) and scene.call("_ground_items_at", HERO).size() == 1, "Repeated extinguishing cannot duplicate a bomb")
		scene.call("_save_loaded_chunks")
		_check(FileAccess.get_file_as_string(path) == source and scene.get("_editor_changes").is_empty() and scene.get("_editor_object_changes").is_empty(), "Water disarming never enters source-map Save")
		scene.free()


func _check_chain() -> void:
	var victim := HERO + Vector2i.RIGHT * 2
	var scene := await _fixture({victim: "skeletal_horse"})
	var id: int = scene.get("_goblins_by_cell")[victim]
	scene.get("_goblins")[id].retaliates_only = true
	scene.call("_sync_active_goblins")
	_plant(scene)
	scene.set("_hero_cell", ORIGIN)
	_settle(scene)
	_plant(scene)
	scene.call("_set_terrain_cell", ORIGIN, DEMO.TileType.WATER)
	_check(is_instance_valid(_floor_bomb(scene, ORIGIN)), "The neighboring water bomb is an ordinary item before the blast")
	scene.set("_hero_cell", HERO + Vector2i.LEFT * 5)
	_settle(scene)
	scene.call("_explode_bomb", HERO)
	_check(scene.get("_bombs_by_cell").is_empty() and _floor_bomb(scene, ORIGIN) == null and scene.get("_goblins")[id].strength == 200 and scene.get("_hero_strength") == 10, "A nearby blast destroys the extinguished item but cannot ignite it or damage targets outside its own radius")
	scene.free()
