extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s = load("res://tests/seat_colony.gd").new()
	root.add_child(s)
	s.set_process(false)
	s.equal_controllers = false
	s.rival_ai_enabled = false
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
			rows.append({"seed": seed_value, "offset": offset, "state": s.census()})
			print("UNGUIDED seed=%d offset=%d pop=%s" % [seed_value, offset, rows[-1].state.population])
	var file := FileAccess.open("res://tests/coral_unguided_control.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": true, "note": "300s surface-only controls. No colony orders, invasions or births. Individual food/scent/combat unchanged.", "runs": rows}, "\t"))
	quit()
