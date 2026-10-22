extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440,900)
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	s.game_modes.start(1,81923); s.paused = true
	s.clarity.record("raid","Small raid sighting: 3 observed",s.HOME+Vector2(220,100))
	s.clarity.record("forecast","Public protein forecast: 30s",s.HOME+Vector2(100,-120))
	s.clarity.toggle_history()
	await capture(s,"res://screenshots/clarity_events.png")
	s.clarity.close_panels()
	while s.living_count(0)<40: s._spawn_worker(0)
	s.food_stores[0]=1000; s.protein_stores[0]=1000
	s.elapsed=10
	s.progression.choose(0,1)
	s.command_system.history.clear(); s.command_system.sample()
	s.command_system.issue(1,s.HOME+Vector2(100,0)); s.command_system.set_priority(0,0)
	s.set_chamber_tool(2); s.designate(s.chamber_cell(0)+Vector2i(7,0))
	s.command_system.set_priority(2,0); s.clarity.sample(); s.clarity.toggle_work()
	await capture(s,"res://screenshots/clarity_work.png")
	s.set_view(false)
	for offset in [Vector2(150,0),Vector2(0,150)]: s.command_system.issue(1,s.HOME+offset)
	for offset in [Vector2(200,0),Vector2(0,200),Vector2(-200,0)]: s.command_system.issue(2,s.HOME+offset)
	s.command_system.issue(4,s.nest_position(1))
	s.command_system.issue(3,Vector2(1800,800)); s.clarity.sample()
	if s.command_system.markers.size()!=8: push_error("Capture requires eight actual orders"); quit(1); return
	s.toggle_order_panel()
	await capture(s,"res://screenshots/clarity_orders.png")
	s.order_panel.visible=false
	s.clarity.close_panels(); s.progression.toggle()
	await capture(s,"res://screenshots/clarity_objective.png")
	quit()
