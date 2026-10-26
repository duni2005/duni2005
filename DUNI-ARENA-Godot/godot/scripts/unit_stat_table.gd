class_name UnitStatTable
extends RefCounted
## Every tunable number of the stat/damage system in one place.
##
## Unit base stats (HP, move speed, range and attack interval stay in each character's .tres):
##   [main damage kind, defense, physical defense, magic defense, physical damage, magic damage]
## Damage instances, per unit:  key -> [skill, kind, base, ratio, tags, label]
##   raw damage = base + (physical or magic damage) x ratio
##   skill: basic / passive / ultimate (ultimate damage % applies) / transcend / item / system
## The Phase 1-7 golden harnesses (full characters off) keep their original numbers.

## Mitigation: final = damage x M / (M + defense) for defense >= 0,
## damage x (2 - M / (M - defense)) below zero.
const MITIGATION: float = 100
const CRIT_DAMAGE: float = 1.5
## Elements multiply with "element damage %"; every tag can carry its own bonus.
const ELEMENTS = [&"ice", &"fire", &"poison", &"wind", &"light", &"dark", &"lightning"]
const DAMAGE_TAGS = [&"explosion", &"area", &"projectile", &"dot"]
const TAG_NAMES = {&"ice":"얼음", &"fire":"화염", &"poison":"맹독", &"wind":"바람", &"light":"빛", &"dark":"어둠", &"lightning":"번개", &"explosion":"폭발", &"area":"범위", &"projectile":"투사체", &"dot":"지속"}
const KIND_NAMES = {&"physical":"물리", &"magic":"마법"}
const SKILL_NAMES = {&"basic":"기본공격", &"passive":"패시브", &"ultimate":"궁극기", &"transcend":"초월", &"item":"아이템", &"system":"공용"}

const STATS = {
	"warrior":[&"physical", 50, 0, 0, 28, 10],
	"archer":[&"physical", 30, 0, 0, 30, 10],
	"mage":[&"magic", 35, 0, 10, 10, 38],
	"assassin":[&"physical", 35, 0, 0, 45, 10],
	"guardian":[&"physical", 85, 0, 15, 24, 10],
	"healer":[&"magic", 30, 0, 10, 10, 22],
	"sniper":[&"physical", 40, 0, 0, 160, 10],
	"shotgun":[&"physical", 45, 0, 0, 70, 10],
	"rps":[&"physical", 45, 0, 0, 42, 15],
	"ufc":[&"physical", 55, 10, 0, 18, 10],
	"greatsword":[&"physical", 80, 10, 0, 70, 15],
	"dolphin":[&"physical", 35, 0, 0, 40, 10],
	"predator":[&"physical", 95, 15, 0, 72, 15],
	"bomber":[&"physical", 40, 0, 0, 60, 15],
	"swordsman":[&"physical", 50, 0, 0, 25, 10],
	"satellite":[&"physical", 35, 0, 0, 28, 15],
	"paladin":[&"physical", 70, 0, 20, 30, 20],
	"hero":[&"physical", 60, 0, 0, 40, 15],
	"tank":[&"physical", 100, 10, -10, 62, 30],
	"fanatic":[&"magic", 40, 0, 0, 15, 30],
	"lightning":[&"magic", 40, 0, 10, 10, 30],
	"mirror":[&"magic", 45, 0, 30, 10, 30],
	"galaxy":[&"magic", 40, 0, 10, 10, 20],
	"machine_gun":[&"physical", 40, 0, 0, 45, 10],
	"frog":[&"physical", 50, 0, 0, 60, 15],
	"puppet":[&"magic", 40, 0, 10, 10, 23],
	"stake":[&"physical", 45, 0, 0, 50, 10],
	"conductor":[&"physical", 35, 0, 0, 30, 10],
	"refraction":[&"magic", 20, 0, 0, 10, 145],
	"courier":[&"physical", 30, 0, 0, 0, 0],
	"magnet":[&"magic", 35, 0, 10, 10, 24],
	"frost":[&"magic", 25, 0, 10, 10, 30],
}

