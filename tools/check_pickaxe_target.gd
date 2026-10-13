extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_directions()
	await _check_invalid_and_cancel()
	await _check_speed_and_stale_item()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("PICKAXE TARGET OK: inventory use, four WASD neighbors, no bump modal, exactly one item/action and no magic, unchanged position/source map, invalid/cancel/stale targets, frozen input/timers and speed cadence")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_directions() -> void:
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var direction: Vector2i = {KEY_W: Vector2i.UP, KEY_A: Vector2i.LEFT, KEY_S: Vector2i.DOWN, KEY_D: Vector2i.RIGHT}[key]
		var wall := HERO + direction
		var scene := await _fixture({}, {wall: "#"})
		_add(scene, "pickaxe")
		scene.call("_try_move_hero", direction)
		_check(not scene.get("_door_prompt").is_open() and not scene.call("_field_target_is_active") and scene.get("_turn_queue").current_turn == 0, "Bumping a wall does not trigger pickaxe use")
		scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
		var target: Node2D = scene.get("_field_target")
		_check(target.is_active() and target.direction == Vector2i.ZERO and target.find_child("TargetHint", true, false).text.begins_with("Кирка"), "Inventory pickaxe opens the shared reticle with its own hint")
		_input_key(scene, key)
		_check(target.direction == direction and scene.get("_hero_cell") == HERO, "WASD chooses a neighboring cell without walking")
		_input_key(scene, KEY_SPACE)
		_check(scene.call("_terrain_type", wall) == DEMO.TileType.FLOOR and not target.is_active() and scene.get("_hero_cell") == HERO and not scene.get("_inventory_item_ids").has("pickaxe") and scene.get("_hero_magic") == 10 and scene.get("_turn_queue").current_turn == 1, "Confirm mines only the selected neighbor for exactly one tool/action, with no magic")
		scene.call("_finish_hero_move", false)
		_check(scene.get("_turn_queue").current_turn == 1 and scene.get("_hero_cell") == HERO and scene.get("_editor_changes").is_empty(), "Finishing the mining animation does not add a turn or editor changes")
		scene.free()


func _check_invalid_and_cancel() -> void:
	var wall := HERO + Vector2i.RIGHT
	var door := HERO + Vector2i.DOWN
	var scene := await _fixture({HERO + Vector2i.LEFT: "empty_cabinet"}, {wall: "#", door: "D"})
	_add(scene, "pickaxe")
	_add(scene, "health_potion")
	scene.set("_strength_boost_turns", 7)
	scene.set("_hero_strength", 1)
	scene.get("_held_move_keys").append(KEY_D)
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	var target: Node2D = scene.get("_field_target")
	_check(scene.get("_held_move_keys").is_empty(), "Starting mining targeting clears held movement")
	_input_key(scene, KEY_SPACE)
	_check(target.is_active() and target.direction == Vector2i.ZERO, "Space without a selected cell does nothing")
	for key: Key in [KEY_W, KEY_A, KEY_S]:
		_input_key(scene, key)
		_input_key(scene, KEY_SPACE)
		_check(target.is_active() and target.get("_blocked") and scene.get("_inventory_item_ids").has("pickaxe") and scene.get("_turn_queue").current_turn == 0 and scene.get("_hero_magic") == 10, "Floor, furniture and doors reject mining without spending anything")
	_input_key(scene, KEY_H)
	_input_key(scene, KEY_E)
	scene.call("_try_move_hero", Vector2i.UP)
	scene.call("_wait_hero_turn")
	scene.call("_advance_world_turn")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("health_potion"))
	_check(scene.get("_hero_cell") == HERO and scene.get("_hero_strength") == 1 and scene.get("_strength_boost_turns") == 7 and scene.get("_turn_queue").current_turn == 0 and not scene.get("_hero_picker").is_open() and not scene.get("_editor_canvas").visible, "Mining targeting pauses movement, waits, inventory, effects and other interfaces")
	_input_key(scene, KEY_ESCAPE)
	_check(not target.is_active() and scene.get("_pending_target_slot") == -1 and scene.get("_pending_target_item_id").is_empty() and scene.get("_inventory_item_ids").has("pickaxe"), "Escape discards the selection and preserves the pickaxe")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	_input_key(scene, KEY_S)
	_input_key(scene, KEY_SPACE)
	_input_key(scene, KEY_D)
	_check(not target.get("_blocked") and target.find_child("TargetHint", true, false).text.begins_with("Кирка"), "Selecting a different target clears the rejected-cell state")
	_input_key(scene, KEY_SPACE)
	_check(not target.is_active() and scene.call("_terrain_type", wall) == DEMO.TileType.FLOOR and scene.call("_terrain_type", door) == DEMO.TileType.DOOR and scene.get("_turn_queue").current_turn == 1, "A valid retry destroys the wall while retaining the rejected door")
	scene.free()


func _check_speed_and_stale_item() -> void:
	var scene := await _fixture({}, {ORIGIN: "#"})
	_add(scene, "speed_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	scene.call("_finish_hero_move", false)
	_add(scene, "pickaxe")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	_input_key(scene, KEY_D)
	_input_key(scene, KEY_SPACE)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 1 and scene.get("_speed_actions_this_turn") == 1 and scene.get("_speed_boost_turns") == 10 and scene.get("_hero_magic") == 11, "Mining consumes one fast action without advancing the world or gaining magic")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 2 and scene.get("_speed_boost_turns") == 9, "The next fast action advances the world once")
	scene.call("_set_terrain_cell", ORIGIN, DEMO.TileType.WALL)
	_add(scene, "pickaxe")
	var slot: int = scene.get("_inventory_item_ids").find("pickaxe")
	scene.call("_activate_inventory_slot", slot)
	scene.call("_consume_inventory_slot", slot)
	_add(scene, "pickaxe")
	_input_key(scene, KEY_D)
	_input_key(scene, KEY_SPACE)
	_check(not scene.call("_field_target_is_active") and scene.call("_terrain_type", ORIGIN) == DEMO.TileType.WALL and scene.get("_inventory_item_ids").has("pickaxe") and scene.get("_turn_queue").current_turn == 2, "A replaced inventory entry invalidates the old target rather than consuming another pickaxe")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	scene.call("_build_scene")
	_check(not scene.call("_field_target_is_active") and scene.get("_pending_target_slot") == -1 and scene.get("_pending_target_revision") == -1, "Restart clears a pending mining target")
	scene.free()


func _input_key(scene: Node2D, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	scene.call("_input", event)
