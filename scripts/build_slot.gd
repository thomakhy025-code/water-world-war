extends Node2D

const Rules = preload("res://scripts/army_rules.gd")

var block_angle := 0.0
var interact_radius := 0.0
var structure = null
var highlighted := false
var slot_index := 0


func _ready() -> void:
	add_to_group("build_slots")
	interact_radius = Rules.BUILD_RANGE
	z_index = 1
	queue_redraw()


func _process(_delta: float) -> void:
	var want := false
	for captain in _captains():
		if captain.ai_controlled:
			continue
		if global_position.distance_to(captain.global_position) <= interact_radius:
			want = true
			break
	if want != highlighted:
		highlighted = want
		queue_redraw()


func try_build(captain, kind: String) -> bool:
	if structure != null or not captain.alive:
		return false
	if global_position.distance_to(captain.global_position) > interact_radius:
		return false
	var battle = get_tree().current_scene
	if battle != null and battle.get("finished") == true:
		return false
	var cost := Rules.build_cost(kind)
	if Rules.build_uses_food(kind):
		if captain.carried_food < cost:
			captain.notify("Need %d food for a campsite." % roundi(cost))
			return false
		captain.carried_food -= cost
	else:
		if captain.carried_materials < cost:
			captain.notify("Need %d materials." % roundi(cost))
			return false
		captain.carried_materials -= cost
	var built = preload("res://scripts/structure.gd").new()
	built.kind = kind
	built.team_id = captain.team_id
	built.color = captain.color
	built.block_angle = block_angle
	built.slot = self
	add_child(built)
	structure = built
	queue_redraw()
	captain.notify("%s built." % kind.capitalize())
	return true


func clear_structure() -> void:
	structure = null
	queue_redraw()


func _captains() -> Array:
	var loose: Array = []
	loose.assign(get_tree().get_nodes_in_group("captains"))
	return loose


func _draw() -> void:
	if structure != null:
		return
	var stone := Color("d7c4a1") if highlighted else Color("8d8374")
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)
	]), stone)
	draw_string(ThemeDB.fallback_font, Vector2(-4, 32), str(slot_index), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
