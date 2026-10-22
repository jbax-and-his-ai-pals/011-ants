extends SceneTree
func _initialize() -> void: call_deferred("_run")
func capture(s, path: String) -> void:
	s._update_ui()
	s.world_canvas.queue_redraw()
	s.mini_canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func _run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	s.speed = 4
	s.place_surface_order(1, s.foods[0].pos)
	s.place_surface_order(2, s.HOME + Vector2(400, 120))
	s.place_surface_order(3, s.HOME + Vector2(650, -130))
	s.place_surface_order(4, s.nest_position(1))
	s.designate(s.HOME_CELL + Vector2i(27, 4))
	for tick in 750: s.simulate(s.STEP)
	s.fit_world()
	s.paused = true
	await capture(s, "res://screenshots/orders.png")
	s.toggle_labor_panel()
	await capture(s, "res://screenshots/labor.png")
	s.toggle_labor_panel()
	# Show a real inspectable worker and the order on its card.
	for i in s.COUNT:
		if s.health[i] > 0 and s.roles[i] == s.WARDEN:
			s.select_ant(i)
			s.camera_zoom = 1.2
			s.camera_center = s.positions[i]
			s._sync_camera()
			break
	await capture(s, "res://screenshots/guard_order.png")
	quit()
