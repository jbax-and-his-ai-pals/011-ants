extends SceneTree
## No rendering measurements here; reproducible longitudinal balance telemetry.
var output_path := "res://tests/long_balance_results.json"
func _initialize() -> void: call_deferred("run")
func save_report(report: Dictionary) -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
func run() -> void:
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	s.wide_map_layout = "--wide-map" in OS.get_cmdline_user_args()
	if s.native_kernel == null:
		push_error("Native kernel required")
		quit(1)
		return
	var cases: Array = []
	for seed_value in [81923, 7, 42]:
		cases.append({"group": "default_unattended", "seed": seed_value, "equal_ai": false, "traits": [1, 2, 0]})
		cases.append({"group": "equal_ai_neutral", "seed": seed_value, "equal_ai": true, "traits": [0, 0, 0]})
	for seed_value in [7, 42]:
		for traits in [[1, 2, 0], [0, 1, 2], [2, 0, 1]]:
			cases.append({"group": "equal_ai_rotated_traits", "seed": seed_value, "equal_ai": true, "traits": traits})
	if "--mirrors-only" in OS.get_cmdline_user_args():
		cases.clear()
		for seed_value in [81923, 7, 42]: cases.append({"group": "equal_ai_neutral_mirrored", "seed": seed_value, "equal_ai": true, "traits": [0, 0, 0], "swapped": true})
		output_path = "res://tests/long_balance_mirrors.json"
	if "--targeting" in OS.get_cmdline_user_args():
		output_path = output_path.replace("long_balance", "targeting_balance")
	if "--map-balance" in OS.get_cmdline_user_args():
		output_path = output_path.replace("long_balance", "map_balance")
	if "--endgame" in OS.get_cmdline_user_args():
		output_path = output_path.replace("long_balance", "endgame_balance")
	if "--coral" in OS.get_cmdline_user_args():
		output_path = output_path.replace("long_balance", "coral_balance")
	if s.wide_map_layout: output_path = output_path.replace("map_balance", "map_wide_balance")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shard="):
			var parts := argument.trim_prefix("--shard=").split("/")
			var shard := int(parts[0])
			var count := int(parts[1])
			var subset: Array = []
			for i in cases.size():
				if i % count == shard: subset.append(cases[i])
			cases = subset
			output_path = output_path.replace(".json", "_shard%d.json" % shard)
	var pilot: bool = "--pilot" in OS.get_cmdline_user_args()
	if pilot: cases = [cases[0]]
	var report := {"simulated_horizon_seconds": 1800, "starting_workers_per_colony": 2000, "sample_interval_seconds": 15, "note": "Headless balance runs, not FPS measurements. Same fixed map and colony-specific worker RNG streams. Equal-AI cases give Amber the same strategy class as rivals and suppress its legacy automatic raid timer. Observer continues after player defeat until one queen remains; game_result/game_end_seconds preserve when ordinary play would stop. Censored runs have winner=-2; worker leads are not wins. Traits 0 Balanced / 1 Stewards / 2 Raiders. Nest/food layout is recorded below.", "complete": false, "runs": []}
	report["starting_seats"] = "fixed" if s.fixed_starting_seats else "seeded_map_rng_v1"
	report["raid_policy"] = "bounded_commitment_v1"
	report["layout"] = "legacy" if s.legacy_map_layout else ("wide1022" if s.wide_map_layout else "equilateral742")
	var invalid := false
	for config in cases:
		s.swapped_sides = config.get("swapped", false)
		s.equal_controllers = config.equal_ai
		s.doctrines = PackedInt32Array(config.traits)
		s.reset_colony(config.seed)
		var wall := Time.get_ticks_msec()
		var samples: Array = [s.census()]
		var next_sample := 15.0
		print("START %s seed=%d traits=%s" % [config.group, config.seed, config.traits])
		for tick in 54000:
			s.simulate(s.STEP)
			if s.elapsed + 0.001 >= next_sample:
				var sample: Dictionary = s.census()
				samples.append(sample)
				if sample.invalid_state > 0: invalid = true
				next_sample += 15
				if int(round(s.elapsed)) % 300 == 0: print("PROGRESS %s seed=%d t=%.0f populations=%s queens=%s" % [config.group, config.seed, s.elapsed, sample.population, sample.queens])
			if not s.match_result.is_empty(): break
			if tick % 300 == 0: await process_frame
		var final: Dictionary = s.census()
		var peak_population := [0, 0, 0]
		var peak_fighting := 0
		var peak_slots := 0
		for sample in samples:
			for c in 3: peak_population[c] = maxi(peak_population[c], sample.population[c])
			peak_fighting = maxi(peak_fighting, sample.fighting[0] + sample.fighting[1] + sample.fighting[2])
			peak_slots = maxi(peak_slots, sample.slots)
		var row: Dictionary = config.duplicate(true)
		row.merge({"winner": s.winner, "censored": s.winner == -2, "game_result": s.game_result, "game_end_seconds": s.game_end_seconds, "eliminations": s.eliminations.duplicate(true), "final": final, "peak_population": peak_population, "peak_fighting_sampled": peak_fighting, "peak_slots": peak_slots, "wall_seconds": (Time.get_ticks_msec() - wall) / 1000.0, "samples": samples})
		report.runs.append(row)
		save_report(report)
		print("RESULT %s seed=%d winner=%d t=%.1f populations=%s wall=%.1fs" % [config.group, config.seed, s.winner, s.elapsed, final.population, row.wall_seconds])
	report.complete = true
	report["invalid_state"] = invalid
	save_report(report)
	quit(1 if invalid else 0)
