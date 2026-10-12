extends RefCounted

const CHUNK_PATH_TEMPLATE := "res://assets/maps/starter/chunks/chunk_%d_%d.txt"
const HERO_START_CELL := Vector2i(5, 30)
const FIRST_GOBLIN_CELL := Vector2i(17, 30)
const SWORD_CELLS: Array[Vector2i] = [Vector2i(8, 30)]
const GOBLINS := [
	{"cell": FIRST_GOBLIN_CELL, "strength": 4},
	{"cell": Vector2i(29, 14), "strength": 6},
]
# This door opens only from the returning corridor, after reaching the upper hall.
const SHORTCUT_DOOR := Vector2i(9, 25)
const SHORTCUT_INSIDE_CELL := Vector2i(9, 24)
const SHORTCUT_OUTSIDE_CELL := Vector2i(9, 26)
