class_name Phase11Tests
extends RefCounted
var checks: int=0
var failures: int=0
var tree: SceneTree
var location: String=""
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE11 FAIL: "+label)
func semantic_equal(a: Variant,b: Variant) -> bool:return JSON.parse_string(JSON.stringify(SaveValueCodec.new().encode(a)))==JSON.parse_string(JSON.stringify(SaveValueCodec.new().encode(b)))
func equal_run(a: RunState,b: RunState) -> bool:return semantic_equal(SaveDomainCodec.new().encode(a,"run"),SaveDomainCodec.new().encode(b,"run"))
func make_save() -> SaveManager:
	return SaveManager.new(location+"/slot_%d.json"%checks)
func round_trip() -> void:
	var c: TowerController=Phase11Fixture.make();var save:=make_save();var time: int=Time.get_ticks_usec();var doc: SaveLoadResult=save.snapshot(c)
	verify(doc.ok(),"snapshot complex run "+doc.detail)
	if not doc.ok():return
	var encode_usec: int=Time.get_ticks_usec()-time;time=Time.get_ticks_usec()
	var text: String=JSON.stringify(doc.document,"  ");var parsed: Variant=JSON.parse_string(text);var restored: SaveLoadResult=SaveSnapshotLoader.restore(parsed)
	verify(restored.ok(),"v1 JSON decode "+restored.detail)
	if not restored.ok():return
	var decode_usec: int=Time.get_ticks_usec()-time
	verify(equal_run(c.guild.state,restored.run),"complete semantic run equality")
	verify(restored.run!=c.guild.state and restored.run.guild_members.values()[0]!=c.guild.state.guild_members.values()[0],"independent objects")
	verify(parsed.schema_version==1 and restored.metadata.guild_count==c.guild.all_members().size(),"schema and metadata")
	verify(restored.run.tower.map.floors.size()==15 and restored.run.tower.map.rooms.size()==120,"whole actual map")
	for member in c.guild.all_members():
		var loaded: GuildMemberState=restored.controller.guild.get_member(member.member_id)
		verify(loaded!=null and loaded.current_hp==member.current_hp and loaded.level==member.level and loaded.stars==member.stars,"individual identity growth HP")
		verify(loaded.energy==member.energy and loaded.ultimate_gauge==member.ultimate_gauge and loaded.transcendence_gauge==member.transcendence_gauge and loaded.stance==member.stance,"individual gauges stance energy")
		verify(semantic_equal(loaded.character_specific_state,member.character_specific_state) and loaded.fang_kills==member.fang_kills,"character persistence")
	verify(not restored.controller.guild.all_members()[1].is_alive(),"dead member retained")
	var next: GuildMemberState=restored.controller.guild.create_member(0);verify(next.member_id!=c.guild.all_members()[0].member_id and restored.run.next_member_number==c.guild.state.next_member_number+1,"counter and same-type new identity")
	# Restore untouched copy for subsequent counter checks.
	restored=SaveSnapshotLoader.restore(parsed)
	for item in c.guild.state.inventory:
		var loaded: ItemInstance=restored.controller.content.inventory.get_item(item.item_id)
		verify(loaded!=null and loaded.kind==item.kind and loaded.equipped_to_member_id==item.equipped_to_member_id and loaded.consumed==item.consumed,"inventory ownership")
	for card in c.guild.state.strategy_cards:
		var loaded: StrategyCardInstance=restored.run.get_strategy_card(card.card_id)
		verify(loaded!=null and loaded.used_depth==card.used_depth and loaded.ready_floor==card.ready_floor and loaded.used_floors==card.used_floors and loaded.consumed==card.consumed,"individual card state")
	verify(restored.run.next_item_number==c.guild.state.next_item_number and restored.run.next_strategy_card_number==c.guild.state.next_strategy_card_number,"item/card counters")
	for room in c.guild.state.tower.map.rooms.values():
		var loaded: RoomState=restored.run.tower.map.get_room(room.room_id)
		verify(loaded!=room and loaded.enemy_state.size()==room.enemy_state.size() and loaded.room_type==room.room_type,"room identity and encounter")
		for enemy in room.enemy_state.values():
			var e: EnemyRoomState=loaded.enemy_state[enemy.enemy_id]
			verify(e.current_hp==enemy.current_hp and e.position==enemy.position and e.ultimate_gauge==enemy.ultimate_gauge and semantic_equal(e.persistent_state,enemy.persistent_state),"enemy persistent state")
	verify(restored.run.strategy_use_receipts==c.guild.state.strategy_use_receipts and restored.run.transaction_receipts==c.guild.state.transaction_receipts,"receipts retained")
	verify(restored.run.tower.reward_requests[0].fulfilled and restored.run.tower.map.floors[1].conquered,"conquest request retained")
	var count: int=restored.run.inventory.size();restored.controller.process_reward_requests();verify(restored.run.inventory.size()==count,"reward receipt no duplicate")
	for kind in ["map","content","combat"]:
		var source: RandomNumberGenerator=c.generator.rng if kind=="map" else c.content_rng if kind=="content" else c.combat_rng
		var target: RandomNumberGenerator=restored.controller.generator.rng if kind=="map" else restored.controller.content_rng if kind=="content" else restored.controller.combat_rng
		verify(source.state==target.state and source.randi()==target.randi(),"exact next RNG "+kind)
	verify(save.write_document(doc.document).ok(),"atomic initial file")
	verify(save.read_document().ok(),"actual file read")
	print("PHASE11 PERFORMANCE bytes=",text.to_utf8_buffer().size()," snapshot_us=",encode_usec," JSON_parse_validate_restore_us=",decode_usec)
