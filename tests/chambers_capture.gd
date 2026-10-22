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
	s.set_chamber_tool(1)
	s.designate(s.chamber_cell(0) + Vector2i(-8, 0))
	s.set_chamber_tool(2)
	s.designate(s.chamber_cell(0) + Vector2i(8, 0))
	s.camera_center = s._center(s.chamber_cell(0)) + Vector2(0, -110)
	s.camera_zoom = 1.5
	s._sync_camera()
	s.paused = true
	await capture(s, "res://screenshots/chambers_planned.png")
	s.set_labor_priority(2, 3)
	for tick in 2400: s.simulate(s.STEP)
	s.dig_mode = false
	s.set_command_tool(s.command_system.GUARD)
	s.place_surface_order(s.command_system.GUARD, s._center(s.entrance_cell(0) + Vector2i(0, 6)))
	for tick in 300: s.simulate(s.STEP)
	s.command_tool = 0
	await capture(s, "res://screenshots/chambers_working.png")
	for i in s.colony_workers[0]:
		if s.health[i] > 0 and s.roles[i] == s.NURSE and s.nurse_load[i] > 0:
			s.select_ant(i)
			break
	await capture(s, "res://screenshots/chambers_nurse.png")
	print("CHAMBERS_CAPTURE capacity=%s brood=%s births=%s buffered=%s reserved=%s pending=%d" % [s.storage_capacity, s.brood_capacity, s.births, s.chambers.buffered, s.chambers.reserved, s.pending_count()])
	quit()
