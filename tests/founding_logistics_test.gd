extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.game_modes.start(1, 81923)
	var signatures := {}
	for c in 3:
		var offset: Array = []
		for k in 3:
			var food: Dictionary = s.foods[c * 3 + k]
			check(food.pos.distance_to(s.nest_position(c)) >= 79 and food.pos.distance_to(s.nest_position(c)) <= 126, "Every founding nest has reachable local supplies")
			check(food.amount >= [160, 110, 220][k] and food.amount <= [220, 170, 300][k] and food.resource == (1 if k == 2 else 0), "Seeded variety preserves guaranteed sugar and protein ranges")
			offset.append([food.pos - s.nest_position(c), food.amount])
		signatures[var_to_str(offset)] = true
	check(signatures.size() == 3, "Starting areas have distinct local positions and quantities")
	var before := var_to_bytes([s.game_modes.home_sites, s.game_modes.local_amounts])
	var rng_state: int = s.ant_rng[0].state
	var target_state: int = s.rival_ai.target_rng.state
	s.game_modes.prepare_sites()
	check(before == var_to_bytes([s.game_modes.home_sites, s.game_modes.local_amounts]), "Local variety is reproducible from the world seed")
	check(s.ant_rng[0].state == rng_state and s.rival_ai.target_rng.state == target_state, "Local scenery/resource randomness does not consume worker or AI RNG")
	s._spawn_worker(0)
	s.chambers.allocate_nurses()
	check(s.chambers.nurse_workers[0].size() == 2, "Founding nursing grows with the young workforce")
	# A ready larva far from storage must beat empty nearby brood tiles.
	var hungry: int = s.chambers.brood_cells[0][-1]
	for j in s.chambers.brood_cells[0]: s.brood_buffers[j] = 0
	s.chambers.buffered[0] = 0
	s.brood[0] = [{"cell": hungry, "stage": 0, "age": 100.0}]
	var worker: int = s.chambers.nurse_workers[0][0]
	s.layers[worker] = 0
	var storage: int = s.chambers.storage_cells[0][0]
	s.positions[worker] = s._center(Vector2i(storage % s.COLS, storage / s.COLS))
	s.chambers.prepare_reference()
	s.chambers.nurse(worker, s.STEP)
	check(s.nurse_targets[worker] == hungry and s.nurse_load[worker] > 0, "A ready hungry brood receives priority over empty brood tiles")
	var protein: float = s.protein_stores[0]
	for tick in 600:
		s.chambers.nurse(worker, s.STEP)
		if s.brood_buffers[hungry] >= 3: break
	check(s.brood_buffers[hungry] >= 3 and s.protein_stores[0] == protein, "Nurse physically delivers the banked protein without creating or spending it")
	check(s.chambers.feed(0, s.brood[0][0], 3), "Delivered protein unblocks the actual local brood meal")
	s.game_modes.start(1, 81923)
	check(s.rival_ai.nest.defense_marker(false).is_empty(), "Small unthreatened founding crews do not waste workers on a standing garrison")
	check(not s.rival_ai.nest.defense_marker(true).is_empty(), "Small colonies can still defend a real nest invasion")
	# Explicit player orders remain stronger than autonomous local guidance.
	s.command_system.issue(s.command_system.FORAGE, s.foods[0].pos)
	var assigned := -1
	for i in s.colony_workers[0]:
		if s.worker_order_ids[i] >= 0: assigned = i; break
	var identity: int = s.worker_order_ids[assigned]
	var goal: Vector2 = s.worker_order_goals[assigned]
	s.game_modes.allocate_local_foragers()
	check(s.worker_order_ids[assigned] == identity and s.worker_order_goals[assigned] == goal, "Founding autonomy never overrides explicit player orders")
	var autonomous := 0
	var scouts := 0
	for i in s.colony_workers[0]:
		if s.worker_order_ids[i] == -2:
			autonomous += 1
			check(s.worker_order_goals[i].distance_to(s.HOME) < 130 and s.roles[i] == s.FORAGER, "Autonomous guidance uses real local foragers and real source positions")
		if s.worker_ids[i] % 7 == 0 and s.worker_order_ids[i] < 0: scouts += 1
	check(autonomous > 0 and scouts > 0, "Founding keeps both local collectors and individual scouts")
	for n in 48: s._spawn_worker(0)
	s.elapsed = 500
	s.game_modes.allocate_local_foragers()
	check(not -2 in s.worker_order_ids.slice(0, 12), "A mature colony releases its temporary local guidance")
	s.game_modes.start(1, 81923)
	for wave in 4:
		s.elapsed = (wave + 1) * 120 - 30
		s.food_cycle.tick()
		check(s.food_cycle.pending.size() == (3 if wave < 3 else 6), "Local support persists alongside later shared food")
		if wave == 0:
			for index in s.food_cycle.pending: check(s.foods[index].resource == 1, "The first replenishment provides brood protein")
		s.elapsed += 30
		s.food_cycle.tick()
	s.game_modes.start(0, 81923)
	s._spawn_worker(0)
	s.chambers.allocate_nurses()
	check(s.chambers.nurse_workers[0].size() == 6, "Skirmish retains its original nursing cap and allocation")
	if failures == 0: print("PASS: seeded local variety and guaranteed resources, independent RNG, founding nurse scaling and hungry-room priority, real delivery, economical guard policy, autonomous local foragers, scouts, player orders and persistent local protein waves.")
	s.queue_free()
	quit(1 if failures else 0)
