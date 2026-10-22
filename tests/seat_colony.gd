extends "res://tests/observed_colony.gd"
## Surface-only diagnostic: permute colors/RNG streams over the three physical
## seats. Invasions and reproduction are disabled by the caller, so legacy
## per-colony tunnel grids do not participate in this experiment.
var seat_offset := 0
func nest_position(colony: int) -> Vector2:
	return [HOME, RIVAL_HOME, THIRD_HOME][(colony + seat_offset) % 3]

func _ready() -> void:
	fixed_starting_seats = true
	super._ready()
