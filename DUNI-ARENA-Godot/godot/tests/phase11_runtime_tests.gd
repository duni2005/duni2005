class_name Phase11RuntimeTests
extends RefCounted
var checks: int=0
var failures: int=0
var tree: SceneTree
var location: String
var controllers: Array[TowerController]=[]
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE11 RUNTIME FAIL: "+label)
func frames() -> void:
	for i in range(3):await tree.process_frame
func fresh() -> TowerController:
	var c:=TowerController.new();var s:=SaveManager.new(location+"/slot_%d.json"%checks);s.attach(c);c.new_run(19,73);controllers.append(c);return c
func manager() -> BattleManager:
	var b:=BattleManager.new();b.auto_start=false;tree.root.add_child(b);b.set_physics_process(false);return b
func launch(c: TowerController) -> BattleManager:
	c.select_room("0:3");var plan:=DeploymentPlan.new(c.guild);plan.place(c.guild.all_members()[0].member_id,Vector2(180,400));var b:=manager()
	verify(c.start_battle(plan,b),"checkpoint-backed battle starts")
	return b
func transactions() -> void:
	var c:=fresh();var s: SaveManager=c.save_manager;await frames()
	verify(s.writes==1 and s.read_document().ok(),"new run autosave")
	c.select_room("0:0");await frames();var offer: RecruitOffer=c.current_room().recruit.offers[0];var before: int=c.guild.all_members().size();var writes: int=s.writes
	verify(c.content_action(&"recruit",{"offer_id":offer.offer_id}).ok,"recruit success")
	await frames();var loaded: SaveLoadResult=s.load_controller();verify(loaded.ok() and loaded.run.guild_members.size()==before+1 and loaded.controller.current_room().recruit.offers[0].purchased,"recruit persisted")
	verify(s.writes==writes+1,"one transaction one save")
	writes=s.writes;var random_state: int=c.content_rng.state
	verify(not c.content_action(&"recruit",{"offer_id":offer.offer_id}).ok,"repeat rejected")
	await frames();verify(s.writes==writes and c.content_rng.state==random_state,"failure does not save or consume RNG")
	c.content_action(&"reroll");await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.controller.current_room().recruit.revision==1,"reroll persisted")
	c.return_map();c.select_room("0:1");await frames()
	var stock: ShopOffer=c.current_room().shop.offers.filter(func(o):return o.category==&"equipment")[0]
	verify(c.content_action(&"buy",{"offer_id":stock.offer_id}).ok,"shop success")
	await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.run.inventory.size()==1 and loaded.controller.current_room().shop.offers.any(func(o):return o.offer_id==stock.offer_id and o.purchased),"shop stock/sold persisted")
	var item: ItemInstance=c.content.inventory.available()[0];var member: GuildMemberState=c.guild.all_members()[0]
	# Consumable cannot be equipped with no equipment; choose a real nonconsumable if stock is reengrave.
	if item.kind==&"reengrave":item=c.content.inventory.give(&"vital","runtime:gear")
	verify(c.content_action(&"equip",{"item_id":item.item_id,"member_id":member.member_id}).ok,"equipment success")
	await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.controller.content.inventory.get_item(item.item_id).equipped_to_member_id==member.member_id,"equipment persisted")
	c.return_map();verify(c.content_action(&"upgrade",{"member_id":member.member_id}).ok,"upgrade success")
	await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.controller.guild.get_member(member.member_id).level==1,"upgrade persisted")
	writes=s.writes;s.request_autosave(c);s.request_autosave(c);s.request_autosave(c);await frames();verify(s.writes==writes+1,"same frame debounce")
	c.select_room("0:2");c.content_action(&"rest",{"choice":&"player"});await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.run.tower.map.get_room("0:2").consumed,"rest completion persisted")
