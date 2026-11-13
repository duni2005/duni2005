class_name CustomBattleTests
extends RefCounted
## Custom battle (web custom mode): roster rules and real multi-team / free-for-all battles.
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("CUSTOM: "+label)
func run(tree: SceneTree) -> void:
	var setup:=CustomBattleSetup.new()
	verify(setup.validate()!="","empty roster cannot start")
	verify(setup.add(0,0,Vector2(100,100))=="","place warrior for blue")
	verify(setup.add(0,0,Vector2(130,100))!="","58 spacing enforced")
	verify(setup.add(1,0,Vector2(400,400))=="","second blue unit")
	verify(setup.validate()!="","one faction cannot start")
	verify(setup.add(5,1,Vector2(5,900))=="" and setup.entries[-1].position==Vector2(40,760),"placement clamps to 40..760 over the whole map")
	verify(setup.validate()=="","two factions can start")
	verify(setup.move(int(setup.entries[0].id),Vector2(700,700))=="" and setup.entries[0].position==Vector2(700,700),"free move")
	verify(setup.move(int(setup.entries[0].id),setup.entries[1].position)!="","move respects spacing")
	verify(setup.team_spending(0)==int(CharacterCatalog.all()[0].base_gold_cost+CharacterCatalog.all()[1].base_gold_cost),"team cost sums base cost")
	var id: int=int(setup.entries[0].id)
	verify(setup.equip(id,&"woodSword")=="" and setup.equip(id,&"dragonHeart")=="" and setup.get_entry(id).items==[&"woodSword",&"dragonHeart"],"items stay separate (no combining)")
	verify(setup.equip(id,&"verdantStone")!="","item slots capped at two")
	verify(setup.equip(id,&"reengrave")!="","consumables are not equippable")
	verify(is_equal_approx(setup.stats_for(setup.get_entry(id)).physical_power,1.12) and setup.stats_for(setup.get_entry(id)).dragon_heart_count==1,"items change stats")
	verify(setup.unequip(id,0) and setup.get_entry(id).items.size()==1,"items removable")
	setup.set_stance(id,CombatStance.RUSH);verify(setup.get_entry(id).stance==CombatStance.RUSH,"per-unit stance")
	verify(setup.remove(id) and setup.entries.size()==2,"eraser removes one")
	setup.clear();verify(setup.entries.is_empty(),"clear all")
	for i in range(CustomBattleSetup.MAX_PARTICIPANTS):setup.add(i%26,CustomBattleSetup.TEAM_ORDER[i%5])
	verify(setup.entries.size()==CustomBattleSetup.MAX_PARTICIPANTS and setup.add(0,0)!="","24 participant cap with auto placement")
	# Four teams plus free-for-all solo units fight to a single winner.
	setup.clear()
	var spots: Array=[Vector2(150,150),Vector2(650,150),Vector2(150,650),Vector2(650,650),Vector2(400,400),Vector2(400,120)]
	for i in range(4):setup.add(0,i,spots[i])
	setup.add(1,CustomBattleSetup.SOLO,spots[4]);setup.add(1,CustomBattleSetup.SOLO,spots[5])
	verify(setup.faction_count()==6,"two solo units are separate factions")
	var b:=BattleManager.new();b.auto_start=false;b.custom_mode=true;tree.root.add_child(b)
	verify(b.start_battle(setup.placements(),77),"custom placements start")
	b.set_physics_process(false)
	verify(b.units[0].team_color()==CustomBattleSetup.TEAM_COLORS[0] and b.units[3].team_color()==CustomBattleSetup.TEAM_COLORS[3],"four team colours")
	verify(b.units[4].team_color()==CustomBattleSetup.TYPE_COLORS[1],"solo unit uses its character colour")
	b.units[2].transcendence_gauge=100
	verify(b.transcendence.ready(b.units[2]),"any team may use transcendence in custom mode")
	var guard: int=0
	while not b.finished and guard<60*240:b.simulate(1.0/60);guard+=1
	verify(b.finished,"multi-faction battle reaches an end")
	var alive: Dictionary={}
	for u in b.units:
		if u.alive:alive[u.original_team]=true
	verify(alive.size()<=1,"at most one faction survives")
	b.queue_free()
	await new_characters(tree)
	element_effects(tree)
	attack_speed_pace(tree)
	hero_moves(tree)
	await custom_result_flow(tree)
	await status_sheet(tree)
	griffin_and_crossbow(tree)
	stun_rush_and_travel(tree)
	balance_layer(tree)
	parrot_and_whisperer(tree)
	plague_and_golem(tree)
	flame_blade_and_tags(tree)
	snowman_and_santa(tree)
	battle_stats(tree)
	prediction_variety(tree)
	balance_0845(tree)
	top_and_bounty(tree)
	fixes_0860(tree)
	puppet_0861(tree)
	researcher(tree)
	ai_fluid(tree)
	fixes_0910(tree)
	fumble(tree)
	items_0940(tree)
	items_0960(tree)
	slime_unit(tree)
	items(tree)
	multikill(tree)
	stairs()
	await unit_sheet(tree)
	stat_damage(tree)
	stances(tree)
	tactical_mind(tree)
	await map_wallet_return(tree)
	ai_health(tree)
	print("CUSTOM BATTLE RESULT: ",checks," checks; ",failures," failures")
func duel(tree: SceneTree,rows: Array,seed: int=5) -> BattleManager:
	var setup:=CustomBattleSetup.new()
	for row in rows:setup.add(row[0],row[1],row[2])
	var b:=BattleManager.new();b.auto_start=false;b.custom_mode=true;tree.root.add_child(b)
	b.start_battle(setup.placements(),seed);b.set_physics_process(false)
	return b
