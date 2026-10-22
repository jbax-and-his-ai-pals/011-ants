extends RefCounted
## Read-only observations. Does not steer workers or read hostile order goals.
const SECTOR := 96.0
const MEMORY := 20.0
const MAX_FOOD := 64
const FOOD_BUDGET := 64
var sim
var visible: Dictionary = {}
var explored: Dictionary = {}
var foods: Dictionary = {}
var contacts: Dictionary = {}
var tracks: Dictionary = {}
var activity: Dictionary = {}
var warnings: Dictionary = {}
var routes: Dictionary = {}
var rows: Array = []
var cursor := 0
var page := 0
var scans := 0
var last_scan_usec := 0
var max_scan_usec := 0
var panel: Panel
var button: Button
var banner: Button
var title: Label
var enemy_text: Label
var footer: Label
var food_buttons: Array[Button] = []
var territory_image: Image
var territory_texture: ImageTexture
func setup(owner_node) -> void: sim = owner_node
func sector(point: Vector2) -> Vector2i: return Vector2i(point / SECTOR)
func reset() -> void:
	visible.clear(); explored.clear(); foods.clear(); contacts.clear(); tracks.clear()
	activity.clear(); warnings.clear(); routes.clear(); rows.clear()
	cursor = 0; page = 0; scans = 0; max_scan_usec = 0
	if is_instance_valid(panel): panel.visible = false
	sample()
func reveal(cell: Vector2i) -> void:
	for y in range(-1, 2):
		for x in range(-1, 2):
			var key := cell + Vector2i(x, y)
			if key.x >= 0 and key.y >= 0 and key.x * SECTOR < sim.SIZE.x and key.y * SECTOR < sim.SIZE.y:
				visible[key] = true
				explored[key] = true
func observe_food(index: int) -> void:
	if index < 0 or index >= sim.foods.size():
		foods.erase(index)
		return
	var patch: Dictionary = sim.foods[index]
	if foods.has(index) and foods[index].pos != patch.pos: foods.erase(index)
	if patch.get("layer", -1) != -1 or patch.get("dropped", false) or not visible.has(sector(patch.pos)): return
	var old: Dictionary = foods.get(index,{})
	if old.is_empty(): sim.clarity.record("food", "Food sighted: " + ["sugar", "protein"][int(patch.get("resource",0))], patch.pos,-1,"food:%d" % index,60)
	elif old.amount > 0 and patch.amount == 0: sim.clarity.record("food", "Observed food depleted",patch.pos,-1,"depleted:%d" % index,30)
	foods[index] = {"pos": patch.pos, "amount": patch.amount, "resource": patch.get("resource", 0), "kind": patch.get("food_visual", index % 3), "seen": sim.elapsed}