func battle_checkpoint_retry() -> void:
	var c:=fresh();await frames();var s: SaveManager=c.save_manager;var b: BattleManager=launch(c)
	var checkpoint: SaveLoadResult=s.read_document();verify(checkpoint.ok() and checkpoint.document.recovery.kind=="battle" and checkpoint.run.tower.phase==&"deploy","prebattle checkpoint route")
	verify(checkpoint.run.tower.map.get_room("0:3").battle_attempt_count==0 and checkpoint.run.last_formation.entries[0].position==Vector2(180,400),"prebattle attempt and actual formation")
	var seed_value: int=int(checkpoint.document.recovery.seed);var source_rng: int=c.combat_rng.state;var writes: int=s.writes
	b.units[0].current_hp=43;b.units[0].position=Vector2(350,450)
	verify(s.manual_save(c).code==SaveLoadResult.Code.BUSY and s.writes==writes,"midbattle manual save refused")
	b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2)
	verify(b.turning.is_paused() and s.manual_save(c).code==SaveLoadResult.Code.BUSY,"TP save refused")
	var loaded: SaveLoadResult=s.load_controller();verify(loaded.ok() and loaded.run.guild_members.values()[0].current_hp==150,"app kill restores prebattle HP")
	var retry: TowerController=loaded.controller;controllers.append(retry);b.free();c.release_runtime_connections();c=null
	var plan:=DeploymentPlan.new(retry.guild);plan.restore(retry.guild.state.last_formation);var replay:=manager()
	verify(retry.start_battle(plan,replay) and replay.rng.seed==seed_value and retry.combat_rng.state==source_rng,"same reserved attempt seed without reconsuming source")
	verify(replay.units[0].position==Vector2(180,400) and replay.turning.next_at==12,"fresh placement/AI/TP")
	verify(replay.melee_strikes.is_empty() and replay.projectiles.is_empty() and replay.turning.current==null,"no battle transient restored")
	var member: BattleUnit=replay.units[0];var enemies: Array=replay.units.filter(func(u):return not u.source_enemy_id.is_empty())
	member.current_hp=43;enemies[0].receive_damage(100000,member);enemies[1].current_hp=40;enemies[1].position=Vector2(470,330);enemies[1].ultimate_gauge=58;enemies[1].shield_hp=19;enemies[1].shield_remaining=2.4;enemies[1].parry_cooldown=3.2
	replay.clock.elapsed=20;verify(retry.session.request_retreat(),"actual retreat settlement")
	await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.run.tower.phase==&"result" and loaded.document.recovery.is_empty(),"settled autosave supersedes checkpoint")
	verify(loaded.run.guild_members.values()[0].current_hp==43,"participant HP after settlement")
	var room: RoomState=loaded.run.tower.map.get_room("0:3");var saved_enemies: Array=room.enemy_state.values()
	verify(not saved_enemies[0].alive and saved_enemies[1].current_hp==40 and saved_enemies[1].position==Vector2(470,330) and saved_enemies[1].ultimate_gauge==58,"damaged/dead enemies saved")
	verify(saved_enemies[1].persistent_state.shieldHp==19 and saved_enemies[1].persistent_state.parryCooldown==3.2,"common persistent runtime state")
	var gold: int=loaded.run.gold;verify(not loaded.controller.session is RoomBattleSession,"no session restored")
	loaded.controller.process_reward_requests();verify(loaded.run.gold==gold,"load/result no repeated reward")
	loaded.controller.return_map();verify(loaded.controller.select_room("0:3")==TowerNavigationPolicy.Code.OK,"damaged room load/retry")
	plan=DeploymentPlan.new(loaded.controller.guild);plan.restore(loaded.run.last_formation);controllers.append(loaded.controller);var next:=manager();verify(loaded.controller.start_battle(plan,next),"new retry after settled load")
	verify(next.units.filter(func(u):return not u.source_enemy_id.is_empty()).size()==enemies.size()-1,"dead enemy not recreated")
	var restored_enemy: BattleUnit=next.units.filter(func(u):return u.source_enemy_id==saved_enemies[1].enemy_id)[0]
	verify(restored_enemy.current_hp==40 and restored_enemy.position==Vector2(470,330) and restored_enemy.ultimate_gauge==58,"enemy stable ID injected")
	verify(next.units[0].position==Vector2(180,400) and next.turning.next_at==12,"ally start formation not ending position")
	replay.free();next.free()
