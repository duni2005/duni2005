class_name TrialCatalog
extends RefCounted
## 시련: traits of a battle room (일반 전투 · 미니보스 · 보스). Most work on the room's enemies; 환경
## trials work on both sides. At most MAX_TRIALS per room, each trial once.
## Kinds: 카운터 (enemies take COUNTER_TAKEN of one damage kind or tag), 환경, 적 강화, 보상
## (a harder room that pays more), 제약 (fewer options for the player) and 구조물 (objects on the
## field, FieldObjects). Every definition and number is here; TrialEffects runs them in battle,
## TrialArt draws them.
const COUNTER: StringName = &"counter"
const ENVIRONMENT: StringName = &"environment"
const EMPOWER: StringName = &"empower"
const REWARD: StringName = &"reward"
const CONSTRAINT: StringName = &"constraint"
const STRUCTURE: StringName = &"structure"
const KINDS: Array[StringName] = [COUNTER, ENVIRONMENT, EMPOWER, REWARD, CONSTRAINT, STRUCTURE]
const KIND_NAMES = {COUNTER: "카운터", ENVIRONMENT: "환경", EMPOWER: "적 강화", REWARD: "보상", CONSTRAINT: "제약", STRUCTURE: "구조물"}
## Icon rim by kind: 카운터 red, 환경 yellow, 적 강화 purple, 보상 gold, 제약 grey, 구조물 teal.
const KIND_COLORS = {COUNTER: Color("ff5a5a"), ENVIRONMENT: Color("f2e45a"), EMPOWER: Color("b884ff"), REWARD: Color("e8a93a"), CONSTRAINT: Color("a4acb6"), STRUCTURE: Color("3fd6c4")}

const MAX_TRIALS: int = 4
const MAX_COUNTERS: int = 2
## 미니보스 and 챕터 보스 rooms.
const MAX_BOSS_COUNTERS: int = 1
const MAX_REWARDS: int = 1
## 제약 and 구조물: at most one each in a room, from these floors.
const MAX_CONSTRAINTS: int = 1
const MAX_STRUCTURES: int = 1
const CONSTRAINT_FLOOR: int = 4
const STRUCTURE_FLOOR: int = 2
## Kinds with a cap of one per room.
const KIND_CAPS = {REWARD: MAX_REWARDS, CONSTRAINT: MAX_CONSTRAINTS, STRUCTURE: MAX_STRUCTURES}
## Floors (1-based): [first, last, fewest trials, most trials, most counters].
const FLOOR_RULES: Array = [[1, 3, 0, 1, 0], [4, 6, 1, 2, 1], [7, 9, 2, 3, 2], [10, 15, 2, 4, 2]]
## 강인함 (physical) and 해루석 보호막 (magic) appear from this floor and never together.
const BROAD_COUNTER_FLOOR: int = 7
const EXCLUSIVE: Array = [[&"tough", &"seastone"], [&"martyr", &"split"]]

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

