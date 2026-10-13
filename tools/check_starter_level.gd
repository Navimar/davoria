extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const SIGHT := preload("res://scripts/actor_sight.gd")
const GOBLIN_TYPES := preload("res://scripts/goblin_types.gd")
const MAP_OBJECTS := preload("res://scripts/map_objects.gd")
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]
var _errors: Array[String] = []
var _cells: Dictionary = {}
var _cabinet_cells: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_layout()
	await _check_runtime()
	if _errors.is_empty():
		print("LEVEL CHECK OK: safe entry, sword before enemy sight, reachable encounters, both branches, symmetric closed-door blocking, shared player/creature sight and diagonal visibility")
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
	# Water placements also occupy the existing northern chunk.
	var north_rows := FileAccess.get_file_as_string(LEVEL.CHUNK_PATH_TEMPLATE % [0, -1]).strip_edges().split("\n")
	for y in range(64):
		for x in range(64):
			_cells[Vector2i(x, y - 64)] = north_rows[y][x]
	var entry := LEVEL.HERO_START_CELL
	var reachable_before := _reachable_cells(entry)
	for cabinet in LEVEL.POTION_CABINETS:
		_cabinet_cells[cabinet.cell] = true
	var reachable_after := _reachable_cells(entry)
	for cell in reachable_before:
		_check(_cabinet_cells.has(cell) or reachable_after.has(cell), "Cabinets never cut off previously reachable terrain")
	_check(_walkable(entry, {}), "Entry stands on walkable terrain")
	var enemy_cells: Dictionary = {}
	var used_types: Dictionary = {}
	for spawn in LEVEL.ENEMIES:
		var expected_tile := "~" if spawn.get("type", "") == "water_elemental" else "."
		_check(_cells.get(spawn.cell) == expected_tile, "Enemy placement matches its habitat")
		_check(not enemy_cells.has(spawn.cell), "Every enemy has its own starting cell")
		enemy_cells[spawn.cell] = true
		_check(_path_length(entry, spawn.cell) > 0, "Enemy encounter is reachable")
		_check(not SIGHT.contains(entry, spawn.cell), "Entry is outside enemy sight")
	for spawn in LEVEL.GOBLINS:
		_check(spawn.has("type") and not spawn.has("strength"), "Goblin placement specifies type instead of fixed strength")
		_check(not GOBLIN_TYPES.definition(spawn.type).is_empty(), "Every placed goblin references a known type")
		used_types[spawn.type] = true
	_check(LEVEL.GOBLINS.size() >= 30 and used_types.size() == GOBLIN_TYPES.TYPES.size(), "Map contains many goblins and all three selected visual types")
	_check(LEVEL.BOSSES.size() == 1 and LEVEL.BOSSES[0].strength == 200, "One boss starts with two hundred strength")
	_check(_path_length(entry, LEVEL.BOSSES[0].cell) > _path_length(entry, Vector2i(29, 14)) + 30, "Boss occupies a reachable room far beyond the existing hall")
	var objects: Dictionary = MAP_OBJECTS.read_map(MAP_OBJECTS.path_for_chunks(LEVEL.CHUNK_PATH_TEMPLATE)).objects
	for sword: Vector2i in objects:
		if objects[sword] != "sword":
			continue
		_check(_path_length(entry, sword) > 0, "Starting sword is reachable")
		for spawn in LEVEL.ENEMIES:
			_check(not SIGHT.contains(sword, spawn.cell), "Sword is available before entering any goblin's sight")
	var occupied := {LEVEL.HERO_START_CELL: true}
	for cell in LEVEL.SWORD_CELLS:
		occupied[cell] = true
	for spawn in LEVEL.ENEMIES:
		occupied[spawn.cell] = true
	for cabinet in LEVEL.POTION_CABINETS:
		var cell: Vector2i = cabinet.cell
		_check(not occupied.has(cell), "Cabinet placement avoids actors and starting items")
		occupied[cell] = true
		var beside_wall := false
		var reachable_approach := false
		for direction in CARDINALS:
			beside_wall = beside_wall or _cells.get(cell + direction) == "#"
			reachable_approach = reachable_approach or reachable_after.has(cell + direction)
		_check(_cells.get(cell) == "." and beside_wall and reachable_approach, "Each cabinet stands against a wall with a reachable neighboring cell")
	_check(LEVEL.POTION_CABINETS.size() == 10, "Ten wall cabinets retain their authored positions without configured contents")
	var hall := Vector2i(29, 14)
	var fork := Vector2i(26, 29)
	_check(_path_length(fork, hall, {Vector2i(26, 24): true, Vector2i(27, 24): true}) > 0, "Detour reaches the hall when direct passage is blocked")
	_check(_path_length(fork, hall, {Vector2i(38, 24): true, Vector2i(39, 24): true}) > 0, "Direct passage reaches the hall when detour is blocked")


func _walkable(cell: Vector2i, excluded: Dictionary) -> bool:
	if excluded.has(cell) or _cabinet_cells.has(cell) or not _cells.has(cell):
		return false
	return _cells[cell] != "#" and _cells[cell] != "D"


func _reachable_cells(entry: Vector2i) -> Dictionary:
	var seen := {entry: true}
	var queue: Array[Vector2i] = [entry]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in CARDINALS:
			var neighbor := cell + direction
			if not seen.has(neighbor) and _walkable(neighbor, {}):
				seen[neighbor] = true
				queue.append(neighbor)
	return seen


func _path_length(origin: Vector2i, target: Vector2i, excluded: Dictionary = {}) -> int:
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
			if not distances.has(next) and _walkable(next, excluded):
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

	# Isolate movement checks from authored objects and random pickups.
	for actor_id: int in scene.get("_goblins").keys():
		scene.call("_remove_goblin", actor_id)
	scene.get("_cabinets").clear()
	scene.get("_props_by_cell").clear()
	scene.get("_items_by_cell").clear()
	for door_cell: Vector2i in [Vector2i(7, 30), Vector2i(30, 10)]:
		scene.call("_set_terrain_cell", door_cell, DEMO.TileType.DOOR)
		for direction: Vector2i in CARDINALS:
			var approach := door_cell + direction
			scene.call("_set_terrain_cell", approach, DEMO.TileType.FLOOR)
			for hasted: bool in [false, true]:
				scene.set("_speed_boost_turns", 3 if hasted else 0)
				scene.set("_speed_actions_this_turn", 1 if hasted else 0)
				scene.set("_hero_cell", approach)
				scene.call("_finish_hero_move", false)
				var before: int = queue.current_turn
				scene.call("_try_move_hero", -direction)
				_check(scene.get("_hero_cell") == approach and hero.position == scene.call("_cell_center", approach), "A closed door blocks the same real movement from all four directions")
				_check(scene.call("_terrain_type", door_cell) == DEMO.TileType.DOOR and not scene.call("_is_walkable", door_cell) and not scene.call("_is_terrain_visible_through", door_cell), "Blocked movement never changes a door or its movement/sight flags")
				_check(queue.current_turn == before and not scene.get("_is_moving") and scene.get("_speed_actions_this_turn") == (1 if hasted else 0) and scene.get("_speed_boost_turns") == (3 if hasted else 0), "A closed door spends neither a normal turn nor a fast half-action")
	scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