func invalid_saves() -> void:
	var c: TowerController=Phase11Fixture.make();var save:=make_save();var original: Dictionary=save.snapshot(c).document
	var bad: Dictionary=original.duplicate(true);bad.schema_version=99
	verify(SaveValidator.validate(bad).code==SaveLoadResult.Code.UNSUPPORTED_VERSION,"unsupported schema")
	bad=original.duplicate(true);bad.run.guild_members.append(bad.run.guild_members[0].duplicate(true));verify(not SaveValidator.validate(bad).ok(),"duplicate member")
	for edit in [["unit_type_id",CharacterCatalog.NAMES.size()],["energy",6],["ultimate_gauge",101],["level",11],["stars",3],["current_hp",-1]]:
		bad=original.duplicate(true);bad.run.guild_members[0][edit[0]]=edit[1];verify(not SaveValidator.validate(bad).ok(),"invalid member "+edit[0])
	for edit in [["gold",-1],["player_hp",-1],["next_item_number",1]]:
		bad=original.duplicate(true);bad.run[edit[0]]=edit[1];verify(not SaveValidator.validate(bad).ok(),"invalid run "+edit[0])
	bad=original.duplicate(true);bad.run.guild_members[0].current_hp=INF;verify(not SaveValidator.validate(bad).ok(),"Infinity rejected")
	bad=original.duplicate(true);bad.run.guild_members[0].current_hp=NAN;verify(not SaveValidator.validate(bad).ok(),"NaN rejected")
	bad=original.duplicate(true);bad.run.inventory[0].equipped_to_member_id="missing";verify(not SaveValidator.validate(bad).ok(),"broken equipment")
	bad=original.duplicate(true);bad.run.inventory.append(bad.run.inventory[0].duplicate(true));verify(not SaveValidator.validate(bad).ok(),"duplicate item")
	bad=original.duplicate(true);bad.run.strategy_cards.append(bad.run.strategy_cards[0].duplicate(true));verify(not SaveValidator.validate(bad).ok(),"duplicate card")
	bad=original.duplicate(true);bad.run.tower.unlocked_floor=15;verify(not SaveValidator.validate(bad).ok(),"impossible floor")
	bad=original.duplicate(true);bad.run.tower.map.rooms.append(bad.run.tower.map.rooms[0].duplicate(true));verify(not SaveValidator.validate(bad).ok(),"duplicate room")
	bad=original.duplicate(true);bad.run.tower.map.rooms[3].enemy_state[0].enemy_id="other/enemy_001";verify(not SaveValidator.validate(bad).ok(),"enemy ownership")
	bad=original.duplicate(true);bad.run.tower.map.rooms[3].enemy_state[0].position.x=INF;verify(not SaveValidator.validate(bad).ok(),"bad enemy position")
	bad=original.duplicate(true);bad.run.guild_members[0].character_specific_state.brain={"intent":1};verify(not SaveValidator.validate(bad).ok(),"AI transient rejected")
	bad=original.duplicate(true);bad.run.tower.map.rooms[3].enemy_state[1].persistent_state.ultCast.erase("duration");verify(not SaveValidator.validate(bad).ok(),"incomplete cast rejected before battle")
	bad=original.duplicate(true);bad.run.tower.map.rooms[3].enemy_state[2].persistent_state.puppetControl.erase("original_team");verify(not SaveValidator.validate(bad).ok(),"incomplete control rejected")
	bad=original.duplicate(true);bad.rng.map.state=123.0;verify(not SaveValidator.validate(bad).ok(),"RNG precision required")
	bad=original.duplicate(true);bad.run.tower.map.rooms[3].enemy_state[1].persistent_state.ultCast.target="battle:12";verify(not SaveValidator.validate(bad).ok(),"transient battle ID forbidden")
	bad=original.duplicate(true);bad.run.last_formation.entries[0].position.x=INF;verify(not SaveValidator.validate(bad).ok(),"invalid formation coordinates")
	bad=original.duplicate(true);bad.run.inventory[1].equipped_to_member_id="missing";verify(not SaveValidator.validate(bad).ok(),"invalid owner reference")
	var object:=Node.new();var values:=SaveValueCodec.new();values.encode({"unit":object});verify(not values.error.is_empty(),"Node cannot enter JSON");object.free()
	values=SaveValueCodec.new();values.encode({"callback":Callable(self,"round_trip")});verify(not values.error.is_empty(),"Callable cannot enter JSON")
	values=SaveValueCodec.new();values.encode({"resource":CharacterCatalog.all()[0]});verify(not values.error.is_empty(),"Resource cannot enter JSON")
	bad=original.duplicate(true);bad.run.tower.map.rooms[0].erase("recruit");verify(not SaveValidator.validate(bad).ok(),"missing critical field")
	verify(save.read_document().code==SaveLoadResult.Code.FILE_NOT_FOUND,"missing file")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(location));save.write_text(save.path,"{");verify(save.read_document(false).code==SaveLoadResult.Code.PARSE_ERROR,"malformed JSON")
	save.write_text(save.path,"");verify(save.read_document(false).code==SaveLoadResult.Code.PARSE_ERROR,"empty JSON")
	save.write_text(save.path,"[]");verify(save.read_document(false).code==SaveLoadResult.Code.VALIDATION_ERROR,"invalid root")
	verify(save.write_document(original).ok(),"initial normal save")
	var before: String=FileAccess.get_file_as_string(save.path)
	save.write_text(save.path+".tmp","{");verify(not save.commit_temp().ok() and FileAccess.get_file_as_string(save.path)==before,"invalid temp leaves previous bytes")
	var blocked:=SaveManager.new(save.path+"/inside/slot.json");verify(not blocked.write_document(original).ok() and FileAccess.get_file_as_string(save.path)==before,"write failure preserves slot")
	var updated: Dictionary=original.duplicate(true);updated.updated_at+=1;updated.metadata.timestamp+=1
	verify(save.write_document(updated).ok() and save.read_file(save.path+".backup").ok(),"normal backup created")
	save.write_text(save.path,"broken");var backup: SaveLoadResult=save.read_document();verify(backup.ok() and backup.from_backup,"validated backup fallback")
	save.write_text(save.path,JSON.stringify({"schema_version":99}));verify(save.read_document().code==SaveLoadResult.Code.UNSUPPORTED_VERSION,"future version no silent rollback")
