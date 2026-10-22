extends RefCounted
## Persistent player intent; individual workers still sense, move and fight.
const FORAGE := 1
const GUARD := 2
const AVOID := 3
const RAID := 4
const AVOID_RADIUS := 100.0
const MAX_ORDERS := 8
const NAMES := ["Navigate", "Forage", "Guard", "Avoid", "Raid"]
const COLORS := [Color("9cafa3"), Color("bee27c"), Color("8cc7ca"), Color("ef907f"), Color("edb76c")]
const PRIORITIES := ["Off", "Low", "Normal", "High"]
var sim
var colony := 0
var markers: Array = []
var next_id := 1
var labor := PackedInt32Array([2, 2, 2]) # Marked forage, security, excavation.
var history: Array = []
var losses: Array = []
var loss_head := 0
var next_sample := 1.0
var report := {}
var hotspot := {}
var assignments_present := false
var cargo_orders := {} # Stable worker ID -> order held at pickup.
var order_delivered := {}
var order_resources := {}

func setup(owner_node, colony_id: int = 0) -> void:
	sim = owner_node
	colony = colony_id

func reset() -> void:
	markers.clear()
	cargo_orders.clear()
	order_delivered.clear()
	order_resources.clear()
	next_id = 1
	labor.fill(2)
	losses.clear()
	loss_head = 0
	history.clear()
	next_sample = 1
	hotspot.clear()
	assignments_present = false
	if colony == 0: sim.avoid_points.clear()
	sim.worker_order_ids.resize(sim.health.size())
	sim.worker_order_kinds.resize(sim.health.size())
	sim.worker_order_goals.resize(sim.health.size())
	for i in sim.colony_workers[colony]:
		sim.worker_order_ids[i] = -1
		sim.worker_order_kinds[i] = 0
		sim.worker_order_goals[i] = Vector2.ZERO
	history.append(snapshot())
	sample()

func snapshot() -> Dictionary:
	return {"time": sim.elapsed, "harvest": sim.delivered if colony == 0 else (sim.rival_delivered if colony == 1 else sim.third_delivered), "sugar": sim.resource_delivered[colony * 2], "protein": sim.resource_delivered[colony * 2 + 1], "upkeep": sim.upkeep_spent[colony], "brood": sim.brood_spent[colony]}

func tick() -> void:
	if sim.elapsed >= next_sample:
		sample()
		next_sample = sim.elapsed + 1

func sample() -> void:
	while history.size() > 1 and history[1].time < sim.elapsed - 30: history.pop_front()
	var now := snapshot()
	if history.is_empty() or now.time > history.back().time: history.append(now)
	var base: Dictionary = history.front()
	var duration: float = maxf(0.001, now.time - base.time)
	var income: float = (now.harvest - base.harvest) / duration
	var upkeep: float = (now.upkeep - base.upkeep) / duration
	var breeding: float = (now.brood - base.brood) / duration
	var sugar_income: float = (now.sugar - base.sugar) / duration
	var protein_income: float = (now.protein - base.protein) / duration
	var net := sugar_income - upkeep
	var runway: float = sim.food_stores[colony] / -net if net < -0.001 else INF
	while loss_head < losses.size() and losses[loss_head].time < sim.elapsed - 30: loss_head += 1
	var combat := 0
	var hunger := 0
	var cells := {}
	var per_order := {}
	hotspot.clear()
	for index in range(loss_head, losses.size()):
		var loss: Dictionary = losses[index]
		var id: int = loss.get("order", -1)
		if not per_order.has(id): per_order[id] = [0, 0]
		per_order[id][1 if loss.hunger else 0] += 1
		if loss.hunger: hunger += 1
		else: combat += 1
		var key := Vector3i(int(loss.pos.x / 70), int(loss.pos.y / 70), loss.layer)
		if not cells.has(key): cells[key] = {"count": 0, "pos": loss.pos, "layer": loss.layer}
		cells[key].count += 1
		if hotspot.is_empty() or cells[key].count > hotspot.count: hotspot = cells[key].duplicate()
	if loss_head > 512:
		losses = losses.slice(loss_head)
		loss_head = 0
	report = {"income": income * 60, "sugar_income": sugar_income * 60, "protein_income": protein_income * 60, "upkeep": upkeep * 60, "brood": breeding * 60, "net": net * 60, "runway": runway, "duration": duration, "combat": combat, "hunger": hunger}
	# Count living assignments, rather than the last recruitment quota.
	var assigned := {}
	for i in sim.colony_workers[colony]:
		if sim.health[i] > 0:
			var id: int = sim.worker_order_ids[i]
			assigned[id] = assigned.get(id, 0) + 1
	for marker in markers:
		marker.assigned = assigned.get(marker.id, 0)
		marker.delivered = order_delivered.get(marker.id, 0)
		marker.recent_losses = per_order.get(marker.id, [0, 0])

