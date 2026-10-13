extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_gold()
	await _check_operations()
	await _check_corpse()
	await _check_protection_and_statues()
	await _check_protected_combat_and_speed()
	await _check_blast_loot()
	await _check_statue_editor_origin()
	await _check_ui_and_flash()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("LOOT/EQUIPMENT OK: three pile tiers rolled at pickup, stacks, manual floor pickup/drop and turns, drag data, equipment-only bonuses, potion bottles, corpse warning/hazards/protection/expiry, no-strength petrification, transparent statues, pickaxe/bomb trapped loot, blast drops, save/restart, UI layout and potion flashes")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _ground(scene: Node2D, cell: Vector2i, type_id: String) -> Sprite2D:
	return scene.call("_add_item", load(CATALOG.definition(type_id).path), cell, 1.0, 10, type_id)


func _settle(scene: Node2D) -> void:
	scene.call("_finish_hero_move", false)


func _entry(scene: Node2D, item: Sprite2D) -> Dictionary:
	return {"sprite": item, "cell": scene.get("_hero_cell")}


func _check_gold() -> void:
	for pair in [["weak_club", "gold_small"], ["medium_swordsman", "gold_medium"], ["strong_guard", "gold_large"]]:
		var scene := await _fixture({ORIGIN: pair[0]})
		var id: int = scene.get("_goblins_by_cell")[ORIGIN]
		var rng: RandomNumberGenerator = scene.get("_rng")
		var state := rng.state
		scene.call("_defeat_enemy", id)
		var items: Array = scene.call("_ground_items_at", ORIGIN)
		_check(items.size() == 1 and items[0].get_meta("item_id") == pair[1] and rng.state == state and scene.get("_money") == 0, "Goblins drop the matching pile without rolling quantity at death: " + pair[0])
		var limits: Vector2i = CATALOG.definition(pair[1]).money_range
		_check(CATALOG.definition(pair[1]).category != "item", "Gold is currency, not an inventory item")
		for index in range(scene.get("_inventory").size(), DEMO.INVENTORY_SIZE):
			_add(scene, "ghost_ring")
		scene.call("_try_move_hero", Vector2i.RIGHT)
		_settle(scene)
		var money: int = scene.get("_money")
		_check(money >= limits.x and money <= limits.y and scene.get("_inventory").size() == DEMO.INVENTORY_SIZE and scene.call("_ground_items_at", ORIGIN).is_empty(), "Stepping onto gold rolls money despite full inventory")
		scene.call("_try_pickup_item", ORIGIN)
		_check(scene.get("_money") == money, "The same pile cannot pay twice")
		scene.call("_build_scene")
		_check(scene.get("_money") == 0, "Restart resets run money")
		scene.free()


func _check_operations() -> void:
	var scene := await _fixture({})
	_add(scene, "sword")
	_check(scene.call("_weapon_strength_bonus") == 0, "A carried sword supplies no strength")
	var slot: int = scene.get("_inventory_item_ids").find("sword")
	var payload: Variant = scene.call("_inventory_drag_payload", slot)
	scene.call("_receive_weapon_payload", payload)
	_check(scene.get("_equipped_weapon_id") == "sword" and scene.call("_weapon_strength_bonus") == 5 and scene.get("_turn_queue").current_turn == 1 and scene.get("_hero_strength_label").text == "15", "Dragging a sword equips it for one action and updates effective strength")
	_settle(scene)
	_check(not scene.call("_can_equip_payload", payload), "An old drag payload cannot equip the next item after mutation")
	_add(scene, "health_potion")
	for index in range(scene.get("_inventory").size(), DEMO.INVENTORY_SIZE):
		_add(scene, "magic_key")
	slot = scene.get("_inventory_item_ids").find("health_potion")
	scene.call("_equip_inventory_item", slot)
	_check(scene.get("_equipped_weapon_id") == "broken_bottle" and scene.call("_weapon_strength_bonus") == 2 and scene.get("_inventory").size() == DEMO.INVENTORY_SIZE and scene.get("_inventory_item_ids").has("sword") and not scene.get("_inventory_item_ids").has("health_potion") and scene.get("_hero_magic") == 10 and scene.get("_turn_queue").current_turn == 2, "Potion becomes a rose, swaps the old sword even in full inventory, without use or magic")
	_settle(scene)
	scene.call("_unequip_weapon")
	_check(scene.get("_equipped_weapon_id") == "broken_bottle" and scene.get("_turn_queue").current_turn == 2, "Full inventory blocks unequip without spending an action")
	scene.call("_drop_inventory_item", scene.get("_inventory_item_ids").find("sword"))
	_settle(scene)
	scene.call("_drop_equipped_weapon")
	_settle(scene)
	var items: Array = scene.call("_ground_items_at", HERO)
	_check(items.size() == 2 and items.all(func(item: Sprite2D): return not item.get_meta("auto_pickup")) and scene.get("_turn_queue").current_turn == 4 and scene.call("_weapon_strength_bonus") == 0, "Inventory/equipped drops coexist underfoot, each costs one action and disables auto pickup")
	scene.call("_try_move_hero", Vector2i.UP)
	_settle(scene)
	scene.call("_try_move_hero", Vector2i.DOWN)
	_settle(scene)
	_check(scene.call("_ground_items_at", HERO).size() == 2 and scene.get("_floor_entries").size() == 2, "Returning to dropped items leaves them for manual floor pickup")
	var before: int = scene.get("_turn_queue").current_turn
	scene.call("_manual_pickup_floor", _entry(scene, items[0]))
	_settle(scene)
	_check(scene.get("_inventory_item_ids").has("sword") and scene.call("_ground_items_at", HERO).size() == 1 and scene.get("_turn_queue").current_turn == before + 1, "Manual pickup collects exactly one stacked item and one action")
	scene.call("_manual_pickup_floor", _entry(scene, items[0]))
	_check(scene.get("_turn_queue").current_turn == before + 1, "Stale floor click cannot duplicate an already collected item")
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
	_check(saved.objects.size() == 1 and saved.objects[HERO] == "hero_start", "Save excludes ground drops, equipment and money")
	scene.free()


