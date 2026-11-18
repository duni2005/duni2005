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
const EVADE: StringName = &"evade"
const SLASH: StringName = &"slash"
const SWEEP: StringName = &"sweep"
## 0.99.10: 용암 붓기, 치유, 소리치기, 단결, 은신, 미사일.
const LAVA: StringName = &"lava"
const MEND: StringName = &"mend"
const SHOUT: StringName = &"shout"
const UNITE: StringName = &"unite"
const STEALTH: StringName = &"stealth"
const MISSILE: StringName = &"missile"
const NAMES = {HEAL:"회복", SMASH:"강타", MOVE:"이동", CHARGE:"충전", OVERCHARGE:"과충전", CLEAVE:"가르기", EVADE:"회피", SLASH:"참격", SWEEP:"휩쓸어 모으기", LAVA:"용암 붓기", MEND:"치유", SHOUT:"소리치기", UNITE:"단결", STEALTH:"은신", MISSILE:"미사일"}
const ICONS = {HEAL:"mango", SMASH:"battle", MOVE:"boots", CHARGE:"charge", OVERCHARGE:"energy", CLEAVE:"woodSword", EVADE:"evade", SLASH:"woodSword", SWEEP:"skull", LAVA:"phoenixFeather", MEND:"star", SHOUT:"hawkFeather", UNITE:"shield", STEALTH:"evade", MISSILE:"dragonHeart"}
## Danger grades: 일반 (normal), 주의 (caution), 위험 (danger), 고위험 (high, 보스급 only).
const NORMAL: StringName = &"normal"
const CAUTION: StringName = &"caution"
const DANGER: StringName = &"danger"
const HIGH: StringName = &"high"
const TIERS = {HEAL:NORMAL, MOVE:NORMAL, CHARGE:NORMAL, EVADE:NORMAL, MEND:NORMAL, SLASH:CAUTION, SHOUT:CAUTION, STEALTH:CAUTION, SMASH:DANGER, CLEAVE:DANGER, OVERCHARGE:DANGER, LAVA:DANGER, UNITE:DANGER, SWEEP:HIGH, MISSILE:HIGH}
const TIER_NAMES = {NORMAL:"일반", CAUTION:"주의", DANGER:"위험", HIGH:"고위험"}
## Damage a strategy needs the unit to deal (any of its own damage instances): fire, light, explosion.
const NEEDS = {LAVA:&"fire", MEND:&"light", MISSILE:&"explosion"}
## Numbers of the 0.99.10 strategies.
const LAVA_TIME: float = 7
const LAVA_RADIUS: float = 85
const MEND_AMOUNT: float = .2
const SHOUT_TIME: float = 5
const SHOUT_RADIUS: float = 190
const UNITE_SHIELD: float = .3
const UNITE_TIME: float = 10
const STEALTH_TIME: float = 5
const MISSILE_RADIUS: float = 170
const WINDUP_MISSILE: float = 1.4
## 도감: [what it does, when an enemy picks it].
const INFO = {
	HEAL:["비상식량을 먹어 자신의 HP를 20~30% 회복한다.", "자신의 HP가 65% 미만일 때."],
	MOVE:["표시된 경로로 빠르게 이동해 적에게 다가간다.", "근거리 유닛이 적과 멀리 떨어져 있을 때."],
	CHARGE:["궁극기 게이지를 20~30% 충전한다.", "궁극기가 있고 게이지가 80% 미만일 때."],
	EVADE:["표시된 안전한 위치로 빠르게 물러난다.", "적이 가까이 붙었고, 원거리이거나 HP가 50% 미만일 때."],
	MEND:["가까운 아군 하나의 HP를 20% 치유한다.", "빛 속성 피해를 쓰는 적. 근처에 다친 아군이 있을 때."],
	SLASH:["앞쪽 원형 범위에 참격을 가한다.", "적이 260 거리 안에 있을 때."],
	SHOUT:["자신 앞 부채꼴 범위의 유닛들에게 피해를 주고 5초간 \"역풍\"(이동속도 -30%, 공격속도 -20%)을 건다.", "적이 가까이 있을 때."],
	STEALTH:["5초간 은신해 적에게 보이지 않는다.", "언제든. 원거리이거나 HP가 낮으면 더 자주."],
	SMASH:["앞쪽 부채꼴을 강하게 내려쳐 피해를 주고 2초간 기절시킨다.", "적이 바로 앞에 있을 때."],
	CLEAVE:["표시된 경로로 대시하며 닿는 적에게 피해를 준다.", "적이 110~340 거리에 있을 때."],
	OVERCHARGE:["즉시 궁극기를 쓰거나(샷건은 8초 강화) 한다.", "궁극기가 있고 탑을 어느 정도 올랐을 때."],
	LAVA:["표시된 위치에 7초간 남는 용암 장판을 붓는다. 장판에 닿은 유닛은 지속 피해와 화상 스택을 받는다.", "화염 속성 피해를 쓰는 적. 적이 사거리 안에 있을 때."],
	UNITE:["모든 아군에게 최대 HP의 30%만큼 보호막(10초)을 준다.", "언제든. 아군이 많을수록 더 자주."],
	SWEEP:["주변 넓은 원에 강한 참격을 일으키고 맞은 유닛을 한곳에 모은다.", "보스급. 주변에 적이 있을 때."],
	MISSILE:["표시된 위치로 미사일을 날려 큰 범위에 폭발 피해를 준다.", "폭발 피해를 쓰는 보스급 적. 적이 사거리 안에 있을 때."],
}
## Units whose own damage can use `kind` (always true for strategies with no NEEDS).
static func usable(kind: StringName, type_id: int) -> bool:
	if not NEEDS.has(kind):return true
	var tag: StringName = NEEDS[kind]
	if CharacterCatalog.element(type_id) == tag:return true
	for spec in UnitStatTable.instances(type_id):
		if spec.key != &"transcend" and tag in spec.tags:return true
	return false
