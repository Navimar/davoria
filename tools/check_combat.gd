extends SceneTree

const COMBAT := preload("res://scripts/strength_combat.gd")
const QUEUE := preload("res://scripts/turn_queue.gd")
const AI := preload("res://scripts/goblin_ai.gd")
const SIGHT := preload("res://scripts/actor_sight.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const SCENE := preload("res://scenes/asset_demo.tscn")
const GOBLIN_TYPES := preload("res://scripts/goblin_types.gd")
const OBJECTS := preload("res://scripts/map_objects.gd")
var _errors: Array[String] = []
var _folder: String
var _template: String


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_combat_rules()
	_check_queue()
	_check_ai()
	_check_goblin_types()
	_build_fixture()
	await _check_population()
	await _check_game()
	for name in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(name))
	DirAccess.remove_absolute(_folder)
	if _errors.is_empty():
		print("COMBAT CHECK OK: enemy population, strength, sword, rewards, stable queue, skip chance, bounded pursuit, memory, chunk activation, automatic death restart, held attacks and responsive turns")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_combat_rules() -> void:
	for pair in [[-5, 0], [0, 0], [1, 1], [100, 1], [101, 2], [200, 2], [201, 3]]:
		_check(COMBAT.damage_for_strength(pair[0]) == pair[1], "Damage boundary %d" % pair[0])
	var win := COMBAT.exchange(10, 10, 0, 9)
	var loss := COMBAT.exchange(10, 10, 0, 10)
	_check(win.player == 10 and win.enemy == 9 and win.player_hit, "Roll below player strength hits enemy")
	_check(loss.player == 9 and loss.enemy == 10 and not loss.player_hit, "Roll at boundary hits player")
	var hits := 0
	for roll in range(40):
		if COMBAT.exchange(10, 30, 0, roll).player_hit:
			hits += 1
	_check(hits == 10, "Exact strength ratio: 10 of 40 possible rolls")
	_check(COMBAT.effective_strength(10, 5) == 15, "Weapon adds five combat strength without changing own strength")
	_check(COMBAT.effective_strength(10, 5, 2) == 25 and COMBAT.effective_strength(0, 5, 2) == 0, "Strength boost doubles own strength while retaining the weapon and exhaustion rules")
	var sword := COMBAT.exchange(10, 2, 5, 0)
	_check(not sword.killed and sword.enemy == 1 and sword.player == 10 and sword.damage == 1, "Sword improves strength without adding direct damage")
	hits = 0
	for roll in range(25):
		if COMBAT.exchange(10, 10, 5, roll).player_hit:
			hits += 1
	_check(hits == 15, "Weapon changes the exact hit ratio to fifteen of twenty-five rolls")
	var wound := COMBAT.exchange(10, 10, 5, 15)
	_check(wound.player == 9 and wound.enemy == 10 and wound.damage == 1, "Incoming damage reduces own strength and not the weapon bonus")
	_check(COMBAT.effective_strength(0, 5) == 0 and COMBAT.effective_strength(-3, 5) == 0, "Weapon cannot supply combat strength to an exhausted hero")
	var exhausted := COMBAT.exchange(0, 10, 5, 0)
	_check(exhausted.player == -1 and not exhausted.player_hit and exhausted.enemy == 10, "Exhausted player cannot counterattack even with a weapon")
	_check(COMBAT.exchange(96, 10, 5, 0).damage == 2, "Effective strength follows the existing damage threshold")
	_check(COMBAT.exchange(10, 1, -5, 0).damage == 1, "Negative bonus cannot reduce base damage")