func sample() -> void:
	var start := Time.get_ticks_usec()
	scans += 1
	visible.clear()
	var scout_cells := {}
	if sim.queen_health[0] > 0: scout_cells[sector(sim.HOME)] = true
	for i in sim.colony_workers[0]:
		if sim.health[i] > 0 and sim.layers[i] == -1: scout_cells[sector(sim.positions[i])] = true
	for key in scout_cells: reveal(key)
	for index in foods.keys(): observe_food(index)
	for n in mini(FOOD_BUDGET, sim.foods.size()):
		observe_food(cursor % sim.foods.size())
		cursor += 1
	# Public forecasts reveal a position/arrival, never its current stock.
	for index in sim.food_cycle.pending: observe_food(index)
	if foods.size() > MAX_FOOD:
		var oldest: Array = foods.keys()
		oldest.sort_custom(func(a, b): return foods[a].seen < foods[b].seen)
		for n in foods.size() - MAX_FOOD: foods.erase(oldest[n])
	var groups := {}
	var seen_groups := {}
	var now_contacts := {}
	for i in sim.health.size():
		if sim.health[i] <= 0 or sim.colonies[i] == 0: continue
		var c: int = sim.colonies[i]
		var inside: bool = sim.layers[i] == 0
		if not inside and (sim.layers[i] != -1 or not visible.has(sector(sim.positions[i]))): continue
		var point: Vector2 = sim.positions[i]
		var key := sector(point)
		if not inside: now_contacts[key] = now_contacts.get(key, 0) + 1
		if not seen_groups.has(c): seen_groups[c] = {"count": 0, "pos": Vector2.ZERO}
		seen_groups[c].count += 1
		seen_groups[c].pos += point
		if not inside and sim.roles[i] != sim.INVADER: continue
		var identity: int = sim.worker_ids[i]
		var distance: float = point.distance_to(sim.HOME)
		var previous: Dictionary = tracks.get(identity, {})
		var approaching := false
		var closing := 0.0
		if not previous.is_empty() and sim.elapsed > previous.time:
			closing = (previous.pos.distance_to(sim.HOME) - distance) / (sim.elapsed - previous.time)
			var motion: Vector2 = point - previous.pos
			var ahead: Vector2 = point + motion.normalized() * minf(distance, 1000)
			approaching = closing > 8 and Geometry2D.get_closest_point_to_segment(sim.HOME, point, ahead).distance_to(sim.HOME) < 230
		tracks[identity] = {"pos": point, "time": sim.elapsed}
		if inside or (sim.roles[i] == sim.INVADER and distance < 1000 and (approaching or distance < 260)):
			if not groups.has(c): groups[c] = {"count": 0, "pos": Vector2.ZERO, "distance": INF, "speed": 0.0, "inside": false}
			groups[c].count += 1; groups[c].pos += point
			groups[c].inside = groups[c].inside or inside
			if distance < groups[c].distance: groups[c].distance = distance; groups[c].speed = closing
	for key in now_contacts: contacts[key] = {"count": now_contacts[key], "time": sim.elapsed}
	for key in contacts.keys():
		if visible.has(key) and not now_contacts.has(key): contacts.erase(key)
		elif sim.elapsed - contacts[key].time > MEMORY: contacts.erase(key)
	for identity in tracks.keys():
		if sim.elapsed - tracks[identity].time > MEMORY: tracks.erase(identity)
	for c in seen_groups:
		activity[c] = {"count": seen_groups[c].count, "pos": seen_groups[c].pos / seen_groups[c].count, "seen": sim.elapsed}
	for c in groups:
		var group: Dictionary = groups[c]
		group.pos /= group.count
		group["seen"] = sim.elapsed
		group["eta"] = group.distance / clampf(group.speed, 20, 75)
		warnings[c] = group
	for c in warnings.keys():
		if not groups.has(c) and (warnings[c].inside or visible.has(sector(warnings[c].pos))): warnings.erase(c)
		elif sim.elapsed - warnings[c].seen > 12: warnings.erase(c)
	# Aggregate loss evidence once; route queries never scan every casualty.
	var loss_sectors := {}
	for n in range(sim.command_system.loss_head, sim.command_system.losses.size()):
		var loss: Dictionary = sim.command_system.losses[n]
		if loss.layer != -1 or sim.elapsed - loss.time > 30: continue
		var key := sector(loss.pos)
		loss_sectors[key] = loss_sectors.get(key, 0) + 1
	routes.clear()
	for index in foods: routes[index] = route_report(foods[index].pos, loss_sectors)
	rows = foods.keys()
	rows.sort_custom(func(a, b):
		if (foods[a].amount > 0) != (foods[b].amount > 0): return foods[a].amount > 0
		return foods[a].pos.distance_squared_to(sim.HOME) < foods[b].pos.distance_squared_to(sim.HOME))
	page = clampi(page, 0, maxi(0, (rows.size() - 1) / 6))
	refresh_territory()
	last_scan_usec = Time.get_ticks_usec() - start
	max_scan_usec = maxi(max_scan_usec, last_scan_usec)
func refresh_territory() -> void:
	if territory_image == null: territory_image = Image.create(ceili(sim.SIZE.x / SECTOR), ceili(sim.SIZE.y / SECTOR), false, Image.FORMAT_RGBA8)
	territory_image.fill(Color(0.02, 0.04, 0.03, .22))
	for key in explored: territory_image.set_pixel(key.x, key.y, Color(.55, .75, .5, .04))
	for key in visible: territory_image.set_pixel(key.x, key.y, Color(.5, .85, .7, .09))
	for key in contacts:
		if key.x >= 0 and key.y >= 0 and key.x < territory_image.get_width() and key.y < territory_image.get_height(): territory_image.set_pixel(key.x, key.y, Color(.9, .25, .2, .2))
	if territory_texture == null: territory_texture = ImageTexture.create_from_image(territory_image)
	else: territory_texture.update(territory_image)
