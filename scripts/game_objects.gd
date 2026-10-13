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
const PICKAXE_PATH := "res://assets/items/pickaxe.png"
const BOMB_PATH := "res://assets/items/bomb.png"
const TOOL_CABINET_PATH := "res://assets/props/furniture/series_01/tool_cabinet.png"
const CABINET_FULL_PATH := "res://assets/props/furniture/series_01/02_cabinet_jars.png"
const WATER_ELEMENTAL_PATH := "res://assets/actors/pixel_monsters/series_05/05_water_elemental.png"
const BOSS_PATH := "res://assets/actors/pixel_monsters/series_05/14_skeletal_horse.png"
const COCKATRICE_PATH := "res://assets/actors/pixel_monsters/series_05/11_cockatrice.png"
const PUSH_SCROLL_PATH := "res://assets/items/push_scroll.png"
const HERO_GRAVE_PATH := "res://assets/props/memorials/hero_grave.png"
const BOOKCASE_PATH := "res://assets/props/furniture/series_01/01_bookcase_books.png"
const TILE_FLOOR_PATH := "res://assets/tiles/dungeon/floor.png"
const TILE_WALL_PATH := "res://assets/tiles/dungeon/wall.png"
const TILE_WATER_PATH := "res://assets/tiles/dungeon/water.png"
const TILE_DOOR_PATH := "res://assets/tiles/dungeon/door.png"
const EARTH_PATH_PREFIX := "res://assets/tiles/earth_burrow/series_01/"
const BEDROCK_PATH_PREFIX := "res://assets/tiles/bedrock/series_01/"
static var _entries: Array[Dictionary] = []

