extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	await _check_editor_and_loading()
	await _check_blocking_and_tools()
	await _check_blast(false)
	await _check_blast(true)
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("BEDROCK OK: native opaque assets, stable 80/20 variants, automatic editor, source-only Save/restart and background loading, no earth reclassification, movement/FOV/push blockers, free invalid pickaxe target, timed and chain blast immunity with ordinary terrain destruction preserved")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _settle(scene: Node2D) -> void:
	scene.call("_finish_hero_move", false)


func _check_editor_and_loading() -> void:
	var remote := Vector2i(40, 40)
	var scene := await _fixture({}, {ORIGIN: "B", remote: "B"})
	var terrain := DEMO.TileType.BEDROCK
	_check(scene.call("_terrain_type", ORIGIN) == terrain and scene.call("_terrain_type", remote) == terrain and not scene.get("_earth_cells").has(remote), "Explicit bedrock survives even inside the old masonry-to-earth mass")
	_check(scene.get("_editor_palette").get_children().any(func(button: Button): return button.get_meta("object_type", "") == "bedrock"), "The shared catalog automatically exposes bedrock in the editor")
	var variants: Array = scene.get("_tile_variants")[terrain]
	_check(variants.size() == 4 and variants.all(func(texture: Texture2D): return texture.get_size() == Vector2(64, 64) and texture.get_image().get_pixel(0, 0).a == 1.0), "All bedrock variants retain native opaque 64px art")
	var counts: Dictionary = {}
	for y in range(100):
		for x in range(100):
			var cell := Vector2i(100 + x, 100 + y)
			scene.get("_terrain_cells")[cell] = terrain
			var texture: Texture2D = scene.call("_tile_texture_for_cell", cell)
			counts[texture] = counts.get(texture, 0) + 1
	_check(counts.size() == 4 and counts[variants[0]] >= 7800 and counts[variants[0]] <= 8200, "The main tile occupies 80 percent and three variants share the remainder")
	var cell := HERO + Vector2i.DOWN
	var path: String = scene.get("_chunk_path_template") % [0, 0]
	var original := FileAccess.get_file_as_string(path)
	scene.call("_set_terrain_cell", HERO + Vector2i.LEFT, DEMO.TileType.FLOOR)
	scene.call("_save_loaded_chunks")
	_check(FileAccess.get_file_as_string(path) == original, "Unrelated gameplay state remains excluded from Save")
	scene.call("_toggle_editor")
	scene.call("_select_editor_object", "bedrock")
	scene.call("_paint_selected_tile", cell)
	var texture: Texture2D = scene.call("_tile_texture_for_cell", cell)
	scene.call("_save_loaded_chunks")
	var rows := FileAccess.get_file_as_string(path).split("\n")
	_check(rows[cell.y][cell.x] == "B" and rows[HERO.y][HERO.x - 1] == original.split("\n")[HERO.y][HERO.x - 1] and scene.get("_editor_changes").is_empty(), "Save writes bedrock B while preserving unrelated authored cells")
	var loader := DEMO.CHUNK_LOADER.new(scene.get("_chunk_path_template"), DEMO.CHUNK_SIZE)
	loader.request(Vector2i.ZERO)
	for frame in range(600):
		if loader.has_ready(Vector2i.ZERO):
			break
		await process_frame
	var loaded := loader.take_ready(Vector2i.ZERO)
	loader.close()
	_check(not loaded.is_empty() and loaded.error.is_empty() and loaded.cells[cell.y * 64 + cell.x] == terrain and loaded.earth[remote.y * 64 + remote.x] == 0, "The background worker preserves bedrock and never converts it to earth")
	scene.call("_build_scene")
	_check(scene.call("_terrain_type", cell) == terrain and scene.call("_tile_texture_for_cell", cell) == texture, "A new run reloads the edited cell and its stable visual variant")
	scene.free()


