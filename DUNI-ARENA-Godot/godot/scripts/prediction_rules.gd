class_name PredictionRules
extends RefCounted
## spectator.js actual combo pool, count/size odds and team spawn positioning.
const POOLS = [[0,5],[0,2],[0,3],[0,0],[3,5],[1,4],[1,2],[3,4],[2,5],[1,3],[6,4],[6,5],[7,8],[7,5],[8,0],[6,7],[8,8],[9,5],[9,4],[9,6],[9,8],[9,1],[10,5],[10,11],[11,6],[11,8],[10,4],[11,9],[12,5],[12,4],[12,11],[12,0],[13,4],[13,5],[13,0],[13,7],[17,5],[17,4],[17,18],[18,0],[18,5],[18,15],[19,0],[19,18],[19,17],[20,15],[20,4],[20,19],[21,0],[21,5],[21,20],[22,0],[22,1],[22,4],[22,3],[23,4],[23,5],[23,0],[23,22]]
## Team colours for up to five prediction teams (블루, 레드, 그린, 퍼플, 골드).
const TEAM_COLORS: Array[Color] = [Color("88b7ff"), Color("ff947d"), Color("a4db89"), Color("c8a1ff"), Color("ffd27a")]
const MAX_TEAMS: int = 5
const MAX_TEAM_SIZE: int = 6
## 수적 열세 crowds can be larger than an ordinary team.
const MAX_CROWD: int = 9
const MAX_UNITS: int = 30
## Teams are kept within this ratio of total unit cost (strongest / weakest).
const BALANCE: float = 1.15
## Situations, each with its weight: 클래식 (the original two-unit combos), 팀전 (2-3 teams),
## 난전 (4-5 teams), 같은 유닛 팀전 (each team is copies of its own unit), 수적 열세 (high-tier
## units against a larger crowd of low-tier ones) and 개인전 (lone units). Team sizes are random
## (1-6), but every team in a situation has the same number of units except in 수적 열세, and the
## teams' total unit cost is kept within BALANCE so no side is a sure thing.
const SCENARIOS: Array = [[&"classic", 2], [&"teams", 4], [&"brawl", 3], [&"clones", 3], [&"outnumbered", 2], [&"solo", 2]]
static func create(rng: RandomNumberGenerator) -> PredictionState:
	var total: int=0
	for row in SCENARIOS:total+=int(row[1])
	var roll: int=rng.randi_range(1,total);var kind: StringName=&"classic"
	for row in SCENARIOS:
		roll-=int(row[1])
		if roll<=0:kind=row[0];break
	# Keep the fairest of several tries; no two teams may line up the same units (a coin toss).
	var best: Array=[];var best_spread: float=INF
	for attempt in range(40):
		var teams: Array=_teams(kind,rng)
		if kind in [&"teams",&"brawl",&"solo",&"outnumbered"]:_even_out(teams,rng,kind==&"outnumbered")
		if _has_mirror(teams):continue
		var spread: float=spread_of(teams)
		if spread<best_spread:best=teams;best_spread=spread
		if spread<=BALANCE:break
	var state:=PredictionState.new()
	for i in range(best.size()):state.teams.append({"team":i,"types":best[i]})
	return state
static func cost(type: int) -> float:return float(CharacterCatalog.all()[type].base_gold_cost)
static func team_cost(types: Array) -> float:
	var sum: float=0
	for t in types:sum+=cost(t)
	return sum
## Strongest team's total unit cost over the weakest's (1 = perfectly even).
static func spread_of(teams: Array) -> float:
	var costs: Array=teams.map(func(row):return team_cost(row))
	return float(costs.max())/maxf(1,float(costs.min()))
