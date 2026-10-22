extends Node2D
## Painted once per reset into a private viewport, then sampled as one texture.
var garden
func _draw() -> void:
	if garden != null and garden.picture != null: garden.draw_decor(self)
