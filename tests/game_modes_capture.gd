extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.game_modes.start(1, 81923)
	s.paused = true
	await capture(s, "res://screenshots/founding_start.png")
	s.fit_world()
	await capture(s, "res://screenshots/founding_overview.png")
	for tick in 5400: s.simulate(s.STEP)
	s.camera_center = s.HOME
	s.camera_zoom = 1.5
	s._sync_camera()
	await capture(s, "res://screenshots/founding_grown.png")
	s.game_modes.selector.show_popup()
	await capture(s, "res://screenshots/game_mode_selector.png")
	quit()
