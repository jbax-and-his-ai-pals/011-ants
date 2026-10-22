extends SceneTree
## Real-renderer 4x windows sampled from a continuous seeded match, plus explicitly
## synthetic growth/cap fixtures. Do not run alongside other benchmarks.
var report := {"resolution": "1440x900", "renderer": "GL Compatibility", "vsync_requested": "disabled", "seed": 81923, "starting_workers_per_colony": 2000, "window_min_wall_seconds": 5, "note": "Natural checkpoints are reached by full fixed ticks between live 4x renderer windows, not continuous real-time playback of the whole match. Observer may continue after player defeat, labeled in each row. Growth-cap and battle fixtures explicitly add workers through the real spawn path and food to isolate capacity; these are not naturally achieved populations. No aggregate ants or skipped off-screen updates.", "complete": false, "windows": []}
var underground_nest := 0
var failed := false
var growth_target := 3200
var output_path := "res://tests/long_performance_results.json"

func _initialize() -> void: call_deferred("run")

func save_report() -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))

func advance(s, target: float) -> void:
	s.set_process(false)
	var ticks := 0
	while s.elapsed + 0.001 < target and s.match_result.is_empty():
		s.simulate(s.STEP)
		ticks += 1
		if ticks % 300 == 0: await process_frame

func battle_center(s) -> Vector2:
	if "--map-balance" in OS.get_cmdline_user_args() or "--endgame" in OS.get_cmdline_user_args() or "--coral" in OS.get_cmdline_user_args() or "--food-cycle" in OS.get_cmdline_user_args():
		return (s.nest_position(0) + s.nest_position(1) + s.nest_position(2)) / 3
	return Vector2(1638, 1050)

func measure(s, scenario: String, synthetic: bool = false, detailed: bool = false) -> void:
	if not s.match_result.is_empty(): return
	s.speed = 4
	s.paused = false
	s.select_ant(-1)
	s.set_view(false)
	s.fit_world()
	if detailed:
		s.camera_zoom = 1.3
		s.camera_center = battle_center(s)
		s._sync_camera()
	if scenario.begins_with("underground"):
		s.inspected_colony = underground_nest
		s.set_view(true)
		s.camera_center = s._center(s.chamber_cell(underground_nest)) + Vector2(0, -115)
		s.camera_zoom = 1.5
		s._sync_camera()
	s.accumulator = 0
	s.set_process(true)
	# Short settle avoids attributing fast-forward's first delta to a live window.
	# A synthetic invasion can resolve during settling; include its actual attack
	# burst rather than timing an already-empty battlefield.
	for frame in (0 if scenario == "underground_large_invasion" else 30): await process_frame
	if not s.match_result.is_empty(): s.set_process(false); return
	var before: Dictionary = s.census()
	var sim_start: float = s.elapsed + s.accumulator
	var wall_start := Time.get_ticks_usec()
	var times: Array[float] = []
	var wall := 0.0
	s.profiling = true
	s.profile_ticks = 0
	s.profile_usec.fill(0)
	while wall < 5000 and s.match_result.is_empty():
		var start := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		times.append((Time.get_ticks_usec() - start) / 1000.0)
		wall = (Time.get_ticks_usec() - wall_start) / 1000.0
	var sim_end: float = s.elapsed + s.accumulator
	s.set_process(false)
	s.profiling = false
	times.sort()
	var mean: float = wall / maxi(1, times.size())
	var speed: float = (sim_end - sim_start) / (wall / 1000)
	var row := {"scenario": scenario, "synthetic": synthetic, "post_player_game_end": not s.game_result.is_empty(), "start": before, "end": s.census(), "wall_seconds": snappedf(wall / 1000, 0.001), "frames": times.size(), "mean_fps": snappedf(1000 / mean, 0.1), "mean_frame_ms": snappedf(mean, 0.01), "p95_ms": snappedf(times[int(times.size() * 0.95)], 0.01), "p99_ms": snappedf(times[int(times.size() * 0.99)], 0.01), "max_frame_ms": snappedf(times.back(), 0.01), "actual_speed": snappedf(speed, 0.01), "zoom": s.camera_zoom, "visible_ants": s.visible_ant_count, "tick_ms_by_phase": {}}
	var slow_frames := 0
	for ms in times:
		if ms > 1000.0 / 60: slow_frames += 1
	row["percent_frames_over_16_67ms"] = snappedf(float(slow_frames) / times.size() * 100, 0.1)
	row["target_met"] = mean <= 1000.0 / 60 and row.p95_ms <= 1000.0 / 30 and speed >= 3.9
	row["complete_window"] = wall >= 5000
	for phase in 4:
		row.tick_ms_by_phase[["scent_and_jobs", "encounters", "movement", "resolution_and_nursery"][phase]] = snappedf(float(s.profile_usec[phase]) / maxi(1, s.profile_ticks) / 1000.0, 0.001)
	if not row.target_met or before.invalid_state or row.end.invalid_state: failed = true
	row["scouting"] = {"sites": s.scouting.foods.size(), "sectors_explored": s.scouting.explored.size(), "contacts": s.scouting.contacts.size(), "tracks": s.scouting.tracks.size(), "max_scan_ms": snappedf(s.scouting.max_scan_usec / 1000.0, .001), "panel_open": s.scouting.panel.visible}
	report.windows.append(row)
	save_report()
	print("WINDOW %s t=%.1f..%.1f workers=%s..%s fps=%.1f p95=%.2f speed=%.2f pass=%s phases=%s" % [scenario, before.seconds, row.end.seconds, before.population, row.end.population, row.mean_fps, row.p95_ms, speed, row.target_met, row.tick_ms_by_phase])

