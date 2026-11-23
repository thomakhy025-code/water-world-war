extends RefCounted

## Design contract for Water World War steps 1–2.
## The soldier counter is the squad's size, health, and damage multiplier.
## Food feeds Spirit. Spirit at or above the high threshold doubles food use
## and multiplies damage. Missing a payment starves soldiers away.
## Revive cost is Base × 1.5^Deaths. Training cost does not use Deaths.

const MAX_SOLDIERS := 100.0
const MAX_SPIRIT := 100.0
const HIGH_SPIRIT := 70.0

const UPKEEP_PER_SEC := 1.25
const HIGH_SPIRIT_FOOD_MULT := 2.0
const SPIRIT_GAIN_PER_SEC := 12.0
const SPIRIT_LOSS_PER_SEC := 18.0
const STARVE_SOLDIERS_PER_SEC := 3.5

const SPIRIT_DAMAGE_SCALE := 0.8
const HIGH_SPIRIT_DAMAGE_MULT := 1.75
const HIGH_SPIRIT_DAMAGE_TAKEN := 0.55

const CARRY_FOOD_MAX := 36.0
const CARRY_MAT_MAX := 36.0
const HARVEST_RADIUS := 82.0

const MOVE_SPEED := 250.0
const ATTACK_RANGE := 58.0
const ATTACK_BASE := 8.0
const ATTACK_COOLDOWN := 0.5
const SKILL_BASE := 14.0
const SKILL_COOLDOWN := 4.0
const SKILL_RADIUS := 78.0
const DASH_SPEED := 880.0
const DASH_TIME := 0.18

const REVIVE_BASE := 24.0
const REVIVE_SOLDIERS := 50.0
const REVIVE_SPIRIT := 30.0
const REVIVE_RATIONS := 12.0
const TRAIN_AMOUNT := 10.0
const TRAIN_COST := 8.0

const BARRICADE_COST := 20.0
const TRAP_COST := 14.0
const CATAPULT_COST := 36.0
const CAMPSITE_COST := 28.0

const BARRICADE_HP := 280.0
const TRAP_HP := 90.0
const CATAPULT_HP := 160.0
const CAMPSITE_HP := 120.0

const TRAP_DAMAGE := 10.0
const TRAP_INTERVAL := 0.5
const CATAPULT_DAMAGE := 40.0
const CATAPULT_INTERVAL := 2.0
const CATAPULT_RANGE := 560.0

const KING_HP := 1200.0
const CASTLE_RADIUS := 170.0
const CAMPSITE_RADIUS := 130.0
const BUILD_RANGE := 74.0

const BEAST_DANGER_PER_SEC := 7.0
const NODE_REGEN_DELAY := 2.0

const NODE_RATE := {
	"tree": 10.0,
	"ore": 8.0,
	"fruit": 14.0,
	"beast": 20.0,
}
const NODE_REGEN := {
	"tree": 5.0,
	"ore": 4.0,
	"fruit": 6.0,
	"beast": 3.0,
}
const NODE_MAX := {
	"tree": 90.0,
	"ore": 80.0,
	"fruit": 80.0,
	"beast": 55.0,
}


static func revive_cost(deaths: int) -> float:
	return REVIVE_BASE * pow(1.5, float(deaths))


static func upkeep_rate(spirit: float) -> float:
	if spirit >= HIGH_SPIRIT:
		return UPKEEP_PER_SEC * HIGH_SPIRIT_FOOD_MULT
	return UPKEEP_PER_SEC


## Food kept in the pouch when banking, so a march off the store does not start at zero.
static func marching_reserve(spirit: float) -> float:
	if spirit >= HIGH_SPIRIT:
		return 24.0
	return 12.0


static func spirit_state(spirit: float, fed: bool) -> String:
	if not fed:
		return "starving"
	if spirit >= HIGH_SPIRIT:
		return "high spirit"
	return "fed"


static func apply_upkeep(soldiers: float, spirit: float, food_on_hand: float, delta: float) -> Dictionary:
	var cost := upkeep_rate(spirit) * delta
	if cost <= 0.0:
		return {
			"soldiers": soldiers,
			"spirit": spirit,
			"food": food_on_hand,
			"spent": 0.0,
			"fed": true,
		}
	if food_on_hand >= cost:
		return {
			"soldiers": soldiers,
			"spirit": minf(MAX_SPIRIT, spirit + SPIRIT_GAIN_PER_SEC * delta),
			"food": food_on_hand - cost,
			"spent": cost,
			"fed": true,
		}
	return {
		"soldiers": maxf(0.0, soldiers - STARVE_SOLDIERS_PER_SEC * delta),
		"spirit": maxf(0.0, spirit - SPIRIT_LOSS_PER_SEC * delta),
		"food": 0.0,
		"spent": food_on_hand,
		"fed": false,
	}


static func outgoing_damage(base_damage: float, soldiers: float, spirit: float) -> float:
	var army := clampf(soldiers / MAX_SOLDIERS, 0.0, 1.0)
	var spirit_bonus := 1.0 + (spirit / MAX_SPIRIT) * SPIRIT_DAMAGE_SCALE
	if spirit >= HIGH_SPIRIT:
		spirit_bonus *= HIGH_SPIRIT_DAMAGE_MULT
	return base_damage * army * spirit_bonus


static func incoming_damage(raw: float, spirit: float) -> float:
	var taken := lerpf(1.0, HIGH_SPIRIT_DAMAGE_TAKEN, clampf(spirit / MAX_SPIRIT, 0.0, 1.0))
	return raw * taken


static func train_quote(current_soldiers: float) -> Dictionary:
	var room := minf(TRAIN_AMOUNT, MAX_SOLDIERS - current_soldiers)
	if room <= 0.0:
		return {"amount": 0.0, "cost": 0.0}
	return {
		"amount": room,
		"cost": TRAIN_COST * (room / TRAIN_AMOUNT),
	}


static func build_cost(kind: String) -> float:
	match kind:
		"barricade":
			return BARRICADE_COST
		"trap":
			return TRAP_COST
		"catapult":
			return CATAPULT_COST
		"campsite":
			return CAMPSITE_COST
		_:
			return 99999.0


static func build_uses_food(kind: String) -> bool:
	return kind == "campsite"


static func structure_hp(kind: String) -> float:
	match kind:
		"barricade":
			return BARRICADE_HP
		"trap":
			return TRAP_HP
		"catapult":
			return CATAPULT_HP
		"campsite":
			return CAMPSITE_HP
		_:
			return 50.0


static func node_rate(kind: String) -> float:
	return float(NODE_RATE.get(kind, 0.0))


static func node_regen(kind: String) -> float:
	return float(NODE_REGEN.get(kind, 0.0))


static func node_max(kind: String) -> float:
	return float(NODE_MAX.get(kind, 1.0))
