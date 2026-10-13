extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_creature_types()
	await _check_directions_and_range()
	await _check_obstacles()
	await _check_stacks_and_loot()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("CORPSE PUSH OK: every creature type, four directions, immediate contact and exact range, first victim only, no strength/combat/self-petrification, one scroll/action/magic, preserved corpse/stacks/trapped loot, blockers, ordinary items, water, save/restart and animations")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _cast_direction(scene: Node2D, direction: Vector2i) -> void:
	_add(scene, "push_scroll")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("push_scroll"))
	_key(scene, {Vector2i.UP: KEY_W, Vector2i.LEFT: KEY_A, Vector2i.DOWN: KEY_S, Vector2i.RIGHT: KEY_D}[direction])
	_key(scene, KEY_SPACE)


func _check_creature_types() -> void:
	var victim := HERO + Vector2i.RIGHT * 3
	for definition: Dictionary in CATALOG.definitions():
		if definition.category != "enemy":
			continue
		var terrain := {victim: "~", SHORE: "~"} if definition.get("requires_water", false) else {}
		var scene := await _fixture({ORIGIN: "cockatrice_corpse", victim: definition.id}, terrain)
		var id: int = scene.get("_goblins_by_cell")[victim]
		var corpse: Sprite2D = scene.call("_ground_items_at", ORIGIN)[0]
		var rng: RandomNumberGenerator = scene.get("_rng")
		var rng_state := rng.state
		_cast(scene)
		_check(not scene.get("_goblins").has(id) and scene.call("_is_enemy_statue", victim) and not scene.get("_turn_queue").get("_positions").has(id) and not scene.get("_actor_blocked_cells").has(victim), "Corpse contact petrifies and removes AI/queue/live occupancy: " + definition.id)
		_check(scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10 and not scene.get("_petrified") and rng.state == rng_state, "Remote corpse hit is deterministic, gives no strength and cannot petrify its caster: " + definition.id)
		_check(scene.get("_hero_magic") == 11 and scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has("push_scroll") and not scene.call("_field_target_is_active"), "Hit spends exactly one scroll/action and earns normal scroll magic")
		_check(scene.call("_ground_items_at", victim) == [corpse] and scene.call("_ground_items_at", ORIGIN).is_empty() and not corpse.get_meta("auto_pickup") and not scene.get("_seen_encounters").has("cockatrice_corpse"), "Corpse remains intact without auto pickup or the manual handling warning")
		var statue: Sprite2D = scene.get("_props_by_cell")[victim]
		_check(statue.material.get_shader_parameter("petrified") and not scene.call("_is_walkable", victim) and scene.call("_is_terrain_visible_through", victim), "Impact uses the existing solid, sight-transparent stone statue")
		scene.call("_finish_hero_move", false)
		_check(corpse.position.is_equal_approx(scene.call("_cell_center", victim)) and scene.get("_turn_queue").current_turn == 1, "Flight finishes at the contact cell without another action")
		scene.call("_save_loaded_chunks")
		var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
		_check(saved.objects.get(ORIGIN) == "cockatrice_corpse" and saved.objects.get(victim) == definition.id and scene.get("_editor_object_changes").is_empty(), "Gameplay collision does not replace authored spawns in Save")
		scene.free()


func _check_directions_and_range() -> void:
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		for distance: int in [1, DEMO.PUSH_DISTANCE]:
			var origin := HERO + direction
			var victim := origin + direction * distance
			var scene := await _fixture({origin: "cockatrice_corpse", victim: "weak_club"})
			_cast_direction(scene, direction)
			_check(scene.call("_is_enemy_statue", victim) and scene.call("_ground_items_at", victim).size() == 1 and scene.get("_turn_queue").current_turn == 1, "Contact works in all directions, including the next cell and exact maximum range")
			scene.free()
	var distant := LANDING + Vector2i.RIGHT
	var scene := await _fixture({ORIGIN: "cockatrice_corpse", distant: "weak_club"})
	var id: int = scene.get("_goblins_by_cell")[distant]
	scene.get("_goblins")[id].retaliates_only = true
	scene.call("_sync_active_goblins")
	_cast(scene)
	_check(scene.get("_goblins").has(id) and not scene.call("_is_enemy_statue", distant) and scene.call("_ground_items_at", LANDING).size() == 1, "A creature beyond five cells from the corpse is not hit")
	scene.free()
	# Ordinary thrown items still stop before creatures and do not petrify them.
	var victim := HERO + Vector2i.RIGHT * 3
	scene = await _fixture({ORIGIN: "magic_key", victim: "weak_club"})
	id = scene.get("_goblins_by_cell")[victim]
	scene.get("_goblins")[id].retaliates_only = true
	scene.call("_sync_active_goblins")
	_cast(scene)
	_check(scene.get("_goblins").has(id) and not scene.call("_is_enemy_statue", victim) and scene.call("_ground_items_at", SHORE)[0].get_meta("item_id") == "magic_key", "A pushed ordinary item retains its usual collision behavior")
	scene.free()