func record_pickup(i: int) -> void:
	var id: int = sim.worker_order_ids[i]
	if id >= 0 and sim.worker_order_kinds[i] == FORAGE:
		cargo_orders[sim.worker_ids[i]] = id
	else: cargo_orders.erase(sim.worker_ids[i])

func record_delivery(i: int, resource: int = 0) -> void:
	var worker: int = sim.worker_ids[i]
	var id: int = cargo_orders.get(worker, -1)
	# Removed orders cannot reappear or accumulate hidden history.
	for marker in markers:
		if marker.id == id:
			order_delivered[id] = order_delivered.get(id, 0) + 1
			if not order_resources.has(id): order_resources[id] = [0, 0]
			order_resources[id][resource] += 1
			break
	cargo_orders.erase(worker)

func record_loss(i: int, hunger: bool) -> void:
	if sim.colonies[i] == colony:
		losses.append({"time": sim.elapsed, "pos": sim.positions[i], "layer": sim.layers[i], "hunger": hunger, "order": sim.worker_order_ids[i]})
		cargo_orders.erase(sim.worker_ids[i])

func is_avoided(point: Vector2) -> bool:
	if colony != 0: return false
	for center in sim.avoid_points:
		if point.distance_squared_to(center) < AVOID_RADIUS * AVOID_RADIUS: return true
	return false

func issue(kind: int, point: Vector2) -> bool:
	if kind < FORAGE or kind > RAID or not sim.match_result.is_empty(): return false
	point = point.clamp(Vector2(9, 9), sim.SIZE - Vector2(9, 9))
	if kind == AVOID and point.distance_to(sim.nest_position(0)) < AVOID_RADIUS + 40:
		sim.message = "Keep the entrance clear: place Avoid at least 140 px from your nest."
		return false
	var order_layer: int = 0 if kind == GUARD and sim.chambers_enabled and sim.underground and sim.inspected_colony == 0 else -1
	if order_layer == 0 and sim.exit_flow[sim._idx(sim._cell(point))] < 0:
		sim.message = "Place nest guards on a connected, excavated tunnel tile."
		return false
	if order_layer < 0 and kind != AVOID and is_avoided(point):
		sim.message = "That target is inside an Avoid area. Remove or move Avoid first."
		return false
	var existing := -1
	var same_kind := 0
	for m in markers.size():
		if markers[m].kind == kind:
			same_kind += 1
			if markers[m].get("layer", -1) == order_layer and (kind == RAID or markers[m].pos.distance_to(point) < 42): existing = m
	if existing < 0 and (markers.size() >= MAX_ORDERS or same_kind >= 3):
		sim.message = "Order limit: 8 markers total, 3 per type, 1 Raid. Right-click a marker to remove it."
		return false
	if existing >= 0:
		markers[existing].pos = point
		markers[existing].seen_food = false
	else:
		markers.append({"id": next_id, "kind": kind, "pos": point, "seen_food": false, "assigned": 0, "status": "Active", "layer": order_layer})
		next_id += 1
	rebuild_avoid()
	allocate()
	sim.message = "%s order placed. It persists until removed; drag to pan, right-click the marker to cancel." % NAMES[kind]
	return true

func rebuild_avoid() -> void:
	sim.avoid_points.clear()
	for marker in markers:
		if marker.kind == AVOID: sim.avoid_points.append(marker.pos)

func remove(id: int) -> bool:
	if not sim.match_result.is_empty(): return false
	for m in markers.size():
		if markers[m].id == id:
			markers.remove_at(m)
			order_delivered.erase(id)
			order_resources.erase(id)
			rebuild_avoid()
			allocate()
			return true
	return false

