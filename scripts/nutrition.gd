extends RefCounted
## Colony-wide demand changes slowly; every pickup and carried load stays individual.
const SUGAR := 0
const PROTEIN := 1
const NAMES := ["Sugar", "Protein"]
var sim

func setup(owner_node) -> void:
	sim = owner_node

func refresh() -> void:
	for c in sim.colony_count:
		var sugar_target: float = maxf(8, sim.upkeep_rate(c) * 60)
		# Enough protein for a short replacement pipeline, bounded by brood capacity.
		var protein_target: float = maxf(8, minf(80, (sim.brood[c].size() + 5) * 8))
		if sim.game_mode == sim.game_modes.FOUNDING and not sim.progression.daughters[c].is_empty():
			sugar_target += 45; protein_target += 24
		if sim.queen_health[c] <= 0 or sim.living_count(c) + sim.brood[c].size() >= sim.POPULATION_CAP: protein_target = 1
		sim.nutrition_weights[c * 2] = clampf(sugar_target / (sim.food_stores[c] + sugar_target * 0.25), 0.25, 4)
		sim.nutrition_weights[c * 2 + 1] = clampf(protein_target / (sim.protein_stores[c] + protein_target * 0.25), 0.25, 4)

func status(c: int) -> String:
	if sim.chambers_enabled and sim.storage_capacity[c] <= 0: return "No connected storage: reconnect"
	if sim.chambers_enabled and sim.food_stores[c] + sim.protein_stores[c] + 1 > sim.storage_capacity[c]: return "Storage full: expand [8]"
	if sim.food_stores[c] < sim.upkeep_rate(c) * 30: return "Sugar low: favor fruit / nectar"
	if sim.queen_health[c] > 0 and sim.living_count(c) + sim.brood[c].size() < sim.POPULATION_CAP and sim.protein_stores[c] < 8: return "Protein low: favor insect food"
	return "Automatic forage: sugar + protein"
