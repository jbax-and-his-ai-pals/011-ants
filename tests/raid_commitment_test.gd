extends SceneTree
var failures := 0
var s
var ai
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func fresh(own: int = 100, enemy: int = 8) -> void:
	s.reset_colony(81923)
	s.reproduction_enabled = false
	s.health.fill(0)
	for i in own: s.health[s.COUNT + i] = 3
	for i in enemy: s.health[i] = 3
	for i in s.health.size(): s.positions[i] = s.nest_for(i)
	s.food_stores.fill(20000)
	s.elapsed = 100
	s.next_raids[0] = INF
	ai.escalation[0] = {"completed": true, "ready_at": 0.0, "seen": s.elapsed}
	ai.think()
	ai.orders.allocate()
func run() -> void:
	s = load("res://main.tscn").instantiate()
	s.colony_count = 2
	root.add_child(s)
	s.set_process(false)
	ai = s.rival_ai
	fresh()
	check(ai.mode == "Raiding" and ai.raid_roster.size() == ai.raid_size, "Real recruits enter an identity-based raid roster")
	var deadline: float = ai.raid_until
	s.casualties[1] += 100
	ai.think()
	check(ai.raid_until == deadline, "Unrelated forager losses do not recall a raid or reset its clock")
	var slot: int = ai.raid_roster.values()[0]
	var identity: int = s.worker_ids[slot]
	s.worker_ids[slot] += 1000000
	ai.inspect_raid()
	check(ai.raid_dead == 1, "A recycled slot cannot masquerade as a surviving party member")
	s.worker_ids[slot] = identity
	s.layers[slot] = 0
	s.positions[slot] = s._center(s.entrance_cell(0))
	s.elapsed = deadline - 1
	s.queen_health[0] -= 2
	ai.think()
	check(ai.raid_until > deadline and ai.raid_counts.progress == 1, "Target queen damage with party inside extends commitment")
	s.elapsed = ai.raid_hard_until - 1
	s.queen_health[0] -= 2
	ai.think()
	check(ai.raid_until == ai.raid_hard_until, "Progress extension stays below the hard campaign limit")
	s.elapsed = ai.raid_hard_until
	ai.think()
	check(ai.raid_until == 0 and ai.next_attack > s.elapsed, "Even a progressing campaign has a hard end and cooldown")
	fresh()
	for i in 8: s.positions[i] = s.nest_position(1) + Vector2(100, 0)
	ai.think()
	ai.orders.allocate()
	check(ai.raid_until > 0 and ai.mode == "Raiding", "Incidental surface pressure does not cancel the committed party")
	check(ai.raid_roster.size() == ai.raid_size, "A guard post does not silently replace or expand the raid party")
	s.layers[0] = 1
	s.positions[0] = s.queen_position(1)
	ai.think()
	ai.orders.allocate()
	check(ai.raid_until == 0 and ai.raid_status.contains("home in danger"), "An enemy at the home queen forces recall")
	fresh()
	s.food_stores[1] = s.upkeep_rate(1) * 10
	ai.think()
	check(ai.raid_until == 0 and ai.raid_status.contains("Food emergency"), "Critical reserves force recall")
	fresh()
	for member in ai.raid_roster.values(): s.roles[member] = s.RECOVERING
	ai.orders.allocate()
	check(ai.raid_roster.size() == ai.raid_size * 2, "Campaign can recruit a bounded replacement wave")
	for member in ai.raid_roster.values(): s.roles[member] = s.RECOVERING
	ai.orders.allocate()
	check(ai.raid_roster.size() == ai.raid_size * 2, "No recruits beyond the campaign budget")
	ai.think()
	check(ai.raid_until == 0 and ai.raid_status.contains("exhausted"), "Unavailable exhausted party ends the campaign")
	# End-to-end: a small fed colony walks the full legacy 1,022px route,
	# traverses the actual shaft, and defeats an undefended queen after 35s.
	for native in [true, false]:
		s.native_enabled = native
		fresh(20, 0)
		check(ai.raid_size == 4 and ai.raid_until > 0, "A viable small colony can finish a deserted nest")
		for tick in 3000:
			s.simulate(s.STEP)
			if s.queen_health[0] <= 0: break
		check(s.queen_health[0] <= 0 and s.elapsed > 135, "Individual raiders finish the queen beyond the old 35s timeout native=%s" % native)
		check(ai.raid_roster.size() <= 8, "Real finishing battle respects recruit budget")
	if failures == 0: print("PASS: party identity/slot reuse, unrelated losses, travel/progress/hard deadlines, incidental/critical defense, emergency recall, bounded recruits and real small-colony finishes in both kernels.")
	quit(1 if failures else 0)
