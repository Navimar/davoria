extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	var scene := await _fixture({})
	var template: String = scene.get("_chunk_path_template")
	var file_path := template % [0, 0]
	var original := FileAccess.get_file_as_string(file_path)
	_check(scene.call("_terrain_type", Vector2i(1, 10)) == DEMO.TileType.WALL and scene.call("_terrain_type", Vector2i(1, 1)) == DEMO.TileType.WALL, "Edges and diagonal corners beside rooms retain masonry")
	_check(scene.call("_terrain_type", Vector2i(0, 10)) == DEMO.TileType.EARTH and scene.call("_terrain_type", Vector2i(40, 40)) == DEMO.TileType.EARTH and not scene.call("_is_walkable", Vector2i(40, 40)) and not scene.call("_is_terrain_visible_through", Vector2i(40, 40)), "The surrounding mass is solid opaque earth")
	var source: PackedByteArray = scene.get("_saved_chunk_cells")[Vector2i.ZERO]
	_check(source[40 * 64 + 40] == DEMO.TileType.WALL and scene.get("_editor_changes").is_empty(), "Earth presentation does not mutate authored legacy terrain")
	scene.call("_set_terrain_cell", Vector2i(39, 40), DEMO.TileType.FLOOR)
	_check(scene.call("_terrain_type", Vector2i(40, 40)) == DEMO.TileType.EARTH, "A gameplay hole cannot reclassify nearby earth into masonry")
	for id in ["earth", "earth_floor"]:
		_check(scene.get("_editor_palette").get_children().any(func(button: Button): return button.get_meta("object_type", "") == id), "Catalog automatically exposes terrain in editor: " + id)
	for terrain in [DEMO.TileType.EARTH, DEMO.TileType.EARTH_FLOOR]:
		var variants: Array = scene.get("_tile_variants")[terrain]
		_check(variants.size() == 8 and variants.all(func(texture: Texture2D): return texture.get_size() == Vector2(64, 64)), "Earth walls and passages have eight native 64px sprites")
		var counts: Dictionary = {}
		for y in range(100):
			for x in range(100):
				var cell := Vector2i(100 + x, 100 + y)
				scene.get("_terrain_cells")[cell] = terrain
				var texture: Texture2D = scene.call("_tile_texture_for_cell", cell)
				counts[texture] = counts.get(texture, 0) + 1
		_check(counts.get(variants[0], 0) >= 7800 and counts.get(variants[0], 0) <= 8200 and counts.size() == 8, "Terrain uses 80 percent base and shared 20 percent alternatives")
	var earth := Vector2i(0, 10)
	scene.set("_hero_cell", Vector2i(1, 10))
	scene.call("_finish_hero_move", false)
	_add(scene, "pickaxe")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("pickaxe"))
	_check(scene.call("_field_target_is_active") and not scene.get("_door_prompt").is_open(), "A pickaxe uses field targeting for solid earth")
	_key(scene, KEY_A)
	_key(scene, KEY_SPACE)
	scene.call("_finish_hero_move", false)
	_check(scene.call("_terrain_type", earth) == DEMO.TileType.EARTH_FLOOR and scene.call("_is_walkable", earth) and scene.call("_is_terrain_visible_through", earth) and scene.get("_turn_queue").current_turn == 1, "Digging produces a passable earthen passage for one action")
	_check(scene.call("_enemy_can_step", earth, "floor", false) and not scene.call("_enemy_can_step", earth, "water", true) and CATALOG.can_place_on("potion_cabinet", DEMO.TileType.EARTH_FLOOR), "Land creatures and furniture accept earthen passages, water creatures do not")
	scene.call("_save_loaded_chunks")
	_check(FileAccess.get_file_as_string(file_path) == original, "Gameplay digging is never saved as editor work")
	scene.call("_set_editor_terrain_cell", Vector2i(30, 30), DEMO.TileType.EARTH)
	scene.call("_set_editor_terrain_cell", Vector2i(31, 30), DEMO.TileType.EARTH_FLOOR)
	scene.call("_save_loaded_chunks")
	var raw := DEMO.CHUNK_LOADER.read_chunk(Vector2i.ZERO, template, DEMO.CHUNK_SIZE)
	_check(raw.cells[30 * 64 + 30] == DEMO.TileType.EARTH and raw.cells[30 * 64 + 31] == DEMO.TileType.EARTH_FLOOR and raw.cells[10 * 64] == DEMO.TileType.WALL, "Editor saves explicit earth and passage characters while preserving gameplay and other source cells")
	# A room touching a chunk edge must preserve masonry in its neighboring chunk,
	# even before that chunk or its neighbor has been loaded into the scene.
	var neighbor_path := template % [1, 0]
	var neighbor := FileAccess.open(neighbor_path, FileAccess.WRITE)
	for y in range(64):
		neighbor.store_line("#".repeat(64))
	neighbor.close()
	var source_rows := FileAccess.get_file_as_string(file_path).split("\n")
	source_rows[10] = source_rows[10].substr(0, 63) + "."
	var source_file := FileAccess.open(file_path, FileAccess.WRITE)
	source_file.store_string("\n".join(source_rows))
	source_file.close()
	raw = DEMO.CHUNK_LOADER.read_chunk(Vector2i(1, 0), template, DEMO.CHUNK_SIZE)
	_check(raw.earth[10 * 64] == 0 and raw.earth[10 * 64 + 1] == 1, "Authored halo preserves exactly one masonry layer across a chunk seam")
	scene.free()
	scene = await _fixture({ORIGIN: "water_elemental"}, {ORIGIN: "~", LANDING: ":"})
	_cast(scene)
	_check(scene.get("_goblins").is_empty() and scene.get("_sinking_actors").values().has(LANDING), "Pushing a water elemental into an earthen passage starts its land death")
	scene.free()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("EARTH BIOME OK: authored masonry shell including corners/seams, opaque surrounding earth, eight native variants at 80/20, dynamic editor, pickaxe passages and land habitats, gameplay-only digging and exact source-only Save")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)
