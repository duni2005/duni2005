class_name Phase10Tests
extends RefCounted
var host: SceneTree
var checks: int=0
var failures: int=0
var groups: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE10 FAIL: "+label)
func tower() -> TowerController:
	var t:=TowerController.new();t.new_run(19,73);return t
func enter_event(t: TowerController,kind: StringName) -> void:
	var node: RoomState=t.guild.state.tower.map.get_room("0:4");node.event_type=kind
	verify(t.select_room(node.room_id)==TowerNavigationPolicy.Code.OK,"event enters")
func give(t: TowerController,kind: StringName,member: GuildMemberState) -> ItemInstance:
	var item: ItemInstance=t.content.inventory.give(kind)
	verify(item!=null and t.content_action(&"equip",{"item_id":item.item_id,"member_id":member.member_id}).ok,"gear equipped "+String(kind))
	return item
func create_battle(t: TowerController,ids: Array=[]) -> BattleManager:
	var plan:=DeploymentPlan.new(t.guild)
	var selected: Array=ids if not ids.is_empty() else [t.guild.all_members()[0].member_id]
	for i in range(selected.size()):verify(plan.place(selected[i],Vector2(100,220+i*100))==DeploymentRules.Code.OK,"deployment valid")
	var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
	verify(t.start_battle(plan,b),"content stats enter full session")
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0
	return b
func golden() -> void:
	groups+=1
	var web: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://migration/phase10-web-rules.json"))
	verify(ItemCatalog.LEGACY.size()==10 and ItemCatalog.LEGACY.all(func(k):return ItemCatalog.get_item(k)!=null),"ten web items still load (legacy grade)")
	for row in web.items:
		var item: ItemData=ItemCatalog.get_item(StringName(row.id))
		verify(item.display_name==row.name and item.gold_price==row.cost and item.description==row.help,"executed JS item "+row.id)
	for row in web.cards:verify(StrategyCardCatalog.get_card(StringName(row.kind)).gold_price==row.cost,"actual card price")
	for type in range(26):verify(CharacterCatalog.all()[type].recruit_tokens==web.recruitPrices[type],"actual recruit price")
	verify(PredictionRules.POOLS.size()==web.predictionPools.size(),"59 exact prediction combinations")
	for i in range(PredictionRules.POOLS.size()):
		for j in range(2):verify(PredictionRules.POOLS[i][j]==int(web.predictionPools[i][j]),"exact prediction pool type")
	var g:=GuildManager.new();g.state.tower=TowerRunState.new();var inv:=InventoryService.new(g.state)
	var base: Dictionary={}
	for type in range(26):base[type]=[g.definition(type).max_hp,g.definition(type).attack,g.definition(type).defense_power,g.definition(type).move_speed]
	for row in web.samples:
		# The web gave each star 40 levels of stats; stars now add none (promotion pays EXP instead).
		if row.stars>0:continue
		g.state.inventory.clear()
		var member: GuildMemberState=g.create_member(row.type);member.level=row.level;member.stars=row.stars;member.fang_kills=row.kills
		for kind in row.gear:inv.give(StringName(kind)).equipped_to_member_id=member.member_id
		var stats: UnitCombatStats=g.member_stats(member)
		# Attack is now attack % (gear x fang growth): the web damage divided by its level-grown base.
		var grow: float=1+row.level*.08
		verify(is_equal_approx(stats.attack,row.stats.dmg/(g.definition(row.type).attack*grow)),"executed JS gear/fang attack golden as attack %")
		verify(is_equal_approx(stats.physical_damage,UnitStatTable.base_physical(row.type)*grow*stats.physical_power) and is_equal_approx(stats.defense,UnitStatTable.base_defense(row.type)*grow),"table damage/defense with level growth")
		for pair in [["max_hp","hp"],["speed","speed"],["healing_power","healingPower"],["victory_gold","victoryGold"],["vigor_totem_count","totemCount"],["charge_totem_count","chargeTotemCount"],["fang_count","fangCount"],["opening_awl_count","openingAwlCount"]]:verify(is_equal_approx(stats.get(pair[0]),row.stats[pair[1]]),"executed JS growth/gear golden")
	var plain: GuildMemberState=g.create_member(0);var starred: GuildMemberState=g.create_member(0);plain.level=4;starred.level=4;starred.stars=2
	verify(g.member_stats(plain).max_hp==g.member_stats(starred).max_hp and g.member_stats(plain).attack==g.member_stats(starred).attack,"stars add no stat bonus")
	for type in range(26):verify(base[type]==[g.definition(type).max_hp,g.definition(type).attack,g.definition(type).defense_power,g.definition(type).move_speed],"shared UnitData immutable")
