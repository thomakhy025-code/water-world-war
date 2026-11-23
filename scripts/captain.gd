extends CharacterBody2D

const Rules = preload("res://scripts/army_rules.gd")
const Groups = preload("res://scripts/groups.gd")
const Feedback = preload("res://scripts/feedback.gd")
const LootBag = preload("res://scripts/loot_bag.gd")
const CaptainAi = preload("res://scripts/captain_ai.gd")

var team_id := 0
var ai_controlled := false
var color := Color.WHITE
var team_name := "Blue"
var callsign := ""
var role := ""
var lane_point := Vector2.ZERO
var soldiers := 100.0
var spirit := 50.0
var carried_food := 0.0
var carried_materials := 0.0
var deaths := 0
var alive := true
var fed := true
var facing := Vector2.RIGHT
var nearby_slot = null
var nearby_storage = null
var toast := ""
var toast_left := 0.0

var _attack_cd := 0.0
var _skill_cd := 0.0
var _dash_time := 0.0
var _dash_dir := Vector2.RIGHT
var _move_dir := Vector2.ZERO
var _wants_attack := false
var _flash := 0.0
var _ai = null


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	set_process_unhandled_input(true)
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	add_to_group("captains")
	add_to_group("damageable")
	z_index = 4
	if ai_controlled:
		_ai = CaptainAi.new()
	else:
		var cam := Camera2D.new()
		cam.zoom = Vector2(0.72, 0.72)
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 7.0
		var limits = Vector2(3000, 1800)
		var battle = get_tree().current_scene
		if battle != null and battle.get("map_size") != null:
			limits = battle.map_size
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(limits.x)
		cam.limit_bottom = int(limits.y)
		add_child(cam)
		cam.make_current()


func notify(text: String) -> void:
	toast = text
	toast_left = 2.6


func is_targetable() -> bool:
	return alive


func my_castle():
	for castle in Groups.get_all(get_tree(), "castles"):
		if int(castle.team_id) == team_id:
			return castle
	return null


func apply_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	var dealt := Rules.incoming_damage(amount, spirit)
	soldiers = maxf(0.0, soldiers - dealt)
	if dealt >= 1.0:
		_flash = 0.08
		Feedback.rising_text(get_parent(), global_position + Vector2(-8, -28), str(maxi(1, roundi(dealt))), Color("ffd2d2"))
	if soldiers <= 0.0:
		_die()


func _unhandled_input(event: InputEvent) -> void:
	if ai_controlled or _battle_over():
		return
	if event.is_action_pressed("skill"):
		_start_dash()
	elif event.is_action_pressed("castle_action"):
		_use_hands()
	elif event.is_action_pressed("build_barricade"):
		_try_build("barricade")
	elif event.is_action_pressed("build_trap"):
		_try_build("trap")
	elif event.is_action_pressed("build_catapult"):
		_try_build("catapult")
	elif event.is_action_pressed("build_campsite"):
		_try_build("campsite")


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_skill_cd = maxf(0.0, _skill_cd - delta)
	toast_left = maxf(0.0, toast_left - delta)
	_flash = maxf(0.0, _flash - delta)
	modulate = Color(1, 0.55, 0.55) if _flash > 0.0 else Color.WHITE
	_update_nearby()
	if alive and not _battle_over():
		_simulate(delta)
	if not alive or _battle_over():
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	if ai_controlled:
		var decision = _ai.choose(self, delta)
		_move_dir = _separate(decision.move)
		_wants_attack = decision.attack
		if str(decision.build) != "":
			_try_build(str(decision.build))
		if str(decision.action) == "drop":
			drop_food(Rules.marching_reserve(spirit))
		elif str(decision.action) == "train" or str(decision.action) == "revive":
			_use_hands()
	else:
		_move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_wants_attack = Input.is_action_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _wants_attack:
		_try_attack()
	_apply_motion(delta)
	queue_redraw()


func _simulate(delta: float) -> void:
	_harvest(delta)
	if not alive:
		return
	_collect_bags()
	_upkeep(delta)


func _harvest(delta: float) -> void:
	var node = _nearest("resource_nodes", Rules.HARVEST_RADIUS)
	if node == null:
		return
	var room_food := Rules.CARRY_FOOD_MAX - carried_food
	var room_mat := Rules.CARRY_MAT_MAX - carried_materials
	var got: Dictionary = node.take(delta, room_food, room_mat)
	carried_food += float(got.food)
	carried_materials += float(got.materials)
	if float(got.danger) > 0.0:
		apply_damage(float(got.danger))


