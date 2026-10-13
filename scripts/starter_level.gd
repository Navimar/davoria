extends RefCounted

const CHUNK_PATH_TEMPLATE := "res://assets/maps/starter/chunks/chunk_%d_%d.txt"
const HERO_START_CELL := Vector2i(5, 30)
const FIRST_GOBLIN_CELL := Vector2i(17, 30)
const SWORD_CELLS: Array[Vector2i] = [Vector2i(8, 30)]
const POTION_CABINETS := [
	# Default cabinet positions. Contents are rolled at runtime, never authored.
	{"cell": Vector2i(4, 26)},
	{"cell": Vector2i(18, 25)},
	{"cell": Vector2i(25, 25)},
	{"cell": Vector2i(12, 11)},
	{"cell": Vector2i(31, 7)},
	{"cell": Vector2i(36, 29)},
	{"cell": Vector2i(40, 17)},
	{"cell": Vector2i(38, 5)},
	{"cell": Vector2i(54, 4)},
	{"cell": Vector2i(60, 12)},
]
const GOBLINS := [
	{"cell": FIRST_GOBLIN_CELL, "type": "weak_club"},
	{"cell": Vector2i(29, 14), "type": "medium_swordsman"},
	# Early encounters: leave the entry and starting sword outside enemy sight.
	{"cell": Vector2i(14, 29), "type": "weak_club"},
	{"cell": Vector2i(16, 26), "type": "weak_club"},
	{"cell": Vector2i(20, 26), "type": "weak_club"},
	{"cell": Vector2i(20, 32), "type": "weak_club"},
	{"cell": Vector2i(24, 30), "type": "weak_club"},
	{"cell": Vector2i(28, 31), "type": "weak_club"},
	{"cell": Vector2i(28, 25), "type": "weak_club"},
	# Direct passage and upper hall.
	{"cell": Vector2i(27, 24), "type": "medium_swordsman"},
	{"cell": Vector2i(26, 21), "type": "medium_swordsman"},
	{"cell": Vector2i(27, 18), "type": "medium_swordsman"},
	{"cell": Vector2i(23, 16), "type": "weak_club"},
	{"cell": Vector2i(25, 14), "type": "medium_swordsman"},
	{"cell": Vector2i(31, 16), "type": "medium_swordsman"},
	{"cell": Vector2i(33, 12), "type": "medium_swordsman"},
	{"cell": Vector2i(29, 11), "type": "medium_swordsman"},
	{"cell": Vector2i(27, 7), "type": "strong_guard"},
	{"cell": Vector2i(33, 7), "type": "strong_guard"},
	# Longer eastern route provides weaker encounters before its side rooms.
	{"cell": Vector2i(30, 29), "type": "weak_club"},
	{"cell": Vector2i(34, 30), "type": "weak_club"},
	{"cell": Vector2i(39, 29), "type": "weak_club"},
	{"cell": Vector2i(38, 26), "type": "weak_club"},
	{"cell": Vector2i(39, 23), "type": "medium_swordsman"},
	{"cell": Vector2i(38, 20), "type": "medium_swordsman"},
	{"cell": Vector2i(38, 16), "type": "medium_swordsman"},
	# Strongest enemies occupy optional alcoves, away from the entrance.
	{"cell": Vector2i(42, 17), "type": "strong_guard"},
	{"cell": Vector2i(44, 18), "type": "strong_guard"},
	{"cell": Vector2i(41, 21), "type": "strong_guard"},
	{"cell": Vector2i(37, 9), "type": "strong_guard"},
	{"cell": Vector2i(42, 7), "type": "strong_guard"},
	{"cell": Vector2i(40, 5), "type": "strong_guard"},
	{"cell": Vector2i(19, 12), "type": "medium_swordsman"},
	{"cell": Vector2i(14, 11), "type": "weak_club"},
	{"cell": Vector2i(10, 16), "type": "weak_club"},
	{"cell": Vector2i(9, 20), "type": "weak_club"},
]
const BOSSES := [{"cell": Vector2i(57, 7), "strength": 200}]
const WATER_ELEMENTALS := [
	{"cell": Vector2i(12, 20), "type": "water_elemental"},
	{"cell": Vector2i(15, 19), "type": "water_elemental"},
	{"cell": Vector2i(16, 22), "type": "water_elemental"},
	{"cell": Vector2i(21, 7), "type": "water_elemental"},
	{"cell": Vector2i(23, 9), "type": "water_elemental"},
	{"cell": Vector2i(43, 19), "type": "water_elemental"},
	{"cell": Vector2i(44, 22), "type": "water_elemental"},
	{"cell": Vector2i(60, 5), "type": "water_elemental"},
	{"cell": Vector2i(12, -5), "type": "water_elemental"},
	{"cell": Vector2i(16, -3), "type": "water_elemental"},
	{"cell": Vector2i(14, -2), "type": "water_elemental"},
	{"cell": Vector2i(16, 6), "type": "water_elemental"},
]
const ENEMIES := GOBLINS + BOSSES + WATER_ELEMENTALS