## Attacks wait this long after the turning point before they land; a high-danger one waits longer.
const WINDUP: float = .6
const WINDUP_HIGH: float = 1.0
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
		EVADE:return "이 적은 해당 위치로 이동하려 합니다."
		SLASH:return "이 적은 해당 범위에 참격을 가하려 합니다. (피해 %d)" % roundi(float(m.get("damage", 0)))
		SWEEP:return "이 적은 해당 범위에 강한 참격을 일으키고 유닛을 한곳에 모으려 합니다. (피해 %d)" % roundi(float(m.get("damage", 0)))
		LAVA:return "이 유닛은 해당 위치에 %d초간 유지되는 용암 장판을 배치하려 한다. 용암 장판에 닿은 유닛은 지속 피해와 화상 스택을 받는다." % roundi(LAVA_TIME)
		MEND:return "이 유닛은 가까운 아군의 HP를 %d%% 치유하려 한다." % roundi(float(m.get("amount", MEND_AMOUNT)) * 100)
		SHOUT:return "이 유닛은 해당 범위 유닛들에게 피해 %d와 \"역풍\" 디버프를 %d초간 부여하려 한다." % [roundi(float(m.get("damage", 0))), roundi(SHOUT_TIME)]
		UNITE:return "이 유닛은 모든 아군에게 보호막을 부여하려 한다. (최대 HP의 %d%%)" % roundi(UNITE_SHIELD * 100)
		STEALTH:return "이 유닛은 %d초간 은신하려 한다." % roundi(STEALTH_TIME)
		MISSILE:return "이 유닛은 해당 위치에 미사일을 날려 큰 범위 폭발 피해 %d를 가하려 한다." % roundi(float(m.get("damage", 0)))
	return ""
func tier() -> StringName:return TIERS.get(plan_type, NORMAL)
