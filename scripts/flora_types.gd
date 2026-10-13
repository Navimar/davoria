extends RefCounted

# Mushrooms are ordered from weak to strong; the map stores only their type.
const TYPES := [
	{"id": "brown_mushroom", "name_key": "OBJECT_NAME_BROWN_MUSHROOM", "tier": "weak", "strength_range": Vector2i(5, 30),
		"path": "res://assets/actors/flora/series_01/brown_mushroom.png"},
	{"id": "red_mushroom", "name_key": "OBJECT_NAME_RED_MUSHROOM", "tier": "medium", "strength_range": Vector2i(31, 65),
		"path": "res://assets/actors/flora/series_01/red_mushroom.png"},
	{"id": "violet_mushroom", "name_key": "OBJECT_NAME_VIOLET_MUSHROOM", "tier": "strong", "strength_range": Vector2i(66, 99),
		"path": "res://assets/actors/flora/series_01/violet_mushroom.png"},
	{"id": "thorn_bush", "name_key": "OBJECT_NAME_THORN_BUSH", "strength": 10,
		"path": "res://assets/actors/flora/series_01/thorn_bush.png"},
]
