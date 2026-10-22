extends RefCounted
## Observation and presentation only. No worker goals, assignments or RNG writes.
const MAX_EVENTS := 96
const MAX_KEYS := 128
const PAGE_SIZE := 5
var sim
var events: Array = []
var cooldowns := {}
var order_reasons := {}
var order_states := {}
var work_rows: Array = []
var workforce := {"available": 0, "carrying": 0, "nurses": 0, "diggers": 0, "faces": 0}
var warning_states := {}
var ready_seen := false
var queen_ready_seen := false
var queen_danger := false
var last_result := ""
var next_id := 1
var page := 0
var objective_step := 1
var objective_text := ""
var history_panel: Panel
var work_panel: Panel
var history_button: Button
var work_button: Button
var tracker: Button
var history_rows: Array[Button] = []
var work_buttons: Array[Button] = []
var history_ids: Array[int] = []
var history_footer: Label
var work_header: Label
var last_sample_usec := 0
var max_sample_usec := 0
func setup(owner_node) -> void: sim = owner_node
func reset() -> void:
	events.clear(); cooldowns.clear(); order_reasons.clear(); order_states.clear(); work_rows.clear(); warning_states.clear()
	ready_seen = false; queen_ready_seen = false; queen_danger = false; last_result = ""
	history_ids.clear()
	next_id = 1; page = 0; objective_step = 1; objective_text = ""; max_sample_usec = 0
	if is_instance_valid(history_panel): history_panel.visible = false; work_panel.visible = false
func record(kind: String, text: String, point: Vector2, layer: int = -1, key: String = "", cooldown: float = 0) -> void:
	if not key.is_empty():
		if cooldowns.has(key) and sim.elapsed - cooldowns[key] < cooldown: return
		if cooldowns.size() >= MAX_KEYS and not cooldowns.has(key): cooldowns.erase(cooldowns.keys()[0])
		cooldowns[key] = sim.elapsed
	events.push_front({"id": next_id, "time": sim.elapsed, "kind": kind, "text": text, "pos": point, "layer": layer})
	next_id += 1
	if events.size() > MAX_EVENTS: events.pop_back()
	page = clampi(page, 0, maxi(0, (events.size()-1)/PAGE_SIZE))
func sample() -> void:
	var start := Time.get_ticks_usec()
	workforce = {"available": 0, "carrying": 0, "nurses": 0, "diggers": 0, "faces": 0}
	for i in sim.colony_workers[0]:
		if sim.health[i] <= 0: continue
		if sim.roles[i] == sim.NURSE: workforce.nurses += 1
		if sim.roles[i] == sim.DIGGER:
			workforce.diggers += 1
			if sim.targets[i] >= 0: workforce.faces += 1
		if sim.roles[i] == sim.FORAGER:
			if sim.carrying[i]: workforce.carrying += 1
			elif sim.layers[i] == -1 and sim.opponents[i] < 0: workforce.available += 1
	var active := {}
	order_reasons.clear()
	for marker in sim.command_system.markers:
		active[marker.id] = true
		var why := explain_order(marker)
		order_reasons[marker.id] = why
		if not order_states.has(marker.id) or order_states[marker.id].why != why:
			order_states[marker.id] = {"why": why, "since": sim.elapsed, "reported": false}
		var state: Dictionary = order_states[marker.id]
		if not state.reported and sim.elapsed - state.since >= 8 and marker.kind != sim.command_system.AVOID and (marker.status in ["Paused", "Blocked", "Depleted"] or marker.assigned == 0):
			record("work", "%s #%d: %s" % [sim.command_system.NAMES[marker.kind], marker.id, why], marker.pos, marker.get("layer", -1), "order:%d" % marker.id, 30)
			state.reported = true
	for id in order_states.keys():
		if not active.has(id): order_states.erase(id)
	for c in sim.scouting.warnings:
		var w: Dictionary = sim.scouting.warnings[c]
		var severity := 2 if w.inside else 1
		if warning_states.get(c, 0) < severity:
			record("breach" if w.inside else "raid", "%s: %s (%d observed)" % [sim.COLONY_NAMES[c], "Nest breach" if w.inside else "Raid sighting", w.count], sim.queen_position(0) if w.inside else w.pos, 0 if w.inside else -1, "threat:%d:%d" % [c,severity], 12)
		warning_states[c] = severity
	for c in warning_states.keys():
		if not sim.scouting.warnings.has(c): warning_states.erase(c)
	var danger: bool = sim.queen_health[0] > 0 and sim.queen_health[0] <= 50
	if danger and not queen_danger: record("queen", "Your queen is below 50% health", sim.queen_position(0), 0, "queen_danger", 30)
	queen_danger = danger
	if sim.game_mode == sim.game_modes.FOUNDING:
		if not ready_seen and sim.progression.choice_reason(0) == "Ready to specialize":
			ready_seen = true; record("development", "Specialization ready [P]", sim.HOME)
		if not queen_ready_seen and sim.progression.queen_reason(0) == "Ready to raise daughter":
			queen_ready_seen = true; record("development", "Daughter queen can now be started [P]", sim.queen_position(0), 0)
		cache_objective()
	cache_work()
	last_sample_usec = Time.get_ticks_usec()-start; max_sample_usec = maxi(max_sample_usec,last_sample_usec)
