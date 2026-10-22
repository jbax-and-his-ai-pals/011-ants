extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.game_modes.start(1, 81923)
	s.paused = true
	await capture(s, "res://screenshots/founding_variety_start.png")
	for tick in 9000: s.simulate(s.STEP)
	s.camera_center = s.HOME
	s.camera_zoom = 1.5
	s._sync_camera()
	await capture(s, "res://screenshots/founding_growth_5min.png")
	s.set_view(true)
	s.focus_nest()
	await capture(s, "res://screenshots/founding_nursery_5min.png")
	quit()
