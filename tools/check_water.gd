extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const GRID := preload("res://scripts/grid_config.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# This fixture never paints or saves the user's map.
	var folder := "/private/tmp/davoria_water_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			row += "." if x >= 4 and x <= 10 and y >= 28 and y <= 32 else "#"
		file.store_line(row)
	file.close()
	var original := FileAccess.get_file_as_string(template % [0, 0])
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		# Random crystal pickups would change the fixed strength used below.
		scene.call("_remove_procedural_item", cell)
		scene.call("_erase_live_map_object", cell)
	scene.call("_set_terrain_cell", Vector2i(6, 30), DEMO.TileType.WATER)
	scene.call("_set_terrain_cell", Vector2i(7, 30), DEMO.TileType.WATER)
	scene.call("_set_terrain_cell", Vector2i(7, 29), DEMO.TileType.WALL)
	var hero: Sprite2D = scene.get("_hero")
	var strength_label: Label = scene.get("_hero_strength_label")
	var breath_label: Label = scene.get("_hero_breath_label")
	var label_position := strength_label.position
	_check(scene.get("_hero_breath") == 30 and not breath_label.visible, "Breath starts full and hidden on land")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_hero_cell") == Vector2i(6, 30) and scene.get("_hero_breath") == 30 and breath_label.visible and breath_label.text == "30", "Entering water shows a full reserve above strength")
	_check(breath_label.position.y < strength_label.position.y and breath_label.modulate == DEMO.BREATH_COLOR and breath_label.z_index == strength_label.z_index, "Breath is blue and on the same upper label layer")
	_check(hero.offset == GRID.ACTOR_DRAW_OFFSET, "Entry uses the normal sprite height")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_breath") == 30, "Finishing animation never spends breath")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_breath") == 29 and hero.offset.y > GRID.ACTOR_DRAW_OFFSET.y, "A subsequent water step spends one breath and begins submerging")
	_wait(scene)
	_check(scene.get("_hero_breath") == 28, "Waiting on water spends breath like moving")
	var turn: int = scene.get("_turn_queue").current_turn
	scene.call("_try_move_hero", Vector2i.UP)
	_check(scene.get("_hero_breath") == 28 and scene.get("_turn_queue").current_turn == turn, "A rejected wall move spends neither a turn nor breath")
	var previous_offset := hero.offset.y
	for remaining in range(27, -1, -1):
		_wait(scene)
		_check(scene.get("_hero_breath") == remaining and hero.offset.y >= previous_offset, "Each accepted water action spends exactly one breath and submerges monotonically")
		previous_offset = hero.offset.y
	_check(scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10, "Thirty breath-consuming actions precede strength loss")
	_check(hero.offset == GRID.ACTOR_DRAW_OFFSET + Vector2(0, 48) and hero.material.get_shader_parameter("submerged_pixels") == 48.0, "Submerging stops at exactly three quarters of the native 64px sprite")
	_check(strength_label.position == label_position and breath_label.visible, "Submerging never moves or clips world labels")
	scene.call("_add_inventory_item", load(DEMO.SWORD_PATH), DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_id", DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_texture", load(DEMO.SWORD_PATH))
	scene.call("_refresh_inventory_panel")
	scene.set("_strength_boost_turns", 3)
	_wait(scene)
	_check(scene.get("_hero_strength") == 9 and scene.get("_hero_max_strength") == 10 and scene.call("_weapon_strength_bonus") == 5 and strength_label.text == "23", "Drowning takes one own strength, preserving maximum, weapon bonus and boost rules")
	_check(hero.material.get_shader_parameter("submerged_pixels") == 48.0, "Strength loss cannot sink the hero below three quarters")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_cell") == Vector2i(8, 30) and scene.get("_hero_breath") == 30 and not breath_label.visible and hero.offset == GRID.ACTOR_DRAW_OFFSET and hero.material.get_shader_parameter("submerged_pixels") == 0.0, "Leaving water refills breath, hides the number and restores the whole sprite")
	scene.call("_try_move_hero", Vector2i.LEFT)
	scene.call("_finish_hero_move", false)
	scene.set("_hero_breath", 6)
	scene.call("_refresh_combat_labels")
	var depth := hero.offset
	_add_water_potion(scene)
	_drink_last(scene)
	_check(scene.get("_hero_magic") == 11 and scene.get("_water_breathing_turns") == 30 and scene.get("_hero_breath") == 6 and hero.offset == depth, "Water potion freezes breath/submerging for three times pre-use magic and then grants one magic")
	_check(scene.get("_inventory_item_ids") == [DEMO.ITEM_ID_GHOST_RING, DEMO.ITEM_ID_SWORD], "Drinking consumes exactly the blue potion and preserves the other slots")
	for index in range(30):
		_wait(scene)
		_check(scene.get("_hero_breath") == 6 and hero.offset == depth and scene.get("_hero_strength") == 9, "All protected turns preserve breath, depth and own strength")
	_check(scene.get("_water_breathing_turns") == 0, "Water breathing expires after exactly thirty subsequent world turns")
	_wait(scene)
	_check(scene.get("_hero_breath") == 5, "The next water turn resumes breath consumption")
	_add_water_potion(scene)
	_drink_last(scene)
	_check(scene.get("_water_breathing_turns") == 33 and scene.get("_hero_magic") == 12, "Reusing the potion renews its duration without restoring lost breath")
	scene.call("_add_inventory_item", load(DEMO.HEALTH_POTION_PATH), DEMO.ITEM_ID_HEALTH_POTION)
	_drink_last(scene)
	_check(scene.get("_water_breathing_turns") == 32 and scene.get("_hero_magic") == 13 and scene.get("_hero_breath") == 5, "Another potion action spends an existing water-breathing turn")
	scene.call("_add_inventory_item", load(DEMO.STRENGTH_POTION_PATH), DEMO.ITEM_ID_STRENGTH_POTION)
	_drink_last(scene)
	_check(scene.get("_water_breathing_turns") == 31 and scene.get("_strength_boost_turns") == 13, "Starting a strength boost cannot pause the existing water-breathing duration")
	_add_water_potion(scene)
	_drink_last(scene)
	_check(scene.get("_water_breathing_turns") == 42 and scene.get("_strength_boost_turns") == 12, "Starting water breathing cannot pause an existing strength boost")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_water_breathing_turns") == 41 and scene.get("_hero_breath") == 30, "Effect duration counts land actions too; dry land restores breath independently")
	scene.call("_try_move_hero", Vector2i.LEFT)
	scene.call("_finish_hero_move", false)
	scene.set("_hero_breath", 0)
	scene.set("_hero_magic", 2)
	scene.set("_hero_strength", 10)
	_add_water_potion(scene)
	_drink_last(scene)
	for index in range(6):
		_wait(scene)
	_check(scene.get("_hero_breath") == 0 and scene.get("_hero_strength") == 10 and scene.get("_water_breathing_turns") == 0, "Water breathing prevents drowning even when applied with an empty reserve")
	_wait(scene)
	_check(scene.get("_hero_strength") == 9, "Drowning resumes on the first unprotected turn with zero breath")
	# The catalog supplies both random cabinet contents and the generated editor palette.
	_check(CATALOG.potion_ids().has(DEMO.ITEM_ID_WATER_BREATHING_POTION), "Registered water potion automatically joins the cabinet pool")
	scene.call("_toggle_editor")
	var found := false
	for button: Button in scene.get("_editor_canvas").find_children("*", "Button", true, false):
		if button.get_meta("object_type", "") == DEMO.ITEM_ID_WATER_BREATHING_POTION:
			found = true
	_check(found, "Generated editor palette automatically contains the water potion")
	scene.call("_toggle_editor")
	scene.set("_hero_strength", -10)
	scene.call("_wait_hero_turn")
	_check(scene.get("_game_over") and scene.get("_hero_strength") == -11, "Drowning uses the normal death threshold")
	await process_frame
	await process_frame
	_check(not scene.get("_game_over") and scene.get("_hero_strength") == 10 and scene.get("_hero_breath") == 30 and scene.get("_water_breathing_turns") == 0 and not scene.get("_hero_breath_label").visible, "Death restarts with full breath, no effects and land visuals")
	# A full-width river separates the hero from the goblin; all pursuit/wander steps stay on land.
	for y in range(28, 33):
		scene.call("_set_terrain_cell", Vector2i(7, y), DEMO.TileType.WATER)
	scene.set("_hero_cell", Vector2i(8, 30))
	scene.call("_finish_hero_move", false)
	var actor_id: int = scene.call("_spawn_goblin", Vector2i(6, 30), "weak_club")
	_check(not scene.call("_goblin_can_step", Vector2i(7, 30)) and scene.call("_is_walkable", Vector2i(7, 30)), "Water is accessible to the hero and forbidden to goblins")
	for index in range(20):
		scene.call("_take_goblin_turn", actor_id)
		scene.call("_finish_goblin_animations")
		var goblin: Dictionary = scene.get("_goblins")[actor_id]
		_check(scene.call("_terrain_type", goblin.cell) == DEMO.TileType.FLOOR and goblin.cell.x < 7, "Goblin pursuit and wandering cannot enter or cross water")
	scene.set("_hero_cell", Vector2i(7, 30))
	_check(not scene.call("_goblin_can_step", Vector2i(7, 30)), "Hero occupancy does not make water traversable for a goblin")
	scene.call("_remove_goblin", actor_id)
	actor_id = scene.call("_spawn_goblin", Vector2i(5, 30), "weak_club")
	scene.set("_hero_strength", 0)
	scene.call("_take_goblin_turn", actor_id)
	scene.call("_finish_goblin_animations")
	_check(scene.get("_goblins")[actor_id].cell == Vector2i(6, 30), "A visible hero in water is pursued along land to the adjacent shore")
	scene.call("_take_goblin_turn", actor_id)
	scene.call("_finish_goblin_animations")
	_check(scene.get("_hero_strength") == -1 and scene.get("_goblins")[actor_id].cell == Vector2i(6, 30), "The goblin attacks a water-bound hero from land without entering water")
	_check(FileAccess.get_file_as_string(template % [0, 0]) == original and scene.get("_editor_changes").is_empty(), "Breath, drowning and water fixtures never write gameplay state to the map")
	scene.free()
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("WATER CHECK OK: entry, step/wait countdown, fixed surface/pixel clipping, 75% depth cap, drowning, dry recovery, potion duration/renewal/independent effects, automatic catalog/editor, restart and dry-land goblin pursuit/shore attacks")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _wait(scene: Node2D) -> void:
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)


func _add_water_potion(scene: Node2D) -> void:
	scene.call("_add_inventory_item", load(DEMO.WATER_BREATHING_POTION_PATH), DEMO.ITEM_ID_WATER_BREATHING_POTION)


func _drink_last(scene: Node2D) -> void:
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").size() - 1)
	scene.call("_finish_hero_move", false)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
