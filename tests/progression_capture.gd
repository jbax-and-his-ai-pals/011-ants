extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440, 900)
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	s.game_modes.start(1, 81923)
	while s.living_count(0) < 100: s._spawn_worker(0)
	s.food_stores[0] = 2000; s.protein_stores[0] = 1000
	var base: Vector2i = s.chamber_cell(0)
	for x in range(2, 8):
		var j: int = s._idx(base + Vector2i(x, 0))
		s.earth[j] = 1; s.chamber_rooms[j] = s.chambers.BROOD; s.chambers.room_tiles[0][j] = s.chambers.BROOD
	s.chambers.dirty = true; s.chambers.rebuild()
	s.progression.panel.visible = true; s.paused = true
	await capture(s,"res://screenshots/progression_choice.png")
	s.progression.choose(0, 2); s.next_raids.fill(INF); s.rival_ai_enabled = false
	for tick in 4200: s.simulate(s.STEP)
	for x in range(8, 12):
		var j: int = s._idx(base + Vector2i(x, 0))
		s.earth[j] = 1; s.chamber_rooms[j] = s.chambers.BROOD; s.chambers.room_tiles[0][j] = s.chambers.BROOD
	s.chambers.dirty = true; s.chambers.rebuild()
	print("CAPTURE READINESS ",s.progression.queen_reason(0), " population=",s.living_count(0), " capacity=", s.brood_capacity)
	s.progression.start_daughter(0)
	for tick in 2700: s.simulate(s.STEP)
	s.set_view(true); s.camera_center = s._center(base) + Vector2(200, 20); s.camera_zoom = 2.4; s._sync_camera()
	s.progression.panel.visible = true
	await capture(s,"res://screenshots/progression_daughter.png")
	for i in s.health.size():
		if s.castes[i] and s.health[i] > 0:
			s.progression.panel.visible = false; s.select_ant(i)
			await capture(s,"res://screenshots/progression_soldier.png")
			break
	print("PROGRESSION CAPTURE daughter=", s.progression.daughters[0], " soldiers=", s.progression.soldier_counts[0])
	quit()