func outcomes() -> void:
	for mode in ["defeat","hp_zero","no_reserves"]:
		var c:=fresh();await frames()
		if mode=="hp_zero":c.guild.state.player_hp=1
		if mode=="no_reserves":
			var first: GuildMemberState=c.guild.all_members()[0];c.guild.state.guild_members={first.member_id:first}
		var b: BattleManager=launch(c);b.units[0].receive_damage(100000,b.units[1]);b.check_outcome();await frames()
		var loaded: SaveLoadResult=c.save_manager.load_controller();verify(loaded.ok(),"outcome autosave "+mode+" "+loaded.detail)
		if loaded.ok():
			verify(loaded.run.game_over==(mode!="defeat") and loaded.run.tower.phase==(&"result" if mode=="defeat" else &"gameover"),"run end distinction "+mode)
			verify(loaded.run.player_hp==(0 if mode=="hp_zero" else 75),"death and defeat HP loss saved "+mode)
			verify(not loaded.controller.guild.all_members()[0].is_alive(),"dead participant kept "+mode)
		b.free()
	var c:=fresh();await frames();verify(c.abandon(true),"confirmed abandon")
	await frames();var loaded: SaveLoadResult=c.save_manager.load_controller();verify(loaded.ok() and loaded.run.tower.result==&"abandon" and loaded.run.game_over_reason==RunState.GameOverReason.ABANDON,"abandon survives restart")
	verify(c.new_run(21,77),"new run replacement")
	await frames();loaded=c.save_manager.load_controller();verify(loaded.ok() and not loaded.run.game_over and loaded.run.run_id==c.guild.state.run_id,"new run replaces ended autosave")