func _collect_bags() -> void:
	for bag in _nearest_list("loot_bags", 42.0):
		var food_room := Rules.CARRY_FOOD_MAX - carried_food
		var mat_room := Rules.CARRY_MAT_MAX - carried_materials
		var food_take := minf(float(bag.food), food_room)
		var mat_take := minf(float(bag.materials), mat_room)
		carried_food += food_take
		carried_materials += mat_take
		bag.food -= food_take
		bag.materials -= mat_take
		bag.queue_redraw()
		if bag.food <= 0.05 and bag.materials <= 0.05:
			bag.queue_free()


func _upkeep(delta: float) -> void:
	var store = nearby_storage
	var pool := carried_food
	if store != null:
		pool += float(store.food)
	var result := Rules.apply_upkeep(soldiers, spirit, pool, delta)
	var spent := float(result.spent)
	var from_pouch := minf(carried_food, spent)
	carried_food -= from_pouch
	var rest := spent - from_pouch
	if rest > 0.0 and store != null:
		store.take_food(rest)
	soldiers = float(result.soldiers)
	spirit = float(result.spirit)
	fed = bool(result.fed)
	if soldiers <= 0.0:
		_die()


func _use_hands() -> void:
	if not alive:
		_try_revive()
		return
	if _try_dropoff():
		return
	_try_train()


func drop_food(keep: float) -> bool:
	if nearby_storage == null:
		return false
	var amount := maxf(0.0, carried_food - keep)
	if amount <= 0.0:
		return false
	nearby_storage.add_food(amount)
	carried_food = minf(carried_food, keep)
	notify("Dropped %d food at the %s." % [roundi(amount), str(nearby_storage.storage_name)])
	return true


func _try_dropoff() -> bool:
	return drop_food(0.0)


func _try_train() -> void:
	var castle = my_castle()
	if castle == null or global_position.distance_to(castle.global_position) > float(castle.supply_radius):
		if not ai_controlled:
			notify("Drop food at a castle or campsite. Train at your castle with empty hands.")
		return
	var quote: Dictionary = Rules.train_quote(soldiers)
	if float(quote.amount) <= 0.0:
		notify("The army is already full.")
		return
	if float(castle.food) < float(quote.cost):
		notify("Training costs %d castle food." % roundi(float(quote.cost)))
		return
	castle.take_food(float(quote.cost))
	soldiers = minf(Rules.MAX_SOLDIERS, soldiers + float(quote.amount))
	notify("Trained %d soldiers." % roundi(float(quote.amount)))


func _try_revive() -> void:
	var castle = my_castle()
	if castle == null or global_position.distance_to(castle.global_position) > float(castle.supply_radius):
		notify("Your ghost is at the castle. Revive there.")
		return
	var cost := Rules.revive_cost(deaths)
	if float(castle.food) < cost:
		notify("Revive costs %d food. Castle has %d. Cost is 24 × 1.5^deaths." % [roundi(cost), roundi(float(castle.food))])
		return
	castle.take_food(cost)
	alive = true
	soldiers = Rules.REVIVE_SOLDIERS
	spirit = Rules.REVIVE_SPIRIT
	carried_food = Rules.REVIVE_RATIONS
	fed = true
	collision_layer = 2
	self_modulate.a = 1.0
	notify("Revived with %d soldiers. Next death costs %d food." % [roundi(Rules.REVIVE_SOLDIERS), roundi(Rules.revive_cost(deaths + 1))])


func _try_build(kind: String) -> void:
	if not alive:
		return
	if nearby_slot == null:
		if not ai_controlled:
			notify("Stand on a stone marker to build.")
		return
	nearby_slot.try_build(self, kind)


func _try_attack() -> void:
	if not alive or _attack_cd > 0.0 or _battle_over():
		return
	var target = _nearest_hostile(Rules.ATTACK_RANGE)
	if target == null:
		return
	_attack_cd = Rules.ATTACK_COOLDOWN
	var to: Vector2 = target.global_position - global_position
	if to.length() > 1.0:
		facing = to.normalized()
	target.apply_damage(Rules.outgoing_damage(Rules.ATTACK_BASE, soldiers, spirit))


func _start_dash() -> void:
	if not alive or _skill_cd > 0.0 or _dash_time > 0.0 or _battle_over():
		return
	_dash_dir = _move_dir if _move_dir.length() > 0.1 else facing
	if _dash_dir.length() < 0.1:
		_dash_dir = Vector2.RIGHT
	_dash_dir = _dash_dir.normalized()
	_dash_time = Rules.DASH_TIME
	_skill_cd = Rules.SKILL_COOLDOWN
	facing = _dash_dir


