extends SceneTree

var failures := 0
var colony

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func mouse(local_point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = colony.get_global_transform() * local_point
	event.global_position = event.position
	event.pressed = pressed
	event.button_index = button
	root.push_input(event, true)

func motion(local_point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = colony.get_global_transform() * local_point
	event.global_position = event.position
	root.push_input(event, true)

func _run() -> void:
	colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	root.add_child(colony)
	colony.set_process(false)
	colony.reset_colony(42)
	colony.paused = true
	await process_frame
	check(colony.COLS * colony.ROWS == 9 * 78 * 42 and colony.living_count(0) == colony.COUNT and colony.living_count(1) == colony.COUNT, "World should be nine times larger with the configured starting populations")
	check(colony.world_clip.clip_contents and colony.world_clip.size == colony.VIEW_SIZE, "World rendering should be clipped independently of the fixed UI")
	var point: Vector2 = colony.HOME + Vector2(70, 35)
	check(colony.screen_to_world(colony.world_to_screen(point)).distance_to(point) < 0.001, "World and screen transforms must round trip")
	var anchor := Vector2(800, 420)
	var anchor_before: Vector2 = colony.screen_to_world(anchor)
	mouse(anchor, true, MOUSE_BUTTON_WHEEL_UP)
	check(colony.camera_zoom > 1 and colony.screen_to_world(anchor).distance_to(anchor_before) < 0.01, "Wheel zoom must preserve the world point under the cursor")
	var center_before: Vector2 = colony.camera_center
	mouse(Vector2(760, 450), true)
	motion(Vector2(820, 480))
	mouse(Vector2(820, 480), false)
	check(colony.camera_center.distance_to(center_before - Vector2(60, 30) / colony.camera_zoom) < 0.01, "Dragging should pan by the correct world-space distance")
	check(colony.pending_count() == 0 and colony.selected_ant == -1, "Navigation drag must not dig or select an ant")
	colony.fit_world()
	check(colony.visible_world_rect().size.distance_to(colony.SIZE) < 0.02, "Overview must show the entire expanded world")
	colony.camera_center = Vector2(-10000, 10000)
	colony.camera_zoom = 100
	colony._sync_camera()
	check(colony.camera_zoom == 3.5 and colony.visible_world_rect().position.x >= 0 and colony.visible_world_rect().end.y <= colony.SIZE.y + 0.01, "Camera limits must keep zoom and panning inside the map")
	colony.focus_nest()
	var mini_point: Vector2 = colony.MINI_RECT.position + colony.MINI_MAP.position + colony.MINI_MAP.size * Vector2(0.75, 0.65)
	mouse(mini_point, true)
	mouse(mini_point, false)
	check(colony.camera_center.distance_to(colony.SIZE * Vector2(0.75, 0.65)) < 0.01, "Clicking the minimap must jump to the selected world position")
	# Camera bookmarks must stay separate for each nest and the surface.
	var surface_center: Vector2 = colony.camera_center
	colony.set_view(true)
	colony.focus_nest()
	colony.camera_center += Vector2(100, 0)
	colony._sync_camera()
	var nest_center: Vector2 = colony.camera_center
	colony.set_view(false)
	check(colony.camera_center == surface_center, "Returning to the surface should restore its camera")
	colony.set_view(true)
	check(colony.camera_center == nest_center, "Returning to a nest should restore its camera")
	# Inspection must pick the correct ant in the visible layer after transformations.
	colony.set_view(false)
	colony.focus_nest()
	colony.health.fill(0)
	colony.health[0] = 3
	colony.health[colony.COUNT] = 3
	colony.positions[0] = colony.HOME + Vector2(120, 55)
	colony.positions[colony.COUNT] = colony.positions[0]
	colony.layers[colony.COUNT] = 1
	var ant_point: Vector2 = colony.world_to_screen(colony.positions[0])
	mouse(ant_point, true)
	mouse(ant_point, false)
	check(colony.selected_ant == 0 and colony.inspector_panel.visible and colony.selected_info.id == colony.worker_ids[0], "Clicking a visible ant should show its unique inspector, ignoring other layers")
	colony.deliveries[0] = 7
	colony.worker_kills[0] = 2
	colony.walked[0] = 123
	colony.elapsed = 12
	colony._update_ui()
	check(colony.selected_info.delivered == 7 and colony.selected_info.kills == 2 and colony.selected_info.walked == 123 and colony.selected_info.age == 12, "Inspector must report real per-worker lifetime statistics")
	colony._toggle_follow()
	colony.positions[0] += Vector2(100, 25)
	colony._process(0)
	check(colony.following and colony.camera_center == colony.positions[0], "Following should keep the camera on the selected ant")
	colony.layers[0] = 1
	colony.positions[0] = colony.queen_position(1)
	colony._process(0)
	check(colony.underground and colony.inspected_colony == 1 and colony.active_camera_layer == 1, "Following must track an ant through a nest transition")
	var old_id: int = colony.worker_ids[0]
	colony.health[0] = 0
	colony._kill_ant(0)
	colony._spawn_worker(0)
	colony._update_ui()
	check(colony.selected_ant == -1 and not colony.following and colony.selected_info.id == old_id and not colony.selected_info.alive and colony.worker_ids[0] != old_id, "A dead selected ant must not silently become a different newborn when its slot is reused")
	check(colony.deliveries[0] == 0 and colony.worker_kills[0] == 0 and colony.walked[0] == 0, "Replacement workers need fresh statistics")
	check(not colony.stats.fps.text.is_empty() and not colony.stats.frame_time.text.is_empty(), "Performance counters must remain in the fixed UI")
	colony.reset_colony(7)
	check(colony.selected_ant == -1 and colony.selected_info.is_empty() and colony.camera_zoom == 1 and not colony.dig_mode, "Reset should clear inspection and restore the initial camera/tool")
	if failures == 0:
		print("PASS: expanded world, clipping, camera transforms, cursor zoom, pan, limits, minimap, camera bookmarks, ant picking, stats, cross-layer follow, dead-slot identity, FPS UI, reset.")
	quit(1 if failures else 0)
