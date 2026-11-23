extends RefCounted

const Rules = preload("res://scripts/army_rules.gd")
const Groups = preload("res://scripts/groups.gd")

var _action_wait := 0.0


func choose(captain, delta: float) -> Dictionary:
	var result := {"move": Vector2.ZERO, "attack": false, "build": "", "action": ""}
	_action_wait = maxf(0.0, _action_wait - delta)
	if not captain.alive:
		if _action_wait <= 0.0:
			result.action = "revive"
			_action_wait = 0.45
		return result

	var castle = captain.my_castle()
	var intruder = _nearest_enemy_captain(captain)
	var own_king = _king(captain, true)
	if own_king != null and intruder != null:
		if intruder.global_position.distance_to(own_king.global_position) < 460.0:
			result.attack = true
			result.move = _toward(captain, intruder.global_position)
			return result

	if castle != null and captain.soldiers < 65.0:
		var revive_reserve := Rules.revive_cost(int(captain.deaths) + 1)
		if float(castle.food) >= Rules.TRAIN_COST + revive_reserve:
			if captain.global_position.distance_to(castle.global_position) <= float(castle.supply_radius) and _action_wait <= 0.0:
				result.action = "train"
				_action_wait = 0.45
			result.move = _toward(captain, castle.global_position)
			return result

	var reserve := Rules.marching_reserve(captain.spirit)
	if castle != null and captain.carried_food >= reserve + 10.0:
		var store = _nearest_friendly_storage(captain)
		var goal: Vector2 = castle.global_position if store == null else store.global_position
		if captain.nearby_storage != null and _action_wait <= 0.0:
			result.action = "drop"
			_action_wait = 0.35
		result.move = _toward(captain, goal)
		return result

	if captain.carried_materials >= Rules.BARRICADE_COST:
		var slot = _open_slot(captain, castle)
		if slot != null:
			if captain.global_position.distance_to(slot.global_position) <= float(slot.interact_radius):
				result.build = "barricade"
			result.move = _toward(captain, slot.global_position)
			return result

	if intruder != null and captain.global_position.distance_to(intruder.global_position) < 230.0 and captain.soldiers > 35.0:
		result.attack = true
		result.move = _toward(captain, intruder.global_position)
		return result

	var enemy_king = _king(captain, false)
	if enemy_king != null and captain.spirit >= Rules.HIGH_SPIRIT and captain.soldiers > 55.0:
		if captain.global_position.distance_to(enemy_king.global_position) < 340.0:
			result.attack = true
			result.move = _toward(captain, enemy_king.global_position)
			return result

	var node = _best_node(captain, castle)
	if node != null:
		result.move = _toward(captain, node.global_position)
		return result
	if castle != null:
		result.move = _toward(captain, castle.global_position)
	return result


func _best_node(captain, castle):
	if captain.carried_food < Rules.marching_reserve(captain.spirit) * 0.5:
		var food_node = _nearest_kind(captain, "fruit")
		if food_node == null:
			food_node = _nearest_kind(captain, "beast")
		return food_node
	if captain.carried_materials < Rules.BARRICADE_COST and _open_slot(captain, castle) != null:
		var mat_node = _nearest_kind(captain, "tree")
		if mat_node == null:
			mat_node = _nearest_kind(captain, "ore")
		if mat_node != null:
			return mat_node
	var fruit = _nearest_kind(captain, "fruit")
	if fruit != null:
		return fruit
	return _nearest_kind(captain, "beast")


func _nearest_kind(captain, kind: String):
	var best = null
	var best_d := INF
	for node in Groups.get_all(captain.get_tree(), "resource_nodes"):
		if str(node.kind) != kind or float(node.stock) <= 4.0:
			continue
		var distance: float = captain.global_position.distance_to(node.global_position)
		if distance < best_d:
			best = node
			best_d = distance
	return best


func _open_slot(captain, castle):
	if castle == null:
		return null
	var best = null
	var best_d := 820.0
	for slot in Groups.get_all(captain.get_tree(), "build_slots"):
		if slot.structure != null:
			continue
		if slot.global_position.distance_to(castle.global_position) > 820.0:
			continue
		var distance: float = captain.global_position.distance_to(slot.global_position)
		if distance < best_d:
			best = slot
			best_d = distance
	return best


func _nearest_friendly_storage(captain):
	var best = null
	var best_d := INF
	for storage in Groups.get_all(captain.get_tree(), "storages"):
		if int(storage.team_id) != int(captain.team_id):
			continue
		var distance: float = captain.global_position.distance_to(storage.global_position)
		if distance < best_d:
			best = storage
			best_d = distance
	return best


func _nearest_enemy_captain(captain):
	var best = null
	var best_d := INF
	for other in Groups.get_all(captain.get_tree(), "captains"):
		if other == captain or int(other.team_id) == int(captain.team_id) or not other.alive:
			continue
		var distance: float = captain.global_position.distance_to(other.global_position)
		if distance < best_d:
			best = other
			best_d = distance
	return best


func _king(captain, friendly: bool):
	for king in Groups.get_all(captain.get_tree(), "kings"):
		var same := int(king.team_id) == int(captain.team_id)
		if same == friendly:
			return king
	return null


func _toward(captain, point: Vector2) -> Vector2:
	var to: Vector2 = point - captain.global_position
	if to.length() < 14.0:
		return Vector2.ZERO
	return to.normalized()
