class_name TowerContentService
extends RefCounted
## Pure content operations. UI sends IDs; no Nodes stored in content state.
const REROLL_COST = 200
const HOT_SPRING_COST = 200
var guild: GuildManager
var rng: RandomNumberGenerator
var inventory: InventoryService
var pending_completions: Dictionary = {}
func _init(manager: GuildManager,random_source: RandomNumberGenerator) -> void:
	guild=manager;rng=random_source;inventory=InventoryService.new(guild.state)
func failure(code: StringName) -> Dictionary:return {"ok":false,"code":code}
func success(outcome: Dictionary={}) -> Dictionary:return {"ok":true,"code":&"ok","outcome":outcome}
func room() -> RoomState:return guild.state.tower.map.get_room(guild.state.tower.selected_room_id)
func live() -> bool:return not guild.state.game_over and guild.state.player_hp>0 and not guild.living_members().is_empty()
func valid_room(kind: StringName) -> bool:
	return live() and room()!=null and room().room_type==kind and guild.state.tower.phase==kind
func shuffle(values: Array) -> void:
	for i in range(values.size()-1,0,-1):
		var j: int=rng.randi_range(0,i);var v=values[i];values[i]=values[j];values[j]=v
func create_offers(node: RoomState,revision: int) -> Array[RecruitOffer]:
	var pool: Array=range(CharacterCatalog.NAMES.size());shuffle(pool);var offers: Array[RecruitOffer]=[]
	for slot in range(3):
		var offer:=RecruitOffer.new();offer.offer_id="%s:recruit:%d:%d"%[node.room_id,revision,slot];offer.unit_type_id=pool[slot];offer.token_price=guild.definition(offer.unit_type_id).recruit_tokens;offers.append(offer)
	return offers
func ensure_recruit(node: RoomState) -> void:
	if node.recruit!=null:return
	node.recruit=RecruitState.new();node.recruit.offers=create_offers(node,0)
func ensure_shop(node: RoomState) -> void:
	if node.shop!=null:return
	node.shop=ShopState.new()
	var items: Array=ItemCatalog.KINDS.duplicate();var cards: Array=StrategyCardCatalog.DEFINITIONS.keys()
	# Executable web evaluation draws count, then shuffles each pool.
	var count: int=rng.randi_range(2,3);shuffle(items);items=items.slice(0,count)
	count=rng.randi_range(2,3);shuffle(cards);cards=cards.slice(0,count)
	for category in [&"equipment",&"card"]:
		for kind in items if category==&"equipment" else cards:
			var quantity: int=2 if rng.randf()<.2 else 1
			for copy in range(quantity):
				var offer:=ShopOffer.new();offer.category=category;offer.kind=kind;offer.offer_id="%s:stock:%s:%s:%d"%[node.room_id,category,kind,copy]
				offer.gold_price=ItemCatalog.get_item(kind).gold_price if category==&"equipment" else StrategyCardCatalog.get_card(kind).gold_price
				node.shop.offers.append(offer)
func ensure_event(node: RoomState) -> void:
	if node.event!=null:return
	var event:=EventState.new();event.event_type=node.event_type;node.event=event
	match node.event_type:
		&"hotSpring":event.choices=[&"bathe",&"lottery"]
		&"supply":
			event.choices=[&"heal",&"guild",&"gold",&"loot"]
			event.treasure_kind=&"item" if rng.randf()<.5 else &"card"
			var pool: Array=ItemCatalog.KINDS.duplicate() if event.treasure_kind==&"item" else StrategyCardCatalog.DEFINITIONS.keys()
			event.treasure_reward=pool[rng.randi_range(0,pool.size()-1)]
		&"prediction":event.prediction=PredictionRules.create(rng)
func completion(choice: StringName,outcome: Dictionary={},stay: bool=false) -> Dictionary:
	var node: RoomState=room();var result:=RoomContentResult.new();result.room_id=node.room_id;result.choice=choice;result.outcome=outcome.duplicate(true);result.stay_for_result=stay
	result.receipt="%s:visit:%d:complete"%[node.room_id,node.content_visits]
	if guild.state.content_receipts.has(result.receipt) or pending_completions.has(result.receipt):return failure(&"already_completed")
	pending_completions[result.receipt]=result
	return {"ok":true,"code":&"ok","outcome":outcome,"completion":result}
func recruit(offer_id: String) -> Dictionary:
	if not valid_room(RoomType.RECRUIT):return failure(&"wrong_room")
	var offer: RecruitOffer=null
	for candidate in room().recruit.offers:
		if candidate.offer_id==offer_id:offer=candidate
	if offer==null:return failure(&"invalid_offer")
	if offer.purchased:return failure(&"purchased")
	if not ResourceTransaction.can_spend(guild.state,0,offer.token_price,offer.offer_id):return failure(&"funds")
	if guild.definition(offer.unit_type_id)==null:return failure(&"invalid_type")
	ResourceTransaction.spend(guild.state,0,offer.token_price,offer.offer_id)
	var member: GuildMemberState=guild.create_member(offer.unit_type_id);offer.purchased=true
	return success({"member_id":member.member_id,"tokens_spent":offer.token_price})
