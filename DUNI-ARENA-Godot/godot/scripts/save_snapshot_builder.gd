class_name SaveSnapshotBuilder
extends RefCounted
static func metadata_for(run: RunState,id: String,timestamp: int,checkpoint: bool) -> Dictionary:
	var tower: TowerRunState=run.tower
	var room: RoomState=tower.map.get_room(tower.selected_room_id)
	return {"save_id":id,"timestamp":timestamp,"chapter":tower.current_chapter,"floor":room.floor_index+1 if room!=null else tower.unlocked_floor+1,"unlocked_floor":tower.unlocked_floor+1,"player_hp":run.player_hp,"gold":run.gold,"tokens":run.tokens,"guild_count":run.guild_members.size(),"living_guild_count":run.guild_members.values().filter(func(m):return m.is_alive()).size(),"phase":"battle_checkpoint" if checkpoint else String(tower.phase),"tower_conquered":tower.conquered}
static func build(controller: TowerController,id: String,created: int,recovery: Dictionary={},formation: FormationState=null) -> SaveLoadResult:
	var captured: SaveLoadResult=capture(controller,id,created,recovery,formation)
	return SaveValidator.validate(captured.document) if captured.ok() else captured
static func capture(controller: TowerController,id: String,created: int,recovery: Dictionary={},formation: FormationState=null) -> SaveLoadResult:
	# Copy at the transaction boundary; the writer validates this detached data.
	# No live controller/domain objects cross into the background writer.
	if controller.guild==null or controller.guild.state.tower==null:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,"no_run")
	var codec:=SaveDomainCodec.new();var data: Dictionary=codec.encode(controller.guild.state,"run")
	if not codec.error.is_empty():return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,codec.error)
	if formation!=null:data.last_formation=codec.encode(formation,"formation")
	var timestamp: int=maxi(created,int(Time.get_unix_time_from_system()))
	var document: Dictionary={"schema_version":SaveMigrator.CURRENT_VERSION,"save_id":id,"created_at":created,"updated_at":timestamp,"migration_version":SaveMigrator.MIGRATION_LABEL,"run":data,"rng":{},"recovery":recovery.duplicate(true),"metadata":metadata_for(controller.guild.state,id,timestamp,not recovery.is_empty())}
	for kind in ["map","content","combat"]:
		var rng: RandomNumberGenerator=controller.generator.rng if kind=="map" else controller.content_rng if kind=="content" else controller.combat_rng
		document.rng[kind]={"seed":str(rng.seed),"state":str(rng.state)}
	var result:=SaveLoadResult.new();result.document=document;result.metadata=document.metadata;return result
