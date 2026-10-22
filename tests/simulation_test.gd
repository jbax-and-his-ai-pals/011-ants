extends SceneTree
## Run: Godot --headless --path . --script res://tests/simulation_test.gd

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		errors.append(description)
		push_error(description)

func _run() -> void:
	var colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	root.add_child(colony)
	colony.set_process(false)
	colony.reset_colony(81923)
	colony.invasions_enabled = false # Separate invasion tests exercise warfare.
	var initial_resources := [0, 0]
	var initial_food := 0
	for patch in colony.foods:
		initial_food += patch.amount
		initial_resources[patch.get("resource", 0)] += patch.amount
	for tick in 3600:
		colony.simulate(1.0 / 30.0)
	check(colony.delivered > 30, "Workers should discover and deliver food within two simulated minutes")
	check(colony.rival_delivered > 30, "The rival should independently discover and deliver shared food")
	check(colony.digger_count() == 0, "All surviving workers forage until digging is designated")
	var trail_max := 0.0
	for value in colony.food_scent:
		trail_max = maxf(trail_max, value)
	check(trail_max > 0.1, "Returning ants should deposit persistent food scent")
	var remaining := 0
	for patch in colony.foods:
		remaining += patch.amount
	var in_transit := 0
	for i in colony.carrying.size():
		if colony.roles[i] != colony.NURSE: in_transit += colony.carrying[i]
	check(remaining + colony.delivered + colony.rival_delivered + in_transit == initial_food + colony.food_cycle.added + colony.storage_released[0] + colony.storage_released[1] + colony.storage_released[2] + colony.storage_released[3], "Initial and replenished food must reconcile across shared patches, cargo, dropped loads, and both nests")
	for resource in 2:
		var remaining_kind := 0
		for patch in colony.foods:
			if patch.get("resource", 0) == resource: remaining_kind += patch.amount
		var cargo_kind := 0
		for i in colony.carrying.size():
			if colony.carrying[i] and colony.roles[i] != colony.NURSE and colony.cargo_resource[i] == resource: cargo_kind += 1
		var banked: int = colony.resource_delivered[resource] + colony.resource_delivered[2 + resource]
		check(remaining_kind + cargo_kind + banked == initial_resources[resource] + colony.food_cycle.added_resources[resource] + colony.storage_released[resource] + colony.storage_released[2 + resource], "Each nutrient conserves independently across pickups, drops, banking and replenishment")
	for side in 2:
		check(colony.living_count(side) + colony.casualties[side] + colony.starvation_losses[side] == colony.COUNT + colony.births[side], "Living and fallen workers must account for starting populations and births")
		check(colony.births[side] > 0, "Both queens should produce new workers from delivered food")
		check(absf(colony.INITIAL_STORES + colony.resource_delivered[side * 2] - colony.storage_released[side * 2] - colony.food_stores[side] - colony.upkeep_spent[side]) < 0.001, "Sugar deliveries and upkeep must reconcile")
		check(absf(colony.INITIAL_PROTEIN + colony.resource_delivered[side * 2 + 1] - colony.storage_released[side * 2 + 1] - colony.protein_stores[side] - colony.brood_spent[side]) < 0.001, "Protein deliveries and brood expenditure must reconcile")
	var food_result: int = colony.delivered
	# A remote brush stroke must connect to existing tunnels and recruit workers.
	var chamber: Vector2i = colony.HOME_CELL + Vector2i(14, 3)
	colony.designate(chamber)
	var ordered: int = colony.pending_count()
	check(ordered > 9, "A distant designation should include an access corridor")
	for tick in 30:
		colony.simulate(1.0 / 30.0)
	check(colony.digger_count() == 12, "Digging should recruit exactly 12 of the existing workers")
	for tick in 5400:
		colony.simulate(1.0 / 30.0)
	check(colony.dug == ordered, "Workers should finish every connected designated tile")
	check(colony.pending_count() == 0, "Completed digging should clear the work queue")
	check(colony.digger_count() == 0, "Excavators should return to foraging when finished")
	check(colony.earth[colony._idx(chamber)] == 1, "The remote chamber should become walkable")
	# Brush cannot turn rock into dirt; canceling cannot fill an existing tunnel.
	colony.designate(Vector2i(48, 19))
	check(colony.earth[colony._idx(Vector2i(48, 19))] == 2, "Stone must remain intact")
	check(colony.orders[colony._idx(Vector2i(48, 19))] == 0, "Stone cannot be designated")
	colony.designate(colony.HOME_CELL, false, true)
	check(colony.earth[colony._idx(colony.HOME_CELL)] == 1, "Erasing orders must preserve the nest")
	colony.designate(chamber + Vector2i(3, 0), false)
	colony.designate(chamber + Vector2i(3, 0), false, true)
	check(colony.orders[colony._idx(chamber + Vector2i(3, 0))] == 0, "Right-drag should cancel digging orders")
	# A new stroke at the map edge must also remain connected and in bounds.
	colony.designate(Vector2i(0, 0))
	check(colony.pending_count() > 0, "Map-edge designations should be supported")
	colony.reset_colony()
	check(colony.delivered == 0 and colony.dug == 0 and colony.pending_count() == 0, "Reset should clear food, excavation, and orders")
	check(colony.positions.size() == colony.starting_total() and colony.living_count(0) == colony.COUNT and colony.living_count(1) == colony.COUNT and colony.digger_count() == 0, "Reset should restore both starting colonies")
	check(colony.rival_delivered == 0 and colony.casualties[0] == 0 and colony.casualties[1] == 0 and colony.remains.is_empty(), "Reset should clear rival food, casualties, and remains")
	colony.paused = true
	colony._process(0.1)
	check(colony.elapsed == 0, "Pause should stop the simulation clock")
	colony.paused = false
	colony.speed = 4
	colony._process(0.1)
	check(colony.elapsed > 0.35 and colony.elapsed < 0.45, "Speed control should advance simulation at 4x")
	print("SIMULATION: %d food delivered in 120s; scent peak %.2f; %d designated tiles excavated." % [food_result, trail_max, ordered])
	if errors.is_empty():
		print("PASS: foraging, food conservation, pheromones, connected digging, worker allocation, stone, cancellation, edges, reset, pause, speed.")
		quit(0)
	else:
		print("FAIL: %d checks" % errors.size())
		quit(1)
