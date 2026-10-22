extends "res://tests/observed_colony.gd"
## Full-match diagnostic: layers remain colony-owned, but their terrain comes
## from the physical seat. Food stays in place as colors/RNG/traits rotate.
var seat_offset := 0
func nest_position(colony: int) -> Vector2:
	return [HOME, RIVAL_HOME, THIRD_HOME][(colony + seat_offset) % 3]
func chamber_cell(colony: int) -> Vector2i:
	return _cell(nest_position(colony))
func _nest_grid(colony: int) -> PackedByteArray:
	return [earth, rival_earth, third_earth][(colony + seat_offset) % 3]

func _ready() -> void:
	fixed_starting_seats = true
	super._ready()