func _check_queue() -> void:
	var queue := QUEUE.new()
	queue.schedule_after(20, 2)
	queue.schedule_after(10, 1)
	queue.schedule_after(30, 1)
	_check(queue.pop_due() == -1, "No actor moves before its deadline")
	queue.advance()
	_check(queue.pop_due() == 10 and queue.pop_due() == 30, "Equal deadlines preserve insertion order")
	_check(queue.pop_due() == -1, "Delayed actor skips this turn")
	queue.advance()
	_check(queue.pop_due() == 20 and queue.pop_due() == -1, "Delayed actor gets exactly one turn")
	queue.schedule_after(1, 1)
	queue.schedule_after(1, 2)
	queue.schedule_after(2, 1)
	queue.cancel(2)
	queue.advance()
	_check(queue.pop_due() == -1, "Rescheduling replaces prior entry; cancelled actor stays absent")
	queue.advance()
	_check(queue.pop_due() == 1 and queue.pop_due() == -1, "Only one entry survives rescheduling")
	# Exercise heap deletion and replacements against a simple sorted reference.
	var reference: Array[Dictionary] = []
	for actor_id in range(300):
		var delay := 1 + (actor_id * 17) % 13
		queue.schedule_after(actor_id, delay)
		reference.append({"id": actor_id, "wake": queue.current_turn + delay, "seq": actor_id})
	for actor_id in range(0, 300, 3):
		queue.cancel(actor_id)
	reference = reference.filter(func(entry: Dictionary): return entry.id % 3 != 0)
	reference.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.wake < b.wake or (a.wake == b.wake and a.seq < b.seq))
	for turn in range(13):
		queue.advance()
		while not reference.is_empty() and reference[0].wake <= queue.current_turn:
			_check(queue.pop_due() == int(reference.pop_front().id), "Heap order after arbitrary cancellations")
		_check(queue.pop_due() == -1, "Heap never exposes future actor")


func _check_ai() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var skips := 0
	for index in range(10000):
		var delay := AI.next_delay(rng)
		_check(delay == 1 or delay == 2, "Goblin only skips one turn")
		if delay == 2:
			skips += 1
	_check(skips > 3700 and skips < 4300, "Skip probability stays near 40 percent")
	var floor_cells: Dictionary = {}
	for y in range(-5, 6):
		for x in range(-5, 6):
			floor_cells[Vector2i(x, y)] = true
	var allowed := func(cell: Vector2i) -> bool: return floor_cells.has(cell)
	var sight := func(origin: Vector2i, target: Vector2i) -> bool:
		return SIGHT.visible_cells(origin, allowed, allowed).has(target)
	var plan := AI.plan(Vector2i(3, 0), Vector2i.ZERO, null, allowed, sight, rng)
	_check(plan.target == Vector2i(2, 0) and plan.last_seen == Vector2i.ZERO, "Visible hero is pursued one cardinal cell")
	plan = AI.plan(Vector2i(1, 0), Vector2i.ZERO, null, allowed, sight, rng)
	_check(plan.attack and plan.target == Vector2i(1, 0), "Adjacent goblin attacks without entering hero cell")
	floor_cells.erase(Vector2i(2, 0))
	plan = AI.plan(Vector2i(3, 0), Vector2i.ZERO, Vector2i.ZERO, allowed, func(_origin: Vector2i, _target: Vector2i): return false, rng)
	_check(plan.target == Vector2i(3, 1) or plan.target == Vector2i(3, -1), "Remembered target is approached around a wall")
	_check(plan.last_seen == Vector2i.ZERO, "Last seen hero survives loss of sight")
	plan = AI.plan(Vector2i(6, 0), Vector2i.ZERO, null, allowed, sight, rng)
	_check(plan.target == Vector2i(6, 0) and not plan.attack, "AI never searches outside the small area")
	plan = AI.plan(Vector2i(3, 0), Vector2i.ZERO, Vector2i(3, 0), allowed, func(_origin: Vector2i, _target: Vector2i): return false, rng)
	_check(plan.last_seen == null, "Reached remembered cell is forgotten")
	_check(sight.call(Vector2i(5, 0), Vector2i.ZERO), "Enemy sees five cells away, just like the player")
	_check(sight.call(Vector2i(5, 5), Vector2i.ZERO), "Enemy has the player's diagonal sight")
	_check(not sight.call(Vector2i(6, 0), Vector2i.ZERO), "Shared sight stops beyond radius five")
	var shore := {Vector2i(3, 0): true, Vector2i(2, 0): true, Vector2i(1, 0): true}
	var dry := func(cell: Vector2i) -> bool: return shore.has(cell)
	var clear_sight := func(_origin: Vector2i, _target: Vector2i) -> bool: return true
	plan = AI.plan(Vector2i(3, 0), Vector2i.ZERO, null, dry, clear_sight, rng)
	_check(plan.target == Vector2i(2, 0) and not plan.attack, "An unwalkable hero cell can be targeted for a shore approach")
	plan = AI.plan(Vector2i(1, 0), Vector2i.ZERO, null, dry, clear_sight, rng)
	_check(plan.attack and plan.target == Vector2i(1, 0), "Shore contact attacks never need to enter the hero's water cell")