const DAMAGE = {
	"warrior":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "검 베기"],
		&"counter":[&"passive", &"physical", 0, 1.25, [], "패링 반격"],
		&"ult_slash":[&"ultimate", &"physical", 10, 2.8, [&"area"], "넓게 베기"],
		&"ult_wave":[&"ultimate", &"physical", 0, 2.3, [&"projectile"], "검기 발사"]},
	"archer":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"projectile"], "화살 (3발째 부채꼴 · 튕김)"],
		&"ult":[&"ultimate", &"physical", 20, 7.0, [&"projectile"], "거대한 화살"]},
	"mage":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"projectile", &"explosion"], "마법탄"],
		&"splash":[&"basic", &"magic", 0, 0.5, [&"explosion", &"area"], "폭발 여파"],
		&"ult":[&"ultimate", &"magic", 5, 0.05, [&"dark", &"area", &"dot"], "블랙홀 (0.5초마다)"]},
	"assassin":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "단검 찌르기"]},
	"guardian":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "방패 내려치기"]},
	"healer":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"light", &"projectile"], "빛 화살"]},
	"sniper":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"projectile"], "저격탄"],
		&"ult":[&"ultimate", &"physical", 0, 1.0, [&"projectile"], "연속 저격 (3발)"]},
	"shotgun":{
		&"basic":[&"basic", &"physical", 0, 0.25, [&"projectile"], "산탄 1발 (7발 · 거리 감쇠)"]},
	"rps":{
		&"basic":[&"basic", &"physical", 30, 1.2, [], "가위바위보 승리"],
		&"ult":[&"ultimate", &"physical", 50, 1.6, [], "강화 승부 승리"]},
	"ufc":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "펀치 (1·2타)"],
		&"basic_last":[&"basic", &"physical", 0, 1.35, [], "펀치 (3타)"],
		&"ult":[&"ultimate", &"physical", 15, 0.9, [&"area"], "돌진 충돌"],
		&"ring":[&"ultimate", &"physical", 10, 0.7, [&"area"], "링 줄 충돌"]},
	"greatsword":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "특대검 내려치기"],
		&"ult_slash":[&"ultimate", &"physical", 0, 1.5, [&"area"], "강타"],
		&"ult_wave":[&"ultimate", &"physical", 0, 2.7, [&"projectile"], "충격파"]},
	"dolphin":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "몸통 박치기"],
		&"ult":[&"ultimate", &"physical", 0, 1.15, [], "연속 박치기"]},
	"predator":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"area"], "물기 (최대 3명)"],
		&"ult":[&"ultimate", &"physical", 0, 1.8, [&"area"], "강한 물기"]},
	"bomber":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"fire", &"explosion", &"area"], "폭탄"],
		&"ult":[&"ultimate", &"physical", 0, 2.6, [&"fire", &"explosion", &"area"], "대형 폭탄"],
		&"self_destruct":[&"passive", &"physical", 0, 2.5, [&"fire", &"explosion", &"area"], "자폭"]},
	"swordsman":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "베기 (1타)"],
		&"basic_2":[&"basic", &"physical", 0, 1.1, [], "베기 (2타)"],
		&"basic_3":[&"basic", &"physical", 0, 3.0, [], "베기 (3타)"],
		&"ult":[&"ultimate", &"physical", 0, 3.6, [], "일섬"]},
	"satellite":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"fire", &"projectile"], "추적 미사일 (제어된 적 +40%/초)"],
		&"counter":[&"passive", &"physical", 0, 0.2, [&"fire", &"projectile"], "반격 미사일"],
		&"ult":[&"ultimate", &"physical", 0, 1.8, [&"fire", &"projectile"], "미사일 일제 발사"]},
	"paladin":{
		&"basic":[&"basic", &"physical", 0, 1.25, [&"light"], "강타"],
		&"bash":[&"basic", &"physical", 0, 0.65, [], "방패 밀치기"]},
	"hero":{
		&"basic":[&"basic", &"physical", 0, 1.0, [], "펀치"],
		&"rescue":[&"passive", &"physical", 0, 1.6, [&"area"], "구조 일격"],
		&"ult":[&"ultimate", &"physical", 0, 4.2, [], "강펀치"]},
	"tank":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"fire", &"explosion", &"area"], "포탄"],
		&"enhanced":[&"ultimate", &"physical", 0, 1.7, [&"fire", &"explosion", &"area"], "화염 포탄"],
		&"fire_zone":[&"ultimate", &"magic", 3, 0.2, [&"fire", &"area", &"dot"], "화염 지대 (0.5초마다)"]},
	"fanatic":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"light"], "광신의 일격"]},
	"lightning":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"lightning", &"projectile"], "연쇄 번개 (튈 때마다 -10%)"],
		&"ult":[&"ultimate", &"magic", 10, 2.6, [&"lightning", &"area"], "대방전"]},
	"mirror":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"light", &"projectile"], "반사광 (튕길 때마다 +20%)"]},
	"galaxy":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"projectile"], "별 (5발)"]},
	"machine_gun":{
		&"basic":[&"basic", &"physical", 0, 0.35, [&"projectile"], "총알"]},
	"frog":{
		&"basic":[&"basic", &"physical", 0, 1.0, [&"projectile"], "혀"],
		&"spit":[&"ultimate", &"physical", 0, 1.0, [&"projectile"], "삼킨 적 발사 (무거울수록 +)"],
		&"spit_landing":[&"ultimate", &"physical", 0, 0.7, [], "발사된 적 착지"]},
	"puppet":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"projectile"], "날카로운 실"]},
	"stake":{
		&"open":[&"passive", &"physical", 10, 0.4, [], "말뚝 박기"],
		&"basic":[&"basic", &"physical", 0, 1.0, [], "망치"],
		&"ult":[&"ultimate", &"physical", 30, 1.25, [], "도약 내려찍기"]},
	"conductor":{
		&"ult":[&"ultimate", &"physical", 40, 3.5, [&"area"], "기관차"]},
	"refraction":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"light", &"projectile"], "광선"]},
	"courier":{},
	"magnet":{
		&"basic":[&"basic", &"magic", 0, 1.0, [&"lightning", &"projectile"], "전류구"],
		&"ult":[&"ultimate", &"magic", 10, 0.85, [&"lightning"], "극 부착"],
		&"slam":[&"ultimate", &"magic", 20, 1.3, [&"lightning"], "자석 충돌"],
		&"sweep":[&"ultimate", &"magic", 10, 1.0, [&"lightning"], "끌려가며 부딪힘"]},
	"frost":{
		&"basic":[&"basic", &"magic", 0, 0.5, [&"ice", &"projectile"], "얼음 수정 (3발)"],
		&"ult":[&"ultimate", &"magic", 0, 0.6, [&"ice", &"area", &"dot"], "얼음 폭풍 (0.5초마다)"]},
}
## Damage every unit can deal regardless of character, using its main damage kind.
const TRANSCEND = [&"transcend", &"", 60, 5.0, [&"area"], "초월 · 검격"]
const ITEM = {&"dragon_heart":[&"item", &"magic", 15, 0.6, [&"fire", &"area"], "용의 심장"]}
## Turning-point special strategies; the ratio grows with tower progress (see EnemyStrategyPlanner).
const STRATEGY = {&"strategy_smash":[&"system", &"", 0, 2.0, [&"area"], "특수전략 · 강타"], &"strategy_cleave":[&"system", &"", 0, 1.5, [], "특수전략 · 가르기"]}