func _check_corpse() -> void:
	var scene := await _fixture({ORIGIN: "cockatrice"})
	scene.call("_defeat_enemy", scene.get("_goblins_by_cell")[ORIGIN])
	var corpse: Sprite2D = scene.call("_ground_items_at", ORIGIN)[0]
	_check(corpse.get_meta("item_id") == "cockatrice_corpse" and not corpse.get_meta("auto_pickup"), "Cockatrice leaves its native fallen corpse with auto pickup disabled")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_settle(scene)
	_check(not scene.get("_petrified") and not scene.get("_inventory_item_ids").has("cockatrice_corpse") and scene.get("_floor_entries").size() == 1, "Walking onto a corpse is safe and exposes it in floor UI")
	var before: int = scene.get("_turn_queue").current_turn
	scene.call("_manual_pickup_floor", _entry(scene, corpse))
	_check(scene.get("_encounter_prompt").is_open() and not scene.get("_petrified") and scene.get("_turn_queue").current_turn == before and scene.call("_ground_items_at", ORIGIN).has(corpse), "First corpse click warns and cancels collection without a turn")
	scene.get("_encounter_prompt").call("_accept")
	scene.call("_manual_pickup_floor", _entry(scene, corpse))
	_check(scene.get("_petrified") and scene.get("_turn_queue").current_turn == before and not scene.get("_inventory_item_ids").has("cockatrice_corpse"), "Second unprotected attempt permanently petrifies instead of picking up")
	scene.free()
	for operation in ["drop", "equip", "unequip"]:
		scene = await _fixture({})
		_add(scene, "cockatrice_corpse")
		if operation == "drop":
			scene.call("_drop_inventory_item", scene.get("_inventory_item_ids").find("cockatrice_corpse"))
		elif operation == "equip":
			scene.call("_equip_inventory_item", scene.get("_inventory_item_ids").find("cockatrice_corpse"))
		else:
			scene.set("_equipped_weapon_id", "cockatrice_corpse")
			scene.set("_equipped_weapon_texture", load(CATALOG.definition("cockatrice_corpse").path))
			scene.call("_unequip_weapon")
		_check(scene.get("_petrified") and scene.get("_turn_queue").current_turn == 0, "Unprotected corpse handling petrifies before performing " + operation)
		scene.free()