func explain_order(m: Dictionary) -> String:
	if m.kind == sim.command_system.AVOID: return "Avoid steers workers; it recruits no crew"
	if m.status == "Paused": return "Labor priority Off [L]"
	if m.status == "Blocked": return "Target conflicts with Avoid; move/remove a marker"
	if m.status == "Depleted": return "Known food depleted; move Forage to a discovered source"
	if m.status == "Eliminated": return "Target queen eliminated; choose a living rival"
	if str(m.status).begins_with("Food in"): return "Awaiting announced supplies; arrival is not a delivery"
	if m.kind == sim.command_system.FORAGE and sim.command_system.labor[0] > 0 and int(sim.living_count(0)*[0.0,0.1,0.25,0.5][sim.command_system.labor[0]]) == 0: return "Colony too small for the current marked-forage share"
	if m.kind in [sim.command_system.GUARD,sim.command_system.RAID] and m.get("quota",0) == 0: return "Shared security budget used by earlier posts [L]"
	if m.assigned == 0 and m.kind == sim.command_system.FORAGE and workforce.available > 0: return "Forage share goes to other routes; check distance/demand and [L]"
	if m.assigned == 0: return "No available crew: workers carrying, fighting or on other jobs"
	if m.kind == sim.command_system.FORAGE:
		if sim.storage_capacity[0] == 0: return "No connected storage: reconnect/excavate [8]"
		if sim.food_stores[0]+sim.protein_stores[0]+1 > sim.storage_capacity[0]: return "Storage full: returning loads cannot bank; expand [8]"
		return "Searching locally; nearby food and trails still guide pickups" if m.status == "Searching" else "Workers travel, collect and physically deliver; check route danger [T]"
	return "Crew active; travel, recovery and combat take time"
