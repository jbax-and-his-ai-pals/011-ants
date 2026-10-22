extends RefCounted
## Seeded source alternatives and bounded geometric estimates, never worker routing.
var sim
var pairs: Array = []
var cache: Dictionary = {}
const SAMPLES := 32
const MAX_CACHE := 384

func prepare(owner_node) -> void:
	sim = owner_node
	pairs.clear(); cache.clear()
	if sim.colony_count != 3 or sim.legacy_map_layout or sim.wide_map_layout: return
	var center := Vector2.ZERO
	for c in 3: center += sim.nest_position(c)
	center /= 3
	for c in 3:
		var home: Vector2 = sim.nest_position(c)
		var random := RandomNumberGenerator.new()
		random.seed = sim.world_seed ^ (int(home.x) * 83492791) ^ (int(home.y) * 297121507)
		var axis := (center - home).normalized().rotated(random.randf_range(-.12, .12))
		var founding: bool = sim.game_mode == sim.game_modes.FOUNDING
		var short_length := random.randf_range(330, 360) if founding else random.randf_range(225, 245)
		var long_length := random.randf_range(490, 530) if founding else random.randf_range(345, 375)
		var side := -1 if random.randi_range(0, 1) == 0 else 1
		var short_point := home + axis.rotated(side * .60) * short_length
		var long_point := home + axis.rotated(-side * .60) * long_length
		pairs.append({"home": home, "short": short_point, "long": long_point})
		for kind in 2:
			var quantity := random.randi_range(110, 150) if kind == 0 else random.randi_range(400, 540)
			if not founding: quantity *= 20
			sim.foods.append({"pos": short_point if kind == 0 else long_point, "amount": quantity, "initial": quantity, "resource": kind, "food_visual": random.randi_range(0, 1) if kind == 0 else 2, "garden_site": true, "garden_route": "Exposed soil" if kind == 0 else "Shaded approach"})

func paint(garden) -> void:
	# Paint after incidental paths so each deliberate alternative remains legible.
	for pair in pairs:
		corridor(garden, pair.home, pair.short, false)
		corridor(garden, pair.home, pair.long, true)
	cache.clear()

func corridor(garden, home: Vector2, goal: Vector2, shaded: bool) -> void:
	var start := home.move_toward(goal, 65)
	var width := 34.0
	var lo: Vector2i = sim._cell(start.min(goal) - Vector2.ONE * width)
	var hi: Vector2i = sim._cell(start.max(goal) + Vector2.ONE * width)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var point: Vector2 = sim._center(Vector2i(x, y))
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, goal)) > width: continue
			var j: int = y * sim.COLS + x
			garden.ground[j] = 0 if shaded else 1
			sim.surface_shade[j] = 1 if shaded else 0
	if shaded:
		for n in range(1, 5):
			garden.details.append({"kind": 3, "pos": home.lerp(goal, n / 5.0) + (goal-home).orthogonal().normalized()*43, "angle": n * 1.7, "size": 29.0})

func geometry(home: Vector2, goal: Vector2) -> Dictionary:
	var key := Vector4(home.x, home.y, goal.x, goal.y)
	if cache.has(key): return cache[key]
	var distance := home.distance_to(goal)
	var weighted := 0.0
	var shaded := 0
	var soil := 0
	for n in SAMPLES:
		var j: int = sim._idx(sim._cell(home.lerp(goal, (n + .5) / SAMPLES)))
		weighted += 1.0 / sim.surface_speed[j]
		if sim.surface_shade[j]: shaded += 1
		if sim.surface_speed[j] > 1.01: soil += 1
	var value := {"distance": distance, "effective_distance": distance * weighted / SAMPLES, "shade": shaded * 100.0 / SAMPLES, "soil": soil * 100.0 / SAMPLES}
	if cache.size() >= MAX_CACHE: cache.clear()
	cache[key] = value
	return value

func estimate(colony: int, goal: Vector2) -> Dictionary:
	var data := geometry(sim.nest_position(colony), goal).duplicate()
	var speed_bonus := 1.08 if sim.doctrines[colony] == 1 else 1.0
	data["trip_seconds"] = data.effective_distance / speed_bonus * (1.0 / (52 * sim.foraging_multipliers[colony]) + 1.0 / 43)
	return data
