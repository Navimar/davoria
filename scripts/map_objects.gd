extends RefCounted

const CATALOG := preload("res://scripts/game_objects.gd")
const LEVEL := preload("res://scripts/starter_level.gd")


static func defaults() -> Dictionary:
	var objects: Dictionary = {LEVEL.HERO_START_CELL: "hero_start"}
	for cell in LEVEL.SWORD_CELLS:
		objects[cell] = "sword"
	for cabinet in LEVEL.POTION_CABINETS:
		objects[cabinet.cell] = "potion_cabinet"
	for goblin in LEVEL.GOBLINS:
		objects[goblin.cell] = goblin.type
	for elemental in LEVEL.WATER_ELEMENTALS:
		objects[elemental.cell] = elemental.type
	for boss in LEVEL.BOSSES:
		objects[boss.cell] = "skeletal_horse"
	return objects


static func path_for_chunks(chunk_template: String) -> String:
	return chunk_template.get_base_dir().path_join("objects.json")


static func read_map(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"objects": defaults(), "error": ""}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary or not json.data.get("objects") is Array:
		return {"objects": {}, "error": "Invalid map objects: %s" % path}
	var objects: Dictionary = {}
	for entry in json.data.objects:
		if not entry is Dictionary or not entry.get("cell") is Array or entry.cell.size() != 2 or not entry.get("type") is String:
			return {"objects": {}, "error": "Invalid map object record: %s" % path}
		# Removed short-sword goblins migrate to the remaining weak type.
		var type_id: String = "weak_club" if entry.type == "weak_sword" else entry.type
		var definition := CATALOG.definition(type_id)
		if definition.is_empty() or definition.category == "terrain" or not entry.cell[0] is float or not entry.cell[1] is float or entry.cell[0] != int(entry.cell[0]) or entry.cell[1] != int(entry.cell[1]):
			return {"objects": {}, "error": "Unknown or invalid map object: %s" % str(entry)}
		var cell := Vector2i(int(entry.cell[0]), int(entry.cell[1]))
		# Legacy hand-placed crystals are ignored; procedural pickups are runtime
		# state and must never enter the authoring data or conflict with other objects.
		if definition.get("procedural", false):
			continue
		if objects.has(cell):
			return {"objects": {}, "error": "Duplicate map object at %s" % str(cell)}
		objects[cell] = type_id
	return {"objects": objects, "error": ""}


static func save_map(path: String, objects: Dictionary) -> bool:
	var cells: Array = objects.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var records: Array[Dictionary] = []
	for cell: Vector2i in cells:
		if CATALOG.definition(objects[cell]).get("procedural", false):
			continue
		# Only authoring data: never strength rolls, loot, movement or broken state.
		records.append({"type": objects[cell], "cell": [cell.x, cell.y]})
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		return false
	var temporary_path := "%s.tmp-%d" % [absolute_path, OS.get_process_id()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "objects": records}, "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary_path, absolute_path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return false
	return true
