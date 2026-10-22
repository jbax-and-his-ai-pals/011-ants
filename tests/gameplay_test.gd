extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
func mouse(s, point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = s.get_global_transform() * point
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)
func _run() -> void:
	var s = load("res://main.tscn").instantiate()
	s.colony_count = 2
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	var c = s.command_system
	s.paused = true
	var food: Vector2 = s.foods[0].pos
	check(s.place_surface_order(c.FORAGE, food), "Orders can be placed while paused")
	check(c.markers[0].assigned == 500, "Normal marked forage commits one quarter of 2000 workers")
	s.set_labor_priority(0, 3)
	check(c.markers[0].assigned == 1000, "High forage increases guided workers, retaining free scouts")
	for patch in s.foods:
		if patch.pos.distance_to(food) < 160: patch.amount = 0
	c.allocate()
	check(c.markers[0].status == "Depleted" and c.markers[0].assigned == 0, "Exhausted known food releases its recruits")
	s.clear_surface_orders()
	# Nearest recruitment must never take a loaded carrier away from home.
	s.positions[0] = s.HOME + Vector2(260, 0)
	s.carrying[0] = 1
	check(s.place_surface_order(c.GUARD, s.positions[0]), "Place guard post")
	var guard_id: int = c.markers[0].id
	check(c.markers[0].assigned == 12 and s.roles[0] == s.FORAGER, "Guard budget and cargo delivery priority")
	var guard := -1
	for i in s.COUNT:
		if s.roles[i] == s.WARDEN: guard = i; break
	check(guard >= 0, "Guard post assigns actual individual ants")
	s.health[guard] = 0
	s._kill_ant(guard)
	c.allocate()
	check(c.markers[0].assigned == 12 and s.worker_order_ids[guard] == -1, "Post replaces a casualty with an available worker")
	s.set_labor_priority(1, 0)
	check(c.markers[0].assigned == 0, "Security Off releases the party")
	s.set_labor_priority(1, 3)
	check(c.markers[0].assigned == 24, "Security High supports 24 per post")
	check(c.remove(guard_id), "Remove persistent post")
	for i in s.COUNT: check(s.roles[i] != s.WARDEN, "Removing a post releases every guard")
	# A raid marker near the entrance uses the normal tunnel invasion behavior.
	s.positions[1] = s.nest_position(1)
	s.carrying[1] = 0
	check(s.place_surface_order(c.RAID, s.nest_position(1)), "Place queen raid")
	s._surface_mission(1, s.STEP)
	check(s.layers[1] == 1 and s.roles[1] == s.INVADER, "Marked raider enters the rival's actual tunnels")
	s.clear_surface_orders()
	check(s.roles[1] == s.RETURNING and s.layers[1] == 1, "Cancelled underground raider walks out rather than teleporting")
	check(not c.issue(c.AVOID, s.nest_position(0)), "Avoid cannot seal the home entrance")
	var danger: Vector2 = s.HOME + Vector2(380, 0)
	check(c.issue(c.AVOID, danger), "Place danger area")
	check(not c.issue(c.FORAGE, danger), "Conflicting target inside Avoid is rejected")
	check(c.safe_step(danger + Vector2(101, 0), danger + Vector2(99, 0)) == danger + Vector2(101, 0), "Avoid prevents new entry")
	check(c.safe_step(danger, danger + Vector2(2, 0)) != danger, "Workers caught inside can leave")
	check(c.avoidance_direction(danger + Vector2(-200, 0), danger + Vector2(200, 0), 0).y != 0, "Avoid steers around a blocking circle")
	# Surface danger markers must not suppress defense in a tunnel underneath.
	for native in [true, false]:
		s.reset_colony(42)
		s.native_enabled = native
		s.health.fill(0)
		s.health[0] = 3
		s.health[s.COUNT] = 3
		s.layers[0] = 0
		s.layers[s.COUNT] = 0
		s.positions[0] = s._center(s.entrance_cell(0))
		s.positions[s.COUNT] = s.positions[0] + Vector2(0, 20)
		check(c.issue(c.AVOID, s.positions[0]), "Surface marker can overlap tunnel shaft coordinates")
		s._prepare_encounters(s.STEP)
		check(s.opponents[0] == s.COUNT, "Surface Avoid does not affect tunnel defense native=%s" % native)
	# Walk a real carrier past the obstacle and bank its food, native and fallback.
	for native in [true, false]:
		s.reset_colony(42)
		s.native_enabled = native
		s.health.fill(0)
		s.health[0] = 3
		s.combat_enabled = false
		s.invasions_enabled = false
		s.reproduction_enabled = false
		s.positions[0] = s.HOME + Vector2(600, 0)
		s.carrying[0] = 1
		danger = s.HOME + Vector2(300, 0)
		c.issue(c.AVOID, danger)
		var entered := false
		for tick in 900:
			s.simulate(s.STEP)
			if s.positions[0].distance_to(danger) < 99.99: entered = true
			if s.delivered > 0: break
		check(not entered and s.delivered == 1, "Carrier detours and delivers in implementation native=%s" % native)
	s.reset_colony(42)
	s.designate(s.HOME_CELL + Vector2i(27, 4))
	s.set_labor_priority(2, 3)
	check(s.digger_count() == 24, "High digging recruits a 24-worker crew")
	var queued: int = s.pending_count()
	s.set_labor_priority(2, 0)
	check(s.digger_count() == 0 and s.pending_count() == queued, "Off pauses excavation without erasing plans")
	# Food telemetry uses simulated time and accounts for both spending sources.
	s.reset_colony(42)
	s.elapsed = 10
	s.delivered = 40
	s.resource_delivered[0] = 30
	s.resource_delivered[1] = 10
	s.upkeep_spent[0] = 60
	s.brood_spent[0] = 10
	s.food_stores[0] = 90
	s.positions[0] = Vector2(700, 700)
	s.health[0] = 0
	s._kill_ant(0)
	s.positions[1] = Vector2(705, 705)
	s.health[1] = 0
	s._kill_ant(1, true)
	c.sample()
	check(is_equal_approx(c.report.income, 240) and is_equal_approx(c.report.net, -180), "Combined income and sugar net account for distinct resource deliveries")
	check(is_equal_approx(c.report.runway, 30) and c.report.combat == 1 and c.report.hunger == 1, "Depletion forecast and distinct causes")
	check(c.hotspot.count == 2, "Nearby losses form an inspectable hotspot")
	s.focus_loss_hotspot()
	check(s.show_loss_hotspot and s.camera_center.distance_to(Vector2(700, 700)) < 1, "Hotspot control centers on the recorded location")
	s.elapsed = 41
	c.sample()
	check(c.report.combat == 0 and c.report.hunger == 0 and c.hotspot.is_empty(), "Recent loss window expires")
	s.match_result = "victory"
	check(not c.issue(c.GUARD, Vector2(600, 600)), "Finished matches reject new orders")
	s.reset_colony(42)
	check(c.markers.is_empty() and s.avoid_points.is_empty() and c.labor == PackedInt32Array([2, 2, 2]), "New seed clears commands and resets labor")
	await process_frame
	key(KEY_5)
	check(s.command_tool == c.GUARD and not s.underground, "Guard shortcut selects the surface tool")
	var point := Vector2(850, 400)
	mouse(s, point, true)
	mouse(s, point, false)
	check(c.markers.size() == 1, "Viewport click places an order")
	mouse(s, point, true, MOUSE_BUTTON_RIGHT)
	mouse(s, point, false, MOUSE_BUTTON_RIGHT)
	check(c.markers.is_empty(), "Viewport right-click removes a marker")
	key(KEY_L)
	check(s.labor_panel.visible, "Labor shortcut opens the priorities panel")
	var before: int = c.labor[0]
	mouse(s, s.labor_panel.position + s.priority_buttons[0].position + s.priority_buttons[0].size * 0.5, true)
	mouse(s, s.labor_panel.position + s.priority_buttons[0].position + s.priority_buttons[0].size * 0.5, false)
	await process_frame
	check(c.labor[0] == (before + 1) % 4 and c.markers.is_empty(), "Actual priority button works without placing an order through the panel")
	key(KEY_ESCAPE)
	check(s.command_tool == 0 and not s.labor_panel.visible, "Escape closes the overlay and restores inspection")
	if failures == 0: print("PASS: persistent orders, labor budgets, depletion, carrier detours in both implementations, queen invasion, casualty replacement and food/loss telemetry.")
	quit(1 if failures else 0)
