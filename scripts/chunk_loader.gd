extends RefCounted

# The worker owns only file data. Nodes, terrain dictionaries and materials stay
# on the main thread; publishing completed buffers is protected by the mutex.
var _path_template: String
var _size: Vector2i
var _thread := Thread.new()
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _jobs: Array[Vector2i] = []
var _pending: Dictionary = {}
var _ready: Dictionary = {}
var _stopping := false


func _init(path_template: String, size: Vector2i) -> void:
	_path_template = path_template
	_size = size
	_thread.start(_run)


func request(chunk_coord: Vector2i) -> void:
	_mutex.lock()
	if _stopping or _pending.has(chunk_coord) or _ready.has(chunk_coord):
		_mutex.unlock()
		return
	_pending[chunk_coord] = true
	_jobs.append(chunk_coord)
	_mutex.unlock()
	_wake.post()


func take_ready(chunk_coord: Vector2i) -> Dictionary:
	_mutex.lock()
	var result: Dictionary = _ready.get(chunk_coord, {})
	_ready.erase(chunk_coord)
	_mutex.unlock()
	return result


func has_ready(chunk_coord: Vector2i) -> bool:
	_mutex.lock()
	var ready := _ready.has(chunk_coord)
	_mutex.unlock()
	return ready


func close() -> void:
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_wake.post()
	if _thread.is_started():
		_thread.wait_to_finish()


func _run() -> void:
	while true:
		_wake.wait()
		_mutex.lock()
		if _stopping:
			_mutex.unlock()
			return
		var chunk_coord: Vector2i = _jobs.pop_front()
		_mutex.unlock()
		var result := read_chunk(chunk_coord, _path_template, _size)
		_mutex.lock()
		if not _stopping:
			_ready[chunk_coord] = result
		_pending.erase(chunk_coord)
		_mutex.unlock()


static func read_chunk(chunk_coord: Vector2i, path_template: String, size: Vector2i) -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(size.x * size.y)
	cells.fill(1) # Missing chunks are solid walls, as in the map editor.
	var path := path_template % [chunk_coord.x, chunk_coord.y]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"cells": cells, "error": ""}
	var rows: Array[String] = []
	while not file.eof_reached():
		var row := file.get_line()
		if not row.is_empty():
			rows.append(row)
	if rows.size() != size.y:
		return {"cells": PackedByteArray(), "error": "Chunk %s has %d rows, expected %d" % [chunk_coord, rows.size(), size.y]}
	for y in range(size.y):
		if rows[y].length() != size.x:
			return {"cells": PackedByteArray(), "error": "Chunk %s row %d has width %d, expected %d" % [chunk_coord, y, rows[y].length(), size.x]}
		for x in range(size.x):
			match rows[y].unicode_at(x):
				35: cells[y * size.x + x] = 1 # Wall: #
				126: cells[y * size.x + x] = 2 # Water: ~
				68: cells[y * size.x + x] = 3 # Door: D
				_: cells[y * size.x + x] = 0 # Floor
	return {"cells": cells, "error": ""}
