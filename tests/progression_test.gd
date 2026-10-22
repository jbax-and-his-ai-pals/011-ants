extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; push_error(text)
func make_sim(native: bool = true):
	var s = load("res://main.tscn").instantiate()
	root.add_child(s); s.set_process(false); s.native_enabled = native
	s.game_modes.start(1, 81923)
	return s
func prepare(s) -> void:
	while s.living_count(0) < 100: s._spawn_worker(0)
	s.food_stores[0] = 2000; s.protein_stores[0] = 1000
	# A provisioned connected nursery isolates transport/development tests.
	var base: Vector2i = s.chamber_cell(0)
	for x in range(2, 8):
		var j: int = s._idx(base + Vector2i(x, 0))
		s.earth[j] = 1; s.chamber_rooms[j] = s.chambers.BROOD; s.chambers.room_tiles[0][j] = s.chambers.BROOD
	s.chambers.dirty = true; s.chambers.rebuild()
	s.next_raids.fill(INF); s.rival_ai_enabled = false
func run() -> void:
	var s = make_sim()
	check(not s.progression.choose(0, 1), "Founders cannot buy a specialization before 40 workers")
	prepare(s)
	var sugar: float = s.food_stores[0]; var protein: float = s.protein_stores[0]
	var key := InputEventKey.new(); key.keycode = KEY_P; key.pressed = true
	s._input(key)
	check(s.progression.panel.visible, "P opens Founding development")
	check(s.progression.details.global_position == s.progression.panel.global_position + s.progression.details.position, "Development content is positioned inside its panel")
	s.progression.forage_button.pressed.emit()
	check(s.progression.paths[0] == 1, "The actual specialization button purchases Foraging")
	s.scouting.toggle()
	check(not s.progression.panel.visible, "Scouting closes the development overlay")
	s.scouting.panel.visible = false
	check(s.food_stores[0] == sugar - 40 and s.protein_stores[0] == protein - 12, "Specialization charges the banks once")
	check(not s.progression.choose(0, 2) and s.foraging_multipliers[0] == 1.15, "Choice is exclusive and retained for this match")
	print("QUEEN READINESS ", s.progression.queen_reason(0), " capacity=", s.brood_capacity, " cells=", s.chambers.brood_cells[0])
	if not s.progression.start_daughter(0): quit(1); return
	var royal: int = s.progression.occupied_cell(0)
	for n in 20: check(s.chambers.room_for_egg(0) != royal, "Daughter reserves her actual nursery tile")
	# Existing room buffer alone cannot complete the project; each installment
	# is transported by normal nurses in the full simulation below.
	var banked: float = s.protein_stores[0]
	s.brood_buffers[royal] = 0
	s.chambers.buffered[0] = 0
	for j in s.chambers.brood_cells[0]: s.brood_buffers[j] = 0
	s.progression.tick(8)
	check(s.progression.daughters[0].progress == 0 and s.protein_stores[0] == banked, "Banked protein cannot feed the daughter remotely")
	var delivery := false
	for tick in 16000:
		s.simulate(s.STEP)
		if s.progression.daughters[0].progress > 0: delivery = true
		if not s.match_result.is_empty(): break
	check(delivery and s.match_result == "victory", "Real nurse journeys feed and launch a daughter through full ticks")
	check(s.progression.daughters[0].progress == 240 and s.progression.daughters[0].complete, "Daughter needs all thirty paid installments")
	check(s.protein_stores[0] + 0.01 >= s.chambers.buffered[0] + s.chambers.reserved[0], "Royal and ordinary brood preserve protein allocation accounting")
	var before: float = s.elapsed; s.simulate(s.STEP)
	check(s.elapsed == before, "Daughter victory freezes the match")
	# Paid soldier development and per-worker reference equivalence.
	var reference = make_sim(false)
	s.game_modes.start(1, 81923)
	for sim in [s, reference]:
		prepare(sim); check(sim.progression.choose(0, 2), "Soldier development can be chosen")
	for tick in 4500:
		s.simulate(s.STEP); reference.simulate(reference.STEP)
	check(s.progression.soldier_counts[0] > 0, "New eggs mature into real soldiers, rather than converting existing workers")
	for field in ["castes", "max_health", "roles", "layers", "births", "brood", "resource_delivered", "brood_buffers", "nurse_load"]:
		check(s.get(field) == reference.get(field), "Soldier production native/reference agrees: " + field)
	var soldier := -1
	for i in s.health.size():
		check(s.positions[i].distance_to(reference.positions[i]) < 0.002 and s.ant_rng[i].state == reference.ant_rng[i].state, "Native/reference movement and RNG agree through caste births")
		if s.castes[i] and s.health[i] > 0: soldier = i
	check(soldier >= 0, "A soldier exists after paid brood development")
	if soldier >= 0:
		check(s.max_health[soldier] == 5 and s.ant_info(soldier).bite >= 1.5, "Soldier stats are inspectable")
		s.health[soldier] = 2; s.roles[soldier] = s.GUARD; s.layers[soldier] = -1; s.positions[soldier] = s.HOME
		s._recover_worker(soldier, 1)
		check(s.roles[soldier] == s.RECOVERING and s.health[soldier] > 2, "Wounded soldier retreats and heals toward its own maximum")
		for n in 10: s._recover_worker(soldier, 1)
		check(is_equal_approx(s.health[soldier], 5) and s.roles[soldier] == s.FORAGER, "Soldier recovery restores five HP and releases the job")
		var count: int = s.progression.soldier_counts[0]
		s.health[soldier] = 0; s._kill_ant(soldier)
		check(s.progression.soldier_counts[0] == count - 1, "Soldier losses remove their extra upkeep")
	# Foraging bonus matches both kernels with individual scent steering.
	for sim in [s, reference]:
		sim.game_modes.start(1, 81923); prepare(sim); sim.progression.choose(0, 1)
	for tick in 600: s.simulate(s.STEP); reference.simulate(reference.STEP)
	for i in s.health.size(): check(s.positions[i].distance_to(reference.positions[i]) < 0.002 and s.ant_rng[i].state == reference.ant_rng[i].state, "Foraging specialization preserves native/reference behavior")
	# Real contact combat uses the caste bite in both kernels, including deaths.
	for sim in [s, reference]:
		sim.game_modes.start(1, 81923); sim.reproduction_enabled = false; sim.rival_ai_enabled = false; sim.next_raids.fill(INF)
		sim.progression.born(0, 1)
		sim.positions[0] = Vector2(1600, 800); sim.positions[12] = Vector2(1608, 800)
		sim.roles[0] = sim.WARDEN; sim.worker_order_goals[0] = sim.positions[0]
		sim.roles[12] = sim.WARDEN; sim.worker_order_goals[12] = sim.positions[12]
		sim.attack_cooldowns[0] = 0; sim.attack_cooldowns[12] = 0
	for tick in 120: s.simulate(s.STEP); reference.simulate(reference.STEP)
	check(s.casualties == reference.casualties and s.casualties[1] > 0, "Soldier contact bite kills a real enemy in both kernels")
	check(s.ant_rng[0].state == reference.ant_rng[0].state and s.health[0] == reference.health[0], "Caste combat preserves simultaneous damage and individual RNG")
	# Rendering uses the same enlarged soldier transforms in both paths.
	s.batch_counts.fill(0)
	for b in 3: s.ant_buffers[b].resize(s.health.size() * 12)
	s._batch_ant(0)
	var visual: Dictionary = s.native_kernel.visual_batch(s, Rect2(s.positions[0] - Vector2.ONE, Vector2.ONE * 2), -1, 1.0)
	for j in 12: check(absf(visual.buffers[0][j] - s.ant_buffers[0][j]) < 0.002, "Soldier body transform matches native/reference drawing")
	# Readiness failures, real connected capacity and interruption.
	s.game_modes.start(1, 81923); prepare(s); s.progression.choose(0, 1)
	check(s.progression.start_daughter(0), "Second queen fixture starts")
	var d: Dictionary = s.progression.daughters[0]
	var idx: int = d.cell
	s.food_stores[0] = 0; s.progression.tick(30)
	check(d.progress == 0 and d.status.contains("sugar"), "Sugar shortage pauses without accumulating catch-up progress")
	s.food_stores[0] = 1000; s.chamber_rooms[idx] = 0; s.chambers.dirty = true; s.chambers.rebuild(); s.progression.tick(8)
	check(d.progress == 0 and d.status.contains("Reconnect"), "A disconnected/removed daughter room cannot progress")
	s.queen_health[1] = 0; s.queen_health[2] = 0; s._check_outcome()
	check(s.match_result.is_empty(), "Eliminating rivals alone is not a Founding victory")
	s.progression.daughters[1] = {"complete": true}; s.queen_health[1] = 100; s._check_outcome()
	check(s.match_result == "defeat", "A living rival launching first wins the race")
	s.game_modes.start(1, 81923); s.queen_health[0] = 0; s._check_outcome()
	check(s.match_result == "defeat", "Home queen death still loses")
	s.game_modes.start(0, 81923)
	check(not s.progression.choose(0, 1) and not s.progression.start_daughter(0) and not s.progression.button.visible, "Skirmish does not expose or enable progression")
	check(s.castes.count(1) == 0 and s.foraging_multipliers == PackedFloat64Array([1, 1, 1]), "Reset clears all caste and development state")
	s.queen_health[1] = 0; s.queen_health[2] = 0; s._check_outcome()
	check(s.match_result == "victory", "Skirmish retains queen elimination victory")
	s.queue_free(); reference.queue_free()
	if failures == 0: print("PASS: Founding development, paid real soldier brood, both-kernel movement/RNG, physical nurse-fed daughter launch, interruptions, rival race, reset and Skirmish outcome isolation.")
	quit(1 if failures else 0)
