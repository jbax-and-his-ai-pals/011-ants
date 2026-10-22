extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	for mode in [0, 1]:
		s.game_modes.start(mode, 81923)
		var intel = s.scouting
		s.health.fill(0)
		s.queen_health[0] = 100
		s.health[0] = 3
		s.layers[0] = -1
		s.positions[0] = s.HOME
		var local: Vector2 = s.HOME + Vector2(40, 0)
		var remote: Vector2 = s.HOME + Vector2(600, 0)
		s.foods = [{"pos": local, "amount": 50, "resource": 0}, {"pos": remote, "amount": 70, "resource": 1}]
		intel.reset()
		check(intel.foods.has(0) and not intel.foods.has(1), "Food reports require real scout coverage in both modes")
		s.positions[0] = remote
		s.elapsed += .8; intel.sample()
		check(intel.foods.has(1) and intel.foods[1].amount == 70, "A real scout discovers remote protein")
		s.positions[0] = s.HOME
		s.foods[1].amount = 2
		s.elapsed += .8; intel.sample()
		check(intel.foods[1].amount == 70, "Unwatched food reports keep their last-seen stock")
		s.positions[0] = remote
		s.elapsed += .8; intel.sample()
		check(intel.foods[1].amount == 2, "Revisiting refreshes the actual stock")
		# Public forecasts do not reveal current supplies in an unseen sector.
		s.foods.append({"pos": s.HOME + Vector2(-600, 0), "amount": 999, "resource": 0, "arrival": s.elapsed + 30, "cycle_site": 99})
		s.food_cycle.pending.assign([2])
		s.elapsed += .8; intel.sample()
		check(not intel.foods.has(2), "A public forecast is not a remote stock observation")
		# Near scout, remote from home: detect presence, then actual approach.
		var enemy: int = s.workers_per_colony
		s.health[enemy] = 3; s.colonies[enemy] = 1; s.layers[enemy] = -1; s.roles[enemy] = s.INVADER
		s.positions[enemy] = remote + Vector2(30, 0)
		s.elapsed += .8; intel.sample()
		check(intel.activity.has(1) and intel.warnings.is_empty(), "A distant stationary sighting does not invent an incoming raid")
		s.positions[enemy].x -= 35
		s.elapsed += .8; intel.sample()
		check(intel.warnings.has(1) and intel.warnings[1].count == 1, "Observed raider movement toward the nest creates a warning")
		check(intel.routes[1].danger > 0, "Observed enemies raise danger on the affected route")
		# A worker carrying food is activity, not proof of a raid.
		s.roles[enemy] = s.FORAGER
		s.elapsed += .8; intel.sample()
		check(intel.warnings.is_empty(), "Visible retreat or non-raiding activity clears an obsolete warning")
		s.roles[enemy] = s.INVADER
		s.positions[0] = s.HOME
		s.positions[enemy] = s.nest_position(1)
		s.elapsed += .8; intel.sample()
		check(intel.warnings.is_empty(), "Unseen hostile raid orders do not leak into warnings")
		s.elapsed += 25; intel.sample()
		check(intel.contacts.is_empty(), "Enemy route evidence expires in simulation time")
		# Own losses are reliable danger even when the enemy has disappeared.
		s.command_system.losses = [{"time": s.elapsed, "pos": s.HOME.lerp(remote, .5), "layer": -1, "hunger": false, "order": -1}]
		s.command_system.loss_head = 0
		intel.sample()
		check(intel.routes[1].losses == 1 and intel.routes[1].danger == 1, "Actual recent route losses contribute independently")
		s.elapsed += 31; intel.sample()
		check(intel.routes[1].losses == 0, "Route casualty evidence expires after 30 seconds")
		# Nest alarm is local information and does not need surface scouts.
		s.layers[enemy] = 0; s.positions[enemy] = s.queen_position(0)
		intel.sample()
		check(intel.warnings.has(1) and intel.warnings[1].inside, "A real nest breach reports intruders")
		intel.focus_warning()
		check(s.underground and s.inspected_colony == 0, "Clicking a breach warning focuses the player's nest")
		s.layers[enemy] = -1; s.positions[enemy] = s.nest_position(1)
		s.elapsed += .8; intel.sample()
		check(intel.warnings.is_empty(), "A cleared nest breach removes its alarm")
		var rng_state: int = s.ant_rng[0].state
		var target_state: int = s.rival_ai.target_rng.state
		intel.sample()
		check(s.ant_rng[0].state == rng_state and s.rival_ai.target_rng.state == target_state, "Scouting does not consume worker or AI random streams")
		intel.toggle(); intel.update_ui()
		check(intel.panel.visible and not s.order_panel.visible, "Scouting panel opens with readable route rows")
		s.toggle_labor_panel()
		check(s.labor_panel.visible and not intel.panel.visible, "Opening labor priorities replaces the scout panel")
		intel.focus_food(1)
		check(not s.underground and s.camera_center == remote, "Report rows focus the remembered source")
		var scans: int = intel.scans
		s.paused = true; s._process(.1)
		check(intel.scans == scans, "Pause freezes scouting reports")
		s.game_modes.start(mode, 404)
		check(not intel.panel.visible and intel.warnings.is_empty() and intel.activity.is_empty(), "New seed clears enemy memory and panels")
	# Bounded food memory and discovery effort even with many cargo piles.
	s.foods.clear()
	for n in 5000: s.foods.append({"pos": s.HOME, "amount": 1, "resource": 0, "dropped": n >= 100})
	s.scouting.reset()
	for n in 5: s.scouting.sample()
	check(s.scouting.foods.size() <= 64 and s.scouting.cursor == 6 * s.scouting.FOOD_BUDGET, "Discovery work and remembered food sites are bounded")
	if failures == 0: print("PASS: scouting in both modes, real food discovery/revisit/staleness, public forecast limits, observed approach warnings, unseen intent isolation, retreat/breach clearing, route sightings/loss expiry, focus/UI/pause/reset, RNG isolation and bounded food work.")
	s.queue_free()
	quit(1 if failures else 0)