func reroll() -> Dictionary:
	if not valid_room(RoomType.RECRUIT):return failure(&"wrong_room")
	var receipt: String="%s:reroll:%d"%[room().room_id,room().recruit.revision+1]
	if not ResourceTransaction.can_spend(guild.state,200,0,receipt):return failure(&"funds")
	var offers: Array[RecruitOffer]=create_offers(room(),room().recruit.revision+1)
	ResourceTransaction.spend(guild.state,200,0,receipt);room().recruit.revision+=1;room().recruit.offers=offers
	return success({"gold_spent":200})
func buy(offer_id: String) -> Dictionary:
	if not valid_room(RoomType.SHOP):return failure(&"wrong_room")
	if not inventory.valid():return failure(&"invalid_inventory")
	var offer: ShopOffer=null
	for candidate in room().shop.offers:
		if candidate.offer_id==offer_id:offer=candidate
	if offer==null:return failure(&"invalid_offer")
	if offer.purchased:return failure(&"sold")
	if offer.category not in [&"equipment",&"card"]:return failure(&"invalid_item")
	if offer.category==&"equipment" and ItemCatalog.get_item(offer.kind)==null or offer.category==&"card" and StrategyCardCatalog.get_card(offer.kind)==null:return failure(&"invalid_item")
	if not ResourceTransaction.can_spend(guild.state,offer.gold_price,0,offer.offer_id):return failure(&"funds")
	ResourceTransaction.spend(guild.state,offer.gold_price,0,offer.offer_id);offer.purchased=true
	if offer.category==&"equipment":return success({"item_id":inventory.give(offer.kind,"shop:"+offer.offer_id).item_id,"gold_spent":offer.gold_price})
	return success({"card_id":guild.state.give_strategy_card(offer.kind).card_id,"gold_spent":offer.gold_price})
## Equipment and upgrades are open whenever no battle is running: on the map, while deploying
## and inside any content room (shop, recruit, rest, events).
const MANAGE_PHASES = [&"route",&"deploy",&"shop",&"recruit",&"rest",&"event_active",&"content_result",&"cleared"]
func can_manage() -> bool:return live() and guild.state.tower.phase in MANAGE_PHASES
func equip(item_id: int,member_id: String) -> Dictionary:
	if not can_manage():return failure(&"management_locked")
	if not inventory.valid():return failure(&"invalid_inventory")
	var member: GuildMemberState=guild.get_member(member_id);var instance: ItemInstance=inventory.get_item(item_id)
	if member==null or instance==null or instance.consumed:return failure(&"invalid_target")
	var item: ItemData=ItemCatalog.get_item(instance.kind)
	if item==null or not instance.equipped_to_member_id.is_empty():return failure(&"equipped")
	var equipment: Array[ItemInstance]=inventory.equipped(member_id)
	if item.consumable:
		if instance.kind!=&"reengrave" or equipment.is_empty():return failure(&"no_equipment")
		for gear in equipment:gear.equipped_to_member_id=""
		instance.consumed=true;member.current_hp=minf(member.current_hp,guild.member_stats(member).max_hp)
		return success({"returned_items":equipment.map(func(i):return i.item_id)})
	# Like auto-chess: a basic item meeting another basic on the same unit fuses into one rare item.
	var partner: ItemInstance=null
	if item.grade==&"common":
		for gear in equipment:
			if ItemCatalog.get_item(gear.kind).grade==&"common":partner=gear;break
	if partner==null and equipment.size()>=GuildMemberCombatStats.equipment_limit(member):return failure(&"slots_full")
	var state: Dictionary=member.character_specific_state
	var stats: UnitCombatStats=guild.member_stats(member)
	if partner!=null:
		var receipt: String="combine:%d:%d"%[partner.item_id,instance.item_id]
		partner.equipped_to_member_id="";partner.consumed=true;instance.consumed=true
		var made: ItemInstance=inventory.give(ItemCatalog.combined_kind(partner.kind,instance.kind),receipt)
		item=ItemCatalog.get_item(made.kind);instance=made
		stats=guild.member_stats(member)
	if item.vigor_totem and stats.vigor_totem_count==0:state["totemClock"]=5
	if item.charge_totem and stats.charge_totem_count==0:state["chargeTotemClock"]=4
	member.character_specific_state=state;instance.equipped_to_member_id=member_id
	if partner!=null:return success({"item_id":instance.item_id,"member_id":member_id,"combined":instance.kind,"components":[partner.item_id,item_id]})
	return success({"item_id":item_id,"member_id":member_id})
