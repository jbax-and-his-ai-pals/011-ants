extends RefCounted
## Bounded projects use the same soil, workers and security quotas as the player.
var strategy_ref: WeakRef
var ai:
	get: return strategy_ref.get_ref()
var sim
var colony := 1
var pending: Dictionary = {}
var progress: Dictionary = {}
var dug := 0
var projects := 0
var project := ""
var reason := "Starter rooms have spare capacity."
var next_project := 0.0
var widened := false
var guard_cell := -1

func setup(strategy) -> void:
	strategy_ref = weakref(strategy)
	sim = ai.sim
	colony = ai.colony

func reset() -> void:
	if colony == 0: pending = sim.designated_cells
	pending.clear()
	progress.clear()
	dug = 0
	projects = 0
	project = ""
	reason = "Starter rooms have spare capacity."
	next_project = 0
	widened = false
	guard_cell = -1

func think(population: int, invaded: bool) -> void:
	if not sim.chambers_enabled: return
	if not pending.is_empty():
		reason = "%s: %d tiles left; %d diggers." % [project, pending.size(), sim.digger_count(colony)]
		return
	if not project.is_empty():
		project = ""
		progress.clear()
		next_project = sim.elapsed + 12
	if sim.elapsed < next_project: return
	next_project = sim.elapsed + 12
	if population < 40 or sim.food_stores[colony] < sim.upkeep_rate(colony, population) * 25:
		reason = "Food recovery takes priority over expansion."
		return
	if invaded:
		reason = "Finish existing work; defend before starting another project."
		return
	var stock: float = sim.food_stores[colony] + sim.protein_stores[colony]
	var capacity: int = sim.storage_capacity[colony]
	if stock >= capacity * 0.70 or capacity < sim.upkeep_rate(colony, population) * 40:
		if add_room(sim.chambers.STORAGE):
			project = "Storage expansion (reserves at %d%%)" % int(stock * 100 / maxf(1, capacity))
			started()
			return
	var slots: int = sim.brood_capacity[colony]
	var desired := mini(sim.BROOD_CAP, maxi(18, ceili(population / 80.0)))
	var prepare_royal: bool = sim.game_mode == sim.game_modes.FOUNDING and population >= 60 and sim.progression.paths[colony] != sim.progression.NONE and sim.progression.daughters[colony].is_empty()
	if prepare_royal: desired = maxi(desired, 24)
	if slots < desired and (sim.brood[colony].size() >= slots * 0.75 or prepare_royal) and sim.protein_stores[colony] >= 16 and sim.food_stores[colony] >= sim.upkeep_rate(colony, population) * 45:
		if add_room(sim.chambers.BROOD):
			project = "Prepare daughter nursery before 80 workers" if prepare_royal else "Brood expansion (%d/%d slots in use)" % [sim.brood[colony].size(), slots]
			started()
			return
	if shortcut():
		project = "Shorten a detouring nurse route"
		started()
		return
	# Only widen the busy haul section, preserving the inner defensive throat.
	# At most one 20-tile route project per nest, never a per-ant search.
	if not widened and busy_shaft():
		var base: Vector2i = sim.chamber_cell(colony)
		var grid: PackedByteArray = sim._nest_grid(colony)
		for y in range(-13, -3):
			for x in [-2, 2]:
				var j: int = sim._idx(base + Vector2i(x, y))
				if grid[j] == 0: sim._set_order(j, true, colony)
		widened = true
		if not pending.is_empty():
			project = "Widen busy storage route; preserve inner guard corridor"
			started()
			return
	reason = "Rooms have spare capacity; maintain the guarded inner corridor."

func started() -> void:
	projects += 1
	reason = "%s: %d tiles queued for workers." % [project, pending.size()]

