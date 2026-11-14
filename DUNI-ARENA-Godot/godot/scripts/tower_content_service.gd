class_name TowerContentService
extends RefCounted
## Pure content operations. UI sends IDs; no Nodes stored in content state.
const REROLL_COST = 200
## Candidates per recruit room (rooms entered before 0.56.0 keep their three).
const RECRUIT_SLOTS = 4
const HOT_SPRING_COST = 200
## Guild rest: how many dead members one revive brings back (at 20% HP).
const REST_REVIVE_LIMIT = 3
## Token shop event offers: token price and how many times each can be bought in one visit
## (0 = no limit). revive: one chosen dead member at 20% HP; heal: every living member +5% HP;
## item: a random item from the floor table; card: a random strategy card; restore: one chosen
## living member to full.
## Mango sapling: a free revive of one dead member, an offering of MANGO_OFFERING gold for one
## faith stack, and (when faith is held on entry) a blessing that spends all faith for gold.
## Each once per room.
const MANGO_OFFERING = 200
const MANGO_LIMITS = {&"revive":{"limit":1},&"offer":{"limit":1},&"bless":{"limit":1}}
## Blessing gold for `faith` stacks: 500, 700, 1000, 1400, 1900... (each step 100 more than the last).
static func blessing_gold(faith: int) -> int:return 400+50*faith*(faith+1) if faith>0 else 0
## Gambler's room: each game once per room for GAMBLE_COST gold. The roulette lands on one of
## ROULETTE's equal slots; at dice, three dice against the gambler's three, the higher total
## pays double the stake and a tie returns it.
const GAMBLE_COST = 200
const GAMBLE_LIMITS = {&"roulette":{"limit":1},&"dice":{"limit":1}}
const ROULETTE = [&"miss",&"gold100",&"gold300",&"gold600",&"gold1000",&"tokens2",&"item",&"card"]
## The roulette "아이템" slot uses its own grade odds (ItemTuning.ROULETTE_ODDS).
## Per-visit purchase limits of the open events, offer name -> {"limit"}.
static func purchase_limits(event_type: StringName) -> Dictionary:
	match event_type:
		&"tokenShop":return TOKEN_SHOP
		&"mangoSapling":return MANGO_LIMITS
		&"gambler":return GAMBLE_LIMITS
	return {}
const TOKEN_SHOP = {
	&"revive":{"tokens":2,"limit":3},
	&"heal":{"tokens":1,"limit":10},
	&"item":{"tokens":2,"limit":3},
	&"card":{"tokens":2,"limit":0},
	&"restore":{"tokens":5,"limit":2},
}
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
	var offers: Array[RecruitOffer]=[];var by_price: Dictionary={}
	for type in CharacterCatalog.playable():
		var price: int=guild.definition(type).recruit_tokens
		if not by_price.has(price):by_price[price]=[]
		by_price[price].append(type)
	for slot in range(RECRUIT_SLOTS):
		# A price first (by the guild's recruit odds, among prices with units left), then a unit of
		# that price; no unit shows twice in one room.
		var odds: Dictionary=GrowthRules.recruit_odds(guild.state);var total: float=0
		for price in by_price:
			if not by_price[price].is_empty():total+=float(odds.get(price,0))
		var roll: float=rng.randf()*total;var pick: int=-1
		for price in by_price:
			if by_price[price].is_empty() or odds.get(price,0)==0:continue
			pick=price;roll-=float(odds[price])
			if roll<0:break
		var units: Array=by_price[pick];var type: int=units.pop_at(rng.randi_range(0,units.size()-1))
		var offer:=RecruitOffer.new();offer.offer_id="%s:recruit:%d:%d"%[node.room_id,revision,slot];offer.unit_type_id=type;offer.token_price=guild.definition(type).recruit_tokens;offers.append(offer)
	return offers
func ensure_recruit(node: RoomState) -> void:
	if node.recruit!=null:return
	node.recruit=RecruitState.new();node.recruit.offers=create_offers(node,0)