func upgrade(member_id: String) -> Dictionary:
	if not inventory.valid():return failure(&"invalid_inventory")
	if not can_manage():return failure(&"management_locked")
	var member: GuildMemberState=guild.get_member(member_id)
	if member==null:return failure(&"invalid_member")
	# Gold buys the experience still missing for the next level.
	var gained: int=GrowthRules.exp_to_next(member.level)-GrowthRules.exp_progress(member.total_exp)
	var cost: int=GuildMemberCombatStats.upgrade_cost(member);var receipt: String="upgrade:%s:%d:%d"%[member_id,member.stars,member.total_exp]
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	var old_max: float=guild.member_stats(member).max_hp;var dead: bool=not member.is_alive()
	ResourceTransaction.spend(guild.state,cost,0,receipt);member.total_exp+=gained
	var gain: float=GuildMemberCombatStats.heal(guild,member,maxf(0,guild.member_stats(member).max_hp-old_max),true)
	if dead and member.unit_type_id==13:GuildMemberCombatStats.reset_bomber(member)
	return success({"level":member.level,"exp_gained":gained,"hp_gained":gain,"gold_spent":cost})
func upgrade_sortie() -> Dictionary:
	if not can_manage():return failure(&"management_locked")
	var cost: int=GrowthRules.sortie_cost(guild.state)
	if cost<0:return failure(&"max_sortie")
	var receipt: String="sortie:%d"%guild.state.sortie_level
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	ResourceTransaction.spend(guild.state,cost,0,receipt);guild.state.sortie_level+=1
	return success({"sortie_limit":GrowthRules.sortie_limit(guild.state),"gold_spent":cost})
func finish() -> Dictionary:
	if not live() or room()==null:return failure(&"run_ended")
	if valid_room(RoomType.RECRUIT) or valid_room(RoomType.SHOP):return completion(&"close")
	return failure(&"unfinished_content")
func rest(choice: StringName,members: Array=[]) -> Dictionary:
	if not valid_room(RoomType.REST) or room().cleared:return failure(&"wrong_room")
	var out: Dictionary={"choice":choice}
	match choice:
		&"player":
			var before: float=guild.state.player_hp;guild.state.player_hp+=15;out["player_hp_gained"]=guild.state.player_hp-before
		&"resources":guild.state.gold+=350;guild.state.tokens+=1;out["gold"]=350;out["tokens"]=1
		&"guild":
			for member in guild.living_members():GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.35)
		&"revive":
			if members.size()<1 or members.size()>2:return failure(&"invalid_selection")
			var seen: Dictionary={}
			for id in members:
				var member: GuildMemberState=guild.get_member(id)
				if member==null or member.is_alive() or seen.has(id):return failure(&"invalid_selection")
				seen[id]=true
			for id in members:
				var member: GuildMemberState=guild.get_member(id);GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.2,true);GuildMemberCombatStats.reset_bomber(member)
			out["revived"]=members.duplicate()
		_:return failure(&"invalid_choice")
	return completion(choice,out)
func event(choice: StringName) -> Dictionary:
	if not live() or room()==null or guild.state.tower.phase!=&"event_active" or room().cleared or room().event==null or room().event.resolved:return failure(&"wrong_event")
	var e: EventState=room().event;var outcome: Dictionary={"choice":choice}
	if not choice in e.choices:return failure(&"invalid_choice")
	if e.event_type==&"hotSpring":
		if choice==&"bathe":
			for member in guild.living_members():GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.1)
		else:
			if not inventory.valid():return failure(&"invalid_inventory")
			var receipt: String=room().room_id+":lottery"
			if not ResourceTransaction.can_spend(guild.state,200,0,receipt):return failure(&"funds")
			var rewards: Array=[&"item",&"items",&"gold250",&"tokens",&"gold500",&"strategy",&"unit",&"gold100",&"gold300"]
			var reward: StringName=rewards[rng.randi_range(0,rewards.size()-1)]
			ResourceTransaction.spend(guild.state,200,0,receipt);outcome["reward"]=reward
			match reward:
				&"item",&"items":
					var ids: Array=[]
					for i in range(2 if reward==&"items" else 1):ids.append(inventory.give(ItemCatalog.KINDS[rng.randi_range(0,9)]).item_id)
					outcome["items"]=ids
				&"strategy":
					var kinds: Array=StrategyCardCatalog.DEFINITIONS.keys();outcome["card_id"]=guild.state.give_strategy_card(kinds[rng.randi_range(0,kinds.size()-1)]).card_id
				&"unit":outcome["member_id"]=guild.create_member(rng.randi_range(0,25)).member_id
				&"tokens":guild.state.tokens+=3;outcome["tokens"]=3
				_:var gold: int=int(String(reward).trim_prefix("gold"));guild.state.gold+=gold;outcome["gold"]=gold
	elif e.event_type==&"supply":
		match choice:
			&"heal":guild.state.player_hp+=10
			&"guild":
				for member in guild.living_members():GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.1)
			&"gold":guild.state.gold+=300;guild.state.tokens+=1;outcome["gold"]=300;outcome["tokens"]=1
			&"loot":
				if not inventory.valid():return failure(&"invalid_inventory")
				if e.treasure_kind==&"item":outcome["item_id"]=inventory.give(e.treasure_reward,"treasure:"+room().room_id).item_id
				else:outcome["card_id"]=guild.state.give_strategy_card(e.treasure_reward).card_id
	else:return failure(&"invalid_event")
	e.selected_choice=choice;e.resolved=true;e.outcome=outcome.duplicate(true)
	return completion(choice,outcome,e.event_type==&"hotSpring")