func recruit_shop() -> void:
	groups+=1
	var t:=tower();t.select_room("0:0");var room: RoomState=t.current_room();var offers: Array[RecruitOffer]=room.recruit.offers
	verify(offers.size()==3 and offers[0].unit_type_id!=offers[1].unit_type_id and offers[0].unit_type_id!=offers[2].unit_type_id and offers[1].unit_type_id!=offers[2].unit_type_id,"three distinct offers")
	var first: RecruitOffer=offers[0];t.guild.create_member(first.unit_type_id)
	var gold: int=t.guild.state.gold;var tokens: int=t.guild.state.tokens;var before: int=t.guild.all_members().size()
	var result: Dictionary=t.content_action(&"recruit",{"offer_id":first.offer_id})
	verify(result.ok and t.guild.all_members().size()==before+1,"recruit individual member")
	var member: GuildMemberState=t.guild.get_member(result.outcome.member_id)
	verify(member.level==0 and member.stars==0 and member.current_hp==t.guild.definition(member.unit_type_id).max_hp and member.energy==5 and member.ultimate_gauge==0 and member.transcendence_gauge==0 and member.stance==CombatStance.NORMAL and member.character_specific_state.is_empty(),"web initial member state")
	verify(t.guild.state.gold==gold and t.guild.state.tokens==tokens-first.token_price,"tokens only purchase")
	verify(not t.content_action(&"recruit",{"offer_id":first.offer_id}).ok,"purchased offer refused")
	verify(t.guild.all_members().filter(func(m):return m.unit_type_id==first.unit_type_id).size()>=2,"same type independently owned")
	t.guild.state.tokens=0;var seed: int=t.content_rng.state;var receipts: int=t.guild.state.transaction_receipts.size()
	verify(not t.content_action(&"recruit",{"offer_id":offers[1].offer_id}).ok and t.content_rng.state==seed and t.guild.state.transaction_receipts.size()==receipts and not offers[1].purchased,"failed recruit unchanged")
	t.return_map();verify(room.cleared and not room.consumed,"recruit clears on leaving but reenterable")
	t.select_room("0:0");verify(room.recruit.offers==offers and first.purchased,"revisit retains offers/purchase")
	t.guild.state.gold=1000;verify(t.content_action(&"reroll").ok and t.guild.state.gold==800 and room.recruit.revision==1,"reroll200")
	verify(room.recruit.offers[0].offer_id!=first.offer_id and room.recruit.offers.all(func(o):return not o.purchased),"reroll replaces purchase state")
	t.guild.state.gold=0;seed=t.content_rng.state;var revision: int=room.recruit.revision
	verify(not t.content_action(&"reroll").ok and t.content_rng.state==seed and room.recruit.revision==revision,"failed reroll RNG unchanged")
	t.return_map();t.guild.state.gold=10000;t.select_room("0:1");room=t.current_room()
	var stock: Array[ShopOffer]=room.shop.offers
	for category in [&"equipment",&"card"]:
		var kinds: Dictionary={}
		for offer in stock:
			if offer.category==category:kinds[offer.kind]=true
		verify(kinds.size() in [2,3],"shop distinct category kinds2..3")
	verify(stock.size()>=4 and stock.size()<=12,"shop individual stock copies4..12")
	var offer: ShopOffer=stock.filter(func(o):return o.category==&"equipment")[0];gold=t.guild.state.gold
	result=t.content_action(&"buy",{"offer_id":offer.offer_id})
	verify(result.ok and t.guild.state.gold==gold-offer.gold_price and t.content.inventory.get_item(result.outcome.item_id).kind==offer.kind,"shop buy exact cost/item")
	verify(not t.content_action(&"buy",{"offer_id":offer.offer_id}).ok,"sold duplicate refused")
	var card: ShopOffer=stock.filter(func(o):return o.category==&"card")[0];var cards: int=t.guild.state.strategy_cards.size()
	verify(t.content_action(&"buy",{"offer_id":card.offer_id}).ok and t.guild.state.strategy_cards.size()==cards+1,"shop card new instance")
	var unsold: ShopOffer=stock.filter(func(o):return not o.purchased)[0];t.guild.state.gold=0;seed=t.content_rng.state;receipts=t.guild.state.transaction_receipts.size()
	verify(not t.content_action(&"buy",{"offer_id":unsold.offer_id}).ok and t.content_rng.state==seed and t.guild.state.transaction_receipts.size()==receipts and not unsold.purchased,"shop failure atomic")
	t.return_map();verify(room.cleared and not room.consumed,"shop reenterable")
	t.select_room("0:1");verify(room.shop.offers==stock and offer.purchased,"shop stock persists")
	var a: ItemInstance=t.content.inventory.give(&"vital");var b: ItemInstance=t.content.inventory.give(&"vital")
	verify(a.item_id!=b.item_id,"same kind separate IDs")
	t.guild.state.gold=1000;t.guild.state.next_item_number=1;gold=t.guild.state.gold;seed=t.content_rng.state
	verify(not t.content_action(&"buy",{"offer_id":unsold.offer_id}).ok and t.guild.state.gold==gold and t.content_rng.state==seed,"invalid inventory cannot debit")
