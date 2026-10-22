extends RefCounted
## One coherent main-thread capture; object-free disk work runs off-thread.
const SCHEMA = preload("res://scripts/save_schema.gd")
const CODEC = preload("res://scripts/save_codec.gd")
var sim
var menu = preload("res://scripts/match_menu.gd").new()
var directory := "res://saves"
var match_config := {}
var autosave_interval := 120.0 # Active wall seconds, independent of game speed.
var autosave_clock := 0.0
var outcome_saved := false
var writer: Thread
var writing_slot := ""
var writing_meta := {}
var status := "F5 saves this match. F9 loads the manual slot."
var last_capture_ms := 0.0
var max_capture_ms := 0.0
var last_write_ms := 0.0
var saved_count := 0
var failed_count := 0
var last_bytes := 0

func setup(owner_node) -> void:
	sim=owner_node; menu.setup(self)
	if OS.has_feature("template"): directory="user://saves"
	var preferences:=ConfigFile.new()
	if preferences.load(directory.path_join("settings.cfg"))==OK:
		var interval=preferences.get_value("save","autosave_seconds",120.0)
		if interval in [0.0,60.0,120.0,300.0]: autosave_interval=interval
func set_autosave(interval: float) -> void:
	if interval not in [0.0,60.0,120.0,300.0]: return
	autosave_interval=interval; autosave_clock=0
	var preferences:=ConfigFile.new(); preferences.set_value("save","autosave_seconds",interval)
	var error:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error==OK: error=preferences.save(directory.path_join("settings.cfg"))
	status="Autosave off; existing files retained." if interval==0 else "Autosave every %d active wall minutes, plus match outcome." % int(interval/60)
	if error!=OK: status+=" Could not remember this setting for next launch."
func on_reset() -> void:
	match_config={"mode":sim.game_mode,"seed":sim.world_seed,"doctrines":sim.doctrines.duplicate()}
	autosave_clock=0; outcome_saved=false
	if is_instance_valid(menu.overlay): menu.overlay.visible=false
func slot_path(slot: String) -> String:
	return ProjectSettings.globalize_path(directory.path_join(slot+".formic"))
func groups() -> Dictionary:
	return {"sim":[sim,SCHEMA.SIM],"commands":[sim.command_system,SCHEMA.COMMANDS],
		"ai1":[sim.rival_ai,SCHEMA.AI],"ai2":[sim.third_ai,SCHEMA.AI],
		"orders1":[sim.rival_ai.orders,SCHEMA.COMMANDS],"orders2":[sim.third_ai.orders,SCHEMA.COMMANDS],
		"nest1":[sim.rival_ai.nest,SCHEMA.NEST],"nest2":[sim.third_ai.nest,SCHEMA.NEST],
		"chambers":[sim.chambers,SCHEMA.CHAMBERS],"progression":[sim.progression,SCHEMA.PROGRESSION],
		"scouting":[sim.scouting,SCHEMA.SCOUTING],"clarity":[sim.clarity,SCHEMA.CLARITY],
		"cycle":[sim.food_cycle,SCHEMA.CYCLE],"modes":[sim.game_modes,SCHEMA.MODES],
		"garden":[sim.garden,SCHEMA.GARDEN],"strategy_map":[sim.strategic_garden,SCHEMA.STRATEGY_MAP]}
func freeze(value):
	# Packed arrays need their own buffers too: direct script indexing can
	# mutate a shared wrapper while the encoder is reading on another thread.
	if typeof(value)>=TYPE_PACKED_BYTE_ARRAY: return value.duplicate()
	if value is Array:
		var copy: Array=value.duplicate()
		for i in copy.size(): copy[i]=freeze(copy[i])
		return copy
	if value is Dictionary:
		var copy: Dictionary=value.duplicate()
		for key in copy: copy[key]=freeze(copy[key])
		return copy
	return value
func capture() -> Dictionary:
	var start:=Time.get_ticks_usec()
	var values: Dictionary={}
	var all_groups:=groups()
	for key in all_groups:
		var data: Dictionary={}
		for field in all_groups[key][1]:
			var value=all_groups[key][0].get(field)
			data[field]=freeze(value)
		values[key]=data
	if is_instance_valid(menu.overlay) and menu.overlay.visible: values.sim.paused=menu.was_paused
	var streams:=PackedInt64Array()
	for random in sim.ant_rng: streams.append(random.seed); streams.append(random.state)
	var version:=Engine.get_version_info()
	var data: Dictionary={"rules":CODEC.RULES,"engine":"%d.%d" % [version.major,version.minor],"sections":values,"ants_rng":streams,
		"world_rng":PackedInt64Array([sim.rng.seed,sim.rng.state]),"strategy_rng":[PackedInt64Array([sim.rival_ai.target_rng.seed,sim.rival_ai.target_rng.state]),PackedInt64Array([sim.third_ai.target_rng.seed,sim.third_ai.target_rng.state])],
		"config":match_config.duplicate(true),"meta":{"mode":sim.game_mode,"seed":sim.world_seed,"seconds":sim.elapsed,"population":[sim.living_count(0),sim.living_count(1),sim.living_count(2)],"saved_at":Time.get_datetime_string_from_system()}}
	last_capture_ms=(Time.get_ticks_usec()-start)/1000.0; max_capture_ms=maxf(max_capture_ms,last_capture_ms)
	return data
