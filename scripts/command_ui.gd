extends RefCounted

static func build(s) -> void:
	s.command_buttons.resize(5)
	var positions := [782, 314, 434, 550, 666]
	for kind in 5:
		var title: String = "Inspect [Esc]" if kind == 0 else "%s [%d]" % [s.command_system.NAMES[kind], kind + 3]
		var button: Button = s._button(title, Vector2(positions[kind], 797), Vector2(110, 36), func() -> void: s.set_command_tool(kind))
		button.add_theme_font_size_override("font_size", 13)
		s.command_buttons[kind] = button
	s.command_buttons[1].tooltip_text = "Mark a food site. A bounded share of your foragers travels there; workers still find food locally and carry one unit home. Depleted known sites stop recruiting."
	s.command_buttons[2].tooltip_text = "Maintain a small guard patrol around this point. Guards engage nearby enemies and return to their post. Underground [5] places a connected nest guard post: workers enter and walk there."
	s.command_buttons[3].tooltip_text = "Mark a 100px danger area. Your ants detour around it, ignore food inside and avoid pursuing enemies into it. Contact combat remains possible. Keep your entrance clear."
	s.command_buttons[4].tooltip_text = "Maintain a raid party at a surface target. Mark within 90px of the rival entrance to invade its tunnels and attack its queen. Only one Raid marker exists; placing another moves it."
	s._button("Priorities [L]", Vector2(900, 797), Vector2(132, 36), s.toggle_labor_panel)
	s.command_clear_button = s._button("Clear orders", Vector2(1040, 797), Vector2(108, 36), s.clear_surface_orders)
	s.command_clear_button.add_theme_font_size_override("font_size", 12)
	s.hotspot_button = s._button("No recent losses", Vector2(44, 737), Vector2(220, 26), s.focus_loss_hotspot)
	s.hotspot_button.add_theme_font_size_override("font_size", 11)
	s.hotspot_button.tooltip_text = "Show the cluster with the most of your losses in the last 30 simulated seconds, switching nest layers if necessary."
	s.labor_panel = Panel.new()
	s.labor_panel.position = Vector2(324, 254)
	s.labor_panel.size = Vector2(410, 356)
	s.labor_panel.add_theme_stylebox_override("panel", s._style(Color("14251c"), 12, Color("58765c")))
	s.ui.add_child(s.labor_panel)
	var previous = s.ui
	s.ui = s.labor_panel
	s._label("LABOR PRIORITIES", Vector2(20, 15), 17, s.ACCENT, true, 320)
	s._button("×", Vector2(365, 10), Vector2(30, 28), s.toggle_labor_panel)
	for category in 3:
		s._label(["Marked forage sites", "Guard + raid parties", "Excavation crew"][category], Vector2(20, 68 + category * 55), 14, s.INK, false, 220)
		var button: Button = s._button("Normal", Vector2(248, 60 + category * 55), Vector2(142, 36), func() -> void: s.set_labor_priority(category, (s.command_system.labor[category] + 1) % 4))
		s.priority_buttons.append(button)
	s.priority_details = s._label("", Vector2(20, 232), 12, s.MUTED, false, 372)
	s.priority_details.size.y = 110
	s.priority_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.ui = previous
	s.labor_panel.visible = false
	s._button("Orders [O]", Vector2(1156, 797), Vector2(124, 36), s.toggle_order_panel)
	s.food_notice = s._button("", Vector2(324, 178), Vector2(630, 30), s.food_cycle.focus)
	s.food_notice.add_theme_font_size_override("font_size", 12)
	s.food_notice.tooltip_text = "Public food forecast: three sites every 120 simulated seconds, with 30 seconds' notice. Each tops up to 6,000 food. All colonies can prepare. Click to focus a gold ring."
	s.garden_legend = s._label("SOIL +15% SPEED · SHADE 2× TRAILS\nFruit / nectar: sugar · Insects: protein", Vector2(970, 179), 10, s.INK, false, 230)
	s.garden_legend.size.y = 32
	s.garden_legend.mouse_filter = Control.MOUSE_FILTER_STOP
	s.garden_legend.tooltip_text = "Warm bare-soil paths give every surface ant +15% movement. Each nest has a modest sugar source on an exposed soil approach and richer protein along a longer shaded approach. Shade doubles pheromone half-life; it gives no combat protection. T compares surface round trips, soil/shade and observed danger. All terrain stays walkable. Fruit/nectar support upkeep and recovery; insects support brood. Nearby Founding starters stay varied and guaranteed. Workers carry one unit and follow individual local sensing, orders and trails."
	s.order_panel = Panel.new()
	s.order_panel.position = Vector2(324, 254)
	s.order_panel.size = Vector2(552, 516)
	s.order_panel.add_theme_stylebox_override("panel", s._style(Color("14251c"), 12, Color("58765c")))
	s.ui.add_child(s.order_panel)
	s.ui = s.order_panel
	s._label("YOUR SURFACE ORDERS", Vector2(18, 14), 17, s.ACCENT, true, 460)
	s._button("×", Vector2(504, 10), Vector2(30, 28), s.toggle_order_panel)
	s._label("Assigned · sugar/protein delivered · 30s losses · why waiting", Vector2(18, 46), 12, s.MUTED, false, 516)
	for row in 8:
		var button: Button = s._button("", Vector2(18, 62 + row * 50), Vector2(516, 48), func() -> void:
			if row < s.command_system.markers.size(): s.focus_order(s.command_system.markers[row].id))
		button.add_theme_font_size_override("font_size", 11)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "Click to focus. Deliveries belong to the order held at pickup, even if that ant is reassigned before returning home. Losses belong to the order held at death. Counts refresh each simulated second."
		s.order_rows.append(button)
	s._label("Hover for full explanation; click a row to focus. L: labor priorities.\n4/5/6/7 place orders. Deliveries and losses use simulated time.", Vector2(18, 472), 12, s.MUTED, false, 516)
	s.ui = previous
	s.order_panel.visible = false