## The shelf is rolled once per shop room and kept for later visits: ItemTuning.SHOP_ITEMS items
## from the floor table (all different, owned 전설 left out) priced by grade, and the strategy
## cards as before.
func ensure_shop(node: RoomState) -> void:
	if node.shop!=null:return
	node.shop=ShopState.new()
	var count: int=rng.randi_range(ItemTuning.SHOP_ITEMS.x,ItemTuning.SHOP_ITEMS.y)
	var items: Array=ItemRewards.roll(rng,ItemRewards.odds(node.floor_index),count,ItemRewards.owned_legendaries(guild.state))
	var cards: Array=StrategyCardCatalog.DEFINITIONS.keys()
	count=rng.randi_range(2,3);shuffle(cards);cards=cards.slice(0,count)
	for kind in items:
		var offer:=ShopOffer.new();offer.category=&"equipment";offer.kind=kind;offer.offer_id="%s:stock:equipment:%s:0"%[node.room_id,kind]
		offer.gold_price=ItemCatalog.price(kind);node.shop.offers.append(offer)
	for kind in cards:
		var quantity: int=2 if rng.randf()<.2 else 1
		for copy in range(quantity):
			var offer:=ShopOffer.new();offer.category=&"card";offer.kind=kind;offer.offer_id="%s:stock:card:%s:%d"%[node.room_id,kind,copy]
			offer.gold_price=StrategyCardCatalog.get_card(kind).gold_price;node.shop.offers.append(offer)
func ensure_event(node: RoomState) -> void:
	if node.event!=null:return
	var event:=EventState.new();event.event_type=node.event_type;node.event=event
	match node.event_type:
		&"hotSpring":event.choices=[&"bathe",&"lottery"]
		&"supply":
			event.choices=[&"heal",&"guild",&"gold",&"loot"]
			event.treasure_kind=&"item" if rng.randf()<.5 else &"card"
			if event.treasure_kind==&"item":event.treasure_reward=ItemRewards.one(rng,guild.state,node.floor_index)
			else:
				var pool: Array=StrategyCardCatalog.DEFINITIONS.keys();event.treasure_reward=pool[rng.randi_range(0,pool.size()-1)]
		&"prediction":event.prediction=PredictionRules.create(rng)
		# The token shop stays open for any number of purchases; leaving ends the event.
		&"tokenShop":event.choices=[&"leave"]
		# The blacksmith likewise stays open until 지도로.
		&"blacksmith":event.choices=[&"leave"]
		# The blessing is offered only to a party that arrives with faith.
		&"gambler":event.choices=[&"leave"]
		&"mangoSapling":
			event.choices=[&"leave"]
			if guild.state.mango_faith>0:event.choices.append(&"bless")
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
	if guild_full():return failure(&"guild_full")
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
	if equipment.size()>=GuildMemberCombatStats.equipment_limit(member):return failure(&"slots_full")
	# 고대: at most ItemTuning.ANCIENT_PER_UNIT on one unit.
	if item.grade==&"ancient" and equipment.filter(func(g):return ItemCatalog.grade_of(g.kind)==&"ancient").size()>=ItemTuning.ANCIENT_PER_UNIT:return failure(&"ancient_limit")
	var state: Dictionary=member.character_specific_state
	var stats: UnitCombatStats=guild.member_stats(member)
	if item.vigor_totem and stats.vigor_totem_count==0:state["totemClock"]=5
	if item.charge_totem and stats.charge_totem_count==0:state["chargeTotemClock"]=4
	member.character_specific_state=state;instance.equipped_to_member_id=member_id
	return success({"item_id":item_id,"member_id":member_id})
