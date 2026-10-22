extends RefCounted
## Physical nest logistics. Shared flow maps, individual loads and movement.
const STORAGE := 1
const BROOD := 2
const STORAGE_PER_TILE := 2000
const BROOD_PER_TILE := 2
const TRAFFIC_LIMIT := 6
const NURSES := 6
const NURSE_LOAD := 4
var sim
var dirty := true
var room_tiles: Array = [{}, {}, {}]
var nurse_workers: Array = [[], [], []]
var storage_cells: Array = [[], [], []]
var brood_cells: Array = [[], [], []]
var buffered := PackedInt32Array([0, 0, 0])
var reserved := PackedInt32Array([0, 0, 0])
var room_cursor := PackedInt32Array([0, 0, 0])
var populations := PackedInt32Array([0, 0, 0])
var buttons: Array[Button] = []
var summary: Label

func setup(owner_node) -> void: sim = owner_node

func reset() -> void:
	nurse_workers = [[], [], []]
	sim.storage_capacity.fill(0)
	sim.brood_capacity.fill(0)
	for name in ["chamber_rooms", "brood_buffers", "storage_flow", "exit_flow", "tunnel_occupancy"]:
		var data := PackedInt32Array()
		data.resize(sim.CELLS * 3)
		data.fill(-1 if name in ["storage_flow", "exit_flow"] else 0)
		sim.set(name, data)
	sim.nurse_load.resize(sim.health.size())
	sim.nurse_load.fill(0)
	sim.nurse_targets.resize(sim.health.size())
	sim.nurse_targets.fill(-1)
	sim.nest_entries.resize(9)
	sim.nest_entries.fill(-1)
	buffered.fill(0)
	reserved.fill(0)
	room_cursor.fill(0)
	room_tiles = [{}, {}, {}]
	for c in sim.colony_count:
		populations[c] = sim.living_count(c)
		var grid: PackedByteArray = sim._nest_grid(c)
		var base: Vector2i = sim.chamber_cell(c)
		for y in range(-15, -12):
			for x in range(-1, 2):
				var j: int = sim._idx(base + Vector2i(x, y))
				if grid[j] == 1:
					sim.chamber_rooms[c * sim.CELLS + j] = STORAGE
					room_tiles[c][j] = STORAGE
		for y in range(-1, 2):
			for x in range(1, 4):
				var j: int = sim._idx(base + Vector2i(x, y))
				if grid[j] == 1:
					sim.chamber_rooms[c * sim.CELLS + j] = BROOD
					room_tiles[c][j] = BROOD
					sim.brood_buffers[c * sim.CELLS + j] = 8
					buffered[c] += 8
	dirty = true
	rebuild()

func flow(sources: Array, grid: PackedByteArray) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(sim.CELLS)
	result.fill(-1)
	var queue: Array[int] = []
	for j in sources:
		if grid[j] == 1: result[j] = j; queue.append(j)
	var head := 0
	while head < queue.size():
		var j: int = queue[head]
		head += 1
		var cell := Vector2i(j % sim.COLS, j / sim.COLS)
		for neighbor in sim._neighbors(cell):
			var k: int = sim._idx(neighbor)
			if grid[k] == 1 and result[k] < 0:
				result[k] = j
				queue.append(k)
	return result

func rebuild() -> void:
	if not dirty: return
	var exits := PackedInt32Array()
	var stores := PackedInt32Array()
	for c in sim.colony_count:
		var grid: PackedByteArray = sim._nest_grid(c)
		var entrances: Array = []
		for lane in 3:
			var j: int = sim._idx(sim.entrance_cell(c) + Vector2i(lane - 1, 0))
			sim.nest_entries[c * 3 + lane] = j if grid[j] == 1 else -1
			if grid[j] == 1: entrances.append(j)
		var outward := flow(entrances, grid)
		storage_cells[c] = []
		brood_cells[c] = []
		exits.append_array(outward)
		for j in room_tiles[c]:
			if outward[j] < 0: continue
			var kind: int = sim.chamber_rooms[c * sim.CELLS + j]
			if kind == STORAGE: storage_cells[c].append(j)
			if kind == BROOD: brood_cells[c].append(j)
		var inward := flow(storage_cells[c], grid)
		stores.append_array(inward)
		sim.storage_capacity[c] = storage_cells[c].size() * STORAGE_PER_TILE
		sim.brood_capacity[c] = mini(sim.BROOD_CAP, brood_cells[c].size() * BROOD_PER_TILE)
	exits.resize(sim.CELLS * 3)
	stores.resize(sim.CELLS * 3)
	sim.exit_flow = exits
	sim.storage_flow = stores
	dirty = false