func equipment_growth() -> void:
	groups+=1
	var t:=tower();var member: GuildMemberState=t.guild.all_members()[0];var base: UnitData=t.guild.definition(0);member.current_hp=40
	var vital: ItemInstance=give(t,&"vital",member)
	verify(t.guild.member_stats(member).max_hp==180 and member.current_hp==40,"vital20% no free equip heal")
	var fang: ItemInstance=give(t,&"fang",member)
	verify(is_equal_approx(t.guild.member_stats(member).attack,1.15),"fang15% attack")
	var boots: ItemInstance=t.content.inventory.give(&"boots")
	verify(not t.content_action(&"equip",{"item_id":boots.item_id,"member_id":member.member_id}).ok and boots.equipped_to_member_id.is_empty(),"two slots enforce")
	verify(not t.content_action(&"equip",{"item_id":vital.item_id,"member_id":t.guild.all_members()[1].member_id}).ok,"no move/double equip")
	member.stars=1;verify(t.content_action(&"equip",{"item_id":boots.item_id,"member_id":member.member_id}).ok,"one star three slots")
	verify(is_equal_approx(t.guild.member_stats(member).speed,base.move_speed*1.1),"stars + boots speed (no star stats)")
	member.stars=2;give(t,&"boots",member)
	verify(GuildMemberCombatStats.equipment_limit(member)==4 and is_equal_approx(t.guild.member_stats(member).speed,base.move_speed*1.21),"two stars4 slots /boots multiply")
	var ids: Array=t.content.inventory.equipped(member.member_id).map(func(i):return i.item_id)
	var recovery: ItemInstance=t.content.inventory.give(&"reengrave")
	verify(t.content_action(&"equip",{"item_id":recovery.item_id,"member_id":member.member_id}).ok and recovery.consumed,"reengrave consumes")
	verify(ids.all(func(id):return t.content.inventory.get_item(id).equipped_to_member_id.is_empty()) and not t.content_action(&"equip",{"item_id":recovery.item_id,"member_id":member.member_id}).ok,"returns same IDs once")
	member.stars=0;member.current_hp=0;give(t,&"greenNecklace",member);give(t,&"greenNecklace",member)
	verify(is_equal_approx(t.guild.member_stats(member).healing_power,1.21) and member.current_hp==0,"dead equip permitted /necklace multiplication")
	t.guild.state.gold=10000
	var result: Dictionary=t.content_action(&"upgrade",{"member_id":member.member_id})
	verify(result.ok and member.total_exp==100 and member.level==1 and GrowthRules.exp_progress(member.total_exp)==20 and is_equal_approx(member.current_hp,18*1.21) and t.guild.state.gold==9900,"one 100 EXP pack: dead unit levels and revives with incoming healing, excess kept")
	verify(t.content_action(&"level_up",{"member_id":member.member_id}).ok and member.level==2 and member.total_exp==200 and t.guild.state.gold==9800,"instant level-up buys the one pack still needed")
	while member.level<10:verify(t.content_action(&"level_up",{"member_id":member.member_id}).ok,"level-up repeats")
	verify(member.level==10 and 10000-t.guild.state.gold==member.total_exp and member.total_exp>=1700 and member.total_exp<1800,"gold buys EXP 1:1 in 100 packs; overshoot stays as progress")
	var stats: UnitCombatStats=t.guild.member_stats(member)
	verify(stats.max_hp==330 and is_equal_approx(stats.attack,1) and is_equal_approx(stats.physical_damage,UnitStatTable.base_physical(0)*1.8) and is_equal_approx(stats.magic_damage,UnitStatTable.base_magic(0)*1.8) and is_equal_approx(stats.defense,UnitStatTable.base_defense(0)*1.8) and is_equal_approx(stats.speed,base.move_speed*1.2),"linear growth hp12/atk8/def8/speed2")
	var gold: int=t.guild.state.gold;var packs: int=GrowthRules.packs_to_level(member.total_exp)
	verify(t.content_action(&"level_up",{"member_id":member.member_id}).ok and member.level==11 and gold-t.guild.state.gold==packs*100,"no level cap; level-up spends packs x 100 G")
	verify(t.guild.member_stats(member).max_hp==348,"growth keeps scaling past 10 (hp +12%/level)")
	var other: GuildMemberState=t.guild.all_members()[1];t.guild.state.gold=0;var hp: float=other.current_hp
	verify(not t.content_action(&"upgrade",{"member_id":other.member_id}).ok and other.current_hp==hp and other.level==0,"failed upgrade unchanged")
	var bomber: GuildMemberState=t.guild.create_member(13);bomber.current_hp=0;bomber.character_specific_state={"bomberRush":true,"bomberRushTime":4,"bomberFuse":1};t.guild.state.gold=100
	verify(t.content_action(&"upgrade",{"member_id":bomber.member_id}).ok and bomber.is_alive() and bomber.character_specific_state.bomberFuse==null,"dead bomber upgrade cleanup")
