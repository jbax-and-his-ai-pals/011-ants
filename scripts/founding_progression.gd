extends RefCounted
## Founding-only development. No worker RNG or Skirmish decisions are consumed.
const NONE := 0
const FORAGING := 1
const SOLDIERS := 2
const NAMES := ["Undeveloped", "Foraging", "Soldier brood"]
const CHOICE_SUGAR := 40.0
const CHOICE_PROTEIN := 12.0
const QUEEN_POPULATION := 80
const QUEEN_CAPACITY := 24
const QUEEN_SECONDS := 240.0
var sim
var paths := PackedInt32Array([0, 0, 0])
var soldier_counts := PackedInt32Array([0, 0, 0])
var preparation_reserves := PackedInt32Array([0, 0, 0])
var egg_sequence := PackedInt32Array([0, 0, 0])
var daughters: Array = [{}, {}, {}]
var ai_clock := 0.0
var panel: Panel
var button: Button
var details: Label
var forage_button: Button
var soldier_button: Button
var queen_button: Button
func setup(owner_node) -> void: sim = owner_node
func enabled() -> bool: return sim.game_mode == sim.game_modes.FOUNDING
func reset() -> void:
	paths.fill(0); soldier_counts.fill(0); egg_sequence.fill(0); preparation_reserves.fill(0)
	daughters = [{}, {}, {}]; ai_clock = 0
	sim.foraging_multipliers.fill(1.0)
	if is_instance_valid(panel): panel.visible = false
func free_protein(c: int) -> float:
	return maxf(0, sim.protein_stores[c] - sim.chambers.buffered[c] - sim.chambers.reserved[c])
func choice_reason(c: int) -> String:
	if not enabled(): return "Founding only"
	if not sim.match_result.is_empty() or sim.queen_health[c] <= 0: return "Match ended or queen lost"
	if paths[c] != NONE: return "Specialization chosen for this match"
	if sim.living_count(c) < 40: return "Grow to 40 workers"
	if sim.food_stores[c] < CHOICE_SUGAR + sim.upkeep_rate(c) * 30: return "Need 40 sugar plus 30 seconds of upkeep"
	if free_protein(c) < CHOICE_PROTEIN: return "Need 12 unallocated protein (room and nurse loads are reserved)"
	return "Ready to specialize"
func choose(c: int, path: int) -> bool:
	if path not in [FORAGING, SOLDIERS] or choice_reason(c) != "Ready to specialize": return false
	sim.food_stores[c] -= CHOICE_SUGAR; sim.protein_stores[c] -= CHOICE_PROTEIN
	sim.brood_spent[c] += CHOICE_PROTEIN; sim.upkeep_spent[c] += CHOICE_SUGAR
	paths[c] = path
	if c == 0: sim.clarity.record("development", "Specialization chosen: " + NAMES[path],sim.HOME)
	if path == FORAGING: sim.foraging_multipliers[c] = 1.15
	return true
func egg_caste(c: int) -> int:
	if not enabled() or paths[c] != SOLDIERS: return 0
	egg_sequence[c] += 1
	return 1 if egg_sequence[c] % 5 == 0 else 0
func born(i: int, caste: int) -> void:
	sim.castes[i] = caste if enabled() else 0
	if sim.castes[i]:
		sim.max_health[i] = 5; sim.health[i] = 5
		soldier_counts[sim.colonies[i]] += 1
func died(i: int) -> void:
	if sim.castes[i]: soldier_counts[sim.colonies[i]] = maxi(0, soldier_counts[sim.colonies[i]] - 1)
func occupied_cell(c: int) -> int:
	return int(daughters[c].get("cell", -1)) if enabled() else -1
# Cache at the strategy cadence; nurse trips only read three scalar holds.
# Existing carried/buffered protein remains assigned and is never reclaimed.
func refresh_preparation() -> void:
	preparation_reserves.fill(0)
	if not enabled(): return
	for c in sim.colony_count:
		if paths[c] != NONE and daughters[c].is_empty() and sim.queen_health[c] > 0 and sim.brood_capacity[c] >= QUEEN_CAPACITY and sim.living_count(c) >= QUEEN_POPULATION:
			preparation_reserves[c] = 20
