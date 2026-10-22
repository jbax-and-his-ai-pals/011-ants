extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	var rows := []
	for path in [1, 2]:
		s.game_modes.start(1, 81923); s.next_raids[0] = INF
		var row := {"path": path, "choice_at": -1, "queen_start": -1, "snapshots": []}
		var planned := false
		for tick in 54000:
			if tick % 90 == 0:
				if s.progression.paths[0] == 0 and s.progression.choose(0, path): row.choice_at = s.elapsed
				if not planned and s.living_count(0) >= 80:
					s.chambers.designate(s.chamber_cell(0) + Vector2i(7, 0), s.chambers.BROOD, true, false)
					planned = true
				if s.progression.daughters[0].is_empty() and s.progression.start_daughter(0): row.queen_start = s.elapsed
			s.simulate(s.STEP)
			if tick % 3600 == 0:
				row.snapshots.append({"seconds": s.elapsed, "population": [s.living_count(0),s.living_count(1),s.living_count(2)], "sugar": Array(s.food_stores), "protein": Array(s.protein_stores), "capacity": Array(s.brood_capacity), "paths": Array(s.progression.paths), "daughters": s.progression.daughters.duplicate(true)})
			if not s.match_result.is_empty(): break
		row["seconds"] = s.elapsed; row["result"] = s.match_result; row["daughters"] = s.progression.daughters.duplicate(true)
		rows.append(row); print("NATURAL PROGRESSION ", JSON.stringify(row))
	FileAccess.open("res://tests/progression_natural_runs.json", FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	quit()
