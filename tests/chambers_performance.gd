extends "res://tests/food_performance.gd"
func grow(s) -> void:
	super.grow(s)
	# Supply the stress colony without pretending it has unlimited room space.
	for c in 3:
		s.food_stores[c] = 12000
		s.protein_stores[c] = 3000