## Buys experience in packs of GrowthRules.EXP_PACK. Levels gained raise HP by the max-HP gain
## (reviving a fallen unit); the rest stays as progress toward the next level.
func buy_exp(member_id: String,packs: int) -> Dictionary:
	if not inventory.valid():return failure(&"invalid_inventory")
	if not can_manage():return failure(&"management_locked")
	var member: GuildMemberState=guild.get_member(member_id)
	if member==null:return failure(&"invalid_member")
	if packs<1:return failure(&"invalid_amount")
	var gained: int=packs*GrowthRules.EXP_PACK;var cost: int=packs*GrowthRules.pack_cost()
	var receipt: String="exp:%s:%d:%d"%[member_id,member.total_exp,packs]
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	var old_max: float=guild.member_stats(member).max_hp;var dead: bool=not member.is_alive()
	ResourceTransaction.spend(guild.state,cost,0,receipt);member.total_exp+=gained
	var gain: float=GuildMemberCombatStats.heal(guild,member,maxf(0,guild.member_stats(member).max_hp-old_max),true)
	if dead and member.is_alive() and member.unit_type_id==13:GuildMemberCombatStats.reset_bomber(member)
	return success({"level":member.level,"exp_gained":gained,"hp_gained":gain,"gold_spent":cost})
## Buys exactly the packs needed for the next level.
func level_up(member_id: String) -> Dictionary:
	var member: GuildMemberState=guild.get_member(member_id)
	return buy_exp(member_id,GrowthRules.packs_to_level(member.total_exp)) if member!=null else failure(&"invalid_member")
## The guild holds as many members as its roster limit (dead ones count).
func guild_full() -> bool:return guild.all_members().size()>=GrowthRules.roster_limit(guild.state)
func upgrade_sortie() -> Dictionary:
	if not can_manage():return failure(&"management_locked")
	var cost: int=GrowthRules.sortie_cost(guild.state)
	if cost<0:return failure(&"max_sortie")
	var receipt: String="sortie:%d"%guild.state.sortie_level
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	ResourceTransaction.spend(guild.state,cost,0,receipt);guild.state.sortie_level+=1
	return success({"sortie_limit":GrowthRules.sortie_limit(guild.state),"gold_spent":cost})
## Guild expansion: a bigger roster (+2 members) or better recruit odds (next level).
func upgrade_roster() -> Dictionary:
	if not can_manage():return failure(&"management_locked")
	var cost: int=GrowthRules.roster_cost(guild.state)
	if cost<0:return failure(&"max_roster")
	var receipt: String="roster:%d"%guild.state.roster_level
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	ResourceTransaction.spend(guild.state,cost,0,receipt);guild.state.roster_level+=1
	return success({"roster_limit":GrowthRules.roster_limit(guild.state),"gold_spent":cost})
func upgrade_odds() -> Dictionary:
	if not can_manage():return failure(&"management_locked")
	var cost: int=GrowthRules.odds_cost(guild.state)
	if cost<0:return failure(&"max_odds")
	var receipt: String="odds:%d"%guild.state.odds_level
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	ResourceTransaction.spend(guild.state,cost,0,receipt);guild.state.odds_level+=1
	return success({"odds_level":guild.state.odds_level,"gold_spent":cost})
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
			if members.size()<1 or members.size()>REST_REVIVE_LIMIT:return failure(&"invalid_selection")
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
## Token shop: one purchase. `member_id` names the member for revive / restore.
func token_shop(choice: StringName,member_id: String="") -> Dictionary:
	if not live() or room()==null or guild.state.tower.phase!=&"event_active" or room().event==null or room().event.event_type!=&"tokenShop" or room().event.resolved:return failure(&"wrong_event")
	if not TOKEN_SHOP.has(choice):return failure(&"invalid_choice")
	var e: EventState=room().event;var offer: Dictionary=TOKEN_SHOP[choice];var bought: int=int(e.purchases.get(String(choice),0))
	if int(offer.limit)>0 and bought>=int(offer.limit):return failure(&"sold_out")
	var member: GuildMemberState=guild.get_member(member_id) if not member_id.is_empty() else null
	match choice:
		&"revive":
			if member==null or member.is_alive():return failure(&"invalid_target")
		&"restore":
			if member==null or not member.is_alive() or member.current_hp>=guild.member_stats(member).max_hp:return failure(&"invalid_target")
		&"heal":
			if guild.living_members().is_empty():return failure(&"no_effect")
		_:
			if not inventory.valid():return failure(&"invalid_inventory")
	var receipt: String="%s:token:%s:%d"%[room().room_id,choice,bought]
	if not ResourceTransaction.can_spend(guild.state,0,int(offer.tokens),receipt):return failure(&"insufficient_tokens")
	ResourceTransaction.spend(guild.state,0,int(offer.tokens),receipt)
	var outcome: Dictionary={"choice":choice,"tokens_spent":int(offer.tokens)}
	match choice:
		&"revive":
			GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.2,true);GuildMemberCombatStats.reset_bomber(member);outcome["revived"]=[member.member_id]
		&"restore":
			outcome["hp_gained"]=GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp);outcome["member_id"]=member.member_id
		&"heal":
			for living in guild.living_members():GuildMemberCombatStats.heal(guild,living,guild.member_stats(living).max_hp*.05)
		&"item":outcome["item_id"]=inventory.give(ItemRewards.one(rng,guild.state,room().floor_index)).item_id
		&"card":
			var kinds: Array=StrategyCardCatalog.DEFINITIONS.keys();outcome["card_id"]=guild.state.give_strategy_card(kinds[rng.randi_range(0,kinds.size()-1)]).card_id
	e.purchases[String(choice)]=bought+1
	return success(outcome)
