extends RefCounted
## Low-frequency colony decisions. Commands use the same individual worker jobs.
const CELL := 160.0
const SIGHT := 190.0
const INTERVAL := 3.0
const PATCH_BUDGET := 64
const MAX_SITES := 64
var sim
var nest = preload("res://scripts/nest_planner.gd").new()
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
var raid_budget := 0
var raid_phase := "invasion"
var raid_goal := Vector2.ZERO
var raid_evidence := ""
var probe_arrived_at := -1.0
var probe_failures: Dictionary = {}
var escalation: Dictionary = {} # Target colony -> successful probe and recovery time.
var phase_counts := {"probes": 0, "probes_completed": 0, "invasions": 0}
const PROBE_HOLD := 8.0
const ESCALATION_GAP := 45.0
const PROBE_RETRY := 75.0
const PROBE_MEMORY := 600.0
var home_threat := 0
var source_scores: Array = []
var route_contacts: Dictionary = {} # Only observed 160px sectors, twenty-second memory.
var route_losses: Dictionary = {}
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
	nest.setup(self)

func reset() -> void:
	orders.reset()
	nest.reset()
	known.clear()
	selected.clear()
	source_scores.clear()
	route_contacts.clear(); route_losses.clear()
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
	raid_budget = 0
	raid_phase = "invasion"
	raid_goal = Vector2.ZERO
	raid_evidence = ""
	probe_arrived_at = -1
	escalation.clear()
	probe_failures.clear()
	phase_counts = {"probes": 0, "probes_completed": 0, "invasions": 0}
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
		if raid_until > 0: end_raid("Home queen eliminated")
		orders.markers.clear()
		orders.allocate()
		sim._allocate_workers(colony)
		mode = "Eliminated"
		return
	if sim.elapsed >= next_think:
		think()
		next_think = sim.elapsed + INTERVAL
	# Recruitment cadence matches player orders, independently of decision cadence.
	orders.allocate()
	sim._allocate_workers(colony)

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
	sim.nutrition.refresh()
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
	# Coarse route evidence is observed by our own scouts, including public sites.
	var watched_enemy := {}
	for key in enemy:
		if visible((Vector2(key) + Vector2(.5, .5)) * CELL, scouts):
			watched_enemy[key] = enemy[key]
			route_contacts[key] = {"count": enemy[key], "seen": sim.elapsed}
	for key in route_contacts.keys():
		if sim.elapsed - route_contacts[key].seen > 20 or (not watched_enemy.has(key) and visible((Vector2(key) + Vector2(.5, .5)) * CELL, scouts)): route_contacts.erase(key)
	route_losses.clear()
	for n in range(orders.loss_head, orders.losses.size()):
		var loss: Dictionary = orders.losses[n]
		if loss.layer == -1 and not loss.hunger and sim.elapsed - loss.time <= 30:
			var key := cell(loss.pos)
			route_losses[key] = route_losses.get(key, 0) + 1
	# Bounded discovery work even if a match accumulates many dropped-food patches.
	for n in mini(PATCH_BUDGET, sim.foods.size()):
		var index: int = patch_cursor % sim.foods.size()
		patch_cursor += 1
		var patch: Dictionary = sim.foods[index]
		if patch.get("layer", -1) != sim.SURFACE: continue
		var forecast: int = patch.get("forecast", 0) if patch.get("arrival", 0.0) > sim.elapsed else 0
		var watched := visible(patch.pos, scouts)
		if not watched and forecast <= 0: continue
		var quantity: int = maxi(patch.amount, forecast) if watched else forecast
		if quantity <= 0:
			known.erase(index)
			continue
		known[index] = {"pos": patch.pos, "amount": quantity, "seen": sim.elapsed, "friends": vicinity(friendly, patch.pos), "enemies": vicinity(watched_enemy, patch.pos)}
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
		var patch: Dictionary = sim.foods[index]
		var forecast: int = patch.get("forecast", 0) if patch.get("arrival", 0.0) > sim.elapsed else 0
		var watched := visible(known[index].pos, scouts)
		if not watched and forecast <= 0: continue
		var quantity: int = maxi(patch.amount, forecast) if watched else forecast
		if quantity <= 0: known.erase(index); continue
		known[index].amount = quantity
		known[index].seen = sim.elapsed
		known[index].friends = vicinity(friendly, patch.pos)
		known[index].enemies = vicinity(watched_enemy, patch.pos)
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
		source_scores.append(score_source(index, population[colony]))
	source_scores.sort_custom(func(a, b): return a.score > b.score if a.score != b.score else a.index < b.index)
	selected.clear()
	for item in source_scores:
		if selected.size() == 3: break
		if not selected.is_empty() and item.score < source_scores[0].score * .30: break
		# A third near-equivalent route prevents arbitrary index/rounding ties
		# from always excluding one equally useful direction. Labor stays fixed.
		if selected.size() == 2 and item.score < source_scores[1].score * 0.95: break
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
		elif raid_dead >= (maxi(1, ceili(raid_budget * .5)) if raid_phase == "probe" else maxi(2, ceili(raid_budget * .6))): end_raid("Probe repelled" if raid_phase == "probe" else "Party losses")
		elif raid_living == 0 and raid_roster.size() >= raid_budget: end_raid("Probe repelled" if raid_phase == "probe" else "Party exhausted")
		elif raid_phase == "probe" and probe_arrived_at >= 0 and sim.elapsed >= probe_arrived_at + PROBE_HOLD: end_raid("Probe complete")
		elif sim.elapsed >= raid_until or sim.elapsed >= raid_hard_until: end_raid("No progress / time limit")
	# Global foraging losses justify caution, but must not permanently veto an
	# affordable finishing attack. Food/queen emergencies still prevent launch.
	var recovery_safe: bool = not recovering or (finishing and reserves >= 75 and sim.queen_health[colony] >= 70)
	if raid_until == 0 and enemy_id >= 0 and sim.queen_health[enemy_id] > 0 and sim.invasions_enabled and not defend and recovery_safe and reserves >= 75 and population[colony] >= (12 if finishing else 30) and population[colony] >= population[enemy_id] * 0.9 and sim.elapsed >= next_attack and sim.game_modes.automatic_raids_allowed(colony, population[colony]):
		var intel: Dictionary = escalation.get(enemy_id, {})
		var decisive: bool = finishing or population[colony] >= population[enemy_id] * 1.25
		var qualified: bool = intel.get("completed", false) or (intel.get("repelled_twice", false) and decisive)
		var ready: bool = qualified and sim.elapsed >= intel.get("ready_at", INF) and sim.elapsed - intel.get("seen", -INF) <= PROBE_MEMORY
		start_raid(population, advantage, not ready)
	mode = ("Probing" if raid_phase == "probe" else "Raiding") if raid_until > 0 else ("Defending" if defend else ("Recovering" if recovering else ("Contesting" if contested >= 0 else ("Gathering" if not selected.is_empty() else "Scouting"))))
	orders.labor[0] = 3 if recovering or defend else 2
	orders.labor[1] = 3 if defend or (raid_until > 0 and advantage) else (2 if contested >= 0 or raid_until > 0 else 1)
	nest.think(population[colony], invaded)
	orders.labor[2] = (1 if defend or recovering else 3) if not nest.pending.is_empty() else 0
	# Preparation is a small project, not a reason to divert 24 founders.
	if sim.game_mode == sim.game_modes.FOUNDING and nest.project.begins_with("Prepare daughter"):
		orders.labor[2] = mini(orders.labor[2],1)
	var plan: Array = []
	for index in selected:
		var food_order := marker(1000 + index, orders.FORAGE, known[index].pos)
		for entry in source_scores:
			if entry.index == index: food_order["route_weight"] = 1.0 / (1 + entry.risk * (3 if recovering else 1.5)); break
		plan.append(food_order)
	# Reserve the committed party first; a small guard post cannot silently
	# consume its security quota. Existing automatic nest defenders still act.
	if raid_until > 0:
		var raid := marker(400001, orders.RAID, raid_goal)
		raid["roster"] = raid_roster
		raid["recruit_cap"] = raid_budget
		raid["party_limit"] = raid_size
		raid["phase"] = raid_phase
		plan.append(raid)
	var corridor: Dictionary = nest.defense_marker(invaded)
	if not corridor.is_empty(): plan.append(corridor)
	if defend:
		plan.append(marker(300001, orders.GUARD, sim.nest_position(colony)))
	elif contested >= 0:
		plan.append(marker(300001, orders.GUARD, known[contested].pos))
	orders.markers = plan
	orders.assignments_present = true # Also release assignments when plan becomes empty.
	if raid_until > 0: reason = ("Probing %s outside its nest; withdraw after observing the approach." if raid_phase == "probe" else "Invading %s after an earlier probe and a response interval.") % sim.COLONY_NAMES[enemy_id]
	elif defend: reason = "Nest threatened: guarding the entrance."
	elif recovering: reason = "Reserves, queen health or recent losses favor food and recovery."
	elif contested >= 0: reason = "Shared food route: protect collectors with a guard post."
	elif selected.is_empty(): reason = "Scouts search for food; no worthwhile known source remains."
	else: reason = "Balance trip time, colony shortages and observed route danger; keep scouts exploring."
	if raid_until > 0 and raid_phase != "probe": reason += " " + raid_evidence
	if sim.game_mode == sim.game_modes.FOUNDING and not sim.game_modes.automatic_raids_allowed(colony, population[colony]):
		reason += " Founding: raids wait for 5 minutes and 60 workers."
	if raid_until == 0 and sim.elapsed < next_attack and phase_counts.probes > 0:
		reason += " Response interval: no new attack for %ds." % ceili(next_attack - sim.elapsed)
	reason += " " + sim.nutrition.status(colony)
	last_think_usec = Time.get_ticks_usec() - start
	max_think_usec = maxi(max_think_usec, last_think_usec)

