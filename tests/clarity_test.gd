extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; push_error(text)
func fingerprint(s) -> PackedByteArray:
	var randoms := []
	for r in s.ant_rng: randoms.append(r.state)
	return var_to_bytes([s.positions,s.roles,s.health,s.carrying,s.layers,s.food_stores,s.protein_stores,s.brood,s.brood_buffers,s.foods,s.worker_order_ids,s.command_system.markers,randoms,s.rival_ai.target_rng.state])
func run() -> void:
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	s.game_modes.start(0,81923)
	var before := fingerprint(s)
	for n in 3: s.clarity.sample(); s.clarity.toggle_history(); s.clarity.toggle_work(); s.clarity.close_panels()
	check(fingerprint(s)==before,"Observation and panels do not change Skirmish worker state, economy, orders or RNG")
	check(not s.clarity.tracker.visible,"Skirmish has no Founding objective tracker")
	var hidden := {"pos": Vector2(3000,60), "amount": 20, "layer": -1, "resource": 1}
	s.foods.append(hidden); var index: int = s.foods.size()-1
	s.scouting.visible.clear(); var count: int = s.clarity.events.size()
	s.scouting.observe_food(index)
	check(s.clarity.events.size()==count,"History cannot discover unseen food")
	s.scouting.reveal(s.scouting.sector(hidden.pos)); s.scouting.observe_food(index)
	check(s.clarity.events.size()==count+1,"A real observed discovery becomes an event")
	s.scouting.observe_food(index)
	check(s.clarity.events.size()==count+1,"Repeated sightings do not flood history")
	s.scouting.visible.clear(); hidden.amount = 0; s.scouting.observe_food(index)
	check(s.clarity.events.size()==count+1,"Unseen depletion cannot leak into history")
	s.scouting.reveal(s.scouting.sector(hidden.pos)); s.scouting.observe_food(index)
	check(s.clarity.events.front().text.contains("depleted"),"Observed depletion is dated in history")
	var old := Vector2(1200,600)
	s.clarity.record("raid","Old observed group",old)
	s.clarity.toggle_history(); s.clarity.history_rows[0].pressed.emit()
	check(s.camera_center==old and not s.underground and not s.clarity.history_panel.visible,"Actual event row focuses its stored observed position")
	s.clarity.record("breach","Breach",s.queen_position(0),0)
	s.clarity.focus_event(s.clarity.events.front().id)
	check(s.underground and s.inspected_colony==0,"Breach history focuses the correct nest layer")
	for n in 300: s.clarity.record("test","Bounded event",old,-1,"test:%d" % n,1)
	check(s.clarity.events.size()==96 and s.clarity.cooldowns.size()<=128,"History and deduplication memory remain bounded")
	s.game_modes.start(1,81923)
	check(s.clarity.objective_step==1 and s.clarity.tracker.visible,"Founding starts with the specialization objective")
	while s.living_count(0)<40: s._spawn_worker(0)
	s.food_stores[0]=1000; s.protein_stores[0]=1000; s.clarity.sample()
	check(s.clarity.events.any(func(e): return e.text.contains("Specialization ready")),"A newly affordable specialization emits a readiness event")
	s.paused=true; s.progression.choose(0,1); s._update_ui()
	check(s.clarity.objective_step==2,"Paused development immediately advances the objective tracker")
	s.clarity.sample(); s.clarity.tracker.pressed.emit()
	check(s.underground and s.chamber_tool==2 and s.inspected_colony==0,"Nursery tracker opens actual brood designation")
	s.command_system.issue(1,s.HOME+Vector2(80,0)); s.command_system.set_priority(0,0); s.clarity.sample()
	var m: Dictionary = s.command_system.markers[0]
	s.toggle_order_panel(); s._update_ui()
	check(s.order_rows[0].text.contains("Off") and s.order_rows[0].text.contains("protein"),"Order rows keep delivery information and show the blocking reason")
	check(s.clarity.order_reasons[m.id].contains("Off"),"Stalled forage explains labor Off without changing assignments")
	s.clarity.toggle_work(); s._input(make_key(KEY_E))
	check(s.clarity.history_panel.visible and not s.clarity.work_panel.visible,"E opens history and closes the work panel")
	s._input(make_key(KEY_ESCAPE)); check(not s.clarity.history_panel.visible,"Escape closes clarity panels")
	var isolated := Vector2i(130,40)
	s.earth[s._idx(isolated)]=0; s._set_order(s._idx(isolated),true)
	s.clarity.sample()
	check(s.clarity.work_rows[0].why.contains("reachable"),"Isolated excavation reports the missing connected work face")
	s.command_system.set_priority(2,0); s.clarity.sample()
	check(s.clarity.work_rows[0].why.contains("paused"),"Excavation Off has a concrete explanation")
	s.queen_health[0]=0; s._check_outcome()
	check(not s.clarity.tracker.visible and not s.clarity.history_panel.visible and not s.clarity.work_panel.visible,"Results take priority over clarity overlays")
	# Earlier planning uses real projects, costs/labor and worker excavation.
	for native in [false,true]:
		s.game_modes.start(1,81923); s.native_enabled=native
		while s.living_count(1)<60: s._spawn_worker(1)
		s.food_stores[1]=1000; s.protein_stores[1]=1000
		s.progression.choose(1,1)
		var planner = s.rival_ai.nest
		planner.next_project=0; planner.think(60,false)
		check(planner.project.contains("daughter") and not planner.pending.is_empty(),"A specialized 60-worker rival queues a nursery before 80")
		check(s.brood_capacity[1]==18,"A planned room grants no instant capacity")
		s.rival_ai.think(); s._allocate_workers(1)
		check(s.rival_ai.orders.labor[2]==1 and s.digger_count(1)<=6,"Preparation uses at most six actual diggers to preserve the young workforce")
		s.next_raids.fill(INF); s.rival_ai_enabled=false
		for tick in 2400:
			s._allocate_workers(1); s.simulate(s.STEP)
			if s.brood_capacity[1]>=24: break
		check(s.brood_capacity[1]>=24 and planner.dug>0,"Real rival workers dig and connect the earlier nursery in both kernels")
		s.game_modes.start(0,81923); planner=s.rival_ai.nest; planner.next_project=0; planner.think(60,false)
		check(not planner.project.contains("daughter"),"Skirmish never receives Founding nursery anticipation")
	s.queue_free()
	if failures==0: print("PASS: read-only observation, bounded dated history, discovery privacy, actual row focus/layers, objective actions, concrete stalled work, overlay input, real earlier rival excavation in both kernels and Skirmish isolation.")
	quit(1 if failures else 0)
func make_key(code: int) -> InputEventKey:
	var e := InputEventKey.new(); e.keycode=code; e.pressed=true; return e