func validate(data: Dictionary) -> String:
	var version:=Engine.get_version_info()
	if data.get("rules","")!=CODEC.RULES or data.get("engine","")!="%d.%d" % [version.major,version.minor]: return "Unsupported match/engine version."
	if not data.get("sections") is Dictionary: return "Missing saved match state."
	var all_groups:=groups()
	for key in all_groups:
		if not data.sections.get(key) is Dictionary: return "Missing saved section: "+key
		for field in all_groups[key][1]:
			if not data.sections[key].has(field) or typeof(data.sections[key][field])!=typeof(all_groups[key][0].get(field)): return "Invalid saved field: "+key+"."+field
	var s: Dictionary=data.sections.sim
	if s.colony_count!=3 or s.game_mode not in [0,1] or s.speed not in sim.SPEEDS: return "Unsupported match configuration."
	var n: int=s.health.size()
	if n<1 or n>sim.POPULATION_CAP*3 or data.get("ants_rng",PackedInt64Array()).size()!=n*2: return "Invalid saved worker/RNG count."
	for field in ["positions","headings","layers","roles","castes","max_health","carrying","cargo_resource","worker_ids","born_at","deliveries","worker_kills","walked","last_attackers","trips","targets","paths","colonies","attack_cooldowns","opponents","hit_flashes","combat_damage","route_goals","nurse_load","nurse_targets","worker_order_ids","worker_order_kinds","worker_order_goals"]:
		if s[field].size()!=n: return "Inconsistent worker array: "+field
	for field in ["earth","rival_earth","third_earth","orders","excavation","surface_speed","surface_shade","scent_active","food_scent","home_scent","rival_food_scent","rival_home_scent","third_food_scent","third_home_scent","protein_scent","rival_protein_scent","third_protein_scent"]:
		if s[field].size()!=sim.CELLS: return "Invalid saved map array: "+field
	for field in ["chamber_rooms","brood_buffers","storage_flow","exit_flow","tunnel_occupancy"]:
		if s[field].size()!=sim.CELLS*3: return "Invalid saved nest array: "+field
	if data.sections.garden.ground.size()!=sim.CELLS or s.brood.size()!=3 or s.colony_workers.size()!=3: return "Invalid saved colony geometry."
	if not data.get("world_rng") is PackedInt64Array or data.world_rng.size()!=2 or not data.get("strategy_rng") is Array or data.strategy_rng.size()!=2: return "Missing random streams."
	for stream in data.strategy_rng:
		if not stream is PackedInt64Array or stream.size()!=2: return "Invalid strategy random stream."
	if not data.get("config") is Dictionary or data.config.get("mode",-1)!=s.game_mode or data.config.get("seed",-1)!=s.world_seed or not data.config.get("doctrines") is PackedInt32Array or data.config.doctrines.size()!=3: return "Invalid saved starting configuration."
	var counts:=PackedInt32Array([0,0,0])
	var identities: Dictionary={}
	for i in n:
		if s.colonies[i]>2 or s.roles[i]>7 or s.layers[i]<-1 or s.layers[i]>2 or not s.positions[i].is_finite() or not is_finite(s.health[i]) or s.health[i]>s.max_health[i]+.001: return "Invalid individual worker state."
		if s.worker_ids[i]<=0 or identities.has(s.worker_ids[i]): return "Duplicate worker identity."
		identities[s.worker_ids[i]]=true
		if s.health[i]>0: counts[s.colonies[i]]+=1
	var base: int=12 if s.game_mode==1 else sim.COUNT
	for c in 3:
		if counts[c]!=base+s.births[c]-s.casualties[c]-s.starvation_losses[c]: return "Population ledger does not reconcile."
		if not is_finite(s.food_stores[c]) or not is_finite(s.protein_stores[c]) or s.protein_stores[c]+.02<data.sections.chambers.buffered[c]+data.sections.chambers.reserved[c] or s.food_stores[c]+s.protein_stores[c]>s.storage_capacity[c]+.02: return "Saved food ledger does not reconcile."
	return ""
