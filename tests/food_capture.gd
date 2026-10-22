extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(s, path: String) -> void:
	s._update_ui()
	s.world_canvas.queue_redraw()
	s.mini_canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	for tick in 300: s.simulate(s.STEP)
	s.elapsed = 90
	s.food_cycle.tick()
	s.command_system.issue(1, s.food_cycle.sites[0])
	s.command_system.issue(1, s.foods[0].pos)
	s.command_system.issue(2, s.HOME + Vector2(150, 0))
	s.command_system.issue(4, s.nest_position(1))
	s.toggle_order_panel()
	s.fit_world()
	s.paused = true
	await capture(s, "res://screenshots/food_forecast_orders.png")
	s.order_panel.visible = false
	s.food_cycle.focus()
	await capture(s, "res://screenshots/food_forecast_close.png")
	quit()