static func _teams(kind: StringName,rng: RandomNumberGenerator) -> Array:
	var all: int=CharacterCatalog.NAMES.size();var out: Array=[]
	match kind:
		&"classic":
			var size: int=2 if rng.randf()<.7 else 3
			for t in range(2 if rng.randf()<.55 else 3):
				var combo: Array=POOLS[rng.randi_range(0,POOLS.size()-1)].duplicate()
				if size==3:combo.append(rng.randi_range(0,all-1))
				out.append(combo)
		&"teams","brawl":
			var size: int=rng.randi_range(1,MAX_TEAM_SIZE)
			for t in range(rng.randi_range(2,3) if kind==&"teams" else rng.randi_range(4,5)):out.append(_random_types(rng,size))
		&"clones":
			# Each team copies its own unit; the units cost about the same.
			var count: int=rng.randi_range(2,5);var size: int=rng.randi_range(2,MAX_TEAM_SIZE)
			var picks: Array=range(all);_shuffle(picks,rng)
			var first: int=picks[0];var chosen: Array=[first]
			for t in picks.slice(1):
				if chosen.size()>=count:break
				if maxf(cost(t),cost(first))/minf(cost(t),cost(first))<=BALANCE:chosen.append(t)
			if chosen.size()<2:chosen.append(picks[1])
			for type in chosen:
				var row: Array=[]
				for i in range(size):row.append(type)
				out.append(row)
		&"outnumbered":
			# A few high-tier units (4-5 tokens) against a larger crowd of 1-2 token units.
			var strong: Array=_tier_types(4,5);var weak: Array=_tier_types(1,2)
			var few: Array=[];var crowd: Array=[]
			for i in range(rng.randi_range(1,4)):few.append(strong[rng.randi_range(0,strong.size()-1)])
			var target: float=team_cost(few)
			while crowd.size()<MAX_CROWD and (crowd.size()<=few.size() or team_cost(crowd)<target*.95):crowd.append(weak[rng.randi_range(0,weak.size()-1)])
			out=[few,crowd] if rng.randf()<.5 else [crowd,few]
		_:
			for t in range(rng.randi_range(3,5)):out.append([rng.randi_range(0,all-1)])
	return out
## Swaps units (same tier band for 수적 열세) so every team's total cost moves toward the average.
static func _even_out(teams: Array,rng: RandomNumberGenerator,keep_tiers: bool) -> void:
	var target: float=0
	for row in teams:target+=team_cost(row)
	target/=teams.size()
	if keep_tiers:target=float(teams.map(func(row):return team_cost(row)).max())
	var all: int=CharacterCatalog.NAMES.size()
	for row in teams:
		var pool: Array=range(all)
		if keep_tiers:pool=_tier_types(4,5) if CharacterCatalog.all()[row[0]].recruit_tokens>=4 else _tier_types(1,2)
		for step in range(40):
			var i: int=rng.randi_range(0,row.size()-1);var swap: int=pool[rng.randi_range(0,pool.size()-1)]
			var now: float=team_cost(row);var after: float=now-cost(row[i])+cost(swap)
			if absf(after-target)<absf(now-target):row[i]=swap
static func _shuffle(list: Array,rng: RandomNumberGenerator) -> void:
	for i in range(list.size()-1,0,-1):
		var j: int=rng.randi_range(0,i);var keep=list[i];list[i]=list[j];list[j]=keep
## True when two teams have exactly the same units (order ignored).
static func _has_mirror(teams: Array) -> bool:
	var seen: Dictionary={}
	for row in teams:
		var key: Array=row.duplicate();key.sort()
		if seen.has(str(key)):return true
		seen[str(key)]=true
	return false
static func _random_types(rng: RandomNumberGenerator,size: int) -> Array:
	var row: Array=[]
	for i in range(size):row.append(rng.randi_range(0,CharacterCatalog.NAMES.size()-1))
	return row
static func _tier_types(low: int,high: int) -> Array:
	var out: Array=[];var catalog: Dictionary=CharacterCatalog.all()
	for type in catalog:
		if catalog[type].recruit_tokens>=low and catalog[type].recruit_tokens<=high:out.append(type)
	return out
## The situation's name, read back from the teams (so saves need no extra field).
static func label(state: PredictionState) -> String:
	var sizes: Array=state.teams.map(func(t):return t.types.size())
	if sizes.max()!=sizes.min():return "수적 열세"
	if sizes.all(func(n):return n==1):return "개인전"
	if state.teams.all(func(t):return t.types.size()>1 and t.types.all(func(x):return x==t.types[0])):return "같은 유닛 팀전"
	if state.teams.size()>=4:return "%d팀 난전"%state.teams.size()
	return "%d팀 대전"%state.teams.size()
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
			result.append({"data":CharacterCatalog.all()[team.types[i]],"team":team.team,"position":at.clamp(Vector2(40,40),Vector2(760,760))})
	return result

static func valid(state: PredictionState) -> bool:
	if state==null or state.teams.size()<2 or state.teams.size()>MAX_TEAMS:return false
	var seen: Dictionary={};var units: int=0
	for team in state.teams:
		if not team is Dictionary or not team.get("team") is int or seen.has(team.team) or team.team<0 or team.team>=MAX_TEAMS or not team.get("types") is Array or team.types.size()<1 or team.types.size()>MAX_CROWD:return false
		units+=team.types.size()
		if units>MAX_UNITS:return false
		if not team.types.all(func(type):return type is int and type>=0 and type<CharacterCatalog.NAMES.size()):return false
		seen[team.team]=true
	return true
