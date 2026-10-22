extends SceneTree

var failures := 0
var colony

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func fresh(ids: Array = [0]) -> void:
	colony.reset_colony(42)
	colony.reproduction_enabled = false
	colony.doctrines.fill(0)
	colony.health.fill(0)
	for i in ids:
		colony.health[i] = 3
		colony.positions[i] = colony.nest_for(i)
		colony.attack_cooldowns[i] = 0

func _run() -> void:
	colony = load("res://main.tscn").instantiate()
	colony.colony_count = 2
	root.add_child(colony)
	colony.set_process(false)
	fresh()
	var before: Vector2 = colony.positions[0]
	check(colony.launch_raid(0) == 1 and colony.roles[0] == colony.INVADER, "A depleted colony can send its one available worker")
	check(colony.positions[0] == before and colony.layers[0] == colony.SURFACE, "Ordering a raid must not teleport a worker into the enemy nest")
	check(not colony._enter_nest(0, 1), "A worker must reach the surface entrance before entering tunnels")
	colony.positions[0] = colony.nest_position(1)
	check(colony._enter_nest(0, 1) and colony.layers[0] == 1 and colony.invaders_in(1) == 1, "An invader at the surface entrance must enter the correct enemy tunnel layer")
	var route: Array = colony.tunnel_route(colony.entrance_cell(1), colony._cell(colony.queen_position(1)), 1)
	check(not route.is_empty(), "The starting enemy entrance must have a route to its queen")
	var previous: Vector2i = colony.entrance_cell(1)
	for tile in route:
		check(colony._nest_grid(1)[colony._idx(tile)] == 1 and absi(tile.x - previous.x) + absi(tile.y - previous.y) == 1, "Every route step must stay in an adjacent open tunnel tile")
		previous = tile
	colony.queen_health[1] = 3
	for tick in 600:
		colony.simulate(1.0 / 30.0)
		check(colony.rival_earth[colony._idx(colony._cell(colony.positions[0]))] == 1, "Invader movement must stay out of soil and stone")
		if not colony.match_result.is_empty():
			break
	check(colony.match_result == "victory" and colony.queen_health[1] == 0 and colony.queen_death_causes[1] == "invaders", "An invader must walk to, attack, and kill the rival queen for victory")
	check(colony.result_panel.visible and colony.result_title.text == "VICTORY", "Victory must display a clear result card")
	var end_time: float = colony.elapsed
	var end_positions: PackedVector2Array = colony.positions.duplicate()
	var end_stores: PackedFloat64Array = colony.food_stores.duplicate()
	for tick in 90:
		colony.simulate(1.0 / 30.0)
	check(colony.elapsed == end_time and colony.positions == end_positions and colony.food_stores == end_stores, "A finished match must freeze movement, combat, food, and time")
	check(colony.launch_raid(0) == 0, "A finished match must reject new raids")
	# Seal the entire entrance shaft; invaders cannot damage queens through dirt.
	fresh()
	colony.roles[0] = colony.INVADER
	colony.positions[0] = colony.nest_position(1)
	colony._enter_nest(0, 1)
	var shaft_x: int = colony.entrance_cell(1).x
	var barrier_y: int = colony.HOME_CELL.y - 7
	for x in range(shaft_x - 1, shaft_x + 2):
		colony.rival_earth[colony._idx(Vector2i(x, barrier_y))] = 0
	check(colony.tunnel_route(colony.entrance_cell(1), colony._cell(colony.queen_position(1)), 1).is_empty(), "A sealed shaft must make the queen unreachable")
	for tick in 360:
		colony.simulate(1.0 / 30.0)
	check(colony.queen_health[1] == 100 and colony.positions[0] == colony._center(colony.entrance_cell(1)), "An unreachable queen must take no damage and the invader must not cross walls")
	colony.rival_earth[colony._idx(Vector2i(shaft_x, barrier_y))] = 1
	for tick in 240:
		colony.simulate(1.0 / 30.0)
	check(colony.queen_health[1] < 100, "Opening a tunnel must let a waiting invader find the new route")
	# Equal drawing positions in different nests or on the surface never interact.
	fresh([0, colony.COUNT])
	colony.positions[0] = colony.queen_position(1)
	colony.positions[colony.COUNT] = colony.positions[0]
	colony.roles[0] = colony.INVADER
	colony.layers[0] = 1
	colony.layers[colony.COUNT] = colony.SURFACE
	colony._prepare_encounters(0)
	check(colony.opponents[0] == -1 and colony.opponents[colony.COUNT] == -1, "Different layers must never exchange worker attacks")
	colony.layers[0] = colony.SURFACE
	colony.simulate(1.0 / 30.0)
	check(colony.queen_health[1] == 100, "A surface ant over the queen's drawing position must not attack underground")
	# A defender in the same tunnel intercepts an invader instead of the queen.
	fresh([0, colony.COUNT])
	colony.layers[0] = 1
	colony.layers[colony.COUNT] = 1
	colony.roles[0] = colony.INVADER
	colony.roles[colony.COUNT] = colony.GUARD
	colony.positions[0] = colony.queen_position(1) + Vector2(0, -8)
	colony.positions[colony.COUNT] = colony.positions[0] + Vector2(8, 0)
	colony.simulate(1.0 / 30.0)
	check(colony.health[0] < 3 and colony.health[colony.COUNT] < 3 and colony.queen_health[1] == 100, "Tunnel defenders and invaders must fight each other with worker targets taking priority")
	# No seeing or striking through a dirt tile, including diagonal corner gaps.
	fresh([0, colony.COUNT])
	colony.layers[0] = 0
	colony.layers[colony.COUNT] = 0
	colony.earth[colony._idx(Vector2i(17, 10))] = 1
	colony.earth[colony._idx(Vector2i(19, 10))] = 1
	colony.earth[colony._idx(Vector2i(18, 10))] = 0
	colony.positions[0] = colony._center(Vector2i(17, 10))
	colony.positions[colony.COUNT] = colony._center(Vector2i(19, 10))
	colony._prepare_encounters(0)
	check(colony.opponents[0] == -1 and colony.opponents[colony.COUNT] == -1, "Dirt between nearby enemies must block encounter detection")
	colony.earth[colony._idx(Vector2i(10, 10))] = 1
	colony.earth[colony._idx(Vector2i(11, 11))] = 1
	check(not colony._tunnel_line_clear(colony._center(Vector2i(10, 10)), colony._center(Vector2i(11, 11)), 0), "Diagonal movement must not cut across a closed grid corner")
	# Being close to the queen is insufficient if a corner blocks direct access.
	fresh([colony.COUNT])
	colony.layers[colony.COUNT] = 0
	colony.roles[colony.COUNT] = colony.INVADER
	colony.positions[colony.COUNT] = colony.HOME + Vector2(-6.5, -9)
	colony.earth[colony._idx(colony.HOME_CELL + Vector2i(-1, -1))] = 0
	check(not colony._tunnel_line_clear(colony.positions[colony.COUNT], colony.queen_position(0), 0), "The near-queen corner fixture must initially block a direct bite")
	for tick in 120:
		colony.simulate(1.0 / 30.0)
	check(colony.queen_health[0] < 100, "A nearby invader must route around a blocked corner rather than stop short of the queen")
	# Any queen death ends the match, including hunger and simultaneous raids.
	fresh([colony.COUNT])
	colony.layers[colony.COUNT] = 0
	colony.roles[colony.COUNT] = colony.INVADER
	colony.positions[colony.COUNT] = colony.queen_position(0) + Vector2(0, -8)
	colony.queen_health[0] = 0.1
	colony.simulate(1.0 / 30.0)
	check(colony.match_result == "defeat" and colony.result_title.text == "DEFEAT", "The rival killing the player's queen must show defeat")
	fresh([0, colony.COUNT])
	colony.layers[0] = 1
	colony.layers[colony.COUNT] = 0
	colony.roles[0] = colony.INVADER
	colony.roles[colony.COUNT] = colony.INVADER
	colony.positions[0] = colony.queen_position(1) + Vector2(0, -8)
	colony.positions[colony.COUNT] = colony.queen_position(0) + Vector2(0, -8)
	colony.queen_health.fill(0.1)
	colony.simulate(1.0 / 30.0)
	check(colony.match_result == "draw" and colony.queen_health[0] == 0 and colony.queen_health[1] == 0, "Simultaneous queen deaths must result in a draw rather than colony-order bias")
	fresh([])
	colony.reproduction_enabled = true
	colony.food_stores[0] = 0
	colony.queen_health[0] = 0.001
	colony.simulate(1.0 / 30.0)
	check(colony.match_result == "defeat" and colony.queen_death_causes[0] == "starvation", "A queen starving must also end the match with a stated cause")
	colony.reset_colony(7)
	check(colony.match_result.is_empty() and not colony.result_panel.visible and colony.queen_health[0] == 100 and colony.invaders_in(0) == 0, "Restart must clear the result and restore both queens and locations")
	# Automatic defense recruits the invaded colony and travels through its portal.
	colony.reproduction_enabled = false
	colony.roles[0] = colony.INVADER
	colony.layers[0] = 1
	colony.positions[0] = colony._center(colony.entrance_cell(1))
	colony.nest_quiet[1] = 0
	colony._update_defenses()
	var guards := 0
	for i in colony.health.size():
		if colony.roles[i] == colony.GUARD:
			check(colony.colonies[i] == 1, "Defense must recruit the invaded colony's own workers")
			guards += 1
	check(guards == 6, "An invaded nest should recall six defenders")
	if failures == 0:
		print("PASS: raid orders, entrance transitions, open-tunnel routing, sealed shafts, dynamic paths, queen attacks, guards, layers, walls/corners, victory/defeat/draw/starvation, frozen results, restart.")
	quit(1 if failures else 0)
