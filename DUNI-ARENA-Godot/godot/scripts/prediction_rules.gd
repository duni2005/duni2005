class_name PredictionRules
extends RefCounted
## spectator.js actual combo pool, count/size odds and team spawn positioning.
const POOLS = [[0,5],[0,2],[0,3],[0,0],[3,5],[1,4],[1,2],[3,4],[2,5],[1,3],[6,4],[6,5],[7,8],[7,5],[8,0],[6,7],[8,8],[9,5],[9,4],[9,6],[9,8],[9,1],[10,5],[10,11],[11,6],[11,8],[10,4],[11,9],[12,5],[12,4],[12,11],[12,0],[13,4],[13,5],[13,0],[13,7],[17,5],[17,4],[17,18],[18,0],[18,5],[18,15],[19,0],[19,18],[19,17],[20,15],[20,4],[20,19],[21,0],[21,5],[21,20],[22,0],[22,1],[22,4],[22,3],[23,4],[23,5],[23,0],[23,22]]
## Team colours for up to five prediction teams (블루, 레드, 그린, 퍼플, 골드).
const TEAM_COLORS: Array[Color] = [Color("88b7ff"), Color("ff947d"), Color("a4db89"), Color("c8a1ff"), Color("ffd27a")]
const MAX_TEAMS: int = 5
const MAX_UNITS: int = 12
## Situations, each with its weight: 클래식 (the original two-unit combos), 팀전 (2-3 mixed teams
## of 1-4), 난전 (4-5 teams), 같은 유닛 팀전 (every team is copies of one unit), 수적 열세 (a few
## high-tier units against a crowd of low-tier ones) and 개인전 (4-5 lone units).
const SCENARIOS: Array = [[&"classic", 3], [&"teams", 4], [&"brawl", 2], [&"clones", 3], [&"outnumbered", 2], [&"solo", 2]]
static func create(rng: RandomNumberGenerator) -> PredictionState:
	var total: int=0
	for row in SCENARIOS:total+=int(row[1])
	var roll: int=rng.randi_range(1,total);var kind: StringName=&"classic"
	for row in SCENARIOS:
		roll-=int(row[1])
		if roll<=0:kind=row[0];break
	# No two teams may line up the same units: a mirror match would be a coin toss.
	var teams: Array=_teams(kind,rng)
	for attempt in range(20):
		if not _has_mirror(teams):break
		teams=_teams(kind,rng)
	var state:=PredictionState.new()
	for i in range(teams.size()):state.teams.append({"team":i,"types":teams[i]})
	return state
static func _teams(kind: StringName,rng: RandomNumberGenerator) -> Array:
	var all: int=CharacterCatalog.NAMES.size();var out: Array=[]
	match kind:
		&"classic":
			var size: int=2 if rng.randf()<.7 else 3
			for t in range(2 if rng.randf()<.55 else 3):
				var combo: Array=POOLS[rng.randi_range(0,POOLS.size()-1)].duplicate()
				if size==3:combo.append(rng.randi_range(0,all-1))
				out.append(combo)
		&"teams":
			var size: int=rng.randi_range(1,4)
			for t in range(rng.randi_range(2,3)):out.append(_random_types(rng,size if rng.randf()<.7 else rng.randi_range(1,4)))
		&"brawl":
			var count: int=rng.randi_range(4,5)
			for t in range(count):out.append(_random_types(rng,rng.randi_range(1,2 if count==5 else 3)))
		&"clones":
			var count: int=rng.randi_range(2,4);var size: int=rng.randi_range(2,4 if count<=3 else 3)
			# Every team clones a different unit.
			var picks: Array=range(all);_shuffle(picks,rng)
			for t in range(count):
				var row: Array=[]
				for i in range(size):row.append(picks[t])
				out.append(row)
		&"outnumbered":
			var strong: Array=_tier_types(4,5);var weak: Array=_tier_types(1,2)
			var few: Array=[];var crowd: Array=[]
			for i in range(rng.randi_range(1,2)):few.append(strong[rng.randi_range(0,strong.size()-1)])
			for i in range(rng.randi_range(3,5)):crowd.append(weak[rng.randi_range(0,weak.size()-1)])
			out=[few,crowd] if rng.randf()<.5 else [crowd,few]
		_:
			for t in range(rng.randi_range(4,5)):out.append([rng.randi_range(0,all-1)])
	return out
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
	if sizes.all(func(n):return n==1):return "개인전"
	if state.teams.all(func(t):return t.types.size()>1 and t.types.all(func(x):return x==t.types[0])):return "같은 유닛 팀전"
	if state.teams.size()>=4:return "%d팀 난전"%state.teams.size()
	if sizes.max()>=sizes.min()*2+1:return "수적 열세"
	return "%d팀 대전"%state.teams.size()
static func team_color(team: int) -> Color:return TEAM_COLORS[team%TEAM_COLORS.size()]
## Teams start spread evenly around the field; bigger teams stand in a loose cluster.
static func placements(state: PredictionState,rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var rotation: float=rng.randf_range(0,TAU);var count: int=state.teams.size()
	var reach: float=225 if count<=3 else 260
	for team in state.teams:
		var angle: float=rotation+team.team*TAU/count if count>2 else rotation+team.team*PI
		var home:=Vector2(400+cos(angle)*reach,400+sin(angle)*reach)
		for i in range(team.types.size()):
			var at: Vector2=home+Vector2.from_angle(angle+PI*.5)*(i-(team.types.size()-1)*.5)*62+Vector2(rng.randf_range(-24,24),rng.randf_range(-24,24))
			result.append({"data":CharacterCatalog.all()[team.types[i]],"team":team.team,"position":at.clamp(Vector2(40,40),Vector2(760,760))})
	return result

static func valid(state: PredictionState) -> bool:
	if state==null or state.teams.size()<2 or state.teams.size()>MAX_TEAMS:return false
	var seen: Dictionary={};var units: int=0
	for team in state.teams:
		if not team is Dictionary or not team.get("team") is int or seen.has(team.team) or team.team<0 or team.team>=MAX_TEAMS or not team.get("types") is Array or team.types.size()<1 or team.types.size()>5:return false
		units+=team.types.size()
		if units>MAX_UNITS+2:return false
		if not team.types.all(func(type):return type is int and type>=0 and type<CharacterCatalog.NAMES.size()):return false
		seen[team.team]=true
	return true
