extends "res://tests/chambers_capture.gd"
func run() -> void:
	root.size = Vector2i(1440,900)
	var s = load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	s.game_modes.start(1,404)
	while s.living_count(0)<80: s._spawn_worker(0)
	s.food_stores[0] = 1000; s.protein_stores[0] = 1000
	s.progression.choose(0,1)
	var base: Vector2i = s.chamber_cell(0)
	for x in range(2,8):
		var j: int = s._idx(base+Vector2i(x,0))
		s.earth[j]=1; s.chamber_rooms[j]=s.chambers.BROOD; s.chambers.room_tiles[0][j]=s.chambers.BROOD
	s.chambers.dirty=true; s.chambers.rebuild()
	s.protein_stores[0] = s.chambers.buffered[0]+8
	s.progression.refresh_preparation(); s.progression.panel.visible = true; s.paused = true
	await capture(s,"res://screenshots/founding_progression_reserve.png")
	quit()
