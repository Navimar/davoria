extends SceneTree

const COMBAT := preload("res://scripts/strength_combat.gd")
const QUEUE := preload("res://scripts/turn_queue.gd")
const AI := preload("res://scripts/goblin_ai.gd")
const SIGHT := preload("res://scripts/actor_sight.gd")
const LEVEL := preload("res://scripts/starter_level.gd")
const DEMO := preload("res://scripts/asset_demo_scene.gd")
const SCENE := preload("res://scenes/asset_demo.tscn")
var _errors: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_combat_rules()
	_check_queue()
	_check_ai()
	await _check_game()
	if _errors.is_empty():
		print("COMBAT CHECK OK: strength, sword, rewards, stable queue, skip chance, bounded pursuit, memory, chunk activation, death, held attacks and responsive turns")
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
	var sword := COMBAT.exchange(10, 2, 1, 0)
	_check(sword.killed and sword.enemy == 0 and sword.player == 10, "Sword adds one damage and kills")
	_check(COMBAT.exchange(0, 10, 1, 0).player == -1, "Exhausted player can still be hurt")
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


func _check_game() -> void:
	var scene: Node2D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var goblins: Dictionary = scene.get("_goblins")
	_check(goblins.size() == LEVEL.GOBLINS.size() and scene.get("_enemies").size() == goblins.size(), "Level contains its live goblins without display actors")
	var actor_id: int = goblins.keys()[0]
	var goblin: Dictionary = goblins[actor_id]
	# Keep subsequent combat assertions isolated from the other encounter.
	for other_id: int in goblins.keys():
		if other_id != actor_id:
			scene.call("_remove_goblin", other_id)
	_check(goblin.cell == DEMO.GOBLIN_START_CELL and scene.call("_is_terrain_walkable", goblin.cell), "Goblin starts on accessible floor")
	_check(goblin.sprite.texture.resource_path == DEMO.GOBLIN_PATH, "Uses the selected red goblin asset")
	_check(goblin.strength >= 1 and goblin.strength <= 50, "Goblin strength matches Bevy range")
	var queue: RefCounted = scene.get("_turn_queue")
	var hero: Sprite2D = scene.get("_hero")
	var start: Vector2i = scene.get("_hero_cell")
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
	_check(queue.current_turn == before and not scene.get("_is_moving"), "No strength means no initiating attack and no spent turn")
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
	scene.call("_resolve_combat", actor_id)
	_check(scene.get("_hero_strength") == -11 and scene.get("_game_over"), "Death threshold is below minus ten as in Bevy")
	var input := InputEventKey.new()
	input.physical_keycode = KEY_R
	input.pressed = true
	scene.call("_unhandled_key_input", input)
	await process_frame
	_check(not scene.get("_game_over") and scene.get("_hero_strength") == 10 and scene.get("_turn_queue").current_turn == 0, "Restart resets hero, enemy and queue")
	goblins = scene.get("_goblins")
	actor_id = goblins.keys()[0]
	goblin = goblins[actor_id]
	for other_id: int in goblins.keys():
		if other_id != actor_id:
			scene.call("_remove_goblin", other_id)
	goblin.strength = 1
	scene.set("_hero_strength", 10)
	var ids: Array = scene.get("_inventory_item_ids")
	ids.append(DEMO.ITEM_ID_SWORD)
	_check(scene.call("_sword_damage_bonus") == 1, "Sword inventory item supplies combat bonus")
	# Seed with a guaranteed winning next roll rather than changing live rules.
	var rng: RandomNumberGenerator = scene.get("_rng")
	for seed_value in range(100):
		rng.seed = seed_value
		if rng.randi_range(0, 10) < 10:
			rng.seed = seed_value
			break
	var killed_cell: Vector2i = goblin.cell
	scene.call("_resolve_combat", actor_id)
	_check(not goblins.has(actor_id) and scene.call("_is_walkable", killed_cell), "Killed goblin is removed from occupancy and actor state")
	_check(scene.get("_hero_strength") == 10 and scene.get("_hero_max_strength") == 11, "Victory raises maximum without healing current strength")
	queue = scene.get("_turn_queue")
	queue.advance()
	_check(queue.pop_due() == -1, "Killed goblin cannot act from its old queue entry")
	await create_timer(0.4).timeout
	scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
