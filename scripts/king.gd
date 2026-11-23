extends Node2D

const Rules = preload("res://scripts/army_rules.gd")
const Feedback = preload("res://scripts/feedback.gd")

signal changed
signal defeated(team_id: int)

var team_id := 0
var color := Color.WHITE
var team_name := "Blue"
var hp := 0.0
var max_hp := 0.0
var _down := false


func _ready() -> void:
	max_hp = Rules.KING_HP
	hp = max_hp
	add_to_group("kings")
	add_to_group("damageable")
	z_index = 3
	queue_redraw()


func is_targetable() -> bool:
	return hp > 0.0


func apply_damage(amount: float) -> void:
	if _down or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	Feedback.rising_text(get_parent(), global_position + Vector2(-8, -36), str(roundi(amount)), Color("ffd0d0"))
	queue_redraw()
	if hp <= 0.0:
		_down = true
		defeated.emit(team_id)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 30, color.darkened(0.25))
	draw_circle(Vector2.ZERO, 22, color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -16), Vector2(-8, -28), Vector2(-2, -16),
		Vector2(0, -30), Vector2(2, -16), Vector2(8, -28), Vector2(14, -16)
	]), Color("f2d36b"))
	var pct := 0.0 if max_hp <= 0.0 else hp / max_hp
	draw_rect(Rect2(-32, -48, 64, 8), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-32, -48, 64.0 * pct, 8), Color("f2d36b"))
	draw_string(ThemeDB.fallback_font, Vector2(-16, 48), team_name + " King", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