func remove_at(point: Vector2, radius: float) -> bool:
	var id := -1
	var best := radius * radius
	for marker in markers:
		if marker.get("layer", -1) != sim.active_camera_layer: continue
		var distance: float = point.distance_squared_to(marker.pos)
		if distance < best:
			best = distance
			id = marker.id
	return remove(id) if id >= 0 else false

func clear() -> void:
	if not sim.match_result.is_empty(): return
	markers.clear()
	order_delivered.clear()
	order_resources.clear()
	rebuild_avoid()
	allocate()
	sim.message = "Surface orders cleared. Workers resume autonomous jobs; underground raiders return through the entrance."

func set_priority(category: int, value: int) -> void:
	if category < 0 or category > 2 or not sim.match_result.is_empty(): return
	labor[category] = clampi(value, 0, 3)
	allocate()
	sim._allocate_workers()

func raid_limit() -> int:
	return [0, 6, 12, 24][labor[1]]

func digging_limit() -> int:
	return [0, 6, 12, 24][labor[2]]

func has_raid() -> bool:
	for marker in markers:
		if marker.kind == RAID: return true
	return false

func release(i: int) -> void:
	if sim.roles[i] == sim.WARDEN or (sim.roles[i] == sim.INVADER and sim.worker_order_kinds[i] == RAID):
		sim.roles[i] = sim.RETURNING if sim.layers[i] >= 0 else sim.FORAGER
		sim.paths[i] = []
		sim.route_goals[i] = -1
	sim.worker_order_ids[i] = -1
	sim.worker_order_kinds[i] = 0

func assign(i: int, marker: Dictionary) -> void:
	var changed: bool = sim.worker_order_ids[i] != marker.id
	sim.worker_order_ids[i] = marker.id
	sim.worker_order_kinds[i] = marker.kind
	sim.worker_order_goals[i] = marker.pos
	if marker.kind == GUARD: sim.roles[i] = sim.WARDEN
	if marker.kind == RAID: sim.roles[i] = sim.INVADER
	if changed and marker.kind in [GUARD, RAID]:
		sim.trips[i] = 0
		sim.targets[i] = -1
		sim.paths[i] = []
		sim.route_goals[i] = -1
	marker.assigned += 1