func step(b: BattleManager,seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		if b.finished:return
		b.simulate(1.0/60)
func new_characters(tree: SceneTree) -> void:
	verify(CharacterCatalog.all().size()==47,"47 characters in the catalog (one test unit)")
	# 말뚝: opening stake tethers the nearest enemy to a small circle.
	var b:=duel(tree,[[26,0,Vector2(150,400)],[1,1,Vector2(450,400)],[1,1,Vector2(700,700)]])
	step(b,.2)
	var near: BattleUnit=b.units[1]
	verify(near.state_value("tetherTime")>0 and near.current_hp<near.max_hp,"stake opens with damage and a tether on the nearest enemy")
	verify(b.units[2].state_value("tetherTime")<=0,"only the nearest enemy is staked")
	var stake: Vector2=CharacterPersistence.vector(near.character_specific_state.tetherPoint)
	step(b,3)
	verify(near.position.distance_to(stake)<=BindingController.TETHER_RADIUS+1,"tethered unit stays near the stake")
	b.queue_free()
	# 굴절: swaps with the farthest enemy at the start.
	b=duel(tree,[[28,0,Vector2(100,100)],[0,1,Vector2(300,100)],[0,1,Vector2(700,700)]])
	step(b,.05)
	verify(b.units[0].position.distance_to(Vector2(700,700))<20 and b.units[2].position.distance_to(Vector2(100,100))<20,"refraction swaps with the farthest enemy")
	verify(b.units[0].data.ultimate_windup<0 and b.units[0].ultimate.gain(b.units[0],50)==0,"refraction has no ultimate")
	b.queue_free()
	# 배달부: a parcel arrives, is carried to a fighter, and buffs it.
	b=duel(tree,[[29,0,Vector2(400,700)],[4,0,Vector2(400,760)],[4,1,Vector2(400,80)]])
	var courier: BattleUnit=b.units[0]
	courier.set_state("parcelRespawn",0)
	step(b,.1)
	verify(not courier.character_specific_state.get("parcel",{}).is_empty(),"a parcel lands on the map")
	var delivered: bool=false
	for i in range(60*20):
		step(b,1.0/60)
		if b.units[1].state_value("deliveryFx")>0:delivered=true;break
	verify(delivered,"courier picks up the parcel and delivers a buff to its fighter")
	verify(courier.character_specific_state.get("parcel",{}).is_empty() and courier.state_value("parcelRespawn")>5,"next parcel arrives a few seconds later")
	b.units[1].receive_damage(9999,b.units[2]);step(b,.1)
	verify(not courier.alive,"courier dies when no fighting ally remains")
	b.queue_free()
	# 자석: ultimate links the two farthest enemies, pulls them together and holds them.
	b=duel(tree,[[30,0,Vector2(100,400)],[4,1,Vector2(500,150)],[4,1,Vector2(500,650)],[4,1,Vector2(300,400)]])
	var magnet: BattleUnit=b.units[0];magnet.ultimate_gauge=100
	for i in range(60*4):
		step(b,1.0/60)
		if b.units[1].state_value("magnetTime")>0:break
	verify(b.units[1].state_value("magnetTime")>0 and b.units[2].state_value("magnetTime")>0,"magnet links two enemies")
	step(b,1)
	verify(b.units[3].state_value("magnetTime")<=0,"the nearer enemy is not linked")
	verify(b.units[1].position.distance_to(b.units[2].position)<BindingController.MAGNET_GAP+12,"linked enemies are pulled together")
	var partner_hp: float=b.units[2].current_hp
	# A hit without the lightning tag, so no chain jump adds to the partner's damage.
	var hit: DamageOutcome=b.damage_resolver.resolve(magnet,b.units[1],100,{"dmg":&"transcend","critical":false,"impulse":0})
	verify(hit.hp_damage>0 and is_equal_approx(partner_hp-b.units[2].current_hp,CombatRules.js_round(CombatRules.js_round(hit.hp_damage*.1)*CombatRules.mitigation(b.units[2],&"magic"))),"linked partner takes 10% of the damage, after its own defense")
	b.queue_free()
	# 기관사: the train hits enemies on the line hard and shoves allies lightly.
	b=duel(tree,[[27,0,Vector2(100,400)],[4,0,Vector2(250,400)],[1,1,Vector2(500,400)],[1,1,Vector2(650,400)]])
	var conductor: BattleUnit=b.units[0];conductor.ultimate_gauge=100
	# The enemies stand still on the line, so the check is about the train, not where they wander.
	for foe in [b.units[2],b.units[3]]:foe.move_speed=0
	verify(not conductor.ability.can_attack(conductor,b.units[2]),"conductor has no basic attack")
	var enemy_hp: float=b.units[2].current_hp+b.units[3].current_hp;var ally_hp: float=b.units[1].current_hp
	var ran: bool=false
	for i in range(60*5):
		step(b,1.0/60)
		if conductor.state_value("trainFx")>0 and not ran:
			ran=true;var track: Dictionary=conductor.ultimate.cast.track
			verify(absf(float(track.angle))<.3 and float(track.from)<-80,"train enters behind the conductor and heads toward the enemies")
		if ran and conductor.state_value("trainFx")<=0:break
	verify(ran,"conductor runs the train")
	verify(enemy_hp-b.units[2].current_hp-b.units[3].current_hp>=60,"train deals heavy damage to enemies on the track")
	verify(ally_hp-b.units[1].current_hp<20,"allies take only a little train damage")
	b.queue_free()
	verify(CharacterCatalog.all()[29].move_speed<CharacterCatalog.all()[0].move_speed+10,"courier is no faster than a fighter")
	# 말뚝 궁극기 lands with a shockwave cue.
	b=duel(tree,[[26,0,Vector2(200,400)],[1,1,Vector2(500,400)]])
	b.units[0].ultimate_gauge=100;step(b,3)
	verify(b.combat_event_counts.get(&"ult_impact",0)>=1,"stake ultimate emits a landing shockwave")
	b.queue_free()
	# 빙결술사: three crystals per attack, frost stacks, freeze at 10, drifting storm.
	b=duel(tree,[[31,0,Vector2(200,400)],[4,1,Vector2(480,400)]])
	var frost: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	var before: int=b.projectiles.size();frost.ability.release_basic(frost)
	verify(b.projectiles.size()-before==3 and b.projectiles.slice(before).all(func(p):return p.kind=="iceShard"),"frost fires three ice crystals")
	frost.ability.dealt_damage(frost,foe,5,{"melee":false})
	verify(foe.state_value("frostStacks")==1,"a crystal hit adds one frost stack")
	for i in range(9):frost.ability.dealt_damage(frost,foe,5,{"melee":false})
	verify(foe.state_value("frozenTime")>0 and foe.stun_remaining>=3.9 and foe.state_value("frostStacks")==0,"ten frost stacks freeze the enemy for 4 seconds")
	step(b,4.2)
	verify(foe.state_value("frozenTime")<=0,"the freeze thaws")
	b.queue_free()
	b=duel(tree,[[31,0,Vector2(150,400)],[6,1,Vector2(330,400)],[8,1,Vector2(400,460)]])
	frost=b.units[0];frost.ultimate_gauge=100
	# Pin the targets so this checks the storm itself, not how well the AI dodges it.
	for e in b.units.slice(1):StatusController.stun(e,6)
	for i in range(60*3):
		step(b,1.0/60)
		if frost.character_specific_state.has("storm"):break
	verify(frost.character_specific_state.has("storm"),"frost ultimate summons an ice storm")
	var storm_start: Vector2=CharacterPersistence.vector(frost.character_specific_state.storm)
	step(b,1.5)
	var drifted: bool=frost.character_specific_state.has("storm") and CharacterPersistence.vector(frost.character_specific_state.storm).distance_to(storm_start)>50
	verify(drifted,"the storm drifts forward slowly")
	verify(b.units.slice(1).any(func(e):return e.state_value("frostStacks")>0 or e.state_value("frozenTime")>0),"enemies in the storm gain frost")
	b.queue_free()
	# 화염방사기: piercing flame puffs burn oil, oil refills while idle, the ultimate lights an oil
	# patch and refills the tank.
	b=duel(tree,[[32,0,Vector2(200,400)],[4,1,Vector2(330,400)],[6,1,Vector2(400,400)]])
	var flamer: BattleUnit=b.units[0]
	verify(flamer.state_value("oil")==30 and flamer.ability.can_attack(flamer,b.units[1]),"starts with a full tank")
	before=b.projectiles.size();flamer.combat.aim_angle=0;flamer.ability.release_basic(flamer)
	var puff: BattleProjectile=b.projectiles.back()
	verify(b.projectiles.size()-before==1 and puff.kind=="flame" and puff.piercing and flamer.state_value("oil")==29,"a flame puff pierces and burns one oil")
	flamer.set_state("oil",5);verify(not flamer.ability.can_attack(flamer,b.units[1]),"too little oil to start a spray")
	for e in b.units.slice(1):StatusController.stun(e,10)
	flamer.combat.cooldown=999;flamer.set_state("oil",10);step(b,1)
	verify(flamer.state_value("oil")>12,"oil refills while not spraying")
	# Rush stance attacks at once instead of the standoff AI's spacing and hesitation.
	flamer.combat.cooldown=0;flamer.set_state("oil",30);flamer.stance=CombatStance.RUSH;flamer.brain.stance_changed(flamer)
	var hp: Array=b.units.slice(1).map(func(e):return e.current_hp)
	for i in range(60*3):step(b,1.0/60)
	verify(b.units[1].current_hp<hp[0] and b.units[2].current_hp<hp[1],"the spray burns both enemies in a line")
	b.queue_free()
	b=duel(tree,[[32,0,Vector2(200,400)],[4,1,Vector2(380,400)]])
	flamer=b.units[0];flamer.set_state("oil",2);flamer.ultimate_gauge=100;StatusController.stun(b.units[1],8)
	for i in range(60*3):
		step(b,1.0/60)
		if b.zones.entries.any(func(z):return z.kind=="oilFire"):break
	var fire: Array=b.zones.entries.filter(func(z):return z.kind=="oilFire")
	verify(fire.size()==1 and fire[0].puddles.size()==5 and flamer.state_value("oil")>=29,"ultimate throws five oil bottles and refills the tank")
	verify(fire[0].puddles.all(func(p):return float(p.ignite)>=float(p.land)),"each puddle catches fire only after its bottle lands")
	# Stun the thrower: the sequence plays on by itself, and its spray cannot muddy the check.
	StatusController.stun(flamer,8)
	hp=[b.units[1].current_hp];step(b,.9)
	verify(b.units[1].current_hp==hp[0],"nothing burns before the oil is lit")
	step(b,1.6)
	verify(b.units[1].current_hp<hp[0],"the lit oil burns an enemy standing in it")
	var probe: Dictionary={"total":7.0,"life":5.0,"puddles":[{"x":100,"y":100,"r":50,"land":.5,"ignite":1.5},{"x":300,"y":100,"r":50,"land":.6,"ignite":3.0}]}
	verify(BattleZones.burning(probe,Vector2(110,100)) and not BattleZones.burning(probe,Vector2(300,100)) and not BattleZones.burning(probe,Vector2(200,100)),"only lit oil burns; the gap between puddles does not")
	b.queue_free()
	# Tower: new types are recruitable members and fight in ordinary (non-custom) battles.
	var guild:=GuildManager.new(RunState.new())
	verify(range(26,32).all(func(t):return guild.create_member(t)!=null),"new types can join the guild")
	var setup:=CustomBattleSetup.new()
	for row in [[26,0,Vector2(200,300)],[29,0,Vector2(200,420)],[27,0,Vector2(200,540)],[28,1,Vector2(600,300)],[30,1,Vector2(600,420)],[0,1,Vector2(600,540)]]:setup.add(row[0],row[1],row[2])
	b=BattleManager.new();b.auto_start=false;tree.root.add_child(b)
	verify(b.start_battle(setup.placements(),9),"tower-mode battle starts with new types");b.set_physics_process(false)
	step(b,90)
	verify(b.finished,"tower-mode battle with new types finishes")
	b.queue_free()
	# Each new character survives a full battle without errors.
	for type in range(26,32):
		b=duel(tree,[[type,0,Vector2(200,400)],[4,0,Vector2(200,500)],[0,1,Vector2(600,400)],[1,1,Vector2(600,500)]],type)
		step(b,60)
		verify(b.units.size()==4,"type %d battle runs" % type)
		b.queue_free()
func map_wallet_return(tree: SceneTree) -> void:
	# Gold changed inside a room must not replay on the map as a drop followed by a count-up.
	var ui:=TowerScreen.new();tree.root.add_child(ui);ui.controller.new_run(19,73);ui.show_map()
	for i in range(5):await tree.process_frame
	ui.body.get_parent().hide();ui.map_scroll.hide();ui.controller.guild.state.gold+=150
	for i in range(5):await tree.process_frame
	ui.show_map()
	var low: float=INF
	for i in range(60):
		await tree.process_frame;low=minf(low,ui.wallet.shown_gold)
	verify(low==ui.controller.guild.state.gold,"map wallet shows the current gold on return")
	ui.queue_free()
func ai_health(tree: SceneTree) -> void:
	# Target hold: two enemies at nearly the same range must not make the unit flick between them.
	var b:=duel(tree,[[0,0,Vector2(400,400)],[0,1,Vector2(560,330)],[0,1,Vector2(560,470)]],3)
	var u: BattleUnit=b.units[0];var flips: int=0;var last=null
	for i in range(60*3):
		b.simulate(1.0/60)
		if u.target!=null and last!=null and u.target!=last:flips+=1
		last=u.target
	verify(flips<=2,"target held between near-equal enemies (%d switches in 3s)"%flips)
	b.queue_free()
	# Idle and churn budget over a few mixed 6v6 battles.
	var rng:=RandomNumberGenerator.new();rng.seed=11
	var idle_time: float=0;var unit_time: float=0;var switches: int=0
	for n in range(3):
		var rows: Array=[]
		for i in range(6):rows.append([rng.randi_range(0,31),0,Vector2(rng.randf_range(60,300),80+i*120)])
		for i in range(6):rows.append([rng.randi_range(0,31),1,Vector2(rng.randf_range(500,740),80+i*120)])
		b=duel(tree,rows,500+n);var still: Dictionary={};var pos: Dictionary={};var tgt: Dictionary={};var shots: Dictionary={}
		for f in range(60*30):
			if b.finished:break
			b.simulate(1.0/60)
			if b.clock.is_turning_paused():continue
			for v in b.units:
				if not v.alive or v.stun_remaining>0 or v.unavailable() or v.target==null or v.data.type_id==29:continue
				unit_time+=1.0/60
				var id: String=v.target.actor_id()
				if tgt.has(v.battle_id) and tgt[v.battle_id]!=id:switches+=1
				tgt[v.battle_id]=id
				var moved: float=v.position.distance_to(pos.get(v.battle_id,v.position));pos[v.battle_id]=v.position
				var acting: bool=v.combat_state!=CombatController.State.IDLE or not v.ultimate.cast.is_empty() or v.combat.attacks_released!=int(shots.get(v.battle_id,v.combat.attacks_released))
				shots[v.battle_id]=v.combat.attacks_released
				still[v.battle_id]=float(still.get(v.battle_id,0))+1.0/60 if moved<.25 and not acting else 0.0
				if float(still[v.battle_id])>1.2:idle_time+=1.0/60
		b.queue_free()
	verify(idle_time/unit_time<.06,"units rarely stand idle (%.1f%%)"%(idle_time/unit_time*100))
	verify(switches/(unit_time/60)<25,"target churn bounded (%.1f per unit-minute)"%(switches/(unit_time/60)))
func items(tree: SceneTree) -> void:
	# Grades (0.94): 일반 12 + 재각인, 희귀 8, 영웅 3, 전설 6, 고대 3; nothing combines.
	var all: Dictionary=ItemCatalog.all();var count: Dictionary={}
	for k in all:count[all[k].grade]=int(count.get(all[k].grade,0))+1
	verify(count.get(&"common")==23 and count.get(&"rare")==18 and count.get(&"epic")==13 and count.get(&"legendary")==16 and count.get(&"ancient")==13,"item grades 23 / 18 / 13 / 16 / 13 (0.95: +10 each)")
	verify(ItemCatalog.get_item(&"woodSword+woodSword")==null and ItemCatalog.removed_combination("woodSword+woodSword") and ItemCatalog.refund("woodSword+staff")==260,"combined items are gone (refund = two material prices)")
	verify(ItemCatalog.get_item(&"warmNecklace+verdantStone").vigor_totem and ItemCatalog.grade_of(&"woodSword+redThorn")==&"rare" and is_equal_approx(ItemCatalog.get_item(&"woodSword+redThorn").physical_bonus,.1),"the five ability rares keep their effect with one 일반 stat line (0.96)")
	verify(ItemCatalog.grade_of(&"phoenixFeather")==&"legendary" and ItemCatalog.grade_of(&"mimicMask")==&"ancient","old ancients are 전설; 고대 is new")
	verify([&"rare",&"epic",&"legendary"].all(func(g):return ItemCatalog.POOLS[g].all(func(k):return ItemCatalog.price(k)==ItemTuning.GRADE_PRICES[g])),"grade prices 300 / 550 / 900")
	# Tower: two basics on one unit stay two items in two slots.
	var t:=TowerController.new();t.new_run(19,73);var m: GuildMemberState=t.guild.all_members()[0]
	var ids: Array=[]
	for kind in [&"woodSword",&"redThorn",&"staff"]:ids.append(t.content.inventory.give(kind).item_id)
	var results: Array=ids.map(func(id):return t.content_action(&"equip",{"item_id":id,"member_id":m.member_id}))
	verify(results[0].ok and results[1].ok and not results[2].ok and t.content.inventory.equipped(m.member_id).size()==2 and not t.content.inventory.get_item(ids[0]).consumed,"basics never fuse; each takes a slot")
	var mask: ItemInstance=t.content.inventory.give(&"mimicMask");var other: GuildMemberState=t.guild.all_members()[1]
	verify(t.content_action(&"equip",{"item_id":mask.item_id,"member_id":other.member_id}).ok and not t.content_action(&"equip",{"item_id":t.content.inventory.give(&"cursedCrown").item_id,"member_id":other.member_id}).ok,"고대 one per unit (tower)")
	var setup:=CustomBattleSetup.new();setup.add(0,0,Vector2(200,200));var id: int=int(setup.entries[0].id)
	verify(setup.equip(id,&"woodSword")=="" and setup.equip(id,&"staff")=="" and setup.get_entry(id).items==[&"woodSword",&"staff"],"custom: basics stay separate")
	setup.add(1,0,Vector2(500,500));var second: int=int(setup.entries.back().id)
	verify(setup.equip(second,&"gamblerDice")=="" and setup.equip(second,&"cursedCrown")!="" and setup.get_entry(second).items.size()==1,"custom: 고대 one per unit")
	verify(CustomBattleSetup.equippable_items().has(&"mimicMask") and not CustomBattleSetup.equippable_items().has(&"reengrave"),"custom offers every grade (no consumables)")
	# Reward table: floor odds, cut grades keep their ratio, no repeats, owned 전설 and 고대 never offered.
	verify(ItemRewards.odds(0)=={&"common":70.0,&"rare":25.0,&"epic":5.0,&"legendary":0.0} and ItemRewards.odds(14)[&"legendary"]==12.0,"floor odds 1-3 and 13-15")
	verify(ItemRewards.odds(9,&"epic")=={&"epic":24.0,&"legendary":8.0},"boss cut keeps the epic : legendary ratio")
	var r:=RandomNumberGenerator.new();r.seed=5;var seen_dupe: bool=false;var bad_grade: bool=false
	for n in range(200):
		var picks: Array[StringName]=ItemRewards.roll(r,ItemRewards.odds(12,&"rare"),3,[&"hourglass"])
		if picks.size()!=3 or picks[0]==picks[1] or picks[0]==picks[2] or picks[1]==picks[2]:seen_dupe=true
		if picks.any(func(k):return ItemCatalog.grade_rank(k)<1 or ItemCatalog.grade_of(k)==&"ancient" or k==&"hourglass"):bad_grade=true
	verify(not seen_dupe and not bad_grade,"three different items, rare or better, owned legendary left out")
	r.seed=7;var tally: Dictionary={}
	for n in range(4000):
		var k: StringName=ItemRewards.roll(r,ItemRewards.odds(0),1)[0];tally[ItemCatalog.grade_of(k)]=int(tally.get(ItemCatalog.grade_of(k),0))+1
	verify(absf(tally.get(&"common",0)/4000.0-.7)<.03 and absf(tally.get(&"rare",0)/4000.0-.25)<.03 and not tally.has(&"legendary"),"floor 1 draws about 70 / 25 / 5")
	# Damage types: 목검 only boosts physical hitters, 에테르 only elemental hits.
	var b:=duel(tree,[[0,0,Vector2(150,400)],[2,1,Vector2(650,400)]])
	var warrior: BattleUnit=b.units[0];var mage: BattleUnit=b.units[1]
	for u in [warrior,mage]:u.combat_stats.physical_power=1.3;u.combat_stats.element_power=2
	verify(is_equal_approx(EquipmentCombatEffects.damage_factor(warrior,{}),1.3) and is_equal_approx(EquipmentCombatEffects.damage_factor(mage,{}),1),"physical bonus skips a magic hitter")
	verify(is_equal_approx(EquipmentCombatEffects.damage_factor(mage,{"element":&"fire"}),2),"elemental bonus applies to elemental hits")
	verify(CharacterCatalog.damage_label(31)=="마법 · 얼음" and CharacterCatalog.damage_label(0)=="물리","damage labels")
	# 불사조의 깃털: one lethal blow per battle is survived.
	warrior.combat_stats.phoenix_count=1
	verify(CharacterLifecycle.intercept_lethal(warrior,warrior.current_hp+50) and warrior.invincible_remaining>=2 and warrior.alive,"phoenix revives once")
	verify(not EquipmentCombatEffects.phoenix(warrior),"phoenix is spent for this battle")
	# 시간의 모래시계: the gauge refills after an ultimate.
	mage.combat_stats.hourglass_count=1;mage.ultimate_gauge=0;EquipmentCombatEffects.after_ultimate(mage)
	verify(is_equal_approx(mage.ultimate_gauge,35),"hourglass refills 35%")
	b.queue_free()
func multikill(tree: SceneTree) -> void:
	# Original spectator rule: kills by one living unit within 6 battle seconds chain 2..6.
	var b:=duel(tree,[[0,0,Vector2(100,100)],[1,1,Vector2(700,100)],[1,1,Vector2(700,300)],[1,1,Vector2(700,500)],[2,2,Vector2(400,700)]])
	var p:=CombatPresentation.new();p.battle=b
	var killer: BattleUnit=b.units[0]
	p._count_kill(b.units[1],killer);verify(p.multi_banner.is_empty(),"first kill is not a multi-kill")
	b.clock.elapsed+=3;p._count_kill(b.units[2],killer);verify(p.multi_banner.get("count")==2,"second kill within 6s is a double kill")
	b.clock.elapsed+=5;p._count_kill(b.units[3],killer);verify(p.multi_banner.get("count")==3,"chain keeps going inside the window")
	b.clock.elapsed+=7;p._count_kill(b.units[4],killer);verify(p.multi_banner.get("count")==3,"a kill after 6s starts a new chain")
	p._count_kill(killer,b.units[4]);verify(not p.kill_streaks.has(killer.actor_id()),"a dead killer's streak ends")
	verify(CombatPresentation.MULTI_KILL_NAMES[6]=="헥사 킬","names run up to hexa kill")
	p.free();b.queue_free()
func stairs() -> void:
	# The map shows one floor; meeting its clear requirement opens stairs, and climbing leaves it behind.
	var t:=TowerController.new();t.new_run(19,73)
	verify(t.current_floor()==0 and not t.can_ascend() and not t.ascend(),"no stairs before the clear requirement")
	var f: FloorState=t.guild.state.tower.map.floors[0]
	for id in f.room_ids.slice(0,f.required_clear_count):t.guild.state.tower.map.get_room(id).cleared=true
	f.cleared_count=f.required_clear_count;t.refresh_progress(0)
	verify(t.can_ascend() and t.ascend() and t.current_floor()==1,"stairs open and climb one floor")
	verify(t.select_room(f.room_ids[-1])==TowerNavigationPolicy.Code.LOCKED_FLOOR,"rooms of a passed floor stay closed")
	verify(t.select_room(t.guild.state.tower.map.floors[1].room_ids[0])==TowerNavigationPolicy.Code.OK,"rooms of the new floor open")
func unit_sheet(tree: SceneTree) -> void:
	# Every unit has its description text, and the sheet opens with every section for a guild member.
	var complete: bool=true
	for id in range(CharacterCatalog.NAMES.size()):
		if UnitLore.story(id).is_empty() or UnitLore.attack(id).is_empty() or UnitLore.passive(id).is_empty() or UnitLore.ultimate(id).is_empty():complete=false
	verify(complete and UnitLore.STORY.size()==CharacterCatalog.NAMES.size(),"unit description text for every unit")
	# 설명 작성 규칙: a summary line, then "• " lines; no damage-kind tags in the text; effects typed.
	var tidy: bool=true
	for id in range(CharacterCatalog.NAMES.size()):
		for text in [UnitLore.attack(id),UnitLore.passive(id),UnitLore.ultimate(id)]:
			var lines: PackedStringArray=text.split("\n")
			if lines[0].begins_with("· ") or lines.size()>5 or text.contains("(물리") or text.contains("(마법"):tidy=false
			for line in lines.slice(1):
				if not line.begins_with("· "):tidy=false
		for e in UnitLore.EFFECTS.get(id,[]):
			if not e[0] in [&"basic",&"passive",&"ultimate"] or not e[1] in ["회복","보호막","강화","약화","제어","기타"]:tidy=false
	verify(tidy,"every description follows the writing rules (summary, bullet lines, no damage tags, typed effects)")
	var font_chars: bool=true
	for id in range(CharacterCatalog.NAMES.size()):
		for text in [UnitLore.attack(id),UnitLore.passive(id),UnitLore.ultimate(id)]:
			for ch in ["「","」","•","✓","↻","＋"]:
				if text.contains(ch):font_chars=false
	verify(font_chars,"descriptions use only characters the game font has")
	var t:=TowerController.new();t.new_run(5,9);var m: GuildMemberState=t.guild.all_members()[0]
	var host:=Control.new();tree.root.add_child(host)
	var sheet:=UnitInfoSheet.open(host,m.unit_type_id,t.guild.member_stats(m),m);await tree.process_frame
	var titles: Array=sheet.find_children("*","Label",true,false).map(func(l):return l.text)
	verify(["행동성향","기본공격","패시브","궁극기","초월 스킬","기본 스탯","특수 스탯"].all(func(x):return x in titles),"unit sheet shows every section")
	var buttons: Array=sheet.find_children("*","Button",true,false)
	var more: Array=buttons.filter(func(x):return x.text=="자세히 보기")
	verify(buttons.any(func(x):return x.text=="전체 보기") and more.size()==4,"stats fold behind 전체 보기; each warrior skill unfolds its damage")
	var special: Label=sheet.find_children("*","Label",true,false).filter(func(l):return l.text=="특수 스탯")[0]
	verify(not special.is_visible_in_tree() and sheet.tab_buttons.size()==2,"special stats wait behind 전체 보기; an owned unit's sheet has the 상태 tab")
	buttons.filter(func(x):return x.text=="전체 보기")[0].pressed.emit()
	verify(special.is_visible_in_tree(),"전체 보기 shows the special stats")
	var researcher:=UnitInfoSheet.open(host,45);await tree.process_frame
	var heal_row: bool=researcher.find_children("*","Label",true,false).any(func(l):return l.text=="증폭 약물: 회복")
	verify(heal_row,"자세히 보기 lists heals and buffs with their numbers")
	researcher.queue_free()
	more[0].pressed.emit()
	verify(more[0].text=="접기" and sheet.find_children("*","Label",true,false).any(func(l):return l.is_visible_in_tree() and l.text.begins_with("물리 피해의 100%  →  예상 ")),"basic attack detail lists base + ratio and the estimate")
	sheet.queue_free()
	# Without a member the sheet shows the table's base numbers.
	sheet=UnitInfoSheet.open(host,30);await tree.process_frame
	var pole_magic: float=UnitStatTable.base_magic(30)*UnitBalance.damage(CharacterCatalog.all()[30])
	verify(is_equal_approx(sheet.stats.magic_damage,pole_magic) and sheet.find_children("*","Label",true,false).any(func(l):return l.text=="10 + 마법 피해의 85%%  →  예상 %d"%roundi(10+.85*pole_magic)),"base sheet: magnet's pole hit is 10 + 85% of its (balanced) magic damage")
	sheet.queue_free();host.queue_free()
## Player stances (StanceRules): numbers, the cautious counter, and effects the situational
## mind must never switch on.
func stances(tree: SceneTree) -> void:
	var b:=duel(tree,[[0,0,Vector2(300,400)],[0,1,Vector2(380,400)],[0,1,Vector2(380,560)]]);b.started=true
	var u: BattleUnit=b.units[0];var e: BattleUnit=b.units[1]
	u.stance=CombatStance.RUSH
	verify(is_equal_approx(CombatRules.stance_factor(u),StanceRules.RUSH_DAMAGE) and is_equal_approx(CombatRules.taken(u),StanceRules.RUSH_TAKEN) and StanceRules.reaction(u).z==0,"rush deals x1.1, takes x1.2, no counter bonus")
	u.stance=CombatStance.CAUTIOUS
	verify(is_equal_approx(CombatRules.stance_factor(u),StanceRules.CAUTIOUS_DAMAGE) and is_equal_approx(CombatRules.taken(u),StanceRules.CAUTIOUS_TAKEN),"cautious deals x1, takes x0.85")
	# Counter: a dodged hit readies +50% on the next hit, +100% after blocking a rusher; no stacking.
	e.stun_remaining=1000;e.combat_stats.max_hp=10000;e.current_hp=10000
	u.evade_remaining=1
	var out: DamageOutcome=b.damage_resolver.resolve(e,u,40,{"critical":false,"impulse":0})
	verify(out.avoided and StanceRules.counter_ready(u) and u.state_value("counterBoostBonus")==StanceRules.COUNTER_BONUS,"cautious dodge readies the counter")
	u.evade_remaining=0
	var plain:=func(raw: float) -> float:return CombatRules.js_round(raw*CombatRules.attack_factor(u)*CombatRules.taken(e)*CombatRules.mitigation(e,&"physical"))
	out=b.damage_resolver.resolve(u,e,100,{"dmg":&"basic","critical":false,"impulse":0})
	verify(out.hp_damage==plain.call(150) and not StanceRules.counter_ready(u),"counter adds 50% to the next hit and is spent")
	out=b.damage_resolver.resolve(u,e,100,{"dmg":&"basic","critical":false,"impulse":0})
	verify(out.hp_damage==plain.call(100),"the hit after it is normal")
	e.stance=CombatStance.RUSH;e.stun_remaining=0
	for i in range(2):u.evade_remaining=1;b.damage_resolver.resolve(e,u,40,{"critical":false,"impulse":0})
	e.stun_remaining=1000;u.evade_remaining=0
	out=b.damage_resolver.resolve(u,e,100,{"dmg":&"basic","critical":false,"impulse":0})
	verify(u.state_value("counterBoosts")==3 and out.hp_damage==CombatRules.js_round(200*CombatRules.attack_factor(u)*CombatRules.taken(e)*CombatRules.mitigation(e,&"physical")),"blocking a rusher doubles the counter; a second block only refreshes it")
	# A merely cautious mood (normal stance) gets no counter.
	u.stance=CombatStance.NORMAL;u.mind.temper=-1;e.stun_remaining=0;u.evade_remaining=1
	out=b.damage_resolver.resolve(e,u,40,{"critical":false,"impulse":0})
	verify(out.avoided and not StanceRules.counter_ready(u),"a normal-stance dodge (cautious mood or not) never readies the counter")
	u.evade_remaining=0;u.mind.temper=0;e.stance=CombatStance.NORMAL
	b.queue_free()
	# Rush keeps the nearest enemy until it dies; a normal unit switches to a far closer one.
	b=duel(tree,[[0,0,Vector2(300,400)],[0,1,Vector2(420,400)],[0,1,Vector2(650,400)]]);b.started=true
	u=b.units[0];var near: BattleUnit=b.units[1];var far: BattleUnit=b.units[2]
	u.stance=CombatStance.RUSH;u.target=u.target_selector.select_target(u,b.units)
	far.position=Vector2(330,420)
	verify(u.target==near and u.target_selector.select_target(u,b.units)==near,"rush sticks to its target")
	u.stance=CombatStance.NORMAL;u.mind.temper=1
	verify(u.mind.charging(u) and u.target_selector.select_target(u,b.units)==far,"a charging mood does not make a normal unit stick")
	u.stance=CombatStance.RUSH;near.receive_damage(99999,far)
	verify(u.target_selector.select_target(u,b.units)==far,"rush retargets once its target falls")
	u.brain.released(u)
	verify(u.brain.disengage_until==0 and u.brain.mode=="approach","rush does not step back after attacking")
	u.stance=CombatStance.CAUTIOUS;u.brain.released(u)
	verify(u.brain.disengage_until>b.clock.elapsed and u.brain.mode=="retreat","cautious steps back after attacking")
	b.queue_free()
	# Cautious targets whoever attacks it, else the most isolated enemy.
	b=duel(tree,[[0,0,Vector2(300,400)],[0,1,Vector2(450,400)],[0,1,Vector2(500,450)],[0,1,Vector2(300,650)]]);b.started=true
	u=b.units[0];u.stance=CombatStance.CAUTIOUS
	verify(u.target_selector.cautious_target(u)==b.units[3],"cautious prefers the isolated enemy")
	b.units[1].combat_state=CombatController.State.WINDUP;b.units[1].combat.attack_target=u
	verify(u.target_selector.cautious_target(u)==b.units[1],"cautious answers the enemy attacking it")
	b.units[1].combat_state=CombatController.State.IDLE
	b.queue_free()
	# Cautious waits for the enemy's first swing (up to a limit), and does not chase a runner.
	b=duel(tree,[[0,0,Vector2(300,400)],[0,1,Vector2(360,400)]]);b.started=true;b.clock.elapsed=1
	u=b.units[0];e=b.units[1];u.stance=CombatStance.CAUTIOUS;u.mind.enabled=false
	u.brain.update_spacing(u,e);u.brain.spacing.probe=0;u.brain.next_initiative_at=0;u.brain.hesitations=2;u.combat.cooldown=0;u.parry_cooldown=99
	u.brain.advance(u,e,1.0/60)
	verify(u.brain.commit_until==0,"cautious holds its first attack until the enemy swings")
	b.clock.elapsed=1+StanceRules.CAUTIOUS_FIRST_WAIT+.1;u.brain.spacing.probe=0;u.brain.advance(u,e,1.0/60)
	verify(u.brain.commit_until>b.clock.elapsed,"cautious takes the initiative after the wait limit")
	u.brain.commit_until=0;u.brain.attack_decision.clear()
	verify(not u.brain.move_home(u,e,.1) and u.brain.home_set,"contact remembers where the cautious unit fought")
	e.position=Vector2(650,400)
	verify(u.brain.move_home(u,e,.1) and u.brain.movement_override=="cautious_return","a runner is not chased: back to its spot")
	b.clock.elapsed+=StanceRules.CAUTIOUS_HOME_TIME+.1
	verify(not u.brain.move_home(u,e,.1),"after waiting, it closes in again")
	u.stance=CombatStance.NORMAL;u.brain.home_set=true;u.brain.home_since=-1
	verify(not u.brain.move_stance(u,e,.1) or u.brain.movement_override!="cautious_return","the leash is cautious-only")
	# Situational mood flips show a short popup; the stance itself is a fixed icon.
	u.mind.enabled=true
	var marks:=StanceMarks.new();u.mind.temper=.8;marks.track(b,1)
	var first: Dictionary=marks.popups.get(u.battle_id,{})
	marks.track(b,1.2)
	verify(int(first.get("mood",0))==1 and is_equal_approx(float(marks.popups[u.battle_id].start),1),"charging mood pops up once when it starts")
	u.mind.temper=-.6;marks.track(b,2)
	verify(int(marks.popups[u.battle_id].mood)==-1,"cautious mood pops up when it starts")
	b.queue_free()
## Stat table coverage and the damage formula on live custom-battle units.
func stat_damage(tree: SceneTree) -> void:
	var tagged: bool=true
	for id in range(CharacterCatalog.NAMES.size()):
		var unit_name: String=CharacterCatalog.NAMES[id]
		if not UnitStatTable.STATS.has(unit_name) or not UnitStatTable.DAMAGE.has(unit_name):tagged=false
		for d in UnitStatTable.instances(id):
			if not UnitStatTable.KIND_NAMES.has(d.kind) or not d.tags.all(func(t):return t in UnitStatTable.ELEMENTS+UnitStatTable.DAMAGE_TAGS):tagged=false
	verify(tagged and CharacterCatalog.NAMES.size()==47,"all 47 units have base stats and exactly one kind plus known tags per damage instance")
	verify(UnitStatTable.mitigation(0)==1 and UnitStatTable.mitigation(100)==.5 and is_equal_approx(UnitStatTable.mitigation(-100),1.5),"mitigation 100/(100+def), 2-100/(100-def) below zero")
	# Bomber (fire · explosion · area) hits a mage.
	var b:=duel(tree,[[13,0,Vector2(300,400)],[2,1,Vector2(380,400)]]);var src: BattleUnit=b.units[0];var tgt: BattleUnit=b.units[1];b.started=true
	# Stunned: no dodge, parry or unique defense gets in the way of the numbers.
	tgt.stun_remaining=1000;tgt.combat_stats.max_hp=10000;tgt.current_hp=10000
	var st: UnitCombatStats=src.combat_stats
	st.tag_bonus={&"explosion":.2,&"area":.1};st.element_bonus={&"fire":.3,&"ice":5.0};st.element_power=1.5;st.crit_damage=2;st.ult_damage=3
	var expect:=func(raw: float,factor: float,kind: StringName) -> float:return CombatRules.js_round(raw*CombatRules.attack_factor(src)*factor*CombatRules.taken(tgt)*CombatRules.mitigation(tgt,kind))
	var hp: float=tgt.current_hp
	var out: DamageOutcome=b.damage_resolver.resolve(src,tgt,100,{"dmg":&"basic","critical":false,"impulse":0})
	verify(out.hp_damage==expect.call(100,1.6*1.5,&"physical") and hp-tgt.current_hp==out.hp_damage,"matching tag and element bonuses add up, element % multiplies, unrelated element ignored")
	tgt.current_hp=tgt.max_hp;st.crit=1
	out=b.damage_resolver.resolve(src,tgt,100,{"dmg":&"basic","impulse":0})
	verify(out.critical and out.hp_damage==expect.call(100,1.6*1.5*2,&"physical"),"critical hits use crit damage")
	tgt.current_hp=tgt.max_hp;st.crit=0
	out=b.damage_resolver.resolve(src,tgt,100,{"dmg":&"ult","critical":false,"impulse":0})
	verify(out.ultimate and out.hp_damage==expect.call(100,1.6*1.5*3,&"physical"),"ultimate damage % on ultimate instances")
	tgt.current_hp=tgt.max_hp
	out=b.damage_resolver.resolve(src,tgt,100,{"dmg":&"basic","mirror_raw":true,"critical":false,"impulse":0})
	verify(out.hp_damage==CombatRules.js_round(100*CombatRules.taken(tgt)*CombatRules.mitigation(tgt,&"physical")),"reflected damage meets only the target's defense")
	tgt.current_hp=tgt.max_hp;tgt.combat_stats.physical_defense=-300
	out=b.damage_resolver.resolve(src,tgt,100,{"dmg":&"basic","mirror_raw":true,"critical":false,"impulse":0})
	verify(out.hp_damage>100 and out.hp_damage==CombatRules.js_round(100*CombatRules.taken(tgt)*(2-100.0/(100-(CombatRules.defense_sum(tgt)-300)))),"negative defense increases damage")
	tgt.combat_stats.physical_defense=0
	verify(is_equal_approx(UnitStatTable.raw(src,&"self_destruct"),st.physical_damage*2.5) and is_equal_approx(UnitStatTable.raw(b.units[1],&"basic"),tgt.combat_stats.magic_damage),"raw = base + kind damage x ratio")
	b.queue_free()
	# Level growth: HP 12%, damage and defense 8% per level; elites scale attack %.
	var g:=GuildManager.new();g.state.tower=TowerRunState.new();var m: GuildMemberState=g.create_member(2);m.total_exp=GrowthRules.exp_for_level(5)
	var grown: UnitCombatStats=g.member_stats(m)
	var mage_bal: float=UnitBalance.damage(CharacterCatalog.all()[2])
	verify(is_equal_approx(grown.magic_damage,UnitStatTable.base_magic(2)*1.4*mage_bal) and is_equal_approx(grown.defense,35*1.4) and grown.magic_defense==10 and grown.attack==1,"growth raises damage stats and defense, attack % stays 100%")
	var entry:=EnemySpawnEntry.new();entry.level=0;entry.set_rank(&"elite")
	var elite: UnitCombatStats=TowerEnemyStatsAssembler.assemble(CharacterCatalog.all()[2],entry)
	verify(elite.attack==entry.damage_multiplier and elite.attack>1 and is_equal_approx(elite.magic_damage,UnitStatTable.base_magic(2)*.8*mage_bal),"elite damage multiplier becomes attack %")
func tactical_mind(tree: SceneTree) -> void:
	# Every unit has a base role, shown first among its traits.
	var roles: bool=true
	for data in CharacterCatalog.all().values():
		if TacticalMind.trait_names(data)[0] not in TacticalMind.ROLE_NAMES.values():roles=false
	verify(roles,"every unit has one base role")
	var make:=func(rows: Array) -> BattleManager:
		var b:=BattleManager.new();b.auto_start=false;tree.root.add_child(b);var placements: Array[Dictionary]=[]
		for row in rows:placements.append({"data":CharacterCatalog.all()[row[0]],"team":row[1],"position":row[2]})
		b.start_battle(placements,11);b.set_physics_process(false);b.clock.elapsed=1;return b
	# HP and the balance of the fight move the temper.
	var b: BattleManager=make.call([[0,0,Vector2(300,400)],[0,1,Vector2(500,400)]]);var u: BattleUnit=b.units[0]
	u.mind.next_eval=-INF;var healthy: float=u.mind.bias(u)
	u.current_hp=u.max_hp*.15;u.mind.next_eval=-INF;var hurt: float=u.mind.bias(u)
	verify(hurt<healthy-.3,"low HP turns a unit cautious")
	verify(u.mind.parry_factor(u)>1 and u.mind.parry_mistake(u,.3)<.3,"a cautious mind parries better and times it better")
	b.free()
	b=make.call([[0,0,Vector2(300,400)],[1,0,Vector2(250,300)],[5,0,Vector2(250,500)],[0,1,Vector2(500,400)]]);u=b.units[0];u.mind.next_eval=-INF
	verify(u.mind.bias(u)>.45 and u.mind.charging(u),"a healthy melee unit that outnumbers the enemy presses the attack")
	b.free()
	# A far-off swing at someone else is ignored; a shot aimed at a healthy unit is parried, not dodged.
	b=make.call([[0,0,Vector2(150,400)],[0,0,Vector2(560,420)],[0,1,Vector2(620,400)],[1,1,Vector2(620,200)]]);u=b.units[0]
	var foe: BattleUnit=b.units[2];foe.combat.attack_target=b.units[1];foe.combat_state=CombatController.State.WINDUP
	verify(u.mind.adjust_reaction(u,{"parry":.4,"dodge":.2,"counter":.3,"hold":.1},foe).hold==1.0,"a distant attack on an ally is ignored")
	var archer: BattleUnit=b.units[3];archer.combat.attack_target=u;u.parry_cooldown=0
	var odds: Dictionary=u.mind.adjust_reaction(u,{"parry":.4,"dodge":.2,"counter":.3,"hold":.1},archer)
	verify(odds.dodge==0 and odds.parry>.4,"a healthy unit blocks a shot aimed at it")
	u.current_hp=u.max_hp*.2;u.mind.next_eval=-INF
	odds=u.mind.adjust_reaction(u,{"parry":.4,"dodge":.2,"counter":.3,"hold":.1},archer)
	verify(odds.dodge>odds.parry,"a hurt unit sidesteps a shot aimed at it")
	b.free()
	# A guard goes for whoever is attacking a nearby ally.
	b=make.call([[4,0,Vector2(300,400)],[1,0,Vector2(380,400)],[0,1,Vector2(450,400)],[0,1,Vector2(250,300)]]);u=b.units[0]
	var attacker: BattleUnit=b.units[2];attacker.combat.attack_target=b.units[1];attacker.combat_state=CombatController.State.WINDUP
	verify(u.mind.pick_target(u,b.units[3])==attacker,"a guard targets the enemy attacking its ally")
	b.free()

## Element statuses (ElementEffects): burn, poison, frost/frostbite, shock + chain, wind, light, dark.
func element_effects(tree: SceneTree) -> void:
	var b:=duel(tree,[[13,0,Vector2(150,250)],[30,0,Vector2(150,330)],[5,0,Vector2(150,410)],[2,0,Vector2(150,490)],[0,0,Vector2(150,570)],[8,1,Vector2(500,400)],[6,1,Vector2(500,470)],[8,1,Vector2(570,400)]])
	step(b,.05)
	var bomber: BattleUnit=b.units[0];var magnet: BattleUnit=b.units[1];var healer: BattleUnit=b.units[2];var mage: BattleUnit=b.units[3];var warrior: BattleUnit=b.units[4]
	var foe: BattleUnit=b.units[5];var near: BattleUnit=b.units[6];var side: BattleUnit=b.units[7]
	var calm:=func():
		for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.ultimate_gauge=0;u.stance=CombatStance.NORMAL
	var hit:=func(source: BattleUnit,target: BattleUnit,key: StringName) -> DamageOutcome:
		var out: DamageOutcome=b.damage_resolver.resolve(source,target,UnitStatTable.raw(source,key),{"dmg":key,"critical":false,"impulse":0})
		calm.call();return out
	calm.call()
	# 화염: procs on fire hits, burns a stack every half second and scorches nearby allies only.
	for i in range(20):
		hit.call(bomber,foe,&"basic")
		for u in b.units:u.current_hp=u.max_hp
	verify(foe.state_value("burnStacks")>0 and foe.state_value("burnStacks")<=ElementEffects.BURN_MAX,"fire hits add burn stacks (capped)")
	for u in b.units:u.current_hp=u.max_hp;u.character_specific_state.clear()
	ElementEffects.add_burn(bomber,foe,2)
	step(b,.55);calm.call()
	verify(foe.state_value("burnStacks")==1 and foe.current_hp<foe.max_hp,"a burn tick spends one stack for damage")
	verify(near.current_hp<near.max_hp and near.state_value("burnStacks")==0,"the burning unit scorches a nearby ally without passing stacks")
	verify(bomber.current_hp==bomber.max_hp,"burn spread never touches the other side")
	# 맹독: stacks stay, tick every second by stack count, and cut healing.
	for u in b.units:u.current_hp=u.max_hp;u.character_specific_state.clear()
	foe.set_state("poisonStacks",3);foe.set_state("poisonSource",bomber.actor_id())
	step(b,1.05);calm.call()
	var lost: float=foe.max_hp-foe.current_hp
	verify(lost>0 and foe.state_value("poisonStacks")==3,"poison ticks and its stacks never fade")
	foe.current_hp=foe.max_hp*.5
	var gain: float=CharacterAbility.restore_hp(foe,20)
	verify(is_equal_approx(gain,20*foe.healing_received*ElementEffects.POISON_HEAL),"poisoned units receive 60% healing")
	# 얼음: 10 stacks freeze for 4s, then frostbite (+10% taken, frost turns into a 5 damage hit).
	for u in b.units:u.current_hp=u.max_hp;u.character_specific_state.clear();u.stun_remaining=0
	ElementEffects.add_frost(bomber,foe,10)
	verify(foe.state_value("frozenTime")>0 and foe.stun_remaining>=3.9,"ten frost stacks freeze for 4 seconds")
	ElementEffects.add_frost(bomber,foe,3)
	verify(foe.state_value("frostStacks")==0,"no frost builds while frozen")
	step(b,4.1);calm.call()
	verify(foe.state_value("frozenTime")<=0 and foe.state_value("frostbiteTime")>0 and is_equal_approx(CombatRules.taken(foe),ElementEffects.FROSTBITE_TAKEN*StanceRules.taken(foe)),"thawing leaves frostbite (+10% damage taken)")
	var before: float=foe.current_hp
	ElementEffects.add_frost(bomber,foe,1);step(b,.05);calm.call()
	verify(foe.state_value("frostStacks")==0 and foe.current_hp<before,"frost on a frostbitten unit deals extra damage instead of stacking")
	# 번개: shock stacks stun at 5; lightning hits jump to other enemies for 60%.
	step(b,4);for u in b.units:u.current_hp=u.max_hp;u.character_specific_state.clear();u.stun_remaining=0
	calm.call()
	var out: DamageOutcome=hit.call(magnet,foe,&"basic")
	verify(foe.state_value("shockStacks")==1,"a lightning hit adds a shock stack")
	verify(near.current_hp<near.max_hp and side.current_hp<side.max_hp,"the hit jumps on to the other enemies")
	verify(out.hp_damage>0 and side.max_hp-side.current_hp<=out.hp_damage+out.shield_absorbed,"jumps deal at most the hit's damage")
	for i in range(4):hit.call(magnet,foe,&"basic")
	verify(foe.stun_remaining>0 and foe.state_value("shockStacks")==0,"five shock stacks stun")
	hit.call(magnet,foe,&"basic")
	verify(foe.state_value("shockStacks")==0,"no shock builds while stunned")
	# 바람: gusts raise attack speed until a direct hit lands; headwind slows.
	for u in b.units:u.current_hp=u.max_hp;u.character_specific_state.clear();u.stun_remaining=0
	var speed: float=EquipmentCombatEffects.attack_speed(warrior)
	warrior.set_state("windStacks",4)
	verify(is_equal_approx(EquipmentCombatEffects.attack_speed(warrior),speed*1.2),"each gust stack adds 5% attack speed")
	hit.call(foe,warrior,&"basic")
	verify(warrior.state_value("windStacks")==0,"a direct hit resets the gusts")
	var walk: float=foe.move_speed;foe.set_state("headwindTime",2)
	verify(is_equal_approx(foe.move_speed,walk*ElementEffects.HEADWIND_MOVE),"headwind slows movement")
	# 빛: light damage heals allies around the attacker; another unit's hit pops the mark.
	for u in b.units:u.current_hp=u.max_hp*.5;u.character_specific_state.clear()
	foe.current_hp=foe.max_hp
	hit.call(healer,foe,&"basic")
	verify(healer.current_hp>healer.max_hp*.5 and mage.current_hp>mage.max_hp*.5,"light damage heals the attacker and nearby allies")
	verify(str(foe.character_specific_state.get("lightMark",""))==healer.actor_id(),"light marks the target")
	var w: float=warrior.current_hp
	hit.call(warrior,foe,&"basic")
	verify(not foe.character_specific_state.has("lightMark") and warrior.current_hp>w,"another unit's direct hit pops the mark and heals")
	# 어둠: erosion hurts on actions and boosts crits taken; another unit's hit pops the mark for +20%.
	for u in b.units:u.current_hp=u.max_hp;u.character_specific_state.clear()
	hit.call(mage,foe,&"ult")
	verify(foe.state_value("erosionTime")>0 and str(foe.character_specific_state.get("darkMark",""))==mage.actor_id(),"dark hits erode and mark")
	verify(is_equal_approx(ElementEffects.crit_taken(foe),.25),"eroded units take +25% critical damage")
	before=foe.current_hp
	ElementEffects.on_action(foe);step(b,.02);calm.call()
	verify(foe.current_hp<before,"acting while eroded hurts")
	var spec: Dictionary=UnitStatTable.spec(warrior.data.type_id,&"basic")
	verify(is_equal_approx(ElementEffects.outgoing(warrior,foe,spec,{}),ElementEffects.DARK_POP) and is_equal_approx(ElementEffects.outgoing(mage,foe,spec,{}),1),"the mark boosts only another unit's hit")
	hit.call(warrior,foe,&"basic")
	verify(not foe.character_specific_state.has("darkMark"),"a direct hit pops the dark mark")
	b.queue_free()
	# Element tags per unit (0.65.0).
	var tagged:=func(type: int,element: StringName) -> bool:
		return UnitStatTable.instances(type).all(func(d):return d.key==&"transcend" or d.tags.has(element))
	verify(tagged.call(1,&"wind") and tagged.call(11,&"ice") and tagged.call(24,&"poison"),"archer wind, dolphin ice, frog poison on every attack")
	verify(tagged.call(15,&"lightning") and not UnitStatTable.instances(15).any(func(d):return d.tags.has(&"fire") or d.tags.has(&"light")) and CharacterCatalog.all()[15].recruit_tokens==4,"satellite deals lightning (0.81.0) and is a hero-grade unit")
	var zeal: Dictionary=UnitStatTable.spec(19,&"basic")
	verify(zeal.kind==&"physical" and zeal.tags.has(&"dark") and not zeal.tags.has(&"light"),"fanatic basic is physical dark")
	verify(tagged.call(22,&"dark") and UnitStatTable.spec(22,&"ult").tags.has(&"dot"),"galaxy deals dark, its ultimate over time")
	b=duel(tree,[[22,0,Vector2(200,400)],[8,1,Vector2(480,400)]])
	step(b,.05)
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0
	var star: BattleUnit=b.units[0];foe=b.units[1]
	b.zones.add(star,"galaxy",foe.position,270,7,{"target":foe.actor_id()})
	before=foe.current_hp
	step(b,1.05)
	verify(foe.current_hp<before and foe.state_value("erosionTime")>0,"galaxy state deals dark damage over time")
	b.queue_free()

## Attack speed must show in how often units actually attack, not only in the cooldown (0.66.0).
func attack_speed_pace(tree: SceneTree) -> void:
	var rates: Array=[]
	for factor in [1.0,2.0]:
		var released: float=0
		for seed in range(1,4):
			var b:=duel(tree,[[3,0,Vector2(250,330)],[3,0,Vector2(250,470)],[3,1,Vector2(550,330)],[3,1,Vector2(550,470)]],seed)
			for u in b.units:
				u.combat_stats.max_hp=6000;u.current_hp=6000
				if u.team==0:u.combat_stats.attack_speed=factor
			step(b,20)
			for u in b.units:
				if u.team==0:released+=u.combat.attacks_released
			b.queue_free()
		rates.append(released)
	verify(rates[1]>=rates[0]*1.35,"double attack speed attacks clearly more often (%d -> %d)"%[rates[0],rates[1]])

## 히어로 (0.67.0): the rescue shields the ally the moment it triggers; the ultimate grabs the enemy,
## holds it while the fist is drawn back, then punches.
func hero_moves(tree: SceneTree) -> void:
	var b:=duel(tree,[[17,0,Vector2(150,250)],[0,0,Vector2(420,520)],[4,1,Vector2(520,560)]])
	step(b,.05)
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0
	var hero: BattleUnit=b.units[0];var ally: BattleUnit=b.units[1];var foe: BattleUnit=b.units[2]
	ally.current_hp=3
	b.damage_resolver.resolve(foe,ally,200,{"critical":false})
	verify(ally.alive and not hero.hero_rescue.is_empty() and ally.shield_hp>=60 and b.combat_event_counts.get(&"hero_call",0)==1,"rescue cancels the lethal hit and shields the ally at once")
	step(b,1.5)
	verify(b.combat_event_counts.get(&"hero_rescue",0)==1,"the hero lands with a shockwave")
	b.queue_free()
	b=duel(tree,[[17,0,Vector2(200,400)],[8,1,Vector2(480,400)]])
	step(b,.05)
	hero=b.units[0];foe=b.units[1]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000
	hero.ultimate_gauge=100
	var grabbed: bool=false;var held: bool=true
	for i in range(60*5):
		step(b,1.0/60)
		if b.combat_event_counts.get(&"hero_grab",0)>0 and hero.ultimate.cast.get("phase","")=="punch":
			grabbed=true
			held=held and foe.stun_remaining>0 and foe.position.distance_to(hero.position)<90
		if b.combat_event_counts.get(&"hero_punch",0)>0:break
	verify(grabbed and held,"the ultimate grabs and holds the enemy while charging")
	verify(b.combat_event_counts.get(&"hero_punch",0)==1,"then punches with a shockwave")
	b.queue_free()

## Custom battle result (0.69.0): shown shortly after the end, owned by its battle, and a rematch or a
## paused spectator view never leaves the old battle's result or picture behind.
func custom_result_flow(tree: SceneTree) -> void:
	var cs:=CustomBattleScreen.new();tree.root.add_child(cs);await tree.process_frame
	cs.setup.add(13,1,Vector2(200,400));cs.setup.add(0,2,Vector2(320,400))
	cs.start_battle();await tree.process_frame
	cs.battle.finish_with_reason(BattleEndReason.Value.VICTORY,1)
	cs._process(.5)
	verify(not cs.winner_panel.visible,"the result waits for the final slow motion")
	cs.start_battle();await tree.process_frame
	cs._process(2.0)
	verify(not cs.winner_panel.visible and not cs.battle.finished,"a rematch drops the old battle's pending result")
	cs._toggle_pause()
	cs.start_battle();await tree.process_frame
	verify(not cs.watch_paused and cs.board.presentation.is_processing(),"a rematch resumes a paused view")
	cs.battle.finish_with_reason(BattleEndReason.Value.VICTORY,1)
	cs._process(.8);cs._process(.7)
	verify(cs.winner_panel.visible,"the result shows about 1.4 s after the end")
	cs.queue_free();await tree.process_frame

## 상태이상 (0.70.0): StatusCatalog lists what a unit carries; the unit sheet's 상태 tab shows it.
func status_sheet(tree: SceneTree) -> void:
	var b:=duel(tree,[[12,0,Vector2(200,400)],[23,1,Vector2(480,400)]])
	step(b,.05)
	var predator: BattleUnit=b.units[0];var gunner: BattleUnit=b.units[1]
	predator.set_state("predatorStacks",3);predator.set_state("burnStacks",4);predator.set_state("darkMark",gunner.actor_id())
	StatusController.stun(predator,2);predator.shield_hp=40;predator.shield_remaining=5
	var keys: Array=StatusCatalog.collect(predator).map(func(r):return r.key)
	verify(keys.has(&"predator") and keys.has(&"burn") and keys.has(&"dark_mark") and keys.has(&"stun") and keys.has(&"shield"),"collect lists growth, debuffs, marks, control and buffs")
	verify(StatusCatalog.collect(gunner).any(func(r):return r.key==&"ammo"),"unit resources such as ammo are listed")
	for row in StatusCatalog.collect(predator):verify(StatusCatalog.ENTRIES.has(row.key),"every collected status is described in the codex")
	var t:=TowerController.new();t.new_run(5,9);var m: GuildMemberState=t.guild.all_members()[0]
	m.character_specific_state={"predatorStacks":2,"shieldHp":30.0,"shieldTime":4.0}
	var member_keys: Array=StatusCatalog.collect(m,t.guild.member_stats(m)).map(func(r):return r.key)
	verify(member_keys.has(&"predator") and member_keys.has(&"shield"),"a waiting guild member's carried statuses are listed")
	var host:=Control.new();tree.root.add_child(host);await tree.process_frame
	verify(host.get_window()!=null,"sheet host is in a window")
	if host.get_window()==null:return
	var sheet:=UnitInfoSheet.open(host,predator.data.type_id,predator.combat_stats,null,predator);await tree.process_frame
	sheet._show_tab("status");await tree.process_frame
	verify(sheet.tab_buttons.size()==2 and sheet.status_body.visible and not sheet.info_body.visible,"a field unit's sheet has 정보 / 상태 tabs")
	verify(sheet.status_body.get_child_count()>=5+keys.size()-1,"상태 tab shows the gauges and one row per status")
	sheet._show_tab("info");sheet.queue_free()
	var plain:=UnitInfoSheet.open(host,3);await tree.process_frame
	verify(plain.tab_buttons.is_empty() and plain.info_body.visible,"a sheet without a unit instance has no 상태 tab")
	plain.queue_free();host.queue_free();b.queue_free();await tree.process_frame

const CrossbowAbilityRef=preload("res://scripts/abilities/crossbow_ability.gd")
## 그리핀 (33) and 석궁 (34), 0.72.0.
func griffin_and_crossbow(tree: SceneTree) -> void:
	# 그리핀: fixed (never walks), dashes in on its attack and leaves a wind storm.
	var b:=duel(tree,[[33,0,Vector2(200,400)],[4,1,Vector2(420,400)]])
	step(b,.05)
	var griffin: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	verify(TacticalMind.role(griffin.data)==TacticalMind.FIXED and griffin.data.recruit_tokens==4,"griffin is a fixed 4-token unit")
	foe.move_speed=0;foe.combat.cooldown=1000;foe.parry_cooldown=1000;foe.defense_cooldown=1000
	var start: Vector2=griffin.position
	for i in range(60*4):
		step(b,1.0/60)
		if b.zones.entries.any(func(z):return z.kind=="griffinStorm"):break
	verify(b.zones.entries.any(func(z):return z.kind=="griffinStorm") and griffin.position.distance_to(start)>60,"griffin dashes in and raises a storm")
	var hp: float=foe.current_hp
	step(b,1.2)
	verify(foe.current_hp<hp and foe.state_value("headwindTime")>0,"the storm deals wind damage over time")
	b.queue_free()
	# Gust: knocks back, and a unit thrown into another is stunned.
	# The blocker is the griffin's own ally, outside the cone, so only the thrown enemy flies.
	b=duel(tree,[[33,0,Vector2(200,400)],[8,1,Vector2(330,400)],[4,0,Vector2(440,400)]])
	step(b,.05)
	griffin=b.units[0];var front: BattleUnit=b.units[1];var back: BattleUnit=b.units[2]
	front.position=Vector2(330,400);back.position=Vector2(440,400)
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0
	griffin.ability.gust(griffin,0.0)
	verify(front.knockback_velocity.length()>200 and front.current_hp<front.max_hp,"the gust damages and throws enemies back")
	var stunned: bool=false
	for i in range(60):
		step(b,1.0/60)
		if front.stun_remaining>0 or back.stun_remaining>0:stunned=true;break
	verify(stunned,"a unit thrown into another is stunned")
	b.queue_free()
	# 석궁: a magazine of seven bolts, each bolt its own basic attack, then a reload.
	b=duel(tree,[[34,0,Vector2(200,400)],[4,1,Vector2(480,400)],[4,1,Vector2(520,450)]])
	step(b,.05)
	var bow: BattleUnit=b.units[0]
	for u in b.units.slice(1):u.move_speed=0;u.combat.cooldown=1000
	var seen: Dictionary={};var released0: int=bow.combat.attacks_released;var reloaded: bool=false
	for i in range(60*10):
		step(b,1.0/60)
		for p in b.projectiles:
			if p.source==bow and p.kind=="crossBolt":seen[p.projectile_id]=true
		if bow.state_value("reloadRemaining")>0:reloaded=true
		if seen.size()>=7:break
	verify(seen.size()>=7 and bow.combat.attacks_released-released0==seen.size(),"crossbow: every bolt is one basic attack (%d bolts, %d attacks)"%[seen.size(),bow.combat.attacks_released-released0])
	verify(reloaded and int(bow.state_value("bolts"))==0 and not bow.combat.can_start(bow,b.units[1]),"after seven bolts the crossbow reloads before shooting again")
	step(b,CrossbowAbilityRef.RELOAD+.1)
	verify(int(bow.state_value("bolts"))==7 and StatusCatalog.collect(bow).any(func(r):return r.key==&"bolts"),"the reload refills the magazine (shown in 상태이상)")
	bow.ability.burst(bow,b.units[1].position)
	var marked: Array=b.units.slice(1).filter(func(e):return e.state_value("targetedTime")>0)
	verify(marked.size()==2,"the marking shell bursts and marks every enemy in the blast")
	var spec: Dictionary=UnitStatTable.spec(34,&"basic");bow.set_state("windStacks",0)
	verify(is_equal_approx(ElementEffects.taken(marked[0]),1.1*(ElementEffects.FROSTBITE_TAKEN if marked[0].state_value("frostbiteTime")>0 else 1.0)) and is_equal_approx(ElementEffects.outgoing(bow,marked[0],spec,{})*ElementEffects.TARGETED_TAKEN,ElementEffects.TARGETED_WIND),"목표: +10% damage taken, +15% wind damage taken")
	verify(StatusCatalog.collect(marked[0]).any(func(r):return r.key==&"targeted"),"목표 shows in the unit's 상태이상")
	b.queue_free()

## 불의 검사 (40) and the 0.81.0 tag changes.
func flame_blade_and_tags(tree: SceneTree) -> void:
	verify(UnitStatTable.spec(0,&"basic").tags.has(&"melee") and UnitStatTable.spec(17,&"ult").tags.has(&"melee") and not UnitStatTable.spec(1,&"basic").tags.has(&"melee") and UnitStatTable.TAG_NAMES[&"melee"]=="근접공격","근접공격 tag on melee hits only")
	verify(UnitStatTable.instances(17).all(func(d):return d.key==&"transcend" or d.tags.has(&"lightning")) and CharacterCatalog.element(17)==&"lightning","히어로: every hit carries lightning")
	verify(UnitStatTable.instances(15).all(func(d):return not d.tags.has(&"light") and (d.key==&"transcend" or d.tags.has(&"lightning"))),"소형 위성: lightning instead of light")
	verify(CharacterCatalog.all()[38].tags.has("대치형"),"역병 is 대치형")
	var b:=duel(tree,[[40,0,Vector2(300,400)],[4,1,Vector2(370,400)],[0,1,Vector2(330,470)]])
	step(b,.05)
	var fb: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1];var side: BattleUnit=b.units[2]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	b.damage_resolver.resolve(fb,foe,10,{"dmg":&"basic","critical":false,"transcendent":true})
	verify(int(foe.state_value("burnStacks"))==5,"불의 검: each slash sets 5 burn stacks")
	side.set_state("burnStacks",8.0)
	var hp: float=side.current_hp;fb.ultimate_gauge=100
	verify(fb.ultimate.request(fb,foe),"the swordsman starts its ultimate")
	var ignited: bool=false
	for i in range(60*2):
		step(b,1.0/60)
		if b.combat_event_counts.get(&"ignite",0)>0:ignited=true;break
	verify(ignited and side.state_value("burnStacks")==0 and side.current_hp<hp-UnitStatTable.raw(fb,&"ult")*.3,"the circular cut ignites every burn stack for extra damage")
	b.queue_free()

