extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
const GRID := preload("res://scripts/grid_config.gd")
const HERO := Vector2i(10, 10)
const ORIGIN := HERO + Vector2i.RIGHT
const SHORE := HERO + Vector2i.RIGHT * 2
const LANDING := ORIGIN + Vector2i.RIGHT * DEMO.PUSH_DISTANCE
var _errors: Array[String] = []
var _folders: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for definition: Dictionary in CATALOG.definitions():
		if definition.category == "enemy":
			await _check_death(definition.id)
	await _check_flyover()
	await _check_swimmers()
	await _check_blockers()
	await _check_speed()
	await _check_fog_and_restart()
	for folder in _folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("FORCED IMMERSION OK: every current enemy, can_swim/requires_water, final landing only and flyover, immediate death/AI/collision removal, no strength reward, pixel-aligned sink and cleanup, surviving swimmers, obstacles, speed, fog, unchanged authored map/restart and ordinary death")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _fixture(objects: Dictionary, terrain: Dictionary = {}) -> Node2D:
	var folder := "/private/tmp/davoria_immersion_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), _folders.size()]
	_folders.append(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		var row := ""
		for x in range(64):
			row += terrain.get(Vector2i(x, y), "." if x >= 2 and x <= 25 and y >= 2 and y <= 25 else "#")
		file.store_line(row)
	file.close()
	var map := objects.duplicate()
	map[HERO] = "hero_start"
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(template), map), "Isolated immersion map is created")
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	while scene.get("_encounter_prompt").is_open():
		scene.get("_encounter_prompt").call("_accept")
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	return scene


func _check_death(type_id: String) -> void:
	var aquatic := type_id == "water_elemental"
	var terrain := {ORIGIN: "~"} if aquatic else {LANDING: "~"}
	var scene := await _fixture({ORIGIN: type_id}, terrain)
	var actor_id: int = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[actor_id]
	var texture: Texture2D = enemy.sprite.texture
	_check(enemy.can_swim == aquatic and enemy.requires_water == aquatic, "Current swimming/water-dependence flags match " + type_id)
	_cast(scene)
	_check(not scene.get("_goblins").has(actor_id) and not scene.get("_goblins_by_cell").has(ORIGIN) and not scene.get("_goblins_by_cell").has(LANDING) and not scene.get("_actor_blocked_cells").has(ORIGIN) and not scene.get("_actor_blocked_cells").has(LANDING) and not scene.get("_turn_queue").get("_positions").has(actor_id) and not scene.get("_encounter_candidates").has(actor_id), "Lethal displacement immediately releases AI, queue, occupancy and encounter state for " + type_id)
	_check(scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10 and scene.get("_hero_magic") == 11 and scene.get("_turn_queue").current_turn == 1 and not scene.get("_inventory_item_ids").has("push_scroll") and not scene.get("_petrified"), "Immersion gives no strength reward and one scroll action for " + type_id)
	_check(scene.get("_sinking_actors").size() == 1 and scene.get("_sinking_actors").values().has(LANDING), "Sinking begins only at the resolved landing cell for " + type_id)
	if scene.get("_sinking_actors").is_empty():
		scene.free()
		return
	var effect: Sprite2D = scene.get("_sinking_actors").keys()[0]
	var tween: Tween = effect.get("_sink_tween")
	tween.pause()
	_check(effect.texture == texture and effect.scale == Vector2.ONE and effect.material.shader == DEMO.WATER_SUBMERGE_SHADER and effect.find_child("Strength", true, false) == null and effect.find_child("ContactShadow", true, false) == null, "Death animation retains native art and the hero's clipping shader without a live label or shadow")
	tween.custom_step(DEMO.HERO_MOVE_DURATION * 0.5)
	_check(effect.position.x > scene.call("_cell_center", ORIGIN).x and effect.position.x < scene.call("_cell_center", LANDING).x and effect.material.get_shader_parameter("submerged_pixels") == 0.0, "Travel reaches the lethal tile before sinking starts")
	tween.custom_step(DEMO.HERO_MOVE_DURATION * 0.5 + DEMO.ACTOR_SINK.SINK_DURATION * 0.5)
	_check(effect.position.is_equal_approx(scene.call("_cell_center", LANDING)) and effect.offset == GRID.ACTOR_DRAW_OFFSET + Vector2(0, 32) and effect.material.get_shader_parameter("submerged_pixels") == 32.0, "Midway immersion lowers and clips precisely 32 native pixels")
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(effect.offset == GRID.ACTOR_DRAW_OFFSET + Vector2(0, 32) and tween.is_valid() and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 2, "A new hero action leaves the visual sink intact and cannot grant strength or permit retaliation")
	scene.call("_save_loaded_chunks")
	var saved := OBJECTS.read_map(OBJECTS.path_for_chunks(scene.get("_chunk_path_template")))
	_check(saved.objects.get(ORIGIN) == type_id and not saved.objects.has(LANDING) and scene.get("_editor_object_changes").is_empty(), "Drowning never replaces authored spawns with runtime deaths or sinking effects")
	tween.custom_step(DEMO.ACTOR_SINK.SINK_DURATION * 0.5 + 0.01)
	_check(scene.get("_sinking_actors").is_empty() and effect.material.get_shader_parameter("submerged_pixels") == 64.0, "Full immersion clips the entire picture and unregisters its visual effect")
	await process_frame
	_check(not is_instance_valid(effect), "Finished sink frees its temporary sprite")
	scene.free()