## The open blacksmith event of the current room, or null.
func blacksmith_event() -> EventState:
	if not live() or room()==null or guild.state.tower.phase!=&"event_active" or room().event==null or room().event.event_type!=TowerController.BLACKSMITH or room().event.resolved:return null
	return room().event
## Raises a 희귀 · 영웅 · 전설 item (equipped or not) one level, up to ItemCatalog.MAX_ENHANCE;
## always succeeds.
func blacksmith_enhance(item_id: int) -> Dictionary:
	if blacksmith_event()==null:return failure(&"wrong_event")
	var instance: ItemInstance=inventory.get_item(item_id)
	if instance==null or instance.consumed or not ItemCatalog.can_enhance(instance):return failure(&"invalid_target")
	var cost: int=ItemCatalog.ENHANCE_COSTS[instance.enhance];var receipt: String="%s:enhance:%d:%d"%[room().room_id,item_id,instance.enhance+1]
	if not ResourceTransaction.can_spend(guild.state,cost,0,receipt):return failure(&"funds")
	ResourceTransaction.spend(guild.state,cost,0,receipt);instance.enhance+=1
	return success({"item_id":item_id,"enhance":instance.enhance,"gold_spent":cost})
## Sells an unequipped 일반 or 희귀 item for half its shop price (ItemTuning.SELL_RATE).
func blacksmith_sell(item_id: int) -> Dictionary:
	if blacksmith_event()==null:return failure(&"wrong_event")
	var instance: ItemInstance=inventory.get_item(item_id)
	if instance==null or instance.consumed or not instance.equipped_to_member_id.is_empty() or ItemCatalog.sell_price(instance.kind)<=0:return failure(&"invalid_target")
	var gold: int=ItemCatalog.sell_price(instance.kind);instance.consumed=true;guild.state.gold+=gold
	return success({"item_id":item_id,"gold":gold})
## 전투 보상: after a win the room offers ItemTuning.REWARD_CHOICES items, rolled once from the floor
## table cut to the room's lowest grade (전투 일반+, 미니보스 희귀+, 보스 영웅+); owned 전설 left out.
func roll_battle_reward(node: RoomState,source: RandomNumberGenerator,extra: int=0) -> void:
	if node==null or not node.item_choices.is_empty() or node.item_choice!=&"":return
	var lowest: StringName=ItemTuning.REWARD_MIN_GRADE.get(node.room_type,&"common")
	node.item_choices=ItemRewards.roll(source,ItemRewards.odds(node.floor_index,lowest),ItemTuning.REWARD_CHOICES+extra,ItemRewards.owned_legendaries(guild.state))
func pending_reward(node: RoomState) -> bool:return node!=null and not node.item_choices.is_empty() and node.item_choice==&""
## Takes one offered item, or &"skip" for ItemTuning.SKIP_GOLD gold. Once per room.
func pick_reward(kind: StringName) -> Dictionary:
	var node: RoomState=room()
	if not pending_reward(node) or guild.state.tower.phase!=&"result":return failure(&"no_reward")
	if kind==&"skip":
		guild.state.gold+=ItemTuning.SKIP_GOLD;node.item_choice=&"skip";return success({"gold":ItemTuning.SKIP_GOLD,"skipped":true})
	if not kind in node.item_choices:return failure(&"invalid_choice")
	if not inventory.valid():return failure(&"invalid_inventory")
	var item: ItemInstance=inventory.give(kind,"reward:"+node.room_id)
	if item==null:return failure(&"invalid_item")
	node.item_choice=kind;return success({"item_id":item.item_id,"kind":kind})