func allocate() -> void:
	if markers.is_empty() and not assignments_present: return
	assignments_present = not markers.is_empty()
	var active := {}
	var forage: Array = []
	var security: Array = []
	var population: int = sim.living_count(colony)
	var security_left := mini(48, maxi(0, population / 5))
	for marker in markers:
		marker.assigned = 0
		marker.status = "Active"
		if marker.kind == AVOID: continue
		if marker.kind == RAID:
			var eliminated := false
			for target in sim.colony_count:
				if target != colony and sim.queen_health[target] <= 0 and marker.pos.distance_to(sim.nest_position(target)) <= 90: eliminated = true
			if eliminated: marker.status = "Eliminated"; continue
		if marker.get("layer", -1) < 0 and is_avoided(marker.pos): marker.status = "Blocked"; continue
		if labor[0 if marker.kind == FORAGE else 1] == 0: marker.status = "Paused"; continue
		if marker.kind == FORAGE:
			marker.weight = 0.25
			var food := 0
			var arrival := INF
			for patch in sim.foods:
				if patch.get("layer", -1) == -1 and patch.pos.distance_squared_to(marker.pos) < 160 * 160:
					if patch.amount > 0 or patch.get("arrival", 0.0) > sim.elapsed:
						marker.weight = maxf(marker.weight, sim.nutrition_weights[colony * 2 + int(patch.get("resource", 0))])
					if patch.amount > 0 and not is_avoided(patch.pos): food += patch.amount
					if patch.get("arrival", 0.0) > sim.elapsed and not is_avoided(patch.pos): arrival = minf(arrival, patch.arrival)
			if food > 0: marker.seen_food = true
			elif not is_inf(arrival): marker.status = "Food in %ds" % ceili(arrival - sim.elapsed)
			elif marker.seen_food: marker.status = "Depleted"; continue
			else: marker.status = "Searching"
			# Rival route evidence can reduce guidance toward a dangerous source.
			# Player markers omit this field and retain their existing allocation.
			marker.weight *= clampf(marker.get("route_weight", 1.0), .1, 1.0)
			forage.append(marker)
		else:
			marker.quota = mini(mini(raid_limit(), marker.get("party_limit", 48)), security_left)
			security_left -= marker.quota
			security.append(marker)
		active[marker.id] = marker
	# Retain security workers, including those already inside a rival nest.
	for i in sim.colony_workers[colony]:
		if sim.worker_order_ids[i] < 0: continue
		var marker = active.get(sim.worker_order_ids[i])
		if sim.roles[i] == sim.RECOVERING:
			sim.worker_order_ids[i] = -1
			sim.worker_order_kinds[i] = 0
			continue
		if sim.health[i] <= 0 or marker == null or sim.colonies[i] != colony:
			release(i)
		elif marker.kind == FORAGE:
			release(i) # Reassign a bounded share below; cargo and travel state stay intact.
		elif marker.assigned < marker.quota:
			assign(i, marker)
		else: release(i)
	for marker in security:
		if marker.assigned >= marker.quota: continue
		var candidates: Array[int] = []
		for i in sim.colony_workers[colony]:
			if sim.health[i] > 0 and sim.roles[i] == sim.FORAGER and sim.layers[i] == -1 and sim.carrying[i] == 0 and sim.opponents[i] < 0:
				candidates.append(i)
		candidates.sort_custom(func(a: int, b: int) -> bool:
			if sim.castes[a] != sim.castes[b]: return sim.castes[a] > sim.castes[b]
			return sim.positions[a].distance_squared_to(marker.pos) < sim.positions[b].distance_squared_to(marker.pos))
		for i in candidates:
			if marker.assigned >= marker.quota: break
			if marker.has("roster"):
				if marker.roster.size() >= marker.recruit_cap: break
				if marker.roster.has(sim.worker_ids[i]): continue
			assign(i, marker)
			if marker.has("roster"): marker.roster[sim.worker_ids[i]] = i
	if not forage.is_empty():
		var remaining := int(population * [0.0, 0.1, 0.25, 0.5][labor[0]])
		for i in sim.colony_workers[colony]:
			if remaining <= 0: break
			if sim.health[i] <= 0 or sim.roles[i] != sim.FORAGER or sim.layers[i] != -1: continue
			var nearest: Dictionary = forage[0]
			var best: float = sim.positions[i].distance_squared_to(nearest.pos) / nearest.weight
			for marker in forage:
				var distance: float = sim.positions[i].distance_squared_to(marker.pos) / marker.weight
				if distance < best: nearest = marker; best = distance
			assign(i, nearest)
			remaining -= 1

func avoidance_direction(point: Vector2, goal: Vector2, worker: int) -> Vector2:
	if sim.avoid_points.is_empty(): return Vector2.ZERO
	var escape := Vector2.ZERO
	var inside := false
	for center in sim.avoid_points:
		var outward: Vector2 = point - center
		var distance := outward.length()
		if distance < AVOID_RADIUS + 18:
			inside = true
			escape += outward.normalized() if distance > 0.01 else Vector2.from_angle(worker * 2.39996)
	if inside:
		return escape.normalized() if escape.length_squared() > 0.01 else Vector2.from_angle(worker * 2.39996)
	var delta := goal - point
	var length := delta.length()
	if length < 0.01: return Vector2.ZERO
	var direction := delta / length
	var nearest := INF
	var result := Vector2.ZERO
	for center in sim.avoid_points:
		var toward: Vector2 = center - point
		var along := toward.dot(direction)
		if along <= 0 or along > length + AVOID_RADIUS + 18: continue
		if (toward - direction * along).length_squared() >= pow(AVOID_RADIUS + 18, 2) or along >= nearest: continue
		nearest = along
		var cross := delta.cross(toward)
		var side := (-1.0 if cross > 0 else 1.0) if absf(cross) > 0.001 else (-1.0 if worker % 2 else 1.0)
		var angle := toward.angle() + side * asin(minf(1, (AVOID_RADIUS + 18) / toward.length()))
		result = Vector2.from_angle(angle)
	return result

func safe_step(old: Vector2, proposed: Vector2) -> Vector2:
	for center in sim.avoid_points:
		if old.distance_squared_to(center) >= AVOID_RADIUS * AVOID_RADIUS and proposed.distance_squared_to(center) < AVOID_RADIUS * AVOID_RADIUS:
			return old
	return proposed
