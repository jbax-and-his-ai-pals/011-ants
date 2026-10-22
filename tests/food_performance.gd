extends "res://tests/long_performance.gd"
## Same renderer windows and thresholds, with forecasts and the new panel active.
func prepare_orders(s) -> void:
	s.command_system.clear()
	for n in 3: s.command_system.issue(1, s.food_cycle.sites[n * 2])
	s.command_system.issue(2, s.HOME + Vector2(170, 0))
	s.command_system.issue(2, s.HOME + Vector2(0, 170))
	s.command_system.issue(4, s.nest_position(1))
	s.command_system.issue(3, Vector2(250, 250))
	s.command_system.issue(3, Vector2(2800, 1450))
	s.command_system.set_priority(0, 3)
	s.command_system.sample()
	s.order_panel.visible = true
	if "--scouting" in OS.get_cmdline_user_args() or "--raid-escalation" in OS.get_cmdline_user_args():
		s.order_panel.visible = false
		s.scouting.panel.visible = true
	s._update_ui()

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	output_path = "res://tests/food_cycle_performance.json"
	var arrival_only: bool = "--arrival-only" in OS.get_cmdline_user_args()
	if arrival_only: output_path = "res://tests/food_cycle_arrival_performance.json"
	if "--garden" in OS.get_cmdline_user_args(): output_path = "res://tests/garden_performance.json"
	if "--nutrition" in OS.get_cmdline_user_args(): output_path = "res://tests/nutrition_performance.json"
	if "--chambers" in OS.get_cmdline_user_args(): output_path = "res://tests/chambers_performance.json"
	if "--nest-planner" in OS.get_cmdline_user_args(): output_path = "res://tests/nest_planner_performance.json"
	if "--game-modes" in OS.get_cmdline_user_args(): output_path = "res://tests/game_modes_skirmish_performance.json"
	if "--scouting" in OS.get_cmdline_user_args() or "--raid-escalation" in OS.get_cmdline_user_args(): output_path = "res://tests/scouting_skirmish_performance.json"
	if "--raid-escalation" in OS.get_cmdline_user_args(): output_path = "res://tests/raid_escalation_skirmish_performance.json"
	growth_target = 2000
	report["growth_target_per_colony"] = 2000
	report["feature"] = "Food forecasts, replenishment and per-order accounting; eight-order panel open in provisioned workloads. Same 5-second renderer windows and thresholds as long_performance."
	if "--garden" in OS.get_cmdline_user_args(): report["feature"] = "Seeded cached garden, individual soil movement +15%, shade doubles scent half-life, fruit/nectar/insect scenery; same nine food-cycle workloads with eight-order panel in provisioned tests."
	if "--nutrition" in OS.get_cmdline_user_args(): report["feature"] = "Sugar upkeep, protein brood, per-load resource identity, shortage-weighted local food/scent and AI routing; same nine garden/food-cycle workloads."
	if "--chambers" in OS.get_cmdline_user_args(): report["feature"] = "Physical storage trips, six nurses per colony, room-local protein feeding, brood capacity and bounded tunnel traffic; provisioned stocks stay within real room capacity."
	if "--nest-planner" in OS.get_cmdline_user_args(): report["feature"] = "Both rivals plan real storage/brood excavation, route improvements and underground guards; same nine room-logistics workloads at 2,000 ants per colony."
	if "--raid-escalation" in OS.get_cmdline_user_args(): report["feature"] = "Rival probes, physical withdrawal, response intervals and larger committed invasions, with scouting and territory reports open at requested 4x."
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	if s.native_kernel == null: quit(1); return
	s.reset_colony(81923)
	if "--scouting" in OS.get_cmdline_user_args() or "--raid-escalation" in OS.get_cmdline_user_args(): s.scouting.panel.visible = true
	for checkpoint in ([] if arrival_only else [0, 90, 120, 240, 360]):
		await advance(s, checkpoint)
		if not s.match_result.is_empty(): break
		if checkpoint == 90: prepare_orders(s)
		await measure(s, "food_natural_%ds" % checkpoint)
	for scenario in (["food_2000_panel_arrival"] if arrival_only else ["food_2000_panel_overview", "food_2000_panel_battle", "food_2000_panel_detail", "food_2000_panel_arrival"]):
		grow(s)
		s.elapsed = 112 if scenario.ends_with("arrival") else 90
		s.food_cycle.tick()
		prepare_orders(s)
		if scenario in ["food_2000_panel_battle", "food_2000_panel_detail"]: battle(s)
		await measure(s, scenario, true, scenario.ends_with("detail"))
		if s.command_system.markers.size() != 8: failed = true
		if scenario.ends_with("arrival"):
			report["arrival_wave"] = s.food_cycle.wave
			report["arrived_food"] = s.food_cycle.added
			if s.food_cycle.wave != 1 or s.food_cycle.added <= 0: failed = true
	report.complete = true
	report["all_targets_met"] = not failed
	save_report()
	quit(1 if failed else 0)
