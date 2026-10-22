extends RefCounted
## Modal match setup keeps text entry and navigation out of simulation input.
var store_ref: WeakRef
var store:
	get: return store_ref.get_ref()
var sim
var overlay: Control
var panel: Panel
var was_paused := false
var mode: OptionButton
var seed_input: LineEdit
var traits: Array[OptionButton]=[]
var autosave: OptionButton
var info: Label
var manual_info: Label
var auto_info: Label
var current: Label
var actions: Array[Button]=[]
var toast: Label
func setup(owner_store) -> void: store_ref=weakref(owner_store); sim=owner_store.sim
func build_ui() -> void:
	overlay=Control.new(); overlay.size=Vector2(1440,900); overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	sim.ui.add_child(overlay)
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,.72); shade.size=overlay.size; overlay.add_child(shade)
	panel=Panel.new(); panel.position=Vector2(340,158); panel.size=Vector2(760,610)
	panel.add_theme_stylebox_override("panel",sim._style(Color("14251c"),12,sim.ACCENT)); overlay.add_child(panel)
	var old=sim.ui; sim.ui=panel
	sim._label("MATCH / SAVE & LOAD",Vector2(20,12),22,sim.ACCENT,true,640)
	sim._button("x",Vector2(706,10),Vector2(34,30),close)
	current=sim._label("",Vector2(20,49),12,sim.MUTED,false,710)
	sim._label("New match mode",Vector2(20,76),12,sim.INK,false,190)
	mode=option(Vector2(20,98),Vector2(190,34),["Skirmish · 2,000 each","Founding · 12 each"])
	sim._label("Seed (0–4294967295)",Vector2(230,76),12,sim.INK,false,250)
	seed_input=LineEdit.new(); seed_input.position=Vector2(230,98); seed_input.size=Vector2(245,34)
	seed_input.max_length=10; seed_input.add_theme_font_size_override("font_size",14); panel.add_child(seed_input)
	sim._button("Random seed",Vector2(492,98),Vector2(152,34),func(): seed_input.text=str(randi()))
	for c in 3:
		sim._label(sim.COLONY_NAMES[c]+" trait",Vector2(20+c*240,146),12,sim.INK,false,215)
		traits.append(option(Vector2(20+c*240,167),Vector2(215,32),["Balanced","Stewards","Raiders"]))
	actions.append(sim._button("Start new match",Vector2(20,214),Vector2(224,36),start_match))
	actions.append(sim._button("Restart same seed",Vector2(260,214),Vector2(224,36),store.restart_same_seed))
	sim._label("MANUAL SAVE",Vector2(20,272),14,sim.ACCENT,true,300)
	manual_info=sim._label("",Vector2(20,300),12,sim.MUTED,false,710)
	actions.append(sim._button("Save current [F5]",Vector2(20,330),Vector2(224,34),func(): store.request_save(); refresh()))
	actions.append(sim._button("Load manual [F9]",Vector2(260,330),Vector2(224,34),func(): store.load_slot(); refresh()))
	actions.append(sim._button("Previous manual",Vector2(500,330),Vector2(224,34),func(): store.load_slot("manual",true); refresh()))
	sim._label("AUTOSAVE",Vector2(20,386),14,sim.ACCENT,true,300)
	auto_info=sim._label("",Vector2(20,414),12,sim.MUTED,false,710)
	actions.append(sim._button("Load autosave",Vector2(20,444),Vector2(224,34),func(): store.load_slot("autosave"); refresh()))
	actions.append(sim._button("Previous autosave",Vector2(260,444),Vector2(224,34),func(): store.load_slot("autosave",true); refresh()))
	autosave=option(Vector2(500,444),Vector2(224,34),["Autosave off","Every 1 active minute","Every 2 active minutes","Every 5 active minutes"])
	autosave.select([0.0,60.0,120.0,300.0].find(store.autosave_interval))
	autosave.item_selected.connect(func(index: int): store.set_autosave([0.0,60.0,120.0,300.0][index]))
	info=sim._label("",Vector2(20,498),12,sim.INK,false,710); info.size.y=64; info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sim._label("Opening setup pauses play. Loading restores the match paused.\nManual and autosave slots each keep a previous good save. Escape closes.",Vector2(20,566),11,sim.MUTED,false,710)
	sim.ui=old; overlay.visible=false
	toast=sim._label("F5 save · F9 load · M match setup",Vector2(1040,80),10,sim.MUTED,false,380)
	toast.mouse_filter=Control.MOUSE_FILTER_STOP
func option(pos: Vector2, dimensions: Vector2, labels: Array) -> OptionButton:
	var field:=OptionButton.new(); field.position=pos; field.size=dimensions
	field.add_theme_font_size_override("font_size",12); field.add_theme_stylebox_override("normal",sim._style(Color("22342a"),7))
	for text in labels: field.add_item(text)
	panel.add_child(field); return field
func open_setup(selected_mode: int=-1) -> void:
	if overlay.visible: return
	was_paused=sim.paused; sim.paused=true
	sim.painting=false; sim.erasing=false; sim.dragging=false
	mode.select(sim.game_mode if selected_mode<0 else selected_mode); seed_input.text=str(sim.world_seed)
	for c in 3: traits[c].select(sim.doctrines[c])
	sim.clarity.close_panels(); sim.scouting.panel.visible=false; sim.progression.panel.visible=false
	sim.order_panel.visible=false; sim.labor_panel.visible=false; sim.rival_panel.visible=false
	overlay.visible=true; refresh_slots(); refresh(); sim._update_ui()
func toggle() -> void:
	if overlay.visible: close()
	else: open_setup()
func close() -> void:
	if not is_instance_valid(overlay) or not overlay.visible: return
	overlay.visible=false; sim.paused=was_paused
	seed_input.release_focus(); sim._update_ui()
func start_match() -> void:
	if store.busy(): return
	var text:=seed_input.text.strip_edges()
	if not text.is_valid_int() or text.to_int()<0 or text.to_int()>4294967295:
		store.status="Enter a whole seed from 0 to 4294967295, or use Random seed."; refresh(); return
	var next_traits:=PackedInt32Array()
	for trait_option in traits: next_traits.append(trait_option.selected)
	var next_mode:=mode.selected
	close(); sim.doctrines=next_traits; sim.game_modes.start(next_mode,text.to_int())
func slot_summary(slot: String) -> String:
	var result: Dictionary=store.CODEC.read_file(store.slot_path(slot))
	if result.has("error"): return result.error
	var meta: Dictionary=result.data.get("meta",{})
	return "%s · seed %d · %02d:%02d · %s" % ["Founding" if meta.get("mode",0) else "Skirmish",meta.get("seed",0),int(meta.get("seconds",0))/60,int(meta.get("seconds",0))%60,meta.get("saved_at","").replace("T"," ")]
func refresh_slots() -> void:
	manual_info.text=slot_summary("manual"); auto_info.text=slot_summary("autosave")
func refresh() -> void:
	if is_instance_valid(toast):
		toast.text=store.status.left(65); toast.tooltip_text=store.status
	if not is_instance_valid(overlay) or not overlay.visible: return
	current.text="Current: %s · seed %d · %02d:%02d · %s× speed" % ["Founding" if sim.game_mode else "Skirmish",sim.world_seed,int(sim.elapsed)/60,int(sim.elapsed)%60,str(sim.speed)]
	info.text=store.status; info.tooltip_text=store.status+"\nSave folder: "+ProjectSettings.globalize_path(store.directory)
	for action in actions: action.disabled=store.busy()
