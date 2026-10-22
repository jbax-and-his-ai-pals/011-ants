extends SceneTree
## Render the real game viewport for visual review. The application exits afterward.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var colony = load("res://main.tscn").instantiate()
	root.add_child(colony)
	colony.set_process(false)
	colony.reset_colony(81923)
	for tick in 2400:
		colony.simulate(1.0 / 30.0)
	colony._update_ui()
	colony.queue_redraw()
	colony.world_canvas.queue_redraw()
	colony.mini_canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/surface.png")
	colony.set_view(true)
	colony.designate(colony.HOME_CELL + Vector2i(27, 4))
	colony.designate(colony.HOME_CELL + Vector2i(28, 5), false)
	colony.designate(colony.HOME_CELL + Vector2i(29, 5), false)
	for tick in 330:
		colony.simulate(1.0 / 30.0)
	colony._update_ui()
	colony.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/underground.png")
	colony.inspected_colony = 1
	colony._update_ui()
	colony.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/rival_nursery.png")
	# Controlled encounter previews use the real simulation, entrance transitions,
	# routing and damage. The first three images above are the ordinary colony run.
	colony.reset_colony(42)
	colony.reproduction_enabled = false
	colony.health.fill(0)
	for i in 48:
		colony.health[i] = 3
	for i in 8:
		colony.positions[i] = colony.nest_position(1) + Vector2(i * 2, 0)
	for i in range(colony.COUNT, colony.COUNT + 3):
		colony.health[i] = 3
		colony.layers[i] = 1
		colony.roles[i] = colony.GUARD
		colony.positions[i] = colony.queen_position(1) + Vector2(i - colony.COUNT, -10)
	colony.launch_raid(0, 8)
	colony.invasions_enabled = false
	colony.queen_health[1] = 18
	colony.inspected_colony = 1
	colony.set_view(true)
	for tick in 2000:
		colony.simulate(1.0 / 30.0)
		if colony.queen_health[1] < 13:
			break
	colony._update_ui()
	colony.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/invasion.png")
	for tick in 2000:
		colony.simulate(1.0 / 30.0)
		if not colony.match_result.is_empty():
			break
	if colony.match_result != "victory":
		push_error("The scripted victory preview failed to kill the rival queen")
		quit(1)
		return
	colony._update_ui()
	colony.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/victory.png")
	colony.reset_colony(42)
	colony.reproduction_enabled = false
	colony.invasions_enabled = false
	colony.health.fill(0)
	colony.health[colony.COUNT] = 3
	colony.roles[colony.COUNT] = colony.INVADER
	colony.layers[colony.COUNT] = 0
	colony.positions[colony.COUNT] = colony.queen_position(0) + Vector2(0, -8)
	colony.attack_cooldowns[colony.COUNT] = 0
	colony.queen_health[0] = 0.1
	colony.set_view(true)
	colony.simulate(1.0 / 30.0)
	colony._update_ui()
	colony.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/defeat.png")
	colony.reset_colony(81923)
	colony.invasions_enabled = false
	for tick in 1800:
		colony.simulate(1.0 / 30.0)
	var inspect_ant := 0
	for i in colony.COUNT:
		if colony.health[i] > 0 and colony.carrying[i]:
			inspect_ant = i
			break
	colony.select_ant(inspect_ant)
	colony.camera_center = colony.positions[inspect_ant] + Vector2(115, 0)
	colony.camera_zoom = 1.7
	colony._sync_camera()
	colony._update_ui()
	colony.world_canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/ant_inspector.png")
	colony.select_ant(-1)
	colony.fit_world()
	colony.world_canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/world_overview.png")
	print("Saved gameplay, invasion/results, ant inspector and world overview screenshots.")
	quit()