func _check_blocking_and_tools() -> void:
	var scene := await _fixture({}, {ORIGIN: "B"})
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_hero_cell") == HERO and scene.get("_turn_queue").current_turn == 0 and not scene.call("_is_walkable", ORIGIN) and not scene.call("_is_terrain_visible_through", ORIGIN), "Bedrock blocks movement and sight without spending an action")
	var material: ShaderMaterial = scene.call("_create_tile_diffusion_material", ORIGIN)
	_check(material.get_shader_parameter("outline_left") and not material.get_shader_parameter("diffuse_left"), "Bedrock uses existing walkability outlines without stitching")
	_check(CATALOG.tool_for_terrain(DEMO.TileType.BEDROCK).is_empty() and not CATALOG.can_place_on("weak_club", DEMO.TileType.BEDROCK), "No key or pickaxe can target bedrock, and actors cannot be placed inside it")
	_add(scene, "pickaxe")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	_key(scene, KEY_D)
	_key(scene, KEY_SPACE)
	_check(scene.call("_field_target_is_active") and scene.get("_inventory_item_ids").has("pickaxe") and scene.get("_turn_queue").current_turn == 0 and scene.get("_hero_magic") == 10 and scene.call("_terrain_type", ORIGIN) == DEMO.TileType.BEDROCK, "Invalid digging keeps its target adjustable and spends neither item nor turn")
	_key(scene, KEY_ESCAPE)
	scene.free()
	scene = await _fixture({ORIGIN: "weak_club"}, {HERO + Vector2i.RIGHT * 3: "B"})
	var id: int = scene.get("_goblins_by_cell")[ORIGIN]
	_cast(scene)
	_settle(scene)
	_check(scene.get("_goblins")[id].cell == SHORE and not scene.get("_goblins_by_cell").has(HERO + Vector2i.RIGHT * 3), "Pushed creatures stop before bedrock rather than flying into or through it")
	scene.free()


func _check_blast(chain: bool) -> void:
	var origin := HERO + Vector2i.RIGHT * 4
	var rock := origin + Vector2i.UP
	var terrain := {rock: "B", origin + Vector2i.DOWN: "B", origin + Vector2i(-1, 1): "B", origin + Vector2i(1, -1): "#", origin + Vector2i.RIGHT: "D", origin + Vector2i(1, 1): "%"}
	var scene := await _fixture({}, terrain)
	var path: String = scene.get("_chunk_path_template") % [0, 0]
	var source := FileAccess.get_file_as_string(path)
	var texture: Texture2D = scene.call("_tile_texture_for_cell", rock)
	scene.set("_hero_cell", origin)
	_settle(scene)
	_add(scene, "bomb")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
	_settle(scene)
	if chain:
		scene.set("_hero_cell", origin + Vector2i.LEFT)
		_settle(scene)
		_add(scene, "bomb")
		scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("bomb"))
		_settle(scene)
		scene.set("_hero_cell", HERO)
		_settle(scene)
		scene.call("_explode_bomb", origin)
	else:
		for step in range(3):
			scene.call("_try_move_hero", Vector2i.LEFT)
			_settle(scene)
	_check(scene.get("_bombs_by_cell").is_empty() and scene.get("_hero_strength") == 10, "Real bomb detonation completes outside hero range, including chain explosions")
	for cell: Vector2i in terrain:
		var expected := DEMO.TileType.BEDROCK if terrain[cell] == "B" else (DEMO.TileType.EARTH_FLOOR if terrain[cell] == "%" else DEMO.TileType.FLOOR)
		_check(scene.call("_terrain_type", cell) == expected, "Bedrock survives while ordinary masonry, doors and earth still break: " + str(cell))
	_check(scene.call("_tile_texture_for_cell", rock) == texture and not scene.call("_is_walkable", rock) and not scene.call("_is_terrain_visible_through", rock), "A surviving tile retains art, collision and opacity")
	scene.call("_save_loaded_chunks")
	_check(FileAccess.get_file_as_string(path) == source and scene.get("_editor_changes").is_empty(), "Neither blast results nor bedrock immunity create editor changes")
	scene.free()
