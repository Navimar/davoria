extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const SIGHT := preload("res://scripts/actor_sight.gd")
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]
var _errors: Array[String] = []
var _cells: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_layout()
	await _check_runtime()
	if _errors.is_empty():
		print("LEVEL CHECK OK: safe entry, sword before enemy sight, reachable encounters, both branches, return shortcut, shared player/creature sight and diagonal visibility")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_layout() -> void:
	var rows := FileAccess.get_file_as_string(LEVEL.CHUNK_PATH_TEMPLATE % [0, 0]).strip_edges().split("\n")
	_check(rows.size() == 64, "Starter chunk has 64 rows")
	for y in range(rows.size()):
		_check(rows[y].length() == 64, "Starter chunk row width")
		for x in range(rows[y].length()):
			_cells[Vector2i(x, y)] = rows[y][x]
	var entry := LEVEL.HERO_START_CELL
	_check(_walkable(entry, {}), "Entry stands on walkable terrain")
	for spawn in LEVEL.GOBLINS:
		_check(_walkable(spawn.cell, {}), "Enemy stands on walkable terrain")
		_check(_path_length(entry, spawn.cell) > 0, "Enemy encounter is reachable")
		_check(not SIGHT.contains(entry, spawn.cell), "Entry is outside enemy sight")
	for sword in LEVEL.SWORD_CELLS:
		_check(_path_length(entry, sword) > 0, "Starting sword is reachable")
		_check(not SIGHT.contains(sword, LEVEL.FIRST_GOBLIN_CELL), "Sword is available before entering the first goblin's sight")
	var hall := Vector2i(29, 14)
	var fork := Vector2i(26, 29)
	_check(_path_length(fork, hall, {Vector2i(26, 24): true, Vector2i(27, 24): true}) > 0, "Detour reaches the hall when direct passage is blocked")
	_check(_path_length(fork, hall, {Vector2i(38, 24): true, Vector2i(39, 24): true}) > 0, "Direct passage reaches the hall when detour is blocked")
	var closed_distance := _path_length(entry, LEVEL.SHORTCUT_INSIDE_CELL)
	var open_distance := _path_length(entry, LEVEL.SHORTCUT_INSIDE_CELL, {}, true)
	_check(closed_distance > open_distance + 10, "Opening shortcut substantially shortens the return route")
	_check(_cells[LEVEL.SHORTCUT_DOOR] == "D", "Shortcut begins closed")


func _walkable(cell: Vector2i, excluded: Dictionary, open_shortcut := false) -> bool:
	if excluded.has(cell) or not _cells.has(cell):
		return false
	if open_shortcut and cell == LEVEL.SHORTCUT_DOOR:
		return true
	return _cells[cell] != "#" and _cells[cell] != "D"


func _path_length(origin: Vector2i, target: Vector2i, excluded: Dictionary = {}, open_shortcut := false) -> int:
	var queue: Array[Vector2i] = [origin]
	var distances := {origin: 0}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == target:
			return distances[cell]
		for direction in CARDINALS:
			var next := cell + direction
			if not distances.has(next) and _walkable(next, excluded, open_shortcut):
				distances[next] = int(distances[cell]) + 1
				queue.append(next)
	return -1


func _check_runtime() -> void:
	var scene: Node2D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var hero: Sprite2D = scene.get("_hero")
	var queue: RefCounted = scene.get("_turn_queue")
	# All origins, including creature cells, use the same calculation as the player.
	for origin in [LEVEL.HERO_START_CELL, LEVEL.FIRST_GOBLIN_CELL, Vector2i(26, 20), Vector2i(29, 14)]:
		var visible: Dictionary = scene.call("_calculate_visible_cells", origin)
		for y in range(origin.y - 6, origin.y + 7):
			for x in range(origin.x - 6, origin.x + 7):
				var target := Vector2i(x, y)
				_check(scene.call("_actor_can_see", origin, target) == visible.has(target), "Creature and player visibility agree")
	var fixture := DEMO.new()
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		fixture.call("_set_terrain_cell", direction, DEMO.TileType.WALL)
	for distance in range(7):
		fixture.call("_set_terrain_cell", Vector2i(distance, distance), DEMO.TileType.FLOOR)
	_check(fixture.call("_actor_can_see", Vector2i.ZERO, Vector2i(5, 5)), "Creature can see along an open diagonal past orthogonal blockers")
	_check(not fixture.call("_actor_can_see", Vector2i.ZERO, Vector2i(6, 6)), "Creature diagonal sight stops at the shared boundary")
	fixture.free()

	scene.set("_hero_cell", LEVEL.SHORTCUT_OUTSIDE_CELL)
	scene.call("_finish_hero_move", false)
	var before: int = queue.current_turn
	scene.call("_try_move_hero", Vector2i.UP)
	_check(scene.get("_hero_cell") == LEVEL.SHORTCUT_OUTSIDE_CELL and queue.current_turn == before, "Shortcut stays closed when approached from entry")
	_check(not scene.call("_is_walkable", LEVEL.SHORTCUT_DOOR), "Closed shortcut blocks entry")
	scene.set("_hero_cell", LEVEL.SHORTCUT_INSIDE_CELL)
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.DOWN)
	_check(scene.get("_hero_cell") == LEVEL.SHORTCUT_INSIDE_CELL and queue.current_turn == before + 1, "Opening from inside uses one action without moving")
	_check(scene.call("_is_walkable", LEVEL.SHORTCUT_DOOR), "Opening releases collision immediately")
	scene.call("_try_move_hero", Vector2i.DOWN)
	_check(scene.get("_hero_cell") == LEVEL.SHORTCUT_DOOR and queue.current_turn == before + 2, "Next action enters the opened door without duplicating the opening turn")
	await create_timer(DEMO.HERO_MOVE_DURATION * 2.0).timeout
	_check(hero.position == scene.call("_cell_center", LEVEL.SHORTCUT_DOOR), "Shortcut movement finishes on the grid")
	scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
