extends RefCounted

const WEAK := "weak"
const MEDIUM := "medium"
const STRONG := "strong"
const DEFAULT_TYPE := "weak_club"
const PATH_PREFIX := "res://assets/actors/goblins/series_01/"
const STRENGTH_RANGES := {
	WEAK: Vector2i(5, 30),
	MEDIUM: Vector2i(31, 65),
	STRONG: Vector2i(66, 99),
}
# Visually selected sprites, ordered from weak to strong.
const TYPES := [
	{"id": "weak_club", "name": "Гоблин с дубинкой", "tier": WEAK,
		"path": PATH_PREFIX + "01_weak_club.png"},
	{"id": "medium_swordsman", "name": "Гоблин-мечник", "tier": MEDIUM,
		"path": PATH_PREFIX + "09_medium_swordsman.png"},
	{"id": "strong_guard", "name": "Тяжёлый гоблин-страж", "tier": STRONG,
		"path": PATH_PREFIX + "12_strong_guard.png"},
]


static func definition(type_id: String) -> Dictionary:
	for entry: Dictionary in TYPES:
		if entry.id == type_id:
			return entry
	return {}


static func strength_range(type_id: String) -> Vector2i:
	var entry := definition(type_id)
	return STRENGTH_RANGES[entry.tier] if not entry.is_empty() else Vector2i.ZERO


static func roll_strength(type_id: String, rng: RandomNumberGenerator) -> int:
	var limits := strength_range(type_id)
	return rng.randi_range(limits.x, limits.y)
