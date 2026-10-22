extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	check(s.game_mode == 0 and s.starting_total() == 6000, "The original skirmish remains the default")
	s.game_modes.start(1, 81923)
	check(s.starting_total() == 36 and s.health.size() == 36, "Founding creates exactly 12 real workers per colony")
	for c in 3:
		check(s.living_count(c) == 12 and s.food_stores[c] == 80 and s.protein_stores[c] == 96, "Each founding colony gets the same small economy")
		check(s.chambers.buffered[c] <= s.protein_stores[c], "Initial brood buffers are paid from founding protein")
		for other in 3:
			if other != c: check(s.nest_position(c).distance_to(s.nest_position(other)) > 1400, "Founding nests have room to grow before encountering each other")
		for kind in 3:
			var food: Dictionary = s.foods[c * 3 + kind]
			check(food.pos.distance_to(s.nest_position(c)) < 130 and food.resource == (1 if kind == 2 else 0), "Every colony starts with local sugar and protein")
	check(s.game_modes.selector.selected == 1 and s.camera_zoom == 1.5, "Mode selection and founding camera are visible")
	# Finite local replenishment first, followed by shared food on the same rules.
	for wave in 4:
		s.elapsed = (wave + 1) * 120 - 30
		s.food_cycle.tick()
		check(s.food_cycle.pending.size() == (3 if wave < 3 else 6), "Founding retains local supplies and forecasts shared supplies later")
		for n in 3:
			var patch: Dictionary = s.foods[s.food_cycle.pending[n]]
			if wave < 3:
				check(patch.pos.distance_to(s.nest_position(n)) < 130 and patch.forecast == 360, "Early replenishment supplies each home equally")
			else:
				check(patch.cycle_site < 9 and patch.forecast == maxi(0, 360 - patch.amount), "Local support tops up remaining stock when competition starts")
		if wave >= 3:
			for index in s.food_cycle.pending.slice(3):
				var shared: Dictionary = s.foods[index]
				check(shared.cycle_site >= 9 and shared.forecast == 1200, "Later food also appears in shared territory")
		s.elapsed += 30
		s.food_cycle.tick()
	check(s.food_cycle.wave == 4, "All founding supply waves arrive")
	s.game_modes.start(1, 81923)
	s.elapsed = 299
	check(not s.game_modes.automatic_raids_allowed(1, 100), "Rivals do not raid during the five-minute founding period")
	s.elapsed = 300
	check(not s.game_modes.automatic_raids_allowed(1, 59) and s.game_modes.automatic_raids_allowed(1, 60), "Rival raids also wait for 60 actual workers")
	s.rival_ai.think()
	check(s.rival_ai.raid_until == 0 and s.rival_ai.reason.contains("Founding"), "A small rival explains why it is growing instead of raiding")
	for n in 48: s._spawn_worker(1)
	s.food_stores[1] = 500
	s.rival_ai.think()
	check(s.rival_ai.raid_until > 0, "A grown colony can resume normal raid decisions")
	s.game_modes.start(1, 81923)
	check(s.place_surface_order(s.command_system.RAID, s.nest_position(1)), "The player can choose an early expedition")
	var raiders := 0
	for i in s.colony_workers[0]:
		if s.roles[i] == s.INVADER: raiders += 1
	check(raiders > 0, "Founding limits automatic raids, not player agency")
	# Growing arrays, room-local births and individual RNG stay equivalent in
	# both kernels when the initial colony has only twelve workers.
	var reference = load("res://main.tscn").instantiate()
	root.add_child(reference)
	reference.set_process(false)
	reference.native_enabled = false
	reference.game_modes.start(1, 81923)
	s.game_modes.start(1, 81923)
	for tick in 1500:
		s.simulate(s.STEP)
		reference.simulate(reference.STEP)
	check(s.health.size() == reference.health.size(), "Both kernels grow the same worker arrays from founding crews")
	for field in ["births", "roles", "carrying", "cargo_resource", "layers", "resource_delivered", "brood_buffers", "nurse_load"]:
		check(s.get(field) == reference.get(field), "Founding native/reference state agrees: " + field)
	for i in s.health.size():
		check(s.positions[i].distance_to(reference.positions[i]) < 0.002 and s.ant_rng[i].state == reference.ant_rng[i].state, "Founders and new workers preserve individual movement and RNG in both kernels")
	reference.queue_free()
	# Real development and collection over six minutes, without artificial income.
	var samples := []
	for seed_value in [81923, 404, 9973]:
		s.game_modes.start(1, seed_value)
		var first_contact := -1.0
		var early_losses := -1
		for tick in 10800:
			s.simulate(s.STEP)
			if first_contact < 0 and s.casualties[0] + s.casualties[1] + s.casualties[2] > 0: first_contact = s.elapsed
			if tick == 3599: early_losses = s.casualties[0] + s.casualties[1] + s.casualties[2]
		print("FOUNDING OPENING seed=%d first combat loss=%.1fs losses at 120s=%d" % [seed_value, first_contact, early_losses])
		check(early_losses == 0, "Separated founding colonies have a peaceful first two minutes")
		var population := [s.living_count(0), s.living_count(1), s.living_count(2)]
		for c in 3:
			check(s.births[c] > 0 and population[c] > 12, "Every colony grows through fed brood from a small founding crew")
			check(s.queen_health[c] > 0 and s.starvation_losses[c] == 0, "The founding opening supports all three queens and workers")
			check(s.resource_delivered[c * 2] > 0 and s.resource_delivered[c * 2 + 1] > 0, "Founders physically deliver both resources")
			check(s.protein_stores[c] + 0.01 >= s.chambers.buffered[c] + s.chambers.reserved[c], "Founding nurse allocations reconcile with protein stores")
			samples.append({"seed": seed_value, "colony": c, "population": population[c], "births": s.births[c], "combat_losses": s.casualties[c], "hunger_losses": s.starvation_losses[c]})
	print("FOUNDING 360s: ", JSON.stringify(samples))
	s.reset_colony(81923)
	check(s.game_mode == 1 and s.health.size() == 36 and s.food_cycle.wave == 0 and s.elapsed == 0, "New seed retains the selected mode and resets its state")
	s.game_modes.start(0, 81923)
	check(s.game_mode == 0 and s.health.size() == 6000 and s.workers_per_colony == 2000, "Switching back restores the full skirmish")
	check(s.food_stores[0] == s.INITIAL_STORES and s.protein_stores[0] == s.INITIAL_PROTEIN and s.food_cycle.sites.size() == 6, "Skirmish economy and supply sites remain unchanged")
	check(s.nest_position(0).distance_to(s.nest_position(1)) < 800 and s.game_modes.automatic_raids_allowed(1, 12), "Skirmish keeps its close placement and existing raid rules")
	if failures == 0: print("PASS: mode selection/reset, preserved skirmish, 12-worker founding colonies, separated local supplies, phased replenishment, raid maturity, player agency and three real six-minute growth runs.")
	s.queue_free()
	quit(1 if failures else 0)