func _check_goblin_types() -> void:
	_check(GOBLIN_TYPES.STRENGTH_RANGES == {"weak": Vector2i(5, 30), "medium": Vector2i(31, 65), "strong": Vector2i(66, 99)}, "Weak, medium and strong goblins use the requested inclusive ranges")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var type_ids: Dictionary = {}
	var tier_order := {"weak": 0, "medium": 1, "strong": 2}
	var previous_tier := -1
	for entry in GOBLIN_TYPES.TYPES:
		_check(not type_ids.has(entry.id), "Goblin type IDs are unique")
		type_ids[entry.id] = true
		_check(tier_order[entry.tier] >= previous_tier, "Sprite sheet and type catalog progress from weak to strong")
		previous_tier = tier_order[entry.tier]
		var limits := GOBLIN_TYPES.strength_range(entry.id)
		var observed: Dictionary = {}
		for index in range(500):
			var strength := GOBLIN_TYPES.roll_strength(entry.id, rng)
			_check(strength >= limits.x and strength <= limits.y, "Every random strength remains inside its type's tier")
			observed[strength] = true
		_check(observed.has(limits.x) and observed.has(limits.y) and observed.size() > 1, "Random strength varies and can include both range endpoints")
	_check(type_ids.keys() == ["weak_club", "medium_swordsman", "strong_guard"], "Catalog contains only the three distinct goblin types")


func _build_fixture() -> void:
	# Editor changes must not invalidate combat fixtures or modify the user's map.
	_folder = "/private/tmp/davoria_combat_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_template = _folder.path_join("chunk_%d_%d.txt")
	DirAccess.make_dir_recursive_absolute(_folder)
	var objects := OBJECTS.defaults()
	objects[Vector2i(2, 28)] = "brown_mushroom"
	objects[Vector2i(8, 32)] = "red_mushroom"
	objects[Vector2i(10, 12)] = "violet_mushroom"
	objects[Vector2i(27, 13)] = "thorn_bush"
	var chunks: Dictionary = {}
	for cell: Vector2i in objects:
		chunks[Vector2i(floori(float(cell.x) / DEMO.CHUNK_SIZE.x), floori(float(cell.y) / DEMO.CHUNK_SIZE.y))] = true
	for chunk: Vector2i in chunks:
		var file := FileAccess.open(_template % [chunk.x, chunk.y], FileAccess.WRITE)
		for y in range(DEMO.CHUNK_SIZE.y):
			var line := ""
			for x in range(DEMO.CHUNK_SIZE.x):
				var cell := chunk * DEMO.CHUNK_SIZE + Vector2i(x, y)
				var habitat: String = DEMO.OBJECT_CATALOG.definition(objects.get(cell, "")).get("habitat", "floor")
				line += "~" if habitat == "water" else "."
			file.store_line(line)
		file.close()
	_check(OBJECTS.save_map(OBJECTS.path_for_chunks(_template), objects), "Isolated combat map is created")


