class_name RoomBattleSession
extends RefCounted
## Run/room orchestration. UI and placement never own live death losses.
signal settled(result: BattleResult, status: BattleSettlement.Status)
var guild: GuildManager
var room: RoomState
var battle: BattleManager
var retreat := RetreatController.new()
var settlement := BattleSettlement.new()
var settlement_status: BattleSettlement.Status = BattleSettlement.Status.INVALID_RESULT

func _init(manager: GuildManager, encounter: RoomState) -> void:
	guild = manager
	room = encounter
	if room != null and room.source_run_id.is_empty():
		room.source_run_id = guild.state.run_id

func can_enter() -> bool:
	return room != null and room.source_run_id == guild.state.run_id and not room.cleared and room.active_result_id.is_empty() and not guild.state.game_over and guild.state.player_hp > 0 and not guild.living_members().is_empty() and not room.living_enemies().is_empty()

func start(plan: DeploymentPlan, manager: BattleManager, seed_value: int = -1) -> bool:
	if not can_enter() or plan == null or plan.guild != guild or manager == null or manager.started:
		return false
	var enemies: Array[Dictionary] = CombatPersistence.placements(room, guild)
	if enemies.is_empty():
		return false
	battle = manager
	battle.room_id = room.room_id
	battle.unit_died.connect(_on_death)
	battle.battle_finished.connect(_on_finished)
	battle.battle_finalizing.connect(_on_finalizing)
	if not plan.launch(battle, enemies, seed_value):
		battle.unit_died.disconnect(_on_death)
		battle.battle_finished.disconnect(_on_finished)
		battle.battle_finalizing.disconnect(_on_finalizing)
		battle.room_id = ""
		battle = null
		return false
	room.battle_attempt_count += 1
	room.active_result_id = battle.battle_result_id
	# Web launchOpeningEquipment skips every retry of an already-started room.
	if room.battle_attempt_count == 1 and room.floor_index >= 0: EquipmentCombatEffects.launch_opening(battle)
	battle.enable_turning_points(guild)
	return true

func _on_death(unit: BattleUnit, _source) -> void:
	# One owner for death loss: this event path, never the final dead list.
	settlement.record_member_death(unit, guild, room)
	if room.floor_index >= 0 and not unit.source_enemy_id.is_empty() and not unit.alive and not room.kill_rewards.has(unit.source_enemy_id):
		var enemy: EnemyRoomState = room.enemy_state.get(unit.source_enemy_id)
		if enemy != null and enemy.spawn != null:
			var factor: float = unit.data.recruit_tokens / 2.0 * (1 + enemy.spawn.level * .12)
			var reward: Dictionary = {"gold": floori((10 + battle.rng.randi_range(0,30)) * factor + .5), "tokens": int(battle.rng.randf() < minf(.25,.03*factor))}
			room.kill_rewards[unit.source_enemy_id] = reward
			guild.state.gold += reward.gold; guild.state.tokens += reward.tokens
	if guild.state.player_hp <= 0:
		battle.run_end_requested = true

func _on_finalizing(reason: BattleEndReason.Value) -> void:
	# Web settleTowerBattle heals surviving tower allies before snapshotTowerMember.
	# Standalone Phase4 rooms intentionally keep their previous settlement contract.
	if room.floor_index < 0 or room.cleared or guild.state.player_hp <= 0 or reason != BattleEndReason.Value.VICTORY:
		return
	for unit in battle.units:
		if unit.alive and not unit.source_member_id.is_empty():
			StrategyEffects.heal(unit, unit.max_hp * .3)

func _on_finished(result: BattleResult) -> void:
	settlement_status = settlement.apply_room(result, guild, room)
	settled.emit(result, settlement_status)

func request_retreat() -> bool:
	return retreat.request(battle, guild.state)
