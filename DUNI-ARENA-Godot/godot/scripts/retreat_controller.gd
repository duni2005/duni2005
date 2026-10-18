class_name RetreatController
extends RefCounted
## Entire battle retreat. Not an individual tactical/strategy-card command.
enum Code { OK, NOT_STARTED, FINISHED, TOO_EARLY, NO_ALLIES, NO_ENEMIES, ALREADY_RETREATING, RUN_OVER, NOT_ROOM_BATTLE, CLOCK_LOCKED }
const MIN_TIME: float = 20.0
var processing: bool = false

func check(battle: BattleManager, run: RunState) -> Code:
	if processing:
		return Code.ALREADY_RETREATING
	if battle == null or not battle.started:
		return Code.NOT_STARTED
	if battle.finished:
		return Code.FINISHED
	if run.game_over or run.player_hp <= 0 or battle.run_end_requested:
		return Code.RUN_OVER
	if battle.turning != null and not battle.turning.permits_full_retreat():
		return Code.CLOCK_LOCKED
	if battle.clock.stopped or battle.clock.state in [BattleClock.State.TRANSCENDENCE_AIM,BattleClock.State.TRANSCENDENCE_CAST]:
		return Code.CLOCK_LOCKED
	if battle.room_id.is_empty():
		return Code.NOT_ROOM_BATTLE
	if battle.clock.elapsed < MIN_TIME:
		return Code.TOO_EARLY
	var allies: bool = false
	var enemies: bool = false
	for unit in battle.units:
		if unit.alive and not unit.source_member_id.is_empty():
			allies = true
		if unit.alive and not unit.source_enemy_id.is_empty():
			enemies = true
	if not allies:
		return Code.NO_ALLIES
	if not enemies:
		return Code.NO_ENEMIES
	return Code.OK

func request(battle: BattleManager, run: RunState) -> bool:
	if check(battle, run) != Code.OK:
		return false
	processing = true
	return battle.finish_with_reason(BattleEndReason.Value.RETREAT, -1)
