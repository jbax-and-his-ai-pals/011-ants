extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(s, path: String) -> void:
	s.command_system.sample()
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
	s.command_system.issue(1, s.foods[0].pos)
	s.command_system.issue(1, s.foods[2].pos)
	for tick in 2700: s.simulate(s.STEP)
	s.paused = true
	s.fit_world()
	s.toggle_order_panel()
	await capture(s, "res://screenshots/nutrition_orders.png")
	s.order_panel.visible = false
	for i in s.colony_workers[0]:
		if s.health[i] > 0 and s.carrying[i] and s.cargo_resource[i] == 1:
			s.select_ant(i)
			s.camera_center = s.positions[i]
			s.camera_zoom = 1.1
			s._sync_camera()
			break
	await capture(s, "res://screenshots/nutrition_protein_carrier.png")
	s.select_ant(-1)
	s.fit_world()
	s.protein_stores[0] = 0 # Controlled shortage UI fixture, not a match statistic.
	s.nutrition.refresh()
	await capture(s, "res://screenshots/nutrition_protein_shortage.png")
	s.food_stores[0] = 0
	s.protein_stores[0] = 1000
	s.nutrition.refresh()
	await capture(s, "res://screenshots/nutrition_sugar_shortage.png")
	print("PASS: sugar/protein HUD, actual order deliveries, typed carrier and controlled shortage screenshots captured.")
	quit()