func prepare_reference() -> void:
	sim.tunnel_occupancy.fill(0)
	for i in sim.health.size():
		if sim.health[i] > 0 and sim.layers[i] >= 0:
			sim.tunnel_occupancy[sim.layers[i] * sim.CELLS + sim._idx(sim._cell(sim.positions[i]))] += 1

func move_inside(i: int, next: Vector2) -> bool:
	var nest: int = sim.layers[i]
	var old: int = nest * sim.CELLS + sim._idx(sim._cell(sim.positions[i]))
	var target: int = nest * sim.CELLS + sim._idx(sim._cell(next))
	if target != old:
		# Empty friendly couriers can squeeze past a queue. A hard occupancy cap
		# on both directions would deadlock a one-cell corridor permanently.
		var passing: bool = nest == sim.colonies[i] and sim.roles[i] in [sim.FORAGER, sim.NURSE, sim.DIGGER, sim.GUARD, sim.WARDEN] and not sim.carrying[i] and sim.opponents[i] < 0
		if sim.tunnel_occupancy[target] >= TRAFFIC_LIMIT and not passing: return false
		sim.tunnel_occupancy[old] = maxi(0, sim.tunnel_occupancy[old] - 1)
		sim.tunnel_occupancy[target] += 1
	sim.positions[i] = next
	return true

func walk_flow(i: int, route: PackedInt32Array, dt: float) -> bool:
	var nest: int = sim.layers[i]
	var j: int = sim._idx(sim._cell(sim.positions[i]))
	var next: int = route[nest * sim.CELLS + j]
	if next < 0: return false
	var center: Vector2 = sim._center(Vector2i(j % sim.COLS, j / sim.COLS))
	var target: Vector2 = sim._center(Vector2i(next % sim.COLS, next / sim.COLS))
	# Finish a tile center before turning a corner; never cut through walls.
	var delta: Vector2 = target - center
	var offset: Vector2 = sim.positions[i] - center
	if (absf(delta.x) > 0 and absf(offset.y) > 0.05) or (absf(delta.y) > 0 and absf(offset.x) > 0.05) or (next == j): target = center
	var direction: Vector2 = target - sim.positions[i]
	if direction.length_squared() > 0.0001: sim.headings[i] = direction.angle()
	move_inside(i, sim.positions[i].move_toward(target, 47 * dt))
	return next == j and sim.positions[i].distance_squared_to(center) < 0.01

func exit_worker(i: int) -> void:
	var c: int = sim.layers[i]
	var j: int = sim._idx(sim._cell(sim.positions[i]))
	sim.tunnel_occupancy[c * sim.CELLS + j] = maxi(0, sim.tunnel_occupancy[c * sim.CELLS + j] - 1)
	sim.layers[i] = sim.SURFACE
	sim.positions[i] = sim.nest_position(c) + Vector2((sim.worker_ids[i] % 3 - 1) * 8, 18)
	sim.paths[i] = []
	sim.route_goals[i] = -1

func courier(i: int, dt: float) -> void:
	var c: int = sim.colonies[i]
	if sim.layers[i] != c: return
	if not sim.carrying[i]:
		var nearest := -1
		var best := INF
		for f in sim.foods.size():
			var patch: Dictionary = sim.foods[f]
			if patch.amount <= 0 or patch.get("layer", -1) != c: continue
			var distance: float = sim.positions[i].distance_squared_to(patch.pos)
			if distance >= 144: continue
			var score: float = distance / sim.nutrition_weights[c * 2 + int(patch.get("resource", 0))]
			if score < best: best = score; nearest = f
		if nearest >= 0:
			sim.foods[nearest].amount -= 1
			sim.carrying[i] = 1
			sim.cargo_resource[i] = sim.foods[nearest].get("resource", 0)
			if c == 0: sim.food_picked_up(i)
	if sim.carrying[i]:
		if sim.storage_flow[c * sim.CELLS + sim._idx(sim._cell(sim.positions[i]))] < 0:
			if walk_flow(i, sim.exit_flow, dt): exit_worker(i)
		elif walk_flow(i, sim.storage_flow, dt) and sim.food_stores[c] + sim.protein_stores[c] + 1 <= sim.storage_capacity[c]:
			sim.bank_load(i)
	elif walk_flow(i, sim.exit_flow, dt): exit_worker(i)

