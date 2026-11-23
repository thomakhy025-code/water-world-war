extends Node2D

const Rules = preload("res://scripts/army_rules.gd")

signal changed

var team_id := 0
var color := Color.WHITE
var team_name := "Blue"
var food := 0.0
var supply_radius := 0.0
var accepts_food := true
var storage_name := "Castle"
var rally_point := Vector2.ZERO


func _ready() -> void:
	supply_radius = Rules.CASTLE_RADIUS
	add_to_group("castles")
	add_to_group("storages")
	z_index = 2
	queue_redraw()


func add_food(amount: float) -> void:
	if amount <= 0.0:
		return
	food += amount
	changed.emit()
	queue_redraw()


func take_food(amount: float) -> float:
	var taken := minf(food, amount)
	if taken <= 0.0:
		return 0.0
	food -= taken
	changed.emit()
	queue_redraw()
	return taken


func _draw() -> void:
	draw_rect(Rect2(-70, -54, 140, 108), color.darkened(0.45))
	draw_rect(Rect2(-58, -42, 116, 84), color.darkened(0.15))
	draw_rect(Rect2(-10, -78, 20, 28), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -78), Vector2(36, -70), Vector2(10, -62)
	]), Color.WHITE)
	draw_arc(Vector2.ZERO, supply_radius, 0, TAU, 48, Color(color.r, color.g, color.b, 0.28), 2.0)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(-40, -4), team_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(-40, 18), "Food %d" % roundi(food), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
