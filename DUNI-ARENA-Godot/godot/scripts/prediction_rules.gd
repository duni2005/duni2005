class_name PredictionRules
extends RefCounted
## spectator.js actual combo pool, count/size odds and team spawn positioning.
const POOLS = [[0,5],[0,2],[0,3],[0,0],[3,5],[1,4],[1,2],[3,4],[2,5],[1,3],[6,4],[6,5],[7,8],[7,5],[8,0],[6,7],[8,8],[9,5],[9,4],[9,6],[9,8],[9,1],[10,5],[10,11],[11,6],[11,8],[10,4],[11,9],[12,5],[12,4],[12,11],[12,0],[13,4],[13,5],[13,0],[13,7],[17,5],[17,4],[17,18],[18,0],[18,5],[18,15],[19,0],[19,18],[19,17],[20,15],[20,4],[20,19],[21,0],[21,5],[21,20],[22,0],[22,1],[22,4],[22,3],[23,4],[23,5],[23,0],[23,22]]
static func create(rng: RandomNumberGenerator) -> PredictionState:
	var state:=PredictionState.new();var count: int=2 if rng.randf()<.55 else 3;var size: int=2 if rng.randf()<.7 else 3
	for team in range(count):
		var combo: Array=POOLS[rng.randi_range(0,POOLS.size()-1)].duplicate()
		if size==3:combo.append(rng.randi_range(0,25))
		state.teams.append({"team":team,"types":combo})
	return state
static func placements(state: PredictionState,rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var rotation: float=rng.randf_range(0,TAU)
	for team in state.teams:
		for type in team.types:
			var angle: float=rotation+team.team*PI/2
			var at:=Vector2(400+cos(angle)*225+rng.randf_range(-90,90),400+sin(angle)*225+rng.randf_range(-90,90)).clamp(Vector2(40,40),Vector2(760,760))
			result.append({"data":CharacterCatalog.all()[type],"team":team.team,"position":at})
	return result

static func valid(state: PredictionState) -> bool:
	if state==null or state.teams.size() not in [2,3]:return false
	var seen: Dictionary={}
	for team in state.teams:
		if not team is Dictionary or not team.get("team") is int or seen.has(team.team) or not team.get("types") is Array or team.types.size() not in [2,3]:return false
		if not team.types.all(func(type):return type is int and type>=0 and type<CharacterCatalog.NAMES.size()):return false
		seen[team.team]=true
	return true
