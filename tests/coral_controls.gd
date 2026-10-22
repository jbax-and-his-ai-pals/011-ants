extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cases: Array = []
	for seed_value in [81923, 7, 42]:
		for offset in [0, 1, 2]: cases.append({"group": "neutral_seat_rotation", "seed": seed_value, "offset": offset, "traits": [0, 0, 0]})
		for traits in [[2, 1, 0], [1, 0, 2]]: cases.append({"group": "direct_trait_swap", "seed": seed_value, "offset": 0, "traits": traits})
	for seed_value in [81923, 7, 42]: cases.append({"group": "original_traits_equal_ai", "seed": seed_value, "offset": 0, "traits": [1, 2, 0]})
	var suffix := "after"
	var shard := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): suffix = argument.trim_prefix("--label=")
		if argument.begins_with("--shard="): shard = int(argument.trim_prefix("--shard="))
	var s = load("res://tests/full_seat_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	s.equal_controllers = true
	var report := {"complete": false, "horizon_seconds": 1800, "note": "Identical AI in every colony. Physical seats rotate independently of colors/RNG. Trait swaps keep seats fixed. Full invasions/brood and ordinary ant rules remain enabled.", "runs": []}
	var output := "res://tests/coral_controls_%s_shard%d.json" % [suffix, shard]
	for index in cases.size():
		if shard >= 0 and index % 3 != shard: continue
		var config: Dictionary = cases[index]
		s.seat_offset = config.offset
		s.doctrines = PackedInt32Array(config.traits)
		s.reset_colony(config.seed)
		for c in 3:
			if s.tunnel_route(s.entrance_cell(c), s._cell(s.queen_position(c)), c).is_empty(): push_error("Disconnected diagnostic seat"); quit(1); return
		var samples: Array = [s.census()]
		var next_sample := 15.0
		print("START %s seed=%d offset=%d traits=%s" % [config.group, config.seed, config.offset, config.traits])
		for tick in 54000:
			s.simulate(s.STEP)
			if s.elapsed + 0.001 >= next_sample:
				var state: Dictionary = s.census()
				if state.invalid_state: push_error("Invalid diagnostic seat state"); quit(1); return
				samples.append(state)
				next_sample += 15
			if not s.match_result.is_empty(): break
			if tick % 300 == 0: await process_frame
		var row: Dictionary = config.duplicate(true)
		row.merge({"winner": s.winner, "censored": s.winner == -2, "final": s.census(), "eliminations": s.eliminations.duplicate(true), "samples": samples})
		report.runs.append(row)
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		print("RESULT winner=%d t=%.1f pop=%s" % [s.winner, s.elapsed, row.final.population])
	report.complete = true
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit()
