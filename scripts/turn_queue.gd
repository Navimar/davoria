extends RefCounted

var current_turn := 0
var _sequence := 0
var _heap: Array[Dictionary] = []
var _positions: Dictionary = {}


func schedule_after(actor_id: int, delay: int) -> void:
	cancel(actor_id)
	_sequence += 1
	_push({"id": actor_id, "wake_at": current_turn + maxi(delay, 1), "sequence": _sequence})


func cancel(actor_id: int) -> void:
	if _positions.has(actor_id):
		_remove_at(int(_positions[actor_id]))


func advance() -> void:
	current_turn += 1


func pop_due() -> int:
	if _heap.is_empty() or int(_heap[0].wake_at) > current_turn:
		return -1
	var actor_id := int(_heap[0].id)
	_remove_at(0)
	return actor_id


func _push(entry: Dictionary) -> void:
	_heap.append(entry)
	var index := _heap.size() - 1
	_positions[entry.id] = index
	_sift_up(index)


func _remove_at(index: int) -> void:
	_positions.erase(_heap[index].id)
	var last: Dictionary = _heap.pop_back()
	if index >= _heap.size():
		return
	_heap[index] = last
	_positions[last.id] = index
	index = _sift_up(index)
	_sift_down(index)


func _sift_up(index: int) -> int:
	while index > 0:
		var parent := (index - 1) / 2
		if not _before(_heap[index], _heap[parent]):
			break
		_swap(index, parent)
		index = parent
	return index


func _sift_down(index: int) -> void:
	while index * 2 + 1 < _heap.size():
		var child := index * 2 + 1
		if child + 1 < _heap.size() and _before(_heap[child + 1], _heap[child]):
			child += 1
		if not _before(_heap[child], _heap[index]):
			break
		_swap(index, child)
		index = child


func _swap(a: int, b: int) -> void:
	var swap := _heap[a]
	_heap[a] = _heap[b]
	_heap[b] = swap
	_positions[_heap[a].id] = a
	_positions[_heap[b].id] = b


func _before(a: Dictionary, b: Dictionary) -> bool:
	return a.wake_at < b.wake_at or (a.wake_at == b.wake_at and a.sequence < b.sequence)