## 눈사람 (41) and 산타 (42), 0.82.0.
func snowman_and_santa(tree: SceneTree) -> void:
	verify(UnitStatTable.spec(41,&"basic").tags.has(&"melee") and UnitStatTable.spec(41,&"basic").tags.has(&"ice") and UnitStatTable.spec(41,&"basic").kind==&"magic","눈사람: ice club is magic · ice · melee")
	verify(UnitStatTable.spec(41,&"burst").tags.has(&"explosion") and UnitStatTable.spec(42,&"basic").kind==&"physical" and CharacterCatalog.all()[42].tags.has("방황"),"burst is an explosion; 산타 is physical and 방황")
	var b:=duel(tree,[[41,0,Vector2(200,400)],[4,1,Vector2(330,400)],[0,1,Vector2(400,460)]])
	step(b,.05)
	var sm: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1];var foe2: BattleUnit=b.units[2]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	var hp: float=foe.current_hp+foe2.current_hp;sm.ultimate_gauge=100
	verify(sm.ultimate.request(sm,foe),"the snowman starts its ultimate")
	var furthest: float=0;var burst: bool=false
	for i in range(60*4):
		step(b,1.0/60);furthest=maxf(furthest,foe.position.x)
		if b.combat_event_counts.get(&"snowball_burst",0)>0:burst=true;break
	verify(burst and furthest>600,"the snowball drags the enemies it hits to the wall and bursts")
	verify(foe.current_hp+foe2.current_hp<hp and (foe.state_value("frostStacks")>=3 or foe.state_value("frozenTime")>0),"the roll and burst hurt and put 3 frost stacks on")
	verify(not sm.character_specific_state.has("snowball"),"the ball is gone after bursting")
	b.queue_free()
	b=duel(tree,[[42,0,Vector2(300,400)],[4,0,Vector2(240,400)],[0,1,Vector2(420,400)],[4,1,Vector2(460,460)]])
	step(b,.05)
	var santa: BattleUnit=b.units[0];var ally: BattleUnit=b.units[1];foe=b.units[2];foe2=b.units[3]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	santa.ultimate_gauge=100
	verify(santa.ultimate.request(santa,foe),"Santa starts the ultimate")
	var gone: bool=false
	for i in range(60*2):
		step(b,1.0/60)
		if santa.state_value("santaAway")>0:gone=true;break
	verify(gone and santa.unavailable() and not AttackVisuals.body_visible(santa),"Santa vanishes and cannot be targeted")
	step(b,SantaRef.AWAY_TIME+.2)
	verify(b.combat_event_counts.get(&"santa_gift",0)==3 and not santa.unavailable() and b.combat_event_counts.get(&"santa_back",0)==1,"a gift lands on every other unit, then Santa returns")
	ally.set_state("giftPowerTime",0);foe.set_state("giftWeakTime",0)
	var plain: float=ElementEffects.taken(foe)*ElementEffects.outgoing(ally,foe,UnitStatTable.spec(4,&"basic"),{})
	santa.ability.give(santa,foe,&"weak");santa.ability.give(santa,ally,&"power")
	verify(is_equal_approx(ElementEffects.taken(foe)*ElementEffects.outgoing(ally,foe,UnitStatTable.spec(4,&"basic"),{}),plain*2.25),"받는 피해 +50% and 공격력 +50% gifts stack")
	foe.ultimate_gauge=80;santa.ability.give(santa,foe,&"drain");santa.ability.give(santa,foe,&"root")
	foe.move_speed=100;foe.velocity=Vector2(100,0);var at: Vector2=foe.position;step(b,.5)
	verify(foe.ultimate_gauge<1 and foe.position.distance_to(at)<2 and StatusCatalog.collect(foe).any(func(r):return r.key==&"rooted"),"the gauge empties and a rooted enemy cannot move")
	var low: float=ally.max_hp*.4;ally.current_hp=low;santa.ability.give(santa,ally,&"heal30");ally.ultimate_gauge=0;santa.ability.give(santa,ally,&"ult_full")
	verify(ally.current_hp>low+ally.max_hp*.25 and ally.ultimate_gauge>=99,"ally gifts heal and fill the gauge")
	b.queue_free()

