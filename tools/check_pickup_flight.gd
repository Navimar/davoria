extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_cabinets()
	await _check_ground_and_rejections()
	await _check_grave()
	await _check_motion_and_reset()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("PICKUP FLIGHT OK: all cabinets, auto/manual floor loot, gold/crystal targets, grave, exact source/slot coordinates, native textures, immediate single awards and unchanged turns, failed pickup guards, straight tween, HUD/camera and clipped slots, nonblocking controls and clean restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _clear_flights(scene: Node2D) -> void:
	for effect: Node2D in scene.get("_pickup_flights").keys():
		effect.call("cancel")


func _ground(scene: Node2D, cell: Vector2i, id: String) -> Sprite2D:
	return scene.call("_add_item", load(CATALOG.definition(id).path), cell, 1.0, 10, id)


func _check_cabinets() -> void:
	for id: String in ["potion_cabinet", "tool_cabinet", "bookcase"]:
		var scene := await _fixture({ORIGIN: id})
		_check(scene.get("_pickup_flights").is_empty(), "Starting inventory creates no fake pickup animation")
		var cabinet: Dictionary = scene.get("_cabinets")[ORIGIN]
		var amount: int = cabinet.contents.size()
		var item_id: String = cabinet.contents[0]
		var transform: Transform2D = cabinet.sprite.get_global_transform_with_canvas()
		scene.call("_try_move_hero", Vector2i.RIGHT)
		var effects: Array = scene.get("_pickup_flights").keys()
		_check(effects.size() == 1 and scene.get("_inventory_item_ids").back() == item_id and cabinet.contents.size() == amount - 1 and scene.get("_turn_queue").current_turn == 1, "One successful cabinet pickup updates contents and starts one flight: " + id)
		if not effects.is_empty():
			var effect: Node2D = effects[0]
			_check(effect.get("texture") == load(CATALOG.definition(item_id).path) and effect.position.is_equal_approx(transform * cabinet.sprite.offset) and effect.get("_target") == scene.get("_inventory_slot_icons")[1], "The actual item flies from the rendered cabinet to its new inventory slot")
		scene.free()
	var scene := await _fixture({ORIGIN: "potion_cabinet"})
	for slot in range(scene.get("_inventory").size(), DEMO.INVENTORY_SIZE):
		_add(scene, "ghost_ring")
	var amount: int = scene.get("_cabinets")[ORIGIN].contents.size()
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_pickup_flights").is_empty() and scene.get("_cabinets")[ORIGIN].contents.size() == amount and scene.get("_turn_queue").current_turn == 0, "Full inventory neither flies nor loots a cabinet")
	scene.free()
	scene = await _fixture({ORIGIN: "empty_cabinet"})
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_pickup_flights").is_empty(), "Destroying empty furniture is not a pickup")
	scene.free()


func _check_ground_and_rejections() -> void:
	var scene := await _fixture({})
	var item := _ground(scene, HERO, "sword")
	item.set_meta("auto_pickup", false)
	scene.call("_try_pickup_item", HERO)
	_check(scene.get("_pickup_flights").is_empty(), "Manual-only floor loot does not animate on automatic retry")
	scene.call("_manual_pickup_floor", {"sprite": item, "cell": HERO})
	_check(scene.get("_pickup_flights").size() == 1 and scene.get("_inventory_item_ids").has("sword") and scene.get("_turn_queue").current_turn == 1, "Manual floor pickup starts one flight for one action")
	scene.call("_finish_hero_move", false)
	_clear_flights(scene)
	scene.call("_equip_inventory_item", scene.get("_inventory_item_ids").find("sword"))
	scene.call("_finish_hero_move", false)
	scene.call("_unequip_weapon")
	scene.call("_finish_hero_move", false)
	scene.call("_drop_inventory_item", scene.get("_inventory_item_ids").find("sword"))
	scene.call("_finish_hero_move", false)
	_check(scene.get("_pickup_flights").is_empty(), "Equip, unequip and drop create no pickup flights")
	for slot in range(scene.get("_inventory").size(), DEMO.INVENTORY_SIZE):
		_add(scene, "ghost_ring")
	item = _ground(scene, HERO, "health_potion")
	scene.call("_try_pickup_item", HERO)
	_check(scene.get("_pickup_flights").is_empty() and scene.call("_ground_items_at", HERO).has(item), "Full inventory leaves floor loot without an animation")
	for id: String in ["gold_small", "gold_medium", "gold_large", "strength_crystal"]:
		_clear_flights(scene)
		item = _ground(scene, HERO, id)
		var strength: int = scene.get("_hero_strength")
		var money: int = scene.get("_money")
		var turn: int = scene.get("_turn_queue").current_turn
		scene.call("_try_pickup_item", HERO)
		var effects: Array = scene.get("_pickup_flights").keys()
		_check(effects.size() == 1 and scene.get("_inventory").size() == DEMO.INVENTORY_SIZE and scene.get("_turn_queue").current_turn == turn, "Gold/crystals collect with a full inventory without extra actions")
		if not effects.is_empty():
			var target: Control = scene.get("_stats_strength_label") if id == "strength_crystal" else scene.get("_stats_money_label")
			_check(effects[0].get("_target") == target and effects[0].get("texture") == item.texture, "Gold flies to money and a crystal to strength, retaining its real sprite")
		scene.call("_try_pickup_item", HERO)
		_check(scene.get("_pickup_flights").size() == 1 and (scene.get("_hero_strength") == strength + 1 if id == "strength_crystal" else scene.get("_money") > money), "The same item cannot award or animate twice")
	_clear_flights(scene)
	item = _ground(scene, HERO, "cockatrice_corpse")
	scene.call("_manual_pickup_floor", {"sprite": item, "cell": HERO})
	_check(scene.get("_pickup_flights").is_empty() and scene.get("_encounter_prompt").is_open() and scene.call("_ground_items_at", HERO).has(item), "Cancelled dangerous-corpse pickup creates no flight")
	scene.free()


func _check_grave() -> void:
	var scene := await _fixture({})
	scene.get("_inventory").clear()
	scene.get("_inventory_item_ids").clear()
	_add(scene, "pickaxe")
	scene.set("_hero_cell", ORIGIN)
	scene.call("_record_hero_death", "grave")
	scene.call("_build_scene")
	await process_frame
	var grave: Sprite2D = scene.get("_previous_remains_sprite")
	var start: Vector2 = grave.get_global_transform_with_canvas() * grave.offset
	scene.call("_try_move_hero", Vector2i.RIGHT)
	var effects: Array = scene.get("_pickup_flights").keys()
	_check(effects.size() == 1 and scene.get("_previous_remains").item_id.is_empty() and scene.get("_inventory_item_ids").has("pickaxe") and effects[0].position.is_equal_approx(start), "Grave loot flies only after successful durable pickup")
	scene.free()


func _check_motion_and_reset() -> void:
	var scene := await _fixture({})
	var item := _ground(scene, ORIGIN, "health_potion")
	var start: Transform2D = item.get_global_transform_with_canvas()
	scene.call("_try_move_hero", Vector2i.RIGHT)
	var effect: Node2D = scene.get("_pickup_flights").keys()[0]
	_check(effect.position.is_equal_approx(start * item.offset) and effect.scale.is_equal_approx(start.get_scale().abs()) and effect.get_parent().layer > scene.get("_inventory_panel").get_parent().layer and effect.get("texture_filter") == CanvasItem.TEXTURE_FILTER_NEAREST, "Flight preserves source position/scale, nearest pixels and draws above masks/HUD")
	await process_frame
	await process_frame
	var tween: Tween = effect.get("_tween")
	tween.pause()
	tween.custom_step(DEMO.PICKUP_FLIGHT.DURATION * 0.5)
	var progress: float = effect.get("_progress")
	var origin: Vector2 = effect.get("_start_position")
	_check(progress > 0.0 and progress < 1.0 and effect.position.is_equal_approx(origin.lerp(effect.call("_destination"), progress)), "An ordinary tween moves along a straight line toward the HUD")
	var before := effect.position
	scene.call("_try_move_hero", Vector2i.DOWN)
	_check(scene.get("_hero_cell") == ORIGIN + Vector2i.DOWN and scene.get("_turn_queue").current_turn == 2 and effect.position.is_equal_approx(before), "Movement remains responsive and camera movement does not move the overlay")
	var clip: Control = scene.get("_inventory_scroll")
	clip.position += Vector2(20, 0)
	effect.call("_process", 0.0)
	_check(effect.position.is_equal_approx(origin.lerp(effect.call("_destination"), progress)), "Destination follows HUD layout changes during flight")
	clip.size = Vector2(50, 20)
	effect.call("_process", 0.0)
	var fallback := clip.get_global_transform_with_canvas() * (clip.size * 0.5)
	_check(effect.call("_destination").is_equal_approx(fallback), "A clipped slot uses visible backpack bounds without scrolling")
	tween.custom_step(DEMO.PICKUP_FLIGHT.DURATION)
	await process_frame
	_check(not is_instance_valid(effect) and scene.get("_pickup_flights").is_empty() and scene.get("_turn_queue").current_turn == 2, "Arrival frees only the visual, without another award or turn")
	for event in range(DEMO.MAX_PICKUP_FLIGHTS + 3):
		_ground(scene, scene.get("_hero_cell"), "gold_small")
		scene.call("_try_pickup_item", scene.get("_hero_cell"))
	_check(scene.get("_pickup_flights").size() == DEMO.MAX_PICKUP_FLIGHTS and scene.get("_turn_queue").current_turn == 2, "Rapid stacked pickups bound visual copies without dropping logical awards or adding turns")
	item = _ground(scene, scene.get("_hero_cell"), "magic_key")
	scene.call("_try_pickup_item", scene.get("_hero_cell"))
	var waiting: Array = scene.get("_pickup_flights").keys()
	scene.call("_build_scene")
	await process_frame
	await process_frame
	_check(scene.get("_pickup_flights").is_empty() and waiting.all(func(flight): return not is_instance_valid(flight)), "Restart cancels an effect even before its deferred tween starts")
	scene.free()