func cache_work() -> void:
	work_rows.clear()
	var queued: Dictionary = sim.dig_orders(0)
	var target: Vector2 = sim.queen_position(0)
	var reachable := false
	var scanned := 0
	for j in queued:
		if scanned >= 128: break
		var cell := Vector2i(j%sim.COLS,j/sim.COLS)
		if scanned == 0: target = sim._center(cell)
		scanned += 1
		for n in sim._neighbors(cell):
			if sim.exit_flow[sim._idx(n)] >= 0: reachable = true; break
		if reachable: break
	var digging := "No excavation queued"
	if not queued.is_empty():
		if sim.queen_health[0] <= 0: digging = "Queen lost; no excavation crew recruited"
		elif sim.command_system.digging_limit() == 0: digging = "Excavation paused by labor priority [L]"
		elif not reachable: digging = "No reachable face in checked plans; connect tunnels" if queued.size()>128 else "No reachable work face; connect plans to the entrance"
		elif workforce.diggers == 0: digging = "No available diggers; carriers/combat/jobs may occupy workers"
		elif workforce.faces == 0: digging = "Diggers travelling or waiting for a free work face"
		else: digging = "%d diggers; %d have soil targets (travel or excavation)" % [workforce.diggers,workforce.faces]
	work_rows.append({"title": "Excavation: %d queued tiles" % queued.size(), "why": digging, "pos": target, "layer": 0})
	var room_wait := {}; var scanned_rooms := 0
	for j in sim.chambers.room_tiles[0]:
		if scanned_rooms >= 128: break
		scanned_rooms += 1
		var kind: int = sim.chamber_rooms[j]
		if not room_wait.has(kind) and (sim.earth[j] != 1 or sim.exit_flow[j] < 0): room_wait[kind] = {"pos": sim._center(Vector2i(j%sim.COLS,j/sim.COLS)), "why": "Designated room still needs excavation" if sim.earth[j] != 1 else "Open room is disconnected from the entrance"}
	var storage := "Connected storage; carriers must walk inside to bank"
	if sim.storage_capacity[0] == 0: storage = "No connected storage; excavate/reconnect [8]"
	elif sim.food_stores[0]+sim.protein_stores[0]+1 > sim.storage_capacity[0]: storage = "Full: expand storage [8]; loaded workers cannot bank"
	elif room_wait.has(sim.chambers.STORAGE): storage = room_wait[sim.chambers.STORAGE].why
	work_rows.append({"title": "Storage: %d / %d" % [sim.food_stores[0]+sim.protein_stores[0],sim.storage_capacity[0]], "why": storage, "pos": room_wait.get(sim.chambers.STORAGE,{}).get("pos",sim.queen_position(0)), "layer": 0})
	var brood := "Brood developing; nurses deliver protein to actual tiles"
	var brood_pos: Vector2 = sim.queen_position(0)
	if sim.queen_health[0] <= 0: brood = "Queen lost; no new eggs; already paid brood may hatch"
	elif sim.game_mode == sim.game_modes.FOUNDING and not sim.progression.daughters[0].is_empty(): brood = "Worker eggs paused for daughter; existing brood finishes"
	elif sim.food_stores[0] < maxf(8,sim.upkeep_rate(0)*15): brood = "Breeding sugar reserve low; forage fruit/nectar"
	elif sim.brood_capacity[0] == 0: brood = "No connected brood tiles; excavate/reconnect [9]"
	elif room_wait.has(sim.chambers.BROOD): brood = room_wait[sim.chambers.BROOD].why; brood_pos = room_wait[sim.chambers.BROOD].pos
	elif sim.brood[0].size() >= sim.brood_capacity[0]: brood = "All worker brood slots occupied; expand [9]"
	for young in sim.brood[0]:
		if young.stage >= 2 or young.age < sim.stage_duration(0,young.stage): continue
		var cost: int = int(sim.stage_feed_cost(0,young.stage))+(4 if young.stage==1 and young.get("caste",0) else 0)
		var j: int = young.get("cell",-1)
		if sim.protein_stores[0] < cost: brood = "Protein short: forage insect food [4]"; break
		if j >= 0 and sim.brood_buffers[j] < cost:
			brood = "Banked protein awaits nurses at brood tiles" if workforce.nurses > 0 else "Banked protein; no nurses recruited yet"
			brood_pos = sim._center(Vector2i(j%sim.COLS,j/sim.COLS)); break
	work_rows.append({"title": "Brood: %d / %d slots | nurses %d" % [sim.brood[0].size(),sim.brood_capacity[0],workforce.nurses], "why": brood, "pos": brood_pos, "layer": 0})
	var d: Dictionary = sim.progression.daughters[0]
	if sim.game_mode == sim.game_modes.FOUNDING and not d.is_empty():
		work_rows.append({"title": "Daughter: %s / %d%%" % [sim.progression.stage_name(0),d.progress/240.0*100], "why": "%s | local P %d/4" % [d.status,sim.brood_buffers[d.cell]], "pos": sim._center(Vector2i(d.cell%sim.COLS,d.cell/sim.COLS)), "layer": 0})
	for m in sim.command_system.markers:
		if work_rows.size() >= 6: break
		if m.kind == sim.command_system.AVOID: continue
		work_rows.append({"title": "%s #%d: %d assigned" % [sim.command_system.NAMES[m.kind],m.id,m.assigned], "why": order_reasons.get(m.id,"Waiting for assignment refresh"), "pos": m.pos, "layer": m.get("layer",-1)})