func grow(s) -> void:
	s.reset_colony(81923)
	for c in 3:
		s.food_stores[c] = 60000
		while s.living_count(c) < growth_target: s._spawn_worker(c)
	for patch in s.foods: patch.amount += 20000
	# Preserve source and nursery mechanics; only provision the stress fixture.
	s._update_ui()

func battle(s) -> void:
	var center := battle_center(s)
	s.foods.append({"pos": center, "amount": 50000, "layer": -1})
	for c in 3:
		var radial := Vector2.from_angle(c * TAU / 3)
		for k in 600:
			var i: int = s.colony_workers[c][-1 - k]
			s.positions[i] = center + radial * (70 + (k / 10) * 8) + radial.orthogonal() * ((k % 10 - 4.5) * 3)
			s.headings[i] = (-radial).angle()
			s.roles[i] = s.FORAGER
			s.carrying[i] = 0
			s.worker_order_ids[i] = -1
			s.worker_order_kinds[i] = 1
			s.worker_order_goals[i] = center

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	if s.native_kernel == null: quit(1); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--target="):
			growth_target = clampi(int(argument.trim_prefix("--target=")), 2000, 3200)
			output_path = "res://tests/long_performance_%d_results.json" % growth_target
	if "--targeting" in OS.get_cmdline_user_args():
		output_path = "res://tests/targeting_performance_%d.json" % growth_target
	if "--map-balance" in OS.get_cmdline_user_args():
		output_path = "res://tests/map_performance_%d.json" % growth_target
	if "--endgame" in OS.get_cmdline_user_args():
		output_path = "res://tests/endgame_performance_%d.json" % growth_target
	if "--coral" in OS.get_cmdline_user_args():
		output_path = "res://tests/coral_performance_%d.json" % growth_target
	report["growth_target_per_colony"] = growth_target
	var growth_only: bool = "--growth-only" in OS.get_cmdline_user_args()
	s.reset_colony(81923)
	if not growth_only:
		for checkpoint in [0, 60, 180, 360, 600, 900, 1200, 1800]:
			await advance(s, checkpoint)
			if not s.match_result.is_empty(): break
			await measure(s, "natural_%ds" % checkpoint)
		report["natural_final"] = s.census()
		report["natural_winner"] = s.winner
		report["eliminations"] = s.eliminations.duplicate(true)
	grow(s)
	report["growth_start"] = s.census()
	await measure(s, "growth_cap_overview", true)
	grow(s)
	battle(s)
	await measure(s, "growth_cap_battle_overview", true)
	grow(s)
	battle(s)
	await measure(s, "growth_cap_battle_detail", true, true)
	report.complete = true
	report["all_targets_met"] = not failed
	save_report()
	quit(1 if failed else 0)