## 통계 page totals (0.83.0).
func battle_stats(tree: SceneTree) -> void:
	var b:=duel(tree,[[0,0,Vector2(300,400)],[4,0,Vector2(240,460)],[35,1,Vector2(380,400)],[1,1,Vector2(600,600)]])
	step(b,.05)
	var w: BattleUnit=b.units[0];var ally: BattleUnit=b.units[1];var slime: BattleUnit=b.units[2];var archer: BattleUnit=b.units[3]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	var hp: float=archer.current_hp
	b.damage_resolver.resolve(w,archer,40,{"dmg":&"basic","critical":false,"transcendent":true})
	var hit: float=hp-archer.current_hp
	ally.current_hp=ally.max_hp*.5;var healed: float=CharacterAbility.restore_hp(ally,30,w)
	w.ultimate_gauge=100;w.ultimate.request(w,archer);step(b,.6)
	# The slime splits instead of dying: only the last piece's fall is a kill.
	for i in range(8):
		for s in b.units.filter(func(v):return v.alive and v.data.type_id==35):b.damage_resolver.resolve(w,s,s.current_hp+s.shield_hp+500,{"dmg":&"basic","critical":false,"transcendent":true})
		step(b,.5)
	var rows: Array=b.stats.snapshot(b)
	var mine: Dictionary=rows.filter(func(r):return r.type==0)[0];var arow: Dictionary=rows.filter(func(r):return r.type==1)[0]
	var srows: Array=rows.filter(func(r):return r.type==35)
	verify(rows.size()==4 and srows.size()==1,"one row per placed unit; slime splits add to their original's row")
	verify(mine.dealt>=hit and arow.taken>=hit and mine.healed>=healed-.01 and rows.filter(func(r):return r.type==4)[0].heal_received>=healed-.01,"damage dealt / taken and healing done / received are recorded")
	verify(mine.ultimates>=1 and mine.kills==1+int(not arow.alive) and not srows[0].alive and mine.group=="블루 팀","ultimates and kills count; a slime family is one kill once its last piece falls")
	b.queue_free()

