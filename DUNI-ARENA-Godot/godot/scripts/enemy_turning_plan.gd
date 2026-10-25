class_name EnemyTurningPlan
extends RefCounted
## An enemy's special strategy, chosen at a turning point and used as it ends.
## Pure identity-based data. No Unit, target Node or UI reference.
const HEAL: StringName = &"heal"
const SMASH: StringName = &"smash"
const MOVE: StringName = &"move"
const CHARGE: StringName = &"charge"
const OVERCHARGE: StringName = &"overcharge"
const CLEAVE: StringName = &"cleave"
const NAMES = {HEAL:"회복", SMASH:"강타", MOVE:"이동", CHARGE:"충전", OVERCHARGE:"과충전", CLEAVE:"가르기"}
const ICONS = {HEAL:"mango", SMASH:"battle", MOVE:"boots", CHARGE:"charge", OVERCHARGE:"energy", CLEAVE:"woodSword"}
## Attacks wait this long after the turning point before they land.
const WINDUP: float = .6
var plan_id: String = ""
var source_enemy_id: String = ""
var plan_type: StringName = HEAL
var _metadata: Dictionary = {}
var metadata: Dictionary:
	get: return _metadata.duplicate(true)
	set(value):
		if UnitStateCodec.is_pure_data(value):
			_metadata = value.duplicate(true)
var executed: bool = false

static func special_metadata(type_id: int) -> Dictionary:
	# dist/ultimate.js: type 7 (shotgun) is the only null ULTIMATES entry.
	if type_id == 7:
		return {"mode": "temporary_boost", "duration": 8.0, "damage_multiplier": 1.25, "cooldown": 0.0, "ammo": 2, "reloadRemaining": 0.0}
	return {"mode": "ultimate_ready", "gauge_gain": 100.0, "ultThink": 0.0, "ultReadyAge": 5.0, "strategyUltimateReady": true}

## What the strategy will do, as the player reads it.
func describe() -> String:
	var m: Dictionary = _metadata
	match plan_type:
		HEAL:return "이 유닛은 비상식량을 먹어 HP %d%%를 회복하려 한다." % roundi(float(m.get("amount", .2)) * 100)
		SMASH:return "앞으로 강력하게 공격해 피해 %d를 주고 %d초간 기절시킨다." % [roundi(float(m.get("damage", 0))), roundi(float(m.get("stun", 2)))]
		MOVE:return "이 유닛은 표시된 경로로 빠르게 이동하려 한다."
		CHARGE:return "이 유닛은 궁극기를 %d%% 충전하려 한다." % roundi(float(m.get("gauge", 20)))
		OVERCHARGE:return "이 유닛은 강화 상태에 들어가려 한다." if m.get("mode") == "temporary_boost" else "이 유닛은 즉시 궁극기를 사용하려 한다."
		CLEAVE:return "이 유닛은 표시된 경로로 빠르게 대시하며 피해 %d를 가할 예정이다." % roundi(float(m.get("damage", 0)))
	return ""