func _check_swimmers() -> void:
	var water: Dictionary = {}
	for distance in range(1, 7):
		water[HERO + Vector2i.RIGHT * distance] = "~"
	var scene := await _fixture({ORIGIN: "water_elemental"}, water)
	var actor_id: int = scene.get("_goblins_by_cell")[ORIGIN]
	_check(scene.call("_enemy_can_step", SHORE, "water", true) and not scene.call("_enemy_can_step", HERO, "water", true), "Swimming elementals still choose water-only steps rather than voluntary dry-land movement")
	scene.get("_goblins")[actor_id].retaliates_only = true
	scene.call("_sync_active_goblins")
	_cast(scene)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_goblins").has(actor_id) and scene.get("_goblins")[actor_id].cell == ORIGIN + Vector2i.RIGHT * 5 and scene.get("_sinking_actors").is_empty() and scene.get("_hero_strength") == 10, "An elemental pushed entirely through water survives without a death reward")
	scene.free()

	var definition := CATALOG.definition("weak_club").duplicate()
	definition.id = "fixture_swimmer"
	definition.can_swim = true
	CATALOG.definitions().append(definition)
	water.erase(ORIGIN)
	scene = await _fixture({ORIGIN: definition.id}, water)
	actor_id = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[actor_id]
	enemy.retaliates_only = true
	scene.call("_sync_active_goblins")
	_check(enemy.can_swim and not enemy.requires_water and scene.call("_enemy_can_step", SHORE, "floor", true) and not scene.call("_enemy_can_step", SHORE, "floor", false), "Catalog swimming flag reaches runtime and enables voluntary water steps for a land type")
	_cast(scene)
	scene.call("_finish_hero_move", false)
	_check(scene.get("_goblins").has(actor_id) and enemy.cell == ORIGIN + Vector2i.RIGHT * 5 and scene.get("_sinking_actors").is_empty() and scene.get("_hero_strength") == 10, "A swimming land creature crosses the shore and survives the entire push")
	scene.call("_remove_goblin", actor_id)
	_check(scene.get("_sinking_actors").is_empty(), "Ordinary removal still disappears without a sink animation")
	scene.free()
	CATALOG.definitions().erase(definition)