func is_finisher(candidate: int, population: PackedInt32Array) -> bool:
	if candidate < 0 or sim.queen_health[candidate] <= 0: return false
	return population[colony] >= 12 and (population[candidate] <= maxi(8, int(population[colony] * 0.35)) or (sim.queen_health[candidate] < 50 and population[colony] >= population[candidate] * 0.9))

func start_raid(population: PackedInt32Array, advantage: bool, probe: bool = false) -> void:
	raid_started = sim.elapsed
	var travel: float = sim.nest_position(colony).distance_to(sim.nest_position(enemy_id)) / 50.0 + 12
	raid_until = sim.elapsed + clampf(travel + 40, 50, 100)
	raid_hard_until = sim.elapsed + 180
	raid_size = mini(24 if advantage else 12, maxi(1, population[colony] / 5))
	raid_phase = "probe" if probe else "invasion"
	raid_goal = sim.nest_position(enemy_id)
	probe_arrived_at = -1
	if probe:
		raid_size = mini(6, maxi(2, ceili(population[colony] / 40.0)))
		raid_goal += (sim.nest_position(colony) - raid_goal).normalized() * 180
		var approach: float = sim.nest_position(colony).distance_to(raid_goal) / 45.0
		raid_until = sim.elapsed + clampf(approach + 25, 35, 85)
		raid_hard_until = raid_until
		phase_counts.probes += 1
	else:
		raid_evidence = "Two probes repelled; clear strength advantage." if escalation.get(enemy_id, {}).get("repelled_twice", false) else "Earlier probe completed."
		escalation.erase(enemy_id) # A fresh campaign needs a new probe.
		probe_failures.erase(enemy_id)
		phase_counts.invasions += 1
	raid_budget = raid_size if probe else raid_size * 2
	raid_roster = {}
	raid_queen_checkpoint = sim.queen_health[enemy_id]
	raid_home_queen = sim.queen_health[colony]
	raid_living = 0
	raid_dead = 0
	raid_inside = 0
	raid_status = "Probe assembling: no reinforcements; hold outside the entrance." if probe else "Invasion assembling; travel and tunnel time included."
	raid_counts.started += 1

