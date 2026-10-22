extends RefCounted
## Low-frequency colony decisions. Commands use the same individual worker jobs.
const CELL := 160.0
const SIGHT := 190.0
const INTERVAL := 3.0
const PATCH_BUDGET := 64
const MAX_SITES := 64
var sim
var colony := 1
var enemy_id := 0
var orders = preload("res://scripts/colony_commands.gd").new()
var known: Dictionary = {}
var selected: Array[int] = []
var next_think := 0.0
var patch_cursor := 0
var decisions := 0
var mode := "Scouting"
var reason := "Scouts share discoveries; no food site known yet."
var recovering := false
var raid_until := 0.0
var next_attack := 90.0
var raid_roster: Dictionary = {}
var raid_started := 0.0
var raid_hard_until := 0.0
var raid_queen_checkpoint := 100.0
var raid_home_queen := 100.0
var raid_status := "No raid yet."
var raid_counts := {"started": 0, "progress": 0, "recalls": {}}
var raid_living := 0
var raid_dead := 0
var raid_inside := 0
var raid_size := 0
var home_threat := 0
var source_scores: Array = []
var last_think_usec := 0
var max_think_usec := 0
# Strategy randomness never consumes a worker's RNG stream.
var target_rng := RandomNumberGenerator.new()
var target_scores: Array = []
var target_reason := "Waiting for scouts."
var target_since := -INF
var target_sample_time := 0.0
var threat_memory := PackedFloat32Array([0, 0, 0])
const TARGET_TIE := 0.08
const TARGET_MARGIN := 0.18
const TARGET_HOLD := 30.0

func setup(owner_node, colony_id: int = 1) -> void:
	sim = owner_node
	colony = colony_id
	orders.setup(sim, colony)

func reset() -> void:
	orders.reset()
	known.clear()
	selected.clear()
	source_scores.clear()
	patch_cursor = 0
	next_think = 0
	decisions = 0
	mode = "Scouting"
	reason = "Scouts share discoveries; no food site known yet."
	recovering = false
	raid_until = 0
	next_attack = 90
	raid_roster = {}
	raid_started = 0
	raid_hard_until = 0
	raid_queen_checkpoint = 100
	raid_home_queen = 100
	raid_status = "No raid yet."
	raid_counts = {"started": 0, "progress": 0, "recalls": {}}
	raid_living = 0
	raid_dead = 0
	raid_inside = 0
	raid_size = 0
	home_threat = 0
	last_think_usec = 0
	max_think_usec = 0
	enemy_id = -1
	target_since = -INF
	target_sample_time = sim.elapsed
	threat_memory.fill(0)
	target_scores.clear()
	target_reason = "Waiting for scouts."
	target_rng.seed = sim.world_seed + 7919 * (colony + 1) + 32452843

func update() -> void:
	if not sim.match_result.is_empty(): return
	if sim.queen_health[colony] <= 0:
		orders.markers.clear()
		orders.allocate()
		mode = "Eliminated"
		return
	if sim.elapsed >= next_think:
		think()
		next_think = sim.elapsed + INTERVAL
	# Recruitment cadence matches player orders, independently of decision cadence.
	orders.allocate()

func cell(point: Vector2) -> Vector2i:
	return Vector2i(point / CELL)

func vicinity(grid: Dictionary, point: Vector2) -> int:
	var center := cell(point)
	var count := 0
	for y in range(-1, 2):
		for x in range(-1, 2): count += grid.get(center + Vector2i(x, y), 0)
	return count

func visible(point: Vector2, scouts: Dictionary) -> bool:
	if point.distance_squared_to(sim.nest_position(colony)) < SIGHT * SIGHT: return true
	var center := cell(point)
	# Two-cell reach covers the circular sight radius even at cell boundaries.
	for y in range(-2, 3):
		for x in range(-2, 3):
			for worker in scouts.get(center + Vector2i(x, y), []):
				if sim.positions[worker].distance_squared_to(point) < SIGHT * SIGHT: return true
	return false