func growth_rules() -> void:
	groups+=1
	verify(GrowthRules.exp_to_next(0)==80 and GrowthRules.exp_to_next(9)==260 and GrowthRules.exp_for_level(10)==1700,"EXP per level = 80 + 20L, same as the old gold cost")
	verify(GrowthRules.level_for_exp(1699)==9 and GrowthRules.level_for_exp(1700)==10 and GrowthRules.exp_progress(1750)==50,"level and in-level progress from total EXP")
	verify(GrowthRules.EXP_PACK==100 and GrowthRules.pack_cost()==100 and GrowthRules.packs_to_level(GrowthRules.exp_for_level(3)+50)==1 and GrowthRules.packs_to_level(GrowthRules.exp_for_level(5))==2,"EXP sold in 100 packs; level-up buys ceil(missing/100)")
	var m:=GuildMemberState.new();m.level=7;verify(m.total_exp==GrowthRules.exp_for_level(7) and m.level==7,"setting a level stores its cumulative EXP")
	var t:=tower();t.guild.state.gold=10000;var limits: Array=[];var spent: Array=[]
	verify(GrowthRules.sortie_limit(t.guild.state)==3,"three units sortie by default")
	for i in range(5):
		var gold: int=t.guild.state.gold;var result: Dictionary=t.content_action(&"sortie_upgrade")
		limits.append(result.outcome.sortie_limit if result.ok else -1);spent.append(gold-t.guild.state.gold)
	verify(limits==[4,5,6,7,8] and spent==[500,800,1200,1700,2300],"five sortie upgrades: 500/800/1200/1700/2300 G, +1 each")
	var gold: int=t.guild.state.gold
	verify(not t.content_action(&"sortie_upgrade").ok and t.guild.state.gold==gold and GrowthRules.sortie_limit(t.guild.state)==8,"sortie tops out at eight")
	t=tower();t.guild.state.gold=499;verify(not t.content_action(&"sortie_upgrade").ok and t.guild.state.sortie_level==0,"sortie upgrade needs the gold")
func promotion() -> void:
	groups+=1
	for seed in range(12):
		var e:=TowerController.new();e.new_run(seed+3,seed+5);e.select_room("0:4")
		verify(e.current_room().event_type in [&"prediction",&"hotSpring",&"supply"],"promotion is no longer an event room")
	var t:=tower();t.guild.state.gold=10000
	var members: Array=[t.guild.all_members()[0],t.guild.all_members()[1],t.guild.create_member(0)]
	var lead: GuildMemberState=members[0]
	members[0].level=3;members[1].level=1;members[2].total_exp=50
	members[0].current_hp=100;members[1].current_hp=60;members[2].current_hp=20
	var sword: ItemInstance=give(t,&"woodSword",lead)
	var ancient: ItemInstance=give(t,&"phoenixFeather",members[1]);var staff: ItemInstance=give(t,&"staff",members[1])
	var rare: ItemInstance=give(t,ItemCatalog.combined_kind(&"ether",&"redThorn"),members[2]);var feather: ItemInstance=give(t,&"hawkFeather",members[2])
	t.guild.state.last_formation.capture([DeploymentEntry.new(lead.member_id,Vector2(100,100)),DeploymentEntry.new(members[1].member_id,Vector2(100,200)),DeploymentEntry.new(members[2].member_id,Vector2(100,300))])
	var before: int=t.guild.all_members().size();var other: GuildMemberState=t.guild.create_member(1)
	verify(t.content.promotion_eligible(lead) and not t.content.promotion_eligible(other),"three same-character same-star units, no level gate")
	verify(not t.content_action(&"promote",{"member_id":lead.member_id,"materials":[members[1].member_id]}).ok,"needs two materials")
	verify(not t.content_action(&"promote",{"member_id":lead.member_id,"materials":[members[1].member_id,other.member_id]}).ok,"different character rejected")
	verify(not t.content_action(&"promote",{"member_id":lead.member_id,"materials":[members[1].member_id,members[1].member_id]}).ok,"duplicate material rejected")
	members[2].current_hp=0
	verify(not t.content_action(&"promote",{"member_id":lead.member_id,"materials":[members[1].member_id,members[2].member_id]}).ok,"dead material rejected")
	members[2].current_hp=20
	t.guild.state.guild_members.erase(other.member_id);before=t.guild.all_members().size()
	var result: Dictionary=t.content_action(&"promote",{"member_id":lead.member_id,"materials":[members[1].member_id,members[2].member_id]})
	verify(result.ok and t.guild.get_member(lead.member_id)==lead and lead.stars==1 and t.guild.all_members().size()==before-2,"lead kept, two consumed")
	verify(lead.total_exp==300+80+50+GrowthRules.PROMOTION_BONUS_EXP and lead.level==GrowthRules.level_for_exp(lead.total_exp) and lead.level==5,"EXP pooled plus bonus, level recomputed")
	verify(is_equal_approx(lead.current_hp,60),"HP becomes the three units' average")
	var worn: Array=t.content.inventory.equipped(lead.member_id)
	verify(worn.size()==3 and ancient in worn and rare in worn,"ancient then rare fill the free slots first")
	verify(sword.consumed and worn.any(func(i):return ItemCatalog.get_item(i.kind).components.has(&"woodSword")),"a basic fused with the lead's basic as it was equipped")
	var leftover: Array=[staff,feather].filter(func(i):return not i.consumed)
	verify(leftover.size()==1 and leftover[0].equipped_to_member_id.is_empty(),"gear without a free slot goes back to the inventory")
	verify(t.guild.state.last_formation.entries.size()==1 and t.guild.state.last_formation.entries[0].member_id==lead.member_id,"formation removes consumed IDs")
	var count: int=t.guild.all_members().size();verify(not t.content_action(&"promote",{"member_id":lead.member_id,"materials":[members[1].member_id,members[2].member_id]}).ok and t.guild.all_members().size()==count,"consumed materials cannot promote again")
	# Second star: four slots; the average HP is capped by the new maximum; stars stop at two.
	t=tower();members=[t.guild.all_members()[0],t.guild.all_members()[1],t.guild.create_member(0)]
	for m in members:m.stars=1;m.level=10;m.current_hp=9999
	verify(t.content_action(&"promote",{"member_id":members[0].member_id,"materials":[members[1].member_id,members[2].member_id]}).ok and members[0].stars==2 and GuildMemberCombatStats.equipment_limit(members[0])==4,"second star /four slots")
	verify(members[0].current_hp==t.guild.member_stats(members[0]).max_hp,"average HP capped at the new maximum")
	var more: Array=[t.guild.create_member(0),t.guild.create_member(0)]
	for m in more:m.stars=2
	verify(not t.content.promotion_eligible(members[0]) and not t.content_action(&"promote",{"member_id":members[0].member_id,"materials":[more[0].member_id,more[1].member_id]}).ok,"highest star rejected")
