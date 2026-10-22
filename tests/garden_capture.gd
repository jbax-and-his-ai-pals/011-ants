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
	for tick in 450: s.simulate(s.STEP)
	s.paused = true
	s.fit_world()
	await capture(s, "res://screenshots/garden_overview.png")
	var baked_hash := hash(s.garden_cache.get_texture().get_image().get_data())
	if s.garden_cache.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		push_error("Scenery cache must stop rendering after its reset frame"); quit(1); return
	s.camera_center = s.HOME + Vector2(-100, -60)
	s.camera_zoom = 1.1
	s._sync_camera()
	s.select_ant(0)
	await capture(s, "res://screenshots/garden_detail.png")
	s.select_ant(-1)
	s.set_view(true)
	await capture(s, "res://screenshots/garden_underground.png")
	if hash(s.garden_cache.get_texture().get_image().get_data()) != baked_hash:
		push_error("Panning and switching layers must not repaint scenery"); quit(1); return
	s.reset_colony(42)
	s.paused = true
	s.fit_world()
	await capture(s, "res://screenshots/garden_seed42_overview.png")
	if hash(s.garden_cache.get_texture().get_image().get_data()) == baked_hash:
		push_error("Resetting the seed must repaint the cached garden"); quit(1); return
	print("PASS: garden bake renders once, stays unchanged across pan/zoom/layers and refreshes on a new seed.")
	quit()