func think() -> void:
	if not sim.match_result.is_empty(): return
	var start := Time.get_ticks_usec()
	decisions += 1
	orders.sample()
	var scouts := {}
	var friendly := {}
	var enemy := {}
	var population := PackedInt32Array([0, 0, 0])
	var hostile_grids: Array = [{}, {}, {}]
	var pressure := PackedFloat32Array([0, 0, 0])
	home_threat = 0
	var queen_threat := 0
	for i in sim.health.size():
		if sim.health[i] <= 0: continue
		population[sim.colonies[i]] += 1
		var other: int = sim.colonies[i]
		if other != colony and sim.layers[i] == colony:
			pressure[other] += 0.25
			if sim.positions[i].distance_squared_to(sim.queen_position(colony)) < 70 * 70: queen_threat += 1
		if sim.layers[i] != sim.SURFACE: continue
		var key := cell(sim.positions[i])
		if sim.colonies[i] == colony:
			friendly[key] = friendly.get(key, 0) + 1
			if not scouts.has(key): scouts[key] = []
			scouts[key].append(i)
		else:
			enemy[key] = enemy.get(key, 0) + 1
			hostile_grids[other][key] = hostile_grids[other].get(key, 0) + 1
			if sim.positions[i].distance_squared_to(sim.nest_position(colony)) < 240 * 240:
				home_threat += 1
				pressure[other] += 1.0 / 24.0
	# Bounded discovery work even if a match accumulates many dropped-food patches.
	for n in mini(PATCH_BUDGET, sim.foods.size()):
		var index: int = patch_cursor % sim.foods.size()
		patch_cursor += 1
		var patch: Dictionary = sim.foods[index]
		if patch.get("layer", -1) != sim.SURFACE: continue
		if not visible(patch.pos, scouts): continue
		if patch.amount <= 0:
			known.erase(index)
			continue
		known[index] = {"pos": patch.pos, "amount": patch.amount, "seen": sim.elapsed, "friends": vicinity(friendly, patch.pos), "enemies": vicinity(enemy, patch.pos)}
	# Keep scoring and refresh bounded as thousands of dropped cargo piles accrue.
	if known.size() > MAX_SITES:
		var useful: Array = known.keys()
		useful.sort_custom(func(a, b): return known[a].amount > known[b].amount if known[a].amount != known[b].amount else a < b)
		for n in range(MAX_SITES, useful.size()): known.erase(useful[n])
	# Refresh already-known visible sites, even when the discovery cursor is elsewhere.
	for index in known.keys():
		if sim.elapsed - known[index].seen > 60:
			known.erase(index)
			continue
		if not visible(known[index].pos, scouts): continue
		var patch: Dictionary = sim.foods[index]
		if patch.amount <= 0: known.erase(index); continue
		known[index].amount = patch.amount
		known[index].seen = sim.elapsed
		known[index].friends = vicinity(friendly, patch.pos)
		known[index].enemies = vicinity(enemy, patch.pos)
	var upkeep: float = maxf(0.001, sim.upkeep_rate(colony))
	var reserves: float = sim.food_stores[colony] / upkeep
	var recent_losses: int = orders.report.combat + orders.report.hunger
	var heavy_losses := recent_losses >= maxi(8, ceili(population[colony] * 0.04))
	if reserves < 35 or heavy_losses or sim.queen_health[colony] < 60: recovering = true
	elif reserves > 65 and not heavy_losses and sim.queen_health[colony] >= 70: recovering = false
	var invaded: bool = sim.invaders_in(colony) > 0
	var defend := invaded or home_threat >= 8
	# Rank remembered food by delivery distance, useful quantity and local danger.
	source_scores.clear()
	for index in known:
		var site: Dictionary = known[index]
		var distance: float = site.pos.distance_to(sim.nest_position(colony))
		var risk: float = float(site.enemies) / maxf(12, site.friends + 6)
		var score: float = minf(site.amount, population[colony] * 1.5) / (distance + 180) / (1 + risk * (3 if recovering else 1.5))
		if index in selected: score *= 1.2 # Prefer a stable route over marginal gains.
		if sim.elapsed - site.seen > 15: score *= 0.65
		source_scores.append({"index": index, "score": score})
	source_scores.sort_custom(func(a, b): return a.score > b.score if a.score != b.score else a.index < b.index)
	selected.clear()
	for item in source_scores:
		if selected.size() == 2: break
		selected.append(item.index)
	var contested := -1
	for index in selected:
		var site: Dictionary = known[index]
		if site.enemies >= 3 and site.enemies <= site.friends * 1.5 + 12:
			contested = index
			break
	choose_target(population, hostile_grids, pressure)
	if target_scores.is_empty():
		orders.markers.clear()
		orders.assignments_present = true
		last_think_usec = Time.get_ticks_usec() - start
		return
	var finishing: bool = is_finisher(enemy_id, population)
	var advantage: bool = population[colony] >= population[enemy_id] * 1.1 or sim.queen_health[enemy_id] < 50
	var critical_home: bool = queen_threat > 0 or sim.invaders_in(colony) >= 4 or (invaded and sim.queen_health[colony] < 60) or home_threat >= maxi(12, ceili(population[colony] * 0.15))
	if raid_until > 0:
		inspect_raid()
		if not sim.invasions_enabled: end_raid("Invasions disabled")
		elif sim.queen_health[enemy_id] <= 0: end_raid("Target eliminated")
		elif reserves < 20: end_raid("Food emergency")
		elif critical_home or sim.queen_health[colony] < raid_home_queen - 5: end_raid("Queen or home in danger")
		elif raid_dead >= maxi(2, ceili(raid_size * 2 * 0.6)): end_raid("Party losses")
		elif raid_living == 0 and raid_roster.size() >= raid_size * 2: end_raid("Party exhausted")
		elif sim.elapsed >= raid_until or sim.elapsed >= raid_hard_until: end_raid("No progress / time limit")
	# Global foraging losses justify caution, but must not permanently veto an
	# affordable finishing attack. Food/queen emergencies still prevent launch.
	var recovery_safe: bool = not recovering or (finishing and reserves >= 75 and sim.queen_health[colony] >= 70)
	if raid_until == 0 and enemy_id >= 0 and sim.queen_health[enemy_id] > 0 and sim.invasions_enabled and not defend and recovery_safe and reserves >= 75 and population[colony] >= (12 if finishing else 30) and population[colony] >= population[enemy_id] * 0.9 and sim.elapsed >= next_attack:
		start_raid(population, advantage)
	mode = "Raiding" if raid_until > 0 else ("Defending" if defend else ("Recovering" if recovering else ("Contesting" if contested >= 0 else ("Gathering" if not selected.is_empty() else "Scouting"))))
	orders.labor[0] = 3 if recovering or defend else 2
	orders.labor[1] = 3 if defend or (raid_until > 0 and advantage) else (2 if contested >= 0 or raid_until > 0 else 1)
	orders.labor[2] = 0 # Rival tunnel excavation is not part of this strategy layer.
	var plan: Array = []
	for index in selected: plan.append(marker(1000 + index, orders.FORAGE, known[index].pos))
	# Reserve the committed party first; a small guard post cannot silently
	# consume its security quota. Existing automatic nest defenders still act.
	if raid_until > 0:
		var raid := marker(400001, orders.RAID, sim.nest_position(enemy_id))
		raid["roster"] = raid_roster
		raid["recruit_cap"] = raid_size * 2
		raid["party_limit"] = raid_size
		plan.append(raid)
	if defend:
		plan.append(marker(300001, orders.GUARD, sim.nest_position(colony)))
	elif contested >= 0:
		plan.append(marker(300001, orders.GUARD, known[contested].pos))
	orders.markers = plan
	orders.assignments_present = true # Also release assignments when plan becomes empty.
	if raid_until > 0: reason = "Pressing %s with a bounded party." % sim.COLONY_NAMES[enemy_id]
	elif defend: reason = "Nest threatened: guarding the entrance."
	elif recovering: reason = "Reserves, queen health or recent losses favor food and recovery."
	elif contested >= 0: reason = "Shared food route: protect collectors with a guard post."
	elif selected.is_empty(): reason = "Scouts search for food; no worthwhile known source remains."
	else: reason = "Favor useful food near home; keep scouts exploring."
	last_think_usec = Time.get_ticks_usec() - start
	max_think_usec = maxi(max_think_usec, last_think_usec)