func _check_population() -> void:
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", _template)
	root.add_child(scene)
	await process_frame
	_load_enemy_chunks(scene)
	var rng: RandomNumberGenerator = scene.get("_rng")
	rng.seed = 42
	var goblins: Dictionary = scene.get("_goblins")
	var queue: RefCounted = scene.get("_turn_queue")
	_check(goblins.size() == _authored_count(scene, "enemy"), "Entire authored enemy population is spawned")
	for index in range(LEVEL.ENEMIES.size()):
		var spawn: Dictionary = LEVEL.ENEMIES[index]
		var actor: Dictionary = goblins[scene.get("_goblins_by_cell")[spawn.cell]]
		_check(actor.cell == spawn.cell, "Every spawn keeps its configured cell")
		if spawn.has("type"):
			var limits: Vector2i = DEMO.OBJECT_CATALOG.definition(spawn.type).strength_range
			_check(actor.type == spawn.type and actor.strength >= limits.x and actor.strength <= limits.y, "Every placed type rolls strength within its tier")
			_check(actor.sprite.texture.resource_path == DEMO.OBJECT_CATALOG.definition(spawn.type).path, "Every placed type uses its matching visual variant")
		else:
			_check(actor.strength == spawn.strength, "Boss keeps its explicit strength")
	var boss: Dictionary = goblins[scene.get("_goblins_by_cell")[LEVEL.BOSSES[0].cell]]
	_check(boss.sprite.texture.resource_path == DEMO.BOSS_PATH and boss.strength == 200, "Skeletal horse boss uses its selected sprite and two hundred strength")
	var starting_strengths: Dictionary = {}
	for actor_id: int in goblins:
		starting_strengths[goblins[actor_id].sprite.get_meta("map_origin")] = goblins[actor_id].strength
	# All starting enemies are outside the entry's sight; idle turns cannot reroll them.
	for turn in range(8):
		scene.call("_advance_world_turn")
	for actor_id: int in goblins:
		_check(goblins[actor_id].strength == starting_strengths[goblins[actor_id].sprite.get_meta("map_origin")], "Existing enemies keep their strength across idle world turns")
	rng.seed = 1234
	scene.call("_build_scene")
	await process_frame
	_load_enemy_chunks(scene)
	queue = scene.get("_turn_queue")
	var changed := 0
	for spawn: Dictionary in LEVEL.GOBLINS:
		var actor_id: int = scene.get("_goblins_by_cell")[spawn.cell]
		var limits := GOBLIN_TYPES.strength_range(spawn.type)
		_check(goblins[actor_id].type == spawn.type and goblins[actor_id].strength >= limits.x and goblins[actor_id].strength <= limits.y, "Restart rolls each fixed type within its strength tier")
		if goblins[actor_id].strength != starting_strengths[spawn.cell]:
			changed += 1
	_check(changed > 0 and goblins[scene.get("_goblins_by_cell")[LEVEL.BOSSES[0].cell]].strength == 200, "Restart varies goblin strength while the boss stays at two hundred")
	rng.seed = 42
	var moved: Dictionary = {}
	# Exercise simultaneous encounters across the isolated populated field.
	for hero_cell: Vector2i in [Vector2i(26, 29), Vector2i(28, 13), Vector2i(40, 22), Vector2i(55, 12)]:
		# Relocation is a test fixture; free the destination if a previous chase reached it.
		var by_cell: Dictionary = scene.get("_goblins_by_cell")
		if by_cell.has(hero_cell):
			scene.call("_remove_goblin", int(by_cell[hero_cell]))
		scene.set("_hero_cell", hero_cell)
		scene.set("_hero_strength", 10000)
		scene.call("_finish_hero_move", false)
		for turn in range(12):
			scene.call("_finish_goblin_animations")
			scene.call("_advance_world_turn")
			by_cell = scene.get("_goblins_by_cell")
			var blocked: Dictionary = scene.get("_actor_blocked_cells")
			_check(by_cell.size() == goblins.size() and blocked.size() == goblins.size(), "Crowded turns keep one occupied cell per living enemy")
			_check(queue.get("_positions").size() == _scheduled_actor_count(scene), "Each active autonomous enemy has exactly one future queue entry")
			for actor_id: int in goblins:
				var goblin: Dictionary = goblins[actor_id]
				_check(by_cell.get(goblin.cell, -1) == actor_id and blocked.has(goblin.cell), "Enemy position and occupancy agree after a crowded turn")
				_check(goblin.cell != hero_cell and scene.call("_is_terrain_walkable", goblin.cell), "Enemies never overlap the hero or enter walls")
				if goblin.cell != goblin.sprite.get_meta("map_origin"):
					moved[actor_id] = true
	_check(moved.size() >= 6, "Multiple enemies pursue the hero across the populated rooms")
	scene.free()


