extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LOADER := preload("res://scripts/chunk_loader.gd")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_background_data()
	await _check_scene_streaming()
	if _errors.is_empty():
		print("CHUNK STREAMING CHECK OK: background data, exact terrain, bounded graphics, incremental preparation, both chunk boundaries, outlines, editor changes and worker restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _wait_ready(loader: RefCounted, chunk: Vector2i) -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while not loader.has_ready(chunk) and Time.get_ticks_msec() < deadline:
		await process_frame
	return loader.has_ready(chunk)


func _check_background_data() -> void:
	var loader := LOADER.new(DEMO.CHUNK_PATH_TEMPLATE, DEMO.CHUNK_SIZE)
	loader.request(Vector2i.ZERO)
	loader.request(Vector2i.ZERO)
	_check(await _wait_ready(loader, Vector2i.ZERO), "Background worker completes a queued chunk")
	var data := loader.take_ready(Vector2i.ZERO)
	_check(not data.is_empty() and data.error.is_empty(), "Background data validates the saved map")
	if not data.is_empty() and data.error.is_empty():
		var cells: PackedByteArray = data.cells
		var file := FileAccess.open(DEMO.CHUNK_PATH_TEMPLATE % [0, 0], FileAccess.READ)
		var y := 0
		while not file.eof_reached():
			var row := file.get_line()
			if row.is_empty():
				continue
			for x in range(row.length()):
				var expected := DEMO.TileType.FLOOR
				match row[x]:
					"#": expected = DEMO.TileType.WALL
					"~": expected = DEMO.TileType.WATER
					"D": expected = DEMO.TileType.DOOR
				_check(cells[y * DEMO.CHUNK_SIZE.x + x] == expected, "Worker preserves the saved cell type")
			y += 1
		_check(y == DEMO.CHUNK_SIZE.y and cells.size() == DEMO.CHUNK_SIZE.x * DEMO.CHUNK_SIZE.y, "Worker returns one complete chunk")
		var immediate := LOADER.read_chunk(Vector2i.ZERO, DEMO.CHUNK_PATH_TEMPLATE, DEMO.CHUNK_SIZE)
		_check(immediate.cells == cells, "Immediate fallback and background loading use identical terrain")
	_check(loader.take_ready(Vector2i.ZERO).is_empty(), "Published data is consumed once")
	# Closing with outstanding work must join the worker without touching a scene.
	for x in range(1, 8):
		loader.request(Vector2i(x, 0))
	loader.close()
	_check(not loader.get("_thread").is_started(), "Closing joins an active or waiting worker")


func _check_scene_streaming() -> void:
	var scene: Node2D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	var loader: RefCounted = scene.get("_chunk_loader")
	var new_chunk := Vector2i(1, 0)
	_check(await _wait_ready(loader, new_chunk), "Neighbor data is prefetched before approaching its boundary")
	var sprites: Dictionary = scene.get("_tile_sprites")
	var fog: Dictionary = scene.get("_fog_cells")
	var before := sprites.size()
	scene.call("_load_chunk", new_chunk)
	_check(sprites.size() == before and fog.size() == before, "Loading collision data never builds 4096 offscreen tiles")
	_check(scene.call("_terrain_type", Vector2i(64, 30)) == DEMO.TileType.WALL, "An absent chunk stays solid rather than becoming walkable while loading")
	for x in range(60, 68):
		scene.call("_set_terrain_cell", Vector2i(x, 30), DEMO.TileType.FLOOR)
	scene.call("_set_terrain_cell", Vector2i(63, 31), DEMO.TileType.FLOOR)
	scene.call("_set_terrain_cell", Vector2i(64, 31), DEMO.TileType.WALL)
	scene.call("_set_terrain_cell", Vector2i(65, 31), DEMO.TileType.WATER)
	scene.call("_set_terrain_cell", Vector2i(66, 31), DEMO.TileType.DOOR)
	scene.set("_hero_cell", Vector2i(62, 30))
	scene.call("_finish_hero_move", false)
	_check_core(scene)
	before = sprites.size()
	scene.call("_build_queued_tiles")
	_check(sprites.size() - before <= DEMO.TILE_BUILD_BATCH_SIZE, "Outer margin preparation respects its per-frame batch")
	for x in range(63, 67):
		scene.call("_try_move_hero", Vector2i.RIGHT)
		_check(scene.get("_hero_cell") == Vector2i(x, 30), "A normal move crosses the positive chunk boundary without waiting")
		_check_core(scene)
		scene.call("_finish_hero_move", false)
	var wall: Sprite2D = sprites[Vector2i(64, 31)]
	_check(wall.material.get_shader_parameter("outline_left"), "A wall outline sees the walkable neighbor in the adjacent chunk")
	_check(scene.call("_is_walkable", Vector2i(65, 31)) and not scene.call("_is_walkable", Vector2i(66, 31)), "Water and doors retain their collision rules after crossing")
	var material := wall.material
	scene.call("_load_chunk", Vector2i(7, 7))
	_check(wall.material == material, "Loading distant terrain does not rebuild unrelated tile materials")
	for center: Vector2i in [Vector2i(-1, 30), Vector2i(64, -1), Vector2i(-64, -64), Vector2i(192, 192), Vector2i(64, 30)]:
		scene.set("_hero_cell", center)
		scene.call("_finish_hero_move", false)
		_check_core(scene)
		for index in range(8):
			await process_frame
		_check(scene.get("_tile_build_queue").is_empty(), "The outer margin completes in subsequent frames")
		var wanted: Rect2i = scene.get("_render_rect")
		_check(sprites.size() == wanted.get_area() and fog.size() == sprites.size(), "Graphics remain bounded after many positive and negative chunk crossings")
		for cell: Vector2i in sprites:
			_check(wanted.has_point(cell), "Offscreen graphics are released outside the camera margin")
		for cell: Vector2i in scene.get("_fog_tweens"):
			_check(fog.has(cell), "Discarded cells leave no live fog tween")
	_check(scene.call("_terrain_type", Vector2i(64, 30)) == DEMO.TileType.FLOOR, "Edited terrain survives unloading and rebuilding its graphics")
	_check(sprites[Vector2i(64, 30)].texture == scene.call("_tile_texture_for_cell", Vector2i(64, 30)), "Rebuilt graphics use the edited terrain and stable tile variant")
	# The loader can still have prefetched copies, but an editor change is final
	# once the main thread has loaded that chunk.
	scene.call("_load_chunk", new_chunk)
	_check(scene.call("_terrain_type", Vector2i(64, 30)) == DEMO.TileType.FLOOR, "A later load request cannot replace editor changes with prefetched data")
	scene.call("_build_scene")
	_check(not loader.get("_thread").is_started() and scene.get("_chunk_loader") != loader, "Restart joins the previous worker and starts a fresh loader")
	scene.free()


func _check_core(scene: Node2D) -> void:
	var center: Vector2i = scene.get("_hero_cell")
	var sprites: Dictionary = scene.get("_tile_sprites")
	var fog: Dictionary = scene.get("_fog_cells")
	var radius := DEMO.RENDER_CORE_RADIUS
	var wanted: Rect2i = scene.get("_render_rect")
	_check(sprites.size() <= wanted.get_area(), "A move never instantiates a full chunk")
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			_check(sprites.has(cell) and fog.has(cell), "Visible cells and their fog exist immediately, before the next frame")


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
