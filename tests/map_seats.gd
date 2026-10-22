extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s = load("res://tests/seat_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	s.equal_controllers = true
	s.doctrines.fill(0)
	var rows: Array = []
	for seed_value in [81923, 7, 42]:
		for offset in 3:
			s.seat_offset = offset
			s.reset_colony(seed_value)
			s.invasions_enabled = false
			s.reproduction_enabled = false
			for tick in 9000:
				s.simulate(s.STEP)
				if tick % 300 == 0: await process_frame
			var state: Dictionary = s.census()
			rows.append({"seed": seed_value, "offset": offset, "state": state})
			print("SEATS seed=%d offset=%d population=%s harvest=%s" % [seed_value, offset, state.population, state.harvest])
	var file := FileAccess.open("res://tests/map_seat_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": true, "note": "Surface-only 300s controls. Equal AI, Balanced traits, no invasions or births. Colors/RNG streams rotate over physical seats; this is not an additional full-match balance batch.", "runs": rows}, "\t"))
	quit()