func rest_events() -> void:
	groups+=1
	for choice in [&"player",&"resources",&"guild",&"revive"]:
		var t:=tower();t.guild.state.player_hp=50;var m: GuildMemberState=t.guild.all_members()[0];var reserve: GuildMemberState=t.guild.all_members()[1]
		m.current_hp=40;m.energy=1;reserve.current_hp=0
		give(t,&"greenNecklace",m)
		var gold: int=t.guild.state.gold;var tokens: int=t.guild.state.tokens;t.select_room("0:2")
		var result: Dictionary=t.content_action(&"rest",{"choice":choice,"members":[reserve.member_id]})
		verify(result.ok and t.current_room().cleared and t.current_room().consumed,"rest single completion "+String(choice))
		match choice:
			&"player":verify(t.guild.state.player_hp==65,"rest player15")
			&"resources":verify(t.guild.state.gold==gold+50+350 and t.guild.state.tokens==tokens+1,"rest350/1")
			&"guild":verify(is_equal_approx(m.current_hp,40+150*.35*1.1) and reserve.current_hp==0 and m.energy==1,"rest living35 incoming bonus, no energy")
			&"revive":verify(reserve.current_hp==30 and reserve.energy==5,"rest dead20%, no energy change")
		t.select_room("0:2");verify(t.guild.state.tower.phase==&"cleared" and not t.content_action(&"rest",{"choice":choice}).ok,"consumed rest view only")
	var t:=tower();t.guild.all_members()[0].current_hp=0;t.guild.all_members()[1].current_hp=0;t.select_room("0:2")
	verify(not t.content_action(&"rest",{"choice":&"revive","members":[t.guild.all_members()[0].member_id,t.guild.all_members()[0].member_id]}).ok,"duplicate revive IDs reject")
	var m: GuildMemberState=t.guild.all_members()[0];t.return_map();m.current_hp=40;m.energy=0;give(t,&"greenNecklace",m)
	enter_event(t,&"hotSpring")
	verify(not t.return_map() and not t.new_run(9,1),"active event locks map/newrun")
	verify(t.content_action(&"event",{"choice":&"bathe"}).ok and is_equal_approx(m.current_hp,56.5) and m.energy==0,"hotSpring living10% with incoming healing, no energy")
	verify(t.guild.all_members()[1].current_hp==0 and t.guild.all_members()[1].energy==5,"bathe dead unaffected")
	verify(t.return_map(),"resolved event allows map")
	var rewards: Dictionary={}
	for seed_value in range(100):
		t=tower();enter_event(t,&"hotSpring");t.content_rng.seed=seed_value;var before: int=t.guild.state.gold
		var result: Dictionary=t.content_action(&"event",{"choice":&"lottery"})
		verify(result.ok and t.current_room().event.resolved and t.current_room().consumed,"lottery one completion")
		var reward: StringName=result.outcome.reward;rewards[reward]=true
		if String(reward).begins_with("gold"):verify(t.guild.state.gold==before-200+int(String(reward).trim_prefix("gold")),"lottery gold exact")
		elif reward==&"tokens":verify(t.guild.state.gold==before-200 and t.guild.state.tokens==8,"lottery3tokens")
		elif reward==&"unit":verify(t.guild.all_members().size()==5,"lottery recruits individual")
		elif reward==&"strategy":verify(t.guild.state.strategy_cards.size()==5,"lottery card")
		else:verify(t.content.inventory.available().size()==(2 if reward==&"items" else 1),"lottery item copies")
		before=t.guild.state.gold;var random_state: int=t.content_rng.state
		verify(not t.content_action(&"event",{"choice":&"lottery"}).ok and t.guild.state.gold==before and t.content_rng.state==random_state,"repeat lottery unchanged")
	verify(rewards.size()==9,"all nine actual lottery outcomes covered")
	t=tower();enter_event(t,&"hotSpring");t.guild.state.gold=199;var random_state: int=t.content_rng.state
	verify(not t.content_action(&"event",{"choice":&"lottery"}).ok and t.guild.state.gold==199 and t.content_rng.state==random_state and not t.current_room().cleared,"insufficient lottery no RNG/receipt")
	for choice in [&"heal",&"guild",&"gold",&"loot"]:
		t=tower();t.guild.state.player_hp=40;m=t.guild.all_members()[0];m.current_hp=30;m.energy=0
		enter_event(t,&"supply");var event: EventState=t.current_room().event;var kind: StringName=event.treasure_kind;var selected: StringName=event.treasure_reward
		var result: Dictionary=t.content_action(&"event",{"choice":choice})
		verify(result.ok and t.current_room().cleared and t.current_room().consumed,"supply single choice")
		match choice:
			&"heal":verify(t.guild.state.player_hp==50,"supply player10")
			&"guild":verify(m.current_hp==45 and m.energy==0,"supply living10%, no energy")
			&"gold":verify(t.guild.state.gold==1550 and t.guild.state.tokens==6,"supply300/1 + discovery50")
			&"loot":verify(t.content.inventory.available().any(func(i):return i.kind==selected) if kind==&"item" else t.guild.state.strategy_cards.any(func(c):return c.kind==selected),"preselected loot actual pool")
	t=tower();enter_event(t,&"supply");verify(t.abandon(true) and t.guild.state.game_over,"web allows abandon from active event before prediction battle")
