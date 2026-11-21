class_name TrialCatalog
extends RefCounted
## 시련: traits of a battle room (일반 전투 · 미니보스 · 보스). Most work on the room's enemies; 환경
## trials work on both sides. At most MAX_TRIALS per room, each trial once.
## Kinds: 카운터 (enemies take COUNTER_TAKEN of one damage kind or tag), 환경, 적 강화 and 보상
## (a harder room that pays more). Every definition and number is here; TrialEffects runs them
## in battle, TrialArt draws them.
const COUNTER: StringName = &"counter"
const ENVIRONMENT: StringName = &"environment"
const EMPOWER: StringName = &"empower"
const REWARD: StringName = &"reward"
const KINDS: Array[StringName] = [COUNTER, ENVIRONMENT, EMPOWER, REWARD]
const KIND_NAMES = {COUNTER: "카운터", ENVIRONMENT: "환경", EMPOWER: "적 강화", REWARD: "보상"}
## Icon rim by kind: 카운터 red, 환경 yellow, 적 강화 purple, 보상 gold.
const KIND_COLORS = {COUNTER: Color("ff5a5a"), ENVIRONMENT: Color("f2e45a"), EMPOWER: Color("b884ff"), REWARD: Color("e8a93a")}

const MAX_TRIALS: int = 4
const MAX_COUNTERS: int = 2
## 미니보스 and 챕터 보스 rooms.
const MAX_BOSS_COUNTERS: int = 1
const MAX_REWARDS: int = 1
## Floors (1-based): [first, last, fewest trials, most trials, most counters].
const FLOOR_RULES: Array = [[1, 3, 0, 1, 0], [4, 6, 1, 2, 1], [7, 9, 2, 3, 2], [10, 15, 2, 4, 2]]
## 강인함 (physical) and 해루석 보호막 (magic) appear from this floor and never together.
const BROAD_COUNTER_FLOOR: int = 7
const EXCLUSIVE: Array = [[&"tough", &"seastone"]]

## 카운터: share of a matching hit an enemy still takes (60% less), once however many match.
const COUNTER_TAKEN: float = .4
## 소행성: every METEOR_EVERY s a meteor falls on a random spot after a METEOR_WARN s warning.
const METEOR_EVERY: float = 10.0
const METEOR_WARN: float = 1.5
const METEOR_RADIUS: float = 110.0
const METEOR_BASE: float = 20.0
const METEOR_PER_FLOOR: float = 10.0
## 짙은 안개: every unit's range × FOG_RANGE, never below FOG_MIN_RANGE.
const FOG_RANGE: float = .7
const FOG_MIN_RANGE: float = 60.0
## 지진: every QUAKE_EVERY s every unit falls for QUAKE_FALL s; the screen shakes QUAKE_WARN s before.
const QUAKE_EVERY: float = 15.0
const QUAKE_FALL: float = .6
const QUAKE_WARN: float = 1.0
## 끈질긴 생명: enemies heal this share of max HP a second.
const REGEN_PER_SECOND: float = .01
## 광전사들: at or below BERSERK_HP of max HP.
const BERSERK_HP: float = .3
const BERSERK_ATTACK_SPEED: float = 1.5
const BERSERK_MOVE: float = 1.2
## 복수심: each enemy that falls gives the enemies within VENGEANCE_RADIUS attack +VENGEANCE_ATTACK.
const VENGEANCE_RADIUS: float = 200.0
const VENGEANCE_ATTACK: float = .1
const VENGEANCE_MAX: int = 5
## 선봉대: the first VANGUARD_TIME s every enemy moves × VANGUARD_MOVE and charges.
const VANGUARD_TIME: float = 3.0
const VANGUARD_MOVE: float = 1.6
## 저격 지원: every SNIPER_EVERY s the ally with the most HP is aimed at for SNIPER_AIM s, then shot.
const SNIPER_EVERY: float = 12.0
const SNIPER_AIM: float = 1.2
const SNIPER_BASE: float = 25.0
const SNIPER_PER_FLOOR: float = 12.0
## 금괴 운반대: enemy speed × CONVOY_SPEED; kill gold × CONVOY_KILL_GOLD, victory gold × CONVOY_VICTORY_GOLD.
const CONVOY_SPEED: float = 1.2
const CONVOY_KILL_GOLD: float = 2.0
const CONVOY_VICTORY_GOLD: float = 1.3
## 보물 수호자: enemy HP × TREASURE_HP; one more item to choose from after the win.
const TREASURE_HP: float = 1.25
const TREASURE_CHOICES: int = 1
## The floor trial damage is counted at in custom battles (no tower floor there).
const CUSTOM_FLOOR: int = 8

