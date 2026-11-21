class_name PredictionRules
extends RefCounted
## 전투 예측 situations (0.99.14), built from 전투력 (combat power):
## 1. the number of teams (2-6);
## 2. the average power of a team (MIN_POWER-MAX_POWER);
## 3. each team is built up to that power from units and their items (up to MAX_UNIT_ITEMS each),
##    so a lone hero with two rare items (10) can face three common units (10.5).
## A unit's power is UNIT_POWER by its rarity plus ITEM_POWER by the grade of each item it holds.
## Every team ends within POWER_TOLERANCE of the average, so no side is a sure thing.
## Team colours for up to six prediction teams (블루, 레드, 그린, 퍼플, 골드, 청록).
const TEAM_COLORS: Array[Color] = [Color("88b7ff"), Color("ff947d"), Color("a4db89"), Color("c8a1ff"), Color("ffd27a"), Color("7fe0d8")]
const MIN_TEAMS: int = 2
const MAX_TEAMS: int = 6
## Units in one team and in the whole battle.
const MAX_CROWD: int = 9
const MAX_UNITS: int = 30
const MAX_UNIT_ITEMS: int = 4
const MIN_POWER: float = 3.5
const MAX_POWER: float = 90.0
## 전투력 by unit rarity (UnitRarity.tier: 일반 · 고급 · 희귀 · 영웅 · 전설).
const UNIT_POWER: Array[float] = [0.0, 3.5, 4.5, 6.0, 8.0, 10.0]
## 전투력 by item grade.
const ITEM_POWER = {&"common": .5, &"rare": 1.0, &"epic": 2.0, &"legendary": 3.5, &"ancient": 4.0}
## Teams end within this much of the average power (at least half a point).
static func power_tolerance(average: float) -> float:return maxf(.5, average * .03)

static func create(rng: RandomNumberGenerator) -> PredictionState:
	var count: int = rng.randi_range(MIN_TEAMS, MAX_TEAMS)
	var per_team: int = mini(MAX_CROWD, MAX_UNITS / count)
	var average: float = minf(snappedf(rng.randf_range(MIN_POWER, MAX_POWER), .5), per_team * max_unit_power())
	var teams: Array = []
	for t in range(count):
		var best: Dictionary = {};var best_gap: float = INF
		for attempt in range(40):
			var team: Dictionary = _build_team(average, per_team, rng)
			var gap: float = absf(team_power(team) - average)
			if _repeats(teams, team):continue
			if gap < best_gap:best = team;best_gap = gap
			if gap <= power_tolerance(average):break
		teams.append(best)
	var state := PredictionState.new()
	for i in range(teams.size()):state.teams.append({"team": i, "types": teams[i].types, "items": teams[i].items})
	return state

## 전투력 of one unit with its items.
static func unit_power(type: int, items: Array = []) -> float:
	var sum: float = UNIT_POWER[clampi(UnitRarity.tier(type), 1, 5)]
	for kind in items:sum += item_power(StringName(kind))
	return sum
static func item_power(kind: StringName) -> float:return float(ITEM_POWER.get(ItemCatalog.grade_of(kind), 0.0))
## 전투력 of a team ({"types", "items"}; items optional).
static func team_power(team: Dictionary) -> float:
	var sum: float = 0;var items: Array = team.get("items", [])
	for i in range(team.types.size()):sum += unit_power(team.types[i], items[i] if i < items.size() else [])
	return sum
## The most a single unit can carry (a 전설 unit, one 고대 item and the rest 전설).
static func max_unit_power() -> float:
	return UNIT_POWER[5] + ITEM_POWER[&"ancient"] * ItemTuning.ANCIENT_PER_UNIT + ITEM_POWER[&"legendary"] * (MAX_UNIT_ITEMS - ItemTuning.ANCIENT_PER_UNIT)

## One team of about `target` power: a random unit count that can reach it, then each unit takes
## its share of what is left (a rarity that fits, then items to make up the rest).
static func _build_team(target: float, max_units: int, rng: RandomNumberGenerator) -> Dictionary:
	var fewest: int = maxi(1, ceili(target / max_unit_power()));var most: int = maxi(fewest, mini(max_units, floori(target / UNIT_POWER[1])))
	var n: int = rng.randi_range(fewest, most)
	var types: Array = [];var items: Array = [];var left: float = target
	for i in range(n):
		var share: float = left / (n - i)
		var unit: Dictionary = _build_unit(share, rng)
		types.append(unit.type);items.append(unit.items);left -= unit_power(unit.type, unit.items)
	return {"types": types, "items": items}
## A unit of about `share` power: the rarity first (any that leaves a remainder its items can
## cover), then items, largest grades the rest still allows.
static func _build_unit(share: float, rng: RandomNumberGenerator) -> Dictionary:
	var carry: float = max_unit_power() - UNIT_POWER[5]
	var tiers: Array = []
	for tier in range(1, 6):
		if UNIT_POWER[tier] <= share + .25 and share - UNIT_POWER[tier] <= carry:tiers.append(tier)
	if tiers.is_empty():tiers.append(5 if share > UNIT_POWER[5] else 1)
	var tier: int = tiers[rng.randi_range(0, tiers.size() - 1)]
	var pool: Array = types_of_tier(tier)
	var type: int = pool[rng.randi_range(0, pool.size() - 1)]
	var items: Array = [];var rest: float = share - UNIT_POWER[tier]
	while rest >= .5 - .001 and items.size() < MAX_UNIT_ITEMS:
		var slots: int = MAX_UNIT_ITEMS - items.size()
		var grades: Array = []
		for grade in ITEM_POWER:
			var p: float = ITEM_POWER[grade]
			if p > rest + .25:continue
			if grade == &"ancient" and items.filter(func(k):return ItemCatalog.grade_of(StringName(k)) == &"ancient").size() >= ItemTuning.ANCIENT_PER_UNIT:continue
			# What is left after this one must still fit the remaining slots.
			if rest - p > (slots - 1) * ITEM_POWER[&"legendary"] + .001:continue
			grades.append(grade)
		if grades.is_empty():break
		var grade: StringName = grades[rng.randi_range(0, grades.size() - 1)]
		var choices: Array = item_pool(grade).filter(func(k):return not String(k) in items)
		if choices.is_empty():break
		items.append(String(choices[rng.randi_range(0, choices.size() - 1)]));rest -= ITEM_POWER[grade]
	return {"type": type, "items": items}
