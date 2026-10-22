extends RefCounted
## Map setup only. Worker sensing, movement and strategy are unchanged.
static func configure_nests(sim) -> void:
	var triad: bool = sim.colony_count == 3 and not sim.legacy_map_layout
	sim.HOME_CELL = Vector2i(90 if triad else 80, 40 if triad else 63)
	if triad and sim.wide_map_layout: sim.HOME_CELL = Vector2i(80, 31)
	sim.HOME = (Vector2(sim.HOME_CELL) + Vector2(0.5, 0.5)) * sim.TILE
	if triad and not sim.wide_map_layout:
		var height: float = (sim.SIZE.x * 0.5 - sim.HOME.x) * sqrt(3.0)
		sim.HOME.y = (sim.SIZE.y - height) * 0.5
	sim.RIVAL_HOME = Vector2(sim.SIZE.x - sim.HOME.x, sim.HOME.y)
	sim.THIRD_HOME = Vector2(1638, sim.SIZE.y - sim.HOME.y if triad else 1400)
	if triad and sim.game_mode == sim.game_modes.FOUNDING:
		sim.HOME = Vector2(500, 430)
		sim.RIVAL_HOME = Vector2(sim.SIZE.x - 500, 430)
		sim.THIRD_HOME = Vector2(sim.SIZE.x * 0.5, 1430)
		sim.HOME_CELL = sim._cell(sim.HOME)
	sim.map_sites.assign([sim.HOME, sim.RIVAL_HOME, sim.THIRD_HOME])
	sim.starting_seat_offset = 0
	if triad and not sim.wide_map_layout:
		if not sim.fixed_starting_seats:
			var map_random := RandomNumberGenerator.new()
			map_random.seed = sim.world_seed ^ 0x5f3759df
			sim.starting_seat_offset = map_random.randi_range(0, 2)
		var sites: Array = []
		for c in 3:
			var point: Vector2 = sim.map_sites[(c + sim.starting_seat_offset) % 3]
			if sim.swapped_sides: point.x = sim.SIZE.x - point.x
			sites.append(point)
		sim.HOME = sites[0]
		sim.RIVAL_HOME = sites[1]
		sim.THIRD_HOME = sites[2]
		sim.HOME_CELL = sim._cell(sim.HOME)


static func food_patches(sim) -> Array:
	var patches: Array = []
	if sim.game_mode == sim.game_modes.FOUNDING:
		for c in sim.colony_count:
			var sites: Array[Vector2] = sim.game_modes.local_sites(c)
			for kind in 3:
				var food := patch(sites[kind], sim.game_modes.local_amounts[c][kind])
				food.resource = 1 if kind == 2 else 0
				food.food_visual = kind
				patches.append(food)
		return patches
	if sim.colony_count == 3 and not sim.legacy_map_layout:
		var center: Vector2 = (sim.map_sites[0] + sim.map_sites[1] + sim.map_sites[2]) / 3
		var nests: Array = sim.map_sites
		for c in 3:
			var outward: Vector2 = (nests[c] - center).normalized()
			# Three near supplies and two outer supplies per nest, facing away
			# from opponents. Identical quantities and route lengths in each sector.
			for angle in [-PI / 3, 0.0, PI / 3]:
				patches.append(patch(nests[c] + outward.rotated(angle) * 190, 220 * sim.FOOD_SCALE))
			for angle in [-PI * 7 / 36, PI * 7 / 36]:
				patches.append(patch(nests[c] + outward.rotated(angle) * 360, 200 * sim.FOOD_SCALE))
			# One shared site per pair. Each colony borders exactly two contests.
			patches.append(patch((nests[c] + nests[(c + 1) % 3]) / 2, 255 * sim.FOOD_SCALE))
		assign_resources(patches)
		return patches
	# Preserve the original two-colony fixtures and an explicit diagnostic control.
	patches = [patch(sim.HOME + Vector2(171, -135), 260), patch(sim.RIVAL_HOME + Vector2(-171, -135), 260), patch(Vector2(sim.SIZE.x * 0.5, sim.HOME.y + 65), 400), patch(sim.RIVAL_HOME + Vector2(84, -203), 180), patch(sim.HOME + Vector2(-84, -203), 180)]
	for point in [Vector2(300, 650), Vector2(760, 1200), Vector2(1100, 1450), Vector2(500, 1450), Vector2(1200, 300)]:
		for p in [point, Vector2(sim.SIZE.x - point.x, point.y)]: patches.append(patch(p, 200))
	for item in patches:
		item.amount *= sim.FOOD_SCALE
		item.initial *= sim.FOOD_SCALE
	if sim.colony_count == 3:
		for offset in [Vector2(-170, 0), Vector2(170, 0), Vector2(0, 190)]: patches.append(patch(sim.THIRD_HOME + offset, 220 * sim.FOOD_SCALE))
	assign_resources(patches)
	return patches

static func assign_resources(patches: Array) -> void:
	for index in patches.size():
		patches[index].food_visual = index % 3
		patches[index].resource = 1 if index % 3 == 2 else 0

static func patch(point: Vector2, amount: int) -> Dictionary:
	return {"pos": point, "amount": amount, "initial": amount}
