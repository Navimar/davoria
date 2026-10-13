extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const GRID := preload("res://scripts/grid_config.gd")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_map()
	await _check_behavior_and_editor()
	if _errors.is_empty():
		print("WATER ELEMENTALS OK: removed short-sword goblin, 12 existing-water placements, 15-45 strength, native asset, stable/restarted rolls, water-only chase/wander, shore attacks, combat reward and automatic editor/save")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_map() -> void:
	_check(CATALOG.definition("weak_sword").is_empty() and DEMO.GOBLIN_TYPES.TYPES.size() == 3, "Removed goblin is absent from all active types")
	_check(not FileAccess.file_exists("res://assets/actors/goblins/series_01/05_weak_sword.png"), "Removed red sprite is absent from the runtime directory")
	var scene: Node2D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	scene.get("_rng").seed = 7321
	scene.call("_build_scene")
	for spawn in LEVEL.WATER_ELEMENTALS:
		scene.call("_load_chunk", scene.call("_chunk_coord_for_cell", spawn.cell))
	scene.call("_sync_active_goblins")
	scene.call("_refresh_combat_labels")
	var authored: Dictionary = scene.call("_authored_map_objects")
	var initial: Dictionary = {}
	for type_id: String in authored.values():
		_check(type_id != "weak_sword", "Existing map placements migrate to the remaining weak goblin")
	for spawn in LEVEL.WATER_ELEMENTALS:
		_check(authored.get(spawn.cell) == "water_elemental" and scene.call("_terrain_type", spawn.cell) == DEMO.TileType.WATER, "Every elemental is authored on existing water")
		var actor_id: int = scene.get("_goblins_by_cell")[spawn.cell]
		var enemy: Dictionary = scene.get("_goblins")[actor_id]
		_check(enemy.type == "water_elemental" and enemy.habitat == "water" and enemy.strength >= 15 and enemy.strength <= 45, "Each elemental rolls its own water-only type in the requested range")
		_check(enemy.sprite.texture.resource_path == DEMO.WATER_ELEMENTAL_PATH and enemy.sprite.texture.get_size() == Vector2(64, 64) and enemy.sprite.scale == Vector2.ONE and enemy.sprite.offset == GRID.ACTOR_DRAW_OFFSET, "Elementals reuse the selected native sprite without resizing")
		_check(not enemy.sprite.get_node("ContactShadow").visible and enemy.label.text == str(enemy.strength), "Water inhabitants show current strength without a ground shadow")
		initial[spawn.cell] = enemy.strength
	for turn in range(10):
		scene.call("_advance_world_turn")
	for enemy: Dictionary in scene.get("_goblins").values():
		if enemy.type == "water_elemental":
			_check(enemy.strength == initial[enemy.sprite.get_meta("map_origin")], "Elementals do not drown or reroll strength during idle turns")
	scene.get("_rng").seed = 991
	scene.call("_build_scene")
	for spawn in LEVEL.WATER_ELEMENTALS:
		scene.call("_load_chunk", scene.call("_chunk_coord_for_cell", spawn.cell))
	var changed := 0
	for enemy: Dictionary in scene.get("_goblins").values():
		if enemy.type == "water_elemental":
			_check(enemy.strength >= 15 and enemy.strength <= 45, "Restart retains the range")
			if initial[enemy.sprite.get_meta("map_origin")] != enemy.strength:
				changed += 1
	_check(changed > 0 and initial.size() == 12, "Restart rerolls the twelve authored elementals")
	scene.free()
	await process_frame