func restore(data: Dictionary, pause_on_load: bool=true) -> bool:
	var problem:=validate(data)
	if not problem.is_empty(): status=problem+" Current match retained."; return false
	var all_groups:=groups()
	# Data was fully checked before any live assignment. Each load receives its
	# own containers; shared campaign rosters are explicitly reconnected below.
	for key in all_groups:
		for field in all_groups[key][1]:
			var value=data.sections[key][field]
			all_groups[key][0].set(field,freeze(value))
	sim.ant_rng.clear()
	for i in sim.health.size():
		var random:=RandomNumberGenerator.new()
		random.seed=data.ants_rng[i*2]; random.state=data.ants_rng[i*2+1]; sim.ant_rng.append(random)
	sim.rng.seed=data.world_rng[0]; sim.rng.state=data.world_rng[1]
	for c in 2:
		var ai=sim.rival_ai if c==0 else sim.third_ai
		ai.target_rng.seed=data.strategy_rng[c][0]; ai.target_rng.state=data.strategy_rng[c][1]
		for marker in ai.orders.markers:
			if marker.has("roster"): marker.roster=ai.raid_roster
	match_config=data.config.duplicate(true)
	sim.food_index_size=-1; sim.food_buckets.clear(); sim.food_neighbors.clear(); sim.encounter_neighbors.clear()
	sim.strategic_garden.cache.clear()
	sim.painting=false; sim.erasing=false; sim.dragging=false; sim.drag_moved=false
	sim.last_painted=Vector2i(-1,-1); sim.drag_button=MOUSE_BUTTON_NONE
	sim.clarity.close_panels(); sim.scouting.panel.visible=false; sim.progression.panel.visible=false
	sim.order_panel.visible=false; sim.labor_panel.visible=false; sim.rival_panel.visible=false
	menu.overlay.visible=false; sim.paused=true if pause_on_load else sim.paused
	sim._rebuild_map_images(); sim.garden.refresh_picture(); sim.scouting.refresh_territory()
	sim.garden_painter.queue_redraw(); sim.garden_cache.render_target_update_mode=SubViewport.UPDATE_ONCE
	if not RenderingServer.frame_post_draw.is_connected(sim._finish_garden_bake): RenderingServer.frame_post_draw.connect(sim._finish_garden_bake,CONNECT_ONE_SHOT)
	sim._sync_camera(); sim.decor_canvas.queue_redraw(); sim.mini_canvas.queue_redraw(); sim.world_canvas.queue_redraw()
	autosave_clock=0; outcome_saved=not sim.match_result.is_empty()
	sim._update_ui()
	return true
func request_save(slot: String="manual") -> bool:
	if busy() or slot not in ["manual","autosave"]: return false
	var data:=capture()
	writer=Thread.new(); writing_slot=slot; writing_meta=data.meta.duplicate(); status="Saving %s…" % slot
	var error:=writer.start(CODEC.write_file.bind(slot_path(slot),data))
	if error!=OK: writer=null; failed_count+=1; status="Could not start save: "+error_string(error); return false
	return true
func busy() -> bool: return writer!=null
func collect_save() -> void:
	if writer==null: return
	var result: Dictionary=writer.wait_to_finish(); writer=null
	if result.has("error"): failed_count+=1; status=result.error
	else:
		saved_count+=1; last_bytes=result.bytes; last_write_ms=result.write_ms
		status="Saved %s · seed %d · %02d:%02d" % [writing_slot,writing_meta.seed,int(writing_meta.seconds)/60,int(writing_meta.seconds)%60]
	if is_instance_valid(menu.overlay) and menu.overlay.visible: menu.refresh_slots()
func load_slot(slot: String="manual", previous: bool=false) -> bool:
	if slot not in ["manual","autosave"]: return false
	if busy(): status="Wait for the current save to finish."; return false
	var path:=slot_path(slot)+( ".bak" if previous else "")
	var result:=CODEC.read_file(path)
	var recovered:=false
	if result.has("error") and not previous and not result.get("unsupported",false):
		var backup:=CODEC.read_file(path+".bak")
		if not backup.has("error"): result=backup; recovered=true
	if result.has("error"): status=result.error+" Current match retained."; return false
	if not restore(result.data): return false
	status=("Recovered previous " if recovered or previous else "Loaded ")+slot+". Paused; resume when ready."
	return true
func tick(delta: float) -> void:
	if writer!=null and not writer.is_alive(): collect_save()
	if autosave_interval<=0 or busy() or (is_instance_valid(menu.overlay) and menu.overlay.visible): return
	if not sim.match_result.is_empty():
		if not outcome_saved: outcome_saved=request_save("autosave")
		return
	if sim.paused: return
	autosave_clock+=minf(delta,.15)
	if autosave_clock>=autosave_interval and request_save("autosave"): autosave_clock=0
func restart_same_seed() -> void:
	if busy(): return
	var config: Dictionary=match_config.duplicate(true)
	menu.close(); sim.doctrines=config.doctrines.duplicate()
	sim.game_modes.start(config.mode,config.seed)
func finish() -> void:
	if writer!=null: collect_save()