static func duration_text(seconds: float) -> String:
	if is_inf(seconds): return "stable"
	var rounded := maxi(0, ceili(seconds))
	return "%dm %02ds" % [rounded / 60, rounded % 60]

static func update(s) -> void:
	var report: Dictionary = s.command_system.report
	s.garden_legend.visible = not s.underground
	s.food_notice.text = s.food_cycle.headline()
	s.food_notice.tooltip_text = "Public forecasts arrive 30 seconds before supplies. Founding: local 360-unit sites continue alongside later shared 1,200-unit sites. Skirmish: three 6,000-unit sites per wave. Announcement does not reveal current stock to scouts. Click to focus a forecast."
	s.food_notice.visible = not s.underground or not s.chambers_enabled
	for row in s.order_rows.size():
		var button: Button = s.order_rows[row]
		button.visible = row < s.command_system.markers.size()
		if not button.visible: continue
		var marker: Dictionary = s.command_system.markers[row]
		var losses: Array = marker.get("recent_losses", [0, 0])
		var resources: Array = s.command_system.order_resources.get(marker.id, [0, 0])
		button.tooltip_text = s.clarity.order_reasons.get(marker.id, "Awaiting observation refresh") + "\nClick to focus this order."
		button.text = "#%d %s · %s\n%d ants · %d sugar / %d protein home · losses %dC / %dH" % [marker.id, s.command_system.NAMES[marker.kind], marker.status, marker.assigned, resources[0], resources[1], losses[0], losses[1]] + "\n" + s.clarity.order_reasons.get(marker.id,"Awaiting observation refresh").left(76)
	var harvesting := 0
	var guarding := 0
	for marker in s.command_system.markers:
		if marker.kind == 1: harvesting += marker.assigned
		if marker.kind == 2: guarding += marker.assigned
	for kind in 5:
		s._active(s.command_buttons[kind], s.command_tool == kind)
		s.command_buttons[kind].disabled = kind != 0 and not s.match_result.is_empty()
	for category in 3:
		s.priority_buttons[category].text = s.command_system.PRIORITIES[s.command_system.labor[category]]
		s.priority_buttons[category].disabled = not s.match_result.is_empty()
		s._active(s.priority_buttons[category], s.command_system.labor[category] == 3)
	s.command_clear_button.disabled = s.command_system.markers.is_empty() or not s.match_result.is_empty()
	s.priority_details.text = "Marked forage: %d assigned; others scout freely.\nSecurity: up to %d per post; max 48 / 20%% of workers.\nDigging: up to %d workers while work is queued.\nCarriers finish delivery. Home defense stays automatic." % [harvesting, s.command_system.raid_limit(), s.command_system.digging_limit()]
	if not s.match_result.is_empty(): s.labor_panel.visible = false
	s.stats.food.add_theme_font_size_override("font_size", 15)
	s.stats.food.position.y = 267
	s.stats.food.size = Vector2(100, 48)
	s.stats.rival_food.size = Vector2(112, 42)
	s.stats.harvest.position.y = 320
	s.stats.rival_food.add_theme_font_size_override("font_size", 11)
	s.stats.food.text = "S %d\nP %d" % [s.food_stores[0], s.protein_stores[0]]
	s.stats.rival_food.text = "S %d / %d\nP %d / %d" % [s.food_stores[1], s.food_stores[2], s.protein_stores[1], s.protein_stores[2]] if s.colony_count == 3 else "S %d\nP %d" % [s.food_stores[1], s.protein_stores[1]]
	s.stats.food.tooltip_text = "Amber stores: sugar for upkeep and recovery; protein for brood."
	s.stats.rival_food.tooltip_text = "Coral / Azure stores, in that order. S = sugar; P = protein."
	s.stats.harvest.add_theme_font_size_override("font_size", 11)
	s.stats.harvest.text = "Sugar +%.0f / −%.0f per min\nProtein +%.0f / −%.0f per min\nSugar: %s at current upkeep\n%s" % [report.sugar_income, report.upkeep, report.protein_income, report.brood, duration_text(s.food_stores[0] / maxf(0.001, s.upkeep_rate(0))), s.nutrition.status(0)]
	s.stats.harvest.add_theme_color_override("font_color", s.RIVAL if s.food_stores[0] < s.upkeep_rate(0) * 30 else (s.ACCENT if s.protein_stores[0] < 8 else s.MUTED))
	s.stats.harvest.tooltip_text = "S = sugar, P = protein. Fruit and nectar pay worker/queen upkeep and healing; insects pay brood costs. In/out rates use up to 30 simulated seconds. Protein cannot prevent sugar starvation; sugar cannot replace protein for brood. Foragers automatically weight nearby food and distinct trails toward the resource running short. Cargo already collected always comes home."
	s.stats.losses.text = "Total losses · combat %d / hunger %d" % [s.casualties[0], s.starvation_losses[0]]
	s.stats.combat.text = "Last 30s · combat %d / hunger %d" % [report.combat, report.hunger]
	s.hotspot_button.disabled = s.command_system.hotspot.is_empty()
	s.hotspot_button.text = "Loss hotspot · %d recent deaths" % s.command_system.hotspot.count if not s.command_system.hotspot.is_empty() else "No recent losses"
	s.stats.foragers.text += " · %d marked" % harvesting
	s.stats.diggers.text += " · %d on guard posts" % guarding
	if s.dig_mode and s.underground and s.chambers_enabled:
		s.hint_label.text = "PLAN: G tunnels · 8 storage · 9 brood · LEFT drag designate · RIGHT drag erase · ESC inspect · 5 nest guard"
	elif s.command_tool > 0:
		s.hint_label.text = "%s: CLICK place · DRAG pan · RIGHT-CLICK marker remove · ESC inspect · L priorities · 8 markers max" % s.command_system.NAMES[s.command_tool].to_upper()
	elif not s.dig_mode:
		s.hint_label.text = "DRAG pan · WHEEL zoom · CLICK ant · 4/5/6/7 orders · RIGHT-CLICK marker remove · O orders · L priorities · G/8/9 tunnels/storage/brood"
