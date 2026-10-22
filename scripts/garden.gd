extends RefCounted
## Seeded, cached scenery. Only soil speed and shade retention affect ants.
const NAMES := ["Meadow", "Bare soil +15%", "Leaf litter", "Damp earth"]
const COLORS := [Color("43513a"), Color("8a7050"), Color("68523b"), Color("354c43")]
var sim
var ground := PackedByteArray()
var picture: ImageTexture
var details: Array = []

func build(owner_node) -> void:
	sim = owner_node
	ground.resize(sim.CELLS)
	ground.fill(0)
	sim.surface_speed.resize(sim.CELLS)
	sim.surface_speed.fill(1.0)
	sim.surface_shade.resize(sim.CELLS)
	sim.surface_shade.fill(0)
	details.clear()
	var random := RandomNumberGenerator.new()
	random.seed = sim.world_seed ^ 0x6723a51b
	# Soft, irregular-looking patches; their litter/moisture is decorative.
	for n in 64:
		var center := Vector2(random.randf_range(30, sim.SIZE.x - 30), random.randf_range(30, sim.SIZE.y - 30))
		var radius := Vector2(random.randf_range(85, 220), random.randf_range(65, 160))
		paint_patch(center, radius, 2 if n % 3 else 3, false)
	for n in 22:
		var center := Vector2(random.randf_range(100, sim.SIZE.x - 100), random.randf_range(100, sim.SIZE.y - 100))
		var radius := Vector2(random.randf_range(100, 210), random.randf_range(75, 150))
		paint_patch(center, radius, -1, true)
		# Small rosettes mark the plant cover responsible for shade.
		details.append({"kind": 3, "pos": center + Vector2(radius.x * 0.65, -radius.y * 0.4), "angle": random.randf_range(0, TAU), "size": random.randf_range(30, 47)})
	# Connected, gently curved soil routes between nests and out to food sectors.
	for c in sim.colony_count:
		var start: Vector2 = sim.nest_position(c)
		var finish: Vector2 = sim.nest_position((c + 1) % sim.colony_count)
		var control := (start + finish) / 2 + (finish - start).orthogonal().normalized() * 65
		var previous := start
		for n in range(1, 21):
			var t := n / 20.0
			var point := (1 - t) * (1 - t) * start + 2 * (1 - t) * t * control + t * t * finish
			paint_path(previous, point, 29)
			previous = point
		var center := Vector2.ZERO
		for other in sim.colony_count: center += sim.nest_position(other)
		center /= sim.colony_count
		paint_path(start, start + (start - center).normalized() * 410, 24)
	sim.strategic_garden.paint(self)
	for j in sim.CELLS:
		if sim.garden_effects_enabled and ground[j] == 1: sim.surface_speed[j] = 1.15
		if not sim.garden_effects_enabled: sim.surface_shade[j] = 0
	refresh_picture()
	for n in 1400:
		var point := Vector2(random.randf_range(15, sim.SIZE.x - 15), random.randf_range(15, sim.SIZE.y - 15))
		var kind: int = ground[sim._idx(sim._cell(point))]
		if kind == 1: continue
		details.append({"kind": 0 if kind == 0 else (1 if kind == 2 else 2), "pos": point, "angle": random.randf_range(0, TAU), "size": random.randf_range(6, 16)})

func refresh_picture() -> void:
	var image := Image.create(sim.COLS, sim.ROWS, false, Image.FORMAT_RGBA8)
	for y in sim.ROWS:
		for x in sim.COLS:
			var j: int = y * sim.COLS + x
			var hash_value: int = posmod(x * 374761393 + y * 668265263 + sim.world_seed, 65521)
			var color: Color = COLORS[ground[j]]
			color = color.lightened((hash_value % 17) * 0.0025) if hash_value % 2 else color.darkened((hash_value % 19) * 0.003)
			if sim.surface_shade[j]: color = color.darkened(0.30).lerp(Color("304545"), 0.16)
			image.set_pixel(x, y, color)
	picture = ImageTexture.create_from_image(image)

func paint_patch(center: Vector2, radius: Vector2, kind: int, shade: bool) -> void:
	var lo: Vector2i = sim._cell(center - radius)
	var hi: Vector2i = sim._cell(center + radius)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var delta: Vector2 = (sim._center(Vector2i(x, y)) - center) / radius
			var edge := 1.0 + sin(delta.angle() * 5 + center.x) * 0.09
			if delta.length_squared() > edge: continue
			var j: int = y * sim.COLS + x
			if kind >= 0: ground[j] = kind
			if shade: sim.surface_shade[j] = 1