## 전투 예측 situations (0.84.0): up to five teams, clone teams, outnumbered fights, solo brawls.
func prediction_variety(tree: SceneTree) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=11;var labels: Dictionary={};var most: int=0;var valid: bool=true;var mirrors: int=0;var clone_clash: int=0;var balanced: int=0;var biggest: int=0;var outnumbered_ok: bool=true
	for i in range(300):
		var state: PredictionState=PredictionRules.create(rng);labels[PredictionRules.label(state)]=true;most=maxi(most,state.teams.size())
		var units: int=0
		for t in state.teams:units+=t.types.size()
		valid=valid and PredictionRules.valid(state) and units<=PredictionRules.MAX_UNITS
		mirrors+=int(PredictionRules._has_mirror(state.teams.map(func(t):return t.types)))
		var rows: Array=state.teams.map(func(t):return t.types)
		balanced+=int(PredictionRules.spread_of(rows)<=PredictionRules.BALANCE+.001)
		var sizes: Array=rows.map(func(r):return r.size())
		if sizes.max()==sizes.min():biggest=maxi(biggest,sizes.max())
		if PredictionRules.label(state)=="수적 열세":
			var few: Array=rows[0] if rows[0].size()<rows[1].size() else rows[1]
			outnumbered_ok=outnumbered_ok and few.all(func(t):return CharacterCatalog.all()[t].recruit_tokens>=4)
		if PredictionRules.label(state)=="같은 유닛 팀전":
			var firsts: Dictionary={}
			for t in state.teams:firsts[t.types[0]]=true
			clone_clash+=int(firsts.size()!=state.teams.size())
	verify(valid and most==5 and biggest==6,"every situation is valid; up to five teams, equal teams of up to six")
	verify(balanced>=285 and outnumbered_ok,"teams' total unit cost stays within 15%% in nearly every situation (%d/300); the outnumbered side is 4-5 token units"%balanced)
	verify(mirrors==0 and clone_clash==0,"no two teams ever field the same units; clone teams each copy a different unit")
	verify(labels.has("같은 유닛 팀전") and labels.has("개인전") and labels.has("수적 열세") and labels.keys().any(func(k):return k.ends_with("난전")),"clone teams, solo, outnumbered and brawl situations all appear")
	var state:=PredictionState.new()
	for i in range(5):state.teams.append({"team":i,"types":[i,i]})
	var b:=BattleManager.new();b.auto_start=false;b.common_combat_enabled=true;b.full_characters_enabled=true;b.team_colors=PredictionRules.TEAM_COLORS;tree.root.add_child(b)
	verify(b.start_battle(PredictionRules.placements(state,rng),3),"a five-team prediction battle starts")
	var colors: Dictionary={}
	for u in b.units:colors[u.team_color()]=true
	verify(colors.size()==5 and b.units.size()==10,"each of the five teams has its own colour")
	# 빠른 종료: once the picked team is wiped out the watch can end at once as a failed call.
	verify(not PredictionModeScreen.picked_wiped(b,2),"no quick end while the picked team stands")
	for u in b.units.filter(func(v):return v.original_team==2):u.receive_damage(u.current_hp+1,null)
	verify(PredictionModeScreen.picked_wiped(b,2) and not b.finished,"the picked team is gone while four teams fight on")
	b.finish_with_reason(BattleEndReason.Value.DEFEAT,-1)
	verify(b.finished and not b.result.draw and b.result.winner_team!=2,"빠른 종료 ends the battle as a failed prediction")
	b.queue_free()

## 0.84.5 balance: 소형 위성 damage and its ult-to-gauge refill, 마법사 블랙홀, 암살자.
func balance_0845(tree: SceneTree) -> void:
	verify(is_equal_approx(UnitStatTable.spec(2,&"ult").ratio,.04) and is_equal_approx(UnitStatTable.spec(2,&"ult").base,4.0) and is_equal_approx(UnitStatTable.spec(2,&"basic").ratio,1.0),"마법사 블랙홀 -20% (basic unchanged)")
	verify(is_equal_approx(UnitBalance.damage(CharacterCatalog.all()[3]),.88*UnitBalance.tier(CharacterCatalog.all()[3])) and is_equal_approx(UnitBalance.damage(CharacterCatalog.all()[15]),.8*UnitBalance.tier(CharacterCatalog.all()[15])),"암살자 ×0.88, 소형 위성 ×0.8 damage")
	var b:=duel(tree,[[15,0,Vector2(300,400)],[18,1,Vector2(420,400)]])
	step(b,.05)
	var sat: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	var out:=DamageOutcome.new();out.hp_damage=60
	sat.ultimate_gauge=0;CharacterCombat.after_hit(sat,foe,out,{"dmg":&"basic"});var plain: float=sat.ultimate_gauge
	sat.ultimate_gauge=0;CharacterCombat.after_hit(sat,foe,out,{"dmg":&"ult"});var from_ult: float=sat.ultimate_gauge
	verify(plain>0 and is_equal_approx(from_ult,plain*.7),"소형 위성 gains 70% gauge from its own ultimate's damage")
	b.queue_free()

## 팽이 (43) and 바운티 헌터 (44), 0.85.0.
func top_and_bounty(tree: SceneTree) -> void:
	verify(UnitStatTable.spec(43,&"basic").tags.has(&"melee") and UnitStatTable.spec(43,&"basic").tags.has(&"dot") and UnitStatTable.spec(43,&"basic").tags.has(&"wind"),"팽이: melee · over time · wind")
	var b:=duel(tree,[[43,0,Vector2(200,400)],[4,1,Vector2(560,400)]])
	step(b,.05)
	var top: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	foe.move_speed=0;foe.combat.cooldown=1000;foe.parry_cooldown=1000;foe.defense_cooldown=1000;foe.evade_remaining=0
	top.set_state("topAngle",0.0);var hp: float=foe.current_hp;var bounced: bool=false;var moved: float=0;var last: Vector2=top.position
	for i in range(60*10):
		step(b,1.0/60);moved+=top.position.distance_to(last);last=top.position
		if b.combat_event_counts.get(&"top_bounce",0)>0 and foe.current_hp<hp:bounced=true
	verify(foe.current_hp<hp and b.combat_event_counts.get(&"top_hit",0)>=2 and bounced and moved>1200,"팽이 keeps spinning forward, bouncing, and hits the enemies it touches")
	var base_rate: float=top.ability.movement_rate(top);top.set_state("topBoost",5.0)
	verify(top.ability.movement_rate(top)>base_rate*1.5,"폭주 회전 speeds the top up")
	b.queue_free()
	b=duel(tree,[[44,0,Vector2(200,400)],[4,1,Vector2(500,300)],[0,1,Vector2(520,520)],[1,1,Vector2(600,420)]])
	step(b,.05)
	var hunter: BattleUnit=b.units[0]
	var marked: Array=b.units.filter(func(v):return v.character_specific_state.has("bountyBy"))
	verify(marked.size()==2 and marked.all(func(v):return v.team==1),"현상금 on two random enemies at the start")
	var m: BattleUnit=marked[0]
	verify(is_equal_approx(ElementEffects.taken(m),1.05),"a bountied enemy takes 5% more damage")
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	hunter.combat.cooldown=0;hunter.combat.aim_angle=0;var shots: int=0
	for i in range(6):hunter.ability.release_basic(hunter);shots+=1
	verify(int(hunter.state_value("rounds"))==0 and hunter.state_value("reloadRemaining")>0 and b.projectiles.filter(func(p):return p.kind=="deagle").size()==6,"six Desert Eagle rounds, then a reload")
	var hp2: float=marked[1].current_hp;hunter.ultimate_gauge=100
	verify(hunter.ultimate.request(hunter,marked[1]),"the hunter starts its ultimate")
	step(b,1.0)
	verify(marked[1].current_hp<hp2 and marked[1].state_value("rootedUntil")>b.clock.elapsed+3,"현상금 집행 hits every bountied enemy and roots them for 5 s")
	m.receive_damage(m.current_hp+1,hunter);m.announce_death(hunter);step(b,.1)
	verify(int(hunter.state_value("bountyGold"))==100 and b.combat_event_counts.get(&"bounty_paid",0)==1,"a fallen bounty pays 100 gold")
	b.queue_free()

## 0.86.0: tank shell speed, mirror 6 s, UFC ring nerf, flamethrower throws at enemies, charmed
## units always walk to the charmer, and the rock-paper-scissors hands are recorded for display.
func fixes_0860(tree: SceneTree) -> void:
	verify(is_equal_approx(UnitStatTable.spec(9,&"ring").ratio,.49) and is_equal_approx(UnitStatTable.spec(9,&"ring").base,7.0),"UFC 링 줄 충돌 -30%")
	var b:=duel(tree,[[18,0,Vector2(200,400)],[21,1,Vector2(520,400)],[32,0,Vector2(200,600)],[0,1,Vector2(560,640)],[4,1,Vector2(640,700)]])
	step(b,.05)
	var tank: BattleUnit=b.units[0];var mirror: BattleUnit=b.units[1];var flame: BattleUnit=b.units[2]
	var before: int=b.projectiles.size();tank.facing=0;tank.ability.release_basic(tank)
	var shells: Array=b.projectiles.slice(before).filter(func(p):return p.kind=="tankShell")
	verify(not shells.is_empty() and shells[0].velocity.length()>=1200,"tank shells fly about twice as fast")
	mirror.ability.release_ultimate(mirror,{},0)
	verify(is_equal_approx(mirror.state_value("mirrorReflectTime"),6.0),"금간 거울 reflects for 6 s")
	var aim: Vector2=flame.ability.ultimate_point(flame,flame.position)
	verify(aim.distance_to(Vector2(600,670))<90 and flame.position.distance_to(aim)<=FlameRef2.PATCH_REACH+1,"화염방사기 throws its bottles at the enemy group within the longer reach")
	b.queue_free()
	# 매혹: a charmed unit under a projectile threat still walks to its charmer.
	b=duel(tree,[[37,0,Vector2(200,400)],[0,1,Vector2(500,400)],[1,0,Vector2(500,700)]])
	step(b,.05)
	var whisperer: BattleUnit=b.units[0];var victim: BattleUnit=b.units[1]
	victim.set_state("charmTime",3.0);victim.character_specific_state["charmBy"]=whisperer.actor_id()
	var gap: float=victim.position.distance_to(whisperer.position)
	b.units[2].combat.aim_angle=-PI*.5;b.units[2].ability.release_basic(b.units[2])
	step(b,.6)
	verify(victim.position.distance_to(whisperer.position)<gap-12,"a charmed unit keeps walking to the charmer even with a projectile coming")
	b.queue_free()
	b=duel(tree,[[8,0,Vector2(300,400)],[0,1,Vector2(360,400)]])
	step(b,.05)
	verify(CharacterLifecycle.begin_duel(b.units[0],b.units[1]),"a rock-paper-scissors duel starts")
	step(b,1.8)
	var d: Dictionary=b.units[0].duel if not b.units[0].duel.is_empty() else {}
	verify(d.has("ms") and d.has("ts") and int(d.ms) in [0,1,2],"both hands are recorded for the duel display")
	b.queue_free()

## 0.86.1: 인형술사 control lasts 10 s and its thread cuts the controlled unit; 석궁 / 팽이 nerfs.
func puppet_0861(tree: SceneTree) -> void:
	verify(is_equal_approx(UnitBalance.damage(CharacterCatalog.all()[34]),.85*UnitBalance.tier(CharacterCatalog.all()[34])) and is_equal_approx(UnitBalance.hp(CharacterCatalog.all()[43]),.82*UnitBalance.tier(CharacterCatalog.all()[43])),"석궁 damage ×0.85, 팽이 HP ×0.82")
	var b:=duel(tree,[[25,0,Vector2(200,400)],[0,1,Vector2(420,400)],[4,1,Vector2(600,600)]])
	step(b,.05)
	var puppet: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	verify(CharacterLifecycle.control(foe,puppet,PuppetRef.CONTROL_TIME) and is_equal_approx(float(foe.puppet_control.remaining),10.0),"the control thread holds an enemy for 10 s")
	var hp: float=foe.current_hp;step(b,1.6)
	verify(foe.current_hp<hp and b.combat_event_counts.get(&"puppet_cut",0)>=3 and not foe.puppet_control.is_empty(),"the controlled unit takes magic damage every 0.5 s while held")
	b.queue_free()

## 금단의 연구원 (45), 0.87.0.
func researcher(tree: SceneTree) -> void:
	var b:=duel(tree,[[45,0,Vector2(200,400)],[0,0,Vector2(240,560)],[4,1,Vector2(420,400)],[0,1,Vector2(470,470)],[1,1,Vector2(520,380)]])
	step(b,.05)
	var r: BattleUnit=b.units[0];var ally: BattleUnit=b.units[1];var foe: BattleUnit=b.units[2]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	ally.current_hp=ally.max_hp*.4;var hp: float=ally.current_hp
	r.ability.release_basic(r);step(b,.6)
	verify(ally.current_hp>hp and ally.shield_hp>0 and b.combat_event_counts.get(&"boost_drug",0)==1,"증폭 약물 heals and shields the most hurt ally")
	r.combat.aim_angle=0;r.ability.release_basic(r);step(b,.6)
	verify(b.units.any(func(v):return v.team==1 and v.state_value("suppressTime")>0 and v.state_value("slowTime")>0) and b.combat_event_counts.get(&"suppress_drug",0)>=1,"억제 약물 slows the enemy's attacks and movement")
	verify(is_equal_approx(ElementEffects.attack_speed(b.units.filter(func(v):return v.state_value("suppressTime")>0)[0]),.7),"억제 약물: attack speed ×0.7")
	r.ultimate_gauge=100
	verify(r.ultimate.request(r,foe),"the researcher throws the drug bomb")
	var burst: bool=false
	for i in range(60*4):
		step(b,1.0/60)
		if b.combat_event_counts.get(&"drug_bomb_burst",0)>0:burst=true;break
	var mad: Array=b.units.filter(func(v):return v.state_value("frenzyTime")>0)
	verify(burst and not mad.is_empty() and mad.all(func(v):return v.original_team==1 and v.stance==CombatStance.RUSH and v.team!=1),"the bomb bursts as it lands and drives the enemies it hits into 광란")
	var m: BattleUnit=mad[0];var mates: Array=b.units.filter(func(v):return v!=m and v.alive and v.team==1)
	if not mates.is_empty():verify(m.target_selector.select_target(m,b.units).team==1,"a frenzied unit goes for its own side first")
	verify(not b.units.filter(func(v):return v!=m and v.alive and v.original_team==1 and v.state_value("frenzyTime")<=0).any(func(v):return v.enemies(false).has(m)),"its (calm) allies do not target it back")
	verify(ElementEffects.taken(m)>=1.149 and m.team_color()==b.units[2].team_color(),"광란 +15% damage taken; it keeps its side's colour")
	step(b,6.2)
	verify(m.state_value("frenzyTime")<=0 and m.team==1 and m.stance!=CombatStance.RUSH or not m.alive,"광란 ends after 6 s and the unit returns to its side")
	b.queue_free()

const PuppetRef=preload("res://scripts/abilities/puppet_ability.gd")
const FlameRef2=preload("res://scripts/abilities/flamethrower_ability.gd")
const SantaRef=preload("res://scripts/abilities/santa_ability.gd")
const FlameRef=preload("res://scripts/abilities/flame_blade_ability.gd")
## 역병 (38) and 빙하 골렘 (39), 0.79.0.
func plague_and_golem(tree: SceneTree) -> void:
	var b:=duel(tree,[[38,0,Vector2(200,400)],[4,1,Vector2(280,400)],[0,1,Vector2(740,740)]])
	step(b,.05)
	var pl: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1];var far: BattleUnit=b.units[2]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	var hp: float=foe.current_hp
	b.damage_resolver.resolve(pl,foe,10,{"dmg":&"basic","critical":false,"transcendent":true})
	var plain: float=hp-foe.current_hp
	foe.set_state("poisonStacks",5);hp=foe.current_hp
	b.damage_resolver.resolve(pl,foe,10,{"dmg":&"basic","critical":false,"transcendent":true})
	verify(hp-foe.current_hp>plain+1,"역병: the staff hits harder per poison stack on the target")
	foe.set_state("poisonStacks",0);var hp_near: float=foe.current_hp;var hp_far: float=far.current_hp
	pl.ability.release_ultimate(pl,{},0);step(b,1.1)
	verify(foe.current_hp<hp_near and far.current_hp<hp_far and pl.state_value("fogTime")>0,"the plague fog hurts every enemy anywhere on the map")
	verify(UnitStatTable.spec(38,&"ult").tags.has(&"poison") and UnitStatTable.spec(38,&"ult").tags.has(&"dark") and UnitStatTable.spec(38,&"ult").kind==&"magic","fog: magic · dark · poison · area · over time")
	step(b,PlagueRef.FOG_TIME)
	verify(pl.state_value("fogTime")<=0,"the fog lifts after 5 s")
	b.queue_free()
	b=duel(tree,[[39,0,Vector2(300,400)],[4,1,Vector2(380,400)],[0,1,Vector2(700,400)]])
	step(b,.05)
	var golem: BattleUnit=b.units[0];foe=b.units[1];far=b.units[2]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0;u.evade_remaining=0
	hp=foe.current_hp;step(b,1.1)
	verify(foe.current_hp<hp and foe.state_value("frostStacks")>=1 and far.state_value("frostStacks")==0,"빙하 골렘's cold hurts nearby enemies and adds a sure frost stack")
	hp=foe.current_hp;golem.combat.aim_angle=0;golem.ability.release_basic(golem)
	verify(foe.current_hp<hp and foe.state_value("slowTime")>0,"the ground slam hurts and slows")
	golem.ultimate_gauge=100
	verify(golem.ultimate.request(golem,foe),"the golem starts charging")
	step(b,GolemRef.CHARGE_TIME-.6)
	verify(foe.state_value("frozenTime")<=0 and golem.state_value("golemCharge")>0,"no burst while the vapour is gathering")
	foe.set_state("frostStacks",0);hp=foe.current_hp;step(b,1.2)
	verify(foe.current_hp<hp and foe.state_value("frozenTime")>0,"after 4 s the burst hits and freezes at once")
	b.queue_free()

