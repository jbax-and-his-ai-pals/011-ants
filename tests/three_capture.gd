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
	s.speed = 4
	for tick in 750: s.simulate(s.STEP)
	s.fit_world()
	s.paused = true
	s.inspected_ai = 2
	s.toggle_rival_plan()
	await capture(s, "res://screenshots/three_colonies.png")
	s.toggle_rival_plan()
	s.inspected_colony = 2
	s.set_view(true)
	s._set_speed(0.25)
	await capture(s, "res://screenshots/azure_nursery.png")
	s.set_view(false)
	s._set_speed(0.5)
	var worker: int = 2 * s.COUNT
	s.roles[worker] = s.WARDEN
	s.health[worker] = 1
	s.positions[worker] = s.nest_position(2) + Vector2(30, 0)
	s._recover_worker(worker, s.STEP)
	s.select_ant(worker)
	s.camera_center = s.positions[worker]
	s.camera_zoom = 1.5
	s._sync_camera()
	await capture(s, "res://screenshots/soldier_recovery.png")
	quit()