func _check_obstacles() -> void:
	var victim := HERO + Vector2i.RIGHT * 4
	for blocker in ["wall", "door", "earth", "empty_cabinet", "magic_key", "statue"]:
		var terrain: Dictionary = {}
		var objects := {ORIGIN: "cockatrice_corpse", victim: "weak_club"}
		match blocker:
			"wall": terrain[SHORE] = "#"
			"door": terrain[SHORE] = "D"
			"earth": terrain[SHORE] = "%"
			"statue": objects[SHORE] = "weak_club"
			_: objects[SHORE] = blocker
		var scene := await _fixture(objects, terrain)
		var id: int = scene.get("_goblins_by_cell")[victim]
		if blocker == "statue":
			scene.call("_defeat_enemy", scene.get("_goblins_by_cell")[SHORE], true)
		_cast(scene)
		_check(scene.get("_goblins").has(id) and not scene.call("_is_enemy_statue", victim) and scene.call("_ground_items_at", ORIGIN).size() == 1 and scene.get("_turn_queue").current_turn == 0 and scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_hero_magic") == 10 and scene.get("_field_target").get("_blocked"), "An intervening obstacle prevents corpse contact without spending the scroll: " + blocker)
		scene.free()


func _check_stacks_and_loot() -> void:
	var victim := HERO + Vector2i.RIGHT * 3
	var behind := victim + Vector2i.RIGHT
	var scene := await _fixture({ORIGIN: "cockatrice_corpse", victim: "weak_club", behind: "strong_guard"})
	scene.get("_goblins")[scene.get("_goblins_by_cell")[behind]].retaliates_only = true
	scene.call("_sync_active_goblins")
	var corpse: Sprite2D = scene.call("_ground_items_at", ORIGIN)[0]
	var extra: Sprite2D = scene.call("_add_item", load(CATALOG.definition("cockatrice_corpse").path), ORIGIN, 1.0, 10, "cockatrice_corpse")
	var existing: Sprite2D = scene.call("_add_item", load(CATALOG.MAGIC_KEY_PATH), victim, 1.0, 10, "magic_key")
	_cast(scene)
	_check(scene.call("_is_enemy_statue", victim) and scene.get("_goblins_by_cell").has(behind) and not scene.call("_is_enemy_statue", behind) and scene.get("_props_by_cell").size() == 1, "Corpse stops at its first victim; the statue blocks another corpse and protects the next creature")
	_check(scene.call("_ground_items_at", victim).has(existing) and scene.call("_ground_items_at", victim).has(extra) and scene.call("_ground_items_at", SHORE).has(corpse), "Stacked corpses and existing victim-cell loot are preserved without overwriting")
	_check(scene.get("_props_by_cell")[victim].get_meta("trapped_loot").item_id == "gold_small" and scene.get("_hero_strength") == 10 and scene.get("_hero_magic") == 11 and scene.get("_turn_queue").current_turn == 1, "One spell petrifies without learning strength and keeps the goblin's gold trapped")
	scene.call("_destroy_enemy_statue", victim)
	_check(scene.call("_ground_items_at", victim).size() == 3 and scene.call("_ground_items_at", victim).any(func(item: Sprite2D): return item.get_meta("item_id") == "gold_small") and scene.get("_hero_strength") == 10, "Destroying the statue releases gold alongside the intact corpse and original loot")
	scene.call("_build_scene")
	await process_frame
	_check(not scene.call("_is_enemy_statue", victim) and scene.get("_goblins_by_cell").has(victim) and scene.call("_ground_items_at", ORIGIN)[0].get_meta("item_id") == "cockatrice_corpse", "Restart restores authored living creatures and corpse placement")
	scene.free()
