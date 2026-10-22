extends SceneTree
## Small controlled encounters complement the full-colony integration run.

var failures := 0
var colony

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func isolate(ids: Array) -> void:
	colony.reset_colony()
	colony.reproduction_enabled = false
	colony.invasions_enabled = false
	colony.doctrines.fill(0)
	colony.health.fill(0)
	for i in ids:
		colony.health[i] = 3.0
		colony.attack_cooldowns[i] = 0
		colony.positions[i] = Vector2(540, 300)

func _run() -> void:
	colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	colony.chambers_enabled = false # Isolate the pre-chamber nutrient/combat fixture; physical logistics has its own suite.
	root.add_child(colony)
	colony.set_process(false)
	# Ants use their own banks and pheromones, even when the enemy nest is nearby.
	isolate([0, colony.COUNT])
	colony.combat_enabled = false
	colony.positions[0] = colony.HOME
	colony.positions[colony.COUNT] = colony.RIVAL_HOME
	colony.carrying[0] = 1
	colony.carrying[colony.COUNT] = 1
	colony.simulate(1.0 / 30.0)
	check(colony.delivered == 1 and colony.rival_delivered == 1, "Each carrier should deliver to its own food bank")
	var rival_cell: int = colony._idx(colony._cell(colony.RIVAL_HOME))
	check(colony.rival_food_scent[rival_cell] > 0 and colony.food_scent[rival_cell] == 0, "Rival trails must stay separate from player trails")
	colony.carrying[colony.COUNT] = 1
	colony.positions[colony.COUNT] = colony.HOME
	colony._forage(colony.COUNT, 1.0 / 30.0)
	check(colony.carrying[colony.COUNT] == 1 and colony.delivered == 1 and colony.rival_delivered == 1, "A rival cannot deliver food to the player's nest")
	# Both colonies compete for the same final morsel; it cannot be duplicated.
	isolate([0, colony.COUNT])
	colony.combat_enabled = false
	colony.foods = [{"pos": Vector2(540, 300), "amount": 1, "initial": 1}]
	colony._forage(0, 1.0 / 30.0)
	colony._forage(colony.COUNT, 1.0 / 30.0)
	check(colony.foods[0].amount == 0 and colony.carrying[0] + colony.carrying[colony.COUNT] == 1, "Shared food pickup must be exclusive and never negative")
	# Friendly workers never damage one another.
	isolate([0, 1])
	for tick in 90:
		colony.simulate(1.0 / 30.0)
	check(colony.health[0] == 3 and colony.health[1] == 3, "Same-colony encounters must not deal friendly fire")
	# The underground is a separate layer, even at matching drawing coordinates.
	isolate([0, colony.COUNT])
	colony.roles[0] = 1
	colony.layers[0] = 0
	colony._prepare_encounters(1.0 / 30.0)
	check(colony.opponents[0] == -1 and colony.opponents[colony.COUNT] == -1, "Surface enemies must not target underground excavators")
	# Spatial lookup must cover bucket boundaries, but ignore distant enemies.
	isolate([0, colony.COUNT])
	colony.positions[0] = Vector2(511, 300)
	colony.positions[colony.COUNT] = Vector2(520, 300)
	colony.simulate(1.0 / 30.0)
	check(colony.health[0] < 3 and colony.health[colony.COUNT] < 3, "Both sides should attack on the same tick across a spatial bucket boundary")
	var first_health: float = colony.health[0]
	var second_health: float = colony.health[colony.COUNT]
	colony.simulate(1.0 / 30.0)
	check(colony.health[0] == first_health and colony.health[colony.COUNT] == second_health, "Attack cooldowns must prevent damage every simulation tick")
	colony.positions[colony.COUNT] = Vector2(700, 300)
	colony._prepare_encounters(0)
	check(colony.opponents[0] == -1 and colony.opponents[colony.COUNT] == -1, "Distant ants must not fight")
	# Regression: previously the second colony got the first strike while closing.
	isolate([0, colony.COUNT])
	colony.positions[0] = Vector2(511, 300)
	colony.positions[colony.COUNT] = Vector2(524.8, 300)
	colony.simulate(1.0 / 30.0)
	check(colony.health[0] < 3 and colony.health[colony.COUNT] < 3, "Both colonies must test contact after both have moved, including the first approach tick")
	# Antenna decisions must not favor a clockwise turn in near-tied scent.
	for samples in [[0.0, 1.0, 1.01], [0.0, 1.0, 1.2], [1.0, 0.5, 2.0], [1.0, 0.5, 0.5]]:
		check(is_equal_approx(colony.scent_turn(samples[0], samples[1], samples[2]), -colony.scent_turn(samples[0], samples[2], samples[1])), "Swapping left and right antennae must reverse the steering decision")
	# Lethal damage applies to both sides before either gets a next turn.
	isolate([0, colony.COUNT])
	colony.health[0] = 0.5
	colony.health[colony.COUNT] = 0.5
	colony.carrying[0] = 1
	colony.select_ant(0)
	var before := 0
	for patch in colony.foods:
		before += patch.amount
	colony.simulate(1.0 / 30.0)
	check(colony.health[0] == 0 and colony.health[colony.COUNT] == 0, "A lethal exchange must allow simultaneous deaths")
	check(colony.casualties[0] == 1 and colony.casualties[1] == 1, "Each death must count exactly once for the correct colony")
	check(colony.worker_kills[0] == 1 and colony.worker_kills[colony.COUNT] == 1 and colony.selected_info.kills == 1, "Simultaneous kills must credit both workers and preserve the selected fallen worker's final statistics")
	check(colony.remains.size() == 2 and colony.carrying[0] == 0, "Deaths should leave fading remains and remove carried cargo")
	var after := 0
	for patch in colony.foods:
		after += patch.amount
	check(after == before + 1, "A fallen carrier must return exactly one unit to the shared food pool")
	var death_position: Vector2 = colony.positions[0]
	for tick in 60:
		colony.simulate(1.0 / 30.0)
	check(colony.positions[0] == death_position and colony.casualties[0] == 1, "Dead ants must stop updating and cannot die twice")
	# An enemy survivor can recover the dropped cargo.
	colony.health[colony.COUNT + 1] = 3
	colony.positions[colony.COUNT + 1] = death_position
	colony._forage(colony.COUNT + 1, 1.0 / 30.0)
	check(colony.carrying[colony.COUNT + 1] == 1, "Either colony should be able to recover a fallen carrier's food")
	# Nest healing is local to the worker's own colony.
	colony.health[colony.COUNT + 1] = 1
	colony.positions[colony.COUNT + 1] = colony.RIVAL_HOME
	colony._forage(colony.COUNT + 1, 0.5)
	check(colony.health[colony.COUNT + 1] > 1, "Injured workers should heal at their own nest")
	colony.health[colony.COUNT + 1] = 1
	colony.positions[colony.COUNT + 1] = colony.HOME
	colony._forage(colony.COUNT + 1, 0.5)
	check(colony.health[colony.COUNT + 1] == 1, "Enemy nests should not heal an injured worker")
	# A depleted colony recruits only its own surviving workers.
	isolate([0, 1, 2, colony.COUNT, colony.COUNT + 1])
	colony.positions[0] = colony.HOME
	colony.positions[1] = colony.HOME
	colony.positions[2] = colony.HOME
	colony.designate(colony.HOME_CELL + Vector2i(12, 3))
	colony._allocate_workers()
	check(colony.digger_count() == 3, "A depleted colony should recruit its three survivors rather than dead workers")
	check(colony.roles[colony.COUNT] == 0 and colony.roles[colony.COUNT + 1] == 0, "Rival workers must never be recruited to player excavation")
	if failures == 0:
		print("PASS: independent food banks and scent, shared pickups, friendly-fire/layer protection, spatial encounters, simultaneous damage, cooldowns, deaths, dropped food recovery, nest healing.")
	quit(1 if failures else 0)
