extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate()
	root.add_child(s); s.set_process(false)
	s.game_modes.start(1, 81923)
	while s.colony_workers[1].size() < 80: s._spawn_worker(1)
	s.food_stores.fill(2000); s.food_cycles_enabled = false; s.reproduction_enabled = false
	s.health.fill(0)
	for i in s.colony_workers[1]:
		s.health[i] = 3; s.positions[i] = s.nest_position(1)
	s.health[0] = 3; s.roles[0] = s.WARDEN
	var direction: Vector2 = (s.nest_position(1) - s.HOME).normalized()
	s.positions[0] = s.HOME + direction * 180 + direction.orthogonal() * 110
	s.worker_order_goals[0] = s.positions[0]
	s.queen_health[2] = 0; s.next_raids[0] = INF; s.elapsed = 300
	var ai = s.rival_ai
	ai.think(); ai.orders.allocate()
	for tick in 2400:
		s.simulate(s.STEP)
		if s.scouting.warnings.has(1) and ai.probe_arrived_at >= 0: break
	s.camera_center = s.HOME + direction * 110; s.camera_zoom = 1.5; s._sync_camera()
	s.paused = true
	await capture(s, "res://screenshots/raid_probe_warning.png")
	s.rival_panel.visible = true
	await capture(s, "res://screenshots/raid_probe_plan.png")
	s.rival_panel.visible = false
	for tick in 1800:
		s.simulate(s.STEP)
		if ai.escalation.get(0, {}).get("completed", false): break
	s.rival_panel.visible = true
	await capture(s, "res://screenshots/raid_response_interval.png")
	for tick in 2400:
		s.simulate(s.STEP)
		if ai.raid_until > 0 and ai.raid_phase == "invasion": break
	await capture(s, "res://screenshots/raid_invasion_plan.png")
	print("ESCALATION_CAPTURE ", ai.phase_counts, " phase=", ai.raid_phase, " party=", ai.raid_size)
	quit()