func _check_game() -> void:
	var scene: Node2D = SCENE.instantiate()
	scene.set("_chunk_path_template", _template)
	root.add_child(scene)
	await process_frame
	_load_enemy_chunks(scene)
	var goblins: Dictionary = scene.get("_goblins")
	_check(goblins.size() == _authored_count(scene, "enemy") and scene.get("_enemies").size() == goblins.size(), "Level contains its authored live enemies without display actors")
	var actor_id: int = scene.get("_goblins_by_cell")[DEMO.GOBLIN_START_CELL]
	var goblin: Dictionary = goblins[actor_id]
	# Keep subsequent combat assertions isolated from the other encounters.
	for other_id: int in goblins.keys():
		if other_id != actor_id:
			scene.call("_remove_goblin", other_id)
	_check(goblin.cell == DEMO.GOBLIN_START_CELL and scene.call("_is_terrain_walkable", goblin.cell), "Goblin starts on accessible floor")
	var type_id: String = LEVEL.GOBLINS[0].type
	var limits := GOBLIN_TYPES.strength_range(type_id)
	_check(goblin.sprite.texture.resource_path == GOBLIN_TYPES.definition(type_id).path, "First goblin uses its configured type's sprite")
	_check(goblin.strength >= limits.x and goblin.strength <= limits.y, "First goblin rolls its starting strength from the type's range")
	var queue: RefCounted = scene.get("_turn_queue")
	var hero: Sprite2D = scene.get("_hero")
	var start: Vector2i = scene.get("_hero_cell")
	# Random crystals belong to their own check, not this fixed-strength route.
	for cell: Vector2i in [start, start + Vector2i.LEFT]:
		scene.call("_remove_procedural_item", cell)
	var before: int = queue.current_turn
	# A wall attempt does not spend a turn; stopping an animation does not add one.
	scene.call("_set_terrain_cell", start + Vector2i.LEFT, DEMO.TileType.WALL)
	scene.call("_try_move_hero", Vector2i.LEFT)
	_check(queue.current_turn == before and scene.get("_hero_cell") == start, "Blocked movement spends no turn")
	scene.call("_set_terrain_cell", start + Vector2i.LEFT, DEMO.TileType.FLOOR)
	scene.call("_try_move_hero", Vector2i.LEFT)
	_check(queue.current_turn == before + 1, "Accepted logical movement spends exactly one turn")
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(queue.current_turn == before + 2 and hero.position == scene.call("_cell_center", start + Vector2i.LEFT), "Early animation completion starts next turn without duplicating the old one")
	scene.call("_finish_hero_move", false)
	_check(queue.current_turn == before + 2, "Completing visual movement does not advance the world again")
	# Move the same actor adjacent in a controlled room for combat assertions.
	scene.call("_finish_goblin_animations")
	var occupied: Dictionary = scene.get("_actor_blocked_cells")
	var by_cell: Dictionary = scene.get("_goblins_by_cell")
	occupied.erase(goblin.cell)
	by_cell.erase(goblin.cell)
	goblin.cell = start + Vector2i.RIGHT
	occupied[goblin.cell] = true
	by_cell[goblin.cell] = actor_id
	goblin.sprite.position = scene.call("_cell_center", goblin.cell)
	goblin.strength = 100
	scene.set("_hero_strength", 10)
	_check(scene.call("_add_inventory_item", load(DEMO.SWORD_PATH), DEMO.ITEM_ID_SWORD), "Sword is added through the live inventory")
	scene.set("_equipped_weapon_id", DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_texture", load(DEMO.SWORD_PATH))
	scene.call("_refresh_inventory_panel")
	_check(scene.call("_weapon_strength_bonus") == 5 and scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10, "Sword keeps its strength bonus separate from own and maximum strength")
	_check(scene.get("_stats_strength_label").text == "Сила: 10/10+5" and scene.get("_hero_strength_label").text == "15", "Left panel separates weapon strength while overhead shows the total current strength")
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(scene.get("_hero_cell") == start and queue.current_turn == before + 1, "Bump attacks without movement and consumes one turn")
	_check(scene.get("_hero_strength") != 10 or goblin.strength != 100, "Bump resolves a real exchange")
	scene.call("_finish_hero_move", false)
	before = queue.current_turn
	var held := InputEventKey.new()
	held.physical_keycode = KEY_D
	held.pressed = true
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	await create_timer(DEMO.HERO_MOVE_DURATION * 2.3).timeout
	var attack_turns: int = queue.current_turn - before
	_check(attack_turns >= 2 and attack_turns <= 4, "Held attacks repeat at animation pace instead of every frame")
	held = InputEventKey.new()
	held.physical_keycode = KEY_D
	held.pressed = false
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	before = queue.current_turn
	await create_timer(DEMO.HERO_MOVE_DURATION * 2.0).timeout
	_check(queue.current_turn == before, "Releasing attack key stops additional turns")
	scene.call("_wait_hero_turn")
	_check(queue.current_turn == before + 1, "Waiting consumes exactly one world turn")
	scene.call("_finish_hero_move", false)
	scene.set("_hero_strength", 0)
	before = queue.current_turn
	scene.call("_try_move_hero", Vector2i.RIGHT)
	_check(queue.current_turn == before and not scene.get("_is_moving") and scene.call("_weapon_strength_bonus") == 5, "Zero own strength blocks initiating attacks even with the weapon bonus")
	var enemy_before: int = goblin.strength
	scene.call("_resolve_combat", actor_id)
	_check(scene.get("_hero_strength") == -1 and goblin.strength == enemy_before and queue.current_turn == before, "Exhausted hero cannot counterattack an enemy with weapon strength")
	_check(scene.get("_stats_strength_label").text == "Сила: -1/10+5" and scene.get("_hero_strength_label").text == "4", "Damage updates total overhead strength while the weapon bonus stays intact")
	# Chunk deactivation removes pending turns and preserves health and memory.
	goblin.last_seen = start
	var saved_strength: int = goblin.strength
	scene.set("_hero_cell", Vector2i(192, 192))
	scene.call("_sync_active_goblins")
	_check(not goblin.active, "Goblin pauses outside current and neighboring chunks")
	for index in range(10):
		queue.advance()
	_check(queue.pop_due() == -1 and goblin.strength == saved_strength and goblin.last_seen == start, "Inactive goblin keeps its state and accumulates no turns")
	scene.set("_hero_cell", Vector2i(64, 64))
	scene.call("_sync_active_goblins")
	_check(goblin.active and queue.pop_due() == -1, "Diagonal neighboring chunk activates on a future turn")
	queue.advance()
	_check(queue.pop_due() == actor_id and queue.pop_due() == -1, "Reactivated goblin gets one turn with no catch up")
	scene.set("_hero_cell", start)
	scene.set("_hero_strength", -10)
	goblin.strength = 1
	scene.call("_select_hero", 3)
	scene.call("_set_ghost_mode", true)
	var held_keys: Array = scene.get("_held_move_keys")
	held_keys.append(KEY_D)
	queue.schedule_after(actor_id, 1)
	scene.call("_wait_hero_turn")
	_check(scene.get("_hero_strength") == -11 and scene.get("_game_over"), "Death threshold is below minus ten as in Bevy")
	_check(held_keys.is_empty(), "Death clears held movement before restarting")
	before = queue.current_turn
	scene.call("_advance_world_turn")
	scene.call("_resolve_combat", actor_id)
	_check(queue.current_turn == before and scene.get("_hero_strength") == -11, "Death stops further world turns and combat while restart is pending")
	var input := InputEventKey.new()
	input.physical_keycode = KEY_D
	input.pressed = true
	scene.call("_unhandled_key_input", input)
	_check(scene.get("_hero_cell") == start, "Input is blocked while automatic restart is pending")
	await process_frame
	await process_frame
	_check(not scene.get("_game_over") and scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 10 and scene.get("_turn_queue").current_turn == 0, "Death automatically resets hero strength and queue without a restart key")
	_check(scene.get("_hero_cell") == LEVEL.HERO_START_CELL and not scene.get("_is_moving") and not scene.get("_is_ghost_mode"), "Automatic restart restores entry position and clears movement and ghost state")
	_check(not scene.get("_editor_canvas").visible, "Automatic restart hides the editor again")
	_check(scene.get("_selected_hero_index") == 3 and scene.get("_hero").texture.resource_path == DEMO.HERO_VARIANTS[3].path, "Automatic restart keeps the selected hero")
	_load_enemy_chunks(scene)
	var enemy_count := _authored_count(scene, "enemy")
	_check(scene.get("_goblins").size() == enemy_count and scene.get("_turn_queue").get("_positions").size() == _scheduled_actor_count(scene), "Automatic restart restores enemies and schedules only active autonomous actors")
	_check(_authored_live_item_count(scene) == _authored_count(scene, "item") and scene.get("_cabinets").size() == _authored_count(scene, "cabinet") and scene.get("_inventory").size() == 1, "Automatic restart restores authored pickups and cabinets independently of procedural crystals and resets inventory")
	_check(scene.call("_weapon_strength_bonus") == 0 and scene.get("_stats_strength_label").text == "Сила: 10/10", "Restart clears the weapon bonus and resets the left readout")
	goblins = scene.get("_goblins")
	actor_id = scene.get("_goblins_by_cell")[DEMO.GOBLIN_START_CELL]
	goblin = goblins[actor_id]
	for other_id: int in goblins.keys():
		if other_id != actor_id:
			scene.call("_remove_goblin", other_id)
	goblin.strength = 2
	scene.set("_hero_strength", 10)
	scene.call("_add_inventory_item", load(DEMO.SWORD_PATH), DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_id", DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_texture", load(DEMO.SWORD_PATH))
	scene.call("_refresh_inventory_panel")
	scene.call("_add_inventory_item", load(DEMO.SWORD_PATH), DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_id", DEMO.ITEM_ID_SWORD)
	scene.set("_equipped_weapon_texture", load(DEMO.SWORD_PATH))
	scene.call("_refresh_inventory_panel")
	_check(scene.call("_weapon_strength_bonus") == 5, "Duplicate swords do not stack strength bonuses")
	# Roll fourteen wins only when the live random range includes weapon strength.
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(1000):
		rng.seed = seed_value
		if rng.randi_range(0, 16) == 14:
			rng.seed = seed_value
			break
	scene.call("_resolve_combat", actor_id)
	_check(goblin.strength == 1 and scene.get("_hero_strength") == 10, "Live weapon bonus raises hit chance while keeping damage at one")
	for seed_value in range(100):
		rng.seed = seed_value
		if rng.randi_range(0, 15) < 15:
			rng.seed = seed_value
			break
	var killed_cell: Vector2i = goblin.cell
	scene.call("_resolve_combat", actor_id)
	_check(not goblins.has(actor_id) and scene.call("_is_walkable", killed_cell), "Killed goblin is removed from occupancy and actor state")
	scene.call("_resolve_combat", actor_id) # Removed enemies cannot grant their reward again.
	_check(scene.get("_hero_strength") == 11 and scene.get("_hero_max_strength") == 11, "Victory grants one current and one maximum strength")
	_check(scene.get("_stats_strength_label").text == "Сила: 11/11+5" and scene.get("_hero_strength_label").text == "16", "Victory updates total overhead strength while preserving the weapon bonus")
	queue = scene.get("_turn_queue")
	queue.advance()
	_check(queue.pop_due() == -1, "Killed goblin cannot act from its old queue entry")
	await create_timer(0.4).timeout
	scene.free()


func _load_enemy_chunks(scene: Node2D) -> void:
	var objects: Dictionary = scene.call("_authored_map_objects")
	for cell: Vector2i in objects:
		if DEMO.OBJECT_CATALOG.definition(objects[cell]).category == "enemy":
			scene.call("_load_chunk", scene.call("_chunk_coord_for_cell", cell))
	scene.call("_sync_active_goblins")


func _authored_live_item_count(scene: Node2D) -> int:
	var count := 0
	for item: Sprite2D in scene.get("_items_by_cell").values():
		if item.has_meta("map_origin"):
			count += 1
	return count


func _scheduled_actor_count(scene: Node2D) -> int:
	var count := 0
	for actor: Dictionary in scene.get("_goblins").values():
		if actor.active and not actor.retaliates_only:
			count += 1
	return count


func _authored_count(scene: Node2D, category: String) -> int:
	var count := 0
	var objects: Dictionary = scene.call("_authored_map_objects")
	for cell: Vector2i in objects:
		if DEMO.OBJECT_CATALOG.definition(objects[cell]).category == category and scene.get("_loaded_chunks").has(scene.call("_chunk_coord_for_cell", cell)) and DEMO.OBJECT_CATALOG.can_place_on(objects[cell], scene.call("_terrain_type", cell)):
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