func _check_flyover() -> void:
	for definition: Dictionary in CATALOG.definitions():
		if definition.category != "enemy":
			continue
		var aquatic: bool = definition.get("requires_water", false)
		var terrain: Dictionary = {}
		for distance in range(1, DEMO.PUSH_DISTANCE):
			terrain[ORIGIN + Vector2i.RIGHT * distance] = "." if aquatic else "~"
		if aquatic:
			terrain[ORIGIN] = "~"
			terrain[LANDING] = "~"
		var scene := await _fixture({ORIGIN: definition.id}, terrain)
		var id: int = scene.get("_goblins_by_cell")[ORIGIN]
		var enemy: Dictionary = scene.get("_goblins")[id]
		_check(scene.call("_push_adjacent", Vector2i.RIGHT) and scene.get("_goblins").has(id) and enemy.cell == LANDING and enemy.knocked_down and scene.get("_sinking_actors").is_empty(), "Creature crosses unsafe intermediate cells and falls at its safe final landing: " + definition.id)
		_check(scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10 and not scene.get("_actor_blocked_cells").has(ORIGIN) and scene.get("_actor_blocked_cells").has(LANDING), "Safe landing grants no death reward and moves occupancy once: " + definition.id)
		_check(not scene.call("_enemy_can_step", SHORE, "water" if aquatic else "floor", aquatic), "Flight does not grant voluntary movement in an unsafe habitat: " + definition.id)
		var tween: Tween = scene.get("_push_tweens")[enemy.sprite].tween
		tween.pause()
		tween.custom_step(DEMO.HERO_MOVE_DURATION * 0.5)
		_check(enemy.sprite.position.x > scene.call("_cell_center", ORIGIN).x and enemy.sprite.position.x < scene.call("_cell_center", LANDING).x and enemy.cell == LANDING and scene.get("_sinking_actors").is_empty(), "Visual transit over hazardous terrain does not trigger sinking: " + definition.id)
		scene.call("_finish_goblin_animations")
		_check(enemy.sprite.position.is_equal_approx(scene.call("_cell_center", LANDING)) and scene.get("_goblins").has(id), "Creature finishes the flight at the safe landing cell: " + definition.id)
		scene.free()
	# An obstacle changes the resolved landing. Only the last reachable cell
	# before it decides survival, even when earlier cells were also dangerous.
	for obstacle in ["#", "D", "enemy"]:
		for water_landing in [true, false]:
			var destination := ORIGIN + Vector2i.RIGHT * 3
			var barrier := destination + Vector2i.RIGHT
			var terrain := {SHORE: "~", destination: "~" if water_landing else "."}
			var objects := {ORIGIN: "weak_club"}
			if obstacle == "enemy":
				objects[barrier] = "strong_guard"
			else:
				terrain[barrier] = obstacle
			var scene := await _fixture(objects, terrain)
			var id: int = scene.get("_goblins_by_cell")[ORIGIN]
			_check(scene.call("_push_adjacent", Vector2i.RIGHT), "Obstacle permits travel to the last free cell")
			if water_landing:
				_check(not scene.get("_goblins").has(id) and scene.get("_sinking_actors").values().has(destination) and scene.get("_hero_strength") == 10, "Obstacle forces a water landing and no drowning reward: " + obstacle)
			else:
				_check(scene.get("_goblins").has(id) and scene.get("_goblins")[id].cell == destination and scene.get("_sinking_actors").is_empty() and scene.get("_hero_strength") == 10, "Obstacle permits a safe landing beyond intermediate water: " + obstacle)
			if obstacle == "enemy":
				_check(scene.get("_goblins_by_cell").has(barrier), "The blocking creature remains in place")
			scene.free()


