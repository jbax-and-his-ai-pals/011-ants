extends Node2D
## A clipped canvas delegates drawing to the simulation without owning ant nodes.
var colony: Node2D
var minimap := false
var decoration := false

func _draw() -> void:
	if is_instance_valid(colony):
		if decoration:
			colony._draw_surface_decor(self)
		elif minimap:
			colony._draw_minimap(self)
		else:
			colony._draw_world(self)
