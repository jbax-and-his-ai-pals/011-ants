extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size=Vector2i(1440,900)
	var s=load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	s.game_modes.start(1,81923); s.paused=true
	var pair: Dictionary=s.strategic_garden.pairs[0]
	# Staged observation fixture: real scouts cover each corridor, not a grant
	# of remote food information to the game's normal observation system.
	while s.living_count(0)<30: s._spawn_worker(0)
	for n in 9:
		for side in 2:
			var i: int=s.colony_workers[0][n*2+side]
			s.positions[i]=pair.home.lerp(pair.short if side==0 else pair.long,n/8.0); s.layers[i]=-1; s.roles[i]=s.FORAGER
	for n in 8:
		var i: int=s.colony_workers[1][n]
		s.positions[i]=pair.home.lerp(pair.short,.7)+Vector2(n,0); s.layers[i]=-1; s.roles[i]=s.FORAGER
	var distant_scout: int=s.colony_workers[0][18]
	s.positions[distant_scout]=s.foods[3].pos; s.layers[distant_scout]=-1
	s.scouting.sample(); s.scouting.toggle(); s.fit_world()
	if s.scouting.rows.size()<6: push_error("Capture requires all six report rows"); quit(1); return
	await capture(s,"res://screenshots/strategic_garden_reports.png")
	s.scouting.panel.visible=false; s.camera_center=pair.home.lerp(pair.long,.5); s.camera_zoom=1.4; s._sync_camera()
	await capture(s,"res://screenshots/strategic_garden_routes.png")
	s.game_modes.start(0,81923); s.paused=true
	s.rival_ai.think(); s.toggle_rival_plan()
	await capture(s,"res://screenshots/strategic_garden_rival.png")
	quit()