func rewards_transactions() -> void:
	groups+=1
	var t:=tower();var member: GuildMemberState=t.guild.all_members()[0];give(t,&"greenNecklace",member);member.current_hp=0;member.energy=0
	var floor: FloorState=t.guild.state.tower.map.floors[0];floor.bonus=&"heal"
	for id in floor.room_ids:t.guild.state.tower.map.get_room(id).cleared=true
	t.refresh_progress(0);verify(member.current_hp==33 and member.energy==0,"conquest20% revives with incoming1.1, no energy")
	t=tower();floor=t.guild.state.tower.map.floors[0];floor.bonus=&"item";floor.bonus_item_kind=&"vigorTotem"
	for id in floor.room_ids:t.guild.state.tower.map.get_room(id).cleared=true
	t.refresh_progress(0);verify(t.content.inventory.available().size()==1 and t.guild.state.tower.reward_requests[0].fulfilled,"conquest item given immediately once")
	t.process_reward_requests();t.refresh_progress(0);verify(t.content.inventory.available().size()==1,"reward receipt prevents rerender duplicate")
	var request:=RewardRequest.new();request.reward_id="other";request.kind=&"item";request.item_kind=&"fang"
	verify(t.content.inventory.consume_reward(request) and not t.content.inventory.consume_reward(request),"RewardRequest single fulfill")
	var run: RunState=t.guild.state;var gold: int=run.gold
	verify(ResourceTransaction.spend(run,10,1,"test") and not ResourceTransaction.spend(run,10,1,"test") and run.gold==gold-10,"transaction single receipt")
	var receipts: int=run.transaction_receipts.size();verify(not ResourceTransaction.spend(run,-1,0,"negative") and run.transaction_receipts.size()==receipts,"negative resource transaction refuses")
	# Completion cannot be forged from a UI-created result object.
	var forged:=RoomContentResult.new();forged.room_id="0:2";forged.receipt="fake"
	verify(not t.complete_room_content("0:2",forged),"unissued completion rejected")