func _check_protection_and_statues() -> void:
	var scene := await _fixture({ORIGIN: "weak_club"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	scene.get("_goblins")[id].retaliates_only = true
	scene.call("_sync_active_goblins")
	_add(scene, "petrification_protection_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("petrification_protection_potion"))
	_settle(scene)
	_check(scene.get("_petrification_protection_turns") == 30 and scene.get("_hero_magic") == 11 and CATALOG.potion_pool().count("petrification_protection_potion") == 1, "Protection lasts 3 times pre-use magic, grants one magic and has generator weight one")
	scene.call("_petrify_hero")
	_check(not scene.get("_petrified"), "Active protection blocks petrification")
	var corpse := _ground(scene, HERO, "cockatrice_corpse")
	scene.get("_seen_encounters")["cockatrice_corpse"] = true
	scene.call("_manual_pickup_floor", _entry(scene, corpse))
	_settle(scene)
	scene.call("_equip_inventory_item", scene.get("_inventory_item_ids").find("cockatrice_corpse"))
	_settle(scene)
	_check(scene.get("_equipped_weapon_id") == "cockatrice_corpse" and scene.call("_weapon_strength_bonus") == 0 and scene.get("_petrification_protection_turns") == 28, "Protected corpse can be picked up and equipped for two actions with zero strength bonus")
	_force_hit(scene, id)
	var strength: int = scene.get("_hero_strength")
	scene.call("_resolve_combat", id)
	_check(not scene.get("_goblins").has(id) and scene.call("_is_enemy_statue", ORIGIN) and scene.get("_hero_strength") == strength and scene.get("_hero_max_strength") == 10, "A successful corpse hit petrifies an enemy without combat-learning reward")
	_check(not scene.call("_is_walkable", ORIGIN) and scene.call("_is_terrain_visible_through", ORIGIN) and scene.call("_ground_items_at", ORIGIN).is_empty() and not scene.get("_turn_queue").get("_positions").has(id), "Statue blocks movement, transmits sight, traps loot and removes AI")
	_add(scene, "pickaxe")
	var before: int = scene.get("_turn_queue").current_turn
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	_check(scene.call("_field_target_is_active") and not scene.get("_door_prompt").is_open(), "Pickaxe targets an adjacent statue on the field")
	_key(scene, KEY_D)
	_key(scene, KEY_SPACE)
	_settle(scene)
	_check(not scene.call("_is_enemy_statue", ORIGIN) and not scene.get("_inventory_item_ids").has("pickaxe") and scene.call("_ground_items_at", ORIGIN)[0].get_meta("item_id") == "gold_small" and scene.get("_turn_queue").current_turn == before + 1 and scene.get("_hero_strength") == strength, "A pickaxe destroys a statue in one turn and releases trapped gold without strength")
	scene.set("_petrification_protection_turns", 1)
	scene.call("_wait_hero_turn")
	_check(scene.get("_petrified") and scene.get("_petrification_protection_turns") == 0, "Protection expiration petrifies the hero still wielding a corpse")
	scene.free()
	scene = await _fixture({})
	_add(scene, "cockatrice_corpse")
	scene.set("_petrification_protection_turns", 1)
	scene.call("_wait_hero_turn")
	_settle(scene)
	_check(not scene.get("_petrified"), "An untouched corpse in inventory stays safe after protection expires")
	scene.free()


func _force_hit(scene: Node2D, id: int) -> void:
	var total: int = scene.get("_hero_strength") * scene.call("_strength_multiplier") + scene.call("_weapon_strength_bonus") + scene.get("_goblins")[id].strength
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(1000):
		rng.seed = seed_value
		if rng.randi_range(0, total - 1) < scene.get("_hero_strength"):
			rng.seed = seed_value
			break


func _check_blast_loot() -> void:
	var scene := await _fixture({ORIGIN: "cockatrice", SHORE: "strong_guard"})
	scene.call("_defeat_enemy", scene.get("_goblins_by_cell")[SHORE], true)
	var origin := ORIGIN
	var bomb: Sprite2D = scene.call("_add_actor", load(CATALOG.BOMB_PATH), origin, 1.0, 15)
	scene.get("_bombs_by_cell")[origin] = {"sprite": bomb, "fuse": 3}
	scene.set("_hero_cell", HERO + Vector2i.LEFT * 4)
	scene.call("_explode_bomb", origin)
	_check(scene.call("_ground_items_at", ORIGIN).size() == 1 and scene.call("_ground_items_at", ORIGIN)[0].get_meta("item_id") == "cockatrice_corpse" and scene.call("_ground_items_at", SHORE)[0].get_meta("item_id") == "gold_large" and not scene.call("_is_enemy_statue", SHORE), "Bomb releases statue loot and its killed cockatrice's corpse after clearing blast cells")
	_check(scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10 and scene.get("_floating_texts").is_empty() and scene.get("_pending_enemy_loot").is_empty(), "Bomb deaths grant no strength or popup; corpse and trapped loot release once")
	scene.free()


func _check_protected_combat_and_speed() -> void:
	var scene := await _fixture({ORIGIN: "cockatrice"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	scene.get("_goblins")[id].strength = 10
	scene.set("_petrification_protection_turns", 4)
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(1000):
		rng.seed = seed_value
		if rng.randi_range(0, 19) >= 10:
			rng.seed = seed_value
			break
	scene.call("_resolve_combat", id)
	_check(scene.get("_hero_strength") == 9 and not scene.get("_petrified") and scene.get("_petrification_protection_turns") == 4, "A protected cockatrice hit still deals ordinary damage but cannot petrify")
	scene.call("_remove_goblin", id)
	_add(scene, "speed_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	_settle(scene)
	_add(scene, "petrification_protection_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("petrification_protection_potion"))
	_settle(scene)
	_check(scene.get("_petrification_protection_turns") == 33 and scene.get("_hero_magic") == 12 and scene.get("_speed_actions_this_turn") == 1, "Protection activation in the first fast half uses pre-use magic")
	scene.call("_wait_hero_turn")
	_settle(scene)
	_check(scene.get("_petrification_protection_turns") == 33, "Protection activation is not shortened by the second fast half")
	scene.call("_wait_hero_turn")
	_settle(scene)
	scene.call("_wait_hero_turn")
	_settle(scene)
	_check(scene.get("_petrification_protection_turns") == 32, "Protection counts world turns, not speed's individual actions")
	_add(scene, "cockatrice_corpse")
	scene.call("_equip_inventory_item", scene.get("_inventory_item_ids").find("cockatrice_corpse"))
	_settle(scene)
	scene.call("_drop_equipped_weapon")
	_settle(scene)
	var corpse: Sprite2D = scene.call("_ground_items_at", HERO)[0]
	_check(corpse.get_meta("item_id") == "cockatrice_corpse" and not corpse.get_meta("auto_pickup") and not scene.get("_petrified"), "Protected dropping is safe and leaves the corpse for manual pickup")
	# The last-run random item includes the actual weapon, not only backpack contents.
	scene.get("_inventory").clear()
	scene.get("_inventory_item_ids").clear()
	scene.set("_equipped_weapon_id", "sword")
	scene.set("_equipped_weapon_texture", load(CATALOG.SWORD_PATH))
	scene.call("_record_hero_death", "grave")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.call("_previous_run_path")))
	_check(record.get("item_id") == "sword", "The death record can choose the equipped weapon")
	scene.free()


func _check_statue_editor_origin() -> void:
	var scene := await _fixture({ORIGIN: "weak_club"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	scene.call("_push_adjacent", Vector2i.RIGHT)
	scene.call("_finish_goblin_animations")
	var destination: Vector2i = scene.get("_goblins")[id].cell
	scene.call("_defeat_enemy", id, true)
	_check(scene.get("_props_by_cell")[destination].get_meta("map_origin") == ORIGIN, "Statue retains the displaced creature's authored origin")
	scene.call("_toggle_editor")
	scene.call("_select_editor_object", "erase")
	scene.call("_paint_selected_tile", destination)
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
	_check(not scene.call("_is_enemy_statue", destination) and not saved.objects.has(ORIGIN) and not saved.objects.has(destination) and scene.call("_ground_items_at", destination).is_empty() and scene.get("_hero_strength") == 10, "Editor erasure of a moved statue removes the source spawn without loot or combat rewards")
	scene.free()


func _check_ui_and_flash() -> void:
	var scene := await _fixture({})
	await process_frame
	await process_frame
	var panel: Control = scene.get("_inventory_panel")
	var stats: Control = scene.get("_stats_panel")
	_check(panel.position.y >= stats.position.y + stats.size.y and panel.position.y + panel.size.y <= scene.get_viewport_rect().size.y + 1 and scene.get("_inventory_slot_icons").size() == 32 and scene.get("_inventory_scroll").size.y > 300, "32-slot scrolling inventory, weapon and floor UI fit below separate stats")
	for effect_id in ["health_potion", "strength_potion", "water_breathing_potion", "speed_potion", "petrification_protection_potion"]:
		scene.set("_hero_strength", 1)
		_add(scene, effect_id)
		var slot: int = scene.get("_inventory_item_ids").find(effect_id)
		var node: Control = scene.get("_inventory_slot_icons")[slot].get_parent().get_parent()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(20, 20)
		event.pressed = true
		node.call("_gui_input", event)
		_check(scene.get("_inventory_item_ids").has(effect_id), "Press does not drink before possible drag: " + effect_id)
		event.pressed = false
		node.call("_gui_input", event)
		_check(not scene.get("_inventory_item_ids").has(effect_id) and scene.get("_hero_water_material").get_shader_parameter("potion_flash_strength") == 0.8, "Release drinks successfully and flashes the hero: " + effect_id)
		var tween: Tween = scene.get("_potion_flash_tween")
		tween.pause()
		tween.custom_step(0.25)
		_check(scene.get("_hero_water_material").get_shader_parameter("potion_flash_strength") == 0.0, "Potion flash clears without delaying actions")
		_settle(scene)
	scene.free()
