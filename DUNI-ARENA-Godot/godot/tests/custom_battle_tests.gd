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
	verify(setup.equip(id,&"fang")=="" and setup.equip(id,&"vital")=="","two free items")
	verify(setup.equip(id,&"boots")!="","item slots capped at two")
	verify(setup.equip(id,&"reengrave")!="","consumables are not equippable")
	verify(setup.stats_for(setup.get_entry(id)).attack>CharacterCatalog.all()[0].attack,"items change stats")
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
	await map_wallet_return(tree)
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
	verify(CharacterCatalog.all().size()==32,"32 characters in the catalog")
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
	verify(hit.hp_damage>0 and is_equal_approx(partner_hp-b.units[2].current_hp,float(CombatRules.js_round(hit.hp_damage*.1))),"linked partner takes 10% of the damage")
	b.queue_free()
	# 기관사: the train hits enemies on the line hard and shoves allies lightly.
	b=duel(tree,[[27,0,Vector2(100,400)],[4,0,Vector2(250,400)],[1,1,Vector2(500,400)],[1,1,Vector2(650,400)]])
	var conductor: BattleUnit=b.units[0];conductor.ultimate_gauge=100
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