func prediction() -> void:
	groups+=1
	var rng:=RandomNumberGenerator.new();rng.seed=73
	for i in range(30):
		var state: PredictionState=PredictionRules.create(rng);verify(state.teams.size() in [2,3],"prediction2/3 teams")
		for team in state.teams:verify(team.types.size() in [2,3] and team.types.all(func(type):return type>=0 and type<26),"prediction actual types/size")
	for verdict in [&"correct",&"incorrect",&"draw"]:
		var t:=tower();enter_event(t,&"prediction");var event: EventState=t.current_room().event;var state: PredictionState=event.prediction
		verify(not t.return_map() and not t.choose_prediction_stake(51),"prediction navigation/invalid stake")
		verify(t.choose_prediction_team(0) and t.choose_prediction_stake(50),"independent team/stake selection")
		var gold: int=t.guild.state.gold;var hp: float=t.guild.state.player_hp;var member_hp: float=t.guild.all_members()[0].current_hp
		var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
		verify(t.start_prediction(b) and t.guild.state.gold==gold-50 and not t.return_map() and not t.abandon(true),"stake paid /no exit during watch")
		verify(b.common_combat_enabled and b.full_characters_enabled and b.turning==null and b.units.all(func(u):return u.source_member_id.is_empty()),"isolated full prediction battle")
		for u in b.units:
			if verdict==&"draw" or u.original_team!=(0 if verdict==&"correct" else 1):u.receive_damage(10000,b.units[0])
		b.check_outcome()
		verify(state.result==verdict and t.current_room().cleared and t.current_room().consumed,"actual battle verdict clears event")
		verify(t.guild.state.gold==gold-50+(100 if verdict==&"correct" else 50 if verdict==&"draw" else 0) and t.guild.state.tokens==5+int(verdict==&"correct"),"prediction payout actual")
		verify(t.guild.state.player_hp==hp and t.guild.all_members()[0].current_hp==member_hp and t.guild.all_members()[0].energy==5,"spectator battle cannot damage/settle guild")
		var paid: int=t.guild.state.gold;t._prediction_finished(b.result);verify(t.guild.state.gold==paid,"prediction duplicate ignored")
		verify(t.return_map(),"resolved prediction returns map");b.free()
func combat() -> void:
	groups+=1
	var t:=tower();var members: Array=t.guild.all_members();var m: GuildMemberState=members[0];var friend: GuildMemberState=members[1]
	m.level=2;m.stars=1;give(t,&"greenNecklace",m);give(t,&"vigorTotem",m);give(t,&"greenNecklace",friend)
	t.select_room("0:3");var b:=create_battle(t,[m.member_id,friend.member_id]);var u: BattleUnit=b.units[0];var a: BattleUnit=b.units[1];var stats: UnitCombatStats=t.guild.member_stats(m)
	verify(u.max_hp==stats.max_hp and is_equal_approx(u.attack_power,stats.physical_damage*stats.attack) and u.defense_power==stats.defense and u.data==t.guild.definition(0),"level/star/gear derived Unit stats")
	u.current_hp=100;a.current_hp=50;u.position=Vector2(100,300);a.position=Vector2(200,300)
	EquipmentCombatEffects.advance(u,5)
	verify(is_equal_approx(u.current_hp,100+3.6*1.1*1.1) and is_equal_approx(a.current_hp,50+6*1.1*1.1),"totem self/outgoing/incoming math")
	CharacterAbility.restore_hp(u,10,u);verify(is_equal_approx(u.current_hp,100+3.6*1.21+10*1.21),"self heal double multiplier")
	u.current_hp=40;b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2)
	var clock: float=u.state_value("totemClock");var hp: float=u.current_hp;b.simulate(1)
	verify(u.state_value("totemClock")==clock and u.current_hp==hp,"hold freezes totem")
	var card: StrategyCardInstance=t.guild.state.strategy_cards[0];b.turning.current.selected_member_id=m.member_id;b.turning.select_card(card.card_id)
	verify(b.turning.use_selected_card().get("code")==StrategyCardExecutor.Code.OK and is_equal_approx(u.current_hp,40+u.max_hp*.3*1.1),"mango through real gear healing")
	u.transcendence_gauge=100;u.ultimate.cast.clear();u.stun_remaining=0;u.combat.cancel(u)
	verify(b.transcendence.begin(u,Vector2.ZERO),"manual transcend aim")
	clock=u.state_value("totemClock");b.simulate(.5);verify(u.state_value("totemClock")==clock,"transcendence freezes totem")
	b.transcendence.release(true);b.turning.resolve();u.current_hp=100
	for enemy in b.units:
		if enemy.original_team==1:enemy.receive_damage(10000,u)
	b.check_outcome()
	verify(is_equal_approx(m.current_hp,100) and b.result.final_hp_by_member_id[m.member_id]==m.current_hp,"no victory heal; snapshot keeps battle HP")
	b.free()
	# Charge totem + CC blocks, first battle awl, permanent fangs and retry.
	t=tower();m=t.guild.all_members()[0];friend=t.guild.all_members()[1];give(t,&"chargeTotem",m);give(t,&"thickAwl",m);give(t,&"predatorFang",friend);give(t,&"predatorFang",friend)
	t.select_room("0:5");b=create_battle(t,[m.member_id,friend.member_id]);u=b.units[0];a=b.units[1]
	verify(b.projectiles.filter(func(p):return p.kind=="openingAwl").size()==1,"opening awl first attempt once")
	var awl: BattleProjectile=b.projectiles.filter(func(p):return p.kind=="openingAwl")[0]
	verify(awl.velocity==Vector2(1050,0) and awl.hit_radius==28 and awl.power==45 and awl.lifetime==1.1,"exact awl parameters")
	var enemy: BattleUnit=b.units[2];enemy.parry_remaining=0;enemy.invincible_remaining=0;var enemy_hp: float=enemy.current_hp
	ProjectileRules.hit(awl,enemy);verify(enemy.stun_remaining==4 and enemy.current_hp==enemy_hp,"awl stuns4 no damage")
	u.position=Vector2(100,300);a.position=Vector2(200,300);u.ultimate_gauge=0;a.ultimate_gauge=0;a.stun_remaining=2
	EquipmentCombatEffects.advance(u,4);verify(u.ultimate_gauge==2.4 and a.ultimate_gauge==0,"charge self2.4/CC blocks ally")
	a.stun_remaining=0;EquipmentCombatEffects.advance(u,4);verify(u.ultimate_gauge==4.8 and a.ultimate_gauge==4,"charge ally4")
	var base_attack: float=a.attack_power;enemy.receive_damage(10000,a)
	verify(a.equipment_fang_kills==2 and is_equal_approx(a.attack_power,base_attack*1.03),"two fangs linear +3% on kill")
	b.clock.elapsed=20;verify(t.session.request_retreat(),"gear retreat")
	verify(friend.fang_kills==2 and t.content.inventory.equipped(friend.member_id).size()==2,"fang/ownership persists")
	t.return_map();t.select_room("0:5");b.free();b=create_battle(t,[m.member_id,friend.member_id])
	verify(not b.projectiles.any(func(p):return p.kind=="openingAwl") and is_equal_approx(b.units[1].attack_power,base_attack*1.03),"retry skips awl but retains growth")
	b.free()
	# Healer's actual windup release applies both equipped healing factors.
	t=tower();var healer: GuildMemberState=t.guild.all_members()[3];m=t.guild.all_members()[0]
	give(t,&"greenNecklace",healer);give(t,&"greenNecklace",m);give(t,&"vigorTotem",m)
	t.select_room("0:3");b=create_battle(t,[healer.member_id,m.member_id]);u=b.units[0];a=b.units[1]
	u.position=Vector2(100,300);a.position=Vector2(200,300);a.current_hp=30
	u.combat.start_heal(u,a);u.combat.advance(u,2,b)
	verify(is_equal_approx(a.current_hp,30+22*1.21),"actual healer release outgoing/incoming necklace")
	# Web equipment loop is alive/faction based, even while a frog carries the ally.
	u.current_hp=20;u.frog_carrier=a.actor_id();EquipmentCombatEffects.advance(a,5)
	verify(is_equal_approx(u.current_hp,20+6*1.21),"totem includes living swallowed ally")
	b.clock.elapsed=20;verify(t.session.request_retreat(),"heal/totem retreat");b.free()
	# Golden token applies only to participating survivors on FIRST victory.
	t=tower();m=t.guild.all_members()[0];give(t,&"goldToken",m);give(t,&"goldToken",m);t.select_room("0:3");b=create_battle(t)
	var gold: int=t.guild.state.gold
	for gold_enemy in b.units:
		if gold_enemy.original_team==1:gold_enemy.receive_damage(10000,b.units[0])
	var kill_gold: int=t.guild.state.gold-gold;b.check_outcome()
	verify(t.guild.state.gold==gold+kill_gold+t.current_room().gold_reward+80,"two golden tokens +80 victory")
	gold=t.guild.state.gold;t._settled(b.result,BattleSettlement.Status.APPLIED);verify(t.guild.state.gold==gold,"battle rewards not duplicated by content")
	b.free()
