extends SceneTree
## Native hot-loop checks against the retained GDScript implementation.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)

func compare(a, b) -> void:
	var max_position := 0.0
	var max_heading := 0.0
	for i in a.health.size():
		max_position = maxf(max_position, a.positions[i].distance_to(b.positions[i]))
		max_heading = maxf(max_heading, absf(a.headings[i] - b.headings[i]))
	check(max_position < 0.002, "Native/reference worker positions differ: %f px" % max_position)
	check(max_heading < 0.0001, "Native/reference headings differ: %f radians" % max_heading)
	for field in ["nurse_load", "nurse_targets", "tunnel_occupancy", "brood_buffers", "cargo_resource", "resource_delivered", "carrying", "roles", "layers", "opponents", "deliveries", "worker_kills", "casualties", "births", "worker_order_ids", "worker_order_kinds"]:
		check(a.get(field) == b.get(field), "Discrete worker state differs: " + field)
	for field in ["health", "trips", "walked", "attack_cooldowns", "food_scent", "home_scent", "rival_food_scent", "rival_home_scent", "third_food_scent", "third_home_scent", "protein_scent", "rival_protein_scent", "third_protein_scent", "protein_stores", "nutrition_weights", "food_stores"]:
		var first = a.get(field)
		var second = b.get(field)
		var error := 0.0
		for j in first.size(): error = maxf(error, absf(first[j] - second[j]))
		check(error < (0.002 if field == "walked" else 0.00001), "Numeric worker state differs: %s, error %.8f" % [field, error])
	check(a.delivered == b.delivered and a.rival_delivered == b.rival_delivered, "Both colonies must bank the same food")
	for f in a.foods.size(): check(a.foods[f].amount == b.foods[f].amount, "Food pickup must be identical and exclusive")
	var rng_equal := true
	for i in a.ant_rng.size():
		if a.ant_rng[i].state != b.ant_rng[i].state: rng_equal = false
	check(rng_equal, "Every worker must consume the same individual random stream")
	print("Native/reference max position error: %.8f px" % max_position)

