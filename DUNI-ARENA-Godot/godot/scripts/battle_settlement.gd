class_name BattleSettlement
extends RefCounted
## Run-owned, one-time settlement of an already completed, detached result.
## Legacy apply stays guild-only; room sessions use live death receipts + apply_room.
## Tower room session heals before final snapshots; legacy rooms stay unchanged.

enum Status { APPLIED, ALREADY_SETTLED, INVALID_RESULT, FOREIGN_RUN, INVALID_STATE }

func apply(result: BattleResult, guild: GuildManager) -> Status:
	# Do not let a legacy guild-only call consume a room result's settlement ID.
	if result != null and not result.room_id.is_empty():
		return Status.INVALID_RESULT
	return _apply_members(result, guild)

func _apply_members(result: BattleResult, guild: GuildManager) -> Status:
	if result == null or guild == null or not result.completed or result.battle_result_id.is_empty() or result.participating_member_ids.is_empty():
		return Status.INVALID_RESULT
	if result.source_run_id != guild.state.run_id:
		return Status.FOREIGN_RUN
	if guild.state.settled_battle_ids.has(result.battle_result_id):
		return Status.ALREADY_SETTLED
	var participating: Dictionary = {}
	for member_id in result.participating_member_ids:
		var member: GuildMemberState = guild.get_member(member_id)
		var saved = result.member_states.get(member_id)
		if participating.has(member_id) or not saved is Dictionary or not UnitStateCodec.valid_snapshot(saved, member, guild.definition(member.unit_type_id) if member != null else null, guild.member_max_hp(member) if member != null else -1):
			return Status.INVALID_STATE
		var survived: bool = float(saved.current_hp) > 0.0
		if result.surviving_member_ids.count(member_id) != int(survived) or result.dead_member_ids.count(member_id) != int(not survived):
			return Status.INVALID_STATE
		if result.final_hp_by_member_id.get(member_id) != saved.current_hp:
			return Status.INVALID_STATE
		participating[member_id] = true
	if result.member_states.size() != participating.size() or result.final_hp_by_member_id.size() != participating.size() or result.surviving_member_ids.size() + result.dead_member_ids.size() != participating.size():
		return Status.INVALID_STATE
	# All checks finish before any write. No signals/awaits during this commit.
	guild.state.settled_battle_ids[result.battle_result_id] = true
	for member in guild.all_members():
		if participating.has(member.member_id):
			UnitStateCodec.restore(member, result.member_states[member.member_id])
	return Status.APPLIED

const DEATH_HP_RATE: float = 0.05
const DEFEAT_PENALTY: float = 20.0

func record_member_death(unit: BattleUnit, guild: GuildManager, room: RoomState) -> float:
	# The ONLY death HP subtraction path. Called by the room session's unit_died
	# listener; apply_room validates receipts but does NOT subtract deaths again.
	if unit == null or guild == null or room == null or unit.alive or unit.current_hp != 0 or unit.source_member_id.is_empty():
		return 0.0
	if unit.source_run_id != guild.state.run_id or unit.battle.room_id != room.room_id or unit.battle.battle_result_id != room.active_result_id:
		return 0.0
	var member: GuildMemberState = guild.get_member(unit.source_member_id)
	if member == null or member.unit_type_id != unit.data.type_id or not is_finite(unit.data.base_gold_cost) or unit.data.base_gold_cost < 0:
		return 0.0
	var result_id: String = unit.battle.battle_result_id
	var receipts: Dictionary = guild.state.death_losses_by_result_id.get(result_id, {})
	if receipts.has(member.member_id) or guild.state.settled_battle_ids.has(result_id):
		return 0.0
	var loss: float = unit.data.base_gold_cost * DEATH_HP_RATE
	receipts[member.member_id] = loss
	guild.state.death_losses_by_result_id[result_id] = receipts
	var before: float = guild.state.player_hp
	guild.state.player_hp = maxf(0, before - loss)
	return before - guild.state.player_hp

func apply_room(result: BattleResult, guild: GuildManager, room: RoomState) -> Status:
	if result == null or guild == null or room == null or not result.completed or result.room_id != room.room_id:
		return Status.INVALID_RESULT
	if result.source_run_id != guild.state.run_id:
		return Status.FOREIGN_RUN
	if guild.state.settled_battle_ids.has(result.battle_result_id):
		return Status.ALREADY_SETTLED
	if not CombatPersistence.valid_result(result, guild, room):
		return Status.INVALID_STATE
	var receipts: Dictionary = guild.state.death_losses_by_result_id.get(result.battle_result_id, {})
	if receipts.size() != result.dead_member_ids.size():
		return Status.INVALID_STATE
	for member_id in result.dead_member_ids:
		var member: GuildMemberState = guild.get_member(member_id)
		if member == null or receipts.get(member_id) != guild.definition(member.unit_type_id).base_gold_cost * DEATH_HP_RATE:
			return Status.INVALID_STATE
	# Reason consistency prevents clear/penalty changes via mismatched result flags.
	match result.end_reason:
		BattleEndReason.Value.VICTORY:
			if result.winner_team != 0 or not result.surviving_enemy_ids.is_empty() or result.surviving_member_ids.is_empty():
				return Status.INVALID_STATE
		BattleEndReason.Value.DEFEAT:
			if result.winner_team != 1 or not result.surviving_member_ids.is_empty() or result.surviving_enemy_ids.is_empty():
				return Status.INVALID_STATE
		BattleEndReason.Value.RETREAT:
			if result.elapsed < RetreatController.MIN_TIME or result.surviving_member_ids.is_empty() or result.surviving_enemy_ids.is_empty():
				return Status.INVALID_STATE
		BattleEndReason.Value.DRAW:
			if not result.surviving_member_ids.is_empty() or not result.surviving_enemy_ids.is_empty():
				return Status.INVALID_STATE
		BattleEndReason.Value.RUN_ENDED:
			if guild.state.player_hp > 0:
				return Status.INVALID_STATE
		_:
			return Status.INVALID_STATE
	# Existing apply validates the whole allied batch before committing anything.
	var status: Status = _apply_members(result, guild)
	if status != Status.APPLIED:
		return status
	CombatPersistence.restore(result, room)
	# Web penalty: !won && !retreat && hp > 0. Draw also takes this penalty.
	if result.end_reason not in [BattleEndReason.Value.VICTORY, BattleEndReason.Value.RETREAT] and guild.state.player_hp > 0:
		guild.state.player_hp = maxf(0, guild.state.player_hp - DEFEAT_PENALTY)
	# Web clears an all-dead encounter even on draw, provided player HP remains.
	if guild.state.player_hp > 0 and room.living_enemies().is_empty():
		room.cleared = true
	room.settled_result_ids[result.battle_result_id] = true
	room.active_result_id = ""
	if guild.state.player_hp <= 0:
		guild.state.game_over = true
		guild.state.game_over_reason = RunState.GameOverReason.PLAYER_HP
	elif guild.living_members().is_empty():
		guild.state.game_over = true
		guild.state.game_over_reason = RunState.GameOverReason.NO_LIVING_MEMBERS
	return Status.APPLIED
