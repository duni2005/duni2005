class_name SaveValidator
extends RefCounted
## Structural checks happen before assigning clamped domain fields; semantic relations afterward.
const PHASES=[&"route",&"deploy",&"shop",&"recruit",&"rest",&"event_active",&"content_result",&"result",&"cleared",&"gameover"]
const TRANSIENT=["brain","BattleBrain","target","targetId","attackDecision","entryPlan","commit","commitUntil","hesitation","readAttacks","response","rearGoal","areaGoal","safeGoal","projectiles","melee_strikes","pendingRetreat","pendingTaunt","TurningPointState"]
static func reject(reason: String) -> SaveLoadResult:return SaveLoadResult.failure(SaveLoadResult.Code.VALIDATION_ERROR,reason)
static func id_ok(value: String) -> bool:return not value.is_empty() and value.length()<=256
static func state_ok(data: Dictionary) -> bool:
	if not UnitStateCodec.is_pure_data(data):return false
	for key in TRANSIENT:
		if data.has(key):return false
	for field in ["ultCast","puppetControl","satelliteBursts"]:
		if data.has(field) and not relations_ok(data[field]):return false
	for field in ["parryCounterUsed","parryPulseUsed","guardReady","bomberRush","transferUsed","strategyUltimateReady","sniperBurstReady","tankFlameReady"]:
		if data.has(field) and not data[field] is bool:return false
	for field in CharacterPersistence.FIELDS:
		if data.has(field) and field not in ["parryCounterUsed","parryPulseUsed","guardReady","bomberRush","transferUsed","strategyUltimateReady","sniperBurstReady","tankFlameReady","satelliteBursts","bomberFuse"] and not number(data[field]):return false
	if data.has("lostSword"):
		if not data.lostSword is Dictionary:return false
		for field in ["dx","dy","vx","vy","flight","rotation","sizeBoost","scale"]:
			if not number(data.lostSword.get(field)):return false
	if data.has("ultCast"):
		if not data.ultCast is Dictionary or not data.ultCast.get("target") is String:return false
		for field in ["t","duration","angle"]:
			if not number(data.ultCast.get(field)):return false
		if data.ultCast.t<0 or data.ultCast.duration<=0 or not point_record(data.ultCast.get("point")):return false
	if data.has("puppetControl"):
		if not data.puppetControl is Dictionary or not data.puppetControl.get("owner") is String or not number(data.puppetControl.get("remaining")):return false
		for field in ["team","original_team"]:
			if not SaveValueCodec.integer(data.puppetControl.get(field)) or data.puppetControl[field] not in [0,1]:return false
	if data.has("satelliteBursts"):
		if not data.satelliteBursts is Array:return false
		for burst in data.satelliteBursts:
			if not burst is Dictionary or not number(burst.get("remaining")) or not number(burst.get("damage")):return false
	if data.get("bomberFuse")!=null and not number(data.bomberFuse):return false
	return true
static func number(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value))
static func point_record(value: Variant) -> bool:return value is Dictionary and number(value.get("x")) and number(value.get("y"))
static func relations_ok(value: Variant) -> bool:
	if value is String:return not value.begins_with("battle:") and not value.begins_with("res://") and not value.begins_with("user://")
	if value is Array:
		for child in value:
			if not relations_ok(child):return false
	if value is Dictionary:
		for key in value:
			if key in ["target","owner","master","controller","saint"]:
				var id: Variant=value[key]
				if not id is String or not id.is_empty() and not id.begins_with("member:") and not id.begins_with("enemy:"):return false
			if not relations_ok(value[key]):return false
	return true
