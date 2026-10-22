extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func prepare(s, mode: int) -> int:
	s.game_modes.start(mode,81923)
	while s.living_count(0) < 80: s._spawn_worker(0)
	s.food_stores[0] = 1000; s.protein_stores[0] = 8
	for j in s.chambers.brood_cells[0]: s.brood_buffers[j] = 0
	s.chambers.buffered[0] = 0
	var base: Vector2i = s.chamber_cell(0)
	for x in range(2,8):
		var j: int = s._idx(base+Vector2i(x,0))
		s.earth[j] = 1; s.chamber_rooms[j] = s.chambers.BROOD; s.chambers.room_tiles[0][j] = s.chambers.BROOD
	s.chambers.dirty = true; s.chambers.rebuild()
	if mode == 1: s.progression.paths[0] = s.progression.FORAGING
	s.chambers.allocate_nurses()
	var i: int = s.chambers.nurse_workers[0][0]
	s.layers[i] = 0
	var j: int = s.chambers.storage_cells[0][0]
	s.positions[i] = s._center(Vector2i(j%s.COLS,j/s.COLS))
	s.trips[i] = 0; s.chambers.prepare_reference()
	return i
func run() -> void:
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	for native in [false,true]:
		s.native_enabled = native
		var i := prepare(s,1)
		s.progression.refresh_preparation()
		check(s.progression.preparation_reserves[0] == 20, "A mature expanded Founding colony reserves the existing start cost")
		var bank: float = s.protein_stores[0]
		s.chambers.nurse(i,s.STEP)
		check(s.nurse_load[i] == 0 and s.protein_stores[0] == bank, "Nurses leave scarce unallocated protein for the daughter; no food is created")
		s.protein_stores[0] = 24; s.trips[i] = 0
		s.chambers.nurse(i,s.STEP)
		check(s.nurse_load[i] == 4 and s.progression.free_protein(0) == 20, "Real nurse loads can use the surplus above the reserve")
		check(s.progression.start_daughter(0), "A daughter starts using the saved protein despite a committed nurse load")
		check(s.protein_stores[0] == 4 and s.chambers.reserved[0] == 4 and s.progression.preparation_reserves[0] == 0, "Starting spends the reserve exactly once and releases the allocation hold")
		s.progression.refresh_preparation()
		check(s.progression.preparation_reserves[0] == 0, "Active daughter feeding is never blocked by its preparation reserve")
		i = prepare(s,1)
		s.health[79 if s.colonies[79] == 0 else s.colony_workers[0][-1]] = 0
		s.progression.refresh_preparation()
		check(s.progression.preparation_reserves[0] == 0, "Population losses below readiness release protein for rebuilding")
		s.game_modes.start(1,81923); s.progression.refresh_preparation()
		check(s.progression.preparation_reserves == PackedInt32Array([0,0,0]), "Opening growth has no royal preparation tax")
		i = prepare(s,0); s.progression.refresh_preparation(); s.chambers.nurse(i,s.STEP)
		check(s.progression.preparation_reserves[0] == 0 and s.nurse_load[i] == 4, "Skirmish retains ordinary protein allocation")
	s.queue_free()
	if failures == 0: print("PASS: Founding royal preparation holds real free protein, permits surplus nursing, spends/releases once, recovers after losses, preserves opening growth and leaves Skirmish allocation unchanged in both kernels.")
	quit(1 if failures else 0)
