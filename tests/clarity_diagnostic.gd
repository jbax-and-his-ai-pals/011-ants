extends "res://tests/progression_performance.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0; root.size=Vector2i(1440,900)
	output_path="res://tests/clarity_diagnostic.json"
	report["feature"]="Isolated Skirmish battle UI diagnosis with identical provisioned worker/food/order setup; closed/history/work panels."
	var s=load("res://tests/observed_colony.gd").new(); root.add_child(s); s.set_process(false); growth_target=2000
	for panel in ["closed","history","work","history_repeat"]:
		s.game_modes.start(0,81923); grow(s); prepare_orders(s); battle(s)
		s.order_panel.visible=false; s.progression.panel.visible=false; s.scouting.panel.visible=false
		s.clarity.history_panel.visible=panel.begins_with("history"); s.clarity.work_panel.visible=panel=="work"
		for n in 96:s.clarity.record("fixture","Previous observed event %d"%n,s.HOME)
		s.clarity.sample()
		await measure(s,"skirmish_battle_"+panel,true)
		report.windows[-1]["max_observation_ms"]=s.clarity.max_sample_usec/1000.0
	report.complete=true; report["all_targets_met"]=not failed;save_report();quit(1 if failed else 0)