## Units of a rarity the mode may use (test characters excluded).
static func types_of_tier(tier: int) -> Array:
	return CharacterCatalog.playable().filter(func(t):return UnitRarity.tier(t) == tier)
## Items of a grade that work in a battle of their own (no consumables, run-economy or cost items).
static func item_pool(grade: StringName) -> Array:
	var skip: Array = EnemyItems.excluded()
	return ItemCatalog.POOLS.get(grade, []).filter(func(k):return not k in skip and ItemCatalog.get_item(k) != null)
## True when `team` lines up the same units and items as one already made (a coin toss).
static func _repeats(teams: Array, team: Dictionary) -> bool:
	var key: String = _key(team)
	return teams.any(func(t):return _key(t) == key)
static func _key(team: Dictionary) -> String:
	var rows: Array = []
	for i in range(team.types.size()):
		var items: Array = (team.items[i] if i < team.get("items", []).size() else []).duplicate();items.sort()
		rows.append(str(team.types[i]) + ":" + ",".join(items))
	rows.sort()
	return "|".join(rows)
## The situation's name, read back from the teams: 개인전 (lone units), N팀 대전 / N팀 난전 (4+
## teams), and · 수적 열세 when one team has at least twice as many units as another.
static func label(state: PredictionState) -> String:
	var sizes: Array=state.teams.map(func(t):return t.types.size())
	if sizes.all(func(n):return n==1):return "%d인 개인전"%state.teams.size()
	var name: String="%d팀 난전"%state.teams.size() if state.teams.size()>=4 else "%d팀 대전"%state.teams.size()
	return name+(" · 수적 열세" if int(sizes.max())>=2*int(sizes.min()) else "")
static func team_color(team: int) -> Color:return TEAM_COLORS[team%TEAM_COLORS.size()]
## 사각 정원 size for this prediction: more units, a bigger field.
static func map_for(state: PredictionState) -> int:
	var n: int=0
	for team in state.teams:n+=team.types.size()
	return ArenaMap.for_units(n)
## Teams start spread evenly around the field, each in a cluster of rows of up to three units
## (rows stack outward, away from the centre).
static func placements(state: PredictionState,rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var rotation: float=rng.randf_range(0,TAU);var count: int=state.teams.size()
	var reach: float=225 if count<=3 else 250
	for team in state.teams:
		var angle: float=rotation+team.team*TAU/count if count>2 else rotation+team.team*PI
		var out:=Vector2.from_angle(angle);var side: Vector2=out.orthogonal();var home: Vector2=Vector2(400,400)+out*reach
		var n: int=team.types.size();var per_row: int=mini(3,n) if n<=6 else 4
		for i in range(n):
			var row: int=i/per_row;var in_row: int=mini(per_row,n-row*per_row)
			var at: Vector2=home+side*(i%per_row-(in_row-1)*.5)*58+out*row*52+Vector2(rng.randf_range(-14,14),rng.randf_range(-14,14))
			var row_items: Array=team.get("items",[])[i] if i<team.get("items",[]).size() else []
			var placement: Dictionary={"data":CharacterCatalog.all()[team.types[i]],"team":team.team,"position":at.clamp(Vector2(40,40),Vector2(760,760))}
			if not row_items.is_empty():placement["combat_stats"]=stats_for(team.types[i],row_items)
			result.append(placement)
	return result
## Level 0 stats of a unit with its items (the custom battle rules).
static func stats_for(type: int,items: Array) -> UnitCombatStats:
	var stats:=UnitCombatStats.from_table(CharacterCatalog.all()[type])
	for kind in items:
		var item: ItemData=ItemCatalog.get_item(StringName(kind))
		if item!=null:stats.apply_item(item)
	stats.finish_items()
	stats.max_hp=floorf(stats.max_hp+.5)
	stats.equipment_attack_without_growth=stats.attack
	return stats

static func valid(state: PredictionState) -> bool:
	if state==null or state.teams.size()<2 or state.teams.size()>MAX_TEAMS:return false
	var seen: Dictionary={};var units: int=0
	for team in state.teams:
		if not team is Dictionary or not team.get("team") is int or seen.has(team.team) or team.team<0 or team.team>=MAX_TEAMS or not team.get("types") is Array or team.types.size()<1 or team.types.size()>MAX_CROWD:return false
		units+=team.types.size()
		if units>MAX_UNITS:return false
		if not team.types.all(func(type):return type is int and type>=0 and type<CharacterCatalog.NAMES.size()):return false
		# Items (from 0.99.14; older saves have none): one list per unit, up to MAX_UNIT_ITEMS kinds.
		if team.has("items"):
			if not team.items is Array or team.items.size()!=team.types.size():return false
			for row in team.items:
				if not row is Array or row.size()>MAX_UNIT_ITEMS:return false
				for kind in row:
					if not (kind is String or kind is StringName) or ItemCatalog.get_item(StringName(kind))==null:return false
		seen[team.team]=true
	return true
