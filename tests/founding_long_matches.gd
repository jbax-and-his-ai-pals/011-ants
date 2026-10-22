extends SceneTree
var report := {"duration_sim_seconds": 1800, "seeds": [81923, 404, 9973], "complete": false, "runs": [], "skirmish_fingerprints": []}
var output_path := "res://tests/founding_long_before.json"
func _initialize() -> void: call_deferred("run")
func save() -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
func snapshot(s) -> Dictionary:
	var row := {"seconds": snappedf(s.elapsed, 0.1), "colonies": []}
	for c in 3:
		var roles := [0, 0, 0, 0, 0, 0, 0, 0]
		var far := 0
		for i in s.colony_workers[c]:
			if s.health[i] <= 0: continue
			roles[s.roles[i]] += 1
			if s.layers[i] == -1 and s.positions[i].distance_to(s.nest_position(c)) > 400: far += 1
		var stages := [0, 0, 0]
		var waiting := [0, 0] # Ready to molt, with/without enough protein banked.
		for young in s.brood[c]:
			stages[young.stage] += 1
			if young.stage < 2 and young.age >= s.stage_duration(c, young.stage):
				waiting[0 if s.protein_stores[c] >= s.stage_feed_cost(c, young.stage) else 1] += 1
		var food := [0, 0]
		for patch in s.foods:
			if patch.get("layer", -1) == -1 and patch.pos.distance_to(s.nest_position(c)) < 300: food[patch.get("resource", 0)] += patch.amount
		row.colonies.append({"population": s.living_count(c), "births": s.births[c], "combat_losses": s.casualties[c], "hunger_losses": s.starvation_losses[c], "queen": s.queen_health[c], "sugar": snappedf(s.food_stores[c], .01), "protein": snappedf(s.protein_stores[c], .01), "buffered": s.chambers.buffered[c], "reserved": s.chambers.reserved[c], "delivered": [s.resource_delivered[c*2], s.resource_delivered[c*2+1]], "roles": roles, "far_from_home": far, "brood": stages, "waiting_for_room_protein": waiting[0], "waiting_for_bank_protein": waiting[1], "nearby_food": food, "raid_starts": (s.player_ai if c == 0 else (s.rival_ai if c == 1 else s.third_ai)).raid_counts.started})
	return row
func fingerprint(s) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for name in ["positions", "headings", "roles", "health", "carrying", "cargo_resource", "layers", "trips", "worker_order_ids", "worker_order_kinds", "worker_order_goals", "food_stores", "protein_stores", "births", "casualties", "brood", "brood_buffers", "nurse_load", "nurse_targets", "food_scent", "protein_scent", "rival_food_scent", "third_food_scent", "foods", "chamber_rooms", "earth", "rival_earth", "third_earth"]:
		hash.update(var_to_bytes(s.get(name)))
	for random in s.ant_rng: hash.update(var_to_bytes(random.state))
	for ai in [s.rival_ai, s.third_ai]: hash.update(var_to_bytes([ai.orders.markers, ai.orders.labor, ai.nest.pending, ai.nest.project, ai.target_rng.state]))
	return hash.finish().hex_encode()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--after": output_path = "res://tests/founding_long_after.json"
	if not "--after" in OS.get_cmdline_user_args() and FileAccess.file_exists(output_path):
		var previous = JSON.parse_string(FileAccess.get_file_as_string(output_path))
		if previous is Dictionary and not previous.get("complete", false): report = previous
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	for seed_value in report.seeds:
		if report.skirmish_fingerprints.any(func(row): return row.seed == seed_value): continue
		s.equal_controllers = false
		s.game_modes.start(0, seed_value)
		for tick in 1200: s.simulate(s.STEP)
		report.skirmish_fingerprints.append({"seed": seed_value, "ticks": 1200, "sha256": fingerprint(s)})
	for equal in [false, true]:
		for seed_value in report.seeds:
			if report.runs.any(func(row): return row.seed == seed_value and row.controllers == ("equal_ai" if equal else "player_autonomous")): continue
			s.equal_controllers = equal
			s.game_modes.start(1, seed_value)
			var run := {"seed": seed_value, "controllers": "equal_ai" if equal else "player_autonomous", "first_contact": -1.0, "first_loss": -1.0, "first_raid": -1.0, "samples": [snapshot(s)], "births_at_first_contact": [], "invalid_samples": 0}
			for tick in 54000:
				s.simulate(s.STEP)
				if tick % 30 == 29:
					if run.first_contact < 0:
						for opponent in s.opponents:
							if opponent >= 0:
								run.first_contact = snappedf(s.elapsed, .1)
								run.births_at_first_contact = Array(s.births)
								break
					if run.first_loss < 0 and s.casualties[0] + s.casualties[1] + s.casualties[2] > 0: run.first_loss = snappedf(s.elapsed, .1)
					if run.first_raid < 0:
						for role in s.roles:
							if role == s.INVADER: run.first_raid = snappedf(s.elapsed, .1); break
				if tick % 1800 == 1799:
					run.samples.append(snapshot(s))
					if s.census().invalid_state > 0: run.invalid_samples += 1
				if not s.match_result.is_empty(): break
			if run.samples[-1].seconds < s.elapsed - .1: run.samples.append(snapshot(s))
			run["winner"] = s.winner
			run["eliminations"] = s.eliminations.duplicate(true)
			report.runs.append(run)
			save()
			print("LONG seed=%d controllers=%s t=%.0f first_contact=%s first_raid=%s final=%s" % [seed_value, run.controllers, s.elapsed, run.first_contact, run.first_raid, run.samples[-1].colonies.map(func(c): return c.population)])
	report.complete = true
	save()
	s.queue_free()
	quit()