## 낙뢰: every LIGHTNING_EVERY s LIGHTNING_STRIKES bolts (radius LIGHTNING_RADIUS) after a
## LIGHTNING_WARN s warning; LIGHTNING_NEAR of them land within LIGHTNING_SPREAD of a random unit.
## A hit: 시련 피해 LIGHTNING_BASE + LIGHTNING_PER_FLOOR × floor and LIGHTNING_SHOCK 감전 stacks.
const LIGHTNING_EVERY: float = 10.0
const LIGHTNING_WARN: float = 1.2
const LIGHTNING_STRIKES: int = 3
const LIGHTNING_NEAR: int = 2
const LIGHTNING_SPREAD: float = 80.0
const LIGHTNING_RADIUS: float = 70.0
const LIGHTNING_BASE: float = 15.0
const LIGHTNING_PER_FLOOR: float = 8.0
const LIGHTNING_SHOCK: int = 2
## 순교자: a fallen enemy's circle shrinks for MARTYR_FUSE s, then blasts the player's side within
## MARTYR_RADIUS for MARTYR_HP of its max HP (MARTYR_SPLIT_FACTOR of that for the last of a split
## family) and a MARTYR_PUSH knockback.
const MARTYR_FUSE: float = 1.0
const MARTYR_RADIUS: float = 120.0
const MARTYR_HP: float = .2
const MARTYR_SPLIT_FACTOR: float = .5
const MARTYR_PUSH: float = 320.0
## 도망칠 길은 없다: the strategy cards that pull a unit out of the fight cannot be used.
const RETREAT_CARDS: Array[StringName] = [&"evade"]
## 좁은 방: one sortie place fewer (never below NARROW_MIN); dormant while the room's limit is at
## most NARROW_FROM_LIMIT - 1 (no 출정 확장 yet).
const NARROW_CUT: int = 1
const NARROW_MIN: int = 1
const NARROW_FROM_LIMIT: int = 4

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
	&"meteor": {"name": "소행성", "kind": ENVIRONMENT, "icon": "trial_meteor", "short": "10초마다 운석 낙하 · 모두에게 피해", "text": "10초마다 무작위 위치(반경 110)에 운석이 떨어집니다. 1.5초 전 노란 원으로 예고하고, 아군 · 적 모두에게 큰 범위 피해(20 + 10 × 층)를 줍니다."},
	&"fog": {"name": "짙은 안개", "kind": ENVIRONMENT, "icon": "trial_fog", "weather": true, "short": "모든 유닛 사거리 -30%", "text": "짙은 안개로 모든 유닛의 사거리가 30% 줄어듭니다(최소 60)."},
	&"quake": {"name": "지진", "kind": ENVIRONMENT, "icon": "trial_quake", "short": "15초마다 모두 0.6초 넘어짐", "text": "15초마다 땅이 흔들려 모든 유닛이 0.6초 동안 넘어집니다(행동 불가). 1초 전 화면이 흔들리며 예고합니다."},
	&"regen": {"name": "끈질긴 생명", "kind": EMPOWER, "icon": "vital", "short": "적이 매초 최대 HP 1% 회복", "text": "적이 매초 최대 HP의 1%를 회복합니다."},
	&"berserkers": {"name": "광전사들", "kind": EMPOWER, "icon": "berserkerHelm", "short": "HP 30% 이하 적 공격속도 +50%", "text": "적은 HP 30% 이하가 되면 공격속도 +50%, 이동속도 +20%."},
	&"elite_squad": {"name": "정예 부대", "kind": EMPOWER, "icon": "knightCrest", "short": "가장 비싼 적 1명이 엘리트", "text": "가장 비싼 일반 적 1명이 엘리트가 됩니다(엘리트 배율 적용)."},
	&"vengeance": {"name": "복수심", "kind": EMPOWER, "icon": "vengeanceMask", "short": "적이 쓰러지면 주변 적 공격력 +10%", "text": "적이 쓰러질 때마다 반경 200 안의 적 공격력 +10% (최대 5중첩, 전투 동안)."},
	&"vanguard": {"name": "선봉대", "kind": EMPOWER, "icon": "chargeHorn", "short": "시작 3초 적 돌진 · 이동속도 +60%", "text": "전투 시작 후 3초간 적 전원 이동속도 +60%, 아군 쪽으로 돌진합니다."},
	&"sniper": {"name": "저격 지원", "kind": EMPOWER, "icon": "sniperScope", "short": "12초마다 HP 높은 아군 저격", "text": "12초마다 맵 밖에서 HP가 가장 높은 아군을 저격합니다. 1.2초 동안 붉은 조준선으로 예고하고 물리 피해(25 + 12 × 층)를 줍니다."},
	&"lightning": {"name": "낙뢰", "kind": ENVIRONMENT, "icon": "trial_lightning", "short": "10초마다 낙뢰 3곳 · 모두에게 피해", "text": "번개 조심하세요! 10초마다 무작위 위치 3곳(반경 70)에 번개가 칩니다. 1.2초 전 노란 원으로 예고하고, 맞은 유닛(아군 · 적)은 시련 피해(15 + 8 × 층)와 감전 2스택을 받습니다."},
	&"martyr": {"name": "순교자", "kind": EMPOWER, "icon": "trial_martyr", "short": "쓰러진 적이 1초 뒤 폭발", "text": "그들의 죽음은 헛되지 않았습니다. 적이 쓰러지면 그 자리(반경 120)가 1초 뒤 폭발해 아군에게 쓰러진 적 최대 HP 20%의 시련 피해를 주고 밀쳐 냅니다."},
	&"split": {"name": "분열", "kind": EMPOWER, "icon": "trial_split", "short": "적이 처음 쓰러지면 2명으로 분열", "text": "적이 처음 사망 시 분열하여 2명으로 나눠집니다(각 HP 25% · 피해 30% · 몸집 80%, 다시 나뉘지 않고 궁극기 불가). 챕터 보스는 나뉘지 않습니다."},
	&"no_escape": {"name": "도망칠 길은 없다", "kind": CONSTRAINT, "icon": "trial_no_escape", "short": "후퇴 불가", "text": "후퇴할 수 없습니다. 후퇴 효과가 있는 전략카드(전투 회피)도 쓸 수 없습니다."},
	&"narrow_room": {"name": "좁은 방", "kind": CONSTRAINT, "icon": "trial_narrow", "short": "출정 인원 -1", "text": "출정 인원 -1 (최소 1명). 출정 확장을 하기 전에는 나오지 않습니다."},
	&"warm_statue": {"name": "온기의 동상", "kind": STRUCTURE, "icon": "trial_statue", "short": "중앙의 동상이 주변을 회복", "text": "필드 중앙에 온기의 동상이 배치됩니다. 온기의 동상은 매초마다 가까운(반경 150) 유닛의 HP 2%를 회복시킵니다. 유닛은 지나갈 수 없고 투사체는 지나갑니다."},
	&"powder_kegs": {"name": "화약통", "kind": STRUCTURE, "icon": "trial_keg", "short": "맞으면 터지는 화약통 5개", "text": "필드 곳곳에 화약통이 배치됩니다. 화약통은 피해를 받으면 0.4초 뒤 크게 폭발합니다(반경 110, 시련 피해 25 + 12 × 층, 화염 2스택, 넉백). 근처 화약통도 연쇄 폭발합니다."},
	&"gold_convoy": {"name": "금괴 운반대", "kind": REWARD, "icon": "goldToken", "short": "적 이동 +20% · 골드 대폭 증가", "text": "적 이동속도 +20%. 대신 적 처치 골드 2배, 승리 골드 +30%."},
	&"treasure_guard": {"name": "보물 수호자", "kind": REWARD, "icon": "supply", "short": "적 HP +25% · 보상 선택지 +1", "text": "적 HP +25%. 대신 승리 보상 아이템 선택지가 하나 늘어납니다(3 → 4)."},
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
## First floor (1-based) a trial can appear on: 카운터 from 4 (강인함 · 해루석 보호막 from 7),
## 제약 from 4, 구조물 from 2, the rest from 1.
static func first_floor(id: StringName) -> int:
	match kind_of(id):
		COUNTER:return int(TRIALS[id].get("from", FLOOR_RULES[1][0]))
		CONSTRAINT:return CONSTRAINT_FLOOR
		STRUCTURE:return STRUCTURE_FLOOR
	return 1
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
	if KIND_CAPS.has(kind) and chosen.filter(func(t):return kind_of(t) == kind).size() >= int(KIND_CAPS[kind]):return false
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

