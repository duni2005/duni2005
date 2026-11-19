class_name StrategyCardData
extends Resource
## Shared immutable definition of a strategy card; no per-copy use/cooldown state.
## Every card has three axes:
## - card_kind: &"active" (played at a turning point) or &"passive" (on for the battle it is
##   taken into, never played);
## - usage (actives only): &"unit_ally", &"unit_enemy", &"unit_any", &"position", &"instant";
##   passives &"none";
## - cooldown_type: &"consume" (gone once used), &"normal" (every battle it is taken into),
##   &"cooldown" (ready again after cooldown_wins won battle rooms).
## conditions: target or situation rules (all must hold); disrupt: the highest enemy strategy
## grade it removes. image: a picture for the card art (empty: the card icon on its colour).
@export var kind: StringName
@export var display_name: String
@export var description: String
@export var amount: float
@export var duration: float
@export var gold_price: int = 0
@export var card_kind: StringName = &"active"
@export var usage: StringName = &"unit_ally"
@export var cooldown_type: StringName = &"normal"
@export var cooldown_wins: int = 0
## Target conditions: &"melee", &"rush", &"low_hp", &"planning"; situation conditions:
## &"outnumbered", &"enemy_planning", &"element_pair" (passive: two allies of one element).
@export var conditions: Array[StringName] = []
@export var disrupt: StringName = &""
## A second number of the effect (해제 마법서: turning points sealed, 0 = none; 망고 연회: gauge;
## 치유 장판: radius).
@export var extra: float = 0
@export var image: String = ""

const COOLDOWN_NAMES = {&"consume":"소모", &"normal":"일반", &"cooldown":"쿨타임"}
const USAGE_NAMES = {&"unit_ally":"유닛 지정(아군)", &"unit_enemy":"유닛 지정(적)", &"unit_any":"유닛 지정(전체)", &"position":"위치 지정", &"instant":"즉시 시전", &"none":""}
const USAGE_SHORT = {&"unit_ally":"아군", &"unit_enemy":"적", &"unit_any":"전체", &"position":"위치", &"instant":"즉시", &"none":""}
const USAGE_ICONS = {&"unit_ally":"use_unit", &"unit_enemy":"use_unit", &"unit_any":"use_unit", &"position":"use_place", &"instant":"use_instant", &"none":"card"}
const CONDITION_NAMES = {&"melee":"근접형", &"rush":"저돌적", &"low_hp":"HP 30% 이하", &"planning":"특수전략 준비 중인 적", &"outnumbered":"아군 수 열세", &"enemy_planning":"적 특수전략 준비 중", &"element_pair":"같은 속성 아군 2명 이상 출정"}
const SITUATION = [&"outnumbered", &"enemy_planning", &"element_pair"]
const DISRUPT_NAMES = {&"normal":"일반 등급", &"danger":"위험 이하", &"high":"고위험 포함"}

func passive() -> bool:return card_kind == &"passive"
## "소모", "일반" or "쿨타임 2".
func kind_text() -> String:
	return "쿨타임 %d" % cooldown_wins if cooldown_type == &"cooldown" else COOLDOWN_NAMES.get(cooldown_type, "")
## The type band: "액티브 · 유닛 지정(아군)", "액티브 · 위치 지정", "패시브".
func type_text(short: bool = false) -> String:
	if passive():return "패시브"
	return ("액티브·" + USAGE_SHORT.get(usage, "")) if short else "액티브 · " + USAGE_NAMES.get(usage, "")
func use_text() -> String:return USAGE_NAMES.get(usage, "")
func use_icon() -> String:return USAGE_ICONS.get(usage, "card")
func condition_text() -> String:return ", ".join(conditions.map(func(c): return CONDITION_NAMES.get(c, String(c))))
## Tags as shown in lists: [쿨타임 2] [조건: 근접형]. (A disruption grade is in the effect text.)
func tags() -> Array[String]:
	var out: Array[String] = [kind_text()]
	if not conditions.is_empty():out.append("조건: " + condition_text())
	return out
func unit_target() -> bool:return usage in [&"unit_ally", &"unit_enemy", &"unit_any"]
## All of its conditions are situation conditions (no target to check).
func situation() -> bool:return conditions.all(func(c): return c in SITUATION)
## One line for detail views: 종류 · 사용 방식 · 쿨타임 종류 · 조건.
func rule_line() -> String:return " · ".join([type_text()] + tags())