func room_for_egg(c: int) -> int:
	var cells: Array = brood_cells[c]
	if cells.is_empty(): return -1
	var counts := {}
	var royal: int = sim.progression.occupied_cell(c)
	if royal >= 0: counts[royal] = BROOD_PER_TILE
	for young in sim.brood[c]: counts[young.get("cell", -1)] = counts.get(young.get("cell", -1), 0) + 1
	for n in cells.size():
		var slot: int = (room_cursor[c] + n) % cells.size()
		var j: int = cells[slot]
		if counts.get(j, 0) < BROOD_PER_TILE and sim.brood_buffers[c * sim.CELLS + j] >= 1:
			room_cursor[c] = (slot + 1) % cells.size()
			return j
	return -1

func feed(c: int, young: Dictionary, cost: int) -> bool:
	var j: int = young.get("cell", -1)
	if j < 0 or j not in brood_cells[c] or sim.protein_stores[c] < cost or sim.brood_buffers[c * sim.CELLS + j] < cost: return false
	sim.brood_buffers[c * sim.CELLS + j] -= cost
	buffered[c] -= cost
	return true

func allocate_nurses() -> void:
	for c in sim.colony_count:
		var active := 0
		nurse_workers[c] = []
		for i in sim.colony_workers[c]:
			if sim.health[i] > 0 and sim.roles[i] == sim.NURSE:
				active += 1
				nurse_workers[c].append(i)
		var population: int = sim.living_count(c)
		populations[c] = population
		var wanted: int = mini(NURSES, maxi(1, population / 40)) if population > 0 and sim.queen_health[c] > 0 and not brood_cells[c].is_empty() else 0
		if sim.game_mode == sim.game_modes.FOUNDING and wanted > 0:
			wanted = mini(NURSES, mini(maxi(1, population / 6), ceili(population / 12.0)))
		if population < 40 and (sim.protein_stores[c] - buffered[c] - reserved[c] < 1 or sim.food_stores[c] < sim.upkeep_rate(c, population) * 15): wanted = 0
		if active > wanted:
			for i in nurse_workers[c]:
				if active <= wanted: break
				if sim.nurse_load[i] > 0: continue
				sim.roles[i] = sim.FORAGER if sim.layers[i] == sim.SURFACE else sim.RETURNING
				sim.paths[i] = []
				sim.route_goals[i] = -1
				active -= 1
		for i in sim.colony_workers[c]:
			if active >= wanted: break
			if sim.health[i] > 0 and sim.roles[i] == sim.FORAGER and sim.layers[i] == sim.SURFACE and not sim.carrying[i] and sim.opponents[i] < 0:
				sim.roles[i] = sim.NURSE
				nurse_workers[c].append(i)
				sim.worker_order_ids[i] = -1
				sim.worker_order_kinds[i] = 0
				sim.paths[i] = []
				active += 1

