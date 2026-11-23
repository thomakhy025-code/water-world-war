extends StaticBody2D

const Rules = preload("res://scripts/army_rules.gd")
const Groups = preload("res://scripts/groups.gd")
const Feedback = preload("res://scripts/feedback.gd")

signal changed

var kind := "barricade"
var team_id := 0
var color := Color.WHITE
var block_angle := 0.0
var slot = null
var hp := 1.0
var max_hp := 1.0
var food := 0.0
var accepts_food := false
var supply_radius := 0.0
var storage_name := "Campsite"
var _trap_wait := 0.0
var _shot_wait := 0.0
var _aim := Vector2.ZERO
var _show_aim := 0.0


func _ready() -> void:
	max_hp = Rules.structure_hp(kind)
	hp = max_hp
	collision_layer = 0
	collision_mask = 0
	add_to_group("structures")
	add_to_group("damageable")
	z_index = 2
	if kind == "barricade":
		rotation = block_angle
		collision_layer = 1
		var shape := RectangleShape2D.new()
		shape.size = Vector2(96, 28)
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)
	elif kind == "campsite":
		accepts_food = true
		supply_radius = Rules.CAMPSITE_RADIUS
		add_to_group("storages")
	queue_redraw()


func is_targetable() -> bool:
	return hp > 0.0


func add_food(amount: float) -> void:
	if not accepts_food or amount <= 0.0:
		return
	food += amount
	changed.emit()
	queue_redraw()


func take_food(amount: float) -> float:
	if not accepts_food:
		return 0.0
	var taken := minf(food, amount)
	if taken <= 0.0:
		return 0.0
	food -= taken
	changed.emit()
	queue_redraw()
	return taken


func apply_damage(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp -= amount
	Feedback.rising_text(_floater_host(), global_position + Vector2(-8, -20), str(roundi(amount)), Color("ffe0b0"))
	if hp <= 0.0:
		if slot != null and slot.structure == self:
			slot.clear_structure()
		queue_free()
		return
	queue_redraw()


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_show_aim = maxf(0.0, _show_aim - delta)
	if kind == "trap":
		_trap_wait -= delta
		if _trap_wait <= 0.0:
			_trap_wait = Rules.TRAP_INTERVAL
			_pulse_trap()
	elif kind == "catapult":
		_shot_wait -= delta
		if _shot_wait <= 0.0:
			_shot_wait = Rules.CATAPULT_INTERVAL
			_fire_catapult()
	if _show_aim > 0.0:
		queue_redraw()


func _pulse_trap() -> void:
	for captain in Groups.get_all(get_tree(), "captains"):
		if int(captain.team_id) == team_id or not captain.alive:
			continue
		if global_position.distance_to(captain.global_position) > 36.0:
			continue
		captain.apply_damage(Rules.TRAP_DAMAGE)


func _floater_host() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node


func _fire_catapult() -> void:
	var target = _nearest_siege_target()
	if target == null:
		return
	_aim = target.global_position
	_show_aim = 0.25
	target.apply_damage(Rules.CATAPULT_DAMAGE)
	queue_redraw()


func _nearest_siege_target():
	var best = null
	var best_d := Rules.CATAPULT_RANGE
	for node in Groups.get_all(get_tree(), "damageable"):
		if node == self or int(node.get("team_id")) == team_id:
			continue
		if node.is_in_group("captains"):
			continue
		if node.has_method("is_targetable") and not node.is_targetable():
			continue
		var distance := global_position.distance_to(node.global_position)
		if distance < best_d:
			best = node
			best_d = distance
	return best


func _draw() -> void:
	var pct := clampf(hp / max_hp, 0.0, 1.0)
	match kind:
		"barricade":
			draw_rect(Rect2(-48, -14, 96, 28), Color("7a5432"))
			draw_rect(Rect2(-48, -14, 96.0 * pct, 4), Color("f0d2a0"))
		"trap":
			for x in [-16, 0, 16]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 6, 8), Vector2(x, -14), Vector2(x + 6, 8)
				]), Color("4d555d"))
			draw_rect(Rect2(-20, 12, 40.0 * pct, 4), Color("f0d2a0"))
		"catapult":
			draw_rect(Rect2(-18, -8, 36, 18), Color("8a6239"))
			draw_line(Vector2(-8, 0), Vector2(26, -22), Color("d8c3a0"), 4.0)
			draw_circle(Vector2(28, -24), 5, Color("2b2b2b"))
			draw_rect(Rect2(-18, 14, 36.0 * pct, 4), Color("f0d2a0"))
			if _show_aim > 0.0:
				draw_line(Vector2.ZERO, to_local(_aim), Color(1, 0.8, 0.4, 0.8), 2.0)
		"campsite":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-24, 12), Vector2(0, -22), Vector2(24, 12)
			]), color)
			draw_rect(Rect2(-8, 0, 16, 12), Color("6b4a2a"))
			draw_arc(Vector2.ZERO, supply_radius, 0, TAU, 40, Color(color.r, color.g, color.b, 0.28), 2.0)
			draw_string(ThemeDB.fallback_font, Vector2(-28, 32), "Food %d" % roundi(food), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			draw_rect(Rect2(-24, 16, 48.0 * pct, 4), Color("f0d2a0"))