## Mango sapling: one of revive (member_id), offer or bless.
func mango(choice: StringName,member_id: String="") -> Dictionary:
	if not live() or room()==null or guild.state.tower.phase!=&"event_active" or room().event==null or room().event.event_type!=&"mangoSapling" or room().event.resolved:return failure(&"wrong_event")
	if not MANGO_LIMITS.has(choice):return failure(&"invalid_choice")
	var e: EventState=room().event;var used: int=int(e.purchases.get(String(choice),0))
	if used>=int(MANGO_LIMITS[choice].limit):return failure(&"sold_out")
	var outcome: Dictionary={"choice":choice}
	match choice:
		&"revive":
			var member: GuildMemberState=guild.get_member(member_id)
			if member==null or member.is_alive():return failure(&"invalid_target")
			GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.2,true);GuildMemberCombatStats.reset_bomber(member);outcome["revived"]=[member_id]
		&"offer":
			var receipt: String="%s:mango:offer"%room().room_id
			if not ResourceTransaction.can_spend(guild.state,MANGO_OFFERING,0,receipt):return failure(&"funds")
			ResourceTransaction.spend(guild.state,MANGO_OFFERING,0,receipt);guild.state.mango_faith+=1;outcome["faith"]=guild.state.mango_faith;outcome["gold_spent"]=MANGO_OFFERING
		&"bless":
			if not &"bless" in e.choices or guild.state.mango_faith<=0:return failure(&"no_effect")
			var gold: int=blessing_gold(guild.state.mango_faith);outcome["faith_spent"]=guild.state.mango_faith;outcome["gold"]=gold
			guild.state.mango_faith=0;guild.state.gold+=gold
			# 망고 신자의 염주 loses its faith bonus with the faith.
			for m in guild.all_members():m.current_hp=minf(m.current_hp,guild.member_max_hp(m))
	e.purchases[String(choice)]=used+1
	return success(outcome)