func queen_reason(c: int) -> String:
	if not enabled(): return "Founding only"
	if not sim.match_result.is_empty() or sim.queen_health[c] <= 0: return "Match ended or queen lost"
	if not daughters[c].is_empty(): return "Daughter already being raised"
	if paths[c] == NONE: return "Choose a specialization first"
	if sim.living_count(c) < QUEEN_POPULATION: return "Grow to 80 workers"
	if not sim.chambers_enabled or sim.brood_capacity[c] < QUEEN_CAPACITY: return "Expand to 24 connected brood slots [9]"
	if sim.invaders_in(c) > 0: return "Clear nest intruders first"
	if sim.food_stores[c] < 60 + sim.upkeep_rate(c) * 60: return "Need 60 sugar plus 60 seconds of upkeep"
	if free_protein(c) < 20: return "Need 20 unallocated protein"
	if empty_cell(c) < 0: return "Need one empty connected brood tile (two slots)"
	return "Ready to raise daughter"
func empty_cell(c: int) -> int:
	var used := {}
	for young in sim.brood[c]: used[young.get("cell", -1)] = true
	for j in sim.chambers.brood_cells[c]:
		if not used.has(j): return j
	return -1
func start_daughter(c: int) -> bool:
	if queen_reason(c) != "Ready to raise daughter": return false
	var cell := empty_cell(c)
	sim.food_stores[c] -= 60; sim.protein_stores[c] -= 20
	sim.upkeep_spent[c] += 60; sim.brood_spent[c] += 20
	preparation_reserves[c] = 0
	if c == 0: sim.clarity.record("daughter","Daughter queen started",sim._center(Vector2i(cell%sim.COLS,cell/sim.COLS)),c)
	daughters[c] = {"cell": cell, "progress": 0.0, "clock": 0.0, "complete": false, "status": "Nurses supplying daughter"}
	return true
func tick(dt: float) -> void:
	if not enabled(): return
	ai_clock += dt
	if ai_clock >= 3:
		ai_clock = 0
		refresh_preparation()
		for c in range(1, sim.colony_count):
			if paths[c] == NONE: choose(c, FORAGING if (sim.world_seed + c) % 2 == 0 else SOLDIERS)
			if daughters[c].is_empty(): start_daughter(c)
	for c in sim.colony_count:
		var d: Dictionary = daughters[c]
		if d.is_empty() or d.complete: continue
		if sim.queen_health[c] <= 0: d.status = "Home queen lost"; continue
		if d.cell not in sim.chambers.brood_cells[c]: d.status = "Reconnect daughter's brood tile"; continue
		if sim.invaders_in(c) > 0: d.status = "Paused: nest breach"; continue
		if sim.food_stores[c] < 6 + maxf(8, sim.upkeep_rate(c) * 30): d.status = "Paused: sugar reserve low"; continue
		d.clock = minf(8, d.clock + dt)
		if d.clock < 8: d.status = "Growing: nurses supplying protein"; continue
		if not sim.chambers.feed(c, d, 4): d.status = "Waiting for 4 protein at daughter tile"; continue
		sim.protein_stores[c] -= 4; sim.brood_spent[c] += 4
		sim.food_stores[c] -= 6; sim.upkeep_spent[c] += 6
		d.clock = 0; d.progress += 8
		if d.progress >= QUEEN_SECONDS: d.complete = true; d.status = "Daughter queen launched"
		if c == 0 and int(d.progress) in [64,160,240]: sim.clarity.record("daughter","Daughter: " + stage_name(c),sim._center(Vector2i(d.cell%sim.COLS,d.cell/sim.COLS)),c)
func outcome() -> String:
	var ours: bool = not daughters[0].is_empty() and daughters[0].complete
	var rival := false
	for c in range(1, sim.colony_count):
		if not daughters[c].is_empty() and daughters[c].complete and sim.queen_health[c] > 0: rival = true
	if sim.queen_health[0] <= 0: return "draw" if sim.queen_health.count(0.0) == sim.colony_count else "defeat"
	if ours and rival: return "draw"
	if ours: return "victory"
	if rival: return "defeat"
	return ""
func stage_name(c: int) -> String:
	if daughters[c].is_empty(): return "Not started"
	var progress: float = daughters[c].progress
	return "Launched" if daughters[c].complete else ("Egg" if progress < 64 else ("Larva" if progress < 160 else "Pupa"))
