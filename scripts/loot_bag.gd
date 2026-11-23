extends Node2D

var food := 0.0
var materials := 0.0


func _ready() -> void:
	add_to_group("loot_bags")
	z_index = 4
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8, Color("c9a227"))
	var parts: PackedStringArray = []
	if food > 0.5:
		parts.append("F%d" % roundi(food))
	if materials > 0.5:
		parts.append("M%d" % roundi(materials))
	draw_string(ThemeDB.fallback_font, Vector2(-16, -14), " ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
