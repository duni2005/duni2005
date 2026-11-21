class_name SaveSnapshotLoader
extends RefCounted
## A save from before 시련: a combat room nobody has entered gets its trials now (from its own
## seed); rooms already entered keep none.
static func _backfill_trials(room: RoomState,run: RunState) -> void:
	if room.trials_set:return
	room.trials_set=true
	if not UnitBalance.enabled or room.floor_index<0 or not RoomType.is_combat(room.room_type) or room.visited or room.cleared or room.battle_attempt_count>0:return
	TowerMapGenerator.assign_trials(room,hash("%s:%s:trials"%[room.room_id,run.run_id]))
	room.set_meta("trial_backfill",true)
static func restore(document: Dictionary) -> SaveLoadResult:
	var result: SaveLoadResult=SaveValidator.validate(document)
	if not result.ok():return result
	var controller:=TowerController.new();controller.guild=GuildManager.new(result.run)
	for floor in result.run.tower.map.floors:
		for id in floor.room_ids:
			var room: RoomState=result.run.tower.map.get_room(id)
			_backfill_trials(room,result.run)
			for spawn in room.encounter.enemies:
				var enemy: EnemyRoomState=room.enemy_state[spawn.enemy_id];enemy.spawn=spawn;enemy.combat_stats=TowerEnemyStatsAssembler.assemble(controller.guild.definition(spawn.unit_type_id),spawn)
				if room.has_meta("trial_backfill"):enemy.current_hp=enemy.combat_stats.max_hp
			room.remove_meta("trial_backfill")
	for kind in ["map","content","combat"]:
		var rng: RandomNumberGenerator=controller.generator.rng if kind=="map" else controller.content_rng if kind=="content" else controller.combat_rng
		rng.seed=int(document.rng[kind].seed);rng.state=int(document.rng[kind].state)
	controller.content=TowerContentService.new(controller.guild,controller.content_rng)
	controller.recovery_checkpoint=document.recovery.duplicate(true)
	result.controller=controller;return result