func inspect_raid() -> void:
	raid_living = 0
	raid_dead = 0
	raid_inside = 0
	var at_approach := 0
	for identity in raid_roster:
		var slot: int = raid_roster[identity]
		if sim.worker_ids[slot] != identity or sim.health[slot] <= 0:
			raid_dead += 1
			continue
		if sim.roles[slot] == sim.INVADER and sim.worker_order_ids[slot] == 400001 + (500000 if colony == 2 else 0):
			raid_living += 1
			if sim.layers[slot] == enemy_id: raid_inside += 1
			if sim.layers[slot] == -1 and sim.positions[slot].distance_squared_to(raid_goal) <= 50 * 50: at_approach += 1
	if raid_phase == "probe":
		if at_approach > 0 and probe_arrived_at < 0: probe_arrived_at = sim.elapsed
		elif at_approach == 0: probe_arrived_at = -1
	if raid_phase != "probe" and sim.queen_health[enemy_id] < raid_queen_checkpoint - 0.1:
		if raid_inside > 0:
			raid_until = minf(raid_hard_until, maxf(raid_until, sim.elapsed + 35))
			raid_counts.progress += 1
		raid_queen_checkpoint = sim.queen_health[enemy_id]
	raid_status = "%s: %d active / %d inside / %d lost; %d/%d recruited." % ["Probe" if raid_phase == "probe" else "Invasion", raid_living, raid_inside, raid_dead, raid_roster.size(), raid_budget]

