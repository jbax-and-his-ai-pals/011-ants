extends SceneTree
var failures:=0
var samples: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; push_error(text)
func state(s) -> Dictionary:
	var data: Dictionary=s.match_store.capture()
	data.erase("meta")
	data.sections.erase("clarity") # Presentation summaries may refresh on load.
	for field in ["paused","selected_info","camera_centers","camera_zooms","camera_center","camera_zoom"]: data.sections.sim.erase(field)
	return data
func compare(a,b,label: String) -> void:
	var left:=state(a); var right:=state(b)
	for group in left.sections:
		for field in left.sections[group]:
			check(var_to_bytes(left.sections[group][field])==var_to_bytes(right.sections[group][field]),label+": "+group+"."+field)
	check(left.ants_rng==right.ants_rng and left.world_rng==right.world_rng and left.strategy_rng==right.strategy_rng,label+": every RNG stream")
func advance(s,ticks: int) -> void:
	for n in ticks: s.simulate(s.STEP)
func run() -> void:
	var s=load("res://main.tscn").instantiate(); root.add_child(s); s.set_process(false)
	var loaded=load("res://main.tscn").instantiate(); root.add_child(loaded); loaded.set_process(false)
	s.match_store.directory="res://.godot/save_load_tests"; loaded.match_store.directory=s.match_store.directory
	# Disk round-trips and full-population continuations in both modes/kernels.
	for native in [false,true]:
		for mode in [0,1]:
			s.game_modes.start(mode,81923); s.native_enabled=native; s.speed=4
			s.set_chamber_tool(2); s.designate(s.chamber_cell(0)+Vector2i(7,0)); s.set_view(false)
			s.command_system.issue(1,s.foods[0].pos)
			advance(s,93)
			s.select_ant(0); s.following=true
			var store=s.match_store
			var data: Dictionary=store.capture()
			check(store.validate(data).is_empty(),"Live match validates before saving: "+store.validate(data))
			check(store.request_save(),"Background save starts")
			# Main simulation continues while the worker serializes its snapshot.
			advance(s,90); store.collect_save()
			check(store.failed_count==0,"Background write succeeds: "+store.status)
			var result: Dictionary=store.CODEC.read_file(store.slot_path("manual"))
			check(not result.has("error"),"Saved disk file verifies")
			if result.has("error"): continue
			check(result.data.sections.sim.tick_number==data.sections.sim.tick_number,"Disk save captures requested boundary, not later live state")
			check(loaded.match_store.restore(result.data,false),"Snapshot restores: "+loaded.match_store.status)
			check(loaded.selected_ant==0 and loaded.worker_ids[0]==data.sections.sim.worker_ids[0] and loaded.following and loaded.speed==4,"Selection, identity, follow and speed restore")
			advance(loaded,90); compare(s,loaded,"Disk continuation mode=%d native=%s" % [mode,native])
			advance(s,120); advance(loaded,120); compare(s,loaded,"Later continuation mode=%d native=%s" % [mode,native])
			samples.append({"mode":mode,"native":native,"workers":s.health.size(),"capture_ms":store.last_capture_ms,"write_ms":store.last_write_ms,"bytes":store.last_bytes})
	# A real committed rival roster must remain the same shared dictionary as
	# its marker, or replacement workers stop counting toward campaign limits.
	s.game_modes.start(0,404); s.elapsed=100
	var ai=s.rival_ai
	ai.enemy_id=0; ai.start_raid(PackedInt32Array([2000,2000,2000]),true,false)
	var raid: Dictionary=ai.marker(400001,4,s.HOME)
	raid["roster"]=ai.raid_roster; raid["recruit_cap"]=ai.raid_budget; raid["party_limit"]=ai.raid_size
	ai.orders.markers=[raid]; ai.orders.allocate()
	check(not ai.raid_roster.is_empty(),"Invasion fixture recruits actual workers")
	var invader: int=ai.raid_roster.values()[0]
	s.positions[invader]=s.HOME; check(s._enter_nest(invader,0),"Active invader physically enters home tunnels")
	s.health[5]=0; s._kill_ant(5); s._spawn_worker(0) # Reused slot retains its new identity/RNG.
	var data: Dictionary=s.match_store.capture()
	check(loaded.match_store.restore(bytes_to_var(var_to_bytes(data)),false),"Active invasion and recycled worker restore: "+loaded.match_store.status)
	check(is_same(loaded.rival_ai.orders.markers[0].roster,loaded.rival_ai.raid_roster),"Restored campaign marker shares the authoritative roster")
	advance(s,120); advance(loaded,120); compare(s,loaded,"Active invasion continuation")
	# Paid Founding specialization, connected nursery, active daughter, food
	# forecasts and nurse cargo survive together, without duplicate resources.
	s.game_modes.start(1,9973)
	while s.living_count(0)<80: s._spawn_worker(0)
	s.food_stores[0]=1000; s.protein_stores[0]=1000
	var base: Vector2i=s.chamber_cell(0)
	for x in range(4,8):
		var j: int=s._idx(base+Vector2i(x,0)); s.earth[j]=1; s.chamber_rooms[j]=2; s.chambers.room_tiles[0][j]=2
	s.chambers.dirty=true; s.chambers.rebuild()
	check(s.progression.choose(0,2) and s.progression.start_daughter(0),"Paid daughter fixture starts")
	s.elapsed=90; s.food_cycle.tick(); advance(s,90)
	data=s.match_store.capture()
	check(loaded.match_store.restore(bytes_to_var(var_to_bytes(data)),false),"Daughter, forecasts and physical nurse jobs restore")
	advance(s,180); advance(loaded,180); compare(s,loaded,"Founding daughter continuation")
	# Invalid payloads and future versions leave the live match intact.
	var before:=state(s)
	var bad: Dictionary=data.duplicate(true); bad.sections.sim.positions.resize(1)
	check(not s.match_store.restore(bad,false) and var_to_bytes(state(s))==var_to_bytes(before),"Malformed arrays reject before mutation")
	bad=data.duplicate(true); bad.rules="future"
	check(not s.match_store.restore(bad,false) and var_to_bytes(state(s))==var_to_bytes(before),"Future rules reject without mutation")
	# Two saves rotate a previous-good slot. Corrupt current + stray temp must
	# recover the actual older state, with no deletion of the good backup.
	s.game_modes.start(1,73); var store=s.match_store
	store.request_save(); store.collect_save(); var earlier: int=s.tick_number
	advance(s,30); store.request_save(); store.collect_save()
	check(FileAccess.file_exists(store.slot_path("manual")+".bak"),"Previous good manual save retained")
	var file:=FileAccess.open(store.slot_path("manual"),FileAccess.READ_WRITE); file.seek(8); file.store_32(999); file.close()
	before=state(s)
	check(not store.load_slot() and var_to_bytes(state(s))==var_to_bytes(before),"Future disk format rejects without silently loading an older version")
	file=FileAccess.open(store.slot_path("manual"),FileAccess.WRITE); file.store_buffer(PackedByteArray([1,2,3])); file.close()
	file=FileAccess.open(store.slot_path("manual")+".tmp",FileAccess.WRITE); file.store_8(7); file.close()
	check(store.load_slot() and s.tick_number==earlier and s.paused and store.status.contains("Recovered"),"Truncated current recovers previous good save and ignores interrupted temp")
	var backup:=FileAccess.get_file_as_bytes(store.slot_path("manual")+".bak")
	store.request_save(); store.collect_save()
	check(FileAccess.get_file_as_bytes(store.slot_path("manual")+".bak")==backup,"Saving over a corrupt slot preserves its last good backup")
	# Autosave cadence is active wall time, excludes paused/menu time, has an
	# independent slot, and saves the actual outcome once.
	s.game_modes.start(1,81); store.autosave_interval=.2
	s.paused=true; store.tick(.15); store.tick(.15)
	check(not store.busy(),"Paused time does not trigger autosave")
	s.paused=false; store.tick(.15); store.tick(.15)
	check(store.busy() and store.writing_slot=="autosave","Autosave starts at active wall-time deadline")
	store.collect_save()
	check(not store.CODEC.read_file(store.slot_path("autosave")).has("error"),"Independent autosave verifies")
	var saved: int=store.saved_count
	s.match_result="victory"; store.tick(.1); store.collect_save(); store.tick(.1)
	check(store.saved_count==saved+1 and not store.busy(),"Actual result autosaves once")
	# Modal setup and restart restore seed/mode/initial traits without random
	# selection changes leaking through number keys in the text editor.
	s.game_modes.start(1,2026); s.speed=.5; var menu=store.menu
	menu.open_setup(0)
	check(s.paused and s.game_mode==1 and menu.mode.selected==0,"Draft mode selection pauses without starting a match")
	var key:=InputEventKey.new(); key.pressed=true; key.keycode=KEY_3; s._input(key)
	check(s.speed==.5,"Setup typing cannot activate game speed hotkeys")
	menu.seed_input.text="bad"; menu.start_match(); check(s.world_seed==2026 and menu.overlay.visible,"Invalid seeds do not replace the match")
	menu.seed_input.text="404"; menu.traits[0].select(0); menu.start_match()
	check(s.game_mode==0 and s.world_seed==404 and s.doctrines[0]==0 and not menu.overlay.visible,"Start applies draft mode, seed and traits")
	var initial_positions: PackedVector2Array=s.positions.duplicate()
	advance(s,30); s.doctrines[0]=2; store.restart_same_seed()
	check(s.positions==initial_positions and s.world_seed==404 and s.game_mode==0 and s.doctrines[0]==0,"Restart uses the original match configuration and seeded worker positions")
	var report: Dictionary={"complete":true,"passed":failures==0,"round_trips":samples}
	FileAccess.open("res://tests/save_load_verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if failures==0: print("PASS: asynchronous disk snapshots, both-mode/both-kernel exact continuation and RNG, invasion roster aliasing, recycled identities, paid daughter/nurse/forecast state, invalid/version rejection, backup recovery, autosave timing/outcomes and modal seeded setup/restart.")
	s.free(); loaded.free(); quit(1 if failures else 0)
