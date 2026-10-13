extends RefCounted

const CELL_FREQUENCY := 20


static func candidates(chunk: Vector2i, size: Vector2i, game_seed: int) -> Array[Vector2i]:
	# A separate stream for each chunk fixes the whole run's scatter independently
	# of loading order, enemy turns, potion rolls and global random state.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crystals/%d/%d/%d" % [game_seed, chunk.x, chunk.y])
	var cells: Array[Vector2i] = []
	var origin := chunk * size
	for y in range(size.y):
		for x in range(size.x):
			if rng.randi_range(1, CELL_FREQUENCY) == 1:
				cells.append(origin + Vector2i(x, y))
	return cells