## The enemy 정예 부대 promoted in a tower room ("" when none): the room's own elites (a boss
## room's boss and elite, a miniboss room's elite) lead its list, so it is the first elite after them.
static func trial_elite_id(room) -> String:
	if room == null or not &"elite_squad" in room.trials or room.encounter == null:return ""
	var own: int = 2 if room.room_type == RoomType.BOSS else 1 if room.room_type == RoomType.MINIBOSS else 0
	for i in range(own, room.encounter.enemies.size()):
		if room.encounter.enemies[i].rank == &"elite":return room.encounter.enemies[i].enemy_id
	return ""

## The trials of `room` in force for `run`: 좁은 방 sleeps while the sortie limit is below
## NARROW_FROM_LIMIT.
static func active(room, run) -> Array[StringName]:
	var out: Array[StringName] = []
	if room == null:return out
	for id in room.trials:
		if id == &"narrow_room" and run != null and GrowthRules.sortie_limit(run) < NARROW_FROM_LIMIT:continue
		out.append(id)
	return out
## The sortie limit with `trials` (좁은 방).
static func sortie_limit(base: int, trials: Array) -> int:
	return maxi(NARROW_MIN, base - NARROW_CUT) if &"narrow_room" in trials and base >= NARROW_FROM_LIMIT else base

## One short line for the entry band: what the trial does.
static func short_of(id: StringName) -> String:
	var info: Dictionary = TRIALS.get(id, {})
	if info.get("kind") == COUNTER:return "적이 받는 %s 피해 -60%%" % MATCH_NAMES.get(info.get("match"), "")
	return str(info.get("short", ""))
const MATCH_NAMES = {&"projectile": "투사체", &"magic": "마법", &"physical": "물리", &"dark": "어둠", &"light": "빛", &"poison": "맹독", &"lightning": "번개", &"ice": "얼음", &"fire": "화염", &"wind": "바람", &"explosion": "폭발", &"melee": "근접공격", &"area": "범위", &"dot": "지속"}
## 위험 예고: red when only the player's side is in danger, yellow when everyone is.
const HAZARD_ALLY := Color("ff3a3a")
const HAZARD_ALL := Color("ffd23a")

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
