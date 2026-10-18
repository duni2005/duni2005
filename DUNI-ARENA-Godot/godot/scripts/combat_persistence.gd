class_name CombatPersistence
extends RefCounted
## Room identity validation and detached enemy snapshot batches.
static func placements(room: RoomState, guild: GuildManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in room.enemy_state.values():
		if not EnemyStateCodec.valid(enemy, guild.definition(enemy.unit_type_id)):
			return []
	for enemy in room.living_enemies():
		var entry: Dictionary = EnemyStateCodec.placement(enemy, guild.definition(enemy.unit_type_id), room.room_id)
		if entry.is_empty():
			return [] # never partially spawn a malformed encounter
		result.append(entry)
	return result

static func valid_result(result: BattleResult, guild: GuildManager, room: RoomState) -> bool:
	if room == null or room.source_run_id != guild.state.run_id or result.room_id != room.room_id or room.active_result_id != result.battle_result_id or room.cleared:
		return false
	var seen: Dictionary = {}
	for enemy_id in result.enemy_states:
		var enemy: EnemyRoomState = room.enemy_state.get(enemy_id)
		var saved = result.enemy_states[enemy_id]
		if not saved is Dictionary or not EnemyStateCodec.valid_snapshot(saved, enemy, guild.definition(enemy.unit_type_id) if enemy != null else null):
			return false
		# Previously dead enemies cannot be resurrected by a stale result.
		if not enemy.alive:
			return false
		var survived: bool = saved.alive
		if result.surviving_enemy_ids.count(enemy_id) != int(survived) or result.dead_enemy_ids.count(enemy_id) != int(not survived):
			return false
		seen[enemy_id] = true
	for enemy in room.living_enemies():
		if not seen.has(enemy.enemy_id):
			return false
	return not seen.is_empty() and result.surviving_enemy_ids.size() + result.dead_enemy_ids.size() == seen.size()

static func restore(result: BattleResult, room: RoomState) -> void:
	for enemy_id in result.enemy_states:
		EnemyStateCodec.restore(room.enemy_state[enemy_id], result.enemy_states[enemy_id])
