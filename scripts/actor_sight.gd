extends RefCounted

# One sight rule for the player and every creature until a specific ability overrides it.
const RADIUS := 5
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]


static func contains(cell: Vector2i, origin: Vector2i) -> bool:
	return maxi(absi(cell.x - origin.x), absi(cell.y - origin.y)) <= RADIUS


static func visible_cells(origin: Vector2i, known: Callable, transparent: Callable) -> Dictionary:
	var visible := {origin: true}
	var queue: Array[Vector2i] = [origin]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell != origin and not transparent.call(cell):
			continue
		for direction in DIRECTIONS:
			var next := cell + direction
			if visible.has(next) or not known.call(next) or not contains(next, origin):
				continue
			visible[next] = true
			if transparent.call(next):
				queue.append(next)
	return visible
