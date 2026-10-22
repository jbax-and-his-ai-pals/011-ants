extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func isolate(s, native: bool) -> void:
	s.reset_colony(81923)
	s.native_enabled = native
	s.reproduction_enabled = false
	s.invasions_enabled = false
	s.rival_ai_enabled = false
	s.combat_enabled = false
	s.food_cycles_enabled = false
	s.health.fill(0)
	s.foods.clear()
	s.food_index_size = -1

func run() -> void:
	var s = load("res://main.tscn").instantiate()
	s.chambers_enabled = false # Isolate the pre-chamber nutrient/combat fixture; physical logistics has its own suite.
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	for patch in s.foods:
		check(patch.resource == (1 if patch.food_visual == 2 else 0), "Fruit/nectar are sugar; insect sources are protein")
	for native in [false, true]:
		for c in 3:
			for resource in 2:
				isolate(s, native)
				var i: int = c * s.COUNT
				var home: Vector2 = s.nest_position(c)
				s.health[i] = 3
				s.positions[i] = home + Vector2(200, 0)
				s.foods = [{"pos": s.positions[i], "amount": 1, "resource": resource}]
				if c == 0:
					s.command_system.markers = [{"id": 99, "kind": 1, "pos": s.positions[i], "assigned": 1, "status": "Active"}]
					s.worker_order_ids[i] = 99
					s.worker_order_kinds[i] = 1
				s.simulate(s.STEP)
				check(s.carrying[i] == 1 and s.cargo_resource[i] == resource and s.foods[0].amount == 0, "Typed one-unit pickup for each colony and kernel")
				check(s.resource_delivered[c * 2 + resource] == 0, "Pickup is not delivery")
				s.worker_order_ids[i] = -1
				s.positions[i] = home
				s.simulate(s.STEP)
				check(s.food_stores[c] == s.INITIAL_STORES + (1 if resource == 0 else 0) and s.protein_stores[c] == s.INITIAL_PROTEIN + resource, "Load reaches only its own colony's matching store")
				var trail: PackedFloat32Array = ([s.protein_scent, s.rival_protein_scent, s.third_protein_scent] if resource else [s.food_scent, s.rival_food_scent, s.third_food_scent])[c]
				check(trail[s._idx(s._cell(home))] > 0, "Carriers deposit the matching nutrient trail")
				check(s.resource_delivered[c * 2 + resource] == 1 and s.deliveries[i] == 1, "Typed and worker delivery ledgers agree")
				if c == 0: check(s.command_system.order_resources[99][resource] == 1, "Order credits resource held at pickup after reassignment")
		# Local choices reverse when colony demand reverses, without expanding sight.
		isolate(s, native)
		s.health[0] = 3
		var p := Vector2(600, 600)
		s.positions[0] = p
		s.foods = [{"pos": p + Vector2(12, 0), "amount": 10, "resource": 0}, {"pos": p + Vector2(0, 12), "amount": 10, "resource": 1}, {"pos": p + Vector2(87, 0), "amount": 10000, "resource": 0}]
		s.food_stores[0] = 1000
		s.protein_stores[0] = 0
		s.nutrition.refresh()
		s.simulate(s.STEP)
		check(s.carrying[0] == 1 and s.cargo_resource[0] == 1, "Protein shortage changes actual local pickup")
		s.carrying[0] = 0
		s.positions[0] = p
		s.food_stores[0] = 0
		s.protein_stores[0] = 1000
		s.nutrition.refresh()
		s.simulate(s.STEP)
		check(s.cargo_resource[0] == 0 and s.foods[2].amount == 10000, "Sugar shortage changes pickup without omniscient sensing")
		# Identical worker RNG, opposite nutrient trails: demand changes the turn.
		isolate(s, native)
		s.health[0] = 3
		var random_state: int = s.ant_rng[0].state
		var turns: Array[float] = []
		for need in 2:
			s.positions[0] = p
			s.headings[0] = 0
			s.trips[0] = 0
			s.ant_rng[0].state = random_state
			s.food_scent.fill(0)
			s.protein_scent.fill(0)
			s.protein_scent[s._idx(s._cell(p + Vector2.from_angle(-0.65) * 27))] = 5
			s.food_scent[s._idx(s._cell(p + Vector2.from_angle(0.65) * 27))] = 5
			s.food_stores[0] = 0 if need == 0 else 1000
			s.protein_stores[0] = 1000 if need == 0 else 0
			s.nutrition.refresh()
			s.simulate(s.STEP)
			turns.append(s.headings[0])
		check(turns[1] < turns[0] - 0.1, "Shortage changes actual antenna steering toward the needed nutrient trail")
		# Protein cargo cannot merge with a sugar pile, and an enemy can recover it.
		isolate(s, native)
		s.positions[0] = p
		s.carrying[0] = 1
		s.cargo_resource[0] = 1
		s.foods = [{"pos": p, "amount": 7, "resource": 0}]
		s._kill_ant(0)
		check(s.foods.size() == 2 and s.foods[0].amount == 7 and s.foods[1].resource == 1, "A death drops the original nutrient without converting nearby sugar")
		s.health[s.COUNT] = 3
		s.positions[s.COUNT] = p
		s.food_stores[1] = 1000
		s.protein_stores[1] = 0
		s.nutrition.refresh()
		s.simulate(s.STEP)
		# Same-position ties are resolved by patch index, so remove sugar for this recovery fixture.
		if s.cargo_resource[s.COUNT] == 0:
			s.carrying[s.COUNT] = 0
			s.foods[0].amount = 0
			s.positions[s.COUNT] = p
			s.simulate(s.STEP)
		check(s.carrying[s.COUNT] == 1 and s.cargo_resource[s.COUNT] == 1, "A rival recovers typed dropped protein")
		# Sugar funds upkeep; protein alone cannot keep workers alive or heal soldiers.
		isolate(s, native)
		s.health[0] = 2
		s.food_stores[0] = 0
		s.protein_stores[0] = 1000
		s._update_nurseries(1)
		check(s.health[0] < 2 and s.queen_hungry[0] == 1 and s.protein_stores[0] == 1000, "Protein cannot pay sugar upkeep or create brood during starvation")
		s.roles[0] = s.RECOVERING
		s.positions[0] = s.HOME
		var hp: float = s.health[0]
		s._recover_worker(0, 1)
		check(s.health[0] == hp, "Protein cannot pay soldier recovery")
		# Brood waits for protein, then resumes with exactly one protein charge.
		isolate(s, native)
		s.food_stores.fill(1000)
		s.protein_stores.fill(0)
		s.brood[0] = [{"stage": 0, "age": 8.1}]
		s._update_nurseries(0.1)
		check(s.brood[0][0].stage == 0 and s.brood_spent[0] == 0, "Sugar alone cannot feed brood")
		s.protein_stores[0] = 3
		s._update_nurseries(0.1)
		check(s.brood[0][0].stage == 1 and s.protein_stores[0] == 0 and s.brood_spent[0] == 3, "Protein resumes a blocked stage at its explicit cost")
	# Equal-distance known sources change rank when a rival's shortage changes.
	s.reset_colony(81923)
	var home: Vector2 = s.nest_position(1)
	s.foods = [{"pos": home + Vector2(100, 0), "amount": 4000, "resource": 0}, {"pos": home + Vector2(0, 100), "amount": 4000, "resource": 1}]
	for i in s.colony_workers[1]: s.positions[i] = home
	s.food_stores[1] = 1000
	s.protein_stores[1] = 0
	s.rival_ai.think()
	check(s.rival_ai.source_scores[0].index == 1, "Rival ranks protein first during protein shortage")
	s.food_stores[1] = 0
	s.protein_stores[1] = 1000
	s.rival_ai.think()
	check(s.rival_ai.source_scores[0].index == 0, "Rival ranks sugar first during sugar shortage")
	# The player's marked labor share responds too, without increasing its budget.
	s.command_system.clear()
	var player_home: Vector2 = s.nest_position(0)
	s.foods = [{"pos": player_home + Vector2(200, 0), "amount": 4000, "resource": 0}, {"pos": player_home - Vector2(200, 0), "amount": 4000, "resource": 1}]
	for i in s.colony_workers[0]: s.positions[i] = player_home
	s.food_stores[0] = 1000
	s.protein_stores[0] = 0
	s.nutrition.refresh()
	s.command_system.issue(1, s.foods[0].pos)
	s.command_system.issue(1, s.foods[1].pos)
	check(s.command_system.markers[1].assigned == 500 and s.command_system.markers[0].assigned == 0, "Marked labor shifts to protein within the existing normal budget")
	s.food_stores[0] = 0
	s.protein_stores[0] = 1000
	s.nutrition.refresh()
	s.command_system.allocate()
	check(s.command_system.markers[0].assigned == 500 and s.command_system.markers[1].assigned == 0, "Marked labor shifts back to sugar when upkeep is threatened")
	s.food_cycles_enabled = true
	s.elapsed = 90
	s.food_cycle.tick()
	s.elapsed = 120
	s.food_cycle.tick()
	check(s.food_cycle.added_resources == PackedInt32Array([12000, 6000]), "Each wave introduces a conserved sugar/protein mix")
	s.reset_colony(42)
	check(s.protein_stores[0] == s.INITIAL_PROTEIN and s.resource_delivered.count(0) == 6 and s.cargo_resource.count(0) == s.starting_total(), "Reset clears nutrient cargo and ledgers")
	if failures == 0: print("PASS: sugar/protein pickup, own-store banking, order credit, shortage response, typed dropped cargo, upkeep/recovery separation, paused/resumed brood, AI ranking and refill/reset ledgers in both kernels.")
	s.queue_free()
	quit(1 if failures else 0)