func invalid_operations() -> void:
	groups+=1
	var t:=tower();t.select_room("0:1");var offer: ShopOffer=t.current_room().shop.offers[0];offer.category=&"invalid"
	var gold: int=t.guild.state.gold;var rng_state: int=t.content_rng.state
	verify(not t.content_action(&"buy",{"offer_id":offer.offer_id}).ok and t.guild.state.gold==gold and t.content_rng.state==rng_state,"invalid stock category transaction unchanged")
	t=tower();enter_event(t,&"prediction");t.choose_prediction(0,50)
	t.current_room().event.prediction.teams[0].types=[999];var combat_state: int=t.combat_rng.state;gold=t.guild.state.gold
	var b:=BattleManager.new();b.auto_start=false;host.root.add_child(b)
	verify(not t.start_prediction(b) and t.combat_rng.state==combat_state and t.guild.state.gold==gold and t.guild.state.transaction_receipts.is_empty(),"invalid prediction fails atomically including combat RNG")
	b.free();t=tower()
	for member in t.guild.all_members():member.current_hp=0
	verify(not t.content_action(&"upgrade",{"member_id":t.guild.all_members()[0].member_id}).ok and t.guild.state.game_over,"content does not revive a gameover guild")
func run(tree: SceneTree) -> void:
	host=tree;golden();recruit_shop();equipment_growth();growth_rules();promotion();rest_events();rewards_transactions();prediction();combat();invalid_operations()
	print("PHASE 10 RESULT: ",groups," groups; ",checks," checks; ",failures," failures")