func _check_behavior_and_editor() -> void:
	var folder := "/private/tmp/davoria_elementals_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			var land := y == 30 and x >= 4 and x <= 5
			var water := (y == 30 and x >= 6 and x <= 10) or (y >= 31 and y <= 33 and x >= 8 and x <= 10)
			row += "." if land else ("~" if water else "#")
		file.store_line(row)
	file.close()
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	_check(scene.call("_spawn_enemy", Vector2i(4, 30), "water_elemental") == -1, "An elemental cannot spawn on dry land")
	var actor_id: int = scene.call("_spawn_enemy", Vector2i(8, 30), "water_elemental")
	scene.call("_sync_active_goblins")
	var enemy: Dictionary = scene.get("_goblins")[actor_id]
	_check(scene.get("_turn_queue").get("_positions").has(actor_id), "Elementals use the existing scheduled enemy turns")
	_check(scene.call("_enemy_can_step", Vector2i(7, 30), "water") and not scene.call("_enemy_can_step", Vector2i(5, 30), "water"), "Water-only movement excludes the hero's dry cell")
	for target: Vector2i in [Vector2i(7, 30), Vector2i(6, 30)]:
		scene.call("_take_goblin_turn", actor_id)
		scene.call("_finish_goblin_animations")
		_check(enemy.cell == target, "Elemental pursues the land-bound hero through water towards shore")
	scene.set("_hero_strength", 0)
	scene.call("_take_goblin_turn", actor_id)
	scene.call("_finish_goblin_animations")
	_check(enemy.cell == Vector2i(6, 30) and scene.get("_hero_strength") == -1, "Elemental attacks from water without stepping onto the hero's dry cell")
	enemy.strength = 1
	scene.set("_hero_strength", 1000)
	scene.set("_hero_max_strength", 1000)
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(100):
		rng.seed = seed_value
		if rng.randi_range(0, 1000) < 1000:
			rng.seed = seed_value
			break
	scene.call("_resolve_combat", actor_id)
	_check(not scene.get("_goblins").has(actor_id) and scene.get("_hero_strength") == 1001 and scene.get("_hero_max_strength") == 1001 and scene.call("_is_walkable", Vector2i(6, 30)), "Normal combat removes an elemental and grants the existing one-strength kill reward")
	# Block sight across the narrow water entrance to exercise actual wandering.
	var entries := CATALOG.definitions()
	entries.append({"id": "fixture_water_cloud", "name_key": "FIXTURE_WATER_CLOUD", "category": "prop", "path": DEMO.CABINET_FULL_PATH, "habitat": "water", "blocks_movement": false, "blocks_sight": true})
	scene.call("_spawn_map_object", Vector2i(6, 30), "fixture_water_cloud")
	actor_id = scene.call("_spawn_enemy", Vector2i(9, 32), "water_elemental")
	enemy = scene.get("_goblins")[actor_id]
	scene.call("_take_goblin_turn", actor_id)
	scene.call("_finish_goblin_animations")
	_check(enemy.last_seen == null and enemy.cell != Vector2i(9, 32), "Hidden-target elemental wanders within its water habitat")
	for index in range(20):
		scene.set("_hero_strength", 0)
		scene.call("_take_goblin_turn", actor_id)
		scene.call("_finish_goblin_animations")
		_check(scene.call("_terrain_type", enemy.cell) == DEMO.TileType.WATER, "Neither wandering nor chasing can take an elemental onto dry land")
	scene.call("_remove_goblin", actor_id)
	scene.call("_erase_live_map_object", Vector2i(6, 30))
	entries.pop_back()
	scene.call("_toggle_editor")
	var palette_ids: Array[String] = []
	for button: Button in scene.get("_editor_canvas").find_children("*", "Button", true, false):
		if button.has_meta("object_type"):
			palette_ids.append(button.get_meta("object_type"))
	_check(palette_ids.has("water_elemental") and not palette_ids.has("weak_sword"), "Catalog-driven palette contains the elemental and excludes the removed goblin")
	scene.call("_select_editor_object", "water_elemental")
	scene.call("_paint_selected_tile", Vector2i(4, 30))
	_check(not scene.get("_editor_object_changes").has(Vector2i(4, 30)), "Editor rejects an elemental on land")
	var water_cell := Vector2i(9, 32)
	scene.call("_paint_selected_tile", water_cell)
	_check(scene.get("_goblins_by_cell").has(water_cell), "Editor places the elemental on water without a separate palette entry")
	actor_id = scene.get("_goblins_by_cell")[water_cell]
	enemy = scene.get("_goblins")[actor_id]
	scene.call("_select_editor_tile", DEMO.TileType.WATER)
	scene.call("_paint_selected_tile", water_cell)
	_check(scene.get("_goblins_by_cell").get(water_cell) == actor_id, "Repainting compatible water preserves its elemental")
	enemy.strength = 1
	scene.call("_save_loaded_chunks")
	var data := DEMO.MAP_OBJECTS.read_map(DEMO.MAP_OBJECTS.path_for_chunks(template))
	_check(data.objects.get(water_cell) == "water_elemental", "Save persists the type and water cell instead of current strength")
	scene.call("_build_scene")
	_check(scene.get("_goblins_by_cell").has(water_cell) and scene.get("_goblins")[scene.get("_goblins_by_cell")[water_cell]].strength >= 15, "Saved elemental respawns with a fresh strength roll")
	scene.call("_toggle_editor")
	scene.call("_select_editor_tile", DEMO.TileType.FLOOR)
	scene.call("_paint_selected_tile", water_cell)
	_check(not scene.get("_goblins_by_cell").has(water_cell) and scene.get("_editor_object_changes").get(water_cell) == "", "Changing water to dry land removes the now-incompatible authored elemental")
	scene.free()
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
