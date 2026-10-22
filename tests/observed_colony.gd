extends "res://scripts/colony.gd"
## Diagnostic observer only: continue beyond Amber's defeat to identify a winner.
## Product rules remain unchanged. Optional identical strategic controllers.
var equal_controllers := false
var player_ai = preload("res://scripts/rival_strategy.gd").new()
var winner := -2
var game_result := ""
var game_end_seconds := -1.0
var eliminations: Array = []
var observed_dead := PackedByteArray([0, 0, 0])

func _ready() -> void:
	player_ai.setup(self, 0)
	super._ready()

func reset_colony(seed_value: int = 81923) -> void:
	super.reset_colony(seed_value)
	player_ai.reset()
	winner = -2
	game_result = ""
	game_end_seconds = -1
	eliminations.clear()
	observed_dead.fill(0)

func colony_orders(c: int):
	return player_ai.orders if equal_controllers and c == 0 else super.colony_orders(c)

func simulate(dt: float) -> void:
	if equal_controllers and allocation_clock + dt >= 0.8 and match_result.is_empty(): player_ai.update()
	super.simulate(dt)

func launch_raid(colony: int, requested: int = 12) -> int:
	if equal_controllers and colony == 0: return 0
	return super.launch_raid(colony, requested)

func _kill_ant(i: int, starved: bool = false) -> void:
	player_ai.orders.record_loss(i, starved)
	super._kill_ant(i, starved)

func _check_outcome() -> void:
	if game_mode == game_modes.FOUNDING:
		super._check_outcome()
		if not match_result.is_empty():
			game_result = match_result; game_end_seconds = elapsed
			for c in colony_count:
				if not progression.daughters[c].is_empty() and progression.daughters[c].complete: winner = c
		return
	if not match_result.is_empty(): return
	var alive: Array[int] = []
	for c in colony_count:
		if queen_health[c] > 0: alive.append(c)
		elif not observed_dead[c]:
			observed_dead[c] = 1
			eliminations.append({"colony": c, "progression_paths": Array(progression.paths), "soldiers": Array(progression.soldier_counts), "daughters": progression.daughters.duplicate(true), "starting_seat_offset": starting_seat_offset, "seconds": snappedf(elapsed, 0.01), "cause": queen_death_causes[c], "workers": living_count(c)})
	if game_result.is_empty() and (queen_health[0] <= 0 or alive.size() <= 1):
		game_result = "draw" if alive.is_empty() else ("victory" if alive == [0] else "defeat")
		game_end_seconds = elapsed
	if alive.size() <= 1:
		winner = alive[0] if not alive.is_empty() else -1
		match_result = "draw" if winner < 0 else ("victory" if winner == 0 else "defeat")

func census() -> Dictionary:
	var population := [0, 0, 0]
	var fights := [0, 0, 0]
	var recovery := [0, 0, 0]
	var missions := [0, 0, 0]
	var underground_count := [0, 0, 0]
	var active_ids := {}
	var invalid := 0
	for i in health.size():
		if health[i] <= 0: continue
		var c: int = colonies[i]
		population[c] += 1
		if cargo_resource[i] > 1: invalid += 1
		if opponents[i] >= 0: fights[c] += 1
		if roles[i] == RECOVERING: recovery[c] += 1
		if roles[i] == INVADER: missions[c] += 1
		if layers[i] >= 0:
			underground_count[c] += 1
			if _nest_grid(layers[i])[_idx(_cell(positions[i]))] != 1: invalid += 1
		if active_ids.has(worker_ids[i]): invalid += 1
		active_ids[worker_ids[i]] = true
	var remaining := 0
	for patch in foods: remaining += patch.amount
	return {"starting_seat_offset": starting_seat_offset, "seconds": snappedf(elapsed, 0.01), "population": population, "queens": Array(queen_health), "stores": Array(food_stores), "storage_capacity": Array(storage_capacity), "brood_capacity": Array(brood_capacity), "buffered_protein": Array(chambers.buffered), "reserved_protein": Array(chambers.reserved), "storage_released": Array(storage_released), "protein_stores": Array(protein_stores), "resource_delivered": Array(resource_delivered), "nutrition_weights": Array(nutrition_weights), "births": Array(births), "combat_losses": Array(casualties), "hunger_losses": Array(starvation_losses), "fighting": fights, "recovering": recovery, "raiders": missions, "underground": underground_count, "harvest": [delivered, rival_delivered, third_delivered], "food_remaining": remaining, "slots": health.size(), "scent_cells": active_scent.size(), "modes": [player_ai.mode if equal_controllers else "player_autonomous", rival_ai.mode, third_ai.mode], "invalid_state": invalid, "ai_targets": [player_ai.enemy_id if equal_controllers else enemy_for(0), rival_ai.enemy_id, third_ai.enemy_id], "target_reasons": [player_ai.target_reason if equal_controllers else "Legacy nearest-nest automation", rival_ai.target_reason, third_ai.target_reason], "nest_plans": [nest_info(player_ai) if equal_controllers else {}, nest_info(rival_ai), nest_info(third_ai)], "raid_telemetry": [raid_info(player_ai) if equal_controllers else {}, raid_info(rival_ai), raid_info(third_ai)], "target_scores": [player_ai.target_scores.duplicate(true) if equal_controllers else [], rival_ai.target_scores.duplicate(true), third_ai.target_scores.duplicate(true)]}

func raid_info(ai) -> Dictionary:
	return {"active": ai.raid_until > 0, "started": ai.raid_counts.started, "progress": ai.raid_counts.progress, "recalls": ai.raid_counts.recalls.duplicate(), "status": ai.raid_status, "living_party": ai.raid_living, "lost_party": ai.raid_dead, "inside": ai.raid_inside, "recruited": ai.raid_roster.size(), "budget": ai.raid_budget, "phase": ai.raid_phase, "phase_counts": ai.phase_counts.duplicate(), "probe_arrived_at": ai.probe_arrived_at, "next_attack": ai.next_attack, "deadline": ai.raid_until, "hard_deadline": ai.raid_hard_until}

func nest_info(ai) -> Dictionary:
	return {"project": ai.nest.project, "reason": ai.nest.reason, "pending": ai.nest.pending.size(), "dug": dug if ai.colony == 0 else ai.nest.dug, "projects": ai.nest.projects, "diggers": digger_count(ai.colony), "widened": ai.nest.widened, "guard_cell": ai.nest.guard_cell}
