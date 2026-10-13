extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_supplied_poses()
	await _check_delayed_turn()
	await _check_speed_and_repeat()
	await _check_passive_and_counterattack()
	await _check_inactive_and_fog()
	await _check_sink_from_prone()
	for folder in _folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("KNOCKDOWN OK: five supplied native poses, no immediate pursuit/attack, exactly one own turn to rise, skipped turns, repeat push/speed cadence, passive recovery, no prone retaliation/petrification, fog/collision, authored-only Save, restart, removal and drowning from prone")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_supplied_poses() -> void:
	for type_id in ["weak_club", "medium_swordsman", "strong_guard", "cockatrice", "skeletal_horse"]:
		var path: String = CATALOG.definition(type_id).get("prone_path", "")
		_check(path == "res://assets/actors/prone/%s_prone.png" % type_id and ResourceLoader.exists(path), "Catalog picks up the supplied prone pose for " + type_id)
		var scene := await _fixture({ORIGIN: type_id}, {SHORE + Vector2i.RIGHT: "#"})
		var id: int = scene.get("_goblins_by_cell")[ORIGIN]
		var enemy: Dictionary = scene.get("_goblins")[id]
		var upright: Texture2D = enemy.sprite.texture
		_cast(scene)
		_check(enemy.cell == SHORE and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 1 and not enemy.knocked_down, "Immediate enemy response spends its whole turn standing without pursuit or attack for " + type_id)
		_check(enemy.sprite.texture.resource_path == path and enemy.sprite.texture.get_size() == Vector2(64, 64) and enemy.sprite.scale == Vector2.ONE and enemy.sprite.offset == GRID.ACTOR_DRAW_OFFSET and enemy.sprite.rotation == 0 and enemy.label.rotation == 0 and enemy.sprite.get_node("ContactShadow").rotation == 0, "Pushed actor uses its real native prone PNG through travel without rotating its label/shadow")
		_check(scene.call("_is_walkable", ORIGIN) and not scene.call("_is_walkable", SHORE) and scene.get("_hero_magic") == 11, "Fallen creature occupies its new cell, frees the old one, gives no kill reward and the scroll grants one magic")
		if type_id == "weak_club":
			# Let the push callback finish on its own, independently of hero snapping.
			scene.get("_hero_move_tween").pause()
			# A frame timer may fire before that frame's tween callbacks under load.
			# Wait for completion with a bound, without snapping either animation.
			for frame in range(60):
				if scene.get("_push_tweens").is_empty():
					break
				await process_frame
			_check(enemy.sprite.texture == upright and scene.get("_push_tweens").is_empty() and scene.get("_is_moving"), "Natural push completion restores the spent rise pose and cleans its tween without relying on hero animation completion")
		scene.call("_finish_hero_move", false)
		_check(enemy.sprite.texture == upright and not enemy.sprite.get_meta("prone") and enemy.cell == SHORE and scene.get("_push_tweens").is_empty(), "Finishing travel shows the already spent rise action without moving back")
		scene.get("_turn_queue").schedule_after(id, 1)
		scene.call("_wait_hero_turn")
		scene.call("_finish_hero_move", false)
		_check(enemy.cell == ORIGIN and scene.get("_turn_queue").current_turn == 2 and scene.get("_hero_strength") == 10, "The creature can pursue again only on its following own turn")
		scene.free()


