extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_exhaustion()
	await _check_strength_rewards()
	await _check_bomb_then_melee()
	await _check_magic_rewards()
	await _check_non_rewards()
	await _check_animation_and_reset()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("FLOATING TEXT OK: real rewards and held warning dedup, screen-space layer with fixed origin, no camera/fast-step/new-message jumps, rise/fade/free, stable reserved lanes, unchanged turns and clean restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _count(scene: Node2D, message: String) -> int:
	var count := 0
	for popup: Node2D in scene.get("_floating_texts"):
		if popup.get("text") == message:
			count += 1
	return count


func _clear(scene: Node2D) -> void:
	for popup: Node2D in scene.get("_floating_texts").keys():
		popup.call("cancel")


func _settle(scene: Node2D) -> void:
	scene.call("_finish_hero_move", false)


func _check_exhaustion() -> void:
	for own_strength: int in [0, -2]:
		var scene := await _fixture({ORIGIN: "weak_club", HERO + Vector2i.DOWN: "empty_cabinet"})
		var id: int = scene.get("_goblins_by_cell")[ORIGIN]
		var before: int = scene.get("_goblins")[id].strength
		scene.set("_hero_strength", own_strength)
		scene.set("_equipped_weapon_id", "sword")
		scene.call("_try_move_hero", Vector2i.RIGHT)
		var popup: Node2D = scene.get("_exhaustion_popup")
		_check(is_instance_valid(popup) and popup.get("text") == "Вы обессилены.\nНельзя атаковать.", "Exhausted attacks display the requested warning, including with a weapon bonus")
		if not is_instance_valid(popup):
			scene.free()
			continue
		var tween: Tween = popup.get("_tween")
		tween.pause()
		tween.custom_step(0.6)
		var alpha := popup.modulate.a
		for attempt in range(100):
			scene.call("_try_move_hero", Vector2i.RIGHT)
		_check(scene.get("_floating_texts").size() == 1 and scene.get("_exhaustion_popup") == popup and popup.modulate.a == alpha, "Repeated held-style attempts neither duplicate the warning nor restart its fade")
		_check(scene.get("_turn_queue").current_turn == 0 and scene.get("_hero_strength") == own_strength and scene.get("_goblins")[id].strength == before and not scene.get("_is_moving"), "The warning changes no combat, movement or turn state")
		tween.custom_step(0.6)
		await process_frame
		_check(not is_instance_valid(popup) and scene.get("_floating_texts").is_empty(), "The warning disappears and releases its node")
		scene.call("_try_move_hero", Vector2i.DOWN)
		_check(is_instance_valid(scene.get("_exhaustion_popup")) and scene.get("_cabinets").has(HERO + Vector2i.DOWN) and scene.get("_turn_queue").current_turn == 0, "An exhausted attempt to attack empty furniture also warns without a turn")
		scene.free()


func _check_strength_rewards() -> void:
	var scene := await _fixture({ORIGIN: "weak_club"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	scene.get("_goblins")[id].strength = 1
	scene.set("_hero_strength", 200)
	scene.set("_hero_max_strength", 200)
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(1000):
		rng.seed = seed_value
		if rng.randi_range(0, 200) < 200:
			rng.seed = seed_value
			break
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(not scene.get("_goblins").has(id) and scene.get("_hero_strength") == 201 and _count(scene, "+1 сила") == 1 and scene.get("_turn_queue").current_turn == 1, "A real victorious attack displays exactly one strength reward")
	_settle(scene)
	scene.call("_resolve_combat", id)
	_check(_count(scene, "+1 сила") == 1, "A removed enemy cannot trigger another reward label")
	scene.call("_add_item", load(CATALOG.STRENGTH_CRYSTAL_PATH), HERO, 1.0, 10, "strength_crystal")
	scene.call("_try_pickup_item", HERO)
	scene.call("_try_pickup_item", HERO)
	_check(scene.get("_hero_strength") == 202 and scene.get("_hero_max_strength") == 202 and _count(scene, "+1 сила") == 2 and scene.get("_turn_queue").current_turn == 1, "Crystal pickup displays one reward without duplicate pickup or extra turns")
	scene.free()


func _check_bomb_then_melee() -> void:
	var victim := HERO + Vector2i.RIGHT * 3
	var origin := HERO + Vector2i.RIGHT * 2
	var scene := await _fixture({victim: "skeletal_horse"})
	var id: int = scene.get("_goblins_by_cell")[victim]
	scene.get("_goblins")[id].strength = 101
	scene.get("_goblins")[id].retaliates_only = true
	scene.call("_sync_active_goblins")
	var bomb: Sprite2D = scene.call("_add_actor", load(CATALOG.BOMB_PATH), origin, 1.0, 15)
	scene.get("_bombs_by_cell")[origin] = {"sprite": bomb}
	scene.call("_explode_bomb", origin)
	_check(scene.get("_goblins")[id].strength == 1 and scene.get("_hero_strength") == 10 and scene.get("_floating_texts").is_empty(), "Bomb damage without a finishing hit grants no strength or popup")
	for step in range(2):
		scene.call("_try_move_hero", Vector2i.RIGHT)
		_settle(scene)
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(1000):
		rng.seed = seed_value
		if rng.randi_range(0, 10) < 10:
			rng.seed = seed_value
			break
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(not scene.get("_goblins").has(id) and scene.get("_hero_strength") == 11 and scene.get("_hero_max_strength") == 11 and _count(scene, "+1 сила") == 1, "Finishing ordinary hit still earns exactly one reward after earlier bomb damage")
	scene.free()


func _check_magic_rewards() -> void:
	for item_id: String in CATALOG.potion_ids():
		var scene := await _fixture({})
		scene.set("_hero_strength", 0)
		_add(scene, item_id)
		var slot: int = scene.get("_inventory_item_ids").find(item_id)
		scene.call("_activate_inventory_slot", slot)
		_settle(scene)
		_check(scene.get("_hero_magic") == 11 and _count(scene, "+1 магия") == 1 and _count(scene, "+1 сила") == 0, "Successful potion use displays one magic gain, never a false strength gain: " + item_id)
		scene.call("_activate_inventory_slot", slot)
		_check(_count(scene, "+1 магия") == 1, "A consumed potion cannot display another gain")
		scene.free()
	var scene := await _fixture({ORIGIN: "magic_key"})
	_add(scene, "push_scroll")
	var slot: int = scene.get("_inventory_item_ids").find("push_scroll")
	scene.call("_activate_inventory_slot", slot)
	_key(scene, KEY_SPACE)
	_key(scene, KEY_W)
	_key(scene, KEY_SPACE)
	_key(scene, KEY_ESCAPE)
	_check(scene.get("_floating_texts").is_empty() and scene.get("_hero_magic") == 10 and scene.get("_turn_queue").current_turn == 0, "No direction, failed targeting and cancellation never show a magic gain")
	scene.call("_activate_inventory_slot", slot)
	_key(scene, KEY_D)
	_key(scene, KEY_SPACE)
	_settle(scene)
	scene.call("_confirm_field_target")
	_check(_count(scene, "+1 магия") == 1 and scene.get("_hero_magic") == 11 and scene.get("_turn_queue").current_turn == 1, "Successful scroll use displays one magic gain and cannot repeat after confirmation")
	scene.free()


func _check_non_rewards() -> void:
	var removed := await _fixture({ORIGIN: "weak_club"})
	removed.call("_defeat_enemy", removed.get("_goblins_by_cell")[ORIGIN])
	_check(removed.get("_hero_strength") == 10 and removed.get("_hero_max_strength") == 10 and removed.get("_floating_texts").is_empty() and removed.call("_ground_items_at", ORIGIN).size() == 1, "Generic non-combat death releases loot without strength or its popup")
	removed.free()
	var scene := await _fixture({ORIGIN: "weak_club"})
	scene.call("_defeat_enemy", scene.get("_goblins_by_cell")[ORIGIN], true)
	_check(scene.get("_floating_texts").is_empty(), "Petrification earns no strength label")
	scene.call("_destroy_enemy_statue", ORIGIN)
	_check(scene.get("_floating_texts").is_empty(), "Releasing statue loot earns no strength label")
	scene.free()
	scene = await _fixture({})
	_add(scene, "health_potion")
	var slot: int = scene.get("_inventory_item_ids").find("health_potion")
	scene.call("_activate_inventory_slot", slot)
	_check(scene.get("_floating_texts").is_empty() and scene.get("_hero_magic") == 10, "Full-health refusal displays no reward")
	scene.call("_equip_inventory_item", slot)
	_settle(scene)
	_check(scene.get("_equipped_weapon_id") == "broken_bottle" and scene.get("_floating_texts").is_empty(), "A bottle weapon conversion earns no magic or strength label")
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	_settle(scene)
	_check(scene.get("_floating_texts").is_empty(), "Bomb planting itself earns no reward label")
	scene.free()


func _check_animation_and_reset() -> void:
	var scene := await _fixture({ORIGIN: "strength_crystal"})
	# Procedural crystals are intentionally excluded from authored map data.
	scene.call("_add_item", load(CATALOG.STRENGTH_CRYSTAL_PATH), ORIGIN, 1.0, 10, "strength_crystal")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	var popup: Node2D = scene.get("_floating_texts").keys()[0]
	var tween: Tween = popup.get("_tween")
	tween.pause()
	var hero_tween: Tween = scene.get("_hero_move_tween")
	hero_tween.pause()
	var screen_position := popup.position
	hero_tween.custom_step(DEMO.HERO_MOVE_DURATION * 0.5)
	_check(popup.position.is_equal_approx(screen_position) and popup.get_parent() is CanvasLayer and popup.get_parent().layer > scene.get("_view_mask_layer").layer and popup.get("_label").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Popup stays in its own screen-space layer while the hero and camera move")
	scene.call("_try_move_hero", Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	_check(popup.position.is_equal_approx(screen_position) and scene.get("_hero_cell") == ORIGIN + Vector2i.DOWN and scene.get("_turn_queue").current_turn == 2, "An interrupted step and camera snap cannot move existing text")
	var before_y := popup.global_position.y
	tween.custom_step(0.6)
	_check(popup.global_position.y < before_y and popup.modulate.a > 0.0 and popup.modulate.a < 1.0 and is_equal_approx(popup.get("_rise"), roundf(popup.get("_rise"))), "Notification rises by native pixels while fading")
	tween.custom_step(0.6)
	await process_frame
	_check(not is_instance_valid(popup) and scene.get("_floating_texts").is_empty() and scene.get("_turn_queue").current_turn == 2, "Completed effect frees its node without changing world turns")
	_settle(scene)
	# Large bursts keep readable recent messages on screen and preserve magic
	# while many individual strength rewards arrive in the same frame.
	var magic: Node2D = scene.call("_show_floating_text", "+1 магия", Color.WHITE)
	var magic_position := magic.position
	for event in range(30):
		scene.call("_gain_hero_strength", 1)
	_check(scene.get("_floating_texts").size() == DEMO.MAX_FLOATING_TEXTS and _count(scene, "+1 магия") == 1, "Rapid rewards remain bounded and do not crowd out another reward type")
	_check(magic.position.is_equal_approx(magic_position), "New messages never reflow or move an older notification")
	scene.call("_show_exhaustion_warning")
	for effect: Node2D in scene.get("_floating_texts"):
		var bounds := Rect2(effect.position + effect.get("_label").position, effect.get("_label").size)
		_check(bounds.position.y > 0.0, "Burst notifications stay within the visible screen")
		for other: Node2D in scene.get("_floating_texts"):
			if other == effect:
				continue
			var other_bounds := Rect2(other.position + other.get("_label").position, other.get("_label").size)
			_check(not bounds.intersects(other_bounds), "Screen lanes reserve enough space for both one-line rewards and two-line warnings")
	var effects: Array = scene.get("_floating_texts").keys()
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_floating_texts").is_empty() and scene.get("_exhaustion_popup") == null and effects.all(func(effect): return not is_instance_valid(effect)), "Restart cancels all text effects without carrying them into the new run")
	scene.free()
