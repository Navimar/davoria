extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const HERO := Vector2i(5, 5)
const GATE := Vector2i(8, 6)
const FUNGUS := Vector2i(8, 7)
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var folder := "/private/tmp/davoria_enemy_fog_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			row += "~" if Vector2i(x, y) == Vector2i(12, 7) else ("." if (y == 5 and x >= 3 and x <= 30) or (y == 7 and x >= 4 and x <= 11) or (x == 5 and y >= 1 and y < 5) else "#")
		file.store_line(row)
	file.close()
	var map := {HERO: "hero_start", Vector2i(25, 5): "weak_club"}
	var types := ["weak_club", "medium_swordsman", "strong_guard", "brown_mushroom", "red_mushroom", "violet_mushroom", "thorn_bush", "skeletal_horse", "water_elemental"]
	for index in range(types.size()):
		map[Vector2i(4 + index, 7)] = types[index]
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(template), map), "Isolated visibility map is created")
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	var actors: Dictionary = scene.get("_goblins")
	var by_cell: Dictionary = scene.get("_goblins_by_cell")
	var fog_cells: Dictionary = scene.get("_fog_cells")
	var fungus: Dictionary = actors[by_cell[FUNGUS]]
	var fog := fog_cells[FUNGUS] as ColorRect
	var above_fog := fog_cells[FUNGUS + Vector2i.UP] as ColorRect
	var bounds: Rect2 = fungus.sprite.get_global_transform() * fungus.sprite.get_rect()
	_check(bounds.position.y < FUNGUS.y * DEMO.CELL_SIZE and is_zero_approx(above_fog.self_modulate.a), "Raised sprite protrudes into a revealed wall: the reported ears case")
	for actor: Dictionary in actors.values():
		_check_hidden(actor)
		_check(not scene.call("_is_walkable", actor.cell), "Hidden creatures keep their collision")
	_check(not scene.get("_turn_queue").get("_positions").is_empty(), "Hiding does not cancel autonomous turns")
	var far_id: int = by_cell[Vector2i(25, 5)]
	_check(not fog_cells.has(Vector2i(25, 5)), "Offscreen creature has no fog rectangle and still stays hidden")

	scene.call("_set_terrain_cell", GATE, DEMO.TileType.FLOOR)
	scene.call("_update_fog")
	# Sample the actual tween deterministically, independently of startup frame length.
	var reveal: Tween = scene.get("_fog_tweens")[FUNGUS]
	reveal.pause()
	reveal.custom_step(DEMO.FOG_FADE_DURATION * 0.25)
	scene.call("_update_enemy_visibility")
	var alpha: float = fungus.sprite.modulate.a
	_check(alpha > 0.0 and alpha < 1.0 and is_equal_approx(alpha, 1.0 - fog.self_modulate.a), "Creature fades in with its own cell")
	_check(fungus.sprite.is_visible_in_tree() and fungus.label.is_visible_in_tree() and fungus.sprite.get_node("ContactShadow").is_visible_in_tree(), "Sprite, strength and shadow appear together")
	_check(is_equal_approx(fungus.label.self_modulate.a, 1.0) and is_equal_approx(fungus.sprite.get_node("ContactShadow").self_modulate.a, 0.5), "Children inherit one fade; labels are not faded twice and shadow retains fifty percent opacity")
	scene.call("_set_terrain_cell", GATE, DEMO.TileType.WALL)
	scene.call("_update_fog")
	_check(is_equal_approx(fungus.sprite.modulate.a, alpha), "Reversal preserves current creature opacity")
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	_check_hidden(fungus)
	scene.call("_set_terrain_cell", GATE, DEMO.TileType.FLOOR)
	scene.call("_update_fog")
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	_check(fungus.sprite.visible and is_equal_approx(fungus.sprite.modulate.a, 1.0), "Visible creature reaches full opacity")

	# A newly registered actor must never spend a frame peeking out of a hidden cell.
	var visible_id: int = scene.call("_spawn_enemy", Vector2i(3, 5), "brown_mushroom")
	_check(actors[visible_id].sprite.visible and is_equal_approx(actors[visible_id].sprite.modulate.a, 1.0), "New visible creature appears immediately")
	scene.call("_set_terrain_cell", GATE, DEMO.TileType.WALL)
	scene.call("_update_fog")
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	var hidden_id: int = scene.call("_spawn_enemy", Vector2i(26, 5), "red_mushroom")
	_check_hidden(actors[hidden_id])
	scene.call("_remove_goblin", hidden_id)

	# A real AI step into revealed terrain updates visibility before its tween starts.
	var moving_id: int = by_cell[Vector2i(4, 7)]
	var moving: Dictionary = actors[moving_id]
	scene.call("_set_terrain_cell", Vector2i(4, 6), DEMO.TileType.FLOOR)
	scene.call("_update_fog")
	scene.call("_take_goblin_turn", moving_id)
	_check(moving.cell == Vector2i(4, 6) and moving.sprite.visible and is_equal_approx(moving.sprite.modulate.a, 1.0), "Enemy movement uses destination-cell visibility immediately")
	scene.call("_finish_goblin_animations")
	scene.call("_set_terrain_cell", Vector2i(4, 6), DEMO.TileType.WALL)
	scene.call("_update_fog")
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	scene.get("_actor_blocked_cells").erase(moving.cell)
	by_cell.erase(moving.cell)
	moving.cell = Vector2i(4, 7)
	scene.get("_actor_blocked_cells")[moving.cell] = true
	by_cell[moving.cell] = moving_id
	scene.call("_animate_goblin", moving_id, scene.call("_cell_center", moving.cell))
	_check_hidden(moving)
	scene.call("_finish_goblin_animations")

	scene.call("_set_ghost_mode", true)
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	for actor: Dictionary in actors.values():
		_check(actor.sprite.visible and actor.label.is_visible_in_tree() and is_equal_approx(actor.sprite.modulate.a, 1.0), "Ghost mode reveals creatures, including offscreen ones without fog sprites")
	var elemental: Dictionary = actors[by_cell[Vector2i(12, 7)]]
	_check(not elemental.sprite.get_node("ContactShadow").visible, "Visibility does not enable the water elemental's disabled shadow")
	scene.call("_set_ghost_mode", false)
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	_check_hidden(fungus)
	_check_hidden(actors[far_id])

	# Preserve the existing sliding edge, then hide the whole raised sprite as its cell exits.
	scene.call("_set_terrain_cell", GATE, DEMO.TileType.FLOOR)
	scene.call("_update_fog")
	await create_timer(DEMO.FOG_FADE_DURATION * 1.5).timeout
	scene.set("_hero_cell", Vector2i(5, 1))
	scene.call("_update_fog")
	_check(scene.get("_fog_cells_pending_hide").has(FUNGUS) and fungus.sprite.visible and is_equal_approx(fungus.sprite.modulate.a, 1.0), "Outgoing creature stays visible with its sliding tile without fading")
	var camera := scene.get("_camera") as Camera2D
	camera.position = scene.call("_cell_center", Vector2i(5, 1)) - Vector2(0.0, DEMO.FOG_OVERLAP + 1.0)
	camera.force_update_scroll()
	await process_frame
	scene.call("_hide_fog_cells_outside_view")
	scene.call("_update_enemy_visibility")
	_check(not scene.get("_fog_cells_pending_hide").has(FUNGUS), "Outgoing owner cell closes once it leaves the view")
	_check_hidden(fungus)
	var sprite: Sprite2D = moving.sprite
	scene.call("_remove_goblin", moving_id)
	scene.call("_update_enemy_visibility")
	_check(not sprite.visible and not actors.has(moving_id), "Visibility updates cannot resurrect a removed enemy")
	_check(scene.get("_turn_queue").current_turn == 0, "Visibility transitions never spend game turns")
	scene.free()
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("ENEMY FOG OK: raised sprite leaks, all creature types, shadow/label inheritance, fades/reversal, initial spawns, AI movement, ghost mode, offscreen fallback, edge sliding, collision/queue and removed actors")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_hidden(actor: Dictionary) -> void:
	_check(not actor.sprite.is_visible_in_tree() and is_zero_approx(actor.sprite.modulate.a), "Hidden creature's entire sprite is suppressed")
	_check(not actor.label.is_visible_in_tree() and not actor.sprite.get_node("ContactShadow").is_visible_in_tree(), "Hidden creature also hides its strength and shadow")


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