## id -> name, kind, icon, description; 카운터 add "match" (a damage kind or tag) and may add
## "from" (first floor); "weather" marks the ones with a screen effect.
const TRIALS = {
	&"ironclad": {"name": "철갑", "kind": COUNTER, "icon": "sturdyShield", "match": &"projectile", "text": "적들이 철갑으로 무장해, 받는 투사체 피해가 60% 감소했습니다."},
	&"seastone": {"name": "해루석 보호막", "kind": COUNTER, "icon": "magicCloak", "match": &"magic", "from": BROAD_COUNTER_FLOOR, "text": "적들이 해루석 보호막을 둘러, 받는 마법 피해가 60% 감소했습니다."},
	&"tough": {"name": "강인함", "kind": COUNTER, "icon": "ironHelm", "match": &"physical", "from": BROAD_COUNTER_FLOOR, "text": "적들이 강인한 신체를 갖고 있습니다. 받는 물리 피해가 60% 감소합니다."},
	&"holy": {"name": "신성", "kind": COUNTER, "icon": "radiantLamp", "match": &"dark", "text": "적들이 신성한 축복을 받아, 받는 어둠 속성 피해가 60% 감소했습니다."},
	&"corrupt": {"name": "타락", "kind": COUNTER, "icon": "abyssScythe", "match": &"light", "text": "적들이 타락한 힘을 받아, 받는 빛 속성 피해가 60% 감소했습니다."},
	&"immune": {"name": "면역력", "kind": COUNTER, "icon": "verdantStone", "match": &"poison", "text": "적들이 강한 면역력을 지녀, 받는 맹독 속성 피해가 60% 감소했습니다."},
	&"insulator": {"name": "절연체", "kind": COUNTER, "icon": "lightningRod", "match": &"lightning", "text": "적들이 절연 두건을 둘러, 받는 번개 속성 피해가 60% 감소했습니다."},
	&"sun": {"name": "태양", "kind": COUNTER, "icon": "trial_sun", "match": &"ice", "weather": true, "text": "태양이 강하게 떴습니다! 적들이 받는 얼음 속성 피해가 60% 감소합니다."},
	&"rain": {"name": "비", "kind": COUNTER, "icon": "trial_rain", "match": &"fire", "weather": true, "text": "비가 내리고 있습니다. 적들이 받는 화염 속성 피해가 60% 감소합니다."},
	&"calm": {"name": "무풍지대", "kind": COUNTER, "icon": "trial_calm", "match": &"wind", "text": "바람 한 점 없습니다. 적들이 받는 바람 속성 피해가 60% 감소합니다."},
	&"bomb_squad": {"name": "폭탄처리반", "kind": COUNTER, "icon": "powderKeg", "match": &"explosion", "text": "적들은 폭탄처리반으로 일하고 있습니다! 받는 폭발 피해가 60% 감소합니다."},
	&"melee_masters": {"name": "백병전", "kind": COUNTER, "icon": "duelistGlove", "match": &"melee", "text": "적들은 백병전의 달인들입니다! 받는 근접공격 피해가 60% 감소합니다."},
	&"spread": {"name": "산개", "kind": COUNTER, "icon": "commanderCompass", "match": &"area", "text": "적들이 넓게 흩어져 분산했습니다! 받는 범위 피해가 60% 감소합니다."},
	&"stubborn": {"name": "불굴의 체질", "kind": COUNTER, "icon": "lifeResonance", "match": &"dot", "text": "적들이 끈질긴 체질을 지녔습니다. 받는 지속 피해가 60% 감소합니다."},
	&"meteor": {"name": "소행성", "kind": ENVIRONMENT, "icon": "trial_meteor", "text": "10초마다 무작위 위치(반경 110)에 운석이 떨어집니다. 1.5초 전 붉은 원으로 예고하고, 아군 · 적 모두에게 큰 범위 피해(20 + 10 × 층)를 줍니다."},
	&"fog": {"name": "짙은 안개", "kind": ENVIRONMENT, "icon": "trial_fog", "weather": true, "text": "짙은 안개로 모든 유닛의 사거리가 30% 줄어듭니다(최소 60)."},
	&"quake": {"name": "지진", "kind": ENVIRONMENT, "icon": "trial_quake", "text": "15초마다 땅이 흔들려 모든 유닛이 0.6초 동안 넘어집니다(행동 불가). 1초 전 화면이 흔들리며 예고합니다."},
	&"regen": {"name": "끈질긴 생명", "kind": EMPOWER, "icon": "vital", "text": "적이 매초 최대 HP의 1%를 회복합니다."},
	&"berserkers": {"name": "광전사들", "kind": EMPOWER, "icon": "berserkerHelm", "text": "적은 HP 30% 이하가 되면 공격속도 +50%, 이동속도 +20%."},
	&"elite_squad": {"name": "정예 부대", "kind": EMPOWER, "icon": "knightCrest", "text": "가장 비싼 일반 적 1명이 엘리트가 됩니다(엘리트 배율 적용)."},
	&"vengeance": {"name": "복수심", "kind": EMPOWER, "icon": "vengeanceMask", "text": "적이 쓰러질 때마다 반경 200 안의 적 공격력 +10% (최대 5중첩, 전투 동안)."},
	&"vanguard": {"name": "선봉대", "kind": EMPOWER, "icon": "chargeHorn", "text": "전투 시작 후 3초간 적 전원 이동속도 +60%, 아군 쪽으로 돌진합니다."},
	&"sniper": {"name": "저격 지원", "kind": EMPOWER, "icon": "sniperScope", "text": "12초마다 맵 밖에서 HP가 가장 높은 아군을 저격합니다. 1.2초 동안 붉은 조준선으로 예고하고 물리 피해(25 + 12 × 층)를 줍니다."},
	&"gold_convoy": {"name": "금괴 운반대", "kind": REWARD, "icon": "goldToken", "text": "적 이동속도 +20%. 대신 적 처치 골드 2배, 승리 골드 +30%."},
	&"treasure_guard": {"name": "보물 수호자", "kind": REWARD, "icon": "supply", "text": "적 HP +25%. 대신 승리 보상 아이템 선택지가 하나 늘어납니다(3 → 4)."},
}