func _check_blockers() -> void:
	var scene := await _fixture({ORIGIN: "weak_club", SHORE: "water_elemental"}, {SHORE: "~"})
	_cast(scene)
	_check(scene.get("_goblins").size() == 2 and scene.get("_goblins_by_cell").has(ORIGIN) and scene.get("_goblins_by_cell").has(SHORE) and scene.get("_sinking_actors").is_empty() and scene.get("_inventory_item_ids").has("push_scroll") and scene.get("_turn_queue").current_turn == 0, "An occupied water cell blocks a push without drowning either creature or spending a scroll")
	scene.free()
	for obstacle in ["#", "D"]:
		scene = await _fixture({ORIGIN: "weak_club"}, {SHORE: obstacle, SHORE + Vector2i.RIGHT: "~"})
		_cast(scene)
		_check(scene.get("_goblins_by_cell").has(ORIGIN) and scene.get("_sinking_actors").is_empty() and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 0, "Walls and doors still prevent reaching lethal water")
		scene.free()


func _check_speed() -> void:
	var scene := await _fixture({ORIGIN: "weak_club"}, {LANDING: "~"})
	var actor_id: int = scene.get("_goblins_by_cell")[ORIGIN]
	var enemy: Dictionary = scene.get("_goblins")[actor_id]
	enemy.retaliates_only = true
	scene.call("_sync_active_goblins")
	_add(scene, "speed_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("speed_potion"))
	scene.call("_finish_hero_move", false)
	enemy.retaliates_only = false
	scene.call("_sync_active_goblins")
	_cast(scene)
	_check(not scene.get("_goblins").has(actor_id) and not scene.get("_turn_queue").get("_positions").has(actor_id) and scene.get("_turn_queue").current_turn == 1 and scene.get("_speed_actions_this_turn") == 1 and scene.get("_speed_boost_turns") == 10 and scene.get("_hero_strength") == 10, "A fast half-action still kills and cancels the enemy immediately without advancing the world")
	scene.call("_finish_hero_move", false)
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)
	_check(scene.get("_turn_queue").current_turn == 2 and scene.get("_speed_boost_turns") == 9 and scene.get("_hero_strength") == 10 and scene.get("_hero_magic") == 12, "Completing the fast pair advances once and preserves starting strength and one scroll magic gain")
	scene.free()


func _check_fog_and_restart() -> void:
	var destination := HERO + Vector2i.RIGHT * 6
	var scene := await _fixture({ORIGIN: "weak_club"}, {destination: "~"})
	_cast(scene)
	_check(scene.get("_sinking_actors").values().has(destination), "Forced death may occur just beyond the hero's field of view")
	if scene.get("_sinking_actors").is_empty():
		scene.free()
		return
	var effect: Sprite2D = scene.get("_sinking_actors").keys()[0]
	effect.get("_sink_tween").pause()
	_check(not effect.visible and effect.modulate.a == 0.0, "A hidden sinking sprite cannot peek out of fog at its original visible cell")
	var fog: ColorRect = scene.get("_fog_cells")[destination]
	fog.self_modulate.a = 0.4
	scene.call("_update_visibility_at_cell", destination)
	_check(effect.visible and is_equal_approx(effect.modulate.a, 0.6), "A local fog update fades the sinking effect by its own cell")
	fog.self_modulate.a = 1.0
	scene.call("_update_enemy_visibility")
	_check(not effect.visible and effect.modulate.a == 0.0, "Fog closes over the entire dying picture without exposing protruding pixels")
	scene.call("_build_scene")
	await process_frame
	_check(scene.get("_sinking_actors").is_empty() and not is_instance_valid(effect) and scene.get("_goblins_by_cell").has(ORIGIN) and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 0, "Restart cancels effects and restores the authored living spawn and starting strength")
	scene.free()


func _cast(scene: Node2D) -> void:
	_add(scene, "push_scroll")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("push_scroll"))
	_key(scene, KEY_D)
	_key(scene, KEY_SPACE)


func _add(scene: Node2D, id: String) -> void:
	scene.call("_add_inventory_item", load(CATALOG.definition(id).path), id)


func _key(scene: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	scene.call("_unhandled_key_input", event)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
