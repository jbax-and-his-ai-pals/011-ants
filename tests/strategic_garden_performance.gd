extends "res://tests/progression_performance.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0; root.size=Vector2i(1440,900)
	output_path="res://tests/strategic_garden_performance.json"
	report["feature"]="Strategic source pairs, terrain trip estimates, observed rival corridor risk; scouting panel and territory overlay open at full individual 4x."
	report["note"]="Natural Founding uses earned food/growth with a scripted Foraging player and real brood excavation. Supplied stress cases start 2000 workers per colony, legal stores/room cells and approximately 20% rival soldiers. No skipped individual ticks; actual battles reduce populations. Same twelve workloads as clarity, with scouting routes open instead of history."
	var s=load("res://tests/observed_colony.gd").new(); root.add_child(s); s.set_process(false)
	if s.native_kernel==null: quit(1); return
	s.reset_colony(81923); prepare_orders(s)
	await measure(s,"skirmish_orders_control",true)
	for scenario in ["skirmish_battle_control","skirmish_detail_control"]:
		growth_target=2000; grow(s); prepare_orders(s); battle(s)
		await measure(s,scenario,true,scenario.contains("detail"))
	s.game_modes.start(1,81923); s.next_raids[0]=INF
	for checkpoint in [0,180,360,540]:
		await advance(s,checkpoint)
		if not s.match_result.is_empty(): break
		await measure(s,"founding_natural_%ds" % checkpoint)
	for scenario in ["founding_2000_preparing_overview","founding_2000_queen_overview","founding_2000_soldier_battle","founding_2000_soldier_detail","underground_founding_queen"]:
		provision(s,not "preparing" in scenario)
		if "battle" in scenario or "detail" in scenario: battle(s)
		await measure(s,scenario,true,scenario.contains("detail"))
		report.windows[-1]["progression"]={"paths":Array(s.progression.paths),"soldiers":Array(s.progression.soldier_counts)}
	report.complete=true; report["all_targets_met"]=not failed and report.windows.size()==12; save_report(); quit(0 if report.all_targets_met else 1)

func measure(s,scenario: String,synthetic: bool=false,detailed: bool=false) -> void:
	s.clarity.close_panels(); s.progression.panel.visible=false
	s.order_panel.visible=false; s.labor_panel.visible=false; s.rival_panel.visible=false
	s.scouting.sample(); s.scouting.panel.visible=true
	await super.measure(s,scenario,synthetic,detailed)
	if not report.windows.is_empty():
		report.windows[-1]["garden"]={"pairs":s.strategic_garden.pairs.size(),"geometry_cache":s.strategic_garden.cache.size(),"rival_contacts":[s.rival_ai.route_contacts.size(),s.third_ai.route_contacts.size()],"rival_max_think_ms":max(s.rival_ai.max_think_usec,s.third_ai.max_think_usec)/1000.0}