func _check_delayed_turn() -> void:
	var scene := await _fixture({ORIGIN: "weak_club"}, {SHORE + Vector2i.RIGHT: "#"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[id]
	scene.get("_turn_queue").schedule_after(id, 2)
	_cast(scene)
	scene.call("_finish_hero_move", false)
	_check(enemy.knocked_down and enemy.cell == SHORE and enemy.sprite.get_meta("prone") and enemy.sprite.texture.resource_path.ends_with("weak_club_prone.png"), "A scheduled skip leaves the creature prone after travel instead of standing by animation/time")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(not enemy.knocked_down and enemy.cell == SHORE and enemy.sprite.texture == enemy.standing_texture and scene.get("_hero_strength") == 10, "The delayed own turn is spent rising without a simultaneous move or attack")
	scene.free()


func _check_speed_and_repeat() -> void:
	var scene := await _fixture({ORIGIN: "strong_guard"}, {SHORE + Vector2i.RIGHT: "#", SHORE + Vector2i.UP * 2: "#"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[id]
	enemy.retaliates_only = true
	scene.call("_sync_active_goblins")
	_add(scene, "speed_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	scene.call("_finish_hero_move", false)
	enemy.retaliates_only = false
	scene.call("_sync_active_goblins")
	_cast(scene)
	scene.call("_finish_hero_move", false)
	_check(enemy.knocked_down and enemy.cell == SHORE and scene.get("_turn_queue").current_turn == 1 and scene.get("_speed_actions_this_turn") == 1, "A fast half-action leaves the enemy prone until the world gives it a turn")
	scene.set("_hero_cell", SHORE + Vector2i.DOWN)
	scene.call("_finish_hero_move", false)
	_cast_in_direction(scene, Vector2i.UP)
	_check(not enemy.knocked_down and enemy.cell == SHORE + Vector2i.UP and scene.get("_turn_queue").current_turn == 2 and scene.get("_speed_boost_turns") == 9 and scene.get("_hero_strength") == 10 and scene.get("_hero_magic") == 13, "Repeated push refreshes one knockdown; the second fast action spends one rise turn without stacked stun or extra world ticks")
	scene.call("_finish_hero_move", false)
	scene.get("_turn_queue").schedule_after(id, 1)
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(enemy.cell == SHORE and scene.get("_turn_queue").current_turn == 3, "One rise turn suffices after repeated pushes; the next own turn resumes pursuit")
	scene.free()


func _check_passive_and_counterattack() -> void:
	var scene := await _fixture({ORIGIN: "red_mushroom"}, {SHORE + Vector2i.RIGHT: "#"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[id]
	var original_pixels: PackedByteArray = enemy.standing_texture.get_image().get_data()
	_check(scene.call("_push_adjacent", Vector2i.RIGHT), "Passive creature can be knocked over by a successful push")
	scene.call("_finish_goblin_animations")
	_check(enemy.knocked_down and enemy.standing_texture.get_image().get_data() == original_pixels and enemy.sprite.texture.get_size() == Vector2(64, 64), "A type without a supplied pose gets a cached native quarter-turn without altering its standing texture")
	scene.set("_hero_strength", 0)
	scene.call("_resolve_combat", id)
	_check(scene.get("_hero_strength") == 0 and enemy.knocked_down, "Prone passive defender cannot deal counterattack damage on a missed attack")
	scene.call("_sync_active_goblins")
	_check(scene.get("_turn_queue").get("_positions").has(id), "Passive creature enters the queue only to recover from knockdown")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(not enemy.knocked_down and not enemy.active and not scene.get("_turn_queue").get("_positions").has(id) and enemy.cell == SHORE and scene.get("_hero_strength") == 0, "Passive creature spends one rise turn and leaves the autonomous queue without attacking")
	scene.call("_resolve_combat", id)
	_check(scene.get("_hero_strength") == -1, "Ordinary retaliation resumes after standing")
	scene.free()

	scene = await _fixture({ORIGIN: "cockatrice"}, {SHORE + Vector2i.RIGHT: "#"})
	id = scene.get("_goblins_by_cell")[ORIGIN]
	scene.get("_turn_queue").schedule_after(id, 2)
	_cast(scene)
	scene.call("_finish_hero_move", false)
	scene.set("_hero_strength", 0)
	scene.call("_resolve_combat", id)
	_check(not scene.get("_petrified") and scene.get("_hero_strength") == 0 and scene.get("_goblins")[id].knocked_down, "A fallen cockatrice cannot turn a missed attack into damaging/petrifying retaliation")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(not scene.get("_petrified") and scene.get("_hero_strength") == 0, "Cockatrice's rise turn itself cannot attack or petrify")
	scene.call("_resolve_combat", id)
	_check(scene.get("_petrified"), "Standing cockatrice retains its permanent petrification danger")
	scene.free()


func _check_inactive_and_fog() -> void:
	var scene := await _fixture({ORIGIN: "medium_swordsman"}, {SHORE + Vector2i.RIGHT: "#"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[id]
	scene.call("_push_adjacent", Vector2i.RIGHT)
	scene.call("_finish_goblin_animations")
	scene.set("_hero_cell", Vector2i(150, 10))
	scene.call("_advance_world_turn")
	_check(enemy.knocked_down and not enemy.active and not scene.get("_turn_queue").get("_positions").has(id), "Inactive chunks cannot spend a recovery turn while the hero is far away")
	scene.set("_hero_cell", HERO)
	scene.call("_sync_active_goblins")
	var fog: ColorRect = scene.get("_fog_cells")[SHORE]
	fog.self_modulate.a = 1.0
	scene.call("_update_visibility_at_cell", SHORE)
	_check(not enemy.sprite.visible and not enemy.label.visible, "Fog logically hides the prone sprite and its strength together")
	fog.self_modulate.a = 0.4
	scene.call("_update_visibility_at_cell", SHORE)
	_check(enemy.sprite.visible and enemy.label.visible and is_equal_approx(enemy.sprite.modulate.a, 0.6) and is_equal_approx(enemy.sprite.get_node("ContactShadow").self_modulate.a, 0.5), "Fallen pose preserves native shadow opacity and the parent cell's fade")
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
	_check(saved.objects.get(ORIGIN) == "medium_swordsman" and not saved.objects.has(SHORE) and scene.get("_editor_object_changes").is_empty(), "Save excludes the displaced position, knockdown state and pose")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(not enemy.knocked_down and enemy.cell == SHORE, "Reactivated creature's first own turn is recovery rather than catch-up movement")
	scene.call("_remove_goblin", id)
	await process_frame
	_check(scene.get("_goblins").is_empty() and scene.get("_push_tweens").is_empty(), "Removing a recovering creature leaves no stale push callback or actor state")
	scene.call("_build_scene")
	await process_frame
	id = scene.get("_goblins_by_cell")[ORIGIN]
	enemy = scene.get("_goblins")[id]
	_check(not enemy.knocked_down and enemy.sprite.texture == enemy.standing_texture and not enemy.sprite.get_meta("prone", false) and scene.get("_turn_queue").current_turn == 0, "Restart restores a standing authored creature with no old knockdown or pose")
	scene.free()


func _check_sink_from_prone() -> void:
	var scene := await _fixture({ORIGIN: "weak_club"}, {SHORE + Vector2i.RIGHT: "#"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	scene.call("_push_adjacent", Vector2i.RIGHT)
	scene.call("_finish_goblin_animations")
	var fallen: Texture2D = scene.get("_goblins")[id].sprite.texture
	scene.call("_set_terrain_cell", SHORE + Vector2i.RIGHT, DEMO.TileType.FLOOR)
	scene.call("_set_terrain_cell", SHORE + Vector2i.RIGHT * DEMO.PUSH_DISTANCE, DEMO.TileType.WATER)
	scene.set("_hero_cell", ORIGIN)
	scene.call("_finish_hero_move", false)
	_cast(scene)
	_check(not scene.get("_goblins").has(id) and scene.get("_sinking_actors").size() == 1 and scene.get("_hero_strength") == 10 and not scene.get("_turn_queue").get("_positions").has(id), "Pushing a prone enemy into water kills without strength reward rather than scheduling a rise")
	if not scene.get("_sinking_actors").is_empty():
		var effect: Sprite2D = scene.get("_sinking_actors").keys()[0]
		_check(effect.texture == fallen, "Drowning carries the fallen pose into the existing sinking animation")
	scene.free()

	scene = await _fixture({ORIGIN: "weak_club"}, {SHORE + Vector2i.RIGHT: "#"})
	id = scene.get("_goblins_by_cell")[ORIGIN]
	scene.get("_turn_queue").schedule_after(id, 2)
	_cast(scene)
	scene.call("_remove_goblin", id)
	await create_timer(DEMO.HERO_MOVE_DURATION * 1.5).timeout
	_check(scene.get("_goblins").is_empty() and scene.get("_push_tweens").is_empty(), "Death during a prone push cancels the pending pose callback without restoring a deleted actor")
	scene.free()


func _cast_in_direction(scene: Node2D, direction: Vector2i) -> void:
	_add(scene, "push_scroll")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("push_scroll"))
	_key(scene, {Vector2i.UP: KEY_W, Vector2i.LEFT: KEY_A, Vector2i.DOWN: KEY_S, Vector2i.RIGHT: KEY_D}[direction])
	_key(scene, KEY_SPACE)