func end_raid(why: String) -> void:
	if raid_until > 0:
		raid_counts.recalls[why] = raid_counts.recalls.get(why, 0) + 1
	var was_probe: bool = raid_phase == "probe" and raid_until > 0
	if was_probe:
		# Retire surviving party members to a real journey home. Clearing their
		# order identity prevents the old marker from recruiting replacements.
		for identity in raid_roster:
			var slot: int = raid_roster[identity]
			if sim.worker_ids[slot] != identity or sim.health[slot] <= 0 or sim.worker_order_ids[slot] != 400001 + (500000 if colony == 2 else 0) or sim.roles[slot] != sim.INVADER: continue
			sim.roles[slot] = sim.RETURNING
			sim.worker_order_ids[slot] = -1
			sim.worker_order_kinds[slot] = 0
			sim.paths[slot] = []; sim.route_goals[slot] = -1; sim.targets[slot] = -1; sim.trips[slot] = 0
		if why == "Probe complete":
			escalation[enemy_id] = {"completed": true, "ready_at": sim.elapsed + ESCALATION_GAP, "seen": sim.elapsed}
			phase_counts.probes_completed += 1
			probe_failures.erase(enemy_id)
		elif why == "Probe repelled":
			var previous: Dictionary = probe_failures.get(enemy_id, {})
			var failures: int = previous.get("count", 0) + 1 if sim.elapsed - previous.get("seen", -INF) <= PROBE_MEMORY else 1
			probe_failures[enemy_id] = {"count": failures, "seen": sim.elapsed}
			if failures >= 2: escalation[enemy_id] = {"completed": false, "repelled_twice": true, "ready_at": sim.elapsed + PROBE_RETRY, "seen": sim.elapsed}
			else: escalation.erase(enemy_id)
		else:
			escalation.erase(enemy_id)
			probe_failures.erase(enemy_id)
	raid_until = 0
	next_attack = sim.elapsed + (PROBE_RETRY if was_probe and why != "Probe complete" else ESCALATION_GAP)
	raid_status = "Withdrawing: " + why + ". Response interval: %ds." % ceili(next_attack - sim.elapsed)

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