static func point_ok(p: Vector2) -> bool:return p.is_finite() and p.x>=28 and p.x<=772 and p.y>=28 and p.y<=772
static func validate(document: Dictionary) -> SaveLoadResult:
	var version: SaveLoadResult=SaveMigrator.prepare(document)
	if not version.ok():return version
	document=version.document
	if not UnitStateCodec.is_pure_data(document):return reject("non_pure_document")
	if document.size()!=9:return reject("unknown_header_fields")
	for key in ["save_id","created_at","updated_at","migration_version","run","rng","metadata","recovery"]:
		if not document.has(key):return reject("missing_header:"+key)
	if not document.save_id is String or not id_ok(document.save_id) or not document.migration_version is String:return reject("save_identity")
	if not SaveValueCodec.integer(document.created_at) or not SaveValueCodec.integer(document.updated_at) or document.created_at<0 or document.updated_at<document.created_at:return reject("timestamps")
	if not document.rng is Dictionary or document.rng.size()!=3:return reject("rng_record")
	for kind in ["map","content","combat"]:
		if not document.rng.get(kind) is Dictionary or document.rng[kind].size()!=2:return reject("rng_source")
		for key in ["seed","state"]:
			if not SaveValueCodec.valid_int64(document.rng[kind].get(key)):return reject("rng_precision")
	var codec:=SaveDomainCodec.new()
	var run: RunState=codec.decode(document.run,"run")
	if run==null or not codec.error.is_empty():return reject(codec.error)
	var verified: SaveLoadResult=validate_run(run)
	if not verified.ok():return verified
	if not document.recovery is Dictionary:return reject("recovery_required")
	if not document.recovery.is_empty():
		var r: Dictionary=document.recovery
		if r.size()!=3 or r.get("kind") not in ["battle","prediction"] or r.get("room_id")!=run.tower.selected_room_id or not SaveValueCodec.integer(r.get("seed")):return reject("checkpoint_record")
		if r.kind=="battle" and run.tower.phase!=&"deploy" or r.kind=="prediction" and (run.tower.phase!=&"event_active" or run.tower.map.get_room(r.room_id).event_type!=&"prediction"):return reject("checkpoint_route")
	if not document.metadata is Dictionary:return reject("metadata_required")
	var expected: Dictionary=SaveSnapshotBuilder.metadata_for(run,document.save_id,int(document.updated_at),not document.recovery.is_empty())
	if document.metadata.size()!=expected.size():return reject("metadata_mismatch")
	for key in expected:
		if not document.metadata.has(key) or document.metadata[key]!=expected[key]:return reject("metadata_mismatch:"+key)
	verified.document=document;verified.metadata=document.metadata;return verified