func paint_path(start: Vector2, finish: Vector2, width: float) -> void:
	var lo: Vector2i = sim._cell(start.min(finish) - Vector2.ONE * width)
	var hi: Vector2i = sim._cell(start.max(finish) + Vector2.ONE * width)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var point: Vector2 = sim._center(Vector2i(x, y))
			if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, start, finish)) < width * width:
				ground[y * sim.COLS + x] = 1

func ground_name(point: Vector2) -> String:
	var j: int = sim._idx(sim._cell(point))
	return NAMES[ground[j]] + (" · Shade 2× trails" if sim.surface_shade[j] else "")

func draw_decor(canvas: CanvasItem) -> void:
	canvas.draw_texture_rect(picture, Rect2(Vector2.ZERO, sim.SIZE), false)
	for detail in details:
		var p: Vector2 = detail.pos
		var axis: Vector2 = Vector2.from_angle(detail.angle) * detail.size
		match detail.kind:
			0:
				canvas.draw_line(p, p + axis, Color("64734d"), 1.2)
				canvas.draw_line(p + Vector2(3, 0), p + axis.rotated(0.5), Color("536641"), 1)
			1:
				leaf(canvas, p, axis, Color("987044") if int(p.x) % 2 else Color("806240"))
			2:
				canvas.draw_circle(p, detail.size * 0.45, Color("426653"))
				canvas.draw_circle(p + Vector2(3, -2), detail.size * 0.25, Color("53745a"))
			3:
				canvas.draw_circle(p + Vector2(5, 8), detail.size * 0.8, Color("253a30"))
				for petal in 5:
					leaf(canvas, p, axis.rotated(petal * TAU / 5), Color("50704b") if petal % 2 else Color("5d7950"))
	for p in sim.stones:
		canvas.draw_circle(p + Vector2(3, 4), 13, Color("26362d"))
		canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, 3), p + Vector2(-7, -8), p + Vector2(4, -10), p + Vector2(12, -1), p + Vector2(6, 8)]), Color("777568"))
		canvas.draw_line(p + Vector2(-6, -7), p + Vector2(3, -9), Color("989382"), 2)

static func leaf(canvas: CanvasItem, p: Vector2, axis: Vector2, tint: Color) -> void:
	var side := axis.orthogonal() * 0.35
	canvas.draw_colored_polygon(PackedVector2Array([p - axis * 0.6, p + side, p + axis, p - side]), tint)
	canvas.draw_line(p - axis * 0.45, p + axis * 0.8, tint.darkened(0.24), 1)

static func draw_food(canvas: CanvasItem, patch: Dictionary, index: int) -> void:
	var p: Vector2 = patch.pos
	var kind: int = patch.get("food_visual", patch.get("cycle_site", index) % 3)
	canvas.draw_circle(p + Vector2(2, 4), 23, Color(0.08, 0.12, 0.08, 0.3))
	match kind:
		0:
			for offset in [Vector2(-9, 3), Vector2(8, 4), Vector2(0, -8)]:
				canvas.draw_circle(p + offset, 10, Color("b85e51"))
				canvas.draw_circle(p + offset + Vector2(-3, -3), 3, Color("db8b67"))
			leaf(canvas, p + Vector2(5, -16), Vector2(14, -6), Color("769252"))
		1:
			for petal in 5:
				canvas.draw_circle(p + Vector2.from_angle(petal * TAU / 5) * 12, 8, Color("dacb92"))
			canvas.draw_circle(p, 9, Color("dba54d"))
			canvas.draw_circle(p + Vector2(-2, -2), 4, Color("f1d583"))
		2:
			for side in [-1, 1]:
				for leg in 3:
					var root := p + Vector2(leg * 8 - 7, 0)
					canvas.draw_line(root, root + Vector2(-5, side * 15), Color("aa9671"), 2)
			canvas.draw_circle(p + Vector2(-10, 0), 11, Color("777261"))
			canvas.draw_circle(p + Vector2(4, 0), 8, Color("918568"))
			canvas.draw_circle(p + Vector2(15, 0), 6, Color("655e50"))
			canvas.draw_line(p + Vector2(-11, -8), p + Vector2(-11, 8), Color("aaa082"), 1.5)
			canvas.draw_line(p + Vector2(19, -3), p + Vector2(27, -9), Color("aa9671"), 1.5)
			canvas.draw_line(p + Vector2(19, 3), p + Vector2(27, 9), Color("aa9671"), 1.5)
