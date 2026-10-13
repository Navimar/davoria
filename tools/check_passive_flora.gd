extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const TYPES := preload("res://scripts/flora_types.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const FUNGUS_CELL := Vector2i(6, 5)
const MUSHROOM_RANGES := {
	"brown_mushroom": Vector2i(5, 30),
	"red_mushroom": Vector2i(31, 65),
	"violet_mushroom": Vector2i(66, 99),
}
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for type: Dictionary in TYPES.TYPES:
		var image := Image.load_from_file(ProjectSettings.globalize_path(type.path))
		_check(image.get_size() == Vector2i(64, 64) and image.get_used_rect().end.y == 64 and maxi(image.get_used_rect().size.x, image.get_used_rect().size.y) == 64, "Flora fills its native 64px cell without post-pixelization scaling")
		for y in range(64):
			for x in range(64):
				_check(image.get_pixel(x, y).a in [0.0, 1.0], "Flora opacity is binary")
	var folder := "/private/tmp/davoria_passive_flora_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		file.store_line("##" + ".".repeat(14) + "#".repeat(48) if y >= 2 and y < 16 else "#".repeat(64))
	file.close()
	var map := {Vector2i(5, 5): "hero_start", FUNGUS_CELL: "red_mushroom", Vector2i(4, 8): "violet_mushroom", Vector2i(5, 8): "brown_mushroom", Vector2i(6, 8): "thorn_bush"}
	var map_path := OBJECTS.path_for_chunks(template)
	OBJECTS.save_map(map_path, map)
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	var queue: RefCounted = scene.get("_turn_queue")
	var actors: Dictionary = scene.get("_goblins")
	var id: int = scene.get("_goblins_by_cell")[FUNGUS_CELL]
	var fungus: Dictionary = actors[id]
	var starting_strength: int = fungus.strength
	_check(actors.size() == 4 and queue.get("_positions").is_empty(), "Only passive flora exists in the fixture and none is scheduled")
	for actor: Dictionary in actors.values():
		_check(actor.retaliates_only and not actor.active and actor.sprite.scale == Vector2.ONE and actor.sprite.offset == DEMO.GRID.ACTOR_DRAW_OFFSET, "Every type shares passive behavior and native actor rendering")
		_check_starting_strength(actor)
		_check(not scene.call("_is_walkable", actor.cell) and scene.call("_is_terrain_visible_through", actor.cell), "Rooted flora blocks movement but passes sight")
		_check(scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == actor.type), "Every selected type is automatically available in the editor")
	for action in range(100):
		_wait(scene)
	_check(scene.get("_hero_strength") == 10 and fungus.strength == starting_strength and fungus.cell == FUNGUS_CELL and queue.get("_positions").is_empty(), "One hundred adjacent waits cause no attacks, movement, rerolls or queue entries")
	var flip: bool = fungus.sprite.flip_h
	scene.set("_hero_cell", Vector2i(3, 5))
	scene.call("_finish_hero_move", false)
	scene.call("_update_enemy_facing")
	scene.set("_hero_cell", Vector2i(9, 5))
	scene.call("_finish_hero_move", false)
	scene.call("_update_enemy_facing")
	_check(fungus.sprite.flip_h == flip and fungus.sprite.position == scene.call("_cell_center", FUNGUS_CELL), "Passive flora does not turn to follow the hero")
	scene.set("_hero_cell", Vector2i(5, 5))
	scene.call("_finish_hero_move", false)
	queue.schedule_after(id, 1)
	scene.call("_take_goblin_turn", id)
	scene.call("_advance_world_turn")
	_check(scene.get("_hero_strength") == 10 and fungus.strength == starting_strength and fungus.last_seen == null and queue.get("_positions").is_empty(), "Direct AI calls and stale scheduled entries cannot activate passive flora")
	_check_strength_rolls(scene)
	var normal_id: int = scene.call("_spawn_goblin", Vector2i(8, 5), "weak_club")
	scene.call("_sync_active_goblins")
	_check(queue.get("_positions").has(normal_id) and not queue.get("_positions").has(id), "Ordinary enemies still enter the queue alongside passive flora")
	_wait(scene)
	_check(actors[normal_id].cell != Vector2i(8, 5) and fungus.cell == FUNGUS_CELL, "An ordinary goblin acts while the fungus stays rooted")
	scene.call("_remove_goblin", normal_id)
	# Combat fixture: fix health independently of the initial tier roll.
	fungus.strength = 10
	var before: int = queue.current_turn
	_seed_exchange(scene, int(fungus.strength), true)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(fungus.strength == 9 and scene.get("_hero_strength") == 10 and queue.current_turn == before + 1 and scene.get("_hero_cell") == Vector2i(5, 5), "A player hit uses the existing strength exchange without entering the fungus cell")
	scene.call("_finish_hero_move", false)
	_seed_exchange(scene, int(fungus.strength), false)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(fungus.strength == 9 and scene.get("_hero_strength") == 9 and scene.get("_goblin_tweens").has(id), "The fungus can retaliate within the initiated exchange, with a response animation")
	scene.call("_finish_hero_move", false)
	for action in range(20):
		_wait(scene)
	_check(fungus.strength == 9 and scene.get("_hero_strength") == 9 and queue.get("_positions").is_empty(), "Hitting flora never enables subsequent autonomous retaliation")
	scene.set("_hero_strength", 0)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(queue.current_turn == before and fungus.strength == 9, "An exhausted hero cannot attack flora")
	scene.set("_hero_strength", 10)
	scene.set("_speed_boost_turns", 3)
	for action in range(2):
		_seed_exchange(scene, int(fungus.strength), true)
		scene.call("_try_move_hero", Vector2i.RIGHT)
		scene.call("_finish_hero_move", false)
	_check(fungus.strength == 7 and queue.current_turn == before + 1 and scene.get("_speed_boost_turns") == 2, "Speed gives two initiated exchanges and no autonomous flora turn")
	scene.set("_speed_boost_turns", 0)
	fungus.strength = 1
	_seed_exchange(scene, 1, true)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(not actors.has(id) and not fungus.sprite.visible and scene.call("_is_walkable", FUNGUS_CELL) and scene.get("_hero_strength") == 11 and scene.get("_hero_max_strength") == 11, "Destroyed flora disappears, frees the cell and awards the normal one-strength reward")
	scene.call("_finish_hero_move", false)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_hero_cell") == FUNGUS_CELL, "The next action can enter the freed cell")
	scene.call("_set_editor_map_object", Vector2i(4, 6), "thorn_bush")
	var placed_id: int = scene.get("_goblins_by_cell")[Vector2i(4, 6)]
	_check(actors[placed_id].retaliates_only and actors[placed_id].strength == 10, "Editor placement picks up passive behavior from the catalog")
	var editor_cell := Vector2i(5, 6)
	for type_id: String in MUSHROOM_RANGES:
		scene.call("_set_editor_map_object", editor_cell, type_id)
		placed_id = scene.get("_goblins_by_cell")[editor_cell]
		_check_starting_strength(actors[placed_id])
		_check(actors[placed_id].retaliates_only and not queue.get("_positions").has(placed_id), "Editor mushrooms use their tier without joining the queue")
		editor_cell.x += 1
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(map_path)
	_check(saved.objects[FUNGUS_CELL] == "red_mushroom" and saved.objects[Vector2i(4, 6)] == "thorn_bush", "Save keeps authored types after damage/destruction")
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(map_path)).objects:
		_check(record.size() == 2, "Map records contain only type and cell, not health or behavior state")
	scene.call("_build_scene")
	await process_frame
	actors = scene.get("_goblins")
	id = scene.get("_goblins_by_cell")[FUNGUS_CELL]
	_check(actors[id].retaliates_only and scene.get("_turn_queue").get("_positions").is_empty(), "Restart restores destroyed flora and never schedules it")
	for actor: Dictionary in actors.values():
		_check_starting_strength(actor)
	scene.free()
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("PASSIVE FLORA OK: native sprites, mushroom tiers 5-30/31-65/66-99, random rolls, catalog/editor, 100 idle turns without rerolls, no movement/facing/AI/queue, ordinary enemy coexistence, attack-only retaliation, response animation, exhaustion, speed, destruction/reward, source-only Save and fresh strength on restart")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_starting_strength(actor: Dictionary) -> void:
	if MUSHROOM_RANGES.has(actor.type):
		var limits: Vector2i = MUSHROOM_RANGES[actor.type]
		_check(actor.strength >= limits.x and actor.strength <= limits.y, "Each mushroom rolls strength within its own visual tier")
	else:
		_check(actor.type == "thorn_bush" and actor.strength == 10, "Thorn bush retains its fixed strength")


