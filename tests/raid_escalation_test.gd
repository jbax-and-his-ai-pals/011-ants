extends SceneTree
var failures := 0
var s
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func fresh(mode: int, native: bool = true) -> void:
	s.game_modes.start(mode, 81923)
	while s.colony_workers[1].size() < 80: s._spawn_worker(1)
	s.health.fill(0)
	for i in s.colony_workers[1].slice(0, 80):
		s.health[i] = 3; s.positions[i] = s.nest_position(1); s.roles[i] = s.FORAGER; s.layers[i] = -1
	s.health[0] = 3
	s.layers[0] = -1; s.roles[0] = s.WARDEN
	var toward: Vector2 = (s.nest_position(1) - s.HOME).normalized()
	s.positions[0] = s.HOME + toward * 180 + toward.orthogonal() * 110
	s.worker_order_goals[0] = s.positions[0]
	s.queen_health[2] = 0
	s.native_enabled = native
	s.reproduction_enabled = false
	s.food_cycles_enabled = false
	s.foods.clear()
	s.food_stores.fill(2000)
	s.elapsed = 300 if mode == 1 else 100
	s.next_raids[0] = INF
	s.rival_ai.think(); s.rival_ai.orders.allocate()
	s.scouting.reset()
func run() -> void:
	s = load("res://main.tscn").instantiate()
	root.add_child(s); s.set_process(false)
	for mode in [0, 1]:
		for native in [false, true]:
			fresh(mode, native)
			var ai = s.rival_ai
			check(ai.raid_phase == "probe" and ai.mode == "Probing", "First automatic attack is a probe in both modes and kernels")
			check(ai.raid_size >= 2 and ai.raid_size <= 6 and ai.raid_roster.size() == ai.raid_size and ai.raid_budget == ai.raid_size, "Probe uses a small fixed party without a replacement wave")
			check(ai.raid_goal.distance_to(s.HOME) > 90, "Probe holds outside the entrance")
			var size: int = ai.raid_size
			var roster: Dictionary = ai.raid_roster.duplicate()
			var warning_time := -1.0
			var completed := -1.0
			var entered := false
			for tick in 3600:
				s.simulate(s.STEP)
				for slot in roster.values():
					if s.layers[slot] == 0: entered = true
				if warning_time < 0 and s.scouting.warnings.has(1): warning_time = s.elapsed
				if ai.escalation.get(0, {}).get("completed", false): completed = s.elapsed; break
			check(completed > 0 and not entered and s.queen_health[0] == 100, "Actual probe walks to the approach, holds and withdraws without entering or damaging the queen")
			check(warning_time > 0 and warning_time < completed, "Real scout warning precedes probe completion")
			check(ai.raid_roster.size() <= size, "Live probe never recruits replacements")
			var returning := 0
			for slot in roster.values():
				if s.health[slot] > 0 and s.roles[slot] == s.RETURNING: returning += 1
			check(returning > 0, "Probe survivors physically return home instead of resuming harassment")
			var earliest: float = ai.next_attack
			check(earliest >= completed + ai.ESCALATION_GAP - .1, "Probe creates at least 45 simulated seconds of response time")
			while s.elapsed < earliest - 1: s.simulate(s.STEP)
			check(ai.raid_until == 0, "No full invasion starts during the response interval")
			for tick in 300:
				s.simulate(s.STEP)
				if ai.raid_until > 0: break
			check(ai.raid_phase == "invasion" and ai.raid_started >= earliest and ai.raid_size > size and ai.raid_budget == ai.raid_size * 2, "Only a later re-evaluated attack becomes a larger bounded invasion")
			check(not ai.escalation.has(0), "Starting an invasion consumes the target-specific probe")
			print("ESCALATION mode=%d native=%s warning=%.1f probe_done=%.1f full_start=%.1f probe_size=%d full_size=%d" % [mode, native, warning_time, completed, ai.raid_started, size, ai.raid_size])
	# Failed probes do not unlock a full attack or drain an endless recruit stream.
	fresh(0)
	var ai = s.rival_ai
	for slot in ai.raid_roster.values(): s.health[slot] = 0
	ai.think(); ai.orders.allocate()
	check(ai.raid_until == 0 and not ai.escalation.has(0) and ai.next_attack >= s.elapsed + ai.PROBE_RETRY, "A repelled probe withdraws and waits longer before retrying")
	# Two repelled probes can justify a delayed decisive attack, preventing a
	# tiny remnant from permanently blocking a much stronger colony's endgame.
	s.elapsed = ai.next_attack
	ai.think(); ai.orders.allocate()
	check(ai.raid_phase == "probe", "One failed probe does not skip the small retry")
	for slot in ai.raid_roster.values(): s.health[slot] = 0
	ai.think(); ai.orders.allocate()
	check(ai.escalation.get(0, {}).get("repelled_twice", false), "Repeated probe failures are remembered for the actual target")
	var retry: float = ai.next_attack
	s.elapsed = retry - 1; ai.think()
	check(ai.raid_until == 0, "Repeated failures still preserve the longer response interval")
	s.elapsed = retry; ai.think(); ai.orders.allocate()
	check(ai.raid_phase == "invasion" and ai.raid_until > 0, "A clearly stronger colony may escalate after two failures and the full delay")
	# A comparable opponent does not justify escalating merely because probes failed.
	fresh(0)
	ai.end_raid("Probe repelled"); ai.orders.allocate()
	for i in range(80):
		s.health[i] = 3; s.positions[i] = s.HOME; s.layers[i] = -1; s.roles[i] = s.FORAGER
	ai.escalation[0] = {"completed": false, "repelled_twice": true, "ready_at": 0.0, "seen": s.elapsed}
	ai.next_attack = s.elapsed
	ai.think(); ai.orders.allocate()
	check(ai.raid_phase == "probe", "Failed probes alone do not justify a full invasion of a comparable colony")
	fresh(0)
	for slot in ai.raid_roster.values(): s.positions[slot] = ai.raid_goal
	ai.inspect_raid()
	s.elapsed += 4
	for slot in ai.raid_roster.values(): s.positions[slot] = s.nest_position(1)
	ai.inspect_raid()
	s.elapsed += 8; ai.think()
	check(ai.probe_arrived_at < 0 and not ai.escalation.has(0), "Leaving the approach resets the hold observation rather than silently qualifying an invasion")
	fresh(0)
	s.queen_health[1] = 0
	ai.update()
	check(ai.raid_until == 0 and ai.orders.markers.is_empty(), "A dead home queen ends and withdraws its probe")
	# Completion is per rival, and stale reconnaissance cannot qualify a new campaign.
	fresh(0)
	ai.end_raid("Probe complete"); ai.orders.allocate()
	check(ai.escalation.has(0) and not ai.escalation.has(2), "Probe qualification belongs to its actual target")
	s.elapsed += ai.PROBE_MEMORY + 1
	ai.next_attack = 0
	ai.think(); ai.orders.allocate()
	check(ai.raid_phase == "probe", "Expired probe knowledge requires another small attack")
	fresh(0)
	s.food_stores[1] = 1
	ai.think(); ai.orders.allocate()
	check(ai.raid_until == 0 and not ai.escalation.has(0), "A food emergency aborts a probe without authorizing escalation")
	fresh(0)
	s.layers[0] = 1; s.positions[0] = s.queen_position(1)
	ai.think(); ai.orders.allocate()
	check(ai.raid_until == 0 and not ai.escalation.has(0), "A home queen emergency recalls the small party")
	# Manual player Raid orders continue directly to the chosen nest.
	s.game_modes.start(1, 81923)
	check(s.place_surface_order(s.command_system.RAID, s.nest_position(1)), "Player can issue a direct early raid")
	var manual := -1
	for i in s.colony_workers[0]:
		if s.roles[i] == s.INVADER: manual = i; break
	check(manual >= 0 and s.worker_order_goals[manual] == s.nest_position(1), "Player orders do not receive an automatic probe stage")
	s.game_modes.start(0, 404)
	check(s.rival_ai.escalation.is_empty() and s.rival_ai.phase_counts.probes == 0, "New match clears all escalation state")
	if failures == 0: print("PASS: physical probes, actual scouting lead time, surface holds and withdrawal, response intervals, bounded larger invasions, repelled/stale/target-specific reconnaissance, emergencies, manual orders and reset in both modes/kernels.")
	s.queue_free(); quit(1 if failures else 0)