func shortcut() -> bool:
	var storage: Array = sim.chambers.storage_cells[colony]
	var rooms: Array = sim.chambers.brood_cells[colony]
	if storage.is_empty() or rooms.is_empty(): return false
	var start := Vector2i(int(storage[0]) % sim.COLS, int(storage[0]) / sim.COLS)
	var grid: PackedByteArray = sim._nest_grid(colony)
	for n in mini(4, rooms.size()):
		var j: int = rooms[n * rooms.size() / mini(4, rooms.size())]
		var goal := Vector2i(j % sim.COLS, j / sim.COLS)
		var existing: Array = sim.tunnel_route(start, goal, colony)
		var direct := absi(goal.x - start.x) + absi(goal.y - start.y)
		if existing.is_empty() or existing.size() <= direct + 4: continue
		# Test both elbow routes. Never break stone or an inner queen wall.
		for horizontal_first in [true, false]:
			var cursor := start
			var dig: Array[int] = []
			var safe := true
			while cursor != goal:
				if (horizontal_first and cursor.x != goal.x) or cursor.y == goal.y: cursor.x += signi(goal.x - cursor.x)
				else: cursor.y += signi(goal.y - cursor.y)
				var k: int = sim._idx(cursor)
				if grid[k] == 2: safe = false; break
				if grid[k] == 0:
					if cursor.distance_squared_to(sim.chamber_cell(colony)) < 16: safe = false; break
					dig.append(k)
			if safe and not dig.is_empty() and dig.size() <= 32:
				for k in dig: sim._set_order(k, true, colony)
				return true
	return false

func busy_shaft() -> bool:
	var base: Vector2i = sim.chamber_cell(colony)
	for y in range(-12, -4):
		var j: int = sim._idx(base + Vector2i(0, y))
		var traffic := 0
		for x in range(-1, 2): traffic += sim.tunnel_occupancy[colony * sim.CELLS + j + x]
		if traffic >= 6: return true
	return false

func add_room(kind: int) -> bool:
	var base: Vector2i = sim.chamber_cell(colony)
	var grid: PackedByteArray = sim._nest_grid(colony)
	# Finite, mirrored local sites. Storage stays by the portal; brood by the
	# queen. Each new room gets the shortest soil connection around stone.
	for row in ([-13, -9, -5] if kind == sim.chambers.STORAGE else [0, 4, 8]):
		for distance in [6, 10, 14]:
			for side in [-1, 1]:
				var center: Vector2i = base + Vector2i(distance * side, row)
				var valid := true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var tile := center + Vector2i(dx, dy)
						if not sim._valid(tile): valid = false; continue
						var j: int = sim._idx(tile)
						if grid[j] == 2 or sim.chamber_rooms[colony * sim.CELLS + j] != 0: valid = false
				if not valid: continue
				# Check a connection before leaving any designation behind.
				var before: int = pending.size()
				sim._connect_designation(center, colony)
				if grid[sim._idx(center)] == 0 and pending.size() == before: continue
				sim.chambers.designate(center, kind, false, false, colony)
				return true
	return false

func defense_marker(invaded: bool) -> Dictionary:
	if not sim.chambers_enabled: return {}
	if sim.game_mode == sim.game_modes.FOUNDING and sim.living_count(colony) < 40 and not invaded: return {}
	var base: Vector2i = sim.chamber_cell(colony)
	# Inner junction protects brood and queen; forward post meets incoming ants.
	var target := base + Vector2i(0, -5 if invaded else -10)
	var j: int = sim._idx(target)
	if sim.exit_flow[colony * sim.CELLS + j] < 0: return {}
	guard_cell = j
	var marker: Dictionary = ai.marker(300002, ai.orders.GUARD, sim._center(target))
	marker.layer = colony
	marker.party_limit = 12 if invaded else 6
	return marker

func explanation() -> String:
	return "Nest: %s\nBuilt %d tiles / %d projects; digging %s. Guard: %s." % [reason, dug, projects, ai.orders.PRIORITIES[ai.orders.labor[2]], "inner junction" if sim.invaders_in(colony) > 0 else "haul corridor"]
