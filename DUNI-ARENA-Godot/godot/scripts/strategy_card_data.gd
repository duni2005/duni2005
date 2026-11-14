class_name StrategyCardData
extends Resource
## Shared immutable definition of a strategy card; no per-copy use/cooldown state.
## Kind: 소모 (gone once used), 일반 (once in every battle it is taken into), 쿨타임 N (after a
## use, ready again after N won battle rooms). Use: who or where it is played on. Condition: an
## optional target or situation rule; disrupt: the highest enemy strategy grade it can remove.
enum Usage { CONSUME, GENERAL, COOLDOWN }
@export var kind: StringName
@export var display_name: String
@export var targeting_type: StringName = &"living_ally"
@export var usage_rule: Usage
@export var description: String
@export var amount: float
@export var duration: float

@export var gold_price: int = 0
## 쿨타임 N: battle rooms to win before it can be used again.
@export var cooldown_wins: int = 0
## &"ally", &"enemy" (unit cards), &"position" (dropped on the field), &"instant".
@export var use_mode: StringName = &"ally"
## Target conditions: &"melee", &"rush", &"low_hp", &"planning"; situation conditions:
## &"outnumbered", &"enemy_planning". &"" for none.
@export var condition: StringName = &""
## Disruption: the highest enemy strategy grade removed (&"normal", &"danger", &"high"); &"" none.
@export var disrupt: StringName = &""
## A second number of the effect (봉인의 낙인: turning points sealed; 망고 연회: ultimate gauge).
@export var extra: float = 0

const USAGE_NAMES = {Usage.CONSUME:"소모", Usage.GENERAL:"일반", Usage.COOLDOWN:"쿨타임"}
const USE_NAMES = {&"ally":"아군 지정", &"enemy":"적 지정", &"position":"위치 지정", &"instant":"즉시 시전"}
const USE_ICONS = {&"ally":"use_unit", &"enemy":"use_unit", &"position":"use_place", &"instant":"use_instant"}
const CONDITION_NAMES = {&"melee":"근접형", &"rush":"저돌적", &"low_hp":"HP 30% 이하", &"planning":"특수전략 준비 중인 적", &"outnumbered":"아군 수 열세", &"enemy_planning":"적 특수전략 준비 중"}
const SITUATION = [&"outnumbered", &"enemy_planning"]
const DISRUPT_NAMES = {&"normal":"일반 등급", &"danger":"위험 이하", &"high":"고위험 포함"}

## "소모", "일반" or "쿨타임 2".
func kind_text() -> String:
	return "쿨타임 %d" % cooldown_wins if usage_rule == Usage.COOLDOWN else USAGE_NAMES.get(usage_rule, "")
func use_text() -> String:return USE_NAMES.get(use_mode, "")
func use_icon() -> String:return USE_ICONS.get(use_mode, "unit")
func condition_text() -> String:return CONDITION_NAMES.get(condition, "")
## Tags as shown on the card: [쿨타임 2] [조건: 근접형] [방해: 위험 이하].
func tags() -> Array[String]:
	var out: Array[String] = [kind_text()]
	if condition != &"":out.append("조건: " + condition_text())
	if disrupt != &"":out.append("방해: " + DISRUPT_NAMES.get(disrupt, ""))
	return out
func unit_target() -> bool:return use_mode in [&"ally", &"enemy"]
func situation() -> bool:return condition in SITUATION
## One line for detail views: 종류 · 사용법 · 조건.
func rule_line() -> String:return " · ".join(tags() + [use_text()])