func _apply_motion(delta: float) -> void:
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * Rules.DASH_SPEED
		facing = _dash_dir
		var finished_dash := _dash_time <= 0.0
		move_and_slide()
		if finished_dash:
			_skill_burst()
		return
	if _move_dir.length() > 0.05:
		facing = _move_dir.normalized()
		velocity = facing * Rules.MOVE_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _skill_burst() -> void:
	var raw := Rules.outgoing_damage(Rules.SKILL_BASE, soldiers, spirit)
	for node in Groups.get_all(get_tree(), "damageable"):
		if node == self or int(node.team_id) == team_id:
			continue
		if node.has_method("is_targetable") and not node.is_targetable():
			continue
		if global_position.distance_to(node.global_position) > Rules.SKILL_RADIUS:
			continue
		node.apply_damage(raw)


func _die() -> void:
	if not alive:
		return
	alive = false
	soldiers = 0.0
	deaths += 1
	var drop_at := global_position
	_drop_bag(drop_at)
	carried_food = 0.0
	carried_materials = 0.0
	_dash_time = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	self_modulate.a = 0.45
	var castle = my_castle()
	if castle != null:
		global_position = castle.rally_point
	notify("Captain down. Press E at your castle. Revive costs %d food." % roundi(Rules.revive_cost(deaths)))


func _drop_bag(at: Vector2) -> void:
	if carried_food <= 0.5 and carried_materials <= 0.5:
		return
	var bag = LootBag.new()
	bag.food = carried_food
	bag.materials = carried_materials
	get_parent().add_child(bag)
	bag.global_position = at


func _update_nearby() -> void:
	nearby_slot = _nearest("build_slots", Rules.BUILD_RANGE)
	nearby_storage = null
	var best_d := INF
	for storage in Groups.get_all(get_tree(), "storages"):
		if int(storage.team_id) != team_id or not bool(storage.accepts_food):
			continue
		var distance := global_position.distance_to(storage.global_position)
		if distance <= float(storage.supply_radius) and distance < best_d:
			nearby_storage = storage
			best_d = distance


func _nearest(group_name: String, radius: float):
	var best = null
	var best_d := radius
	for node in Groups.get_all(get_tree(), group_name):
		var distance: float = global_position.distance_to(node.global_position)
		if distance <= best_d:
			best = node
			best_d = distance
	return best


func _nearest_list(group_name: String, radius: float) -> Array:
	var found: Array = []
	for node in Groups.get_all(get_tree(), group_name):
		if global_position.distance_to(node.global_position) <= radius:
			found.append(node)
	return found


func _nearest_hostile(radius: float):
	var best = null
	var best_d := radius
	for node in Groups.get_all(get_tree(), "damageable"):
		if node == self or int(node.team_id) == team_id:
			continue
		if node.has_method("is_targetable") and not node.is_targetable():
			continue
		var distance: float = global_position.distance_to(node.global_position)
		if distance <= best_d:
			best = node
			best_d = distance
	return best


func _separate(dir: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for other in Groups.get_all(get_tree(), "captains"):
		if other == self or not other.alive:
			continue
		var away: Vector2 = global_position - other.global_position
		var dist := away.length()
		if dist < 46.0 and dist > 0.01:
			push += away / dist * (46.0 - dist) / 46.0
	if push.length() < 0.05:
		return dir
	if dir.length() < 0.05:
		return push.normalized()
	return (dir + push).normalized()


func _battle_over() -> bool:
	var battle = get_tree().current_scene
	return battle != null and battle.get("finished") == true


func _draw() -> void:
	var font = ThemeDB.fallback_font
	var body := color
	draw_circle(Vector2.ZERO, 18, body)
	draw_line(Vector2.ZERO, facing * 24, Color.WHITE, 3.0)
	var bar := Color("7ddea2")
	if not fed:
		bar = Color("e25b55")
	elif spirit >= Rules.HIGH_SPIRIT:
		bar = Color("f0c14a")
	draw_rect(Rect2(-20, -34, 40, 5), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-20, -34, 40.0 * spirit / Rules.MAX_SPIRIT, 5), bar)
	if font == null:
		return
	var text := str(roundi(soldiers))
	var text_color := Color.WHITE
	if not alive:
		text_color = Color("ff8d8d")
	elif not fed:
		text_color = Color("ff8d8d")
	elif spirit >= Rules.HIGH_SPIRIT:
		text_color = Color("ffe08a")
	var pos := Vector2(-10, -42)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text_color)
	if callsign != "":
		var tag_pos := Vector2(-22, 32)
		draw_string(font, tag_pos + Vector2(1, 1), callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_string(font, tag_pos, callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
