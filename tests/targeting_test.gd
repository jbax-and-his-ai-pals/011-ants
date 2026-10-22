extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	var ai = s.third_ai
	var population := PackedInt32Array([2000, 2000, 2000])
	var grids: Array = [{}, {}, {}]
	var none := PackedFloat32Array([0, 0, 0])
	var choices := [0, 0, 0]
	for seed_value in range(1, 49):
		s.world_seed = seed_value
		ai.reset()
		var worker_state: int = s.ant_rng[0].state
		ai.choose_target(population, grids, none)
		choices[ai.enemy_id] += 1
		check(s.ant_rng[0].state == worker_state, "Strategy preserves individual worker RNG")
		var first: int = ai.enemy_id
		ai.reset()
		ai.choose_target(population, grids, none)
		check(ai.enemy_id == first, "Seeded target choice replays exactly")
	check(choices[0] > 10 and choices[1] > 10, "Symmetric lower nest can choose either opponent across seeds")
	var upper_choices := [0, 0, 0]
	for seed_value in range(1, 49):
		s.world_seed = seed_value
		s.rival_ai.reset()
		s.rival_ai.choose_target(population, grids, none)
		upper_choices[s.rival_ai.enemy_id] += 1
	check(upper_choices[0] > 10 and upper_choices[2] > 10, "Upper nest can choose the farther opponent instead of always targeting the lower nest")
	# Remote hostiles cannot influence a remembered route that is no longer seen.
	s.reset_colony(42)
	ai.known[0] = {"pos": Vector2(800, 800), "seen": 0.0}
	ai.selected.assign([0])
	grids[1][ai.cell(Vector2(800, 800))] = 24
	ai.choose_target(population, grids, none)
	check(ai.enemy_id == 1 and ai.target_scores[0].food == 0.6, "Observed route competition favors the responsible colony")
	s.elapsed = 4
	ai.choose_target(population, grids, none)
	for entry in ai.target_scores: check(entry.food == 0, "Unobserved remote counts do not influence food target pressure")
	grids[1].clear()
	s.reset_colony(81923)
	ai.choose_target(population, grids, none)
	var original: int = ai.enemy_id
	var challenger := 1 - original
	var pressure := none.duplicate()
	pressure[challenger] = 1
	s.elapsed = 10
	ai.choose_target(population, grids, pressure)
	check(ai.enemy_id == original, "Commitment prevents rapid target oscillation")
	s.elapsed = 31
	ai.choose_target(population, grids, pressure)
	check(ai.enemy_id == challenger and ai.target_reason.begins_with("Switched"), "Significant home pressure changes the target after commitment")
	check(ai.target_explanation().contains("threat 1.20"), "UI explains candidate score components")
	ai.raid_until = 100
	s.elapsed = 65
	pressure.fill(0)
	pressure[original] = 1
	ai.choose_target(population, grids, pressure)
	check(ai.enemy_id == challenger, "An active raid retains its living target")
	s.queen_health[challenger] = 0
	ai.choose_target(population, grids, pressure)
	check(ai.enemy_id == original and ai.raid_until == 0 and ai.next_attack > s.elapsed, "Eliminated target releases raid and enforces ordinary cooldown")
	s.reset_colony(42)
	check(ai.enemy_id == -1 and ai.target_scores.is_empty() and ai.threat_memory == none, "New game clears target history")
	# Actual strategy census identifies tunnel attackers separately by colony.
	for i in s.health.size(): s.positions[i] = s.nest_for(i)
	s.layers[0] = 2
	s.positions[0] = s.queen_position(2)
	ai.think()
	check(ai.mode == "Defending" and ai.threat_memory[0] >= 0.25 and ai.threat_memory[1] == 0, "Tunnel pressure is attributed to the invading colony")
	s.inspected_ai = 2
	s.toggle_rival_plan()
	s._update_ui()
	check(s.rival_plan_text.text.contains("Target:") and s.rival_plan_text.text.contains("travel"), "Strategy panel exposes the chosen target and both score breakdowns")
	if failures == 0: print("PASS: seeded target fairness, RNG independence, commitment, threat response, raid stability, elimination, reset and explanations.")
	quit(1 if failures else 0)
