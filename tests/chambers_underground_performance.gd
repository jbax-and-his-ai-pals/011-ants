extends "res://tests/chambers_performance.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1440, 900)
	output_path = "res://tests/chambers_underground_performance.json"
	growth_target = 2000
	report["feature"] = "Real tunnel logistics at requested 4x, 2,000 initial ants per colony; underground camera plus explicitly synthetic large invasion with 600 loaded couriers and 200 real enemy workers. Observer can continue after player queen death."
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	if s.native_kernel == null: quit(1); return
	grow(s)
	await advance(s, 12)
	await measure(s, "underground_couriers_and_nurses", true, true)
	grow(s)
	s.set_chamber_tool(1)
	s.designate(s.chamber_cell(0) + Vector2i(-8, 0))
	s.set_chamber_tool(2)
	s.designate(s.chamber_cell(0) + Vector2i(8, 0))
	s.set_labor_priority(2, 3)
	report["construction_planned_tiles"] = s.pending_count()
	await measure(s, "underground_active_construction", true, true)
	report["construction_excavated_tiles"] = s.dug
	if s.dug <= 0: failed = true
	grow(s)
	var grid: PackedByteArray = s._nest_grid(0)
	var corridor: Array[Vector2i] = []
	for y in range(s.chamber_cell(0).y - 12, s.chamber_cell(0).y):
		for x in range(s.chamber_cell(0).x - 1, s.chamber_cell(0).x + 2):
			if grid[s._idx(Vector2i(x, y))] == 1: corridor.append(Vector2i(x, y))
	for k in 600:
		var i := 100 + k
		s.layers[i] = 0
		s.positions[i] = s._center(corridor[k % corridor.size()])
		s.roles[i] = s.FORAGER
		s.carrying[i] = 1
		s.cargo_resource[i] = k % 2
	for k in 200:
		var i: int = s.COUNT + 100 + k
		s.layers[i] = 0
		s.positions[i] = s._center(corridor[(k + 5) % corridor.size()])
		s.roles[i] = s.INVADER
		s.carrying[i] = 0
	s.chambers.prepare_reference()
	await measure(s, "underground_large_invasion", true, true)
	report.complete = true
	report["all_targets_met"] = not failed
	save_report()
	quit(1 if failed else 0)
