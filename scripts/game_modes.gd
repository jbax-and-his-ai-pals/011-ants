extends RefCounted
const SKIRMISH := 0
const FOUNDING := 1
const FOUNDERS := 12
const FOUNDING_SUGAR := 80.0
const FOUNDING_PROTEIN := 96.0
const RAID_DELAY := 300.0
const RAID_POPULATION := 60
var sim
var selector: OptionButton
var detail: Label
func setup(owner_node) -> void: sim = owner_node
func start(mode: int, seed_value: int = -1) -> void:
	if mode not in [SKIRMISH, FOUNDING]: return
	sim.game_mode = mode
	sim.workers_per_colony = FOUNDERS if mode == FOUNDING else sim.COUNT
	sim.colony_count = 3
	sim.legacy_map_layout = false
	sim.wide_map_layout = false
	sim.fixed_starting_seats = false
	sim.swapped_sides = false
	sim.reset_colony(randi() if seed_value < 0 else seed_value)
func automatic_raids_allowed(colony: int, population: int = -1) -> bool:
	if sim.game_mode != FOUNDING: return true
	if population < 0: population = sim.living_count(colony)
	return sim.elapsed >= RAID_DELAY and population >= RAID_POPULATION
# Generated once from a separate stream, so scenery variation never consumes
# individual worker or rival target randomness.
var home_sites: Array = [[], [], []]
var local_amounts: Array = [[], [], []]
func prepare_sites() -> void:
	home_sites = [[], [], []]
	local_amounts = [[], [], []]
	if sim.game_mode != FOUNDING: return
	for c in sim.colony_count:
		var home: Vector2 = sim.nest_position(c)
		var random := RandomNumberGenerator.new()
		random.seed = sim.world_seed ^ (int(home.x) * 73856093) ^ (int(home.y) * 19349663)
		var rotation := random.randf_range(-0.45, 0.45)
		for kind in 3:
			var angle: float = [2.6, 0.45, -1.5][kind] + rotation + random.randf_range(-0.12, 0.12)
			home_sites[c].append(home + Vector2.from_angle(angle) * random.randf_range(80, 125))
			local_amounts[c].append(random.randi_range([160, 110, 220][kind], [220, 170, 300][kind]))
func local_sites(colony: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	result.assign(home_sites[colony])
	return result

func allocate_local_foragers() -> void:
	# Existing native/reference Forage steering remains individual. Negative
	# identity marks autonomous guidance, not a player order or delivered credit.
	for c in sim.colony_count:
		var population: int = sim.living_count(c)
		var settling: bool = sim.elapsed < 480 or population < RAID_POPULATION
		var local: Array = []
		if settling and sim.queen_health[c] > 0:
			for patch in sim.foods:
				if patch.get("layer", -1) == -1 and patch.amount > 0 and patch.pos.distance_squared_to(sim.nest_position(c)) < 300 * 300:
					if c != 0 or not sim.command_system.is_avoided(patch.pos): local.append(patch)
		for i in sim.colony_workers[c]:
			if sim.worker_order_ids[i] == -2:
				sim.worker_order_ids[i] = -1
				sim.worker_order_kinds[i] = 0
			if sim.health[i] <= 0 or sim.roles[i] != sim.FORAGER or sim.layers[i] != -1 or sim.worker_order_ids[i] >= 0 or sim.carrying[i] or sim.opponents[i] >= 0: continue
			# Keep a real scouting minority; no invisible territorial barrier.
			if local.is_empty() or sim.worker_ids[i] % 7 == 0: continue
			var best := INF
			var goal := Vector2.ZERO
			for patch in local:
				var need: float = sim.nutrition_weights[c * 2 + int(patch.get("resource", 0))]
				var score: float = sim.positions[i].distance_squared_to(patch.pos) / need
				if score < best: best = score; goal = patch.pos
			sim.worker_order_ids[i] = -2
			sim.worker_order_kinds[i] = sim.command_system.FORAGE
			sim.worker_order_goals[i] = goal
func build_ui() -> void:
	selector = OptionButton.new()
	selector.position = Vector2(300, 37)
	selector.size = Vector2(160, 38)
	selector.add_item("Skirmish · 2,000", SKIRMISH)
	selector.add_item("Founding · 12", FOUNDING)
	selector.add_theme_font_size_override("font_size", 13)
	selector.add_theme_stylebox_override("normal", sim._style(Color("22342a"), 7))
	selector.tooltip_text = "Open match setup with this mode selected. Choose a seed and starting traits, then Start new match. M also opens save/load and restart-same-seed controls."
	selector.item_selected.connect(func(index: int): sim.match_store.menu.open_setup(selector.get_item_id(index)); selector.select(sim.game_mode))
	sim.ui.add_child(selector)
	detail = sim._label("", Vector2(300, 80), 11, sim.MUTED, false, 1110)
func update_ui() -> void:
	if not is_instance_valid(selector): return
	selector.select(sim.game_mode)
	if sim.game_mode == FOUNDING:
		detail.text = "FOUNDING · 12 founders · seed %d · rival raids: %s · M: setup / save / load" % [sim.world_seed,("after %ds and 60 workers" % maxi(0, ceili(RAID_DELAY - sim.elapsed)) if sim.elapsed < RAID_DELAY else "60+ workers required")]
	else: detail.text = "SKIRMISH · 2,000 workers per colony · seed %d · M: setup / save / load · F5: save · F9: load" % sim.world_seed