func cache_objective() -> void:
	var p = sim.progression
	var population: int = sim.living_count(0)
	var d: Dictionary = p.daughters[0]
	if not d.is_empty():
		objective_step = 4
		objective_text = "[4/4] Raise daughter: %d%% (%d/240 fed s)\n%s\nClick to inspect daughter and development" % [d.progress/240.0*100,d.progress,d.status]
	elif p.paths[0] == p.NONE:
		objective_step = 1
		objective_text = "[1/4] Specialize [P] | workers %d/40\n40 sugar + 12 free protein\n%s" % [population,p.choice_reason(0)]
	elif sim.brood_capacity[0] < p.QUEEN_CAPACITY:
		objective_step = 2
		objective_text = "[2/4] Expand connected nursery [9]\n%d/24 brood slots | workers %d/80\nClick to plan a brood chamber in your nest" % [sim.brood_capacity[0],population]
	else:
		objective_step = 3
		objective_text = "[3/4] Prepare daughter [P]\nWorkers %d/80 | free protein %d/20\n%s" % [population,p.free_protein(0),p.queen_reason(0)]
func close_panels() -> void:
	history_panel.visible = false; work_panel.visible = false
func dismiss_others() -> void:
	sim.progression.panel.visible = false; sim.scouting.panel.visible = false
	sim.rival_panel.visible = false; sim.order_panel.visible = false; sim.labor_panel.visible = false
func toggle_history() -> void:
	var show := not history_panel.visible
	dismiss_others(); close_panels(); history_panel.visible = show; update_ui()
func toggle_work() -> void:
	var show := not work_panel.visible
	dismiss_others(); close_panels(); work_panel.visible = show; update_ui()
func focus(point: Vector2, layer: int) -> void:
	close_panels(); dismiss_others()
	sim.inspected_colony = maxi(0,layer); sim.set_view(layer >= 0)
	sim.camera_center = point; sim.camera_zoom = 1.3; sim._sync_camera()
func focus_event(id: int) -> void:
	for event in events:
		if event.id == id: focus(event.pos,event.layer); return
func objective_action() -> void:
	if objective_step == 2:
		focus(sim.queen_position(0),0); sim.set_chamber_tool(2)
	elif objective_step == 4 and not sim.progression.daughters[0].is_empty():
		var j: int = sim.progression.daughters[0].cell
		focus(sim._center(Vector2i(j%sim.COLS,j/sim.COLS)),0); sim.progression.toggle()
	else:
		close_panels(); sim.progression.toggle()
func contains(point: Vector2) -> bool:
	for node in [history_button,work_button,tracker,history_panel,work_panel]:
		if is_instance_valid(node) and node.visible and Rect2(node.position,node.size).has_point(point): return true
	return false