func _check_strength_rolls(scene: Node2D) -> void:
	var rng: RandomNumberGenerator = scene.get("_rng")
	var expected_tiers := {"brown_mushroom": "weak", "red_mushroom": "medium", "violet_mushroom": "strong"}
	for type_id: String in MUSHROOM_RANGES:
		var definition := DEMO.OBJECT_CATALOG.definition(type_id)
		_check(definition.strength_range == MUSHROOM_RANGES[type_id] and definition.tier == expected_tiers[type_id] and not definition.has("strength"), "Catalog carries the mushroom's range and tier instead of a fixed strength")
		var values: Dictionary = {}
		for seed_value in range(64):
			rng.seed = seed_value
			var actor_id: int = scene.call("_spawn_enemy", Vector2i(9, 8), type_id)
			var actor: Dictionary = scene.get("_goblins")[actor_id]
			_check_starting_strength(actor)
			_check(actor.tier == expected_tiers[type_id] and actor.sprite.texture.resource_path == definition.path, "Live spawning preserves the tier's sprite and strength")
			values[actor.strength] = true
			scene.call("_remove_goblin", actor_id)
		_check(values.size() > 1, "Spawning a mushroom rolls varied strength rather than one constant")


func _seed_exchange(scene: Node2D, enemy_strength: int, player_hit: bool) -> void:
	var rng: RandomNumberGenerator = scene.get("_rng")
	var power: int = scene.get("_hero_strength")
	for candidate in range(1000):
		rng.seed = candidate
		if (rng.randi_range(0, power + enemy_strength - 1) < power) == player_hit:
			rng.seed = candidate
			return
	_check(false, "A deterministic combat roll can select either side")


func _wait(scene: Node2D) -> void:
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