## Material gear fills the lead in this order: ancient, then rare (combined), then the rest.
const GEAR_PRIORITY = {&"ancient":2,&"rare":1}
## A unit can promote with two more living units of the same character and star rank.
func promotion_eligible(member: GuildMemberState) -> bool:
	if member==null or not member.is_alive() or member.stars>=GrowthRules.MAX_STARS:return false
	return guild.living_members().filter(func(m):return m.unit_type_id==member.unit_type_id and m.stars==member.stars).size()>=3
## The lead stays and gains a star; the two materials are consumed. Experience is pooled with a
## bonus, HP becomes the three units' average, and the materials' gear fills the lead's free slots
## (ancient first, then rare, then the rest; random within a grade; leftovers go to the inventory).
func promote(lead_id: String,material_ids: Array) -> Dictionary:
	if not inventory.valid():return failure(&"invalid_inventory")
	if not can_manage():return failure(&"management_locked")
	if material_ids.size()!=2:return failure(&"invalid_selection")
	var lead: GuildMemberState=guild.get_member(lead_id);var members: Array=[lead];var seen: Dictionary={lead_id:true}
	for id in material_ids:
		if seen.has(id):return failure(&"invalid_selection")
		seen[id]=true;members.append(guild.get_member(id))
	if members.any(func(m):return m==null or not m.is_alive()) or lead.stars>=GrowthRules.MAX_STARS:return failure(&"ineligible")
	if members.any(func(m):return m.unit_type_id!=lead.unit_type_id or m.stars!=lead.stars):return failure(&"ineligible")
	var total_exp: int=GrowthRules.PROMOTION_BONUS_EXP;var hp: float=0
	for member in members:total_exp+=member.total_exp;hp+=member.current_hp
	var gear: Array=[]
	for other in members.slice(1):
		for item in inventory.equipped(other.member_id):item.equipped_to_member_id="";gear.append(item)
		guild.state.guild_members.erase(other.member_id)
		guild.state.last_formation.entries=guild.state.last_formation.entries.filter(func(entry):return entry.member_id!=other.member_id)
	lead.stars+=1;lead.total_exp=total_exp;lead.current_hp=hp/members.size()
	shuffle(gear)
	gear.sort_custom(func(a,b):return GEAR_PRIORITY.get(ItemCatalog.get_item(a.kind).grade,0)>GEAR_PRIORITY.get(ItemCatalog.get_item(b.kind).grade,0))
	var placed: Array=[];var returned: Array=[]
	for item in gear:
		# Equipping runs the usual rules, so two basics on the lead still fuse into a rare item.
		var result: Dictionary=equip(item.item_id,lead.member_id)
		if result.ok:placed.append(item.item_id)
		else:returned.append(item.item_id)
	# The average HP is capped by the new maximum, gear included.
	lead.current_hp=minf(lead.current_hp,guild.member_stats(lead).max_hp)
	return success({"member_id":lead.member_id,"stars":lead.stars,"level":lead.level,"equipped":placed,"returned":returned})
func execute(action: StringName,options: Dictionary={}) -> Dictionary:
	match action:
		&"recruit":return recruit(options.get("offer_id",""))
		&"reroll":return reroll()
		&"buy":return buy(options.get("offer_id",""))
		&"equip":return equip(options.get("item_id",0),options.get("member_id",""))
		&"upgrade":return upgrade(options.get("member_id",""))
		&"finish":return finish()
		&"rest":return rest(options.get("choice",&""),options.get("members",[]))
		&"event":return event(options.get("choice",&""))
		&"sortie_upgrade":return upgrade_sortie()
		&"promote":return promote(options.get("member_id",""),options.get("materials",[]))
	return failure(&"invalid_action")
