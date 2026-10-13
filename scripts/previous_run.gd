extends RefCounted

const CATALOG := preload("res://scripts/game_objects.gd")


static func read_record(path: String, map_key: String, hero_paths: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or parsed.get("version") != 1 or parsed.get("map") != map_key or parsed.get("kind") not in ["grave", "statue"]:
		return {}
	var cell: Variant = parsed.get("cell")
	if not cell is Array or cell.size() != 2:
		return {}
	for coordinate in cell:
		if not (coordinate is float or coordinate is int) or coordinate != int(coordinate) or absf(coordinate) > 2147483647:
			return {}
	var item_id: String = parsed.get("item_id", "") if parsed.get("item_id", "") is String else ""
	if CATALOG.definition(item_id).get("category", "") != "item":
		item_id = ""
	var hero_path: String = parsed.get("hero_path", "") if parsed.get("hero_path", "") is String else ""
	if not hero_paths.has(hero_path):
		hero_path = hero_paths[0] if not hero_paths.is_empty() else ""
	return {"kind": parsed.kind, "cell": Vector2i(int(cell[0]), int(cell[1])), "item_id": item_id, "hero_path": hero_path,
		"flip_h": parsed.get("flip_h", false) == true, "destroyed": parsed.get("destroyed", false) == true}


static func write_record(path: String, map_key: String, record: Dictionary) -> bool:
	var cell: Vector2i = record.cell
	# A single record replaces the previous death. Never serialize the whole
	# inventory, current map, older graves or a list of completed runs.
	var data := {"version": 1, "map": map_key, "kind": record.kind, "cell": [cell.x, cell.y],
		"item_id": record.get("item_id", ""), "hero_path": record.hero_path,
		"flip_h": record.get("flip_h", false), "destroyed": record.get("destroyed", false)}
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary := "%s.tmp-%d" % [absolute, OS.get_process_id()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true
