extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	for c in [1, 2]:
		s.food_stores[c] = 14000
		s.protein_stores[c] = 2000
		s.nest_planner(c).ai.update()
	s.inspected_colony = 1
	s.set_view(true)
	s.camera_center = s._center(s.chamber_cell(1)) + Vector2(0, -100)
	s.camera_zoom = 1.6
	s._sync_camera()
	s.paused = true
	await capture(s, "res://screenshots/nest_planner_queued.png")
	for tick in 2700: s.simulate(s.STEP)
	await capture(s, "res://screenshots/nest_planner_built.png")
	s.rival_panel.visible = true
	s.inspected_ai = 1
	await capture(s, "res://screenshots/nest_planner_strategy.png")
	print("NEST_CAPTURE capacity=%s projects=%s/%s dug=%s/%s pending=%s/%s" % [s.storage_capacity, s.rival_ai.nest.projects, s.third_ai.nest.projects, s.rival_ai.nest.dug, s.third_ai.nest.dug, s.pending_count(1), s.pending_count(2)])
	quit()