func is_finisher(candidate: int, population: PackedInt32Array) -> bool:
	if candidate < 0 or sim.queen_health[candidate] <= 0: return false
	return population[colony] >= 12 and (population[candidate] <= maxi(8, int(population[colony] * 0.35)) or (sim.queen_health[candidate] < 50 and population[colony] >= population[candidate] * 0.9))

func start_raid(population: PackedInt32Array, advantage: bool) -> void:
	raid_started = sim.elapsed
	var travel: float = sim.nest_position(colony).distance_to(sim.nest_position(enemy_id)) / 50.0 + 12
	raid_until = sim.elapsed + clampf(travel + 40, 50, 100)
	raid_hard_until = sim.elapsed + 180
	raid_size = mini(24 if advantage else 12, maxi(1, population[colony] / 5))
	raid_roster = {}
	raid_queen_checkpoint = sim.queen_health[enemy_id]
	raid_home_queen = sim.queen_health[colony]
	raid_living = 0
	raid_dead = 0
	raid_inside = 0
	raid_status = "Assembling; travel and tunnel time included."
	raid_counts.started += 1

func inspect_raid() -> void:
	raid_living = 0
	raid_dead = 0
	raid_inside = 0
	for identity in raid_roster:
		var slot: int = raid_roster[identity]
		if sim.worker_ids[slot] != identity or sim.health[slot] <= 0:
			raid_dead += 1
			continue
		if sim.roles[slot] == sim.INVADER and sim.worker_order_ids[slot] == 400001 + (500000 if colony == 2 else 0):
			raid_living += 1
			if sim.layers[slot] == enemy_id: raid_inside += 1
	if sim.queen_health[enemy_id] < raid_queen_checkpoint - 0.1:
		if raid_inside > 0:
			raid_until = minf(raid_hard_until, maxf(raid_until, sim.elapsed + 35))
			raid_counts.progress += 1
		raid_queen_checkpoint = sim.queen_health[enemy_id]
	raid_status = "%d active / %d inside / %d lost; %d/%d recruited." % [raid_living, raid_inside, raid_dead, raid_roster.size(), raid_size * 2]