func nurse(i: int, dt: float) -> void:
	var c: int = sim.colonies[i]
	var small_emergency: bool = populations[c] < 40 and (sim.protein_stores[c] - buffered[c] - reserved[c] < 1 or sim.food_stores[c] < sim.upkeep_rate(c, populations[c]) * 15)
	if (sim.queen_health[c] <= 0 or small_emergency) and sim.nurse_load[i] == 0:
		sim.roles[i] = sim.FORAGER if sim.layers[i] == sim.SURFACE else sim.RETURNING
		return
	if sim.layers[i] == sim.SURFACE:
		sim._move_surface_worker(i, sim.nest_position(c), dt)
		sim._enter_nest(i, c)
		return
	var target: int = sim.nurse_targets[i]
	if sim.queen_health[c] <= 0: target = -1
	if sim.nurse_load[i] > 0 and target in brood_cells[c]:
		sim._navigate_tunnel(i, Vector2i(target % sim.COLS, target / sim.COLS), dt)
		if sim.positions[i].distance_squared_to(sim._center(Vector2i(target % sim.COLS, target / sim.COLS))) < 1:
			sim.brood_buffers[c * sim.CELLS + target] += sim.nurse_load[i]
			buffered[c] += sim.nurse_load[i]
			reserved[c] -= sim.nurse_load[i]
			sim.nurse_load[i] = 0
			sim.carrying[i] = 0
			sim.nurse_targets[i] = -1
		return
	if not walk_flow(i, sim.storage_flow, dt): return
	if sim.nurse_load[i] > 0: # A cancelled brood designation returns its delivery.
		reserved[c] -= sim.nurse_load[i]
		sim.nurse_load[i] = 0
		sim.carrying[i] = 0
	sim.trips[i] -= dt
	if sim.trips[i] > 0: return
	sim.trips[i] = 0.3
	var available: int = maxi(0, floori(sim.protein_stores[c]) - buffered[c] - reserved[c] - sim.progression.preparation_reserves[c])
	if available <= 0: return
	var incoming := {}
	for worker in nurse_workers[c]:
		if sim.health[worker] > 0 and sim.nurse_load[worker] > 0:
			var goal: int = sim.nurse_targets[worker]
			incoming[goal] = incoming.get(goal, 0) + sim.nurse_load[worker]
	var best := INF
	target = -1
	for j in brood_cells[c]:
		var amount: int = sim.brood_buffers[c * sim.CELLS + j] + incoming.get(j, 0)
		if amount >= 8: continue
		var score: float = amount * 10000 + sim.positions[i].distance_squared_to(sim._center(Vector2i(j % sim.COLS, j / sim.COLS))) * 0.01
		if sim.game_mode == sim.game_modes.FOUNDING:
			var wanted := 0
			var urgent := 0
			for young in sim.brood[c]:
				if young.get("cell", -1) == j and young.stage < 2:
					var cost: int = int(sim.stage_feed_cost(c, young.stage)) + (4 if young.stage == 1 and young.get("caste", 0) else 0)
					wanted += cost
					if young.age >= sim.stage_duration(c, young.stage): urgent += cost
			if sim.progression.occupied_cell(c) == j:
				wanted += 4; urgent += 4
			if amount >= maxi(1, wanted): continue
			score -= maxi(0, urgent - amount) * 1000000 + maxi(0, wanted - amount) * 100000
		if score < best: best = score; target = j
	if target < 0: return
	var load: int = mini(NURSE_LOAD, mini(available, 8 - sim.brood_buffers[c * sim.CELLS + target] - incoming.get(target, 0)))
	sim.nurse_load[i] = load
	sim.nurse_targets[i] = target
	sim.carrying[i] = 1
	sim.cargo_resource[i] = 1
	reserved[c] += load

func worker_died(i: int) -> void:
	if sim.nurse_load[i] <= 0: return
	var c: int = sim.colonies[i]
	var load: int = sim.nurse_load[i]
	reserved[c] -= load
	sim.protein_stores[c] = maxf(0, sim.protein_stores[c] - load)
	sim.storage_released[c * 2 + 1] += load
	# The normal death handler drops the last unit; add the rest here.
	if load > 1: sim.foods.append({"pos": sim.positions[i], "amount": load - 1, "initial": load - 1, "resource": 1, "dropped": true, "layer": sim.layers[i]})
	sim.nurse_load[i] = 0

