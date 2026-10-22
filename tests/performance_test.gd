extends SceneTree
## Run with a real renderer (not --headless); samples wall-clock rendered frames.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	var colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	root.add_child(colony)
	colony.set_process(false)
	if colony.native_kernel == null:
		push_error("Native kernel is required for this performance run")
		quit(1)
		return
	colony.reset_colony(81923)
	colony.reproduction_enabled = false
	colony.invasions_enabled = false
	var results: Array = []
	var failed := false
	for scenario in ["crowded_start", "surface", "overview", "underground_overview", "inspection_4x", "overview_4x", "crowded_start_4x", "live_colonies_4x", "live_start_4x", "mature_overview", "orders_4x", "max_orders_4x", "rival_strategy_4x", "rival_war_4x"]:
		colony.set_process(false)
		colony.reset_colony(81923)
		colony.reproduction_enabled = false
		colony.invasions_enabled = false
		var live_colonies: bool = scenario in ["live_colonies_4x", "live_start_4x", "orders_4x", "max_orders_4x", "rival_strategy_4x", "rival_war_4x"]
		colony.rival_ai_enabled = live_colonies
		colony.reproduction_enabled = live_colonies
		colony.invasions_enabled = live_colonies
		var warmup_ticks := 2700 if scenario == "live_colonies_4x" else (1800 if scenario == "mature_overview" else (0 if scenario.begins_with("crowded_start") or scenario in ["live_start_4x", "orders_4x", "max_orders_4x", "rival_strategy_4x", "rival_war_4x"] else 300))
		for tick in warmup_ticks:
			colony.simulate(1.0 / 30.0)
		if scenario in ["rival_strategy_4x", "rival_war_4x"]:
			# Full population at strategy-enabled startup; war fixture puts scouts and
			# enemies at a shared source and advances the clock, not the population.
			colony.elapsed = 100 if scenario == "rival_war_4x" else 0
			colony.food_stores[1] = 2000 if scenario == "rival_war_4x" else colony.INITIAL_STORES
			var front: Vector2 = colony.nest_position(1) + Vector2(-400, 0)
			for patch in colony.foods:
				if patch.pos.distance_to(colony.nest_position(1)) < 500: patch.amount = 200
			colony.foods.append({"pos": front, "amount": 5000, "layer": -1})
			for i in 200: colony.positions[colony.COUNT + i] = front + Vector2(i % 20, i / 20)
			for i in 30: colony.positions[i] = front + Vector2(-200, i % 10)
			colony.rival_ai.update()
		if scenario == "live_start_4x":
			colony.launch_raid(0, 12)
			colony.launch_raid(1, 12)
			colony.designate(colony.HOME_CELL + Vector2i(27, 4))
		if scenario in ["orders_4x", "max_orders_4x"]:
			for category in 3: colony.set_labor_priority(category, 3)
			colony.place_surface_order(1, colony.foods[0].pos)
			colony.place_surface_order(2, colony.HOME + Vector2(350, 100))
			colony.place_surface_order(3, colony.HOME + Vector2(650, -100))
			colony.place_surface_order(4, colony.nest_position(1))
			colony.designate(colony.HOME_CELL + Vector2i(27, 4))
			if scenario == "max_orders_4x":
				colony.place_surface_order(1, Vector2(1100, 1400))
				colony.place_surface_order(2, Vector2(1800, 1100))
				colony.place_surface_order(3, Vector2(1650, 850))
				colony.place_surface_order(3, Vector2(2200, 1200))
		colony.set_process(true)
		colony.speed = 1
		colony.select_ant(-1)
		colony.set_view(scenario == "underground_overview")
		colony.focus_nest()
		if scenario.contains("overview") or live_colonies:
			colony.fit_world()
		if scenario == "underground_overview":
			colony.set_process(false)
			colony.designate(colony.HOME_CELL + Vector2i(27, 4))
			for tick in 240:
				colony.simulate(1.0 / 30.0)
			colony.set_process(true)
		if scenario.ends_with("_4x"):
			colony.speed = 4
		if scenario == "inspection_4x":
			colony.select_ant(0)
			colony.camera_zoom = 2
			colony.camera_center = colony.positions[0]
			colony._sync_camera()
		var peak_guards := 0
		var peak_raiders := 0
		var modes: Array[String] = []
		for marker in colony.rival_ai.orders.markers:
			if marker.kind == 2: peak_guards = maxi(peak_guards, marker.assigned)
			if marker.kind == 4: peak_raiders = maxi(peak_raiders, marker.assigned)
		if scenario == "rival_war_4x" and (peak_guards == 0 or peak_raiders == 0):
			failed = true
			push_error("War workload must begin with both rival guards and raiders")
		for warmup in 60:
			await process_frame
		colony.profiling = true
		colony.profile_ticks = 0
		colony.profile_usec.fill(0)
		var workers_start: int = colony.living_count(0) + colony.living_count(1)
		var simulated_start: float = colony.elapsed
		var clock_start: float = colony.elapsed + colony.accumulator
		var times: Array[float] = []
		var total := 0.0
		for frame in 240:
			var start := Time.get_ticks_usec()
			# Exercise camera motion too, while keeping near the current location.
			if frame % 30 == 0 and scenario == "surface":
				colony.camera_center += Vector2(6 if frame % 60 == 0 else -6, 0)
				colony._sync_camera()
			await process_frame
			await RenderingServer.frame_post_draw
			var ms := float(Time.get_ticks_usec() - start) / 1000.0
			for marker in colony.rival_ai.orders.markers:
				if marker.kind == 2: peak_guards = maxi(peak_guards, marker.assigned)
				if marker.kind == 4: peak_raiders = maxi(peak_raiders, marker.assigned)
			if colony.rival_ai.mode not in modes: modes.append(colony.rival_ai.mode)
			times.append(ms)
			total += ms
		times.sort()
		var mean := total / times.size()
		var row := {"scenario": scenario, "frames": times.size(), "world_tiles": colony.CELLS, "zoom": colony.camera_zoom, "workers": colony.living_count(0) + colony.living_count(1), "mean_frame_ms": snappedf(mean, 0.01), "p95_frame_ms": snappedf(times[int(times.size() * 0.95)], 0.01), "mean_fps": snappedf(1000.0 / mean, 0.1), "visible_ants": colony.visible_ant_count}
		row["workers_start"] = workers_start
		row["fps_target_met"] = mean <= 1000.0 / 55.0
		row["p95_target_met"] = row.p95_frame_ms <= 1000.0 / 30.0
		row["diggers"] = colony.digger_count()
		row["raiders"] = 0
		for i in colony.health.size():
			if colony.health[i] > 0 and colony.roles[i] == colony.INVADER: row.raiders += 1
		row["rival_ai_enabled"] = colony.rival_ai_enabled
		row["peak_rival_guards"] = peak_guards
		row["peak_rival_raiders"] = peak_raiders
		row["rival_modes"] = modes
		row["rival_mode"] = colony.rival_ai.mode
		row["rival_decisions"] = colony.rival_ai.decisions
		row["rival_max_think_ms"] = snappedf(colony.rival_ai.max_think_usec / 1000.0, 0.001)
		row["rival_orders"] = colony.rival_ai.orders.markers.size()
		row["orders"] = colony.command_system.markers.size()
		row["brood"] = colony.brood[0].size() + colony.brood[1].size()
		row["births"] = colony.births[0] + colony.births[1]
		row["completed_ticks_seconds_per_wall_second"] = snappedf((colony.elapsed - simulated_start) / (total / 1000), 0.01)
		# Include the fractional tick phase: a <1s sample at 250 FPS otherwise
		# quantizes a perfectly real-time 30Hz simulation down to about 0.97x.
		# The accumulator stays below STEP after processing; overload still fails.
		row["simulated_seconds_per_wall_second"] = snappedf((colony.elapsed + colony.accumulator - clock_start) / (total / 1000), 0.01)
		row["tick_ms_by_phase"] = {}
		for phase in 4:
			row.tick_ms_by_phase[["scent_and_jobs", "encounters", "movement", "resolution_and_nursery"][phase]] = snappedf(float(colony.profile_usec[phase]) / max(1, colony.profile_ticks) / 1000, 0.001)
		colony.profiling = false
		results.append(row)
		print(JSON.stringify(row))
		if not row.fps_target_met or not row.p95_target_met or row.simulated_seconds_per_wall_second < colony.speed * 0.975:
			failed = true
			push_error("Missed local 55 FPS, p95 33.3ms, or 97.5% simulation-speed floor: " + scenario)
	var report := {"resolution": "1440x900", "renderer": "GL Compatibility", "vsync_requested": "disabled", "starting_workers": colony.starting_total(), "native_kernel": colony.native_kernel != null, "note": "Local wall-clock renderer measurements; not a cross-hardware guarantee. Native simulation; every worker retains 30Hz updates. Each case resets to %d workers. Combat remains active. Brood/raids disabled except live_start_4x, live_colonies_4x both order cases and the rival strategy/war cases. All live cases enable the new rival AI; isolation cases disable it. Rival strategy/war cases start at full population with a contested food fixture; war advances the clock to raid readiness with sufficient reserves. Orders cases start at full population with all four order types, High labor and digging; max_orders_4x uses eight markers. Live start also orders raids and digging at full population; live colonies warms up 90 simulated seconds with brood/AI raids enabled. Fresh cases warm up 10 seconds; crowded starts have no simulated warmup; mature overview warms up 60 seconds." % colony.starting_total(), "results": results}
	var output := FileAccess.open("res://tests/performance_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	if not failed: print("PASS: all fourteen workloads, including 4x overview and live colonies, clear 55 FPS, p95 33.3ms, and maintain simulation speed.")
	quit(1 if failed else 0)
