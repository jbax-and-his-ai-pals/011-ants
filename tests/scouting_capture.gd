extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s); s.set_process(false)
	s.game_modes.start(1, 81923)
	s.paused = true
	var source: Vector2 = s.HOME + Vector2(450, 0)
	s.foods.append({"pos": source, "amount": 350, "initial": 350, "resource": 1, "food_visual": 2})
	s.positions[0] = source
	var enemy: int = s.workers_per_colony
	s.positions[enemy] = source + Vector2(40, 0); s.roles[enemy] = s.INVADER
	s.scouting.sample()
	s.elapsed += .8; s.positions[enemy] -= Vector2(30, 0)
	s.scouting.sample()
	s.scouting.panel.visible = true
	s.fit_world()
	await capture(s, "res://screenshots/scouting_reports.png")
	s.scouting.panel.visible = false
	s.camera_center = s.HOME + Vector2(200, 0); s.camera_zoom = 1.1; s._sync_camera()
	await capture(s, "res://screenshots/scouting_raid_warning.png")
	s.layers[enemy] = 0; s.positions[enemy] = s.queen_position(0)
	s.scouting.sample(); s.scouting.focus_warning()
	await capture(s, "res://screenshots/scouting_nest_warning.png")
	quit()