func character_injection() -> void:
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json"));var loaded: SaveLoadResult=SaveSnapshotLoader.restore(saved)
	verify(loaded.ok(),"compatibility fixture for runtime injection")
	if not loaded.ok():return
	var c: TowerController=loaded.controller
	c.content_action(&"event",{"choice":&"bathe"});c.return_map();c.select_room("0:3")
	var plan:=DeploymentPlan.new(c.guild);var index: int=0
	for member in c.guild.living_members():
		verify(plan.place(member.member_id,Vector2(90+(index%3)*90,70+(index/3)*85))==DeploymentRules.Code.OK,"persistent actor placement")
		index+=1
	var b:=BattleManager.new();b.auto_start=false;tree.root.add_child(b);b.set_physics_process(false)
	verify(c.start_battle(plan,b),"complex loaded roster starts real battle")
	var sword: BattleUnit=b.units.filter(func(u):return u.data.type_id==10 and not u.source_member_id.is_empty())[0]
	verify(not sword.lost_sword.is_empty() and CharacterPersistence.vector(sword.lost_sword.point)==sword.position+Vector2(90,-35),"lostSword relative placement restored")
	var enemy: BattleUnit=b.units.filter(func(u):return not u.source_enemy_id.is_empty() and not u.ultimate.cast.is_empty())[0]
	verify(b.find_actor(enemy.ultimate.cast.target)!=null,"cast stable target reconnected")
	var controlled: BattleUnit=b.units.filter(func(u):return not u.puppet_control.is_empty())[0]
	verify(controlled.team==0 and controlled.original_team==1 and b.find_actor(controlled.puppet_control.owner)!=null,"puppet current team/original ownership")
	var shotgun: BattleUnit=b.units.filter(func(u):return u.data.type_id==7 and not u.source_member_id.is_empty())[0]
	verify(shotgun.state_value("ammo")==1 and shotgun.state_value("reloadRemaining")==2.7,"shotgun runtime persistence")
	var initial_flight: float=sword.lost_sword.flight;b.simulate(.01)
	verify(sword.lost_sword.flight<initial_flight and b.units.all(func(u):return u.position.is_finite()),"complex persistent states actually advance")
	b.free();c.release_runtime_connections()
func run(host: SceneTree) -> void:
	tree=host;location="user://phase11-tests/"+Crypto.new().generate_random_bytes(8).hex_encode();round_trip();invalid_saves()
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json"));verify(fixture is Dictionary and SaveSnapshotLoader.restore(fixture).ok(),"fixed v1 compatibility fixture")
	character_injection()
	var runtime:=Phase11RuntimeTests.new();await runtime.run(tree,location+"/runtime");checks+=runtime.checks;failures+=runtime.failures
	print("PHASE 11 RESULT: ",checks," checks; ",failures," failures")
