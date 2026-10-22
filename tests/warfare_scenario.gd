extends SceneTree
## A whole-match diagnostic using autonomous raids and automatic defenders.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var colony = load("res://main.tscn").instantiate()
	root.add_child(colony)
	colony.set_process(false)
	var output: Array = []
	var failed := false
	for seed_value in [81923, 7, 42]:
		colony.reset_colony(seed_value)
		var peaks := [0, 0]
		var breached := [false, false]
		for tick in 36000:
			colony.simulate(1.0 / 30.0)
			for nest in 2:
				peaks[nest] = maxi(peaks[nest], colony.invaders_in(nest))
				breached[nest] = breached[nest] or colony.invaders_in(nest) > 0
			for i in colony.health.size():
				if colony.health[i] > 0 and colony.layers[i] >= 0 and colony._nest_grid(colony.layers[i])[colony._idx(colony._cell(colony.positions[i]))] != 1:
					failed = true
					push_error("A living underground worker entered a solid tile")
					break
			if not colony.match_result.is_empty():
				break
		if not breached[0] and not breached[1]:
			failed = true
			push_error("No autonomous invasion reached a nest")
		if colony.match_result.is_empty():
			failed = true
			push_error("A large-world match exceeded the twenty-minute diagnostic budget")
		var row := {"seed": seed_value, "seconds": colony.elapsed, "result": colony.match_result, "queen_health": Array(colony.queen_health), "death_causes": colony.queen_death_causes.duplicate(), "peak_intruders": peaks, "workers": [colony.living_count(0), colony.living_count(1)]}
		print(JSON.stringify(row))
		output.append(row)
	var file := FileAccess.open("res://tests/warfare_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	if not failed:
		print("PASS: full matches reach nest invasions, keep underground workers in open tunnels, and resolve queen deaths.")
	quit(1 if failed else 0)