# Gameplay definitions shared by spawning, inventory and the editor.
# Player-facing text lives in localization/messages.csv; only translation keys belong here.
# Register an object here once; the editor needs no separate list or button code.
static func definitions() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	var entries: Array[Dictionary] = [
		{"id": "floor", "name_key": "OBJECT_NAME_FLOOR", "category": "terrain", "tile": 0, "path": TILE_FLOOR_PATH, "blocks_movement": false, "blocks_sight": false},
		{"id": "wall", "name_key": "OBJECT_NAME_WALL", "category": "terrain", "tile": 1, "path": TILE_WALL_PATH, "blocks_movement": true, "blocks_sight": true, "blast_result": 0},
		{"id": "water", "name_key": "OBJECT_NAME_WATER", "category": "terrain", "tile": 2, "path": TILE_WATER_PATH, "blocks_movement": false, "blocks_sight": false},
		{"id": "door", "name_key": "OBJECT_NAME_DOOR", "category": "terrain", "tile": 3, "path": TILE_DOOR_PATH, "blocks_movement": true, "blocks_sight": true, "blast_result": 0},
		{"id": "earth", "name_key": "OBJECT_NAME_EARTH", "category": "terrain", "tile": 4, "path": EARTH_PATH_PREFIX + "09_wall_loam.png", "blocks_movement": true, "blocks_sight": true, "blast_result": 5},
		{"id": "earth_floor", "name_key": "OBJECT_NAME_EARTH_FLOOR", "category": "terrain", "tile": 5, "path": EARTH_PATH_PREFIX + "01_floor_packed.png", "blocks_movement": false, "blocks_sight": false},
		{"id": "bedrock", "name_key": "OBJECT_NAME_BEDROCK", "category": "terrain", "tile": 6, "path": BEDROCK_PATH_PREFIX + "bedrock_01.png", "variant_paths": [BEDROCK_PATH_PREFIX + "bedrock_01.png", BEDROCK_PATH_PREFIX + "bedrock_02.png", BEDROCK_PATH_PREFIX + "bedrock_03.png", BEDROCK_PATH_PREFIX + "bedrock_04.png"], "blocks_movement": true, "blocks_sight": true, "blast_result": -1},
		{"id": "hero_start", "name_key": "OBJECT_NAME_HERO_START", "category": "hero", "path": "res://assets/actors/hero_mage_rogue.png"},
	]
	for goblin: Dictionary in GOBLIN_TYPES.TYPES:
		entries.append({"id": goblin.id, "name_key": goblin.name_key, "category": "enemy", "path": goblin.path, "goblin_type": goblin.id, "strength_range": GOBLIN_TYPES.strength_range(goblin.id), "tier": goblin.tier, "habitat": "floor", "can_swim": false, "blocks_movement": true, "blocks_sight": false})
	for flora: Dictionary in FLORA_TYPES.TYPES:
		var entry := flora.duplicate()
		entry.merge({"category": "enemy", "retaliates_only": true, "habitat": "floor", "can_swim": false, "blocks_movement": true, "blocks_sight": false})
		entries.append(entry)
	entries.append({"id": "water_elemental", "name_key": "OBJECT_NAME_WATER_ELEMENTAL", "category": "enemy", "path": WATER_ELEMENTAL_PATH, "strength_range": Vector2i(15, 45), "habitat": "water", "can_swim": true, "requires_water": true, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "cockatrice", "name_key": "OBJECT_NAME_COCKATRICE", "category": "enemy", "path": COCKATRICE_PATH, "strength_range": Vector2i(5, 15), "habitat": "floor", "can_swim": false, "petrifies_on_hit": true, "encounter_text_key": "ENCOUNTER_COCKATRICE", "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "skeletal_horse", "name_key": "OBJECT_NAME_SKELETAL_HORSE", "category": "enemy", "path": BOSS_PATH, "strength": 200, "can_swim": false, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "sword", "name_key": "OBJECT_NAME_SWORD", "category": "item", "path": SWORD_PATH, "weapon_bonus": 5})
	entries.append({"id": "broken_bottle", "name_key": "OBJECT_NAME_BROKEN_BOTTLE", "category": "item", "path": "res://assets/items/broken_bottle.png", "weapon_bonus": 2})
	entries.append({"id": "cockatrice_corpse", "description_key": "ITEM_DESCRIPTION_COCKATRICE_CORPSE", "name_key": "OBJECT_NAME_COCKATRICE_CORPSE", "category": "item", "path": "res://assets/actors/prone/cockatrice_prone.png", "auto_pickup": false, "weapon_bonus": 0, "weapon_petrifies_on_hit": true, "petrifies_on_collision": true, "dangerous_to_handle": true})
	for pile: Dictionary in [{"size": "small", "name_key": "OBJECT_NAME_GOLD_SMALL", "range": Vector2i(1, 3)}, {"size": "medium", "name_key": "OBJECT_NAME_GOLD_MEDIUM", "range": Vector2i(3, 6)}, {"size": "large", "name_key": "OBJECT_NAME_GOLD_LARGE", "range": Vector2i(6, 10)}]:
		entries.append({"id": "gold_" + pile.size, "name_key": pile.name_key, "category": "currency", "path": "res://assets/items/gold_%s.png" % pile.size, "money_range": pile.range, "procedural": true})
	entries.append({"id": "ghost_ring", "description_key": "ITEM_DESCRIPTION_GHOST_RING", "name_key": "OBJECT_NAME_GHOST_RING", "category": "item", "path": GHOST_RING_PATH})
	entries.append({"id": "magic_key", "description_key": "ITEM_DESCRIPTION_MAGIC_KEY", "name_key": "OBJECT_NAME_MAGIC_KEY", "category": "item", "path": MAGIC_KEY_PATH, "loot_group": "tools", "loot_weight": 2, "target_terrain": 3, "confirmation_key": "CONFIRMATION_MAGIC_KEY"})
	entries.append({"id": "pickaxe", "description_key": "ITEM_DESCRIPTION_PICKAXE", "name_key": "OBJECT_NAME_PICKAXE", "category": "item", "path": PICKAXE_PATH, "loot_group": "tools", "loot_weight": 3, "target_terrain": 1, "target_terrains": [1, 4], "item_action": "dig"})
	entries.append({"id": "bomb", "description_key": "ITEM_DESCRIPTION_BOMB", "name_key": "OBJECT_NAME_BOMB", "category": "item", "path": BOMB_PATH, "loot_group": "tools", "loot_weight": 1, "item_action": "plant_bomb"})
	entries.append({"id": "push_scroll", "description_key": "ITEM_DESCRIPTION_PUSH_SCROLL", "name_key": "OBJECT_NAME_PUSH_SCROLL", "category": "item", "path": PUSH_SCROLL_PATH, "loot_group": "scrolls", "loot_weight": 1, "item_action": "push"})
	entries.append({"id": "strength_crystal", "name_key": "OBJECT_NAME_STRENGTH_CRYSTAL", "category": "item", "path": STRENGTH_CRYSTAL_PATH, "strength_gain": 1, "procedural": true})
	entries.append({"id": "health_potion", "description_key": "ITEM_DESCRIPTION_HEALTH_POTION", "name_key": "OBJECT_NAME_HEALTH_POTION", "category": "item", "path": HEALTH_POTION_PATH, "potion_effect": "heal", "loot_weight": 3})
	entries.append({"id": "strength_potion", "description_key": "ITEM_DESCRIPTION_STRENGTH_POTION", "name_key": "OBJECT_NAME_STRENGTH_POTION", "category": "item", "path": STRENGTH_POTION_PATH, "potion_effect": "strength", "loot_weight": 2})
	entries.append({"id": "water_breathing_potion", "description_key": "ITEM_DESCRIPTION_WATER_BREATHING_POTION", "name_key": "OBJECT_NAME_WATER_BREATHING_POTION", "category": "item", "path": WATER_BREATHING_POTION_PATH, "potion_effect": "water_breathing", "loot_weight": 1})
	entries.append({"id": "speed_potion", "description_key": "ITEM_DESCRIPTION_SPEED_POTION", "name_key": "OBJECT_NAME_SPEED_POTION", "category": "item", "path": SPEED_POTION_PATH, "potion_effect": "speed", "loot_weight": 1})
	entries.append({"id": "petrification_protection_potion", "description_key": "ITEM_DESCRIPTION_PETRIFICATION_PROTECTION_POTION", "name_key": "OBJECT_NAME_PETRIFICATION_PROTECTION_POTION", "category": "item", "path": "res://assets/items/petrification_protection_potion.png", "potion_effect": "petrification_protection", "loot_weight": 1})
	entries.append({"id": "potion_cabinet", "name_key": "OBJECT_NAME_POTION_CABINET", "category": "cabinet", "path": CABINET_FULL_PATH, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "bookcase", "name_key": "OBJECT_NAME_BOOKCASE", "category": "cabinet", "path": BOOKCASE_PATH, "loot_group": "scrolls", "shelf_areas": [Rect2i(14, 10, 32, 14), Rect2i(14, 26, 32, 14), Rect2i(14, 42, 32, 15)], "shelf_background": Vector2i(22, 10), "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "tool_cabinet", "name_key": "OBJECT_NAME_TOOL_CABINET", "category": "cabinet", "path": TOOL_CABINET_PATH, "loot_group": "tools", "shelf_areas": [Rect2i(13, 6, 38, 15), Rect2i(13, 23, 38, 16), Rect2i(13, 41, 38, 16)], "shelf_background": Vector2i(14, 7), "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "empty_cabinet", "name_key": "OBJECT_NAME_EMPTY_CABINET", "category": "cabinet", "empty": true, "path": CABINET_FULL_PATH, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "hero_grave", "name_key": "OBJECT_NAME_HERO_GRAVE", "category": "prop", "path": HERO_GRAVE_PATH, "procedural": true, "blocks_movement": false, "blocks_sight": false})
	entries.append({"id": "hero_statue", "name_key": "OBJECT_NAME_HERO_STATUE", "category": "prop", "path": "res://assets/actors/hero_mage_rogue.png", "procedural": true, "blocks_movement": true, "blocks_sight": false})
	entries.append({"id": "enemy_statue", "name_key": "OBJECT_NAME_ENEMY_STATUE", "category": "prop", "path": COCKATRICE_PATH, "procedural": true, "blocks_movement": true, "blocks_sight": false})
	# Matching prone art is picked up by type, without another hand-maintained list.
	for entry: Dictionary in entries:
		if entry.category == "enemy":
			var prone_path := "res://assets/actors/prone/%s_prone.png" % entry.id
			if ResourceLoader.exists(prone_path):
				entry.prone_path = prone_path
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
	return loot_pool("potions")


static func loot_pool(group: String) -> Array[String]:
	# The same catalog supplies rarity to generation and unique types to the editor.
	var pool: Array[String] = []
	for entry in definitions():
		if entry.category == "item" and entry.get("loot_group", "potions" if entry.has("potion_effect") else "") == group:
			for index in range(maxi(int(entry.get("loot_weight", 1)), 0)):
				pool.append(entry.id)
	return pool


static func tool_for_terrain(tile_type: int) -> Dictionary:
	for entry in definitions():
		if entry.category == "item" and (entry.get("target_terrain", -1) == tile_type or entry.get("target_terrains", []).has(tile_type)):
			return entry
	return {}


static func terrain_definition(tile_type: int) -> Dictionary:
	for entry in definitions():
		if entry.get("tile", -1) == tile_type:
			return entry
	return {}


static func can_place_on(type_id: String, tile_type: int) -> bool:
	var entry := definition(type_id)
	if entry.is_empty():
		return false
	return tile_type == 2 if entry.get("habitat", "floor") == "water" else tile_type in [0, 5]
