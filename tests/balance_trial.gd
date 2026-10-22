extends SceneTree
## Optional diagnostic, not a claim of statistical balance. Neutral traits, no
## economy: isolate the original combat/foraging rules and swap nest positions.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var colony = load("res://main.tscn").instantiate()
	root.add_child(colony)
	colony.set_process(false)
	var results: Array = []
	var ecology := OS.get_cmdline_user_args().has("--ecology")
	var seeds: Array = [81923, 81924, 7] if ecology else [81923, 81924, 7, 42, 137, 2026]
	for seed_value in seeds:
		for swap in [false, true]:
			colony.swapped_sides = swap
			colony.doctrines.fill(0)
			if ecology:
				colony.doctrines[0] = 1
				colony.doctrines[1] = 2
			colony.reset_colony(seed_value)
			colony.invasions_enabled = false # Preserve the pre-invasion diagnostic.
			colony.reproduction_enabled = ecology
			for tick in 10800:
				colony.simulate(1.0 / 30.0)
			var result := {"seed": seed_value, "swapped": swap, "seconds": 360, "amber_alive": colony.living_count(0), "red_alive": colony.living_count(1), "amber_food": colony.delivered, "red_food": colony.rival_delivered}
			if ecology:
				result["amber_births"] = colony.births[0]
				result["red_births"] = colony.births[1]
				result["amber_queen"] = colony.queen_health[0]
				result["red_queen"] = colony.queen_health[1]
			results.append(result)
			print(JSON.stringify(result))
	var output := FileAccess.open("res://tests/balance_ecology.json" if ecology else "res://tests/balance_after.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	quit()