static func row(type_id: int) -> Array:
	return STATS.get(_name(type_id), [&"physical", 30, 0, 0, 20, 10])
static func _name(type_id: int) -> String:
	return CharacterCatalog.NAMES[type_id] if type_id >= 0 and type_id < CharacterCatalog.NAMES.size() else ""
static func main_kind(type_id: int) -> StringName:return row(type_id)[0]
static func base_defense(type_id: int) -> float:return row(type_id)[1]
static func base_physical_defense(type_id: int) -> float:return row(type_id)[2]
static func base_magic_defense(type_id: int) -> float:return row(type_id)[3]
static func base_physical(type_id: int) -> float:return row(type_id)[4]
static func base_magic(type_id: int) -> float:return row(type_id)[5]

static func _spec(entry: Array, key: StringName, main: StringName) -> Dictionary:
	return {"key":key, "skill":entry[0], "kind":entry[1] if entry[1] != &"" else main, "base":float(entry[2]), "ratio":float(entry[3]), "tags":entry[4], "label":entry[5]}
## The unit's own damage instances, in table order (the transcendence slash last).
static func instances(type_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table: Dictionary = DAMAGE.get(_name(type_id), {})
	for key in table:out.append(_spec(table[key], key, main_kind(type_id)))
	out.append(_spec(TRANSCEND, &"transcend", main_kind(type_id)))
	return out
## Spec for one damage instance; unknown keys fall back to the unit's basic attack (or a plain
## hit of its main kind).
static func spec(type_id: int, key: StringName) -> Dictionary:
	var main: StringName = main_kind(type_id)
	var table: Dictionary = DAMAGE.get(_name(type_id), {})
	if table.has(key):return _spec(table[key], key, main)
	if key == &"transcend":return _spec(TRANSCEND, key, main)
	if ITEM.has(key):return _spec(ITEM[key], key, main)
	if STRATEGY.has(key):return _spec(STRATEGY[key], key, main)
	if table.has(&"basic"):return _spec(table[&"basic"], &"basic", main)
	return {"key":&"", "skill":&"system", "kind":main, "base":0.0, "ratio":1.0, "tags":[], "label":""}

## Physical or magic damage of a live unit or of stats (growth and items included).
static func damage_stat(u, kind: StringName) -> float:
	var stats = u.combat_stats if u is BattleUnit else u
	if stats != null and stats is UnitCombatStats:return stats.physical_damage if kind == &"physical" else stats.magic_damage
	return base_physical(u.data.type_id) if kind == &"physical" else base_magic(u.data.type_id)
## Raw damage of one instance before any multiplier or mitigation.
static func raw(u, key: StringName) -> float:
	var s: Dictionary = spec(u.data.type_id, key)
	return s.base + damage_stat(u, s.kind) * s.ratio
static func has_element(tags: Array) -> bool:
	return tags.any(func(t):return t in ELEMENTS)
## Sum of the attacker's matching element and tag bonuses (added together, multiplied once).
static func tag_bonus(stats: UnitCombatStats, tags: Array) -> float:
	var total: float = 0
	if stats == null:return 0
	for t in tags:total += float(stats.element_bonus.get(t, 0)) + float(stats.tag_bonus.get(t, 0))
	return total
## Damage before mitigation and critical hits: raw x attack % x (1 + bonuses) x element % x ultimate %.
static func estimate(spec_row: Dictionary, stats: UnitCombatStats, physical: float, magic: float) -> float:
	var value: float = spec_row.base + (physical if spec_row.kind == &"physical" else magic) * spec_row.ratio
	if stats == null:return value
	value *= stats.attack * (1 + tag_bonus(stats, spec_row.tags))
	if has_element(spec_row.tags):value *= stats.element_power
	if spec_row.skill == &"ultimate":value *= stats.ult_damage
	return value
## Mitigation multiplier for a defense value.
static func mitigation(defense: float) -> float:
	return MITIGATION / (MITIGATION + defense) if defense >= 0 else 2 - MITIGATION / (MITIGATION - defense)
