extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)
func run() -> void:
	var s = load("res://main.tscn").instantiate()
	root.add_child(s)
	s.set_process(false)
	s.reset_colony(42)
	check(s.health.size() == 6000 and s.living_count(2) == 2000, "Three full individual populations")
	check(s.third_earth != s.earth and s.third_food_scent.size() == s.CELLS, "Third tunnels and scent are independent")
	check(not s.tunnel_route(s.entrance_cell(2), s._cell(s.queen_position(2)), 2).is_empty(), "Azure entrance connects to queen")
	for value in [0.25, 0.5]:
		s.elapsed = 0
		s.accumulator = 0
		s._set_speed(value)
		s._process(0.1)
		check(absf(s.elapsed + s.accumulator - 0.1 * value) < 0.001, "Fractional simulation speed %s" % value)
	s.reset_colony(42)
	s.reproduction_enabled = false
	s.invasions_enabled = false
	s.combat_enabled = false
	for tick in 120: s.simulate(s.STEP)
	check(s.third_ai.decisions > 0 and not s.third_ai.orders.markers.is_empty(), "Independent third AI chooses jobs")
	var trail_data: PackedByteArray = s.native_kernel.trail_pixels(s)
	var reference_image := Image.create(s.COLS, s.ROWS, false, Image.FORMAT_RGBA8)
	reference_image.fill(Color.TRANSPARENT)
	for j in s.active_scent:
		var color := Color(0.38, 0.7, 0.85, minf(s.home_scent[j] * 0.065, 0.16))
		color = color.blend(Color(0.68, 0.88, 0.4, minf(maxf(s.food_scent[j], s.protein_scent[j]) * 0.115, 0.48)))
		color = color.blend(Color(0.96, 0.43, 0.46, minf(maxf(s.rival_food_scent[j], s.rival_protein_scent[j]) * 0.115, 0.48)))
		color = color.blend(Color(0.35, 0.68, 0.96, minf(maxf(s.third_food_scent[j], s.third_protein_scent[j]) * 0.115, 0.48)))
		reference_image.set_pixel(j % s.COLS, j / s.COLS, color)
	var expected_data := reference_image.get_data()
	var byte_error := 0
	for j in expected_data.size(): byte_error = maxi(byte_error, absi(expected_data[j] - trail_data[j]))
	check(byte_error <= 1, "Native pheromone appearance matches reference to one RGBA8 quantization level")
	var dots: Dictionary = s.native_kernel.minimap_batch(s, s.SURFACE, s.MINI_MAP.position, s.MINI_MAP.size)
	var dot_index := 0
	var dot_error := 0.0
	for i in s.health.size():
		if s.health[i] <= 0 or s.layers[i] != s.SURFACE: continue
		var p: Vector2 = s.MINI_MAP.position + s.positions[i] / s.SIZE * s.MINI_MAP.size
		dot_error = maxf(dot_error, dots.points[dot_index * 2].distance_to(p - Vector2(0.6, 0)))
		check(dots.colors[dot_index] == s.colony_color(s.colonies[i]), "Minimap retains individual colony color")
		dot_index += 1
	check(dots.points.size() == dot_index * 2 and dot_error < 0.0001, "Native minimap preserves all individual positions")
	var old_remains: Array = s.remains.duplicate()
	s.remains = [{"pos": Vector2(100, 100), "colony": 0, "layer": -1, "time": 16.0}, {"pos": Vector2(120, 120), "colony": 2, "layer": -1, "time": 2.0}, {"pos": Vector2(110, 110), "colony": 1, "layer": 1, "time": 10.0}, {"pos": Vector2(300, 300), "colony": 1, "layer": -1, "time": 10.0}]
	var bodies: Dictionary = s.native_kernel.remains_batch(s, s.SURFACE, Rect2(0, 0, 200, 200))
	check(bodies.points.size() == 8 and bodies.colors.size() == 4, "Corpse batch preserves layer/viewport culling and both strokes")
	check(bodies.points[0] == Vector2(97, 97) and bodies.points[3] == Vector2(103, 97), "Corpse strokes retain geometry/order")
	check(is_equal_approx(bodies.colors[0].a, 0.65) and is_equal_approx(bodies.colors[2].a, 0.25), "Corpse fading retains simulated lifetime")
	s.remains = old_remains
	# Native transforms/colors must agree with the retained individual drawing path.
	s._resize_ant_batches()
	for zoom in [0.34, 1.5]:
		s.camera_zoom = zoom
		s.batch_counts.fill(0)
		var batch: Dictionary = s.native_kernel.visual_batch(s, Rect2(Vector2.ZERO, s.SIZE), s.SURFACE, zoom)
		for i in s.health.size():
			if s.health[i] > 0 and s.layers[i] == s.SURFACE: s._batch_ant(i)
		check(batch.counts == s.batch_counts, "Native visual instance counts preserve every visible worker/cargo")
		var maximum := 0.0
		for b in 3:
			for j in s.batch_counts[b] * 12: maximum = maxf(maximum, absf(batch.buffers[b][j] - s.ant_buffers[b][j]))
		check(maximum < 0.0001, "Native transforms/colors match individual drawing")
	# Exhaustive all-hostile-colony encounter oracle, including contact and layers.
	s.reset_colony(42)
	s.health.fill(0)
	for i in [0, s.COUNT, 2 * s.COUNT]:
		s.health[i] = 3
		s.positions[i] = Vector2(1600 + (i / s.COUNT) * 10, 800)
	for native in [true, false]:
		s.native_enabled = native
		s._prepare_encounters(s.STEP)
		check(s.opponents[0] == s.COUNT and s.opponents[2 * s.COUNT] == s.COUNT, "Both hostile colonies participate native=%s" % native)
	# Healing spends actual storage; no food means no recovery.
	var worker: int = 2 * s.COUNT
	s.positions[worker] = s.nest_position(2)
	s.roles[worker] = s.INVADER
	s.health[worker] = 1
	s.food_stores[2] = 0
	s._recover_worker(worker, 1)
	check(s.roles[worker] == s.RECOVERING and s.health[worker] == 1, "Wounded soldier seeks home but cannot heal without supplies")
	s.food_stores[2] = 2
	for second in 4: s._recover_worker(worker, 1)
	check(s.health[worker] > 2.99 and s.roles[worker] == s.FORAGER and s.food_stores[2] < 2, "Soldier recovers using its own food and rejoins workforce")
	s.roles[worker] = s.INVADER
	s.health[worker] = 1
	s.layers[worker] = 0
	s.positions[worker] = s._center(s.entrance_cell(0))
	s._recover_worker(worker, s.STEP)
	s._tunnel_mission(worker, s.STEP)
	check(s.layers[worker] == s.SURFACE and s.roles[worker] == s.RECOVERING, "Wounded invader exits through rival shaft before walking home")
	s.reset_colony(42)
	s.queen_health[1] = 0
	s._check_outcome()
	check(s.match_result.is_empty(), "First enemy elimination does not end three-colony match")
	s.place_surface_order(4, s.nest_position(1))
	check(s.command_system.markers[0].status == "Eliminated", "Dead enemy nests release persistent raid recruitment")
	s.queen_health[2] = 0
	s._check_outcome()
	check(s.match_result == "victory", "Both rival queens must die for victory")
	s.reset_colony(42)
	s.inspected_colony = 1
	s.underground = true
	s._inspect_nursery()
	check(s.inspected_colony == 2, "Nursery inspection cycles through third nest")
	# Exercise recovery through the real full tick. A recovered civilian may
	# subsequently join the automatic nursing crew in a small colony.
	for native in [true, false]:
		s.reset_colony(42)
		s.native_enabled = native
		s.rival_ai_enabled = false
		s.invasions_enabled = false
		s.reproduction_enabled = false
		s.combat_enabled = false
		s.health.fill(0)
		s.health[worker] = 1
		s.roles[worker] = s.WARDEN
		s.positions[worker] = s.nest_position(2) + Vector2(80, 0)
		for tick in 180: s.simulate(s.STEP)
		check(s.health[worker] > 2.99 and s.upkeep_spent[2] > 0 and s.roles[worker] in [s.FORAGER, s.NURSE], "Real ticks walk soldier home, spend food and return it to civilian work native=%s" % native)
	await process_frame
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_BRACKETLEFT
	root.push_input(key, true)
	check(s.speed == 0.25, "Quarter speed keyboard shortcut")
	key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_BRACKETRIGHT
	root.push_input(key, true)
	check(s.speed == 0.5, "Half speed keyboard shortcut")
	if failures == 0: print("PASS: 6000 individuals, third food/AI/tunnels, all-hostile encounters, fractional speeds, paid soldier recovery, tunnel retreat and elimination rules.")
	quit(1 if failures else 0)
