extends SceneTree

const Rules = preload("res://scripts/army_rules.gd")


var _battle
var _started := false


func _init() -> void:
	_battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(_battle)


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var battle = _battle
	var player = _human(battle)
	if player == null:
		_fail("missing the human captain")
		return
	var castle = player.my_castle()
	if castle == null:
		_fail("missing the blue castle")
		return

	player.alive = true
	player.soldiers = 100.0
	player.spirit = 80.0
	player.carried_food = 10.0
	player.nearby_storage = null
	player._upkeep(1.0)
	if not is_equal_approx(player.carried_food, 7.5):
		_fail("high spirit should spend 2.5 pouch food, left %s" % player.carried_food)
		return
	if player.soldiers < 99.0 or player.spirit <= 80.0:
		_fail("feeding should keep soldiers and raise spirit")
		return

	player.carried_food = 0.0
	player.spirit = 40.0
	player.soldiers = 100.0
	player.nearby_storage = null
	player._upkeep(1.0)
	if player.soldiers >= 100.0 or player.spirit >= 40.0:
		_fail("an empty pouch with no store should starve the squad")
		return

	var before_food: float = castle.food
	player.alive = true
	player.carried_food = 20.0
	player.global_position = castle.global_position
	player._update_nearby()
	if not player.drop_food(0.0):
		_fail("drop-off at the castle failed")
		return
	if not is_equal_approx(castle.food, before_food + 20.0) or player.carried_food > 0.01:
		_fail("castle did not receive the pouch")
		return

	player.carried_food = 0.0
	player.soldiers = 40.0
	castle.food = Rules.TRAIN_COST
	player._try_train()
	if player.soldiers < 49.0:
		_fail("training at the castle did not add soldiers")
		return

	player._die()
	var first_cost := Rules.revive_cost(player.deaths)
	castle.food = first_cost
	player._try_revive()
	if not player.alive:
		_fail("revive with exact food failed")
		return
	player._die()
	var second_cost := Rules.revive_cost(player.deaths)
	if second_cost <= first_cost:
		_fail("deaths did not raise the revive cost")
		return
	castle.food = second_cost - 1.0
	player._try_revive()
	if player.alive:
		_fail("revive succeeded below the scaled cost")
		return
	castle.food = second_cost
	player._try_revive()
	if not player.alive:
		_fail("revive failed at the scaled cost")
		return

	var slot = _first_slot(battle)
	if slot == null:
		_fail("missing a build slot")
		return
	player.alive = true
	player.global_position = slot.global_position
	player._update_nearby()
	player.carried_materials = Rules.BARRICADE_COST
	player._try_build("barricade")
	if slot.structure == null or player.carried_materials > 0.01:
		_fail("barricade did not spend materials")
		return
	var wall = slot.structure
	player.carried_materials = Rules.BARRICADE_COST
	player._try_build("barricade")
	if slot.structure != wall or not is_equal_approx(player.carried_materials, Rules.BARRICADE_COST):
		_fail("occupied slot accepted a second building")
		return
	wall.apply_damage(Rules.BARRICADE_HP)
	if slot.structure != null:
		_fail("destroyed barricade did not free the slot")
		return

	player.carried_food = Rules.CAMPSITE_COST + 15.0
	player._try_build("campsite")
	var camp = slot.structure
	if camp == null or str(camp.kind) != "campsite":
		_fail("campsite was not built with food")
		return
	player._update_nearby()
	player.drop_food(0.0)
	if camp.food < 14.0:
		_fail("campsite did not store dropped food")
		return
	player.carried_food = 0.0
	player.soldiers = 100.0
	player.spirit = 20.0
	player._upkeep(1.0)
	if camp.food >= 14.0 or player.soldiers < 99.0:
		_fail("army in a campsite should eat stored food instead of starving")
		return

	var king = _enemy_king(battle, player.team_id)
	if king == null:
		_fail("missing the enemy king")
		return
	king.apply_damage(king.hp)
	if not battle.finished or int(battle.winner_id) != int(player.team_id):
		_fail("destroying the enemy king did not end the match")
		return

	print("SMOKE_TESTS_OK")
	quit(0)


func _human(battle):
	for child in battle.get_children():
		if child.is_in_group("captains") and not child.ai_controlled:
			return child
	return null


func _first_slot(battle):
	for child in battle.get_children():
		if child.is_in_group("build_slots"):
			return child
	return null


func _enemy_king(battle, team_id: int):
	for child in battle.get_children():
		if child.is_in_group("kings") and int(child.team_id) != team_id:
			return child
	return null


func _fail(message: String) -> void:
	push_error("SMOKE_TESTS_FAILED " + message)
	quit(1)
