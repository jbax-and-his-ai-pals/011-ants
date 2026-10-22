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
	for tick in 900: s.simulate(s.STEP)
	s.fit_world()
	s.paused = true
	s.toggle_rival_plan()
	await capture(s, "res://screenshots/rival_strategy.png")
	# Controlled full-population fixture, using actual AI observation/assignment.
	s.reset_colony(81923)
	s.speed = 4
	s.elapsed = 100
	s.food_stores[1] = 2000
	var front: Vector2 = s.nest_position(1) + Vector2(-400, 0)
	for patch in s.foods:
		if patch.pos.distance_to(s.nest_position(1)) < 500: patch.amount = 200
	s.foods.append({"pos": front, "amount": 5000, "layer": -1})
	for i in 200: s.positions[s.COUNT + i] = front + Vector2(i % 20, i / 20)
	for i in 30: s.positions[i] = front + Vector2(-200, i % 10)
	s.rival_ai.update()
	s.fit_world()
	s.paused = true
	s.toggle_rival_plan()
	await capture(s, "res://screenshots/rival_raid_plan.png")
	for i in 12: s.positions[i] = s.nest_position(1) + Vector2(100, i % 10)
	s.rival_ai.think()
	s.rival_ai.orders.allocate()
	await capture(s, "res://screenshots/rival_defense.png")
	quit()
