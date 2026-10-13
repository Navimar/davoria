extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	var scene := await _fixture({})
	_add(scene, "health_potion")
	scene.set("_hero_strength", 1)
	await process_frame
	await process_frame
	var source: Control = scene.get("_inventory_slot_icons")[scene.get("_inventory_item_ids").find("health_potion")].get_parent().get_parent()
	var target: Control = scene.get("_weapon_slot")
	var viewport := scene.get_viewport()
	_mouse(viewport, source.get_global_rect().get_center(), true)
	_motion(viewport, source.get_global_rect().get_center() + Vector2(25, 0))
	await process_frame
	_check(viewport.gui_is_dragging() and scene.get("_inventory_item_ids").has("health_potion") and scene.get("_hero_magic") == 10 and scene.get("_hero_strength") == 1, "Native drag begins without drinking the potion on press")
	_motion(viewport, target.get_global_rect().get_center())
	_mouse(viewport, target.get_global_rect().get_center(), false)
	await process_frame
	_check(scene.get("_equipped_weapon_id") == "broken_bottle" and not scene.get("_inventory_item_ids").has("health_potion") and scene.get("_hero_strength") == 1 and scene.get("_hero_magic") == 10 and scene.get("_turn_queue").current_turn == 1, "Native drag-and-drop converts the potion into a bottle weapon for one action")
	scene.call("_finish_hero_move", false)
	var inventory_target: Control = scene.get("_inventory_slot_icons")[0].get_parent().get_parent()
	_mouse(viewport, target.get_global_rect().get_center(), true)
	_motion(viewport, target.get_global_rect().get_center() + Vector2(25, 0))
	await process_frame
	_motion(viewport, inventory_target.get_global_rect().get_center())
	_mouse(viewport, inventory_target.get_global_rect().get_center(), false)
	await process_frame
	_check(scene.get("_equipped_weapon_id").is_empty() and scene.get("_inventory_item_ids").has("broken_bottle") and scene.get("_turn_queue").current_turn == 2, "Native drag back to inventory unequips for one action")
	scene.call("_finish_hero_move", false)
	var bottle_slot: Control = scene.get("_inventory_slot_icons")[scene.get("_inventory_item_ids").find("broken_bottle")].get_parent().get_parent()
	_mouse(viewport, bottle_slot.get_global_rect().get_center(), true, MOUSE_BUTTON_RIGHT)
	_mouse(viewport, bottle_slot.get_global_rect().get_center(), false, MOUSE_BUTTON_RIGHT)
	await process_frame
	_check(scene.call("_ground_items_at", HERO).size() == 1 and scene.get("_turn_queue").current_turn == 3, "Actual right mouse click drops into the floor zone")
	scene.call("_finish_hero_move", false)
	await process_frame
	var floor_slot: Control = scene.get("_floor_grid").get_child(0)
	_mouse(viewport, floor_slot.get_global_rect().get_center(), true)
	_mouse(viewport, floor_slot.get_global_rect().get_center(), false)
	await process_frame
	_check(scene.call("_ground_items_at", HERO).is_empty() and scene.get("_inventory_item_ids").has("broken_bottle") and scene.get("_turn_queue").current_turn == 4, "Actual left click on floor takes exactly one item and action")
	scene.free()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("INVENTORY INPUT OK: real Godot mouse dispatch, potion drag without drinking, drop to weapon, return to backpack, right-click drop, floor click and one action per operation")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _mouse(viewport: Viewport, position: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	viewport.push_input(event, true)


func _motion(viewport: Viewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = Vector2(25, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)
