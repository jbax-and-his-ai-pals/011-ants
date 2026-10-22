extends "res://tests/food_performance.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	output_path = "res://tests/nutrition_shortage_performance.json"
	growth_target = 2000
	report["feature"] = "Provisioned 2,000 per colony, initially zero protein and 40 seconds of sugar, dense combat, eight player orders, live nutrient HUD and order panel; all normal collection/AI remains active."
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	grow(s)
	for c in 3:
		s.protein_stores[c] = 0
		s.food_stores[c] = s.upkeep_rate(c) * 40
	s.nutrition.refresh()
	s.elapsed = 90
	s.food_cycle.tick()
	prepare_orders(s)
	battle(s)
	await measure(s, "protein_shortage_2000_panel_battle", true)
	report.complete = true
	report["all_targets_met"] = not failed
	report["protein_deliveries"] = [s.resource_delivered[1], s.resource_delivered[3], s.resource_delivered[5]]
	save_report()
	quit(1 if failed else 0)