func _run() -> void:
	var reference = load("res://main.tscn").instantiate()
	var native = load("res://main.tscn").instantiate()
	reference.colony_count = 2
	root.add_child(reference)
	native.colony_count = 2
	root.add_child(native)
	reference.set_process(false)
	native.set_process(false)
	check(native.native_kernel != null, "The native kernel must load for this test")
	if native.native_kernel == null:
		quit(1)
		return
	reference.native_enabled = false
	for profile in 3:
		for sim in [reference, native]:
			sim.reset_colony(4621)
			sim.combat_enabled = false
			sim.reproduction_enabled = false
			sim.invasions_enabled = false
			sim.doctrines.fill(profile)
			sim.swapped_sides = profile == 2
			var random := RandomNumberGenerator.new()
			random.seed = 5293
			for i in sim.starting_total():
				sim.positions[i] = Vector2(random.randf_range(9, sim.SIZE.x - 9), random.randf_range(9, sim.SIZE.y - 9))
				sim.carrying[i] = int(i % 3 == 0)
				sim.health[i] = 1.5
				sim.trips[i] = i % 60
			# Exact delivery, food pickup, and boundary-reflection fixtures.
			sim.positions[0] = sim.nest_for(0)
			sim.positions[1] = sim.foods[0].pos
			sim.positions[2] = Vector2(9, 9)
			sim.headings[2] = -2.4
			sim.simulate(sim.STEP)
		compare(reference, native)
	# Repeated full-population updates, including discovery, pickup and trails.
	for sim in [reference, native]:
		sim.swapped_sides = false
		sim.reset_colony(81923)
		sim.reproduction_enabled = false
		sim.invasions_enabled = false
	for tick in 120:
		reference.simulate(reference.STEP)
		native.simulate(native.STEP)
	compare(reference, native)
	# Interleave foragers, fighters, diggers, portal transitions and queen raids.
	for sim in [reference, native]:
		sim.reset_colony(42)
		sim.reproduction_enabled = false
		sim.invasions_enabled = false
		sim.health.fill(0)
		for i in [0, 1, 2, 3, sim.COUNT, sim.COUNT + 1, sim.COUNT + 2]:
			sim.health[i] = 3
			sim.attack_cooldowns[i] = 0
		sim.positions[0] = sim.nest_for(0)
		sim.carrying[0] = 1
		sim.positions[1] = sim.foods[0].pos
		sim.roles[2] = sim.INVADER
		sim.positions[2] = sim.nest_position(1)
		sim.roles[3] = sim.GUARD
		sim.layers[3] = 0
		sim.positions[3] = sim.queen_position(0) + Vector2(10, 0)
		sim.roles[sim.COUNT] = sim.INVADER
		sim.layers[sim.COUNT] = 0
		sim.positions[sim.COUNT] = sim.queen_position(0) + Vector2(0, -8)
		sim.roles[sim.COUNT + 1] = sim.GUARD
		sim.layers[sim.COUNT + 1] = 1
		sim.positions[sim.COUNT + 1] = sim.queen_position(1)
		sim.positions[sim.COUNT + 2] = sim.nest_position(1)
		sim.carrying[sim.COUNT + 2] = 1
	for tick in 240:
		if tick == 60:
			for sim in [reference, native]: sim.designate(sim.HOME_CELL + Vector2i(14, 3))
		reference.simulate(reference.STEP)
		native.simulate(native.STEP)
	compare(reference, native)
	check(reference.queen_health == native.queen_health and reference.earth == native.earth and reference.orders == native.orders, "Mixed missions must preserve queen damage and tunnel excavation")
	# Same full-population command setup in both implementations; includes cargo,
	# danger-zone entry/escape, guide steering, post leashes and hostile contact.
	for sim in [reference, native]:
		sim.reset_colony(81923)
		sim.reproduction_enabled = false
		sim.invasions_enabled = false
		var random := RandomNumberGenerator.new()
		random.seed = 5293
		for i in sim.starting_total():
			sim.positions[i] = Vector2(random.randf_range(9, sim.SIZE.x - 9), random.randf_range(9, sim.SIZE.y - 9))
			sim.carrying[i] = int(i % 3 == 0)
		sim.place_surface_order(1, sim.foods[0].pos)
		sim.place_surface_order(2, Vector2(1300, 800))
		sim.place_surface_order(3, Vector2(1650, 850))
		sim.place_surface_order(4, Vector2(2200, 900))
	for tick in 180:
		reference.simulate(reference.STEP)
		native.simulate(native.STEP)
	compare(reference, native)
	check(reference.worker_order_ids == native.worker_order_ids, "Individual command assignments must match")
	# Force both leaders through food selection, contested guards and a live raid.
	for sim in [reference, native]:
		sim.reset_colony(81923)
		sim.reproduction_enabled = false
		sim.elapsed = 100
		sim.food_stores[1] = 2000
		sim.place_surface_order(2, sim.HOME + Vector2(260, 150))
		sim.place_surface_order(1, sim.foods[0].pos)
		sim.rival_ai.update()
	for tick in 180:
		reference.simulate(reference.STEP)
		native.simulate(native.STEP)
	compare(reference, native)
	check(reference.rival_ai.selected == native.rival_ai.selected and reference.rival_ai.mode == native.rival_ai.mode, "Rival strategic choices must match across kernels")
	# Full three-colony parity, including independent AI, food fields and hostility.
	for sim in [reference, native]:
		sim.colony_count = 3
		sim.reset_colony(81923)
		sim.reproduction_enabled = false
		sim.roles[2 * sim.COUNT] = sim.RECOVERING
		sim.health[2 * sim.COUNT] = 2.99
		sim.positions[2 * sim.COUNT] = sim.nest_position(2)
		sim.place_surface_order(1, sim.foods[0].pos)
		sim.place_surface_order(2, sim.HOME + Vector2(300, 100))
	for tick in 600:
		reference.simulate(reference.STEP)
		native.simulate(native.STEP)
	compare(reference, native)
	check(reference.third_delivered == native.third_delivered and reference.third_ai.selected == native.third_ai.selected, "Third colony delivery and strategic choices match")
	if failures == 0: print("PASS: native/reference rules, all profiles, swapped nests, 4,000 individual RNG streams, deliveries, pickup, healing, scent, reflection and repeated full-population ticks.")
	quit(1 if failures else 0)