func end_raid(why: String) -> void:
	if raid_until > 0:
		raid_counts.recalls[why] = raid_counts.recalls.get(why, 0) + 1
	raid_until = 0
	next_attack = sim.elapsed + 45
	raid_status = "Recalled: " + why + "."

func choose_target(population: PackedInt32Array, hostile_grids: Array, pressure: PackedFloat32Array) -> void:
	var age: float = maxf(0, sim.elapsed - target_sample_time)
	target_sample_time = sim.elapsed
	var previous := enemy_id
	target_scores.clear()
	for candidate in sim.colony_count:
		if candidate == colony or sim.queen_health[candidate] <= 0: continue
		threat_memory[candidate] = maxf(minf(1, pressure[candidate]), threat_memory[candidate] * exp(-age / 30.0))
		var route_pressure := 0
		for index in selected:
			if sim.elapsed - known[index].seen < 0.01:
				route_pressure += vicinity(hostile_grids[candidate], known[index].pos)
		var threat := 1.2 * threat_memory[candidate]
		var food := 0.6 * minf(1, route_pressure / 24.0)
		var strength := 0.25 * float(population[colony]) / maxf(1, population[colony] + population[candidate])
		var queen: float = 0.2 * (1 - sim.queen_health[candidate] / 100.0)
		var travel := 0.15 * maxf(0, 1 - sim.nest_position(colony).distance_to(sim.nest_position(candidate)) / 1800.0)
		target_scores.append({"colony": candidate, "score": threat + food + strength + queen + travel, "threat": threat, "food": food, "strength": strength, "queen": queen, "travel": travel, "finish": 0.35 if is_finisher(candidate, population) else 0.0})
		target_scores[-1].score += target_scores[-1].finish
	if target_scores.is_empty():
		if raid_until > 0: end_raid("Target eliminated")
		enemy_id = -1
		target_reason = "No surviving hostile queen."
		return
	target_scores.sort_custom(func(a, b): return a.score > b.score if a.score != b.score else a.colony < b.colony)
	if previous >= 0 and sim.queen_health[previous] <= 0 and raid_until > 0:
		end_raid("Target eliminated")
	var current: Dictionary = {}
	for entry in target_scores:
		if entry.colony == previous: current = entry
	# Never redirect a living raid in flight; dead targets release immediately.
	if not current.is_empty() and raid_until > 0:
		target_reason = "Holding %s until the current raid ends." % sim.COLONY_NAMES[previous]
		return
	if not current.is_empty() and (sim.elapsed - target_since < TARGET_HOLD or target_scores[0].score < current.score + TARGET_MARGIN):
		target_reason = "Holding %s: %s." % [sim.COLONY_NAMES[previous], "30-second commitment" if sim.elapsed - target_since < TARGET_HOLD else "no challenger leads by 0.18"]
		return
	var options: Array = []
	for entry in target_scores:
		if target_scores[0].score - entry.score <= TARGET_TIE: options.append(entry)
	var chosen: Dictionary = options[target_rng.randi_range(0, options.size() - 1)]
	enemy_id = chosen.colony
	target_since = sim.elapsed
	target_reason = "%s %s: %s." % ["Selected" if previous < 0 else "Switched to", sim.COLONY_NAMES[enemy_id], "seeded choice within 0.08" if options.size() > 1 else "highest score"]