## Gambler's room: plays &"roulette" or &"dice" once. The result is kept on the event so the room
## can show it again.
func gamble(choice: StringName) -> Dictionary:
	if not live() or room()==null or guild.state.tower.phase!=&"event_active" or room().event==null or room().event.event_type!=&"gambler" or room().event.resolved:return failure(&"wrong_event")
	if not GAMBLE_LIMITS.has(choice):return failure(&"invalid_choice")
	var e: EventState=room().event;var played: int=int(e.purchases.get(String(choice),0))
	if played>=int(GAMBLE_LIMITS[choice].limit):return failure(&"sold_out")
	if choice==&"roulette" and not inventory.valid():return failure(&"invalid_inventory")
	var receipt: String="%s:gamble:%s"%[room().room_id,choice]
	if not ResourceTransaction.can_spend(guild.state,GAMBLE_COST,0,receipt):return failure(&"funds")
	ResourceTransaction.spend(guild.state,GAMBLE_COST,0,receipt)
	var outcome: Dictionary={"choice":choice,"gold_spent":GAMBLE_COST}
	if choice==&"roulette":
		var slot: int=rng.randi_range(0,ROULETTE.size()-1);var reward: StringName=ROULETTE[slot];outcome["slot"]=slot;outcome["reward"]=reward
		match reward:
			&"miss":pass
			&"tokens2":guild.state.tokens+=2;outcome["tokens"]=2
			&"item":
				var won: Array[StringName]=ItemRewards.roll(rng,ItemTuning.ROULETTE_ODDS,1,ItemRewards.owned_legendaries(guild.state))
				outcome["item_id"]=inventory.give(won[0] if not won.is_empty() else &"warmNecklace").item_id
			&"card":
				var kinds: Array=StrategyCardCatalog.DEFINITIONS.keys();outcome["card_id"]=guild.state.give_strategy_card(kinds[rng.randi_range(0,kinds.size()-1)]).card_id
			_:var gold: int=int(String(reward).trim_prefix("gold"));guild.state.gold+=gold;outcome["gold"]=gold
	else:
		var mine: Array=[];var theirs: Array=[]
		for i in range(3):mine.append(rng.randi_range(1,6))
		for i in range(3):theirs.append(rng.randi_range(1,6))
		var a: int=mine.reduce(func(s,v):return s+v,0);var b: int=theirs.reduce(func(s,v):return s+v,0)
		var result: StringName=&"win" if a>b else &"draw" if a==b else &"lose";var payout: int={&"win":GAMBLE_COST*2,&"draw":GAMBLE_COST,&"lose":0}[result]
		guild.state.gold+=payout;outcome.merge({"player":mine,"gambler":theirs,"result":result,"payout":payout})
		if payout>0:outcome["gold"]=payout
	e.outcome[String(choice)]=outcome.duplicate(true);e.outcome["last"]=String(choice);e.purchases[String(choice)]=played+1
	return success(outcome)
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
					for i in range(2 if reward==&"items" else 1):ids.append(inventory.give(ItemRewards.one(rng,guild.state,room().floor_index)).item_id)
					outcome["items"]=ids
				&"strategy":
					var kinds: Array=StrategyCardCatalog.DEFINITIONS.keys();outcome["card_id"]=guild.state.give_strategy_card(kinds[rng.randi_range(0,kinds.size()-1)]).card_id
				# A full guild gets the tokens instead of a unit.
				&"unit":
					if guild_full():guild.state.tokens+=3;outcome["tokens"]=3
					else:outcome["member_id"]=guild.create_member(rng.randi_range(0,25)).member_id
				&"tokens":guild.state.tokens+=3;outcome["tokens"]=3
				_:var gold: int=int(String(reward).trim_prefix("gold"));guild.state.gold+=gold;outcome["gold"]=gold
	elif e.event_type in [&"tokenShop",TowerController.BLACKSMITH,&"mangoSapling",&"gambler"]:
		# Open events end only by leaving; their offers have their own actions.
		if choice!=&"leave":return failure(&"invalid_choice")
		outcome["purchases"]=e.purchases.duplicate()
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
## Material gear fills the lead in grade order (ItemTuning.GEAR_PRIORITY): 고대 > 전설 > 영웅 > 희귀 > 일반.
const GEAR_PRIORITY = ItemTuning.GEAR_PRIORITY
## A unit can promote with two more living units of the same character and star rank.
func promotion_eligible(member: GuildMemberState) -> bool:
	if member==null or not member.is_alive() or member.stars>=GrowthRules.MAX_STARS:return false
	return guild.living_members().filter(func(m):return m.unit_type_id==member.unit_type_id and m.stars==member.stars).size()>=3
## The lead stays and gains a star; the two materials are consumed. Experience is pooled with a
## bonus, HP becomes the three units' average, and the materials' gear fills the lead's free slots
## (highest grade first; random within a grade; leftovers go to the inventory).
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
		&"upgrade":return buy_exp(options.get("member_id",""),1)
		&"level_up":return level_up(options.get("member_id",""))
		&"finish":return finish()
		&"rest":return rest(options.get("choice",&""),options.get("members",[]))
		&"event":return event(options.get("choice",&""))
		&"token_shop":return token_shop(options.get("choice",&""),options.get("member_id",""))
		&"enhance":return blacksmith_enhance(options.get("item_id",0))
		&"pick_reward":return pick_reward(options.get("kind",&""))
		&"sell":return blacksmith_sell(options.get("item_id",0))
		&"mango":return mango(options.get("choice",&""),options.get("member_id",""))
		&"gamble":return gamble(options.get("choice",&""))
		&"sortie_upgrade":return upgrade_sortie()
		&"roster_upgrade":return upgrade_roster()
		&"odds_upgrade":return upgrade_odds()
		&"promote":return promote(options.get("member_id",""),options.get("materials",[]))
	return failure(&"invalid_action")
