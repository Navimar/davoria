extends SceneTree

const SCENE := preload("res://scenes/asset_demo.tscn")
const PROFILE := preload("res://tools/monster_profile_scene.gd")
var _report: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _sample(0)
	await _sample(400)
	print(JSON.stringify({"mode": "headless CPU; nested timings are inclusive", "samples": _report}))
	quit()


func _sample(requested_count: int) -> void:
	var scene: Node2D = SCENE.instantiate()
	scene.set_script(PROFILE)
	scene.set("_remains_save_path", "/private/tmp/davoria_profile_unused_%d.json" % OS.get_process_id())
	root.add_child(scene)
	await process_frame
	if scene.get("_encounter_prompt").is_open():
		scene.get("_encounter_prompt").call("_accept")
	scene.get("_seen_encounters")["cockatrice"] = true
	for cell: Vector2i in scene.get("_terrain_cells"):
		if scene.get("_goblins").size() >= requested_count:
			break
		var delta: Vector2i = cell - scene.get("_hero_cell")
		if maxi(absi(delta.x), absi(delta.y)) > 12 and scene.call("_enemy_can_step", cell, "floor"):
			scene.call("_spawn_enemy", cell, "weak_club")
	for enemy: Dictionary in scene.get("_goblins").values():
		if enemy.get("type") == "cockatrice":
			enemy.retaliates_only = true
	scene.set("_hero_strength", 1000000)
	scene.set("_hero_max_strength", 1000000)
	scene.get("_rng").seed = 1729
	scene.call("_sync_active_goblins")
	var population: int = scene.get("_goblins").size()
	scene.get("measurements").clear()
	var durations: Array[int] = []
	for turn in range(40):
		var started := Time.get_ticks_usec()
		scene.call("_advance_world_turn")
		durations.append(Time.get_ticks_usec() - started)
		scene.call("_finish_goblin_animations")
	var turns: Dictionary = scene.get("measurements").duplicate(true)
	durations.sort()
	scene.get("measurements").clear()
	var frames_started := Time.get_ticks_usec()
	for frame in range(100):
		scene.call("_update_enemy_visibility")
	var visibility_average := float(Time.get_ticks_usec() - frames_started) / 100
	scene.get("measurements").clear()
	var fogs: Dictionary = scene.get("_fog_cells")
	for cell: Vector2i in fogs:
		scene.call("_set_fog_visibility", cell, true, false)
		scene.call("_set_fog_visibility", cell, false, true)
	await create_timer(PROFILE.FOG_FADE_DURATION * 1.4).timeout
	var fade: Dictionary = scene.get("measurements").duplicate(true)
	_report.append({"population": population, "turn_median_usec": durations[durations.size() / 2], "turn_max_usec": durations.back(), "forty_turns_inclusive": turns,
		"visibility_call_average_usec": visibility_average, "fog_rectangles": fogs.size(), "fade_inclusive": fade})
	scene.free()
	await process_frame
