extends Node2D

const Rules = preload("res://scripts/army_rules.gd")

var kind := "fruit"
var stock := 0.0
var max_stock := 1.0
var idle := 0.0
var radius := 0.0


func _ready() -> void:
	add_to_group("resource_nodes")
	radius = Rules.HARVEST_RADIUS
	max_stock = Rules.node_max(kind)
	stock = max_stock
	z_index = 1
	queue_redraw()


func _process(delta: float) -> void:
	idle += delta
	if idle < Rules.NODE_REGEN_DELAY or stock >= max_stock:
		return
	stock = minf(max_stock, stock + Rules.node_regen(kind) * delta)
	queue_redraw()


## Removes only what the captain can carry. Danger applies while a beast is actually hunted.
func take(delta: float, food_room: float, mat_room: float) -> Dictionary:
	var result := {"food": 0.0, "materials": 0.0, "danger": 0.0}
	var available := minf(stock, Rules.node_rate(kind) * delta)
	var taken := 0.0
	if kind == "tree" or kind == "ore":
		taken = minf(available, mat_room)
		result.materials = taken
	else:
		taken = minf(available, food_room)
		result.food = taken
	if taken <= 0.0:
		return result
	stock -= taken
	idle = 0.0
	if kind == "beast":
		result.danger = Rules.BEAST_DANGER_PER_SEC * delta
	queue_redraw()
	return result


func _draw() -> void:
	var color := Color("e2b23a")
	match kind:
		"tree":
			color = Color("2f8f4e")
			draw_rect(Rect2(-4, 4, 8, 16), Color("6b4a2a"))
			draw_circle(Vector2(0, -2), 16, color)
		"ore":
			color = Color("b7c0c8")
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -16), Vector2(14, 0), Vector2(0, 16), Vector2(-14, 0)
			]), color)
		"beast":
			color = Color("d36b2c")
			draw_circle(Vector2.ZERO, 16, color)
			draw_circle(Vector2(-5, -3), 2, Color.BLACK)
			draw_circle(Vector2(5, -3), 2, Color.BLACK)
			draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color("ff6b4a"), 2.0)
		_:
			draw_circle(Vector2.ZERO, 12, color)
			draw_line(Vector2(0, -14), Vector2(8, -22), Color("3c8f45"), 2.0)
	var pct := stock / max_stock
	draw_arc(Vector2.ZERO, 26, -PI * 0.5, -PI * 0.5 + TAU * pct, 24, Color(1, 1, 1, 0.85), 2.0)
	var title := kind
	draw_string(ThemeDB.fallback_font, Vector2(-18, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
