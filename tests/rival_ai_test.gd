extends SceneTree
var failures := 0
var s
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)
func fresh() -> void:
	s.reset_colony(81923)
	s.reproduction_enabled = false
	s.invasions_enabled = true
	s.rival_ai_enabled = true
	for i in s.starting_total(): s.positions[i] = s.nest_for(i)
	s.rival_ai.escalation[0] = {"completed": true, "ready_at": 0.0, "seen": 0.0}
	s.foods = [{"pos": s.nest_position(1) + Vector2(-140, 0), "amount": 1200}, {"pos": s.nest_position(1) + Vector2(0, 160), "amount": 1800}, {"pos": Vector2(80, 80), "amount": 20000}]
func decide() -> void:
	s.rival_ai.think()
	s.rival_ai.orders.allocate()
func has_kind(kind: int) -> bool:
	for order in s.rival_ai.orders.markers:
		if order.kind == kind: return true
	return false
func _run() -> void:
	s = load("res://main.tscn").instantiate()
	s.colony_count = 2
	root.add_child(s)
	s.set_process(false)
	fresh()
	var ai = s.rival_ai
	decide()
	check(ai.known.size() == 2 and not ai.known.has(2), "Rival learns nearby food without seeing remote food")
	check(ai.selected[0] == 1 and ai.mode == "Gathering", "Distance and quantity select worthwhile food")
	check(s.worker_order_kinds[s.COUNT] == 1 and s.worker_order_ids[0] == -1, "Rival assigns its workers without touching player orders")
	s.place_surface_order(2, s.HOME + Vector2(250, 200))
	var player_ids: PackedInt32Array = s.worker_order_ids.slice(0, s.COUNT)
	decide()
	check(player_ids == s.worker_order_ids.slice(0, s.COUNT), "Overlapping marker IDs cannot release player workers")
	s.foods[1].amount = 0
	decide()
	check(not ai.known.has(1) and ai.selected == [0], "Observed depletion removes the source and retargets foragers")
	s.positions[s.COUNT + 100] = Vector2(80, 80)
	decide()
	check(ai.known.has(2), "A scout discovers remote food for its colony")
	fresh()
	s.foods.clear()
	for i in 180: s.foods.append({"pos": s.nest_position(1) + Vector2(i % 10, 0), "amount": i + 1})
	for pass_index in 5: decide()
	check(ai.known.size() == ai.MAX_SITES and ai.patch_cursor == 5 * ai.PATCH_BUDGET, "Discovery rotates and strategic memory stays bounded with many cargo piles")
	# Protect a contested site away from the home-defense radius.
	fresh()
	s.foods[0].pos = s.nest_position(1) + Vector2(-400, 0)
	s.foods[0].amount = 6000
	for i in 200: s.positions[s.COUNT + i] = s.foods[0].pos
	for i in 30: s.positions[i] = s.foods[0].pos + Vector2(-50, 0)
	s.carrying[s.COUNT] = 1
	decide()
	check(ai.mode == "Contesting" and has_kind(2), "Contested chosen food gets a guard post")
	check(s.roles[s.COUNT] == s.FORAGER and s.carrying[s.COUNT] == 1, "Rival security leaves loaded carriers delivering")
	var guards := 0
	for i in s.colony_workers[1]:
		if s.roles[i] == s.WARDEN: guards += 1
	check(guards == 18, "Guard labor recruits 12 contested-food guards plus six real corridor guards")
	# Guard pursuit leash applies equally to both colonies in both kernels.
	for native in [true, false]:
		s.native_enabled = native
		s.health.fill(0)
		s.health[s.COUNT + 1] = 3
		s.health[0] = 3
		s.roles[s.COUNT + 1] = s.WARDEN
		s.worker_order_goals[s.COUNT + 1] = Vector2(1600, 800)
		s.positions[s.COUNT + 1] = Vector2(1700, 800)
		s.positions[0] = Vector2(1725, 800)
		s._prepare_encounters(s.STEP)
		check(s.opponents[s.COUNT + 1] == -1, "Rival guard does not chase beyond post native=%s" % native)
	fresh()
	s.elapsed = 100
	s.food_stores[1] = 2000
	decide()
	check(ai.mode == "Raiding" and has_kind(4), "Healthy colony with reserves starts a timed raid")
	var deadline: float = ai.raid_until
	var raider := -1
	for i in s.colony_workers[1]:
		if s.roles[i] == s.INVADER: raider = i; break
	check(raider >= 0, "Raid assigns individual rival invaders")
	s.positions[raider] = s.nest_position(0)
	s._surface_mission(raider, s.STEP)
	check(s.layers[raider] == 0, "Rival marked raiders use the player entrance, not their own")
	s.food_stores[1] = 5
	s.elapsed += 4
	decide()
	check(ai.mode == "Recovering" and not has_kind(4) and ai.orders.labor[0] == 3, "Food emergency cancels raids and increases forage labor")
	check(s.roles[raider] == s.RETURNING and s.layers[raider] == 0, "Recalled underground rival raider returns through tunnels")
	s.food_stores[1] = s.upkeep_rate(1) * 50
	decide()
	check(ai.recovering, "Reserve hysteresis prevents oscillation at the recovery threshold")
	s.food_stores[1] = 2000
	decide()
	check(not ai.recovering and not has_kind(4) and ai.next_attack > s.elapsed, "Recovery exits with a raid cooldown")
	# A fresh wave ends on time or heavy losses; it cannot trickle forever.
	s.elapsed = ai.next_attack
	decide()
	check(has_kind(4), "A later healthy colony may retry its raid")
	s.casualties[1] += 8
	decide()
	check(has_kind(4), "Unrelated colony losses do not recall a committed raid")
	# Actual party casualties, identified by persistent worker IDs, drive recall.
	for identity in ai.raid_roster:
		var slot: int = ai.raid_roster[identity]
		s.health[slot] = 0
	decide()
	for identity in ai.raid_roster:
		var slot: int = ai.raid_roster[identity]
		s.health[slot] = 0
	decide()
	check(not has_kind(4) and ai.next_attack > s.elapsed, "Actual raid-party attrition recalls survivors and enforces a cooldown")
	fresh()
	s.elapsed = 100
	s.food_stores[1] = 2000
	decide()
	s.elapsed = ai.raid_until + 0.1
	decide()
	check(not has_kind(4), "Raid duration is bounded")
	fresh()
	s.elapsed = 100
	s.food_stores[1] = 2000
	for i in 12: s.positions[i] = s.nest_position(1) + Vector2(100, 0)
	decide()
	check(ai.mode == "Defending" and has_kind(2) and not has_kind(4) and ai.orders.labor[1] == 3, "Home threat overrides offensive plans and increases security")
	fresh()
	s.layers[0] = 1
	s.roles[0] = s.INVADER
	s.positions[0] = s.queen_position(1)
	decide()
	check(ai.mode == "Defending", "Tunnel invasion triggers defense without surface enemies")
	fresh()
	for i in 100:
		s.health[s.COUNT + i] = 0
		s._kill_ant(s.COUNT + i)
	decide()
	check(ai.recovering and ai.orders.report.combat == 100, "Recent rival losses inform recovery")
	# Strategic scheduling freezes with simulation; reset clears memory and orders.
	fresh()
	s.paused = true
	var before: int = ai.decisions
	s._process(0.5)
	check(ai.decisions == before, "Paused game does not advance strategy")
	s.match_result = "defeat"
	ai.update()
	check(ai.decisions == before, "Finished game does not advance strategy")
	s.reset_colony(42)
	check(ai.known.is_empty() and ai.orders.markers.is_empty() and ai.decisions == 0, "New match resets rival strategy")
	await process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_I
	event.pressed = true
	root.push_input(event, true)
	check(s.rival_panel.visible, "I exposes the live rival strategy panel")
	if failures == 0: print("PASS: rival scout knowledge, food ranking/depletion, independent orders, contested guards, cargo, pursuit leashes, adaptive raids, recovery/hysteresis, home defense, losses, pause/reset and UI.")
	quit(1 if failures else 0)
