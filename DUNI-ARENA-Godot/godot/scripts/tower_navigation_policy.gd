class_name TowerNavigationPolicy
extends RefCounted
## Cleared combat rooms are viewable, but cannot spawn another battle.
enum Code { OK, INVALID_ROOM, LOCKED_FLOOR, GAME_OVER, UNFINISHED_BATTLE, EVENT_IN_PROGRESS }
static func check(run: RunState, id: String) -> Code:
	if run.tower == null or run.tower.map.get_room(id) == null: return Code.INVALID_ROOM
	if run.game_over: return Code.GAME_OVER
	if run.tower.phase in [&"deploy", &"battle"]: return Code.UNFINISHED_BATTLE
	if run.tower.phase == &"event_active": return Code.EVENT_IN_PROGRESS
	if run.tower.phase != &"route": return Code.UNFINISHED_BATTLE
	if run.tower.map.get_room(id).floor_index > run.tower.unlocked_floor: return Code.LOCKED_FLOOR
	# Floors the party has climbed past stay behind for good.
	if run.tower.map.get_room(id).floor_index < run.strategy_progress.current_depth: return Code.LOCKED_FLOOR
	return Code.OK
static func can_return(run: RunState) -> bool:
	return run.tower != null and run.tower.phase not in [&"deploy", &"battle", &"event_active"]
