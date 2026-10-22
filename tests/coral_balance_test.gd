extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	s.colony_count = 2
	root.add_child(s)
	s.set_process(false)
	for native in [false, true]:
		for role in [s.FORAGER, s.DIGGER, s.INVADER, s.GUARD, s.WARDEN, s.RETURNING]:
			s.reset_colony(81923)
			s.native_enabled = native
			s.reproduction_enabled = false
			s.invasions_enabled = false
			s.doctrines.fill(0)
			s.doctrines[0] = 2
			s.health.fill(0)
			s.health[0] = 3
			s.health[s.COUNT] = 3
			s.roles[0] = role
			s.positions[0] = Vector2(500, 500)
			s.worker_order_goals[0] = s.positions[0]
			s.positions[s.COUNT] = Vector2(532, 500)
			s.attack_cooldowns.fill(0)
			s._prepare_encounters(0)
			var specialist: bool = role in [s.INVADER, s.GUARD, s.WARDEN]
			check((s.opponents[0] == s.COUNT) == specialist, "Only Raider security roles pursue at 32px role=%d native=%s" % [role, native])
			s.positions[s.COUNT] = Vector2(510, 500)
			var preview := RandomNumberGenerator.new()
			preview.seed = s.ant_rng[0].seed
			preview.state = s.ant_rng[0].state
			var expected: float = preview.randf_range(0.85, 1.15) * (1.05 if specialist else 1)
			s.simulate(s.STEP)
			check(absf((3 - s.health[s.COUNT]) - expected) < 0.00001, "Actual damage matches role-specific bonus role=%d native=%s" % [role, native])
			check(s.ant_info(0).bite == (1.05 if specialist else 1.0), "Inspector reports actual role bonus")
	s.reset_colony(81923)
	# This fixture tests score ties, not differing garden travel times.
	s.surface_speed.fill(1.0); s.strategic_garden.cache.clear()
	for i in s.health.size(): s.positions[i] = s.nest_for(i)
	var nest: Vector2 = s.nest_position(1)
	s.foods = [{"pos": nest + Vector2(180, 0), "amount": 4000}, {"pos": nest + Vector2(-180, 0), "amount": 4000}, {"pos": nest + Vector2(0, 180), "amount": 4000}]
	s.rival_ai.think()
	s.rival_ai.orders.allocate()
	check(s.rival_ai.selected.size() == 3, "Three near-equivalent supplies can all receive guided workers")
	var guided := 0
	for marker in s.rival_ai.orders.markers:
		if marker.kind == s.command_system.FORAGE: guided += marker.assigned
	check(guided == 500, "Using a third route preserves the normal 25% labor budget")
	s.foods[2].amount = 1
	s.rival_ai.think()
	check(s.rival_ai.selected.size() == 2 and 2 not in s.rival_ai.selected, "A distinctly worse third source is not recruited")
	# Seat choice uses an independent map RNG. It is reproducible and gives
	# every color access to every vertex across seeds, without touching ants.
	s.colony_count = 3
	s.fixed_starting_seats = false
	s.swapped_sides = false
	var examples := {}
	var state: int = s.ant_rng[0].state
	for seed_value in range(1, 65):
		s.world_seed = seed_value
		preload("res://scripts/colony_map.gd").configure_nests(s)
		var offset: int = s.starting_seat_offset
		examples[offset] = seed_value
		preload("res://scripts/colony_map.gd").configure_nests(s)
		check(s.starting_seat_offset == offset, "Map seed replays its starting seats")
	check(examples.size() == 3 and s.ant_rng[0].state == state, "All three seats occur and map setup preserves worker RNG")
	for seed_value in examples.values():
		s.reset_colony(seed_value)
		for c in 3:
			check(not s.tunnel_route(s.entrance_cell(c), s._cell(s.queen_position(c)), c).is_empty(), "Every seeded colony has a connected private tunnel")
			for k in 10:
				var worker: int = s.colony_workers[c][k]
				check(s.positions[worker].distance_to(s.nest_position(c)) <= 24.01, "Seeded worker spawns at its actual nest")
	if failures == 0: print("PASS: Raider combat-role damage/pursuit in both kernels, truthful inspector, three comparable food routes and unchanged labor budgets.")
	quit(1 if failures else 0)
