extends "res://tests/founding_long_matches.gd"
func run() -> void:
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	var rows := []
	for seed_value in [81923, 404, 9973]:
		s.game_modes.start(0, seed_value)
		for tick in 1200: s.simulate(s.STEP)
		rows.append({"seed": seed_value, "ticks": 1200, "sha256": fingerprint(s)})
	var path := "res://tests/progression_skirmish_after.json" if "--after" in OS.get_cmdline_user_args() else "res://tests/progression_skirmish_before.json"
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("SKIRMISH TRACE ", JSON.stringify(rows))
	quit()
