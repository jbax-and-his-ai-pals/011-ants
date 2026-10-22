extends "res://scripts/colony.gd"
## Diagnostic continuation only: record the real first outcome, then observe
## other colonies to distinguish a lost race from an inability to develop.
var first_result := ""
var first_finish := -1.0
var first_winners: Array = []
var first_snapshot: Array = []
func reset_colony(seed_value: int = 81923) -> void:
	super.reset_colony(seed_value)
	first_result = ""; first_finish = -1; first_winners = []; first_snapshot = []
func _check_outcome() -> void:
	if game_mode != game_modes.FOUNDING: super._check_outcome(); return
	if first_result.is_empty():
		first_result = progression.outcome()
		if not first_result.is_empty():
			first_finish = elapsed
			for c in colony_count:
				if not progression.daughters[c].is_empty() and progression.daughters[c].complete: first_winners.append(c)
			first_snapshot = progression.daughters.duplicate(true)