func route_report(point: Vector2, losses: Dictionary = {}) -> Dictionary:
	var enemies := 0
	var deaths := 0
	for key in contacts:
		var center := (Vector2(key) + Vector2(.5, .5)) * SECTOR
		if Geometry2D.get_closest_point_to_segment(center, sim.HOME, point).distance_to(center) < 110: enemies = maxi(enemies, contacts[key].count)
	for key in losses:
		var center := (Vector2(key) + Vector2(.5, .5)) * SECTOR
		if Geometry2D.get_closest_point_to_segment(center, sim.HOME, point).distance_to(center) < 110: deaths += losses[key]
	var coverage := 0
	for n in 9:
		if explored.has(sector(sim.HOME.lerp(point, n / 8.0))): coverage += 1
	var danger := 2 if deaths >= 3 or enemies >= 8 else (1 if deaths > 0 or enemies > 0 else 0)
	var report: Dictionary = sim.strategic_garden.estimate(0, point)
	report.merge({"danger": danger, "enemies": enemies, "losses": deaths, "coverage": coverage, "text": "High danger" if danger == 2 else ("Contested" if danger == 1 else ("Partly scouted" if coverage < 9 else "No recent threats"))})
	return report
func toggle() -> void:
	sim.clarity.close_panels()
	sim.progression.panel.visible = false
	if not sim.match_result.is_empty() and not sim.result_dismissed: return
	panel.visible = not panel.visible
	if panel.visible:
		sim.order_panel.visible = false; sim.labor_panel.visible = false; sim.rival_panel.visible = false
	update_ui()
	sim.clarity.update_ui()
func focus_food(index: int) -> void:
	if not foods.has(index): return
	panel.visible = false
	sim.set_view(false); sim.camera_center = foods[index].pos; sim.camera_zoom = .9; sim._sync_camera()
func focus_warning() -> void:
	if warnings.is_empty(): return
	panel.visible = false
	sim.order_panel.visible = false; sim.labor_panel.visible = false; sim.rival_panel.visible = false
	var c = warnings.keys()[0]
	for key in warnings:
		if warnings[key].inside: c = key; break
	sim.inspected_colony = 0
	sim.set_view(warnings[c].inside)
	sim.camera_center = sim.queen_position(0) if warnings[c].inside else warnings[c].pos
	sim.camera_zoom = 1.2; sim._sync_camera()
