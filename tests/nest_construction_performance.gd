extends "res://tests/chambers_performance.gd"
func nest_info(s) -> Array:
	var result := []
	for c in [1, 2]:
		var planner = s.nest_planner(c)
		result.append({"colony": c, "project": planner.project, "pending": planner.pending.size(), "dug": planner.dug, "projects": planner.projects, "diggers": s.digger_count(c)})
	return result
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	output_path = "res://tests/nest_construction_performance.json"
	growth_target = 2000
	underground_nest = 1
	report["feature"] = "Provisioned construction stress: two rival planners, player crew, real nurses/couriers and corridor guards. 6,000 initial individual workers, requested 4x."
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	if s.native_kernel == null: quit(1); return
	for kind in ["storage", "brood", "route"]:
		grow(s)
		s.elapsed = 30
		s.rival_panel.visible = true
		s.inspected_ai = 1
		for c in [1, 2]:
			if kind != "storage": s.food_stores[c] = 3000; s.protein_stores[c] = 2000
			if kind == "brood":
				for n in 15: s.brood[c].append({"cell": s.chambers.brood_cells[c][n / 2], "stage": 0, "age": 0.0})
			if kind == "route":
				var j: int = s._idx(s.chamber_cell(c) + Vector2i(0, -8))
				s.tunnel_occupancy[c * s.CELLS + j] = 8
			s.nest_planner(c).ai.think()
			s.nest_planner(c).ai.update()
		s.set_chamber_tool(1)
		s.designate(s.chamber_cell(0) + Vector2i(-8, 0))
		s.set_labor_priority(2, 3)
		s.dig_mode = false
		report[kind + "_before"] = nest_info(s)
		await measure(s, "underground_rival_" + kind, true, true)
		report[kind + "_after"] = nest_info(s)
		for c in [1, 2]:
			if s.nest_planner(c).dug <= 0: failed = true
	report.complete = true
	report["all_targets_met"] = not failed
	save_report()
	quit(1 if failed else 0)