const PlagueRef=preload("res://scripts/abilities/plague_ability.gd")
const GolemRef=preload("res://scripts/abilities/golem_ability.gd")
## 앵무새 (36) and 속삭이는 자 (37), 0.78.0.
func parrot_and_whisperer(tree: SceneTree) -> void:
	# 깃털 세례: five feathers fanned out.
	var b:=duel(tree,[[36,0,Vector2(200,400)],[33,1,Vector2(420,400)],[0,1,Vector2(560,250)],[24,1,Vector2(520,620)]])
	step(b,.05)
	var parrot: BattleUnit=b.units[0];var griffin: BattleUnit=b.units[1]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000
	for u in b.units.slice(1):u.move_speed=0
	var before: int=b.projectiles.size();parrot.combat.aim_angle=0;parrot.ability.release_basic(parrot)
	var feathers: Array=b.projectiles.slice(before).filter(func(p):return p.kind=="feather")
	var spread: float=feathers.map(func(p):return p.velocity.angle()).max()-feathers.map(func(p):return p.velocity.angle()).min()
	verify(feathers.size()==5 and spread>.5,"앵무새 fans out five feathers")
	verify(UnitStatTable.spec(36,&"basic").tags.has(&"wind") and UnitStatTable.spec(36,&"basic").kind==&"physical","feathers are physical · wind · projectile")
	# 흉내: the nearest enemy loses 50 gauge and the parrot casts its ultimate.
	verify(parrot.ability.mimic_source(parrot)==griffin,"the nearest enemy is the one copied")
	griffin.ultimate_gauge=80;parrot.ultimate_gauge=100
	verify(parrot.ultimate.request(parrot,griffin),"the parrot starts its ultimate")
	var hp: float=griffin.current_hp+b.units[2].current_hp
	for i in range(60*2):
		step(b,1.0/60);griffin.ultimate_gauge=minf(griffin.ultimate_gauge,30)
		if parrot.character_specific_state.has("mimicType"):break
	verify(int(parrot.state_value("mimicType"))==33 and griffin.ultimate_gauge<=30.0001,"the parrot drains 50 gauge and copies the griffin's ultimate")
	verify(UnitStatTable.spec_type(parrot,&"ult")==33 and UnitStatTable.spec_type(parrot,&"basic")==36,"while copying, ultimate damage follows the copied unit's table")
	step(b,1.5)
	verify(griffin.current_hp+b.units[2].current_hp<hp,"the copied ultimate hits")
	verify(StatusCatalog.collect(parrot).any(func(r):return r.key==&"mimic"),"흉내 shows in the parrot's 상태이상")
	step(b,ParrotRef.MIMIC_TIME+.5)
	verify(not parrot.character_specific_state.has("mimicType"),"the copy wears off")
	b.queue_free()
	# A next-basic ultimate (탱크) arms the parrot's next basic attack with the tank's flame shell.
	b=duel(tree,[[36,0,Vector2(200,400)],[18,1,Vector2(450,400)]])
	step(b,.05)
	parrot=b.units[0];var tank: BattleUnit=b.units[1]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0
	tank.ultimate_gauge=10;parrot.ultimate_gauge=100;parrot.ultimate.request(parrot,tank)
	for i in range(60):
		step(b,1.0/60);tank.combat.cooldown=1000
		if parrot.character_specific_state.has("mimicBasic"):break
	verify(int(parrot.state_value("mimicBasic"))==18 and tank.ultimate_gauge<1,"even an empty gauge can be stolen; the tank's ultimate arms the parrot's next basic")
	var shot_from: int=b.projectiles.size();parrot.combat.aim_angle=0;parrot.ability.release_basic(parrot)
	var shells: int=b.projectiles.slice(shot_from).filter(func(p):return p.kind=="tankShell").size()
	parrot.ability.after_recovery(parrot)
	verify(shells>0 and not parrot.character_specific_state.has("mimicBasic"),"the next basic attack is the tank's shell, then the parrot is back to feathers")
	b.queue_free()
	# 속삭이는 자: the third needle hit bursts for 5% of max HP.
	b=duel(tree,[[37,0,Vector2(200,400)],[4,1,Vector2(400,400)],[0,1,Vector2(520,400)]])
	step(b,.05)
	var w: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1];var back: BattleUnit=b.units[2]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.evade_remaining=0
	for u in b.units.slice(1):u.move_speed=0
	for i in range(2):b.damage_resolver.resolve(w,foe,5,{"dmg":&"basic","critical":false,"transcendent":true})
	verify(int(foe.state_value("whisperStacks"))==2 and StatusCatalog.collect(foe).any(func(r):return r.key==&"whisper"),"needles stack 속삭임 (shown in 상태이상)")
	var hp_before: float=foe.current_hp
	b.damage_resolver.resolve(w,foe,5,{"dmg":&"basic","critical":false,"transcendent":true})
	verify(int(foe.state_value("whisperStacks"))==0 and hp_before-foe.current_hp>=foe.max_hp*.05*.5,"the third stack bursts for extra damage (max HP 5%)")
	# 하트: pierces and charms every enemy it hurts.
	foe.move_speed=100;back.move_speed=100;w.move_speed=0
	w.ability.release_ultimate(w,{"angle":0.0},0)
	for i in range(60):
		step(b,1.0/60)
		if back.state_value("charmTime")>0:break
	verify(foe.state_value("charmTime")>0 and back.state_value("charmTime")>0,"the heart flies through and charms both enemies")
	foe.combat.cooldown=0
	verify(not foe.combat.can_start(foe,w),"a charmed unit cannot attack")
	var gap: float=foe.position.distance_to(w.position);step(b,1.0)
	verify(foe.position.distance_to(w.position)<gap-10 and foe.brain.movement_override=="charmed","a charmed unit walks slowly toward the whisperer")
	verify(StatusCatalog.collect(foe).any(func(r):return r.key==&"charm"),"매혹 shows in the unit's 상태이상")
	step(b,WhispererRef.CHARM_TIME)
	verify(foe.state_value("charmTime")<=0,"매혹 ends after 5 s")
	b.queue_free()

const ParrotRef=preload("res://scripts/abilities/parrot_ability.gd")
const WhispererRef=preload("res://scripts/abilities/whisperer_ability.gd")
## 0.75.0 balance layer: tier and per-unit HP/damage multipliers on the source values.
func balance_layer(_tree: SceneTree) -> void:
	var all: Dictionary=CharacterCatalog.all()
	var stats:=func(t: int) -> UnitCombatStats:return UnitCombatStats.from_table(all[t])
	verify(is_equal_approx(stats.call(14).max_hp,all[14].max_hp) and is_equal_approx(stats.call(14).physical_damage,UnitStatTable.base_physical(14)),"2-token units keep their source stats")
	verify(is_equal_approx(stats.call(12).max_hp,all[12].max_hp*1.15) and is_equal_approx(stats.call(3).max_hp,all[3].max_hp*.95),"tier multiplier: 5 tokens ×1.15, 1 token ×0.95")
	verify(UnitBalance.max_hp(all[27])==floorf(150*1.15*1.7+.5) and is_equal_approx(stats.call(27).physical_damage,UnitStatTable.base_physical(27)*1.15*1.25),"기관사: tier and its own correction stack")
	verify(is_equal_approx(stats.call(0).max_hp,all[0].max_hp*.95*.9) and is_equal_approx(stats.call(13).physical_damage,UnitStatTable.base_physical(13)*.88),"strong cheap units are toned down")
	verify(is_equal_approx(stats.call(33).max_hp,all[33].max_hp*1.1*1.2) and is_equal_approx(stats.call(33).magic_damage,UnitStatTable.base_magic(33)*1.1*.8),"그리핀: more HP, less damage (0.76.0)")
	verify(is_equal_approx(stats.call(35).physical_damage,UnitStatTable.base_physical(35)*1.05*.8),"슬라임: base damage ×0.8 (0.77.0)")
	verify(is_equal_approx(UnitStatTable.spec(17,&"ult").ratio,3.0) and is_equal_approx(UnitStatTable.spec(35,&"ult").ratio,.9),"히어로 · 슬라임 ultimates hit softer (0.76.0)")
	var setup:=CustomBattleSetup.new();setup.add(27,0,Vector2(200,400))
	verify(is_equal_approx(setup.placements()[0].combat_stats.max_hp,UnitBalance.max_hp(all[27])),"custom battles use the balanced stats")
	UnitBalance.enabled=false
	verify(is_equal_approx(stats.call(27).max_hp,all[27].max_hp),"the layer can be switched off for source-parity tests")
	UnitBalance.enabled=true

## 0.74.0: no standoff against a stunned enemy; 그리핀 dashes to travel when nothing is in reach.
func stun_rush_and_travel(tree: SceneTree) -> void:
	var first_swing:=func(stunned: bool) -> float:
		var b:=duel(tree,[[17,0,Vector2(250,400)],[0,1,Vector2(520,400)]],9)
		step(b,.05)
		var hero: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
		foe.move_speed=0;foe.combat.cooldown=1000;foe.parry_cooldown=1000;foe.defense_cooldown=1000
		var t: float=-1
		for i in range(60*8):
			if stunned:foe.stun_remaining=1.0
			step(b,1.0/60)
			if hero.combat.attacks_started>0:t=i/60.0;break
		var calm: bool=hero.brain.defensive(hero)
		b.queue_free()
		return t if not stunned or not calm else -2.0
	var slow: float=first_swing.call(false);var fast: float=first_swing.call(true)
	verify(fast>=0 and fast<2.0 and (slow<0 or fast<slow),"a standoff unit rushes a stunned enemy (first swing %.2fs vs %.2fs)"%[fast,slow])
	var b:=duel(tree,[[33,0,Vector2(100,400)],[4,1,Vector2(720,400)]])
	step(b,.05)
	var griffin: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	foe.move_speed=0;foe.combat.cooldown=1000
	var d0: float=griffin.position.distance_to(foe.position)
	verify(griffin.ability.travel_attack(griffin,foe),"griffin: no enemy in reach → the basic attack is used to travel")
	for i in range(60*4):
		step(b,1.0/60)
		if griffin.position.distance_to(foe.position)<griffin.data.attack_range:break
	verify(griffin.position.distance_to(foe.position)<minf(d0-200,griffin.data.attack_range),"griffin dashes across the field toward a far enemy")
	verify(not griffin.ability.travel_attack(griffin,foe),"within reach the dash is an ordinary attack again")
	b.queue_free()

const SlimeAbilityRef=preload("res://scripts/abilities/slime_ability.gd")
## 슬라임 (35), 0.73.0: splits twice on death, slam slows, the family leaps together (0.75.0: the last split cannot).
func slime_unit(tree: SceneTree) -> void:
	var b:=duel(tree,[[35,0,Vector2(200,400)],[4,1,Vector2(560,400)]])
	step(b,.05)
	var slime: BattleUnit=b.units[0];var foe: BattleUnit=b.units[1]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000;u.move_speed=0
	var full_hp: float=slime.max_hp;var full_damage: float=slime.combat_stats.physical_damage
	var slimes:=func():return b.units.filter(func(u):return u.alive and u.data.type_id==35)
	var F: float=SlimeAbilityRef.SPLIT_FACTOR;var H: float=SlimeAbilityRef.SPLIT_HP
	b.damage_resolver.resolve(foe,slime,9999,{"critical":false,"transcendent":true});step(b,1.0/60)
	verify(slime.alive and is_equal_approx(slime.max_hp,full_hp*H) and is_equal_approx(slime.combat_stats.physical_damage,full_damage*F) and slimes.call().size()==2,"a lethal blow splits the slime into two weaker slimes (HP %d%%, damage %d%%)"%[roundi(H*100),roundi(F*100)])
	# Family leap: every slime of the family jumps at once and lands on the nearest enemy.
	for s in slimes.call():s.invincible_remaining=0
	var hp: float=foe.current_hp
	slimes.call()[0].ability.release_ultimate(slimes.call()[0],{},0)
	verify(slimes.call().all(func(s):return s.character_specific_state.has("slimeLeap")),"the ultimate makes the whole family leap")
	step(b,.9)
	verify(foe.current_hp<hp and not slimes.call().any(func(s):return s.character_specific_state.has("slimeLeap")),"the slimes land on the enemy")
	for s in slimes.call():s.invincible_remaining=0
	for s in slimes.call():b.damage_resolver.resolve(foe,s,9999,{"critical":false,"transcendent":true})
	step(b,1.0/60)
	verify(slimes.call().size()==4 and slimes.call().all(func(s):return is_equal_approx(s.max_hp,full_hp*H*H)),"each slime splits again: four smaller slimes")
	# The last split can no longer use the ultimate, nor joins a family leap.
	verify(slimes.call().all(func(s):return not s.ability.can_cast(s) and not s.ability.can_ultimate(s,foe)),"slimes of the last split cannot use the ultimate")
	slimes.call()[0].ability.release_ultimate(slimes.call()[0],{},0)
	verify(not slimes.call().any(func(s):return s.character_specific_state.has("slimeLeap")),"last-split slimes do not leap")
	var last=slimes.call()[0];last.invincible_remaining=0
	b.damage_resolver.resolve(foe,last,9999,{"critical":false,"transcendent":true});step(b,1.0/60)
	verify(not last.alive and slimes.call().size()==3,"after two splits a slime dies for good")
	verify(b.units.filter(func(u):return u.data.type_id==35).all(func(s):return s.source_member_id.is_empty()) and b.units.filter(func(u):return u.data.type_id==35 and u!=slime).all(func(s):return s.character_specific_state.get("slimeFamily","")==slime.character_specific_state.get("slimeFamily","")),"split slimes are battle-only and share the family")
	b.queue_free()
	# Body slam: knockback and a 2 s slow.
	b=duel(tree,[[35,0,Vector2(200,400)],[8,1,Vector2(320,400)]])
	step(b,.05)
	slime=b.units[0];foe=b.units[1]
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.defense_cooldown=1000
	foe.position=slime.position+Vector2(40,0);var walk: float=foe.move_speed
	slime.ability.release_basic(slime)
	verify(foe.current_hp<foe.max_hp and foe.knockback_velocity.length()>50 and foe.state_value("slowTime")>0,"the slam damages, knocks back and slows")
	verify(foe.move_speed<walk and StatusCatalog.collect(foe).any(func(r):return r.key==&"slow"),"둔화 slows movement and shows as a status")
	b.queue_free()
func ai_fluid(tree: SceneTree) -> void:
	var b:=duel(tree,[[0,0,Vector2(300,400)],[1,1,Vector2(420,400)]])
	step(b,.05)
	var w: BattleUnit=b.units[0];var a: BattleUnit=b.units[1]
	a.brain.heading=Vector2.RIGHT;a.brain.movement_override=""
	verify(a.brain.flee_rate(a)<.8,"running straight away from a close enemy is slower")
	a.brain.heading=Vector2.LEFT
	verify(is_equal_approx(a.brain.flee_rate(a),1.0),"moving toward the enemy keeps full speed")
	a.brain.heading=Vector2.RIGHT;a.position=Vector2(760,400)
	verify(is_equal_approx(a.brain.flee_rate(a),1.0),"no slowdown far from every enemy")
	# Nobody swung for a while: the unit stops waiting and commits.
	w.combat.cooldown=0;w.threat_response.response.clear();w.brain.commit_until=0;w.brain.disengage_until=0;w.brain.return_until=0;w.brain.punish_until=0
	w.brain.next_initiative_at=b.clock.elapsed+30;w.brain.last_action=b.clock.elapsed-30
	w.brain.advance(w,a,1.0/60)
	verify(w.brain.commit_until>b.clock.elapsed and w.brain.mode=="approach","a long lull makes the unit go in")
	b.queue_free()
func fixes_0910(tree: SceneTree) -> void:
	# 가위바위보 마스터: losing its ultimate duel costs it nothing.
	var b:=duel(tree,[[8,0,Vector2(300,400)],[0,1,Vector2(360,400)]])
	step(b,.05)
	var m: BattleUnit=b.units[0];var t: BattleUnit=b.units[1];var hurt: bool=false
	for i in range(30):
		m.duel={};t.duel={};m.current_hp=m.max_hp*.5;t.current_hp=t.max_hp;m.set_state("duelRounds",1.0+i*3)
		var hp: float=m.current_hp
		CharacterLifecycle.begin_duel(m,t,true)
		for k in range(12):CharacterLifecycle.advance_duel(m,.15)
		if m.current_hp<hp-.01:hurt=true
	verify(not hurt,"가위바위보 ultimate duel: the master never loses HP")
	b.queue_free()
	# 광신도: the saint gains CHARGE gauge per cast.
	verify(load("res://scripts/abilities/fanatic_ability.gd").CHARGE>=35,"광신도 ultimate charges the saint by 35")
	# 슬라임 splits in 전투 예측 too (placements carry no combat stats there).
	var st:=PredictionState.new();st.teams=[{"team":0,"types":[35]},{"team":1,"types":[0]}]
	var mgr:=BattleManager.new();mgr.auto_start=false;mgr.common_combat_enabled=true;mgr.full_characters_enabled=true;tree.root.add_child(mgr)
	var rng:=RandomNumberGenerator.new();rng.seed=4
	mgr.start_battle(PredictionRules.placements(st,rng),4,PredictionRules.map_for(st));mgr.set_physics_process(false)
	var slime: BattleUnit=mgr.units.filter(func(u):return u.data.type_id==35)[0]
	verify(slime.combat_stats==null,"prediction units start without combat stats")
	verify(CharacterLifecycle.intercept_lethal(slime,slime.current_hp+10),"a prediction slime splits instead of dying")
	step(mgr,.1)
	verify(mgr.units.filter(func(u):return u.data.type_id==35 and u.alive).size()==2,"the split slime appears")
	mgr.queue_free()
	# 사각 정원 · 소/중/대
	verify(ArenaMap.label(ArenaMap.SMALL)=="사각 정원 · 소" and ArenaMap.label(ArenaMap.LARGE)=="사각 정원 · 대","map names")
	var big:=BattleManager.new();big.auto_start=false;big.custom_mode=true;tree.root.add_child(big)
	var setup:=CustomBattleSetup.new();setup.add(0,0,Vector2(700,700));setup.add(0,1,Vector2(100,100))
	big.start_battle(setup.placements(),3,ArenaMap.LARGE);big.set_physics_process(false)
	verify(is_equal_approx(ArenaMap.side,1400) and big.units[0].position.distance_to(Vector2(1225,1225))<1,"a large map scales placements to 1400 units")
	verify(MovementController.clamp_position(Vector2(1390,1390)).x>1300,"units can stand past the old 800 edge on a large map")
	big.queue_free()
	var small:=duel(tree,[[0,0,Vector2(200,400)],[0,1,Vector2(600,400)]])
	verify(is_equal_approx(ArenaMap.side,800) and MovementController.clamp_position(Vector2(1000,1000)).x<=772,"the next battle is back on the small map")
	small.queue_free()
	# A big map keeps characters at their size: the camera travels instead of shrinking the view.
	var cam:=ArenaCameraController.new();cam.side=1400;cam.reset()
	cam.set_framing([{"position":Vector2(100,100)},{"position":Vector2(1300,1300)}])
	for i in range(240):cam.advance(1.0/60)
	verify(cam.zoom>=ArenaCameraController.BIG_MIN_ZOOM-.001 and cam.center.x>0 and cam.center.x<1400,"big map camera keeps units near full size and stays over the map")
	cam.set_framing([{"position":Vector2(1250,1250)}])
	for i in range(300):cam.advance(1.0/60)
	verify(cam.center.distance_to(Vector2(1250,1250))<300,"the camera follows the fight across the big map")
	# Per-map battle view (characters ×1 / ×0.85 / ×0.73) and pinch limit; 준비 시간 zoom and pan.
	var board:=CustomBattleBoard.new();board.setup=CustomBattleSetup.new();board.size=Vector2(400,400);tree.root.add_child(board)
	verify(is_equal_approx(board.view_side(),800) and board.edit_zoom==1,"placing view starts on the whole board")
	board.edit_zoom_by(2,Vector2(400,400))
	verify(is_equal_approx(board.edit_zoom,2) and board.logical_point(Vector2(200,200)).distance_to(Vector2(400,400))<1 and board.logical_point(Vector2(0,0)).distance_to(Vector2(200,200))<1,"pinching the placing view zooms around the fingers and taps land where they are drawn")
	board.edit_pan_by(Vector2(100,0))
	verify(board.logical_point(Vector2(200,200)).x<400,"dragging the zoomed placing view pans it")
	board.setup.map=ArenaMap.LARGE
	verify(board.edit_zoom_max()>3,"a large garden may be zoomed in further while placing")
	var lb:=BattleManager.new();lb.auto_start=false;lb.custom_mode=true;board.add_child(lb)
	var ls:=CustomBattleSetup.new();ls.add(0,0,Vector2(300,400));ls.add(0,1,Vector2(500,400))
	lb.start_battle(ls.placements(),5,ArenaMap.LARGE);lb.set_physics_process(false);board.battle=lb;board.editing=false;board._process(.016)
	verify(is_equal_approx(board.view_side(),ArenaMap.VIEWS[ArenaMap.LARGE]) and ArenaMap.VIEWS[ArenaMap.LARGE]>ArenaMap.VIEWS[ArenaMap.SMALL],"a large map shows more of itself in battle (smaller characters)")
	verify(board._zoomable() and is_equal_approx(board.presentation.camera.user_zoom_max,ArenaMap.ZOOMS[ArenaMap.LARGE]),"pinch zoom works in battle, limited by the map")
	board.queue_free()
	verify(ArenaMap.for_units(6)==ArenaMap.SMALL and ArenaMap.for_units(12)==ArenaMap.MEDIUM and ArenaMap.for_units(24)==ArenaMap.LARGE,"prediction map grows with the crowd")
	# The unit sheet keeps drags to itself (the list behind it does not scroll).
	var host:=Control.new();tree.root.add_child(host)
	var sheet=UnitInfoSheet.open(host,0,null,null,null)
	verify(sheet.is_in_group(DragScroll.MODAL),"unit sheet is a drag-scroll modal")
	sheet.queue_free();host.queue_free()
