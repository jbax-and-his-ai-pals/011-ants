extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func mouse(p: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = p
	motion.global_position = p
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = p
	event.global_position = p
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _run() -> void:
	var colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	root.add_child(colony)
	colony.set_process(false)
	await process_frame
	key(KEY_TAB)
	check(colony.underground, "Tab should enter the underground view")
	key(KEY_SPACE)
	check(colony.paused, "Space should pause through the viewport input system")
	key(KEY_3)
	check(colony.speed == 4, "3 should select 4x speed")
	key(KEY_F)
	check(not colony.trails_visible, "F should toggle scent visibility")
	key(KEY_G)
	check(colony.dig_mode, "G should enable tunnel designation instead of camera dragging")
	# Test the custom brush through actual viewport mouse events and transforms.
	var brush_start: Vector2i = colony.HOME_CELL + Vector2i(12, 3)
	var local_point: Vector2 = colony.world_to_screen(colony._center(brush_start))
	var screen_point: Vector2 = colony.get_global_transform() * local_point
	mouse(screen_point, true)
	var end_point: Vector2 = colony.get_global_transform() * colony.world_to_screen(colony._center(brush_start + Vector2i(7, 0)))
	var motion := InputEventMouseMotion.new()
	motion.position = end_point
	motion.global_position = end_point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	mouse(end_point, false)
	check(colony.orders[colony._idx(brush_start)] == 1, "Mouse-down should designate the clicked cell")
	check(colony.orders[colony._idx(brush_start + Vector2i(4, 0))] == 1, "Fast brush strokes should paint intermediate tiles")
	check(not colony.painting, "Releasing the mouse should stop painting")
	mouse(end_point, true, MOUSE_BUTTON_RIGHT)
	mouse(end_point, false, MOUSE_BUTTON_RIGHT)
	check(colony.orders[colony._idx(brush_start + Vector2i(7, 0))] == 0, "Right mouse should erase orders")
	# Exercise the real GUI button, including its mouse hit rectangle.
	var button_point: Vector2 = colony.get_global_transform() * Vector2(370, 122)
	mouse(button_point, true)
	mouse(button_point, false)
	check(not colony.underground, "Surface button should respond to viewport mouse clicks")
	# Letterbox the board to check that the brush uses local board coordinates.
	root.size = Vector2i(1200, 1000)
	await process_frame
	colony._layout_ui()
	colony.set_view(true)
	colony.dig_mode = true
	var resized_tile: Vector2i = colony.HOME_CELL + Vector2i(24, 8)
	local_point = colony.world_to_screen(colony._center(resized_tile))
	screen_point = colony.get_global_transform() * local_point
	mouse(screen_point, true)
	mouse(screen_point, false)
	check(colony.orders[colony._idx(resized_tile)] == 1, "Brush should hit the correct tile in a resized/letterboxed window")
	key(KEY_Q)
	check(colony.inspected_colony == 1 and colony.underground, "Q should inspect the rival queen and nursery")
	var previous_orders: int = colony.pending_count()
	mouse(screen_point, true)
	mouse(screen_point, false)
	check(colony.pending_count() == previous_orders, "Rival nursery inspection must not allow player digging")
	key(KEY_Q)
	check(colony.inspected_colony == 0, "Q should return to the player's nursery")
	var old_profile: int = colony.doctrines[0]
	button_point = colony.get_global_transform() * Vector2(90, 646)
	mouse(button_point, true)
	mouse(button_point, false)
	check(colony.doctrines[0] == (old_profile + 1) % 3, "The player trait button should cycle the player's profile")
	old_profile = colony.doctrines[1]
	button_point = colony.get_global_transform() * Vector2(205, 646)
	mouse(button_point, true)
	mouse(button_point, false)
	check(colony.doctrines[1] == (old_profile + 1) % 3, "The rival trait button should allow neutral or swapped-profile trials")
	key(KEY_R)
	var ordered_raiders := 0
	for i in colony.health.size():
		if colony.roles[i] == colony.INVADER and colony.colonies[i] == 0:
			ordered_raiders += 1
	check(ordered_raiders > 0 and ordered_raiders <= 12, "R should order a bounded player raid while planning is paused")
	colony.set_view(false)
	colony.camera_center = colony.nest_position(1)
	colony._sync_camera()
	for i in range(colony.COUNT, colony.starting_total()):
		colony.positions[i] += Vector2(0, 80)
	button_point = colony.get_global_transform() * colony.world_to_screen(colony.nest_position(1))
	mouse(button_point, true)
	mouse(button_point, false)
	check(colony.underground and colony.inspected_colony == 1, "Clicking a surface nest should inspect that nest's tunnels")
	colony.queen_health[1] = 0
	colony._check_outcome()
	check(colony.result_panel.visible, "Queen death should show the result overlay through the actual game UI")
	button_point = colony.get_global_transform() * Vector2(710, 553)
	mouse(button_point, true)
	mouse(button_point, false)
	check(colony.result_dismissed and not colony.result_panel.visible and colony.match_result == "victory", "Inspect battlefield must dismiss the result without resuming the match")
	var stopped_time: float = colony.elapsed
	key(KEY_SPACE)
	colony._process(0.1)
	check(colony.elapsed == stopped_time, "Space must not resume a finished match")
	button_point = colony.get_global_transform() * Vector2(1360, 124)
	mouse(button_point, true)
	mouse(button_point, false)
	check(colony.match_result.is_empty() and not colony.result_panel.visible and colony.queen_health[1] == 100, "New seed must start a playable new match after dismissing the result")
	if failures == 0:
		print("PASS: keyboard shortcuts, mouse designation, interpolated dragging, release, right-click erasing, GUI buttons, resized window coordinates.")
	quit(1 if failures else 0)