func promotion_events_prediction() -> void:
	var c:=fresh();await frames();var run: RunState=c.guild.state;var s: SaveManager=c.save_manager
	var a: GuildMemberState=c.guild.all_members()[0];var b: GuildMemberState=c.guild.all_members()[1];var donor: GuildMemberState=c.guild.create_member(0)
	for member in [a,b,donor]:member.level=10
	var keep: ItemInstance=c.content.inventory.give(&"vital","promotion:keep");keep.equipped_to_member_id=a.member_id
	var returned: ItemInstance=c.content.inventory.give(&"fang","promotion:return");returned.equipped_to_member_id=b.member_id
	var room: RoomState=run.tower.map.get_room("0:4");room.event_type=&"promotion";c.select_room(room.room_id);await frames()
	var writes: int=s.writes
	for member in [a,b,donor]:verify(c.content_action(&"promotion_select",{"member_id":member.member_id}).ok,"promotion selection")
	await frames();verify(s.writes==writes,"UI promotion choices not autosaved")
	verify(s.manual_save(c).ok(),"stable promotion choice save")
	var loaded: SaveLoadResult=s.load_controller();verify(loaded.ok() and loaded.controller.current_room().event.selected_members.is_empty() and loaded.run.guild_members.size()==5,"selection absent and no partial transaction")
	writes=s.writes;verify(c.content_action(&"promote").ok,"real promotion transaction")
	await frames();loaded=s.load_controller();verify(loaded.ok() and s.writes==writes+1 and loaded.run.guild_members.size()==3,"promotion one atomic autosave")
	verify(loaded.controller.guild.get_member(a.member_id).stars==1 and loaded.controller.guild.get_member(a.member_id).level==0 and loaded.controller.guild.get_member(b.member_id)==null,"promotion identities/stars")
	verify(loaded.controller.content.inventory.get_item(keep.item_id).equipped_to_member_id==a.member_id and loaded.controller.content.inventory.get_item(returned.item_id).equipped_to_member_id.is_empty(),"equipment returned with same IDs")
	verify(c.content_action(&"finish").ok,"promotion finish")
	await frames();loaded=s.load_controller();verify(loaded.ok() and loaded.run.tower.map.get_room(room.room_id).cleared,"promotion room progress persisted")
	c=fresh();await frames();room=c.guild.state.tower.map.get_room("0:4");room.event_type=&"hotSpring";c.select_room(room.room_id)
	verify(c.content_action(&"event",{"choice":&"bathe"}).ok,"hot spring choice")
	await frames();loaded=c.save_manager.load_controller();verify(loaded.ok() and loaded.run.tower.phase==&"content_result" and loaded.controller.current_room().event.resolved,"hot spring result saved")
	c=fresh();await frames();room=c.guild.state.tower.map.get_room("0:4");room.event_type=&"supply";c.select_room(room.room_id)
	verify(c.content_action(&"event",{"choice":&"loot"}).ok,"supply choice")
	await frames();loaded=c.save_manager.load_controller();verify(loaded.ok() and loaded.controller.current_room().event.selected_choice==&"loot" and loaded.controller.current_room().consumed,"supply content/receipt saved")
	c=fresh();await frames();s=c.save_manager;room=c.guild.state.tower.map.get_room("0:4");room.event_type=&"prediction";c.select_room(room.room_id);c.choose_prediction(0,100);await frames()
	var gold: int=c.guild.state.gold;var battle: BattleManager=manager();verify(c.start_prediction(battle),"prediction checkpoint")
	loaded=s.load_controller();verify(loaded.ok() and loaded.document.recovery.kind=="prediction" and loaded.run.gold==gold and loaded.controller.current_room().event.prediction.status==&"ready","prediction crash returns before wager")
	var restored: TowerController=loaded.controller;controllers.append(restored);battle.free();c.release_runtime_connections()
	var replay:=manager();verify(restored.start_prediction(replay),"prediction replay reserved seed")
	replay.finish_with_reason(BattleEndReason.Value.VICTORY,0);await frames();loaded=s.load_controller()
	verify(loaded.ok() and loaded.run.gold==gold+100 and loaded.controller.current_room().event.prediction.status==&"resolved" and loaded.document.recovery.is_empty(),"prediction payout saved once")
	var saved_gold: int=loaded.run.gold;loaded.controller.process_reward_requests();verify(loaded.run.gold==saved_gold,"prediction reload no repeated payout");replay.free()
func conquest() -> void:
	var c:=fresh();await frames();var run: RunState=c.guild.state
	# Reach the actual progression threshold of every floor in explicit fixture data.
	for floor in run.tower.map.floors:
		var ids: Array=floor.room_ids.slice(0,floor.required_clear_count)
		for id in floor.room_ids:
			if run.tower.map.get_room(id).room_type==RoomType.BOSS and not ids.has(id):ids.append(id)
		for id in ids:
			var room: RoomState=run.tower.map.get_room(id);room.discovered=true;room.visited=true;room.cleared=true;room.consumed=room.room_type not in [RoomType.SHOP,RoomType.RECRUIT];run.tower.visited_rooms[id]=true
			for enemy in room.enemy_state.values():enemy.current_hp=0
		c.refresh_progress(floor.floor_index)
	await frames();var loaded: SaveLoadResult=c.save_manager.load_controller()
	verify(loaded.ok() and loaded.run.tower.conquered and loaded.run.tower.unlocked_floor==14,"conquered tower kept")
	verify(loaded.run.tower.result==&"conquered" and not loaded.run.game_over,"conquest not run death")
	var next: String=""
	for room in loaded.run.tower.map.rooms.values():
		if not room.cleared:next=room.room_id;break
	verify(not next.is_empty() and loaded.controller.select_room(next)==TowerNavigationPolicy.Code.OK,"remaining rooms freely explorable after load")
func run(host: SceneTree,folder: String) -> void:
	tree=host;location=folder;await transactions();await battle_checkpoint_retry();await outcomes();await promotion_events_prediction();await conquest()
	await frames()
	for c in controllers:c.release_runtime_connections()
	controllers.clear()
	print("PHASE11 RUNTIME RESULT: ",checks," checks; ",failures," failures")