func fumble(tree: SceneTree) -> void:
	# 놓침: the weapon flies off; no basic attack or ultimate until it is picked up again.
	var b:=duel(tree,[[0,0,Vector2(300,400)],[35,1,Vector2(400,400)],[46,1,Vector2(560,400)]])
	step(b,.05)
	var w: BattleUnit=b.units[0];var slime: BattleUnit=b.units[1];var f: BattleUnit=b.units[2]
	verify(WeaponDrop.holds_weapon(w) and not WeaponDrop.holds_weapon(slime) and not WeaponDrop.holds_weapon(f),"only units holding a weapon can lose it")
	verify(not WeaponDrop.drop(slime),"a unit without a weapon is never disarmed")
	w.combat.cooldown=0;w.ultimate_gauge=100
	verify(WeaponDrop.drop(w,f) and not w.lost_sword.is_empty(),"놓침 knocks the weapon away")
	verify(not w.combat.can_start(w,slime) and not w.ultimate.request(w,slime),"no basic attack and no ultimate while the weapon is lost")
	verify(StatusCatalog.collect(w).any(func(e):return e.key==&"disarmed"),"놓침 shows in the status list")
	step(b,.7)
	var spot: Vector2=CharacterPersistence.vector(w.lost_sword.point)
	verify(spot.distance_to(Vector2(300,400))>150,"the weapon lands away from the unit")
	var before: float=w.position.distance_to(spot)
	step(b,.5)
	verify(w.position.distance_to(spot)<before-20 or w.lost_sword.is_empty(),"the disarmed unit heads for its weapon first")
	for i in range(60*6):
		step(b,1.0/60)
		if w.lost_sword.is_empty():break
	verify(w.lost_sword.is_empty(),"standing on the weapon picks it up again")
	b.queue_free()
	# 놓침 (test unit): its gauge fills fast; the ultimate disarms every enemy holding a weapon.
	var c:=duel(tree,[[46,0,Vector2(400,400)],[0,1,Vector2(520,330)],[1,1,Vector2(560,470)],[35,1,Vector2(520,520)]])
	step(c,.05)
	var t: BattleUnit=c.units[0]
	verify(t.ability.charge_rate(t)>=5,"the test unit's ultimate charges very fast")
	t.ultimate_gauge=100
	verify(t.ultimate.request(t,c.units[1]),"the test unit casts its ultimate")
	step(c,.6)
	verify(not c.units[1].lost_sword.is_empty() and not c.units[2].lost_sword.is_empty() and c.units[3].lost_sword.is_empty(),"its ultimate disarms every enemy with a weapon, and only those")
	c.queue_free()
	# The test unit stays out of the tower, recruiting and 전투 예측.
	verify(not 46 in CharacterCatalog.playable() and CharacterCatalog.playable().size()==46,"test unit is not playable outside custom battles")
	var seen: bool=false
	for seed in range(40):
		var r:=RandomNumberGenerator.new();r.seed=seed
		var st: PredictionState=PredictionRules.create(r)
		if st!=null and st.teams.any(func(team):return 46 in team.types):seen=true
	verify(not seen,"전투 예측 never picks the test unit")
## A custom battle whose units carry items: rows of [type, team, position, [item kinds]].
func gear_duel(tree: SceneTree,rows: Array,seed: int=5) -> BattleManager:
	var setup:=CustomBattleSetup.new()
	for row in rows:
		setup.add(row[0],row[1],row[2])
		for kind in row[3]:setup.equip(int(setup.entries.back().id),kind)
	var b:=BattleManager.new();b.auto_start=false;b.custom_mode=true;tree.root.add_child(b)
	b.start_battle(setup.placements(),seed);b.set_physics_process(false)
	return b
func items_0940(tree: SceneTree) -> void:
	# 일반: defenses and range.
	var setup:=CustomBattleSetup.new();setup.add(0,0,Vector2(200,200));var id: int=int(setup.entries[0].id)
	var plain: UnitCombatStats=setup.stats_for(setup.get_entry(id))
	setup.equip(id,&"magicCloak");setup.equip(id,&"sturdyShield")
	var worn: UnitCombatStats=setup.stats_for(setup.get_entry(id))
	verify(is_equal_approx(worn.magic_defense-plain.magic_defense,20) and is_equal_approx(worn.physical_defense-plain.physical_defense,20),"마법 망토 / 튼튼한 방패: +20 defense")
	var b:=gear_duel(tree,[[1,0,Vector2(200,400),[&"scopeLens"]],[1,1,Vector2(600,400),[]]])
	verify(is_equal_approx(b.units[0].data.attack_range,CharacterCatalog.all()[1].attack_range*1.1) and is_equal_approx(b.units[1].data.attack_range,CharacterCatalog.all()[1].attack_range) and is_equal_approx(CharacterCatalog.all()[1].attack_range,b.units[1].data.attack_range),"망원 렌즈: +10% range for its bearer only")
	b.queue_free()
	# 희귀: duelist stacks on one target, vanguard early, elementalist on status targets.
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"duelistGlove",&"elementTome"]],[0,1,Vector2(300,400),[&"vanguardShield"]],[0,1,Vector2(300,520),[]]])
	var a: BattleUnit=b.units[0];var t1: BattleUnit=b.units[1];var t2: BattleUnit=b.units[2]
	var f: Array=[ItemEffects.outgoing(a,t1,{}),ItemEffects.outgoing(a,t1,{}),ItemEffects.outgoing(a,t1,{}),ItemEffects.outgoing(a,t2,{})]
	verify(is_equal_approx(f[0],1) and is_equal_approx(f[1],1.05) and is_equal_approx(f[2],1.1) and is_equal_approx(f[3],1),"결투가의 장갑: +5% per hit on the same target, reset on a switch")
	for i in range(10):ItemEffects.outgoing(a,t2,{})
	verify(is_equal_approx(ItemEffects.outgoing(a,t2,{}),1.3),"결투가의 장갑 caps at +30%")
	t1.set_state("burnStacks",2);a.set_state("duelTarget","")
	verify(is_equal_approx(ItemEffects.outgoing(a,t1,{}),1.2),"원소술사의 서: +20% against a burning target")
	verify(is_equal_approx(ItemEffects.incoming(t1),.7) and is_equal_approx(ItemEffects.incoming(t2),1),"선봉의 방패: -30% taken at the start")
	b.clock.elapsed=11;verify(is_equal_approx(ItemEffects.incoming(t1),1),"선봉의 방패 ends after 10 s")
	b.queue_free()
	# 영웅: enchanted blade element, overcharge refund, chain ring every third basic hit.
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"enchantedBlade",&"chainRing"]],[2,0,Vector2(200,560),[&"overchargeCore"]],[0,1,Vector2(320,400),[]],[0,1,Vector2(380,470),[]]])
	var w: BattleUnit=b.units[0];var mage: BattleUnit=b.units[1]
	var spec: Dictionary=ItemEffects.adjust_spec(w,UnitStatTable.spec(0,&"basic"))
	verify(spec.tags.has(&"fire") and not UnitStatTable.spec(0,&"basic").tags.has(&"fire"),"마법 부여 검: a basic hit gains fire (no element of its own)")
	verify(not ItemEffects.adjust_spec(w,UnitStatTable.spec(0,&"ult_slash")).tags.has(&"fire"),"only basic attacks are enchanted")
	mage.ultimate_gauge=0;ItemEffects.after_ultimate(mage);w.ultimate_gauge=0;ItemEffects.after_ultimate(w)
	verify(is_equal_approx(mage.ultimate_gauge,25) and is_equal_approx(w.ultimate_gauge,0),"과충전 코어: 25% back after an ultimate")
	var near: BattleUnit=b.units[3];var hp: float=near.current_hp
	for i in range(3):
		var out:=DamageOutcome.new();out.hp_damage=10;out.resolved_damage=10
		ItemEffects.after_hit(w,b.units[2],out,UnitStatTable.spec(0,&"basic"),{})
	verify(near.current_hp<hp and int(w.state_value("chainCount"))==3,"연쇄의 고리: the third basic hit jumps to the nearest other enemy")
	b.queue_free()
	# 전설: sovereign attack and kill aura, giant heart size and immovability, sanctuary lamp.
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"sovereignSword"]],[0,0,Vector2(260,480),[&"giantHeart"]],[2,0,Vector2(420,620),[&"sanctuaryLamp"]],[0,1,Vector2(600,400),[]]])
	var king: BattleUnit=b.units[0];var giant: BattleUnit=b.units[1];var lamp: BattleUnit=b.units[2]
	var plain_king:=CustomBattleSetup.new();plain_king.add(0,0,Vector2(200,200))
	verify(is_equal_approx(king.combat_stats.physical_damage,plain_king.stats_for(plain_king.entries[0]).physical_damage*1.25),"군주의 검: physical · magic damage +25%")
	var base_factor: float=CombatRules.attack_factor(giant);ItemEffects.on_kill(king)
	verify(is_equal_approx(CombatRules.attack_factor(giant),base_factor*1.1) and int(giant.state_value("sovereignStacks"))==1,"군주의 검: a kill gives nearby allies +10% attack")
	for i in range(5):ItemEffects.on_kill(king)
	verify(int(king.state_value("sovereignStacks"))==3,"군주의 검 stacks up to three")
	verify(is_equal_approx(giant.combat_stats.scale,1.2) and giant.max_hp>king.max_hp*1.3,"거인의 심장: bigger body, +40% HP")
	KnockbackController.apply(giant,Vector2(500,0),b.units[3]);verify(giant.knockback_velocity==Vector2.ZERO,"거인의 심장: no knockback")
	verify(is_equal_approx(ItemEffects.incoming(lamp),.8) and is_equal_approx(ItemEffects.incoming(king),1) and is_equal_approx(ItemEffects.incoming(b.units[3]),1),"성역의 등불: allies in range take -20%, others not")
	b.queue_free()
	# 고대: 왕의 왕관 raises every stat by 30% and lifts every ally while worn; 행운의 주사위 rolls one stat up.
	setup=CustomBattleSetup.new();setup.add(0,0,Vector2(200,200));id=int(setup.entries[0].id);plain=setup.stats_for(setup.get_entry(id))
	setup.equip(id,&"cursedCrown");var crowned: UnitCombatStats=setup.stats_for(setup.get_entry(id))
	verify(absf(crowned.max_hp-plain.max_hp*1.3)<=1 and is_equal_approx(crowned.defense,plain.defense*1.3),"왕의 왕관: every stat +30%")
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"cursedCrown"]],[0,0,Vector2(200,560),[]],[0,1,Vector2(600,400),[&"gamblerDice"]]])
	var ally: BattleUnit=b.units[1];var foe: BattleUnit=b.units[2]
	verify(is_equal_approx(ItemEffects.attack_speed(ally),1.08) and is_equal_approx(ItemEffects.attack_speed(foe),1) and &"king_aura" in _keys(ally),"왕의 왕관: allies +8% while the bearer lives (왕의 가호)")
	b.units[0].receive_damage(99999,foe);verify(is_equal_approx(ItemEffects.attack_speed(ally),1),"the aura ends with the bearer")
	verify(foe.character_specific_state.has("diceUp") and foe.state_value("diceRoll")>=.6 and foe.state_value("diceRoll")<=1.2,"행운의 주사위: one stat +60~120%, nothing lowered")
	b.queue_free()
	var t:=TowerController.new();t.new_run(19,73);var m: GuildMemberState=t.guild.all_members()[0]
	# 전투 보상: three different items, room minimum grade, pick once or skip for 50 G; the map waits.
	t=TowerController.new();t.new_run(19,73)
	var node: RoomState=t.guild.state.tower.map.rooms.values().filter(func(r):return r.room_type==RoomType.BATTLE)[0]
	t.guild.state.tower.selected_room_id=node.room_id;t.guild.state.tower.phase=&"result";node.cleared=true
	var r:=RandomNumberGenerator.new();r.seed=3;t.content.roll_battle_reward(node,r)
	verify(node.item_choices.size()==3 and t.content.pending_reward(node) and not t.return_map(),"three items offered; the map waits for the pick")
	var items: int=t.guild.state.inventory.size()
	verify(not t.content_action(&"pick_reward",{"kind":&"twoFacedMask"}).ok,"only an offered item")
	verify(t.content_action(&"pick_reward",{"kind":node.item_choices[1]}).ok and t.guild.state.inventory.size()==items+1 and t.guild.state.inventory.back().kind==node.item_choices[1],"the picked item joins the inventory")
	verify(not t.content_action(&"pick_reward",{"kind":node.item_choices[0]}).ok and t.return_map(),"one pick per room, then back to the map")
	node.item_choices.clear();node.item_choice=&"";t.guild.state.tower.phase=&"result";t.content.roll_battle_reward(node,r);var gold: int=t.guild.state.gold
	verify(t.content_action(&"pick_reward",{"kind":&"skip"}).ok and t.guild.state.gold==gold+50 and node.item_choice==&"skip","건너뛰기 pays 50 G")
	var low: bool=true
	for kind in [RoomType.MINIBOSS,RoomType.BOSS]:
		for n in range(30):
			node.room_type=kind;node.item_choices.clear();node.item_choice=&"";t.content.roll_battle_reward(node,r)
			if node.item_choices.any(func(k):return ItemCatalog.grade_rank(k)<(1 if kind==RoomType.MINIBOSS else 2)):low=false
	verify(low,"미니보스 rewards are 희귀+, 보스 rewards 영웅+")
	node.room_type=RoomType.BATTLE
	# Legendary once per run: an owned 전설 is never offered again.
	for kind in ItemCatalog.LEGENDARY.slice(1):t.content.inventory.give(kind)
	var only: bool=true
	for n in range(60):
		var picks: Array[StringName]=ItemRewards.roll(r,ItemRewards.odds(14,&"legendary"),3,ItemRewards.owned_legendaries(t.guild.state))
		if picks!=[ItemCatalog.LEGENDARY[0]]:only=false
	verify(only,"전설 already owned never comes again")
	# Shop: 3~5 different items priced by grade.
	var shop_ok: bool=true
	for seed_value in range(12):
		var s:=TowerController.new();s.new_run(seed_value+3,seed_value+9)
		var room: RoomState=s.guild.state.tower.map.rooms.values().filter(func(x):return x.room_type==RoomType.SHOP)[0]
		s.content.ensure_shop(room)
		var stock: Array=room.shop.offers.filter(func(o):return o.category==&"equipment")
		var kinds: Dictionary={}
		for o in stock:kinds[o.kind]=true
		if stock.size()<3 or stock.size()>5 or kinds.size()!=stock.size() or stock.any(func(o):return o.gold_price!=ItemCatalog.price(o.kind) or ItemCatalog.grade_of(o.kind)==&"ancient"):shop_ok=false
	verify(shop_ok,"shop: 3~5 different items at grade prices")
	# Save v6 -> v7: a removed combination worn by a member is taken back and refunded once.
	t=TowerController.new();t.new_run(19,73);m=t.guild.all_members()[0]
	var doc: Dictionary=JSON.parse_string(JSON.stringify(SaveSnapshotBuilder.capture(t,"save_v6",1).document))
	doc.schema_version=6;var gold_before: int=int(doc.run.gold);var next: int=int(doc.run.next_item_number)
	doc.run.inventory.append({"item_id":next,"kind":"woodSword+staff","equipped_to_member_id":m.member_id,"consumed":false,"enhance":2})
	doc.run.inventory_receipts["combine:1:2"]=next;doc.run.next_item_number=next+1;doc.run.erase("item_notice")
	for room in doc.run.tower.map.rooms:
		room.erase("item_choices");room.erase("item_choice")
		if room.get("event") is Dictionary:room.event.purchases={"trade":2} if room.event_type=="blacksmith" else room.event.purchases
	var loaded: SaveLoadResult=SaveSnapshotLoader.restore(doc)
	verify(loaded.ok() and loaded.run.gold==gold_before+260 and loaded.run.inventory.all(func(i):return String(i.kind)!="woodSword+staff"),"v6 save: removed combination refunded 260 G")
	verify(loaded.ok() and loaded.run.item_notice.contains("마검") and loaded.run.item_notice.contains("260 G"),"one-time notice names the item and the gold")
	verify(SaveMigrator.CURRENT_VERSION==9,"save version 9")