func build_ui() -> void:
	button = sim._button("Scouting [T]", Vector2(970, 214), Vector2(220, 30), toggle)
	button.add_theme_font_size_override("font_size", 12)
	button.tooltip_text = "Shared reports from your ants' current and neighboring 96px sectors. Food quantities are last seen; route danger uses sightings (20s) and your losses (30s). T toggles reports and routes. The sandbox still draws live ants; this is not full fog of war."
	banner = sim._button("", Vector2(324, 214), Vector2(630, 30), focus_warning)
	banner.add_theme_font_size_override("font_size", 12)
	banner.add_theme_color_override("font_color", sim.RIVAL)
	banner.visible = false
	panel = Panel.new(); panel.position = Vector2(324, 254); panel.size = Vector2(630, 516)
	panel.add_theme_stylebox_override("panel", sim._style(Color("14251c"), 12, Color("58765c")))
	sim.ui.add_child(panel)
	var old = sim.ui; sim.ui = panel
	title = sim._label("SCOUTING & ROUTES", Vector2(18, 12), 16, sim.ACCENT, true, 460)
	sim._button("x", Vector2(583, 8), Vector2(30, 28), toggle)
	enemy_text = sim._label("", Vector2(18, 42), 12, sim.MUTED, false, 516); enemy_text.size.y = 52
	for n in 6:
		var row := n
		var b: Button = sim._button("", Vector2(18, 104 + n * 56), Vector2(594, 54), func():
			var slot := page * 6 + row
			if slot < rows.size(): focus_food(rows[slot]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size", 11)
		food_buttons.append(b)
	sim._button("Previous", Vector2(18, 448), Vector2(105, 28), func(): page = maxi(0, page - 1); update_ui())
	sim._button("Next", Vector2(132, 448), Vector2(105, 28), func(): page = mini(maxi(0, (rows.size() - 1) / 6), page + 1); update_ui())
	footer = sim._label("", Vector2(18, 482), 11, sim.MUTED, false, 594)
	sim.ui = old; panel.visible = false
func update_ui() -> void:
	if not is_instance_valid(button): return
	if not sim.match_result.is_empty() and not sim.result_dismissed: panel.visible = false
	button.text = "Scouting: %d sites [T]" % foods.size()
	banner.visible = not warnings.is_empty()
	var alerts: Array[String] = []
	for c in warnings:
		var w: Dictionary = warnings[c]
		var age := maxi(0, int(sim.elapsed - w.seen))
		alerts.append("%s %d %s%s" % [sim.COLONY_NAMES[c], w.count, "INSIDE NEST" if w.inside else ("approaching (~%ds)" % ceili(w.eta) if w.speed > 8 else "near entrance"), " · %ds old" % age if age > 1 else ""])
	var observed := 0
	for c in warnings: observed += int(warnings[c].count)
	var breached := false
	for c in warnings: breached = breached or warnings[c].inside
	banner.text = ("NEST BREACH · " if breached else ("SMALL RAID SIGHTING · " if observed <= 6 else "RAID REPORT · ")) + " / ".join(alerts)
	banner.tooltip_text = "Observed enemy raiders moving toward your entrance, or intruders in your nest. A small observed party may be a probe or part of a larger force. Travel estimates use observed closing speed, not AI orders. Reports expire 12 simulated seconds after last sighting. Click to focus."
	if not panel.visible: return
	var lines: Array[String] = []
	for c in range(1, sim.colony_count):
		if activity.has(c): lines.append("%s: %d observed · %ds ago" % [sim.COLONY_NAMES[c], activity[c].count, int(sim.elapsed - activity[c].seen)])
		else: lines.append("%s: no scout reports" % sim.COLONY_NAMES[c])
	enemy_text.text = "\n".join(lines) + "\n%d sectors explored · %d currently watched" % [explored.size(), visible.size()]
	for n in 6:
		var slot := page * 6 + n
		var b := food_buttons[n]; b.visible = slot < rows.size()
		if not b.visible: continue
		var index: int = rows[slot]
		var food: Dictionary = foods[index]
		var route: Dictionary = routes[index]
		b.text = "%s · %s %d seen %ds ago · %dpx\n~%.1fs round trip · %d%% soil / %d%% shade\n%s · %d losses · %d/9 sectors explored" % [["Fruit", "Nectar", "Insect"][food.kind], "Protein (brood)" if food.resource else "Sugar (upkeep)", food.amount, int(sim.elapsed - food.seen), route.distance, route.trip_seconds, route.soil, route.shade, route.text, route.losses, route.coverage]
		b.tooltip_text = "Click to focus; use 4 to place a Forage order or 5 to guard. Estimated straight-line surface round trip includes loaded return, soil and current colony speed. Excludes wandering, fights and underground delivery. Soil speeds workers; shade preserves trails, not protection from combat. Danger uses observed enemies (20s) and own losses (30s); unscouted travel remains uncertain. Stocks refresh only when watched."
	footer.size.y = 30
	footer.text = "Page %d/%d · Estimated surface trips; actual ants choose local steps.\nSoil: speed · shade: lasting trails · gold rings: public forecasts." % [page + 1, maxi(1, ceili(rows.size() / 6.0))]
func draw(canvas: CanvasItem) -> void:
	if sim.underground or not panel.visible: return
	if territory_texture: canvas.draw_texture_rect(territory_texture, Rect2(Vector2.ZERO, Vector2(territory_image.get_size()) * SECTOR), false)
	for n in 6:
		var slot := page * 6 + n
		if slot >= rows.size(): break
		var index: int = rows[slot]
		var point: Vector2 = foods[index].pos
		var tint: Color = [sim.GREEN, sim.ACCENT, sim.RIVAL][routes[index].danger]
		canvas.draw_line(sim.HOME, point, Color(tint, .65), 1.5 / sim.camera_zoom)
		canvas.draw_arc(point, 23, 0, TAU, 24, tint, 1.5 / sim.camera_zoom)
	var drawn := 0
	for key in contacts:
		var center := (Vector2(key) + Vector2(.5, .5)) * SECTOR
		if sim.visible_world_rect().has_point(center):
			canvas.draw_arc(center, 35, 0, TAU, 20, Color(sim.RIVAL, .7), 1.5 / sim.camera_zoom)
			drawn += 1
			if drawn >= 48: break
