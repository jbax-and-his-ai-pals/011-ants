extends SceneTree
var failures := 0
var s
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func fresh() -> void:
	s.reset_colony(81923)
	s.reproduction_enabled = false
	s.invasions_enabled = false
	s.combat_enabled = false
	s.food_cycles_enabled = false
	s.foods.clear()
	# Small live crews exercise both kernels; renderer tests retain all 6,000.
	s.health.fill(0)
	for c in 3:
		for n in 128: s.health[c * s.COUNT + n] = 3
	for i in s.health.size(): s.positions[i] = s.nest_position(s.colonies[i])
	for c in 3:
		s.food_stores[c] = 14000
		s.protein_stores[c] = 2000
func advance(ticks: int) -> void:
	for tick in ticks: s.simulate(s.STEP)
func run() -> void:
	s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	for native in [false, true]:
		fresh()
		s.native_enabled = native
		for c in [1, 2]:
			var ai = s.rival_ai if c == 1 else s.third_ai
			var before: int = s.storage_capacity[c]
			ai.think()
			check(ai.nest.project.contains("Storage") and s.pending_count(c) > 0, "Both rivals plan capacity from real storage pressure")
			check(s.storage_capacity[c] == before, "Designating a room grants no free capacity")
			var queued: int = s.pending_count(c)
			for repeat in 5: ai.think()
			check(s.pending_count(c) == queued and ai.nest.projects == 1, "A stable project bounds repeated decisions")
		check(s.pending_count() == 0, "Rival designations do not touch the player's nest")
		advance(2400)
		for c in [1, 2]:
			check(s.storage_capacity[c] >= 36000 and s.nest_planner(c).dug >= 9, "Real rival workers excavate connected storage in both kernels")
			check(s.pending_count(c) == 0 and s.digger_count(c) == 0, "Completed rival construction releases its crew")
			var at_post := false
			for i in s.colony_workers[c]:
				if s.health[i] > 0 and s.roles[i] == s.WARDEN and s.layers[i] == c and s.positions[i].distance_to(s.worker_order_goals[i]) < 2: at_post = true
			check(at_post, "Rival guards physically enter and hold the key corridor")
		fresh()
		s.native_enabled = native
		for c in [1, 2]:
			s.food_stores[c] = 3000
			for n in 15: s.brood[c].append({"cell": s.chambers.brood_cells[c][n / 2], "stage": 0, "age": 0.0})
			var ai = s.rival_ai if c == 1 else s.third_ai
			ai.nest.think(2000, false)
			ai.think()
			check(ai.nest.project.contains("Brood"), "Brood crowding with available food requests a nursery")
		advance(2400)
		for c in [1, 2]: check(s.brood_capacity[c] >= 36, "Workers excavate additional real brood slots")
	# Explicit busy-corridor fixture; no free excavation, inner throat preserved.
	fresh()
	s.food_stores[1] = 3000
	var ai = s.rival_ai
	var busy: int = s._idx(s.chamber_cell(1) + Vector2i(0, -8))
	s.tunnel_occupancy[s.CELLS + busy] = 8
	ai.think()
	check(ai.nest.widened and ai.nest.project.contains("Widen") and s.pending_count(1) == 20, "Congested haul shaft queues one bounded widening project")
	var throat: int = s._idx(s.chamber_cell(1) + Vector2i(2, -3))
	check(not ai.nest.pending.has(throat), "Widening preserves the inner defensive throat")
	advance(3000)
	check(s.pending_count(1) == 0 and s.rival_earth[busy - 2] == 1 and s.rival_earth[busy + 2] == 1, "Individual workers finish both new traffic lanes")
	# Emergency decisions retain existing work, reduce construction and move guards in.
	fresh()
	ai.think()
	var old_queue: int = s.pending_count(1)
	s.food_stores[1] = 5
	s.layers[0] = 1
	s.positions[0] = s.queen_position(1)
	s.roles[0] = s.INVADER
	ai.think()
	check(ai.orders.labor[2] == 1 and s.pending_count(1) == old_queue, "Emergency labor throttles construction without discarding work")
	var inner := false
	for marker in ai.orders.markers:
		if marker.get("layer", -1) == 1:
			inner = marker.pos == s._center(s.chamber_cell(1) + Vector2i(0, -5))
	check(inner, "An invasion shifts the nest post to the inner junction")
	ai.update()
	var security := 0
	for i in s.colony_workers[1]:
		if s.health[i] > 0 and s.roles[i] in [s.INVADER, s.WARDEN]: security += 1
	check(security <= 48 and s.digger_count(1) <= 6, "Construction and guards obey existing real labor budgets")
	s.queen_health[1] = 0
	ai.update()
	check(s.digger_count(1) == 0 and ai.orders.markers.is_empty(), "A dead queen releases construction and security crews")
	# Deliberate tunnel detour: planner opens a shorter safe route, not free tiles.
	fresh()
	var base: Vector2i = s.chamber_cell(1)
	for y in range(-12, -6):
		for x in range(-1, 2): s.rival_earth[s._idx(base + Vector2i(x, y))] = 0
	for y in range(-13, -4): s.rival_earth[s._idx(base + Vector2i(6, y))] = 1
	for y in [-13, -5]:
		for x in range(0, 7): s.rival_earth[s._idx(base + Vector2i(x, y))] = 1
	s.chambers.dirty = true
	s.chambers.rebuild()
	var start: Vector2i = s.entrance_cell(1) + Vector2i(0, 2)
	var goal: Vector2i = base + Vector2i(1, 0)
	var before: int = s.tunnel_route(start, goal, 1).size()
	check(ai.nest.shortcut() and s.pending_count(1) <= 32, "Planner identifies a bounded detour shortcut")
	ai.nest.project = "Route shortcut"
	ai.orders.labor[2] = 3
	s.rival_ai_enabled = false
	s._allocate_workers(1)
	advance(2400)
	check(s.pending_count(1) == 0 and s.tunnel_route(start, goal, 1).size() < before, "Digging a planned shortcut shortens an actual route")
	fresh()
	s.food_stores[1] = 5
	ai.think()
	check(s.pending_count(1) == 0 and ai.nest.reason.contains("recovery"), "Poor colonies keep workers on food rather than speculative growth")
	s.reset_colony(81923)
	check(ai.nest.projects == 0 and ai.nest.pending.is_empty() and ai.nest.progress.is_empty(), "Reset clears all planner state")
	# Equal-controller diagnostics must also give the observer's Amber AI the
	# same real construction labor, rather than the inactive player UI budget.
	var observer = load("res://tests/observed_colony.gd").new()
	root.add_child(observer)
	observer.set_process(false)
	observer.equal_controllers = true
	observer.invasions_enabled = false
	observer.combat_enabled = false
	observer.food_stores[0] = 14000
	observer.protein_stores[0] = 2000
	observer.player_ai.update()
	check(observer.pending_count() > 0 and observer.digger_count() == 24, "Equal-controller observer uses its own AI construction labor")
	for tick in 600: observer.simulate(observer.STEP)
	check(observer.dug > 0, "Observer's Amber AI physically excavates like the rivals")
	observer.queue_free()
	if failures == 0: print("PASS: both rival planners, actual storage/brood excavation in both kernels, stable bounded projects, real corridor guards, traffic lanes, measured route shortcut, emergencies, labor limits and reset.")
	s.queue_free()
	quit(1 if failures else 0)
