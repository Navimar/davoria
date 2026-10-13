extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const CATALOG := preload("res://scripts/game_objects.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DEMO.SPEED_POTION_PATH))
	_check(image.get_size() == Vector2i(64, 64), "Speed potion uses native 64px canvas")
	var reserved := Image.load_from_file(ProjectSettings.globalize_path("res://assets/items/potions/series_01/13_amber_round.png"))
	_check(image.get_data() == reserved.get_data(), "Speed potion reuses the prepared amber bottle without resizing")
	var pool := CATALOG.potion_pool()
	_check(pool.size() == 7 and pool.count("health_potion") == 3 and pool.count("strength_potion") == 2 and pool.count("water_breathing_potion") == 1 and pool.count("speed_potion") == 1, "Generator weights are 3/2/1/1")
	var folder := "/private/tmp/davoria_speed_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	var template := folder.path_join("chunk_%d_%d.txt")
	var file := FileAccess.open(template % [0, 0], FileAccess.WRITE)
	for y in range(64):
		file.store_line("##" + ".".repeat(14) + "#".repeat(48) if y >= 2 and y < 16 else "#".repeat(64))
	file.close()
	OBJECTS.save_map(OBJECTS.path_for_chunks(template), {Vector2i(5, 5): "hero_start"})
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", template)
	root.add_child(scene)
	await process_frame
	for cell: Vector2i in scene.get("_items_by_cell").keys():
		scene.call("_remove_procedural_item", cell)
	_check(scene.get("_editor_palette").get_children().any(func(button: Button) -> bool: return button.get_meta("object_type", "") == DEMO.ITEM_ID_SPEED_POTION), "Speed potion automatically appears in the editor")
	var queue: RefCounted = scene.get("_turn_queue")
	_drink(scene, DEMO.ITEM_ID_SPEED_POTION)
	_check(queue.current_turn == 1 and scene.get("_hero_magic") == 11 and scene.get("_speed_boost_turns") == 10, "Initial drinking costs one world turn, lasts ten subsequent world turns and grants magic")
	_check(scene.get("_stats_speed_label").text == "Скорость: 10 ход." and scene.get("_stats_speed_label").visible, "Speed has a normal text label and duration")
	scene.call("_finish_hero_move", false)
	_check(queue.current_turn == 1 and scene.get("_speed_actions_this_turn") == 0, "Animation completion never spends the extra action")
	var enemy_id: int = scene.call("_spawn_goblin", Vector2i(8, 5), "weak_club")
	scene.call("_sync_active_goblins")
	var enemy: Dictionary = scene.get("_goblins")[enemy_id]
	var position: Vector2i = enemy.cell
	_wait(scene)
	_check(queue.current_turn == 1 and enemy.cell == position and scene.get("_speed_boost_turns") == 10, "First action advances neither the enemy queue nor the duration")
	_wait(scene)
	_check(queue.current_turn == 2 and enemy.cell != position and scene.get("_speed_boost_turns") == 9, "Second action advances the actual enemies and duration exactly once")
	scene.call("_remove_goblin", enemy_id)
	scene.call("_set_terrain_cell", Vector2i(5, 4), DEMO.TileType.WALL)
	scene.call("_try_move_hero", Vector2i.UP)
	_check(queue.current_turn == 2 and scene.get("_speed_actions_this_turn") == 0, "Blocked movement spends no half-action")
	scene.call("_add_inventory_item", load(DEMO.HEALTH_POTION_PATH), DEMO.ITEM_ID_HEALTH_POTION)
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").size() - 1)
	_check(queue.current_turn == 2 and scene.get("_speed_actions_this_turn") == 0, "Full-strength healing spends no half-action")
	# A fresh duration followed by exactly two actions per remaining world turn.
	var magic: int = scene.get("_hero_magic")
	_drink(scene, DEMO.ITEM_ID_SPEED_POTION)
	_wait(scene)
	var before: int = queue.current_turn
	_check(scene.get("_speed_boost_turns") == magic, "Renewal lasts pre-use magic without stacking speed")
	for action in range(1, magic * 2 + 1):
		_wait(scene)
		_check(queue.current_turn == before + action / 2 and scene.get("_speed_boost_turns") == magic - action / 2, "Exactly two accepted actions consume one world turn until expiry")
	_wait(scene)
	_check(queue.current_turn == before + magic + 1 and not scene.get("_stats_speed_label").visible, "The very next action after expiry returns to normal cadence")
	_drink(scene, DEMO.ITEM_ID_SPEED_POTION)
	scene.call("_finish_hero_move", false)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_hero_cell") == Vector2i(6, 5) and queue.current_turn == before, "First fast movement reaches the next logical cell without advancing the world")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_hero_cell") == Vector2i(7, 5) and queue.current_turn == before + 1, "A responsive second movement finishes the prior animation and commits one world turn")
	scene.call("_finish_hero_move", false)
	before = queue.current_turn
	_drink(scene, DEMO.ITEM_ID_SPEED_POTION)
	_check(queue.current_turn == before and scene.get("_speed_actions_this_turn") == 1, "Renewing speed uses the first half of the existing pair")
	_drink(scene, DEMO.ITEM_ID_SPEED_POTION)
	_check(queue.current_turn == before + 1 and scene.get("_speed_actions_this_turn") == 0 and scene.get("_speed_boost_turns") == scene.get("_hero_magic") - 1, "Repeated renewal cannot reset the phase to avoid enemy turns")
	var duration: int = scene.get("_hero_magic")
	before = queue.current_turn
	_drink(scene, DEMO.ITEM_ID_STRENGTH_POTION)
	_wait(scene)
	_check(queue.current_turn == before + 1 and scene.get("_strength_boost_turns") == duration, "A strength potion started on the free action keeps its full duration through the paired world turn")
	_wait(scene)
	_wait(scene)
	_check(scene.get("_strength_boost_turns") == duration - 1, "Strength duration follows world time while hasted")
	duration = scene.get("_hero_magic") * DEMO.WATER_BREATHING_MAGIC_FACTOR
	_drink(scene, DEMO.ITEM_ID_WATER_BREATHING_POTION)
	_wait(scene)
	_check(scene.get("_water_breathing_turns") == duration, "New water breathing also retains its full duration through a pair")
	_wait(scene)
	_wait(scene)
	_check(scene.get("_water_breathing_turns") == duration - 1, "Water breathing ticks once per paired world turn")
	# Environmental time and blocked attacks use the same cadence.
	scene.set("_water_breathing_turns", 0)
	scene.set("_speed_boost_turns", 5)
	scene.call("_set_terrain_cell", Vector2i(7, 6), DEMO.TileType.WATER)
	scene.set("_hero_cell", Vector2i(7, 6))
	scene.set("_was_in_water", true)
	scene.set("_hero_breath", 7)
	scene.call("_finish_hero_move", false)
	_wait(scene)
	_check(scene.get("_hero_breath") == 7, "The free action consumes no breath")
	_wait(scene)
	_check(scene.get("_hero_breath") == 6, "The paired world turn consumes one breath")
	scene.call("_try_move_hero", Vector2i.UP)
	_check(scene.get("_hero_breath") == 30 and not scene.get("_was_in_water"), "A free move to land immediately restores breath")
	scene.call("_finish_hero_move", false)
	_wait(scene)
	enemy_id = scene.call("_spawn_goblin", Vector2i(8, 5), "weak_club")
	scene.set("_hero_strength", 0)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(queue.current_turn == before and scene.get("_speed_actions_this_turn") == 0, "An exhausted blocked attack spends no half-action")
	scene.call("_remove_goblin", enemy_id)
	scene.set("_hero_strength", 10)
	scene.set("_hero_cell", Vector2i(5, 5))
	scene.call("_finish_hero_move", false)
	scene.call("_add_potion_cabinet", Vector2i(4, 5))
	scene.get("_cabinets")[Vector2i(4, 5)].contents.assign([DEMO.ITEM_ID_HEALTH_POTION, DEMO.ITEM_ID_STRENGTH_POTION])
	before = queue.current_turn
	for action in range(1, 5):
		scene.call("_try_move_hero", Vector2i.LEFT)
		scene.call("_finish_hero_move", false)
		_check(queue.current_turn == before + action / 2, "Loot, breakage and movement each use one half-action")
	_check(scene.get("_hero_cell") == Vector2i(4, 5) and not scene.get("_cabinets").has(Vector2i(4, 5)), "Fast looting preserves cabinet contents and breakage behavior")
	# The editor creates a real pickup without special palette code.
	scene.call("_set_editor_map_object", Vector2i(5, 5), DEMO.ITEM_ID_SPEED_POTION)
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_inventory_item_ids").has(DEMO.ITEM_ID_SPEED_POTION), "An editor-placed speed potion enters the real inventory")
	var slot: int = scene.get("_inventory_item_ids").find(DEMO.ITEM_ID_SPEED_POTION)
	var icon: TextureRect = scene.get("_inventory_slot_icons")[slot]
	_check(icon.texture.resource_path == DEMO.SPEED_POTION_PATH and icon.get_parent().get_parent().tooltip_text.contains("2 действия на ход мира"), "Speed pickup has its chosen sprite and readable effect tooltip")
	# Death with a half-finished turn must not leak phase or pending buff state.
	scene.set("_hero_strength", -11)
	scene.call("_check_hero_death")
	await process_frame
	await process_frame
	_check(scene.get("_speed_boost_turns") == 0 and scene.get("_speed_actions_this_turn") == 0 and scene.get("_effects_started_this_turn").is_empty() and not scene.get("_stats_speed_label").visible and scene.get("_inventory_item_ids") == [DEMO.ITEM_ID_GHOST_RING], "Death/restart clears speed, half-turn phase, pending effects and inventory")
	scene.free()
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("SPEED POTION OK: weight 1, native reserved sprite, automatic editor/inventory, 2 actions per world turn, real enemy cadence, exact duration, blocked actions, responsive movement, renewal, simultaneous buffs, breath, cabinet actions and death reset")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _drink(scene: Node2D, item_id: String) -> void:
	_check(scene.call("_add_inventory_item", load(CATALOG.definition(item_id).path), item_id), "Potion fixture fits in inventory")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").size() - 1)


func _wait(scene: Node2D) -> void:
	scene.call("_wait_hero_turn")
	scene.call("_finish_hero_move", false)


func _check(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