static func validate_run(run: RunState) -> SaveLoadResult:
	if not id_ok(run.run_id) or run.tower==null or run.strategy_progress==null or run.last_formation==null:return reject("run_identity")
	if run.player_hp>run.player_max_hp or run.gold<0 or run.tokens<0:return reject("run_resources")
	var tower: TowerRunState=run.tower
	if tower.phase not in PHASES or tower.current_chapter<1 or tower.current_chapter>3 or tower.unlocked_floor<0 or tower.unlocked_floor>=15 or tower.map==null:return reject("tower_progress")
	if run.strategy_progress.current_depth<0 or run.strategy_progress.current_depth>=15 or run.strategy_progress.unlocked_floor!=tower.unlocked_floor:return reject("strategy_progress")
	if tower.result not in [&"",&"conquered",&"gameover",&"abandon"] or tower.map_scroll_y<0:return reject("tower_result")
	var highest: int=0
	for member in run.guild_members.values():
		if not id_ok(member.member_id) or CharacterCatalog.all().get(member.unit_type_id)==null or not state_ok(member.character_specific_state):return reject("member")
		if member.member_id.begins_with("member_") and member.member_id.substr(7).is_valid_int():highest=maxi(highest,int(member.member_id.substr(7)))
	if run.next_member_number<=highest or run.next_member_number<1:return reject("member_counter")
	var inventory:=InventoryService.new(run)
	if not inventory.valid():return reject("inventory_identity_or_ownership")
	for member in run.guild_members.values():
		if inventory.equipped(member.member_id).size()>GuildMemberCombatStats.equipment_limit(member):return reject("equipment_slots")
	var cards: Dictionary={};highest=0
	for card in run.strategy_cards:
		if card.card_id<1 or cards.has(card.card_id) or StrategyCardCatalog.get_card(card.kind)==null or card.used_depth< -1 or card.used_depth>14 or card.ready_floor<0:return reject("card")
		for depth in card.used_floors:
			if depth<0 or depth>=15 or card.used_floors.count(depth)!=1:return reject("card_floors")
		cards[card.card_id]=true;highest=maxi(highest,card.card_id)
	if run.next_strategy_card_number<=highest or run.next_strategy_card_number<1:return reject("card_counter")
	var seen: Dictionary={}
	for entry in run.last_formation.entries:
		# Removed promotion donors may still occur in last formation: Phase3 ignores them.
		if not id_ok(entry.member_id) or seen.has(entry.member_id) or entry.team!=0 or not entry.position.is_finite() or entry.position.x<0 or entry.position.x>800 or entry.position.y<0 or entry.position.y>800:return reject("formation")
		seen[entry.member_id]=true
	if tower.map.floors.size()!=15 or tower.map.rooms.size()!=120:return reject("map_size")
	seen={}
	for i in range(15):
		var floor: FloorState=tower.map.floors[i]
		if floor.floor_index!=i or floor.chapter_index!=i/5+1 or floor.room_ids.size()!=TowerMapGenerator.room_count(i) or floor.required_clear_count!=ceili(floor.room_ids.size()/2.0) or floor.unlocked!=(i<=tower.unlocked_floor):return reject("floor")
		if floor.bonus not in [&"",&"heal",&"item",&"tokens"] or floor.bonus==&"item" and ItemCatalog.get_item(floor.bonus_item_kind)==null:return reject("floor_bonus")
		var count: int=0
		for lane in range(floor.room_ids.size()):
			var id: String=floor.room_ids[lane];var room: RoomState=tower.map.get_room(id)
			if seen.has(id) or room==null or id!="%d:%d"%[i,lane] or room.floor_index!=i or room.chapter_index!=floor.chapter_index or room.lane!=lane or room.source_run_id!=run.run_id:return reject("room_floor_owner")
			seen[id]=true
			var reason: String=validate_room(room)
			if not reason.is_empty():return reject(reason)
			count+=int(room.cleared)
		if count!=floor.cleared_count or floor.conquered!=(count==floor.room_ids.size()) or floor.conquered!=bool(tower.floor_conquest.get(i,false)):return reject("floor_counts")
	var expected_unlock: int=0
	while expected_unlock<14:
		var floor: FloorState=tower.map.floors[expected_unlock]
		var boss_cleared: bool=floor.room_ids.any(func(id):return tower.map.get_room(id).room_type==RoomType.BOSS and tower.map.get_room(id).cleared)
		if floor.cleared_count<floor.required_clear_count or expected_unlock%5==4 and not boss_cleared:break
		expected_unlock+=1
	if tower.unlocked_floor!=expected_unlock:return reject("unlock_boundary")
	if not tower.selected_room_id.is_empty() and tower.map.get_room(tower.selected_room_id)==null:return reject("selected_room")
	if tower.phase not in [&"route",&"gameover"] and tower.selected_room_id.is_empty():return reject("route_room_required")
	if not tower.selected_room_id.is_empty():
		var selected: RoomState=tower.map.get_room(tower.selected_room_id)
		if tower.current_chapter!=selected.chapter_index:return reject("current_chapter")
		if tower.phase==&"deploy" and (not RoomType.is_combat(selected.room_type) or selected.cleared or selected.living_enemies().is_empty()):return reject("deployment_route")
		if tower.phase==&"shop" and (selected.room_type!=RoomType.SHOP or selected.shop==null):return reject("shop_route")
		if tower.phase==&"recruit" and (selected.room_type!=RoomType.RECRUIT or selected.recruit==null):return reject("recruit_route")
		if tower.phase==&"rest" and (selected.room_type!=RoomType.REST or selected.cleared):return reject("rest_route")
		if tower.phase==&"event_active" and (selected.room_type!=RoomType.EVENT or selected.event==null):return reject("event_route")
		if tower.phase==&"cleared" and not selected.cleared:return reject("cleared_route")
	var final_floor: FloorState=tower.map.floors[14]
	var actually_conquered: bool=final_floor.cleared_count>=final_floor.required_clear_count and final_floor.room_ids.any(func(id):return tower.map.get_room(id).room_type==RoomType.BOSS and tower.map.get_room(id).cleared)
	if tower.conquered!=actually_conquered:return reject("conquest_flag")
	for pair in [[tower.floor_conquest,0,14],[tower.chapter_progress,1,3]]:
		for key in pair[0]:
			if not key is int or key<pair[1] or key>pair[2] or pair[0][key]!=true:return reject("progress_history")
	if tower.phase==&"gameover" and not run.game_over or run.game_over and tower.phase!=&"gameover":return reject("gameover_phase")
	if run.player_hp<=0 and not run.game_over or run.guild_members.values().all(func(m):return not m.is_alive()) and not run.game_over:return reject("missing_gameover")
	for receipt in run.inventory_receipts:
		if not SaveValueCodec.integer(run.inventory_receipts[receipt]) or inventory.get_item(int(run.inventory_receipts[receipt]))==null:return reject("item_receipt")
	seen={}
	for request in tower.reward_requests:
		if not id_ok(request.reward_id) or seen.has(request.reward_id) or request.kind!=&"item" or ItemCatalog.get_item(request.item_kind)==null:return reject("reward")
		if request.fulfilled and not run.inventory_receipts.has("reward:"+request.reward_id):return reject("fulfilled_reward_receipt")
		seen[request.reward_id]=true
	for field in [tower.visited_rooms,tower.cleared_rooms]:
		for id in field:
			if not id is String or tower.map.get_room(id)==null or field[id]!=true:return reject("room_history")
	for id in tower.map.rooms:
		var room: RoomState=tower.map.rooms[id]
		if room.visited!=bool(tower.visited_rooms.get(id,false)) or room.cleared!=bool(tower.cleared_rooms.get(id,false)):return reject("room_history_mismatch")
	var result:=SaveLoadResult.new();result.run=run;return result
