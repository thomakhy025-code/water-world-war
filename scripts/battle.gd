extends Node2D

const Rules = preload("res://scripts/army_rules.gd")
const CaptainScript = preload("res://scripts/captain.gd")
const CastleScript = preload("res://scripts/castle.gd")
const KingScript = preload("res://scripts/king.gd")
const SlotScript = preload("res://scripts/build_slot.gd")
const NodeScript = preload("res://scripts/resource_node.gd")
const HudScript = preload("res://scripts/hud.gd")

var map_size := Vector2(3000, 1800)
var finished := false
var winner_id := -1

var _center := Vector2.ZERO
var _attack := Vector2.RIGHT
var _river := Vector2.DOWN
var _blue_castle := Vector2.ZERO
var _red_castle := Vector2.ZERO


func _enter_tree() -> void:
	_register_inputs()


func _ready() -> void:
	_layout()
	_spawn_bounds()
	_spawn_castles_and_kings()
	_spawn_slots()
	_spawn_nodes()
	_spawn_captains()
	add_child(HudScript.new())
	_warn_if_outside()
	queue_redraw()


func _warn_if_outside() -> void:
	var bounds := Rect2(Vector2(40, 40), map_size - Vector2(80, 80))
	for child in get_children():
		if child is CanvasLayer or child is StaticBody2D:
			continue
		if not bounds.has_point(child.position):
			push_warning("Map marker outside the field: %s at %s" % [child.name, str(child.position)])


func _layout() -> void:
	_center = map_size * 0.5
	_attack = Vector2(2080, -1040).normalized()
	_river = Vector2(-_attack.y, _attack.x)
	_blue_castle = _center - _attack * 1080.0
	_red_castle = _center + _attack * 1080.0


func _lane_point(offset: float, along_t: float) -> Vector2:
	var along := lerpf(-1180.0, 1180.0, along_t)
	return _center + _attack * along + _river * offset


func _spawn_bounds() -> void:
	_add_wall(Rect2(-80, -80, map_size.x + 160, 80))
	_add_wall(Rect2(-80, map_size.y, map_size.x + 160, 80))
	_add_wall(Rect2(-80, 0, 80, map_size.y))
	_add_wall(Rect2(map_size.x, 0, 80, map_size.y))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.position + rect.size * 0.5
	body.add_child(col)
	add_child(body)


func _spawn_castles_and_kings() -> void:
	_castle(0, "Blue", Color("3c9dff"), _blue_castle, _blue_castle + _attack * 150.0, 0.0)
	_castle(1, "Red", Color("e25b55"), _red_castle, _red_castle - _attack * 150.0, 36.0)
	_king(0, "Blue", Color("3c9dff"), _blue_castle)
	_king(1, "Red", Color("e25b55"), _red_castle)


func _castle(team_id: int, team_name: String, color: Color, pos: Vector2, rally: Vector2, food: float) -> void:
	var castle = CastleScript.new()
	castle.team_id = team_id
	castle.team_name = team_name
	castle.color = color
	castle.position = pos
	castle.rally_point = rally
	castle.food = food
	add_child(castle)


func _king(team_id: int, team_name: String, color: Color, pos: Vector2) -> void:
	var king = KingScript.new()
	king.team_id = team_id
	king.team_name = team_name
	king.color = color
	king.position = pos
	add_child(king)
	king.defeated.connect(_on_king_down)


func _on_king_down(team_id: int) -> void:
	if finished:
		return
	finished = true
	winner_id = 1 - team_id
	call_deferred("_pause_battle")


func _pause_battle() -> void:
	get_tree().paused = true


func _spawn_slots() -> void:
	var defs: Array = [
		[0.0, 0.16],
		[-400.0, 0.20],
		[400.0, 0.40],
		[0.0, 0.50],
		[-400.0, 0.60],
		[400.0, 0.72],
		[0.0, 0.84],
		[400.0, 0.80],
	]
	var index := 1
	for item in defs:
		var slot = SlotScript.new()
		slot.slot_index = index
		slot.block_angle = _river.angle()
		slot.position = _lane_point(float(item[0]), float(item[1]))
		add_child(slot)
		index += 1


func _spawn_nodes() -> void:
	_node("fruit", _lane_point(-240, 0.12))
	_node("tree", _lane_point(240, 0.13))
	_node("fruit", _lane_point(-460, 0.28))
	_node("fruit", _lane_point(480, 0.34))
	_node("tree", _lane_point(520, 0.48))
	_node("tree", _lane_point(-520, 0.58))
	_node("ore", _lane_point(180, 0.47))
	_node("ore", _lane_point(-180, 0.56))
	_node("beast", _lane_point(50, 0.50))
	_node("beast", _lane_point(-70, 0.44))
	_node("fruit", _lane_point(240, 0.88))
	_node("tree", _lane_point(-240, 0.86))
	_node("fruit", _lane_point(460, 0.70))
	_node("fruit", _lane_point(-480, 0.74))


func _node(kind: String, pos: Vector2) -> void:
	var node = NodeScript.new()
	node.kind = kind
	node.position = pos
	add_child(node)


func _spawn_captains() -> void:
	_captain(false, 0, "Blue", Color("3c9dff"), _blue_castle + _attack * 220.0, 30.0, 50.0)
	_captain(true, 1, "Red", Color("e25b55"), _red_castle - _attack * 220.0, 8.0, 50.0)


func _captain(ai: bool, team_id: int, team_name: String, color: Color, pos: Vector2, food: float, spirit: float) -> void:
	var captain = CaptainScript.new()
	captain.ai_controlled = ai
	captain.team_id = team_id
	captain.team_name = team_name
	captain.color = color
	captain.position = pos
	captain.carried_food = food
	captain.spirit = spirit
	captain.soldiers = Rules.MAX_SOLDIERS
	captain.facing = _attack if team_id == 0 else -_attack
	add_child(captain)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("173c2a"))
	var half := 155.0
	var reach := 1450.0
	var side := _attack * half
	var a := _center - _river * reach
	var b := _center + _river * reach
	draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), Color("1d4e89"))
	draw_line(a, b, Color("6ea0d4"), 6.0)
	draw_line(_lane_point(420, 0.02), _lane_point(420, 0.98), Color(1, 1, 1, 0.07), 80.0)
	draw_line(_lane_point(0, 0.02), _lane_point(0, 0.98), Color(1, 1, 1, 0.05), 70.0)
	draw_line(_lane_point(-420, 0.02), _lane_point(-420, 0.98), Color(1, 1, 1, 0.07), 80.0)
	var font = ThemeDB.fallback_font
	if font == null:
		return
	_tag(font, "BLUE CASTLE", _blue_castle + Vector2(-78, -120))
	_tag(font, "RED CASTLE", _red_castle + Vector2(-70, -120))
	_tag(font, "TOP JUNGLE", _lane_point(520, 0.30))
	_tag(font, "CENTER RIVER", _center + Vector2(-90, -210))
	_tag(font, "BOTTOM JUNGLE", _lane_point(-520, 0.62))


func _tag(font: Font, text: String, pos: Vector2) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))


func _register_inputs() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("attack", [KEY_J])
	_bind("skill", [KEY_K, KEY_SPACE])
	_bind("castle_action", [KEY_E])
	_bind("build_barricade", [KEY_1])
	_bind("build_trap", [KEY_2])
	_bind("build_catapult", [KEY_3])
	_bind("build_campsite", [KEY_4])
	_bind("restart", [KEY_R])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key as Key
		InputMap.action_add_event(action, event)
