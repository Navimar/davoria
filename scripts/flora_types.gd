extends RefCounted

# Mushrooms are ordered from weak to strong; the map stores only their type.
const TYPES := [
	{"id": "brown_mushroom", "name": "Боровик (5–30)", "tier": "weak", "strength_range": Vector2i(5, 30),
		"path": "res://assets/actors/flora/series_01/brown_mushroom.png"},
	{"id": "red_mushroom", "name": "Красный гриб (31–65)", "tier": "medium", "strength_range": Vector2i(31, 65),
		"path": "res://assets/actors/flora/series_01/red_mushroom.png"},
	{"id": "violet_mushroom", "name": "Фиолетовый гриб (66–99)", "tier": "strong", "strength_range": Vector2i(66, 99),
		"path": "res://assets/actors/flora/series_01/violet_mushroom.png"},
	{"id": "thorn_bush", "name": "Колючий куст", "strength": 10,
		"path": "res://assets/actors/flora/series_01/thorn_bush.png"},
]
