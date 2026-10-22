extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)

func run() -> void:
	var s = load("res://main.tscn").instantiate()
	s.chambers_enabled = false # Isolate the pre-chamber nutrient/combat fixture; physical logistics has its own suite.
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(81923)
	for patch in s.foods: patch.amount = 0
	var initial: int = s.foods.size()
	var rng_state: int = s.ant_rng[0].state
	s.elapsed = 89.9
	s.food_cycle.tick()
	check(s.foods.size() == initial, "No unannounced food or early forecast")
	s.elapsed = 90
	s.food_cycle.tick()
	check(s.food_cycle.pending.size() == 3, "Three public sites get 30 seconds of warning")
	var site: int = s.food_cycle.pending[0]
	check(s.foods[site].amount == 0 and s.foods[site].arrival == 120, "Forecast contains no collectible food")
	var first_positions: Array = s.food_cycle.sites.duplicate()
	s.command_system.issue(1, s.foods[site].pos)
	check(s.command_system.markers[0].status == "Food in 30s" and s.command_system.markers[0].assigned > 0, "Forage can prepare at a forecast site")
	for ai in [s.rival_ai, s.third_ai]:
		ai.think()
		check(ai.known.has(site), "Every rival receives the same public forecast")
	s.elapsed = 119.99
	s.food_cycle.tick()
	check(s.foods[site].amount == 0, "Food does not appear early")
	s.elapsed = 120
	s.food_cycle.tick()
	check(s.foods[site].amount == 6000 and s.food_cycle.added == 18000, "Arrival banks exactly three supplies into world patches")
	s.foods[site].amount = 1200
	for wave_time in [210, 240, 330, 360]:
		s.elapsed = wave_time
		s.food_cycle.tick()
	check(s.foods.size() == initial + 6 and s.foods[site].amount == 6000, "Subsequent waves reuse six slots and replenish consumed food")
	check(s.ant_rng[0].state == rng_state, "Forecasts and AI preparation do not consume worker RNG")
	s.reset_colony(81923)
	check(s.food_cycle.wave == 0 and s.food_cycle.pending.is_empty() and s.food_cycle.sites == first_positions, "Reset clears events and repeats seeded positions")
	# Exercise actual pickup and bank paths in each kernel, including reassignment.
	for native in [false, true]:
		s.reset_colony(81923)
		s.native_enabled = native
		s.food_cycles_enabled = false
		s.reproduction_enabled = false
		s.invasions_enabled = false
		s.combat_enabled = false
		s.rival_ai_enabled = false
		s.health.fill(0)
		s.health[0] = 3
		for i in range(1, 4): s.health[i] = 3
		s.roles[0] = s.FORAGER
		s.positions[0] = s.HOME + Vector2(200, 0)
		s.foods = [{"pos": s.positions[0], "amount": 1}]
		s.food_index_size = -1
		s.command_system.issue(1, s.positions[0])
		var original: int = s.command_system.markers[0].id
		s.simulate(s.STEP)
		check(s.carrying[0] == 1 and s.foods[0].amount == 0 and s.delivered == 0, "Pickup depletes food without counting a delivery native=%s" % native)
		s.worker_order_ids[0] = -1
		s.worker_order_kinds[0] = 0
		s.positions[0] = s.HOME
		s.simulate(s.STEP)
		check(s.delivered == 1 and s.command_system.order_delivered.get(original, 0) == 1, "Actual home bank credits pickup order after reassignment native=%s" % native)
		check(s.command_system.cargo_orders.is_empty(), "Delivery clears cargo attribution")
		s.worker_order_ids[0] = original
		s.worker_order_kinds[0] = 1
		s.command_system.record_loss(0, false)
		s.command_system.record_loss(0, true)
		s.command_system.sample()
		check(s.command_system.markers[0].recent_losses == [1, 1], "Order distinguishes combat and hunger losses")
		s.elapsed += 31
		s.command_system.sample()
		check(s.command_system.markers[0].recent_losses == [0, 0], "Order loss window expires in simulation time")
		s.command_system.record_pickup(0)
		s.command_system.remove(original)
		s.command_system.record_delivery(0)
		check(s.command_system.order_delivered.is_empty(), "A cancelled order is not recreated by a late carrier")
	s.toggle_order_panel()
	check(s.order_panel.visible, "Orders panel opens")
	s.toggle_labor_panel()
	check(not s.order_panel.visible and s.labor_panel.visible, "Priorities and order panels do not overlap")
	if failures == 0: print("PASS: public food forecasts, bounded replenishment, AI knowledge, real native/reference pickup attribution, rolling order losses and panel controls.")
	s.queue_free()
	quit(1 if failures else 0)