func route_evidence(point: Vector2) -> Dictionary:
	var peak := 0
	var losses := 0
	var home: Vector2 = sim.nest_position(colony)
	for key in route_contacts:
		var center := (Vector2(key) + Vector2(.5, .5)) * CELL
		if center.distance_to(Geometry2D.get_closest_point_to_segment(center, home, point)) < 130: peak = maxi(peak, route_contacts[key].count)
	for key in route_losses:
		var center := (Vector2(key) + Vector2(.5, .5)) * CELL
		if center.distance_to(Geometry2D.get_closest_point_to_segment(center, home, point)) < 130: losses += route_losses[key]
	return {"enemies": peak, "losses": losses}

func score_source(index: int, population: int) -> Dictionary:
	var site: Dictionary = known[index]
	var travel: Dictionary = sim.strategic_garden.estimate(colony, site.pos)
	var evidence := route_evidence(site.pos)
	var risk: float = maxf(site.enemies, evidence.enemies) / maxf(12, site.friends + 6) + minf(2, evidence.losses / 3.0)
	var need: float = sim.nutrition_weights[colony * 2 + int(sim.foods[index].get("resource", 0))]
	# Trip time includes unloaded specialization and loaded return. Shade keeps
	# real trails alive; it is deliberately not an invented combat safety bonus.
	var equivalent: float = travel.trip_seconds / (1.0 / 52 + 1.0 / 43)
	var score: float = minf(site.amount, population * 1.5) * need / (equivalent + 180) / (1 + risk * (3 if recovering else 1.5))
	if index in selected: score *= 1.2
	if sim.elapsed - site.seen > 15: score *= .65
	return {"index": index, "score": score, "trip": travel.trip_seconds, "risk": risk, "need": need, "losses": evidence.losses, "enemies": evidence.enemies}

func source_explanation() -> String:
	var text := "Food: trip / shortage weight / observed risk"
	for entry in source_scores.slice(0, 3):
		text += "\n%s %s ~%.1fs / x%.1f / %.2f%s" % ["Chosen" if entry.index in selected else "Other", "protein" if sim.foods[entry.index].get("resource", 0) else "sugar", entry.trip, entry.need, entry.risk, " (%d losses)" % entry.losses if entry.losses else ""]
	return text

func marker(id: int, kind: int, point: Vector2) -> Dictionary:
	return {"id": id + (500000 if colony == 2 else 0), "kind": kind, "pos": point, "seen_food": true, "assigned": 0, "status": "Active"}

func build_ui() -> void:
	sim.rival_panel = Panel.new()
	sim.rival_panel.position = Vector2(324, 254)
	sim.rival_panel.size = Vector2(630, 516)
	sim.rival_panel.add_theme_stylebox_override("panel", sim._style(Color("19251e"), 12, sim.RIVAL))
	sim.ui.add_child(sim.rival_panel)
	var previous = sim.ui
	sim.ui = sim.rival_panel
	sim._button("Switch colony", Vector2(188, 8), Vector2(138, 28), func(): sim.inspected_ai = 2 if sim.inspected_ai == 1 and sim.colony_count == 3 else 1; sim._update_ui())
	sim._label("AI STRATEGY", Vector2(16, 10), 14, sim.RIVAL, true, 310)
	sim._button("x", Vector2(583, 8), Vector2(30, 28), sim.toggle_rival_plan)
	sim.rival_plan_text = sim._label("", Vector2(16, 40), 11, sim.INK, false, 598)
	sim.rival_plan_text.size.y = 464
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
	sim.rival_plan_text.text += "\n" + observed.raid_status + "\n\n" + observed.source_explanation() + "\n\n" + observed.target_explanation() + "\n\n" + observed.nest.explanation()


