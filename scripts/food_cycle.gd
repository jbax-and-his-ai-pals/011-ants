extends RefCounted
## Reusable surface sites; founding supplies homes before shared territory.
## Public forecasts never consume worker RNG.
const INTERVAL := 120.0
const NOTICE := 30.0
const SUPPLY := 6000
var sim
var next_arrival := INTERVAL
var wave := 0
var pending: Array[int] = []
var sites: Array[Vector2] = []
var added := 0
var added_resources := PackedInt32Array([0, 0])

func reset(owner_node) -> void:
	sim = owner_node
	next_arrival = INTERVAL
	wave = 0
	pending.clear()
	sites.clear()
	added = 0
	added_resources.fill(0)
	var center := Vector2.ZERO
	for c in sim.colony_count: center += sim.nest_position(c)
	center /= sim.colony_count
	var random := RandomNumberGenerator.new()
	random.seed = sim.world_seed ^ 0x31415926
	var rotation := random.randf_range(0, TAU)
	if sim.game_mode == sim.game_modes.FOUNDING:
		for c in sim.colony_count: sites.append_array(sim.game_modes.local_sites(c))
	for n in 6:
		sites.append((center + Vector2.from_angle(rotation + n * TAU / 6) * 300).clamp(Vector2(80, 80), sim.SIZE - Vector2(80, 80)))

func tick() -> void:
	if not sim.food_cycles_enabled: return
	if pending.is_empty() and sim.elapsed >= next_arrival - NOTICE:
		var wave_sites: Array[int] = []
		if sim.game_mode == sim.game_modes.FOUNDING:
			for n in 3: wave_sites.append((wave + 2) % 3 + n * 3)
			if wave >= 3:
				for n in 3: wave_sites.append(9 + wave % 2 + n * 2)
		else:
			for n in 3: wave_sites.append(wave % 2 + n * 2)
		for site in wave_sites:
			var supply := supply_at(site)
			var index := -1
			for f in sim.foods.size():
				if sim.foods[f].get("cycle_site", -1) == site: index = f; break
			if index < 0:
				index = sim.foods.size()
				sim.foods.append({"pos": sites[site], "amount": 0, "initial": supply, "cycle_site": site, "resource": 1 if site % 3 == 2 else 0, "food_visual": site % 3})
			var patch: Dictionary = sim.foods[index]
			patch.arrival = next_arrival
			patch.forecast = maxi(0, supply - patch.amount)
			pending.append(index)
			sim.clarity.record("forecast","Public food forecast: %ds" % maxi(0,ceili(next_arrival-sim.elapsed)),patch.pos,-1,"forecast:%d" % site,90)
		sim.food_index_size = -1
	if not pending.is_empty() and sim.elapsed + 0.0001 >= next_arrival:
		for index in pending:
			var patch: Dictionary = sim.foods[index]
			var supply: int = maxi(0, supply_at(patch.cycle_site) - patch.amount)
			sim.clarity.record("arrival","Scheduled food arrival",patch.pos,-1,"arrival:%d" % patch.cycle_site,90)
			patch.amount += supply
			added += supply
			added_resources[patch.resource] += supply
			patch.arrival = 0.0
			patch.forecast = 0
		pending.clear()
		wave += 1
		next_arrival += INTERVAL
		sim.food_index_size = -1

func supply_at(site: int) -> int:
	if sim.game_mode == sim.game_modes.FOUNDING: return 360 if site < 9 else 1200
	return SUPPLY

func headline() -> String:
	if not sim.food_cycles_enabled: return "Food cycles disabled"
	if not pending.is_empty(): return "FOOD IN %ds · %d gold rings on map · click notice to inspect" % [maxi(0, ceili(next_arrival - sim.elapsed)), pending.size()]
	return "Food wave %d landed · next forecast in %ds" % [wave, maxi(0, ceili(next_arrival - NOTICE - sim.elapsed))] if wave > 0 else "Food forecast in %ds · finite patches, new supplies every 2 min" % maxi(0, ceili(next_arrival - NOTICE - sim.elapsed))

func focus() -> void:
	if pending.is_empty(): return
	sim.set_view(false)
	sim.camera_center = sim.foods[pending[0]].pos
	sim.camera_zoom = 0.8
	sim._sync_camera()
