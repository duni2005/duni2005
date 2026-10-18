class_name SaveSnapshotLoader
extends RefCounted
static func restore(document: Dictionary) -> SaveLoadResult:
	var result: SaveLoadResult=SaveValidator.validate(document)
	if not result.ok():return result
	var controller:=TowerController.new();controller.guild=GuildManager.new(result.run)
	for floor in result.run.tower.map.floors:
		for id in floor.room_ids:
			var room: RoomState=result.run.tower.map.get_room(id)
			for spawn in room.encounter.enemies:
				var enemy: EnemyRoomState=room.enemy_state[spawn.enemy_id];enemy.spawn=spawn;enemy.combat_stats=TowerEnemyStatsAssembler.assemble(controller.guild.definition(spawn.unit_type_id),spawn)
	for kind in ["map","content","combat"]:
		var rng: RandomNumberGenerator=controller.generator.rng if kind=="map" else controller.content_rng if kind=="content" else controller.combat_rng
		rng.seed=int(document.rng[kind].seed);rng.state=int(document.rng[kind].state)
	controller.content=TowerContentService.new(controller.guild,controller.content_rng)
	controller.recovery_checkpoint=document.recovery.duplicate(true)
	result.controller=controller;return result
