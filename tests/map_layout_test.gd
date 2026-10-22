extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok: failures += 1; push_error(detail)
func audit(s) -> Dictionary:
	var nests: Array = []
	var pairs: Array = []
	var resources: Array = []
	var patches: Array = []
	for c in 3: nests.append(s.nest_position(c))
	for c in 3:
		var n: Vector2 = nests[c]
		var near := 0
		var private := 0
		var shared := 0.0
		var private_lengths: Array = []
		for food in s.foods:
			if food.get("garden_site", false): continue # Audit the preserved base layout separately from new strategic opportunities.
			var distances: Array = []
			for nest in nests: distances.append(food.pos.distance_to(nest))
			var closest: float = distances.min()
			var owners: Array = []
			for side in 3:
				if distances[side] < closest + 0.01: owners.append(side)
			if distances[c] < 240: near += food.amount
			if c in owners:
				shared += float(food.amount) / owners.size()
				if owners.size() == 1:
					private += food.amount
					private_lengths.append(snappedf(distances[c], 0.01))
		private_lengths.sort()
		resources.append({"near_food_240px": near, "exclusive_nearest_food": private, "food_share_with_ties": shared, "private_route_lengths": private_lengths, "nearest_border": minf(minf(n.x, s.SIZE.x - n.x), minf(n.y, s.SIZE.y - n.y))})
		pairs.append(n.distance_to(nests[(c + 1) % 3]))
	for food in s.foods: patches.append({"position": [food.pos.x, food.pos.y], "amount": food.amount})
	return {"nests": nests.map(func(n): return [n.x, n.y]), "pair_distances": pairs, "resources": resources, "patches": patches}
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.legacy_map_layout = true
	s.reset_colony(81923)
	var before := audit(s)
	s.legacy_map_layout = false
	s.reset_colony(81923)
	var after := audit(s)
	check(after.pair_distances.max() - after.pair_distances.min() < 0.01 and absf(after.pair_distances[0] - 742) < 0.01, "All nest pairs are 742px apart")
	check(s.foods.size() == 24, "Map retains eighteen base patches and six strategic alternatives")
	for c in 3:
		var resource: Dictionary = after.resources[c]
		check(resource.near_food_240px == 13200 and resource.exclusive_nearest_food == 21200, "Identical near and private food for colony %d" % c)
		check(absf(resource.food_share_with_ties - 26300) < 0.1, "Identical total territory share for colony %d" % c)
		check(resource.private_route_lengths == [190.0, 190.0, 190.0, 360.0, 360.0], "Identical private route lengths for colony %d" % c)
		check(absf(resource.nearest_border - s.map_sites[0].y) < 0.001, "Equal nearest world boundary for colony %d" % c)
		check(not s.tunnel_route(s.entrance_cell(c), s._cell(s.queen_position(c)), c).is_empty(), "Moved nest has a connected queen chamber")
	for food in s.foods:
		check(Rect2(14, 14, s.SIZE.x - 28, s.SIZE.y - 28).has_point(food.pos), "Food is inside movement bounds")
	# A local route stays inside its owner's nearest-nest territory throughout.
	for c in 3:
		for food in s.foods:
			var exclusive := true
			for other in 3:
				if c != other and food.pos.distance_to(s.nest_position(c)) >= food.pos.distance_to(s.nest_position(other)) - 0.01: exclusive = false
			if not exclusive: continue
			for step in 11:
				var p: Vector2 = s.nest_position(c).lerp(food.pos, step / 10.0)
				for other in 3:
					if c != other: check(p.distance_to(s.nest_position(c)) < p.distance_to(s.nest_position(other)), "Private routes remain in their own territory")
	s.swapped_sides = true
	s.reset_colony(81923)
	check(audit(s).resources == after.resources, "Mirrored upper nests retain equal resource access")
	s.colony_count = 2
	s.reset_colony(81923)
	check(s.HOME == Vector2(1127, 889) and s.foods.size() == 15, "Original two-colony fixtures remain intact")
	var file := FileAccess.open("res://tests/coral_map_layout_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"before": before, "after": after}, "\t"))
	if failures == 0: print("PASS: equal nest separations, local food, private route lengths, pairwise contests, margins, tunnels, mirrored access and legacy fixtures.")
	quit(1 if failures else 0)
