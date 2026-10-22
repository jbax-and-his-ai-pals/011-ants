extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	var speeds: PackedFloat32Array = s.surface_speed.duplicate()
	var shade: PackedByteArray = s.surface_shade.duplicate()
	var ground: PackedByteArray = s.garden.ground.duplicate()
	var food_before: Array = s.foods.duplicate(true)
	var worker_rng: int = s.ant_rng[0].state
	var map_rng: int = s.rng.state
	s.garden.build(s)
	check(s.surface_speed == speeds and s.surface_shade == shade and s.garden.ground == ground, "Garden generation repeats by seed")
	check(s.ant_rng[0].state == worker_rng and s.rng.state == map_rng, "Garden does not consume ant or world RNG")
	check(s.foods == food_before, "Scenery does not change food quantity, position, pickup or refill rules")
	var soil := -1
	var shaded := -1
	var sunny := -1
	var litter := 0
	var damp := 0
	for j in s.CELLS:
		if ground[j] == 1:
			check(absf(speeds[j] - 1.15) < 0.000001, "Soil has exact declared movement bonus")
			var point: Vector2 = s._center(Vector2i(j % s.COLS, j / s.COLS))
			if point.distance_to(s.HOME) > 100 and soil < 0: soil = j
		else: check(speeds[j] == 1, "Other ground has neutral movement")
		if shade[j] and shaded < 0: shaded = j
		if not shade[j] and sunny < 0: sunny = j
		if ground[j] == 2: litter += 1
		if ground[j] == 3: damp += 1
	check(soil >= 0 and shaded >= 0 and sunny >= 0 and litter > 0 and damp > 0, "Map contains all promised ground and shade")
	# Actual per-ant displacement in both kernels, for each colony and cargo state.
	for native in [false, true]:
		for colony in 3:
			for loaded in [0, 1]:
				s.reset_colony(81923)
				s.native_enabled = native
				s.reproduction_enabled = false
				s.invasions_enabled = false
				s.food_cycles_enabled = false
				s.rival_ai_enabled = false
				s.combat_enabled = false
				s.doctrines.fill(0)
				s.foods.clear()
				s.health.fill(0)
				var i: int = colony * s.COUNT
				var point: Vector2 = s._center(Vector2i(soil % s.COLS, soil / s.COLS))
				s.health[i] = 3
				s.positions[i] = point
				s.carrying[i] = loaded
				s.simulate(s.STEP)
				var expected: float = (43 if loaded else 52) * 1.15 * s.STEP
				check(absf(s.positions[i].distance_to(point) - expected) < 0.0002, "Soil changes actual movement for each colony/cargo/kernel")
		# Identical starting scent, one shaded decay versus two sunny decays.
		s.reset_colony(81923)
		s.native_enabled = native
		s.reproduction_enabled = false
		s.invasions_enabled = false
		s.food_cycles_enabled = false
		s.rival_ai_enabled = false
		s.health.fill(0)
		s.active_scent = PackedInt32Array([shaded, sunny])
		s.scent_active[shaded] = 1
		s.scent_active[sunny] = 1
		# Packed arrays use value semantics: seed fields explicitly on the owner.
		for name in ["food_scent", "home_scent", "rival_food_scent", "rival_home_scent", "third_food_scent", "third_home_scent", "protein_scent", "rival_protein_scent", "third_protein_scent"]:
			var field: PackedFloat32Array = s.get(name)
			field[shaded] = 1
			field[sunny] = 1
			s.set(name, field)
		s.scent_clock = 0.15
		s.simulate(s.STEP)
		for name in ["food_scent", "home_scent", "rival_food_scent", "rival_home_scent", "third_food_scent", "third_home_scent", "protein_scent", "rival_protein_scent", "third_protein_scent"]:
			var field: PackedFloat32Array = s.get(name)
			check(absf(field[shaded] * field[shaded] - field[sunny]) < 0.000001, "Shade doubles half-life for all colony fields and both kernels")
	# Direct mission and combat movement use the same multiplier; tunnels do not.
	s.reset_colony(81923)
	var start: Vector2 = s._center(Vector2i(soil % s.COLS, soil / s.COLS))
	s.positions[0] = start
	s._move_surface_worker(0, start + Vector2(100, 0), s.STEP)
	check(absf(s.positions[0].distance_to(start) - 50 * 1.15 * s.STEP) < 0.0002, "Security and recovering ants use soil movement")
	check(s.ant_info(0).terrain.contains("soil"), "Inspector explains the current terrain")
	s.layers[0] = 0
	s.roles[0] = s.RETURNING
	check(s.ant_info(0).speed == 47 and s.ant_info(0).terrain == "Tunnel", "Underground speed ignores surface terrain")
	s.garden_effects_enabled = false
	s.garden.build(s)
	check(s.surface_speed.count(1.0) == s.CELLS and s.surface_shade.count(0) == s.CELLS, "Diagnostic neutral-ground control removes both effects")
	if failures == 0: print("PASS: seeded garden/RNG isolation, unchanged food, neutral decorative terrain, individual soil movement in both kernels, six shaded scent fields, security movement and underground isolation.")
	s.queue_free()
	quit(1 if failures else 0)
