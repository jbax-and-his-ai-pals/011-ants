extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func fresh(s, native: bool = true, count: int = 1) -> void:
	s.reset_colony(81923)
	s.native_enabled = native
	s.reproduction_enabled = false
	s.invasions_enabled = false
	s.rival_ai_enabled = false
	s.combat_enabled = false
	s.food_cycles_enabled = false
	s.foods.clear()
	s.health.fill(0)
	for i in count:
		s.health[i] = 3
		s.positions[i] = s.HOME
	s.chambers.prepare_reference()

func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	for native in [false, true]:
		for colony in 3:
			for resource in 2:
				fresh(s, native, 0)
				var i: int = colony * s.COUNT
				s.health[i] = 3
				s.positions[i] = s.nest_position(colony)
				s.carrying[i] = 1
				s.cargo_resource[i] = resource
				s.simulate(s.STEP)
				check(s.layers[i] == colony and s.deliveries[i] == 0, "Reaching the surface portal does not bank food")
				var walked := false
				for tick in 300:
					var before: Vector2 = s.positions[i]
					s.simulate(s.STEP)
					if s.positions[i].distance_to(before) > 0.1: walked = true
					if s.deliveries[i] == 1: break
				check(walked and s.deliveries[i] == 1 and s.layers[i] == colony, "Every colony walks its real load to storage in both kernels")
				check(s._idx(s._cell(s.positions[i])) in s.chambers.storage_cells[colony], "Delivery happens on a storage tile")
				check(s.food_stores[colony] == s.INITIAL_STORES + (1 if resource == 0 else 0) and s.protein_stores[colony] == s.INITIAL_PROTEIN + resource, "Storage preserves nutrient identity")
				for tick in 300:
					s.simulate(s.STEP)
					if s.layers[i] == s.SURFACE: break
				check(s.layers[i] == s.SURFACE, "An empty courier physically exits after delivery")
		fresh(s, native)
		s.carrying[0] = 1
		s.storage_capacity[0] = int(s.food_stores[0] + s.protein_stores[0])
		check(s.nutrition.status(0).contains("Storage full"), "Full storage has a clear player-facing explanation")
		for tick in 60: s.simulate(s.STEP)
		check(s.layers[0] == s.SURFACE and s.carrying[0] == 1 and s.deliveries[0] == 0, "Full stores do not accept or destroy arriving cargo")
		s.food_stores[0] -= 1
		for tick in 300:
			s.simulate(s.STEP)
			if s.deliveries[0]: break
		check(s.deliveries[0] == 1, "An available slot restarts storage delivery")
		fresh(s, native)
		var barrier: Vector2i = s.entrance_cell(0) + Vector2i(0, 1)
		for x in range(barrier.x - 1, barrier.x + 2): s.earth[s._idx(Vector2i(x, barrier.y))] = 0
		s.chambers.dirty = true
		s.chambers.rebuild()
		check(s.storage_capacity[0] == 0 and s.brood_capacity[0] == 0, "Disconnected rooms add no usable capacity")
		check(s.nutrition.status(0).contains("No connected storage"), "Disconnected storage explains why deliveries stop")
		s.carrying[0] = 1
		for tick in 100: s.simulate(s.STEP)
		check(s.deliveries[0] == 0, "A sealed route cannot bank food through dirt")
	# Real excavation makes a planned room usable; changing its purpose changes capacity.
	fresh(s, true, 24)
	var room: Vector2i = s.chamber_cell(0) + Vector2i(14, 3)
	for dx in range(12, 26):
		var candidate: Vector2i = s.chamber_cell(0) + Vector2i(dx, 3)
		var clear := true
		for y in range(-1, 2):
			for x in range(-1, 2):
				if s.earth[s._idx(candidate + Vector2i(x, y))] != 0: clear = false
		if clear: room = candidate; break
	var capacity: int = s.storage_capacity[0]
	s.set_chamber_tool(1)
	s.designate(room)
	check(s.pending_count() >= 9 and s.storage_capacity[0] == capacity, "Painted dirt is planned capacity, not free storage")
	for tick in 4500:
		s.simulate(s.STEP)
		if s.pending_count() == 0: break
	s.chambers.rebuild()
	check(s.pending_count() == 0 and s.storage_capacity[0] == capacity + 9 * s.chambers.STORAGE_PER_TILE, "Diggers excavate and connect all nine storage tiles")
	var old_brood: int = s.brood_capacity[0]
	s.set_chamber_tool(2)
	s.designate(room)
	s.chambers.rebuild()
	check(s.brood_capacity[0] == old_brood + 18, "Brood designations create usable slots on excavated tiles")
	s.designate(room, false, true)
	s.chambers.rebuild()
	check(s.earth[s._idx(room)] == 1 and s.brood_capacity[0] == old_brood, "Erasing a room does not fill its tunnel")
	fresh(s)
	s.set_chamber_tool(1)
	s.designate(s.chamber_cell(0) + Vector2i(0, -14), false, true)
	s.chambers.rebuild()
	check(s.storage_capacity[0] >= s.food_stores[0] + s.protein_stores[0], "A brush cannot remove the last storage needed by current reserves")
	# Pre-stocked starter brood can rebuild a wiped workforce without free food.
	fresh(s, true, 0)
	s.reproduction_enabled = true
	for tick in 2400:
		s.simulate(s.STEP)
		if s.births[0] > 0 and s.living_count(0) > 0: break
	check(s.births[0] > 0 and s.living_count(0) > 0 and s.brood_spent[0] > 0, "Physical starter brood preserves recovery after total worker loss")
	# Nurses reserve existing stock, carry it along the tunnel, and feed a real room.
	fresh(s)
	s.brood_buffers.fill(0)
	s.chambers.buffered.fill(0)
	s.protein_stores[0] = 100
	var storage: int = s.chambers.storage_cells[0][0]
	s.layers[0] = 0
	s.positions[0] = s._center(Vector2i(storage % s.COLS, storage / s.COLS))
	s.roles[0] = s.NURSE
	s.chambers.prepare_reference()
	s.chambers.nurse(0, s.STEP)
	var target: int = s.nurse_targets[0]
	check(s.nurse_load[0] == 4 and s.protein_stores[0] == 100 and s.chambers.reserved[0] == 4, "Nurses carry reserved protein without duplicating colony stock")
	for tick in 600:
		s.simulate(s.STEP)
		if s.chambers.buffered[0] > 0: break
	check(s.chambers.buffered[0] == 4 and s.nurse_load[0] == 0 and s.positions[0].distance_to(s._center(Vector2i(storage % s.COLS, storage / s.COLS))) > 100, "Nurses physically reach brood before its buffer receives protein")
	s.brood[0] = [{"stage": 0, "age": 9.0, "cell": target}]
	s._update_nurseries(0.1)
	check(s.brood[0][0].stage == 1 and s.protein_stores[0] == 97 and s.chambers.buffered[0] == 1, "A stage consumes room-delivered protein exactly once")
	s.brood[0][0].age = 20
	s._update_nurseries(0.1)
	check(s.brood[0][0].stage == 1 and s.protein_stores[0] == 97, "Plenty of distant stock cannot bypass missing local feed")
	s.brood[0][0].stage = 2
	s.brood[0][0].age = 20
	s._update_nurseries(0.1)
	check(s.layers[1] == 0 and s._idx(s._cell(s.positions[1])) == target, "Workers hatch in their brood chamber and must walk out")
	fresh(s)
	s.roles[0] = s.NURSE
	s.layers[0] = 0
	s.positions[0] = s.queen_position(0)
	s.nurse_load[0] = 4
	s.carrying[0] = 1
	s.cargo_resource[0] = 1
	s.chambers.reserved[0] = 4
	s.protein_stores[0] = 100
	s.health[0] = 0
	s._kill_ant(0)
	var dropped := 0
	for patch in s.foods: dropped += patch.amount
	check(dropped == 4 and s.protein_stores[0] == 96 and s.storage_released[1] == 4 and s.chambers.reserved[0] == 0, "Killed nurses release their exact reserved load into the nest")
	# Combat frontage is bounded; empty friendly traffic has a deadlock escape.
	fresh(s)
	var entry: Vector2i = s.entrance_cell(0)
	s.layers[0] = 0
	s.positions[0] = s._center(entry)
	var next: Vector2 = s._center(entry + Vector2i.DOWN)
	s.tunnel_occupancy[s._idx(entry + Vector2i.DOWN)] = s.chambers.TRAFFIC_LIMIT
	s.roles[0] = s.INVADER
	check(not s.chambers.move_inside(0, next), "A crowded choke limits combat movement")
	s.roles[0] = s.FORAGER
	check(s.chambers.move_inside(0, next), "Empty friendly couriers can pass queues")
	s.layers[0] = s.SURFACE
	s.positions[0] = s.HOME
	s.roles[0] = s.DIGGER
	for lane in 3: s.tunnel_occupancy[s.nest_entries[lane]] = s.chambers.TRAFFIC_LIMIT
	check(s._enter_nest(0, 0), "An incoming courier queue cannot starve the excavation crew at the portal")
	# Players can hold a connected corridor with existing Guard orders.
	fresh(s, true, 24)
	s.inspected_colony = 0
	s.set_view(true)
	s.dig_mode = false
	s.set_command_tool(s.command_system.GUARD)
	var post: Vector2 = s._center(s.entrance_cell(0) + Vector2i(0, 7))
	check(s.place_surface_order(s.command_system.GUARD, post) and s.command_system.markers[0].layer == 0, "Underground Guard orders remain in the nest layer")
	for tick in 600: s.simulate(s.STEP)
	var arrived := false
	for i in s.colony_workers[0]:
		if s.health[i] > 0 and s.roles[i] == s.WARDEN and s.layers[i] == 0 and s.positions[i].distance_to(post) < 2: arrived = true
	check(arrived, "A real guard walks inside and holds the corridor")
	s.command_system.clear()
	var returning := false
	for i in s.colony_workers[0]:
		if s.health[i] > 0 and s.roles[i] == s.RETURNING and s.layers[i] == 0: returning = true
	check(returning, "Cancelling a nest post releases guards through the real exit")
	# Different tunnel layouts change actual route distance and wall protection.
	s.earth.fill(0)
	for y in range(20, 25):
		s.earth[s._idx(Vector2i(20, y))] = 1
		s.earth[s._idx(Vector2i(30, y))] = 1
	for x in range(20, 31): s.earth[s._idx(Vector2i(x, 24))] = 1
	var before: int = s.tunnel_route(Vector2i(20, 20), Vector2i(30, 20), 0).size()
	check(not s._tunnel_line_clear(s._center(Vector2i(20, 20)), s._center(Vector2i(30, 20)), 0), "Undug walls protect rooms across a detour")
	for x in range(20, 31): s.earth[s._idx(Vector2i(x, 20))] = 1
	check(s.tunnel_route(Vector2i(20, 20), Vector2i(30, 20), 0).size() < before, "A shortcut lowers real tunnel travel distance")
	if failures == 0: print("PASS: storage trips/full/sealed routes in both kernels, real chamber excavation/capacity, nurse transport/feed/loss ledgers, brood hatching, traffic passing/combat limits, nest guards and layout distances.")
	s.queue_free()
	quit(1 if failures else 0)
