extends "res://tests/chambers_performance.gd"
func drive(s) -> void:
	if s.game_mode != s.game_modes.FOUNDING: return
	if s.progression.paths[0] == 0: s.progression.choose(0, 1)
	if s.living_count(0) >= 80 and s.brood_capacity[0] < 24 and s.pending_count() == 0:
		s.chambers.designate(s.chamber_cell(0) + Vector2i(7, 0), s.chambers.BROOD, true, false)
	if s.progression.daughters[0].is_empty(): s.progression.start_daughter(0)
func advance(s, target: float) -> void:
	s.set_process(false)
	var ticks := 0
	while s.elapsed + 0.001 < target and s.match_result.is_empty():
		if ticks % 90 == 0: drive(s)
		s.simulate(s.STEP); ticks += 1
		if ticks % 300 == 0: await process_frame
func provision(s, start_projects: bool = true) -> void:
	s.game_modes.start(1, 81923)
	for c in 3:
		while s.living_count(c) < 2000:
			var i: int = s._spawn_worker(c)
			if c > 0 and i % 5 == 0: s.progression.born(i, 1)
		s.food_stores[c] = 12000; s.protein_stores[c] = 3000
		var base: Vector2i = s.chamber_cell(c)
		var grid: PackedByteArray = s._nest_grid(c)
		for x in range(2, 8):
			var j: int = s._idx(base + Vector2i(x, 0))
			grid[j] = 1; s.chamber_rooms[c * s.CELLS + j] = s.chambers.BROOD; s.chambers.room_tiles[c][j] = s.chambers.BROOD
		s.set(["earth", "rival_earth", "third_earth"][c], grid)
	s.chambers.dirty = true; s.chambers.rebuild()
	for c in 3:
		s.progression.choose(c, 1 if c == 0 else 2)
		if start_projects and not s.progression.start_daughter(c): failed = true
		if not start_projects: s.protein_stores[c] = s.chambers.buffered[c] + s.chambers.reserved[c] + 8
	s.progression.refresh_preparation()
	s.progression.panel.visible = true
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0; root.size = Vector2i(1440, 900)
	output_path = "res://tests/clarity_performance.json" if "--clarity" in OS.get_cmdline_user_args() else "res://tests/progression_performance.json"
	report["feature"] = "Founding specialization, soldier bodies/stats and active physically fed daughters; Skirmish control, natural Founding and provisioned 2000-per-colony battle windows."
	report["note"] = "Natural Founding includes a scripted player choosing Foraging and designating one real brood room; all food, workers and digging remain earned. Provisioned Founding explicitly supplies 2000 workers per colony, 20% soldiers in rivals, extra room cells and legal stored food. The preparation fixture keeps 8 free protein per colony to exercise the royal reserve before paid projects can start. Panels open; full individual 30Hz fixed ticks and 4x progression."
	if "--clarity" in OS.get_cmdline_user_args():
		report["feature"] = "Bounded clickable history and work reports, Founding objective tracker and six-digger rival nursery anticipation. Full individual simulation, requested 4x, existing population stress workloads."
		report["note"] += " Clarity run: 96-event histories or work reports open; natural checkpoints 0/180/360/540s avoid the daughter finish boundary. Synthetic records are explicitly UI fixture history, not extra world activity."
	print("PERF creating observer")
	var s = load("res://tests/observed_colony.gd").new(); root.add_child(s); s.set_process(false)
	print("PERF reset and orders")
	s.reset_colony(81923); prepare_orders(s)
	print("PERF first measurement")
	await measure(s,"skirmish_orders_control",true)
	for scenario in ["skirmish_battle_control","skirmish_detail_control"]:
		growth_target = 2000; grow(s); prepare_orders(s); battle(s)
		await measure(s,scenario,true,scenario.contains("detail"))
	s.game_modes.start(1,81923); s.next_raids[0] = INF; s.progression.panel.visible = true
	for checkpoint in ([0,180,360,540] if "--clarity" in OS.get_cmdline_user_args() else [0,180,360,600]):
		await advance(s,checkpoint)
		if not s.match_result.is_empty(): break
		await measure(s,"founding_natural_%ds" % checkpoint)
	for scenario in ["founding_2000_preparing_overview", "founding_2000_queen_overview","founding_2000_soldier_battle","founding_2000_soldier_detail","underground_founding_queen"]:
		provision(s, not "preparing" in scenario)
		if "battle" in scenario or "detail" in scenario: battle(s)
		await measure(s,scenario,true,scenario.contains("detail"))
		report.windows[-1]["progression"] = {"paths": Array(s.progression.paths), "soldiers": Array(s.progression.soldier_counts), "preparation_reserves": Array(s.progression.preparation_reserves), "daughters": s.progression.daughters.duplicate(true)}
	report.complete = true; report["all_targets_met"] = not failed; save_report(); quit(1 if failed else 0)

func measure(s, scenario: String, synthetic: bool = false, detailed: bool = false) -> void:
	if "--clarity" in OS.get_cmdline_user_args():
		s.progression.panel.visible = false
		s.order_panel.visible = false; s.labor_panel.visible = false; s.rival_panel.visible = false; s.scouting.panel.visible = false
		s.clarity.history_panel.visible = not detailed
		s.clarity.work_panel.visible = detailed
		if synthetic:
			for n in 96: s.clarity.record("fixture", "Prior observed event %d" % n,s.HOME)
		s.clarity.sample()
	await super.measure(s,scenario,synthetic,detailed)
	if "--clarity" in OS.get_cmdline_user_args() and not report.windows.is_empty():
		report.windows[-1]["clarity"] = {"events": s.clarity.events.size(), "max_observation_ms": s.clarity.max_sample_usec/1000.0, "history_open": s.clarity.history_panel.visible, "work_open": s.clarity.work_panel.visible, "tracker_visible": s.clarity.tracker.visible}