static func validate_room(room: RoomState) -> String:
	if not RoomType.LABELS.has(room.room_type) or room.encounter==null or not room.active_result_id.is_empty() or room.battle_attempt_count<0 or room.content_visits<0:return "room_state"
	if room.gold_reward<0 or room.token_reward<0 or room.visited and not room.discovered or room.consumed and not room.cleared:return "room_flags"
	if room.encounter.room_kind!=room.room_type or room.encounter.depth!=room.floor_index:return "encounter_owner"
	if RoomType.is_combat(room.room_type) and room.encounter.enemies.is_empty() or not RoomType.is_combat(room.room_type) and not room.encounter.enemies.is_empty():return "encounter_kind"
	var seen: Dictionary={}
	for spawn in room.encounter.enemies:
		if not spawn.enemy_id.begins_with(room.room_id+"/enemy_") or seen.has(spawn.enemy_id) or CharacterCatalog.all().get(spawn.unit_type_id)==null or spawn.level<0 or spawn.rank not in [&"normal",&"elite",&"boss"] or not point_ok(spawn.initial_position):return "spawn"
		for factor in [spawn.body_scale,spawn.hp_multiplier,spawn.damage_multiplier,spawn.defense_multiplier,spawn.speed_multiplier]:
			if not is_finite(factor) or factor<=0:return "spawn_multiplier"
		var enemy: EnemyRoomState=room.enemy_state.get(spawn.enemy_id)
		if enemy==null or enemy.unit_type_id!=spawn.unit_type_id or not point_ok(enemy.position) or enemy.current_hp<0 or enemy.ultimate_gauge<0 or enemy.ultimate_gauge>100 or not state_ok(enemy.persistent_state):return "enemy_state"
		seen[spawn.enemy_id]=true
	if seen.size()!=room.enemy_state.size():return "enemy_encounter_relation"
	if room.cleared and RoomType.is_combat(room.room_type) and not room.living_enemies().is_empty():return "cleared_living_enemy"
	for id in room.kill_rewards:
		if not room.enemy_state.has(id) or room.enemy_state[id].alive:return "kill_receipt"
	if room.recruit!=null:
		if room.room_type!=RoomType.RECRUIT or room.recruit.revision<0 or room.recruit.offers.size()!=3:return "recruit"
		seen={}
		for offer in room.recruit.offers:
			if not id_ok(offer.offer_id) or seen.has(offer.offer_id) or CharacterCatalog.all().get(offer.unit_type_id)==null or offer.gold_price<0 or offer.token_price<0:return "recruit_offer"
			seen[offer.offer_id]=true
	if room.shop!=null:
		if room.room_type!=RoomType.SHOP:return "shop"
		seen={}
		for offer in room.shop.offers:
			if not id_ok(offer.offer_id) or seen.has(offer.offer_id) or offer.gold_price<0 or offer.category not in [&"equipment",&"card"]:return "shop_offer"
			if offer.category==&"equipment" and ItemCatalog.get_item(offer.kind)==null or offer.category==&"card" and StrategyCardCatalog.get_card(offer.kind)==null:return "shop_kind"
			seen[offer.offer_id]=true
	if room.event!=null:
		var event: EventState=room.event
		if room.room_type!=RoomType.EVENT or event.event_type!=room.event_type:return "event"
		if event.event_type not in [&"prediction",&"supply",&"hotSpring"]:return "event_type"
		if event.prediction!=null and (not PredictionRules.valid(event.prediction) or event.prediction.status not in [&"ready",&"resolved"]):return "prediction_state"
	return ""
