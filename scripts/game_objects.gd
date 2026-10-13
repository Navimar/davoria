extends RefCounted

const GOBLIN_TYPES := preload("res://scripts/goblin_types.gd")
const FLORA_TYPES := preload("res://scripts/flora_types.gd")
const SWORD_PATH := "res://assets/items/iron_sword.png"
const GHOST_RING_PATH := "res://assets/items/ghost_ring.png"
const STRENGTH_CRYSTAL_PATH := "res://assets/items/strength_crystal.png"
const HEALTH_POTION_PATH := "res://assets/items/health_potion.png"
const STRENGTH_POTION_PATH := "res://assets/items/strength_potion.png"
const WATER_BREATHING_POTION_PATH := "res://assets/items/water_breathing_potion.png"
const SPEED_POTION_PATH := "res://assets/items/speed_potion.png"
const MAGIC_KEY_PATH := "res://assets/items/magic_key.png"
const CABINET_FULL_PATH := "res://assets/props/furniture/series_01/02_cabinet_jars.png"
const WATER_ELEMENTAL_PATH := "res://assets/actors/pixel_monsters/series_05/05_water_elemental.png"
const BOSS_PATH := "res://assets/actors/pixel_monsters/series_05/14_skeletal_horse.png"
const TILE_FLOOR_PATH := "res://assets/tiles/dungeon/floor.png"
const TILE_WALL_PATH := "res://assets/tiles/dungeon/wall.png"
const TILE_WATER_PATH := "res://assets/tiles/dungeon/water.png"
const TILE_DOOR_PATH := "res://assets/tiles/dungeon/door.png"
static var _entries: Array[Dictionary] = []

# This is the shared source for spawning, inventory items and the editor palette.
# Register an object here once; the editor needs no separate list or button code.
static func definitions() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	var entries: Array[Dictionary] = [
		{"id": "floor", "name": "Пол", "category": "terrain", "tile": 0, "path": TILE_FLOOR_PATH, "blocks_movement": false, "blocks_sight": false},
		{"id": "wall", "name": "Стена", "category": "terrain", "tile": 1, "path": TILE_WALL_PATH, "blocks_movement": true, "blocks_sight": true},
		{"id": "water", "name": "Вода", "category": "terrain", "tile": 2, "path": TILE_WATER_PATH, "blocks_movement": false, "blocks_sight": false},
		{"id": "door", "name": "Дверь", "category": "terrain", "tile": 3, "path": TILE_DOOR_PATH, "blocks_movement": true, "blocks_sight": true},
		{"id": "hero_start", "name": "Старт героя", "category": "hero", "path": "res://assets/actors/hero_mage_rogue.png"},
	]
	for goblin: Dictionary in GOBLIN_TYPES.TYPES:
		entries.append({"id": goblin.id, "name": goblin.name, "category": "enemy", "path": goblin.path, "goblin_type": goblin.id, "strength_range": GOBLIN_TYPES.strength_range(goblin.id), "tier": goblin.tier, "habitat": "floor", "blocks_movement": true, "blocks_sight": false})
	for flora: Dictionary in FLORA_TYPES.TYPES:
		var entry := flora.duplicate()
		entry.merge({"category": "enemy", "retaliates_only": true, "habitat": "floor", "blocks_movement": true, "blocks_sight": false})
		entries.append(entry)
	entries.append({"id": "water_elemental", "name": "Водный элементаль", "category": "enemy", "path": WATER_ELEMENTAL_PATH, "strength_range": Vector2i(15, 45), "habitat": "water", "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "skeletal_horse", "name": "Босс: скелет-лошадь", "category": "enemy", "path": BOSS_PATH, "strength": 200, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "sword", "name": "Меч", "category": "item", "path": SWORD_PATH, "weapon_bonus": 5})
	entries.append({"id": "ghost_ring", "name": "Кольцо призрака", "category": "item", "path": GHOST_RING_PATH})
	entries.append({"id": "magic_key", "name": "Волшебный ключ", "category": "item", "path": MAGIC_KEY_PATH})
	entries.append({"id": "strength_crystal", "name": "Кристалл силы", "category": "item", "path": STRENGTH_CRYSTAL_PATH, "strength_gain": 1, "procedural": true})
	entries.append({"id": "health_potion", "name": "Зелье лечения", "category": "item", "path": HEALTH_POTION_PATH, "potion_effect": "heal", "loot_weight": 3})
	entries.append({"id": "strength_potion", "name": "Зелье силы", "category": "item", "path": STRENGTH_POTION_PATH, "potion_effect": "strength", "loot_weight": 2})
	entries.append({"id": "water_breathing_potion", "name": "Зелье водного дыхания", "category": "item", "path": WATER_BREATHING_POTION_PATH, "potion_effect": "water_breathing", "loot_weight": 1})
	entries.append({"id": "speed_potion", "name": "Зелье скорости", "category": "item", "path": SPEED_POTION_PATH, "potion_effect": "speed", "loot_weight": 1})
	entries.append({"id": "potion_cabinet", "name": "Шкаф зелий", "category": "cabinet", "path": CABINET_FULL_PATH, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "empty_cabinet", "name": "Пустой шкаф", "category": "cabinet", "empty": true, "path": CABINET_FULL_PATH, "blocks_movement": true, "blocks_sight": false})
	_entries = entries
	return _entries


static func definition(type_id: String) -> Dictionary:
	for entry in definitions():
		if entry.id == type_id:
			return entry
	return {}


static func potion_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in definitions():
		if entry.has("potion_effect"):
			ids.append(entry.id)
	return ids


static func potion_pool() -> Array[String]:
	# The same catalog supplies rarity to generation and unique types to the editor.
	var pool: Array[String] = []
	for entry in definitions():
		if entry.has("potion_effect"):
			for index in range(maxi(int(entry.get("loot_weight", 1)), 0)):
				pool.append(entry.id)
	return pool


static func terrain_definition(tile_type: int) -> Dictionary:
	for entry in definitions():
		if entry.get("tile", -1) == tile_type:
			return entry
	return {}


static func can_place_on(type_id: String, tile_type: int) -> bool:
	var entry := definition(type_id)
	if entry.is_empty():
		return false
	return tile_type == (2 if entry.get("habitat", "floor") == "water" else 0)
