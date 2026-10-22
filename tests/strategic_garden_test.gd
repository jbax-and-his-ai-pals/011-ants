extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	var audits: Array = []
	for mode in [0, 1]:
		for seed_value in [81923,404,9973,17,73,2026,1337,9001,42,12345,7,81]:
			s.game_modes.start(mode, seed_value)
			check(s.strategic_garden.pairs.size() == 3, "Every nest has a pair of alternative sources")
			var variants := {}
			for c in 3:
				var pair: Dictionary = s.strategic_garden.pairs[c]
				var short_trip: Dictionary = s.strategic_garden.estimate(c, pair.short)
				var long_trip: Dictionary = s.strategic_garden.estimate(c, pair.long)
				check(short_trip.trip_seconds < long_trip.trip_seconds, "Exposed soil source has the shorter surface round trip")
				check(short_trip.soil >= 60 and short_trip.shade < 30, "Short approach is mostly fast exposed soil")
				check(long_trip.shade >= 60 and long_trip.soil < 30, "Long approach preserves trails along actual shaded cells")
				for point in [pair.short,pair.long]: check(Rect2(14,14,s.SIZE.x-28,s.SIZE.y-28).has_point(point), "Both opportunities stay inside the walkable world")
				var index: int = (9 if mode else 18) + c*2
				check(s.foods[index].resource == 0 and s.foods[index+1].resource == 1 and s.foods[index+1].amount > s.foods[index].amount*2, "Sources offer modest sugar versus richer brood protein")
				variants[var_to_str([pair.short-pair.home,pair.long-pair.home,s.foods[index].amount])] = true
				if mode:
					for n in 3:
						var patch: Dictionary = s.foods[c*3+n]
						check(patch.pos.distance_to(pair.home)<130 and patch.amount >= [160,110,220][n], "Founding starters keep guaranteed nearby nutrients")
				audits.append({"mode":mode,"seed":seed_value,"colony":c,"short":short_trip,"long":long_trip})
			check(variants.size()==3, "Strategic opportunities differ between starting areas")
			var before: PackedByteArray = var_to_bytes([s.foods,s.surface_speed,s.surface_shade])
			s.game_modes.start(mode,seed_value)
			check(before==var_to_bytes([s.foods,s.surface_speed,s.surface_shade]), "Map and source quantities reproduce by seed")
	# Estimates are read-only, bounded, and honor loaded versus unloaded speed.
	s.game_modes.start(1,81923)
	var worker_state: int = s.ant_rng[0].state
	var target_state: int = s.rival_ai.target_rng.state
	var before: Array = s.foods.duplicate(true)
	var goal: Vector2 = s.strategic_garden.pairs[0].long
	var original: float = s.strategic_garden.estimate(0,goal).trip_seconds
	s.foraging_multipliers[0]=1.15
	var faster: float = s.strategic_garden.estimate(0,goal).trip_seconds
	check(faster < original and faster > original/1.15, "Foraging specialization speeds only the unloaded estimate")
	for n in 1000: s.strategic_garden.estimate(0,Vector2(n,400))
	check(s.strategic_garden.cache.size()<=s.strategic_garden.MAX_CACHE, "Geometry cache remains bounded with many loose-source locations")
	check(s.ant_rng[0].state==worker_state and s.rival_ai.target_rng.state==target_state and s.foods==before, "Reports never consume RNG or change food")
	# Same useful quantity: soil travel, shortages, corridor danger and real losses
	# must each affect the actual source ranking, without a hidden threat feed.
	s.game_modes.start(0,81923)
	var ai = s.rival_ai
	var home: Vector2 = s.nest_position(1)
	s.foods=[{"pos":home+Vector2(350,0),"amount":1000,"resource":0},{"pos":home+Vector2(0,350),"amount":1000,"resource":1}]
	ai.known={0:{"pos":s.foods[0].pos,"amount":1000,"friends":0,"enemies":0,"seen":0},1:{"pos":s.foods[1].pos,"amount":1000,"friends":0,"enemies":0,"seen":0}}
	s.nutrition_weights.fill(1)
	var safe: Dictionary = ai.score_source(0,100)
	var mid: Vector2i = ai.cell(home+Vector2(175,0))
	ai.route_contacts[mid]={"count":12,"seen":0}
	check(ai.score_source(0,100).score < safe.score*.6, "Observed midway danger penalizes a source even if its endpoint is empty")
	ai.route_contacts.clear(); ai.route_losses[mid]=3
	check(ai.score_source(0,100).score < safe.score*.6, "Own recent route combat losses discourage repeated costly trips")
	ai.route_losses.clear(); s.nutrition_weights[3]=3
	check(ai.score_source(1,100).score > ai.score_source(0,100).score*2, "Protein shortage can justify a longer trip")
	# Route risk affects real assignments, rather than being inspection text.
	s.foods=[{"pos":home+Vector2(100,0),"amount":1000},{"pos":home+Vector2(0,100),"amount":1000}]
	for i in s.colony_workers[1]: s.positions[i]=home; s.roles[i]=s.FORAGER; s.layers[i]=-1; s.carrying[i]=0
	ai.orders.markers=[ai.marker(1000,1,s.foods[0].pos),ai.marker(1001,1,s.foods[1].pos)]
	ai.orders.markers[1]["route_weight"]=.1
	ai.orders.allocate()
	check(ai.orders.markers[0].assigned==500 and ai.orders.markers[1].assigned==0, "Rival route danger influences individual worker recruitment within the existing labor budget")
	# Actual knowledge: public forecast may reveal future supply, never remote
	# current stock or unobserved enemies anywhere along its route.
	s.game_modes.start(1,81923)
	ai=s.rival_ai; home=s.nest_position(1)
	for i in s.colony_workers[1]: s.positions[i]=home; s.layers[i]=-1
	goal=home+Vector2(-600,0)
	s.foods=[{"pos":goal,"amount":9999,"resource":1,"cycle_site":99,"forecast":1200,"arrival":30.0}]
	for i in s.colony_workers[0]: s.positions[i]=goal; s.layers[i]=-1
	ai.think()
	check(ai.known.has(0) and ai.known[0].amount==1200 and ai.known[0].enemies==0, "Forecast planning uses public supply without hidden stocks or hostile endpoint counts")
	check(ai.route_contacts.is_empty(), "Unseen enemies do not appear in rival route memory")
	var scout: int = s.colony_workers[1][0]
	s.positions[scout]=goal; s.elapsed=1; ai.think()
	check(not ai.route_contacts.is_empty() and ai.known[0].amount==9999, "Real scout discovers both remote stock and corridor threats")
	s.positions[scout]=home; s.elapsed=22; ai.think()
	check(ai.route_contacts.is_empty(), "Unwatched rival route evidence expires after twenty seconds")
	s.scouting.panel.visible=true; s.scouting.update_ui()
	# Real carriers follow both terrain alternatives with either movement kernel.
	for native in [false,true]:
		for kind in 2:
			s.game_modes.start(1,81923); s.native_enabled=native
			s.chambers_enabled=false; s.reproduction_enabled=false; s.combat_enabled=false; s.invasions_enabled=false; s.rival_ai_enabled=false; s.food_cycles_enabled=false
			s.health.fill(0); s.health[0]=3; s.roles[0]=s.FORAGER; s.layers[0]=-1; s.positions[0]=s.HOME
			goal=s.strategic_garden.pairs[0]["short" if kind==0 else "long"]
			s.foods=[{"pos":goal,"amount":1,"resource":kind}]; s.food_index_size=-1
			s.worker_order_ids[0]=42; s.worker_order_kinds[0]=1; s.worker_order_goals[0]=goal
			s.allocation_clock=-100000 # Isolate an existing guided worker from job reassignment.
			for tick in 1800:
				s.simulate(s.STEP)
				if s.resource_delivered[kind]>0: break
			check(s.resource_delivered[kind]==1 and s.foods[0].amount==0 and s.deliveries[0]==1, "Individual ant walks, picks up and returns each alternative's nutrient in both kernels")
	var file:=FileAccess.open("res://tests/strategic_garden_accessibility.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":true,"checks_passed":failures==0,"samples":audits},"\t"))
	if failures==0: print("PASS: 24 seeded maps / 72 colony route pairs, varied guaranteed starters, terrain/trip tradeoffs, bounded read-only estimates, shortage/danger/loss ranking, observed-only rival route memory and physical pickup/return.")
	s.queue_free(); quit(1 if failures else 0)
