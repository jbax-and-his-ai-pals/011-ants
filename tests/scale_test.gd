extends SceneTree
## Compare optimized broad phases against independent exhaustive searches.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	root.add_child(colony)
	colony.set_process(false)
	colony.reset_colony(81923)
	check(colony.COUNT == 2000 and colony.living_count(0) == colony.COUNT and colony.living_count(1) == colony.COUNT, "Start with 2,000 distinct living workers in each colony")
	var ids := {}
	for id in colony.worker_ids: ids[id] = true
	check(ids.size() == colony.starting_total() and colony.ant_rng.size() == colony.starting_total(), "Every worker needs its own identity and random stream")
	var random := RandomNumberGenerator.new()
	random.seed = 4621
	for crowd in [false, true]:
		for i in colony.starting_total():
			colony.positions[i] = Vector2(random.randf_range(200, 450 if crowd else 3000), random.randf_range(200, 450 if crowd else 1500))
			colony.carrying[i] = i % 2
			colony.roles[i] = 2 if i % 17 == 0 else 0
		colony._prepare_encounters(0)
		for i in colony.starting_total():
			var radius := 34.0 if colony.doctrines[colony.colonies[i]] == 2 and colony.roles[i] in [2, 3, 5] else 30.0
			if colony.doctrines[colony.colonies[i]] == 1 and colony.carrying[i]: radius = 12
			var best := radius * radius
			var expected := -1
			for other in colony.starting_total():
				if colony.colonies[i] == colony.colonies[other]: continue
				var distance: float = colony.positions[i].distance_squared_to(colony.positions[other])
				if distance < best:
					best = distance
					expected = other
			check(colony.opponents[i] == expected, "Cached encounter search must equal exhaustive nearest-enemy search, including dense crowds")
	# Many dropped loads must not turn food finding into an all-patches scan per ant.
	colony.foods.clear()
	for f in 1200:
		colony.foods.append({"pos": Vector2(random.randf_range(0, colony.SIZE.x), random.randf_range(0, colony.SIZE.y)), "amount": 0 if f % 7 == 0 else 1, "layer": 0 if f % 11 == 0 else colony.SURFACE})
	colony._rebuild_food_index()
	for sample in 500:
		var p := Vector2(random.randf_range(0, colony.SIZE.x), random.randf_range(0, colony.SIZE.y))
		var expected := -1
		var best := 86.0 * 86.0
		for f in colony.foods.size():
			var food: Dictionary = colony.foods[f]
			if food.amount <= 0 or food.layer != colony.SURFACE: continue
			var distance: float = p.distance_squared_to(food.pos)
			if distance < best:
				best = distance
				expected = f
		check(colony._nearest_food(p) == expected, "Food index must match exhaustive selection, excluding empty loads and other layers")
	colony.foods = [{"pos": Vector2(100, 100), "amount": 1}, {"pos": Vector2(90, 100), "amount": 1}]
	colony._rebuild_food_index()
	check(colony._nearest_food(Vector2(95, 100)) == 0, "Equal-distance food across bucket boundaries must retain array priority")
	colony.foods[0].amount = 0
	check(colony._nearest_food(Vector2(95, 100)) == 1, "A cached candidate depleted by another ant must become unavailable immediately")
	colony.foods.append({"pos": Vector2(95, 100), "amount": 1})
	check(colony._nearest_food(Vector2(95, 100)) == 2, "New dropped cargo must invalidate the food index")
	colony.foods = [{"pos": Vector2(100, 100), "amount": 0}]
	colony._rebuild_food_index()
	check(colony._nearest_food(Vector2(100, 100)) == -1, "An empty patch must not attract workers")
	colony.positions[0] = Vector2(100, 100)
	colony.carrying[0] = 1
	colony.health[0] = 0
	colony._kill_ant(0)
	check(colony._nearest_food(Vector2(100, 100)) == 0, "Cargo merged into an empty patch must become discoverable immediately")
	colony.food_scent.fill(0)
	colony._deposit(colony.food_scent, Vector2(1, 1), 0.6)
	check(is_equal_approx(colony.food_scent[0], 0.6 * colony.STEP * 9) and is_equal_approx(colony.food_scent[1], 0.6 * colony.STEP * 2.2) and colony.food_scent[colony.COLS - 1] == 0, "Flat scent neighbors must preserve deposit strengths without wrapping map edges")
	if failures == 0: print("PASS: 4,000 unique workers; dense/spread nearest-enemy oracle; 1,200-patch food oracle; tie/depletion/drop behavior; scent edges.")
	quit(1 if failures else 0)
