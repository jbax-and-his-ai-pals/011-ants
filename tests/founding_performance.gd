extends "res://tests/chambers_performance.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	output_path = "res://tests/founding_growth_performance.json" if "--logistics" in OS.get_cmdline_user_args() else "res://tests/founding_performance.json"
	if "--scouting" in OS.get_cmdline_user_args() or "--raid-escalation" in OS.get_cmdline_user_args(): output_path = "res://tests/scouting_founding_performance.json"
	if "--raid-escalation" in OS.get_cmdline_user_args(): output_path = "res://tests/raid_escalation_founding_performance.json"
	report["starting_workers_per_colony"] = 12
	report["feature"] = "Founding mode: real colony growth from twelve workers each, local then shared food, staged AI raids; 4x renderer windows."
	if "--raid-escalation" in OS.get_cmdline_user_args(): report["feature"] = "Founding growth with phased rival raids and scouting overlay; natural live 4x renderer checkpoints."
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	s.game_modes.start(1, 81923)
	if "--scouting" in OS.get_cmdline_user_args() or "--raid-escalation" in OS.get_cmdline_user_args(): s.scouting.panel.visible = true
	for checkpoint in ([0, 180, 600, 1200, 1800] if "--logistics" in OS.get_cmdline_user_args() else [0, 180, 600]):
		await advance(s, checkpoint)
		await measure(s, "founding_%ds" % checkpoint)
	report.complete = true
	report["all_targets_met"] = not failed
	save_report()
	quit(1 if failed else 0)
