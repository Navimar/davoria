extends RefCounted

const ACTOR_SIGHT := preload("res://scripts/actor_sight.gd")
const SEARCH_RADIUS := ACTOR_SIGHT.RADIUS
const SKIP_CHANCE := 0.4
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func next_delay(rng: RandomNumberGenerator) -> int:
	return 2 if rng.randf() < SKIP_CHANCE else 1


static func plan(cell: Vector2i, hero: Vector2i, last_seen: Variant,
		walkable: Callable, sight: Callable, rng: RandomNumberGenerator) -> Dictionary:
	var result := {"target": cell, "last_seen": last_seen, "attack": false}
	if not _inside_search(cell, hero):
		return result
	if sight.call(cell, hero):
		result.last_seen = hero
		var delta := hero - cell
		if absi(delta.x) + absi(delta.y) == 1:
			result.attack = true
			return result
		var step: Variant = _next_step(cell, hero, hero, walkable, rng)
		result.target = step if step != null else _wander(cell, hero, walkable, rng)
		return result
	if last_seen != null and cell != last_seen:
		var step: Variant = _next_step(cell, last_seen, hero, walkable, rng)
		if step != null:
			result.target = step
			return result
	result.last_seen = null
	result.target = _wander(cell, hero, walkable, rng)
	return result


static func _next_step(origin: Vector2i, target: Vector2i, hero: Vector2i,
		walkable: Callable, rng: RandomNumberGenerator) -> Variant:
	if not _inside_search(target, hero):
		return null
	var cells: Array[Vector2i] = [origin]
	var first_steps := {origin: origin}
	var directions := _shuffled_directions(rng)
	var index := 0
	while index < cells.size():
		var cell := cells[index]
		index += 1
		for direction in directions:
			var next := cell + direction
			if first_steps.has(next) or not _inside_search(next, hero) or not walkable.call(next):
				continue
			first_steps[next] = next if cell == origin else first_steps[cell]
			if next == target:
				return first_steps[next]
			cells.append(next)
	return null


static func _wander(cell: Vector2i, hero: Vector2i, walkable: Callable,
		rng: RandomNumberGenerator) -> Vector2i:
	for direction in _shuffled_directions(rng):
		var next := cell + direction
		if next != hero and _inside_search(next, hero) and walkable.call(next):
			return next
	return cell


static func _shuffled_directions(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var directions: Array[Vector2i] = DIRECTIONS.duplicate()
	for index in range(directions.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap := directions[index]
		directions[index] = directions[other]
		directions[other] = swap
	return directions


static func _inside_search(cell: Vector2i, hero: Vector2i) -> bool:
	return ACTOR_SIGHT.contains(cell, hero)