## 0.95: fifty more items (ten per grade) and their twenty statuses.
func _spec(skill: StringName,kind: StringName,tags: Array) -> Dictionary:return {"key":&"basic","skill":skill,"kind":kind,"base":0.0,"ratio":1.0,"tags":tags,"label":""}
func _out(dealt: float,critical: bool=false) -> DamageOutcome:
	var out:=DamageOutcome.new();out.hp_damage=dealt;out.resolved_damage=dealt;out.critical=critical;out.accepted=true;return out
func _tick(b: BattleManager,seconds: float,step: float=.1) -> void:
	var n: int=roundi(seconds/step)
	for i in range(n):b.clock.elapsed+=step;ItemEffects.advance(b,step)
func _keys(u) -> Array:return StatusCatalog.collect(u).map(func(r):return r.key)
## 0.96 아이템 재점검: every item of 희귀 and up has stat lines plus one effect and no penalty; eleven
## items were replaced. Checks each revised effect and the item statuses.
func items_0960(tree: SceneTree) -> void:
	var all: Dictionary=ItemCatalog.all();var stats_ok: bool=true;var icons: bool=true;var texts: bool=true
	for grade in [&"rare",&"epic",&"legendary",&"ancient"]:
		for kind in ItemCatalog.POOLS[grade]:
			var item: ItemData=all[kind];var e:=CustomBattleSetup.new();e.add(0,0,Vector2(200,200));var plain: UnitCombatStats=e.stats_for(e.entries[0])
			e.equip(int(e.entries[0].id),kind);var worn: UnitCombatStats=e.stats_for(e.entries[0])
			var stronger: bool=worn.max_hp>plain.max_hp or worn.physical_damage>plain.physical_damage or worn.magic_damage>plain.magic_damage or worn.armor>plain.armor or worn.attack_speed>plain.attack_speed or worn.crit>plain.crit or worn.crit_damage>plain.crit_damage or worn.ultimate_power>plain.ultimate_power or worn.element_power>plain.element_power or worn.speed>plain.speed or worn.range_multiplier>plain.range_multiplier or worn.healing_power>plain.healing_power or not worn.tag_bonus.is_empty()
			if not stronger:stats_ok=false;push_error("no stat line: "+String(kind))
			if ArenaIcon.texture(String(kind))==null:icons=false;push_error("no icon: "+String(kind))
			if kind!=&"weakEye" and item.description.contains("받는 피해 +") or item.description.contains("행동 불가") or item.description.contains("회복하지 못"):texts=false
	verify(stats_ok,"0.96: every 희귀+ item has at least one stat line")
	verify(icons,"0.96: every item has an icon")
	verify(texts,"0.96: no penalties left in the texts")
	verify(ItemCatalog.REPLACED.size()==11 and ItemCatalog.REPLACED.keys().all(func(k):return ItemCatalog.get_item(k)==null) and ItemCatalog.REPLACED.values().all(func(k):return ItemCatalog.get_item(k)!=null),"eleven items replaced")
	verify(ItemCatalog.get_item(&"woodSword+redThorn").description=="물리 피해 +10% · 처치할 때마다 공격력 +2% (런 동안 유지)","texts in one sentence, as in the plan")
	# 희귀
	var b:=gear_duel(tree,[[0,0,Vector2(200,400),[&"firstStrikeRing",&"poisonDagger"]],[0,0,Vector2(200,560),[&"guardFeather",&"lifeChalice"]],[0,1,Vector2(300,400),[]],[0,1,Vector2(600,600),[]]])
	var ring: BattleUnit=b.units[0];var feather: BattleUnit=b.units[1];var foe: BattleUnit=b.units[2]
	var basic: Dictionary=_spec(&"basic",&"physical",[&"melee"])
	verify(&"first_strike" in _keys(ring) and is_equal_approx(ItemEffects.outgoing(ring,foe,{},basic),2.0) and is_equal_approx(ItemEffects.outgoing(ring,foe,{},basic),1),"첫 일격의 반지: the next basic attack +100%")
	_tick(b,8.05);verify(is_equal_approx(ItemEffects.outgoing(ring,foe,{},basic),2.0),"첫 일격의 반지: ready again after 8 s")
	var poisoned: bool=false
	for i in range(60):
		ItemEffects.after_hit(ring,foe,_out(5),basic,{})
		if foe.state_value("poisonStacks")>0:poisoned=true;break
	verify(poisoned,"독 바른 단검: basic attacks poison sometimes")
	feather.current_hp=feather.max_hp*.25;feather.shield_hp=0;ItemEffects.after_hit(foe,feather,_out(10),basic,{})
	verify(is_equal_approx(feather.shield_hp,feather.max_hp*.25),"수호의 깃털: under 30% HP, a 25% shield")
	feather.shield_hp=0;ItemEffects.after_hit(foe,feather,_out(10),basic,{});verify(feather.shield_hp==0,"수호의 깃털: once per battle")
	ring.shield_hp=0;ring.current_hp=ring.max_hp;CharacterAbility.restore_hp(ring,ring.max_hp,feather)
	verify(is_equal_approx(ring.shield_hp,ring.max_hp*.2),"생명의 성배: overhealing becomes a shield up to 20%")
	b.queue_free()
	# 영웅
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"piercingAwl",&"weakEye"]],[4,0,Vector2(200,560),[&"guardChain"]],[0,0,Vector2(260,620),[&"executionScythe",&"swiftCloak"]],[0,1,Vector2(300,400),[]],[0,1,Vector2(360,470),[]]])
	var awl: BattleUnit=b.units[0];var chain: BattleUnit=b.units[1];var friend: BattleUnit=b.units[2];var e1: BattleUnit=b.units[3];var e2: BattleUnit=b.units[4]
	e1.combat_stats.defense=100;var full: float=CombatRules.mitigation(e1,&"physical");var pierced: float=CombatRules.mitigation(e1,&"physical",ItemEffects.defense_pen(awl,false))
	verify(pierced>full and is_equal_approx(ItemEffects.defense_pen(awl,false),.3),"관통의 송곳: 30% of the defense ignored")
	ItemEffects.after_hit(awl,e1,_out(5),basic,{})
	verify(e1.state_value("weakTime")>0 and is_equal_approx(ItemEffects.incoming(e1),1.12) and &"weak_exposed" in _keys(e1),"약점 간파의 눈: the target takes +12% for 4 s (약점 노출)")
	var shares: Array=ItemEffects.plan_share(friend,100,e1,&"physical")
	verify(shares.size()==1 and shares[0].unit==chain and is_equal_approx(float(shares[0].cut),20) and is_equal_approx(float(shares[0].damage),10),"수호의 사슬: takes 20% of its nearest ally's hit, at half")
	verify(is_equal_approx(ItemEffects.incoming(friend,_spec(&"basic",&"physical",[&"projectile"])),.75) and is_equal_approx(ItemEffects.incoming(friend,basic),1),"신속의 망토: projectile damage taken -25%")
	e2.current_hp=e2.max_hp*.14;ItemEffects.after_hit(friend,e2,_out(1),basic,{})
	verify(not e2.alive,"처형의 낫: an attack on an enemy at 15% HP or less kills it (no critical needed)")
	e1.current_hp=e1.max_hp*.1;e1.combat_stats.rank=&"boss";ItemEffects.after_hit(friend,e1,_out(1),basic,{})
	verify(e1.alive and is_equal_approx(ItemEffects.outgoing(friend,e1,{},basic),1.3),"처형의 낫: a boss takes +30% instead")
	b.queue_free()
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"elementStone",&"rageHorn"]],[0,1,Vector2(400,400),[]],[0,1,Vector2(450,450),[]]])
	var stone: BattleUnit=b.units[0];var v1: BattleUnit=b.units[1];var v2: BattleUnit=b.units[2]
	v1.set_state("burnStacks",3);var v2_hp: float=v2.current_hp;stone.current_hp=stone.max_hp*.5
	ItemEffects.on_kill(stone,v1)
	verify(int(v2.state_value("burnStacks"))>=2 and v2.current_hp<v2_hp,"원소 폭발석: a kill on a burning enemy bursts and passes 2 burn")
	verify(is_equal_approx(stone.current_hp,stone.max_hp*.65),"광폭의 뿔: a kill heals 15%")
	b.queue_free()
	# 전설
	b=gear_duel(tree,[[3,0,Vector2(200,400),[&"oblivionVeil"]],[0,0,Vector2(200,560),[&"elderHeart",&"warDrum"]],[2,0,Vector2(260,620),[&"lifeResonance",&"frostCrown"]],[0,1,Vector2(400,400),[]],[0,1,Vector2(600,600),[&"bloodChalice"]]])
	var veil: BattleUnit=b.units[0];var elder: BattleUnit=b.units[1];var reso: BattleUnit=b.units[2];var x1: BattleUnit=b.units[3];var cup: BattleUnit=b.units[4]
	verify(veil.state_value("shadowTime")>=3 and &"veil_strike" in _keys(veil) and is_equal_approx(ItemEffects.outgoing(veil,x1,{},basic),2.0),"암살자의 장막: hidden at the start, attacks x2")
	ItemEffects.on_action(veil,true);verify(is_equal_approx(ItemEffects.outgoing(veil,x1,{},basic),2.0) and is_equal_approx(ItemEffects.outgoing(veil,x1,{},basic),1),"the attack that reveals it still hits x2, once")
	ItemEffects.on_kill(veil,x1);verify(veil.state_value("shadowTime")>=3,"암살자의 장막: hidden again after a kill")
	elder.current_hp=elder.max_hp*.5;var eh: float=elder.current_hp;_tick(b,1.05)
	verify(is_equal_approx(elder.current_hp-eh,elder.max_hp*.015),"거목의 심장: 1.5% of max HP every second")
	verify(is_equal_approx(ItemEffects.attack_speed(reso),1.3) and &"war_drum" in _keys(reso) and is_equal_approx(ItemEffects.attack_speed(cup),1),"전쟁의 북: allies +30% for the first 10 s")
	b.clock.elapsed=20;verify(is_equal_approx(ItemEffects.attack_speed(reso),1.15),"전쟁의 북: +15% after")
	reso.current_hp=reso.max_hp*.5;elder.current_hp=elder.max_hp*.5;ItemEffects.after_ultimate(reso)
	verify(is_equal_approx(reso.current_hp,reso.max_hp*.7) and elder.state_value("regenTime")>0 and is_equal_approx(ItemEffects.incoming(elder),.7),"생명의 공명: an ultimate heals 20% around and -30% taken for 3 s")
	cup.current_hp=cup.max_hp*.5;var ch: float=cup.current_hp;ItemEffects.after_hit(cup,veil,_out(100),basic,{})
	verify(is_equal_approx(cup.current_hp-ch,20),"피의 성배: the bearer heals 20% of its direct damage")
	var frosted: int=int(x1.state_value("frostStacks"))
	ElementEffects.on_hit(reso,x1,_out(5),_spec(&"basic",&"magic",[&"ice"]),{})
	verify(int(x1.state_value("frostStacks"))==frosted+2,"원소 왕관: element stacks always land, one more")
	b.queue_free()
	setup_edge_check()
	# 고대
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"twinMirror"]],[0,0,Vector2(200,560),[&"mangoSeed"]],[0,0,Vector2(260,620),[&"rewindClock"]],[0,1,Vector2(600,400),[&"soulReaper"]],[2,1,Vector2(620,560),[&"invertedHourglass"]],[0,1,Vector2(560,650),[&"starShard"]]],7)
	var twin: BattleUnit=b.units[0];var mango: BattleUnit=b.units[1];var rewind: BattleUnit=b.units[2];var reaper: BattleUnit=b.units[3];var glass: BattleUnit=b.units[4]
	verify(twin.shield_hp>=twin.max_hp*.15-.01 and rewind.shield_hp>0 and reaper.shield_hp<=0,"황금 망고: every ally starts with a 15% shield")
	b.simulate(.016)
	var clones: Array=b.units.filter(func(u):return u.character_specific_state.has("mirrorOf"))
	verify(clones.size()==1 and absf(clones[0].max_hp-twin.max_hp*.7)<1 and clones[0].combat_stats.effects.is_empty(),"쌍둥이의 거울: a copy at 70% HP and damage")
	var start_hp: float=rewind.current_hp;var start_at: Vector2=rewind.position
	_tick(b,6.0)
	rewind.position=Vector2(500,300);rewind.current_hp=5
	verify(&"rewind_ready" in _keys(rewind) and CharacterLifecycle.intercept_lethal(rewind,999) and rewind.alive and rewind.current_hp>5 and rewind.position.distance_to(start_at)<40,"시간술사의 시계: a lethal blow goes back 5 s in HP and place")
	verify(not CharacterLifecycle.intercept_lethal(rewind,99999) or rewind.has_meta("never"),"시간술사의 시계: once a battle")
	glass.ultimate_gauge=0;b.clock.elapsed=11.9;_tick(b,.2)
	verify(is_equal_approx(glass.ultimate_gauge,100),"끝없는 모래시계: a full gauge at the turning-point times")
	var tg: float=glass.transcendence_gauge;glass.ultimate.charge(glass,200,true);verify(glass.transcendence_gauge>tg,"끝없는 모래시계: the transcendence gauge charges as usual now")
	reaper.current_hp=reaper.max_hp*.5;var rhp: float=reaper.max_hp;clones[0].receive_damage(99999,twin)
	verify(int(reaper.state_value("soulStacks"))==1 and reaper.max_hp>rhp*1.04 and &"soul_harvest" in _keys(reaper),"영혼 수확자: a death anywhere grows it (영혼 수확)")
	var star_foes: Array=[twin,mango,rewind].map(func(u):return u.current_hp)
	b.units[5].set_state("starClock",.05);_tick(b,.1)
	verify([twin,mango,rewind].any(func(u):return u.current_hp<star_foes[[twin,mango,rewind].find(u)]),"별의 파편: meteors fall on enemies")
	b.queue_free()
	b=gear_duel(tree,[[0,0,Vector2(200,400),[&"shadowDoll"]],[0,1,Vector2(300,400),[&"overdriveEngine"]],[0,1,Vector2(600,600),[&"greedPouch"]]])
	var doll: BattleUnit=b.units[0];var engine: BattleUnit=b.units[1];var greed: BattleUnit=b.units[2]
	var ehp: float=engine.current_hp;ItemEffects.after_hit(engine,doll,_out(100),basic,{})
	verify(engine.current_hp<ehp and engine.current_hp>ehp-30.5 and is_equal_approx(ItemEffects.outgoing(doll,engine,{}),1),"저주 인형: 30% of a hit goes back, no damage penalty")
	_tick(b,40.0);verify(is_equal_approx(ItemEffects.attack_speed(engine),1.9) and engine.stun_remaining<=0,"폭주 기관: +3% a second up to +90%, no overheat")
	ItemEffects.on_kill(greed,doll);verify(ItemEffects.greed_gold(greed)==15 and is_equal_approx(ItemEffects.incoming(greed),1),"탐욕의 황금손: 15 G a kill, no damage-taken penalty")
	verify(is_equal_approx(ItemEffects.greed_attack(1250),.12) and is_equal_approx(ItemEffects.greed_attack(99999),.5),"탐욕의 황금손: +1% attack per 100 G, up to +50%")
	b.queue_free()
	# 흉내쟁이의 가면: the ultimate goes again at half.
	b=gear_duel(tree,[[2,0,Vector2(200,400),[&"mimicMask"]],[0,1,Vector2(400,400),[]]])
	var mimic: BattleUnit=b.units[0];mimic.ultimate.cast.clear();ItemEffects.after_ultimate(mimic)
	verify(not mimic.ultimate.cast.is_empty() and mimic.state_value("mimicEcho")>0,"흉내쟁이의 가면: the same ultimate starts once more")
	verify(is_equal_approx(ItemEffects.outgoing(mimic,b.units[1],{},_spec(&"ultimate",&"magic",[])),.5),"흉내쟁이의 가면: at half power")
	mimic.ultimate.cast.clear();ItemEffects.after_ultimate(mimic);verify(mimic.ultimate.cast.is_empty() and mimic.state_value("mimicEcho")<=0,"no echo of the echo")
	b.queue_free()
	# 지휘관의 홀: its bearer does not take a sortie place.
	var t:=TowerController.new();t.new_run(19,73);var members: Array=t.guild.all_members()
	var scepter: ItemInstance=t.content.inventory.give(&"commanderScepter");t.content_action(&"equip",{"item_id":scepter.item_id,"member_id":members[0].member_id})
	var entries: Array=[]
	for mm in members:var de:=DeploymentEntry.new();de.member_id=mm.member_id;entries.append(de)
	verify(DeploymentRules.counted(t.guild,entries)==members.size()-1,"지휘관의 홀: one more unit can go out")
	# Save v8 -> v9: a replaced item becomes its replacement, with a notice.
	t=TowerController.new();t.new_run(19,73)
	var doc: Dictionary=JSON.parse_string(JSON.stringify(SaveSnapshotBuilder.capture(t,"v8",1).document))
	doc.schema_version=8;var next: int=int(doc.run.next_item_number)
	doc.run.inventory.append({"item_id":next,"kind":"voidHeart","equipped_to_member_id":"","consumed":false,"enhance":0,"variant":"","growth":3})
	doc.run.inventory.append({"item_id":next+1,"kind":"regenCore","equipped_to_member_id":"","consumed":false,"enhance":2,"variant":"","growth":0})
	doc.run.next_item_number=next+2;doc.run.erase("item_notice");doc.run["item_notice"]=""
	var back: SaveLoadResult=SaveSnapshotLoader.restore(doc)
	verify(back.ok() and back.run.inventory.any(func(i):return i.kind==&"soulReaper") and back.run.inventory.any(func(i):return i.kind==&"lifeResonance" and i.enhance==0) and back.run.item_notice.contains("영혼 수확자"),"v8 save: replaced items become their replacements, with a notice")
	# The item statuses are in the catalog with their kinds and icons.
	var kinds: Dictionary={&"bleed":&"debuff",&"weak_exposed":&"debuff",&"berserk":&"buff",&"hunt":&"buff",&"first_strike":&"buff",&"counter_crit":&"buff",&"veil_strike":&"buff",&"regen_barrier":&"buff",&"soul_harvest":&"growth",&"overdrive":&"growth",&"smash_ready":&"unique",&"mirror_clone":&"unique",&"rewind_ready":&"unique",&"blood_blessing":&"item",&"war_drum":&"item",&"king_aura":&"item",&"greed":&"item"}
	verify(kinds.keys().all(func(k):return StatusCatalog.ENTRIES.has(k) and StatusCatalog.ENTRIES[k][1]==kinds[k] and ArenaIcon.texture(StatusCatalog.ENTRIES[k][2])!=null),"item statuses with their kinds and icons")
	verify(not [&"salvation",&"overheat",&"frame",&"void_charge",&"shadow_link",&"elder_growth",&"mango_growth"].any(func(k):return StatusCatalog.ENTRIES.has(k)),"statuses of removed effects are gone")
## 무한의 칼날: critical hits ignore 30% of the defense; the stat lines are on the item.
func setup_edge_check() -> void:
	var e:=CustomBattleSetup.new();e.add(0,0,Vector2(200,200));var plain: UnitCombatStats=e.stats_for(e.entries[0]);e.equip(int(e.entries[0].id),&"infinityEdge")
	var worn: UnitCombatStats=e.stats_for(e.entries[0])
	verify(is_equal_approx(worn.crit-plain.crit,.2) and is_equal_approx(worn.crit_damage-plain.crit_damage,.6) and worn.physical_damage>plain.physical_damage,"무한의 칼날: +15% physical, +20%p critical, +60% critical damage")
