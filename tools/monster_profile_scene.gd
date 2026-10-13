extends "res://scripts/asset_demo_scene.gd"

var measurements: Dictionary = {}


func _record_time(id: String, started: int) -> void:
	if not measurements.has(id):
		measurements[id] = {"calls": 0, "usec": 0}
	measurements[id].calls += 1
	measurements[id].usec += Time.get_ticks_usec() - started


func _check_enemy_encounters() -> bool:
	var started := Time.get_ticks_usec()
	var result := super._check_enemy_encounters()
	_record_time("encounters", started)
	return result


func _calculate_visible_cells(origin: Vector2i) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._calculate_visible_cells(origin)
	_record_time("full_sight", started)
	return result


func _take_goblin_turn(actor_id: int) -> void:
	var started := Time.get_ticks_usec()
	super._take_goblin_turn(actor_id)
	_record_time("enemy_turns", started)


func _actor_can_see(origin: Vector2i, target: Vector2i) -> bool:
	var started := Time.get_ticks_usec()
	var result := super._actor_can_see(origin, target)
	_record_time("enemy_sight", started)
	return result


func _update_enemy_visibility() -> void:
	var started := Time.get_ticks_usec()
	super._update_enemy_visibility()
	_record_time("all_actor_visibility", started)


func _refresh_combat_labels() -> void:
	var started := Time.get_ticks_usec()
	super._refresh_combat_labels()
	_record_time("labels", started)