func designate(cell: Vector2i, kind: int, connect: bool, erase: bool, c: int = 0) -> void:
	if not sim._valid(cell): return
	var grid: PackedByteArray = sim._nest_grid(c)
	var offset: int = c * sim.CELLS
	if connect and not erase and grid[sim._idx(cell)] == 0: sim._connect_designation(cell, c)
	var remaining_capacity: int = sim.storage_capacity[c]
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var tile := Vector2i(x, y)
			if not sim._valid(tile): continue
			var j: int = sim._idx(tile)
			if grid[j] == 2 or tile == sim._cell(sim.queen_position(c)) or tile == sim.entrance_cell(c): continue
			if erase or (sim.chamber_rooms[offset + j] == BROOD and kind != BROOD):
				var occupied: bool = sim.progression.occupied_cell(c) == j
				for young in sim.brood[c]:
					if young.get("cell", -1) == j: occupied = true
				if occupied: sim.message = "Brood occupies that tile; wait for it to mature before removing the chamber."; continue
			if sim.chamber_rooms[offset + j] == STORAGE and (erase or kind != STORAGE) and j in storage_cells[c]:
				if remaining_capacity - STORAGE_PER_TILE < sim.food_stores[c] + sim.protein_stores[c]:
					sim.message = "Build more connected storage before removing occupied capacity."
					continue
				remaining_capacity -= STORAGE_PER_TILE
			if sim.chamber_rooms[offset + j] == BROOD and (erase or kind != BROOD):
				buffered[c] -= sim.brood_buffers[offset + j]
				sim.brood_buffers[offset + j] = 0
			sim.chamber_rooms[offset + j] = 0 if erase else kind
			if erase: room_tiles[c].erase(j)
			else: room_tiles[c][j] = kind
			if grid[j] == 0: sim._set_order(j, not erase, c)
			dirty = true
	if c == 0: sim._allocate_workers()

func draw(canvas: CanvasItem, c: int, visible: Rect2) -> void:
	var grid: PackedByteArray = sim._nest_grid(c)
	for j in room_tiles[c]:
		var kind: int = sim.chamber_rooms[c * sim.CELLS + j]
		if kind == 0: continue
		var rect := Rect2(Vector2(j % sim.COLS, j / sim.COLS) * sim.TILE, Vector2.ONE * sim.TILE)
		if not visible.intersects(rect): continue
		var color := Color("91a96d") if kind == STORAGE else Color("d4aa7c")
		var active: bool = j in (storage_cells[c] if kind == STORAGE else brood_cells[c])
		canvas.draw_rect(rect.grow(-1), Color(color, 0.20 if active else 0.06))
		canvas.draw_rect(rect.grow(-1.5), Color(color, 0.65), false, 0.8)
		if kind == STORAGE and active and sim.food_stores[c] + sim.protein_stores[c] > 0:
			if sim.food_stores[c] > 0: canvas.draw_circle(rect.get_center() + Vector2(-3, 0), 2, sim.GREEN)
			if sim.protein_stores[c] > 0: canvas.draw_circle(rect.get_center() + Vector2(3, 0), 2, Color("c89c71"))
		elif kind == BROOD and active and sim.brood_buffers[c * sim.CELLS + j] > 0:
			canvas.draw_circle(rect.get_center() + Vector2(4, 4), 1.7, Color("c89c71"))
		elif grid[j] == 0: sim._draw_text(canvas, rect.position + Vector2(3, 11), "S" if kind == STORAGE else "B", 9, color)

func build_ui() -> void:
	for kind in 3:
		var button: Button = sim._button(["Tunnel [G]", "Storage [8]", "Brood [9]"][kind], Vector2(324 + kind * 168, 178), Vector2(158, 30), func() -> void: sim.set_chamber_tool(kind))
		button.add_theme_font_size_override("font_size", 12)
		button.tooltip_text = ["Dig walkable tunnels. Narrow corridors limit traffic and attacking ants; widened routes carry more workers.", "Paint storage (3×3 brush). Dirt is excavated by your digging crew. Only connected open tiles add 2,000 storage capacity each. Carriers must walk inside and deposit there.", "Paint brood chambers (3×3 brush). Connected open tiles hold two brood each, up to 80. Nurses physically bring protein from storage. Right-drag removes a room without filling its tunnel."][kind]
		buttons.append(button)
	summary = sim._label("", Vector2(834, 178), 11, sim.INK, false, 364)
	summary.size.y = 36

func update_ui() -> void:
	var show: bool = sim.chambers_enabled and sim.underground
	for kind in buttons.size():
		buttons[kind].visible = show and sim.inspected_colony == 0
		sim._active(buttons[kind], sim.dig_mode and sim.chamber_tool == kind)
		buttons[kind].disabled = not sim.match_result.is_empty()
	summary.visible = show
	if not show: return
	var c: int = sim.inspected_colony
	summary.text = "Storage %d / %d · Brood %d / %d\nProtein at brood: %d · In nurses: %d" % [sim.food_stores[c] + sim.protein_stores[c], sim.storage_capacity[c], sim.brood[c].size(), sim.brood_capacity[c], buffered[c], reserved[c]]
