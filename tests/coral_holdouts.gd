extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var baseline: bool = "--baseline-ai" in OS.get_cmdline_user_args()
	var s = load("res://tests/observed_colony.gd").new()
	if baseline:
		s.fixed_starting_seats = true
		s.player_ai = load("res://tests/coral_baseline/strategy.gd").new()
		s.rival_ai = load("res://tests/coral_baseline/strategy.gd").new()
		s.third_ai = load("res://tests/coral_baseline/strategy.gd").new()
	root.add_child(s)
	s.set_process(false)
	s.equal_controllers = true
	s.doctrines.fill(0)
	var report := {"complete": false, "note": "Unseen world seeds, all Balanced, identical AI and fixed compact map. Before uses the saved two-route AI. Balanced combat rules are identical in both DLL versions; therefore the current native kernel is valid for this AI/seat comparison. Before uses fixed seats; after uses seeded seats.", "runs": []}
	for seed_value in [23, 101, 2026]:
		s.reset_colony(seed_value)
		var samples: Array = [s.census()]
		var next_sample := 15.0
		for tick in 54000:
			s.simulate(s.STEP)
			if s.elapsed + 0.001 >= next_sample:
				samples.append(s.census())
				next_sample += 15
			if not s.match_result.is_empty(): break
			if tick % 300 == 0: await process_frame
		report.runs.append({"seed": seed_value, "winner": s.winner, "censored": s.winner == -2, "final": s.census(), "samples": samples})
		print("HOLDOUT baseline=%s seed=%d winner=%d t=%.1f" % [baseline, seed_value, s.winner, s.elapsed])
	report.complete = true
	var file := FileAccess.open("res://tests/coral_holdouts_%s.json" % ("before" if baseline else "after"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit()
