extends SceneTree

const Rules = preload("res://scripts/army_rules.gd")


func _init() -> void:
	var errors: Array = []
	_check(errors, is_equal_approx(Rules.revive_cost(0), Rules.REVIVE_BASE), "revive 0")
	_check(errors, is_equal_approx(Rules.revive_cost(1), Rules.REVIVE_BASE * 1.5), "revive 1")
	_check(errors, is_equal_approx(Rules.revive_cost(2), Rules.REVIVE_BASE * 2.25), "revive 2")
	_check(errors, is_equal_approx(Rules.revive_cost(3), Rules.REVIVE_BASE * 3.375), "revive 3")
	_check(errors, is_equal_approx(Rules.upkeep_rate(69.9), Rules.UPKEEP_PER_SEC), "upkeep below high spirit")
	_check(errors, is_equal_approx(Rules.upkeep_rate(70.0), Rules.UPKEEP_PER_SEC * 2.0), "upkeep at high spirit")

	var fed: Dictionary = Rules.apply_upkeep(100.0, 80.0, 10.0, 1.0)
	_check(errors, bool(fed.fed), "feeding flag")
	_check(errors, is_equal_approx(float(fed.food), 10.0 - Rules.UPKEEP_PER_SEC * 2.0), "feeding spends double food")
	_check(errors, float(fed.spirit) > 80.0, "feeding raises spirit")
	_check(errors, is_equal_approx(float(fed.soldiers), 100.0), "feeding keeps soldiers")

	var starved: Dictionary = Rules.apply_upkeep(100.0, 40.0, 0.0, 1.0)
	_check(errors, not bool(starved.fed), "starvation flag")
	_check(errors, is_equal_approx(float(starved.soldiers), 100.0 - Rules.STARVE_SOLDIERS_PER_SEC), "starvation cuts soldiers")
	_check(errors, is_equal_approx(float(starved.spirit), 40.0 - Rules.SPIRIT_LOSS_PER_SEC), "starvation cuts spirit")
	_check(errors, is_equal_approx(float(starved.spent), 0.0), "starvation spends nothing it does not have")

	var scraps: Dictionary = Rules.apply_upkeep(80.0, 10.0, 0.2, 1.0)
	_check(errors, not bool(scraps.fed), "short food is not a full payment")
	_check(errors, is_equal_approx(float(scraps.spent), 0.2), "short food is consumed")

	var high := Rules.outgoing_damage(10.0, 100.0, 100.0)
	var mid := Rules.outgoing_damage(10.0, 100.0, 50.0)
	var half_army := Rules.outgoing_damage(10.0, 50.0, 100.0)
	_check(errors, high > mid * 1.5, "high spirit is a heavy damage bonus")
	_check(errors, is_equal_approx(half_army * 2.0, high), "soldier count multiplies damage")
	_check(errors, is_equal_approx(Rules.outgoing_damage(10.0, 0.0, 100.0), 0.0), "no soldiers deal no damage")
	_check(errors, is_equal_approx(Rules.incoming_damage(100.0, 0.0), 100.0), "empty spirit takes full damage")
	_check(errors, is_equal_approx(Rules.incoming_damage(100.0, 100.0), 55.0), "full spirit takes 55 percent")

	var capped: Dictionary = Rules.train_quote(100.0)
	_check(errors, is_equal_approx(float(capped.amount), 0.0), "training stops at 100")
	var partial: Dictionary = Rules.train_quote(95.0)
	_check(errors, is_equal_approx(float(partial.amount), 5.0), "training fills only the missing soldiers")
	_check(errors, is_equal_approx(float(partial.cost), Rules.TRAIN_COST * 0.5), "training cost stays flat per soldier")
	_check(errors, is_equal_approx(Rules.build_cost("campsite"), Rules.CAMPSITE_COST), "campsite cost")
	_check(errors, Rules.build_uses_food("campsite") and not Rules.build_uses_food("barricade"), "only camps use food")

	_check(errors, is_equal_approx(Rules.marching_reserve(69.0), 12.0), "low spirit keeps a small ration")
	_check(errors, is_equal_approx(Rules.marching_reserve(70.0), 24.0), "high spirit keeps a larger ration")

	if errors.is_empty():
		print("FORMULA_TESTS_OK")
		quit(0)
	else:
		var message := "FORMULA_TESTS_FAILED"
		for name in errors:
			message += " | " + str(name)
		push_error(message)
		quit(1)


func _check(errors: Array, ok: bool, name: String) -> void:
	if not ok:
		errors.append(name)
