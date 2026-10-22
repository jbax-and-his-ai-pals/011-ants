extends SceneTree

var failures := 0
var colony

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func fresh() -> void:
	colony.reset_colony(42)
	colony.doctrines.fill(0)
	colony.combat_enabled = false
	colony.invasions_enabled = false

func _run() -> void:
	colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	colony.chambers_enabled = false # Isolate the pre-chamber nutrient/combat fixture; physical logistics has its own suite.
	root.add_child(colony)
	colony.set_process(false)
	fresh()
	colony.food_stores.fill(1000)
	for tick in 500:
		colony._update_nurseries(0.1)
	check(colony.births[0] > 0 and colony.births[1] > 0, "Fed queens should lay eggs which mature into workers for both colonies")
	check(colony.health.size() > colony.starting_total(), "Growth above the starting population must safely extend worker arrays")
	for side in 2:
		check(colony.living_count(side) == colony.COUNT + colony.births[side], "Every mature pupa must create one living worker of the correct colony")
		check(absf(1000 - colony.food_stores[side] - colony.upkeep_spent[side]) < 0.001, "Sugar upkeep expenditure must be conserved")
		check(absf(colony.INITIAL_PROTEIN - colony.protein_stores[side] - colony.brood_spent[side]) < 0.001, "Protein brood expenditure must be conserved")
		check(colony.brood_spent[side] > colony.births[side] * 8, "Food must pay for both matured workers and brood still in development")
	check(colony.positions.size() == colony.health.size() and colony.ant_rng.size() == colony.health.size() and colony.paths.size() == colony.health.size(), "New worker slots must initialize every simulation array")
	# Replace a loss using its old slot, without inheriting cargo, paths or damage.
	fresh()
	colony.health[0] = 0
	colony.roles[0] = 1
	colony.layers[0] = 1
	colony.carrying[0] = 1
	colony.cargo_resource[0] = 1
	colony.targets[0] = 12
	colony.opponents[colony.COUNT] = 0
	colony.brood[0] = [{"stage": 2, "age": 12.1}]
	colony.food_stores.fill(1000)
	colony._update_nurseries(0.1)
	check(colony.births[0] == 1 and colony.living_count(0) == colony.COUNT and colony.positions.size() == colony.starting_total(), "A hatch should reuse a dead same-colony slot before allocating more memory")
	check(colony.layers[0] == colony.SURFACE and colony.roles[0] == 0 and colony.carrying[0] == 0 and colony.targets[0] == -1 and colony.opponents[colony.COUNT] == -1, "Replacement workers must not inherit stale nest location, jobs, cargo, or enemy targeting")
	check(colony.cargo_resource[0] == 0, "Reused slots must not inherit a dead worker's cargo nutrient")
	# Queens can rebuild a wiped-out workforce if food and brood remain.
	fresh()
	for i in colony.COUNT:
		colony.health[i] = 0
	colony.brood[0] = [{"stage": 2, "age": 12.1}]
	colony._update_nurseries(0.1)
	check(colony.living_count(0) == 1, "A living queen's mature brood can recover from zero workers")
	# Hunger halts breeding, weakens queens and workers, and cannot create food.
	fresh()
	colony.food_stores.fill(0)
	colony.brood[0] = [{"stage": 1, "age": 5.0}]
	for tick in 100:
		colony._update_nurseries(0.1)
	check(colony.queen_health[0] < 100 and colony.health[0] < 3, "Unpaid upkeep must weaken both the queen and workers")
	check(colony.food_stores[0] == 0 and colony.brood[0][0].age == 5.0 and colony.births[0] == 0, "Hungry larvae must pause and reserves must never become negative")
	var hungry_health: float = colony.health[0]
	colony.positions[0] = colony.HOME
	colony._forage(0, 0.1)
	check(colony.health[0] == hungry_health, "Nest healing must not bypass starvation without food")
	colony.health[0] = 0.001
	colony._update_nurseries(0.1)
	check(colony.health[0] == 0 and colony.starvation_losses[0] == 1 and colony.casualties[0] == 0, "Hunger deaths must be counted separately from combat")
	colony.queen_health[0] = 0.001
	colony._update_nurseries(0.1)
	check(colony.queen_health[0] == 0, "Prolonged starvation must be able to kill the queen")
	colony.food_stores[0] = 1000
	colony.brood[0].clear()
	for tick in 100:
		colony._update_nurseries(0.1)
	check(colony.queen_health[0] == 0 and colony.brood[0].is_empty(), "A dead queen must not revive or lay new eggs when food returns")
	# Unfed transition waits, then resumes when the colony can afford it.
	fresh()
	colony.brood[0] = [{"stage": 0, "age": 8.1}]
	colony.food_stores[0] = 8
	colony._update_nurseries(0.1)
	check(colony.brood[0][0].stage == 0, "Brood must wait if feeding would consume the emergency reserve")
	colony.food_stores[0] = 1000
	colony._update_nurseries(0.1)
	check(colony.brood[0][0].stage == 1 and colony.brood_spent[0] == 3, "A resumed transition must consume its feeding cost exactly once")
	# Long abundant-food runs stay within the explicit population and brood caps.
	fresh()
	# Fill most slots directly, then exercise actual breeding into the final slots.
	for side in 2:
		while colony.living_count(side) < colony.POPULATION_CAP - 2:
			colony._spawn_worker(side)
	colony.food_stores.fill(100000)
	for tick in 500:
		colony._update_nurseries(0.1)
	check(colony.living_count(0) == colony.POPULATION_CAP and colony.living_count(1) == colony.POPULATION_CAP, "Abundant food should grow both colonies to the population cap")
	check(colony.brood[0].size() <= colony.BROOD_CAP and colony.health.size() <= colony.POPULATION_CAP * 2, "Brood and worker storage must remain bounded")
	# Differences are explicit rule values, including a neutral mode for trials.
	colony.doctrines[0] = 1
	colony.doctrines[1] = 2
	check(colony.stage_duration(0, 1) < colony.stage_duration(1, 1) and colony.stage_feed_cost(0, 1) == 3 and colony.stage_feed_cost(1, 1) == 4, "Stewards should have faster, cheaper brood than Raiders")
	check(colony.upkeep_rate(1) > colony.upkeep_rate(0), "Raiders should pay their stated upkeep premium")
	# Stewards carrying food defend on contact rather than abandoning deliveries.
	fresh()
	colony.reproduction_enabled = false
	colony.combat_enabled = true
	colony.doctrines[0] = 1
	colony.positions[0] = Vector2(510, 300)
	colony.positions[colony.COUNT] = Vector2(535, 300)
	colony.carrying[0] = 1
	colony._prepare_encounters(0)
	check(colony.opponents[0] == -1, "Steward carriers should continue home instead of pursuing nearby enemies")
	colony.positions[colony.COUNT] = Vector2(520, 300)
	colony._prepare_encounters(0)
	check(colony.opponents[0] == colony.COUNT, "Steward carriers should still defend themselves on contact")
	colony.reset_colony(7)
	check(colony.births[0] == 0 and colony.brood[0].is_empty() and colony.queen_health[0] == 100 and colony.food_stores[0] == colony.INITIAL_STORES and colony.health.size() == colony.starting_total(), "Reset must restore queens, food, brood and initial worker capacity")
	if failures == 0:
		print("PASS: feeding, lifecycle, new/reused worker slots, recovery from zero workers, starvation, dead queens, paused feeding, spending ledger, population caps, colony traits, reset.")
	quit(1 if failures else 0)