func target_explanation() -> String:
	var text := "Target: %s\n" % (sim.COLONY_NAMES[enemy_id] if enemy_id >= 0 else "Undecided")
	text += target_reason
	for entry in target_scores:
		text += "\n%s %.2f | threat %.2f food %.2f strength %.2f queen %.2f travel %.2f finish %.2f" % [sim.COLONY_NAMES[entry.colony], entry.score, entry.threat, entry.food, entry.strength, entry.queen, entry.travel, entry.finish]
	return text

func marker(id: int, kind: int, point: Vector2) -> Dictionary:
	return {"id": id + (500000 if colony == 2 else 0), "kind": kind, "pos": point, "seen_food": true, "assigned": 0, "status": "Active"}

func build_ui() -> void:
	sim.rival_panel = Panel.new()
	sim.rival_panel.position = Vector2(324, 184)
	sim.rival_panel.size = Vector2(480, 358)
	sim.rival_panel.add_theme_stylebox_override("panel", sim._style(Color("19251e"), 12, sim.RIVAL))
	sim.ui.add_child(sim.rival_panel)
	var previous = sim.ui
	sim.ui = sim.rival_panel
	sim._button("Switch colony", Vector2(188, 8), Vector2(138, 28), func(): sim.inspected_ai = 2 if sim.inspected_ai == 1 and sim.colony_count == 3 else 1; sim._update_ui())
	sim._label("AI STRATEGY", Vector2(16, 10), 14, sim.RIVAL, true, 310)
	sim._button("x", Vector2(435, 8), Vector2(30, 28), sim.toggle_rival_plan)
	sim.rival_plan_text = sim._label("", Vector2(16, 40), 12, sim.INK, false, 448)
	sim.rival_plan_text.size.y = 308
	sim.rival_plan_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sim.ui = previous
	sim.rival_panel.visible = false

func update_ui() -> void:
	if not is_instance_valid(sim.rival_plan_button): return
	var observed = sim.rival_ai if sim.inspected_ai == 1 else sim.third_ai
	sim.rival_plan_button.text = "%s: %s [I]" % [sim.COLONY_NAMES[sim.inspected_ai], observed.mode] if sim.rival_ai_enabled else "Rival AI disabled [I]"
	sim.rival_plan_button.tooltip_text = "Inspect the rival's current strategy and labor. Decisions use shared scout discoveries and local threat counts; no stat or resource bonuses."
	if not is_instance_valid(sim.rival_plan_text) or not sim.rival_panel.visible: return
	var assigned := PackedInt32Array([0, 0, 0])
	for order in observed.orders.markers:
		assigned[0 if order.kind == orders.FORAGE else (1 if order.kind == orders.GUARD else 2)] += order.assigned
	sim.rival_plan_text.text = "%s: %s\nKnown food %d / chosen %d\nWorkers: %d guided / %d guards / %d raiders\nLabor: forage %s / security %s\nDecision interval: 3 simulated seconds" % [observed.mode, observed.reason, observed.known.size(), observed.selected.size(), assigned[0], assigned[1], assigned[2], orders.PRIORITIES[observed.orders.labor[0]], orders.PRIORITIES[observed.orders.labor[1]]]
	sim.rival_plan_text.text += "\n" + observed.raid_status + "\n\n" + observed.target_explanation()