func toggle() -> void:
	sim.clarity.close_panels()
	if not enabled(): return
	panel.visible = not panel.visible
	if panel.visible:
		sim.scouting.panel.visible = false; sim.rival_panel.visible = false
		sim.order_panel.visible = false; sim.labor_panel.visible = false
	update_ui()
	sim.clarity.update_ui()
func action(path: int) -> void:
	choose(0, path); sim._update_ui()
func build_ui() -> void:
	button = sim._button("Development [P]", Vector2(970, 250), Vector2(220, 30), toggle)
	panel = Panel.new(); panel.position = Vector2(750, 290); panel.size = Vector2(640, 470)
	panel.add_theme_stylebox_override("panel", sim._style(Color("17251f"), 10, Color("58765c")))
	sim.ui.add_child(panel)
	var title = sim._label("FOUNDING / COLONY DEVELOPMENT", Vector2(18, 14), 17, sim.ACCENT, true, 580)
	title.reparent(panel, false)
	details = sim._label("", Vector2(18, 49), 13, sim.INK, false, 604); details.reparent(panel, false)
	forage_button = sim._button("Foraging: +15% unloaded speed", Vector2(18, 291), Vector2(295, 36), func(): action(FORAGING)); forage_button.reparent(panel, false)
	soldier_button = sim._button("Soldier brood: 1 in 5 eggs", Vector2(325, 291), Vector2(295, 36), func(): action(SOLDIERS)); soldier_button.reparent(panel, false)
	queen_button = sim._button("Begin daughter queen: 60 S / 20 P", Vector2(18, 337), Vector2(602, 36), func(): start_daughter(0); sim._update_ui()); queen_button.reparent(panel, false)
	var hint = sim._label("Specialization costs 40 sugar + 12 free protein; one choice per match.\nDaughter: 80 workers, 24 connected brood slots, one empty tile.\nThen 240 fed seconds: 6 sugar + 4 nurse-delivered protein per 8s.\nWorker egg laying pauses during the project. First launch wins.", Vector2(18, 385), 12, sim.MUTED, false, 604); hint.reparent(panel, false)
	var close = sim._button("x", Vector2(596, 10), Vector2(30, 28), toggle); close.reparent(panel, false)
	panel.visible = false
func update_ui() -> void:
	if not is_instance_valid(button): return
	button.visible = enabled()
	if not enabled(): panel.visible = false; return
	button.text = "Development [P]" if daughters[0].is_empty() else "Daughter %d%% [P]" % int(daughters[0].progress / QUEEN_SECONDS * 100)
	if not panel.visible: return
	var text := "Goal: raise and launch a daughter queen before your rivals.\n\nPath: %s | Living soldiers: %d\nForaging: +15%% unloaded surface forage speed (existing workers).\nSoldiers: new brood only; 5 HP, x1.5 bite, +4 protein at pupation,\n+0.004 sugar/s each; normal jobs, security recruits soldiers first.\n\n%s\nDaughter: %s\n" % [NAMES[paths[0]], soldier_counts[0], choice_reason(0), queen_reason(0) if daughters[0].is_empty() else "%s / %d%% / %s" % [stage_name(0), daughters[0].progress / QUEEN_SECONDS * 100, daughters[0].status]]
	if preparation_reserves[0] > 0: text = text.trim_suffix("\n") + " / nurses saving %d/20 P\n" % mini(20, int(free_protein(0)))
	for c in range(1, sim.colony_count):
		text += "%s: %s | Daughter: %s\n" % [sim.COLONY_NAMES[c], NAMES[paths[c]], stage_name(c)]
	details.text = text
	forage_button.disabled = choice_reason(0) != "Ready to specialize"
	soldier_button.disabled = forage_button.disabled
	queen_button.disabled = queen_reason(0) != "Ready to raise daughter"
func draw_nest(canvas: CanvasItem) -> void:
	var c: int = sim.inspected_colony
	if not enabled() or daughters[c].is_empty(): return
	var d: Dictionary = daughters[c]
	var p: Vector2 = sim._center(Vector2i(d.cell % sim.COLS, d.cell / sim.COLS))
	canvas.draw_circle(p, 7, Color("edd395"))
	canvas.draw_arc(p, 11, 0, TAU * d.progress / QUEEN_SECONDS, 24, sim.colony_color(c), 2)
	sim._draw_text(canvas, p + Vector2(15, -8), "DAUGHTER / " + stage_name(c), 11, sim.INK)
