extends SceneTree
## Fixed-tick early route comparison. These captures are not FPS measurements.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://tests/observed_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	var report := {}
	for old_map in [true, false]:
		s.legacy_map_layout = old_map
		s.reset_colony(81923)
		var pressure := [0, 0, 0]
		var carriers := [0, 0, 0]
		for tick in 3600:
			s.simulate(s.STEP)
			if tick % 150 == 149:
				for i in s.health.size():
					if s.health[i] <= 0 or s.layers[i] != s.SURFACE or s.roles[i] != s.FORAGER: continue
					for nest in 3:
						if nest == s.colonies[i]: continue
						if s.positions[i].distance_squared_to(s.nest_position(nest)) < 240 * 240:
							pressure[nest] += 5
							if s.carrying[i] > 0: carriers[nest] += 5
			if tick % 300 == 0: await process_frame
		var label := "before" if old_map else "after"
		report[label] = {"sampled_foreign_forager_seconds_near_nest": pressure, "sampled_foreign_carrier_seconds_near_nest": carriers, "census": s.census()}
		s.fit_world()
		s.paused = true
		s._update_ui()
		s.world_canvas.queue_redraw()
		s.mini_canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/map_%s.png" % label)
	var file := FileAccess.open("res://tests/map_route_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit()
