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
	verify(setup.equip(id,&"woodSword")=="" and setup.equip(id,&"staff")=="" and setup.get_entry(id).items==[&"woodSword+staff"],"two basics fuse into one rare item")
	verify(setup.equip(id,&"dragonHeart")=="" and setup.equip(id,&"verdantStone")!="","item slots capped at two")
	verify(setup.equip(id,&"reengrave")!="","consumables are not equippable")
	verify(is_equal_approx(setup.stats_for(setup.get_entry(id)).physical_power,1.15) and setup.stats_for(setup.get_entry(id)).dragon_heart_count==1,"items change stats")
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
	verify(CharacterCatalog.all().size()==33,"33 characters in the catalog")
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
	var hit: DamageOutcome=b.damage_resolver.resolve(magnet,b.units[1],100,{"critical":false,"impulse":0})
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
	# Grades: 9 basics, 45 combinations (same pair included), 3 ancients; the shop pool is basics + reengrave.
	var all: Dictionary=ItemCatalog.all();var count: Dictionary={}
	for k in all:count[all[k].grade]=int(count.get(all[k].grade,0))+1
	verify(count.get(&"common")==9 and count.get(&"rare")==45 and count.get(&"ancient")==3,"item grades 9 / 45 / 3")
	verify(ItemCatalog.KINDS.all(func(k):return ItemCatalog.get_item(k).grade==&"common" or ItemCatalog.get_item(k).consumable),"only basics are handed out")
	verify(ItemCatalog.combined_kind(&"staff",&"woodSword")==ItemCatalog.combined_kind(&"woodSword",&"staff"),"combination is order free")
	var rare: ItemData=ItemCatalog.get_item(&"woodSword+woodSword")
	verify(is_equal_approx(rare.physical_bonus,.3) and rare.components==[&"woodSword",&"woodSword"],"same-pair rare doubles and boosts the stat")
	verify(ItemCatalog.get_item(&"warmNecklace+verdantStone").vigor_totem and ItemCatalog.get_item(&"woodSword+redThorn").kill_growth,"old abilities live on combined items")
	# Tower: a basic meets a basic on the same unit and fuses; rare items keep their slot.
	var t:=TowerController.new();t.new_run(19,73);var m: GuildMemberState=t.guild.all_members()[0]
	var ids: Array=[]
	for kind in [&"woodSword",&"redThorn",&"staff",&"staff",&"verdantStone"]:ids.append(t.content.inventory.give(kind).item_id)
	var results: Array=ids.map(func(id):return t.content_action(&"equip",{"item_id":id,"member_id":m.member_id}))
	verify(results[1].ok and results[1].outcome.combined==&"woodSword+redThorn","second basic fuses into 포식자의 엄니")
	verify(t.content.inventory.get_item(ids[0]).consumed and t.content.inventory.get_item(ids[1]).consumed,"components are used up")
	verify(results[3].ok and not results[4].ok and t.content.inventory.equipped(m.member_id).size()==2,"two rare items fill two slots")
	var stats: UnitCombatStats=t.guild.member_stats(m)
	verify(is_equal_approx(stats.magic_power,1.3) and is_equal_approx(stats.fang_rate(),.015*1.34),"rare stats and stronger kill growth reach the member")
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
	var t:=TowerController.new();t.new_run(5,9);var m: GuildMemberState=t.guild.all_members()[0]
	var host:=Control.new();tree.root.add_child(host)
	var sheet:=UnitInfoSheet.open(host,m.unit_type_id,t.guild.member_stats(m),m);await tree.process_frame
	var titles: Array=sheet.find_children("*","Label",true,false).map(func(l):return l.text)
	verify(["행동성향","기본공격","패시브","궁극기","초월 스킬","기본 스탯","특수 스탯"].all(func(x):return x in titles),"unit sheet shows every section")
	var buttons: Array=sheet.find_children("*","Button",true,false)
	var more: Array=buttons.filter(func(x):return x.text=="자세히 보기")
	verify(buttons.any(func(x):return x.text=="전체 보기") and more.size()==4,"stats fold behind 전체 보기; each warrior skill unfolds its damage")
	more[0].pressed.emit()
	verify(more[0].text=="접기" and sheet.find_children("*","Label",true,false).any(func(l):return l.is_visible_in_tree() and l.text.begins_with("물리 피해의 100%  →  예상 ")),"basic attack detail lists base + ratio and the estimate")
	sheet.queue_free()
	# Without a member the sheet shows the table's base numbers.
	sheet=UnitInfoSheet.open(host,30);await tree.process_frame
	verify(sheet.stats.magic_damage==UnitStatTable.base_magic(30) and sheet.find_children("*","Label",true,false).any(func(l):return l.text=="10 + 마법 피해의 85%  →  예상 30"),"base sheet: magnet's pole hit is 10 + 85% of 24 magic damage")
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
	verify(tagged and CharacterCatalog.NAMES.size()==33,"all 33 units have base stats and exactly one kind plus known tags per damage instance")
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
	verify(is_equal_approx(grown.magic_damage,UnitStatTable.base_magic(2)*1.4) and is_equal_approx(grown.defense,35*1.4) and grown.magic_defense==10 and grown.attack==1,"growth raises damage stats and defense, attack % stays 100%")
	var entry:=EnemySpawnEntry.new();entry.level=0;entry.set_rank(&"elite")
	var elite: UnitCombatStats=TowerEnemyStatsAssembler.assemble(CharacterCatalog.all()[2],entry)
	verify(elite.attack==entry.damage_multiplier and elite.attack>1 and is_equal_approx(elite.magic_damage,UnitStatTable.base_magic(2)*.8),"elite damage multiplier becomes attack %")
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