static func has(id: StringName) -> bool:return TRIALS.has(id)
static func info(id: StringName) -> Dictionary:return TRIALS.get(id, {})
static func kind_of(id: StringName) -> StringName:return TRIALS.get(id, {}).get("kind", &"")
static func name_of(id: StringName) -> String:return str(TRIALS.get(id, {}).get("name", ""))
static func color_of(id: StringName) -> Color:return KIND_COLORS.get(kind_of(id), Color.WHITE)
static func of_kind(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in TRIALS:
		if TRIALS[id].kind == kind:out.append(id)
	return out
## First floor (1-based) a trial can appear on: 카운터 from 4 (강인함 · 해루석 보호막 from 7), the rest from 1.
static func first_floor(id: StringName) -> int:
	if kind_of(id) != COUNTER:return 1
	return int(TRIALS[id].get("from", FLOOR_RULES[1][0]))
## [fewest, most, most counters] for a 1-based floor.
static func floor_rule(floor: int) -> Array:
	for row in FLOOR_RULES:
		if floor >= int(row[0]) and floor <= int(row[1]):return [row[2], row[3], row[4]]
	return [FLOOR_RULES.back()[2], FLOOR_RULES.back()[3], FLOOR_RULES.back()[4]]
static func counter_cap(floor: int, room_type: StringName) -> int:
	var cap: int = mini(MAX_COUNTERS, int(floor_rule(floor)[2]))
	return mini(cap, MAX_BOSS_COUNTERS) if room_type in [RoomType.MINIBOSS, RoomType.BOSS] else cap

## Whether `id` may join `chosen` (once each, the kind caps, 강인함 ↔ 해루석 보호막, first floor).
## counter_cap < 0 skips the floor rules (custom battles keep only the room limits).
static func allowed(id: StringName, chosen: Array, floor: int = -1, cap: int = MAX_COUNTERS) -> bool:
	if not has(id) or id in chosen or chosen.size() >= MAX_TRIALS:return false
	if floor >= 0 and floor < first_floor(id):return false
	var kind: StringName = kind_of(id)
	if kind == COUNTER and chosen.filter(func(t):return kind_of(t) == COUNTER).size() >= cap:return false
	if kind == REWARD and chosen.filter(func(t):return kind_of(t) == REWARD).size() >= MAX_REWARDS:return false
	for pair in EXCLUSIVE:
		if id in pair and chosen.any(func(t):return t != id and t in pair):return false
	return true
## A valid list (saves, custom battles): known, unique, within every cap.
static func valid(list: Array) -> bool:
	var seen: Array = []
	for id in list:
		if not (id is StringName or id is String) or not allowed(StringName(id), seen):return false
		seen.append(StringName(id))
	return true

## The trials of a room on a 1-based floor: a count in the floor's range, then for each a kind
## among those still allowed (카운터 only within its cap), then a trial of that kind.
static func roll(rng: RandomNumberGenerator, floor: int, room_type: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if not RoomType.is_combat(room_type):return out
	var rule: Array = floor_rule(floor);var count: int = rng.randi_range(int(rule[0]), int(rule[1]))
	var cap: int = counter_cap(floor, room_type)
	for i in range(count):
		var kinds: Array = KINDS.filter(func(k):return of_kind(k).any(func(t):return allowed(t, out, floor, cap)))
		if kinds.is_empty():break
		var kind: StringName = kinds[rng.randi_range(0, kinds.size() - 1)]
		var options: Array = of_kind(kind).filter(func(t):return allowed(t, out, floor, cap))
		out.append(options[rng.randi_range(0, options.size() - 1)])
	return out

## Spawn changes baked into a room's enemies (saved with them): 정예 부대 makes the costliest
## ordinary enemy an elite, 보물 수호자 adds HP, 금괴 운반대 speed.
static func apply_spawns(encounter: EncounterState, trials: Array) -> void:
	if encounter == null:return
	if &"elite_squad" in trials:
		var best: EnemySpawnEntry = null
		for e in encounter.enemies:
			if e.rank != &"normal":continue
			if best == null or CharacterCatalog.all()[e.unit_type_id].base_gold_cost > CharacterCatalog.all()[best.unit_type_id].base_gold_cost:best = e
		if best != null:best.set_rank(&"elite")
	for e in encounter.enemies:
		if &"treasure_guard" in trials:e.hp_multiplier *= TREASURE_HP
		if &"gold_convoy" in trials:e.speed_multiplier *= CONVOY_SPEED

## The counter trials in `trials` that a hit of this damage kind and these tags falls under.
static func counters_for(trials: Array, kind: StringName, tags: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in trials:
		var t: Dictionary = TRIALS.get(id, {})
		if t.get("kind") != COUNTER:continue
		var match: StringName = t.match
		if match == kind or match in tags:out.append(id)
	return out
## The counters a unit type's basic attack falls under (the 불리 mark).
static func basic_counters(trials: Array, type_id: int) -> Array[StringName]:
	var spec: Dictionary = UnitStatTable.spec(type_id, &"basic")
	return counters_for(trials, spec.get("kind", &"physical"), spec.get("tags", []))