func build_ui() -> void:
	history_button = sim._button("Events [E]",Vector2(1208,320),Vector2(182,30),toggle_history)
	work_button = sim._button("Work report [B]",Vector2(1208,358),Vector2(182,30),toggle_work)
	tracker = sim._button("",Vector2(324,250),Vector2(386,116),objective_action)
	tracker.add_theme_font_size_override("font_size",12); tracker.alignment = HORIZONTAL_ALIGNMENT_LEFT
	history_panel = Panel.new(); history_panel.position = Vector2(324,390); history_panel.size = Vector2(630,370)
	work_panel = Panel.new(); work_panel.position = Vector2(750,290); work_panel.size = Vector2(640,470)
	for node in [history_panel,work_panel]:
		node.add_theme_stylebox_override("panel",sim._style(Color("17251f"),10,Color("58765c"))); sim.ui.add_child(node); node.visible = false
	var previous = sim.ui; sim.ui = history_panel
	sim._label("EVENT HISTORY / OBSERVED POSITIONS",Vector2(18,12),16,sim.ACCENT,true,550)
	sim._button("x",Vector2(582,8),Vector2(30,28),toggle_history)
	for n in PAGE_SIZE:
		var b = sim._button("",Vector2(18,52+n*54),Vector2(594,48),func():
			if n < history_ids.size(): focus_event(history_ids[n]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size",12); history_rows.append(b)
	sim._button("Newer",Vector2(18,328),Vector2(86,28),func(): page = maxi(0,page-1); update_ui())
	sim._button("Older",Vector2(112,328),Vector2(86,28),func(): page = mini(maxi(0,(events.size()-1)/PAGE_SIZE),page+1); update_ui())
	history_footer = sim._label("",Vector2(210,334),11,sim.MUTED,false,400)
	sim.ui = work_panel
	sim._label("WORK REPORT / WHY IS THIS WAITING?",Vector2(18,12),16,sim.ACCENT,true,570)
	sim._button("x",Vector2(592,8),Vector2(30,28),toggle_work)
	work_header = sim._label("",Vector2(18,47),12,sim.MUTED,false,604)
	for n in 6:
		var b = sim._button("",Vector2(18,82+n*54),Vector2(604,48),func():
			if n < work_rows.size(): focus(work_rows[n].pos,work_rows[n].layer))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size",12); work_buttons.append(b)
	sim._label("O: every order's explanation | L: labor | click a row to inspect\nPlans checked in bounded samples; observations refresh every 0.8s.",Vector2(18,414),12,sim.MUTED,false,604)
	sim.ui = previous
func update_ui() -> void:
	if not is_instance_valid(tracker): return
	if sim.paused: sample()
	elif sim.game_mode == sim.game_modes.FOUNDING: cache_objective()
	if not sim.match_result.is_empty() and sim.match_result != last_result:
		last_result = sim.match_result; record("outcome",sim.message,sim.queen_position(0),0)
	if not sim.match_result.is_empty() and not sim.result_dismissed: close_panels()
	tracker.visible = sim.game_mode == sim.game_modes.FOUNDING and (sim.match_result.is_empty() or sim.result_dismissed) and not sim.scouting.panel.visible and not sim.order_panel.visible and not sim.labor_panel.visible
	var lines := PackedStringArray()
	for line in objective_text.split("\n"): lines.append(line if line.length()<=54 else line.left(51)+"...")
	tracker.text = "\n".join(lines)
	tracker.tooltip_text = "Founding objective: specialize, expand connected nursery, prepare and raise a daughter. Click for the next planning action.\n" + objective_text
	var right_busy: bool = sim.progression.panel.visible or sim.rival_panel.visible or work_panel.visible
	history_button.visible = not right_busy; work_button.visible = not right_busy
	history_button.text = "Events %d [E]" % events.size()
	if history_panel.visible:
		history_ids.clear()
		for n in PAGE_SIZE:
			var index := page*PAGE_SIZE+n
			history_rows[n].visible = index < events.size()
			if index >= events.size(): continue
			var e: Dictionary = events[index]; history_ids.append(e.id)
			history_rows[n].text = "%02d:%02d  %s\n%s | observed position; may be stale" % [int(e.time)/60,int(e.time)%60,e.text.left(76),"Surface" if e.layer<0 else "Your nest"]
			history_rows[n].add_theme_color_override("font_color",sim.RIVAL if e.kind in ["raid","breach","queen"] else sim.INK)
			history_rows[n].tooltip_text = e.text+"\nRecorded at %.1f simulated seconds. Clicking focuses the recorded position, not a hidden live target." % e.time
		history_footer.text = "Page %d/%d | %d retained (max %d)" % [page+1,maxi(1,ceili(events.size()/float(PAGE_SIZE))),events.size(),MAX_EVENTS]
	if work_panel.visible:
		work_header.text = "Available %d | carrying %d | nurses %d | free P %d" % [workforce.available,workforce.carrying,workforce.nurses,sim.progression.free_protein(0)]
		for n in 6:
			work_buttons[n].visible = n < work_rows.size()
			if n >= work_rows.size(): continue
			var row: Dictionary = work_rows[n]
			work_buttons[n].text = row.title+"\n"+row.why
			work_buttons[n].tooltip_text = row.why
