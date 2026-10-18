class_name Phase8Tests
extends RefCounted
var host: SceneTree
var checks: int=0
var failures: int=0
var groups: int=0
var character_results: Dictionary={}
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE8 FAIL: "+label)
func fixture(types: Array,teams: Array=[],points: Array=[]) -> BattleManager:
	var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
	var entries: Array[Dictionary]=[]
	for i in range(types.size()):entries.append({"data":CharacterCatalog.all()[types[i]],"team":teams[i] if not teams.is_empty() else 0 if i==0 else 1,"position":points[i] if not points.is_empty() else Vector2(300+i*80,400)})
	verify(b.start_battle(entries,87),"full fixture accepts")
	for u in b.units:
		u.combat.cooldown=10000;u.parry_cooldown=10000;u.defense_cooldown=10000;u.move_speed=0
		u.data=u.data.duplicate();u.data.critical_chance=0
	return b
func tick(b,seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		if b.finished:break
		b.simulate(1.0/60)
func hit(b,source,target,amount: float,options: Dictionary={}) -> DamageOutcome:
	var opts: Dictionary={"critical":false,"impulse":0};opts.merge(options,true)
	return b.damage_resolver.resolve(source,target,amount,opts)
func catalog() -> void:
	groups+=1
	var definitions: Dictionary=CharacterCatalog.all()
	var file:=FileAccess.open("res://migration/phase8-web-catalog.json",FileAccess.READ)
	var web: Array=JSON.parse_string(file.get_as_text())
	verify(definitions.size()==31 and web.size()==26,"26 real web types plus 5 custom-battle types")
	for t in web:
		var data: UnitData=definitions[int(t.type_id)]
		for pair in [["display_name","name"],["max_hp","hp"],["attack","dmg"],["defense_power","defensePower"],["move_speed","speed"],["attack_range","range"],["attack_interval","cd"],["critical_chance","critChance"],["base_gold_cost","cost"]]:verify(data.get(pair[0])==t[pair[1]],"catalog %s/%s"%[t.name,pair[0]])
		for key in ["windup","active","recovery","reach","cone","impulse"]:verify(is_equal_approx(data.attack_profile.get(key),t.profile[key]),"profile %s/%s"%[t.name,key])
		verify(Array(data.tags)==t.tags,"tags")
		verify(data.ultimate_windup==(t.ultimate.windup if t.ultimate!=null else -1),"ultimate data")
	var b:=BattleManager.new();verify(b.common_combat_enabled and b.full_characters_enabled,"real default is common + full");b.free()
func characters() -> void:
	groups+=1
	for batch in [[0,1,2,3,4,5],[6,7,8,9,10,11],[12,13,14,15,16,17],[18,19,20,21,22,23],[24,25]]:
		for kind in batch:
			var b:=fixture([kind,0,1],[0,1,0],[Vector2(300,400),Vector2(370,400),Vector2(230,220)])
			var u: BattleUnit=b.units[0];var e: BattleUnit=b.units[1]
			var before_checks: int=checks;var before_failures: int=failures
			u.target=e;u.combat.force_start(u,e);u.combat.cooldown=10000
			if kind==15:StatusController.stun(e,3)
			tick(b,6)
			verify(u.combat.attacks_released>0,"basic released %d"%kind)
			verify(u.position.is_finite() and is_finite(u.current_hp),"finite basic %d"%kind)
			if not b.finished:
				u.combat.cancel(u);u.ultimate.cast.clear();u.stun_remaining=0
				u.ultimate_gauge=100
				if kind==24:
					var friend=b.units[2];friend.current_hp=1
					verify(CharacterLifecycle.intercept_lethal(friend,1000),"frog reactive ultimate")
				elif kind==7:verify(not u.ultimate.request(u,e),"shotgun no ultimate")
				else:
					if kind==19:u.saint_actor=b.units[2].actor_id()
					verify(u.ultimate.request(u,u.ability.ultimate_target(u)),"ultimate request %d"%kind)
					verify(u.ultimate_gauge==0,"ultimate pays gauge %d"%kind)
				u.set_meta("tested_ult_serial",u.ultimate.serial)
				tick(b,6)
				verify(u.ultimate.cast.is_empty() or u.ultimate.serial>int(u.get_meta("tested_ult_serial",u.ultimate.serial)) or kind==11 and u.combat_state!=CombatController.State.IDLE,"cast resolves %d"%kind)
				var saved: Dictionary=StrategyEffects.snapshot(u)
				verify(UnitStateCodec.is_pure_data(saved),"pure state %d"%kind)
				var before: Array=[u.position,u.current_hp,u.combat.phase_time,saved.duplicate(true),u.ultimate_gauge]
				b.clock.state=BattleClock.State.TURNING_PAUSED
				b.simulate(1)
				verify(before==[u.position,u.current_hp,u.combat.phase_time,StrategyEffects.snapshot(u),u.ultimate_gauge],"TP freezes all character state %d"%kind)
				b.clock.state=BattleClock.State.NORMAL
				var shield_before: float=u.shield_hp;u.shield_hp=100;u.shield_remaining=8
				verify(hit(b,e,u,10).hp_damage==0,"shield card state interacts %d"%kind)
				u.shield_hp=shield_before
				var clone:=b.unit_factory.create({"data":u.data,"team":u.original_team,"position":Vector2(180,180)},999,b,b.rng)
				clone.character_specific_state=saved.duplicate(true);StrategyEffects.inject(clone,saved);CharacterPersistence.restore(clone)
				verify(clone.character_specific_state==saved,"state restore transport %d"%kind)
				clone.free()
				b.finish_with_reason(BattleEndReason.Value.RETREAT,-1)
				var end: Array=[b.clock.elapsed,u.current_hp,u.position,u.ultimate_gauge]
				b.simulate(1);verify(end==[b.clock.elapsed,u.current_hp,u.position,u.ultimate_gauge],"post finish frozen %d"%kind)
			character_results[kind]={"checks":checks-before_checks,"failures":failures-before_failures}
			b.free()
		print("PHASE8 BATCH ",batch," results ",character_results)
func golden_damage() -> void:
	groups+=1
	var b:=fixture([0,4,4],[0,1,1]);var w=b.units[0];var g=b.units[1]
	verify(CombatRules.defense(g)==62,"guardian aura22 non stacking")
	g.defense_cooldown=0
	var out:=hit(b,w,g,100)
	verify(out.hp_damage==30,"guardian .8 * armor100/122 then unique .45 ceil")
	b.free()
	b=fixture([25,1,0,0],[0,0,0,1],[Vector2(300,400),Vector2(260,400),Vector2(220,400),Vector2(380,400)])
	var puppet=b.units[0];var attacker=b.units[3];puppet.shield_hp=10;puppet.shield_remaining=8
	var hp1: float=b.units[1].current_hp;var hp2: float=b.units[2].current_hp
	out=hit(b,attacker,puppet,50)
	verify(out.shield_absorbed==10 and out.hp_damage==28,"puppet post shield40 share12 -> owner28")
	verify(b.units[1].current_hp==hp1-6 and b.units[2].current_hp==hp2-6,"share two independently")
	b.free()
	b=fixture([21,21]);var mirror=b.units[1];var source=b.units[0]
	source.shield_hp=100;source.shield_remaining=8
	out=hit(b,source,mirror,30)
	verify(out.hp_damage==30 and source.shield_hp==97,"mirror10% shard shield no recursive shards")
	mirror.set_state("mirrorReflectTime",3);mirror.invincible_remaining=2
	out=hit(b,source,mirror,40)
	verify(out.hp_damage==0 and out.reflected_damage==40 and b.projectiles.size()==1,"reflection before invincible creates raw40")
	b.free()
	b=fixture([0,17,1],[1,0,0],[Vector2(450,400),Vector2(120,400),Vector2(350,400)])
	var hero=b.units[1];var patient=b.units[2];patient.current_hp=1
	out=hit(b,b.units[0],patient,1000)
	verify(out.hp_damage==0 and patient.alive and hero.hero_rescue_used and patient.current_hp==1,"hero intercept before death")
	verify(hit(b,b.units[0],patient,1000).hp_damage==0,"protected during rescue rush")
	for i in range(25):CharacterLifecycle.advance(b,1.0/60)
	verify(hero.hero_rescue.is_empty() and patient.shield_hp==60 and patient.shield_remaining==10,"hero arrival60 shield10")
	b.free()
func golden_states() -> void:
	groups+=1
	var b:=fixture([10,0]);var u=b.units[0];var e=b.units[1]
	hit(b,e,u,5);verify(u.state_value("guardRemaining")==4 and u.state_value("guardStacks")==1,"guard first hit4sec +1")
	hit(b,e,u,5);verify(u.state_value("guardStacks")==2,"guard second +1")
	CharacterLifecycle.advance(b,4)
	verify(u.state_value("guardRemaining")==0 and u.ability.movement_rate(u)==1.3,"guard ends movement30%")
	u.combat.force_start(u,e)
	verify(u.state_value("guardStacks")==0 and is_equal_approx(u.combat.active_profile.reach,201.6),"next attack consumes stacks")
	u.lost_sword={"point":CharacterPersistence.point(Vector2(420,480)),"flight":.4,"vx":200.0,"vy":0.0,"rotation":0.0,"scale":1.0,"sizeBoost":1.12}
	var saved: Dictionary=StrategyEffects.snapshot(u)
	verify(saved.lostSword.dx==120 and saved.lostSword.dy==80,"lost sword relative coordinates")
	var clone=b.unit_factory.create({"data":u.data,"team":0,"position":Vector2(100,200)},99,b,b.rng);clone.character_specific_state=saved.duplicate(true);StrategyEffects.inject(clone,saved);CharacterPersistence.restore(clone)
	verify(CharacterPersistence.vector(clone.lost_sword.point)==Vector2(220,280),"lost sword restore relative new deployment")
	clone.free();b.free()
	b=fixture([11,0]);u=b.units[0];e=b.units[1]
	hit(b,e,u,15.5);verify(u.state_value("dolphinStacks")==1 and is_equal_approx(u.combat_scale(),.94),"dolphin totalHP10% shrinking")
	u.set_state("curseTime",6);verify(is_equal_approx(u.combat_scale(),.94*.65),"curse multiplicative scale")
	CharacterLifecycle.advance(b,6);verify(u.state_value("curseTime")==0,"curse expires")
	b.free()
	b=fixture([12,1,0],[0,1,1]);u=b.units[0];e=b.units[1];e.current_hp=15
	outcome_execute(b,u,e)
	verify(not e.alive and u.state_value("predatorStacks")==1,"predator threshold13 execution +growth")
	verify(is_equal_approx(u.combat_scale(),1.04),"predator scale4%")
	b.free()
	b=fixture([8,0]);u=b.units[0];e=b.units[1];u.set_state("duelRounds",2)
	verify(CharacterLifecycle.begin_duel(u,e),"duel begins lock")
	verify(StatusController.skill_charge_blocked(u),"duel locks charge")
	CharacterLifecycle.advance_duel(u,1.7)
	verify(u.state_value("duelRounds")==3 and e.current_hp==e.data.max_hp-roundf(e.data.max_hp*.35),"third duel guarantees master win35%")
	CharacterLifecycle.advance_duel(u,.5);verify(u.duel.is_empty() and e.duel.is_empty(),"duel ends both locks")
	b.free()
func outcome_execute(b,u,e) -> void:hit(b,u,e,4,{"execute_threshold":.13})
func golden_relationships() -> void:
	groups+=1
	var b:=fixture([24,0,1],[0,1,1],[Vector2(300,400),Vector2(450,400),Vector2(500,400)])
	var frog=b.units[0];var cargo=b.units[1]
	verify(CharacterLifecycle.capture(frog,cargo),"frog enemy capture")
	verify(cargo.unavailable() and not CombatPerception.can_perceive(b.units[2],cargo),"cargo unavailable to all targeting")
	for i in range(60):CharacterLifecycle.advance(b,1.0/60)
	verify(b.projectiles.size()==1 and b.projectiles[0].kind=="frogBody" and cargo.frog_flight!=0,"pull hold spit real cargo projectile")
	b.finish_with_reason(BattleEndReason.Value.RETREAT,-1)
	verify(not cargo.unavailable() and not cargo.frog_rescue_guard,"cargo released before settlement")
	b.free()
	b=fixture([25,0,1],[0,1,1]);var owner=b.units[0];var controlled=b.units[1]
	verify(CharacterLifecycle.control(controlled,owner),"control creates7")
	verify(controlled.team==0 and controlled.original_team==1,"team vs ownership/faction separate")
	verify(StatusController.skill_charge_blocked(controlled),"controlled charge disabled")
	b.check_outcome();verify(not b.finished,"controlled remaining original faction prevents false victory")
	var saved: Dictionary=StrategyEffects.snapshot(controlled);verify(saved.puppetControl.remaining==7 and saved.puppetControl.owner==owner.actor_id(),"control pure actor persistence")
	CharacterLifecycle.advance(b,7)
	verify(controlled.team==1 and controlled.puppet_control.is_empty(),"control expires ownership unchanged")
	b.free()
	b=fixture([19,0,1],[0,0,1]);var fan=b.units[0];var saint=b.units[1]
	verify(fan.saint_actor==saint.actor_id() and is_equal_approx(CharacterCombat.champion_factor(saint),1.1),"saint chosen and10% devotion")
	saint.current_hp=0;saint.alive=false;saint.announce_death(b.units[2]);fan.ability.tick(fan,.01)
	verify(fan.character_specific_state.get("saintFallen",false) and fan.ability.attack_rate(fan)==1.3 and CombatRules.taken(fan)==1.2,"saint death rage")
	b.free()
func targets_and_charging() -> void:
	groups+=1
	var b:=fixture([3,0,5,14],[0,1,1,1],[Vector2(300,400),Vector2(380,400),Vector2(600,400),Vector2(550,500)])
	var u=b.units[0]
	b.units[1].current_hp=30;b.units[2].current_hp=30
	verify(u.ability.choose_target(u,u.enemies())==b.units[2],"assassin equal lowHP prefers rear")
	u.set_state("shadowTime",10);u.ability.tick(u,.01)
	verify(not CombatPerception.can_perceive(b.units[1],u),"ultimate shadow full conceal even close")
	verify(is_equal_approx(u.ability.critical_bonus(u,b.units[3]),.25),"assassin fullHP10 +shadow15")
	u.ultimate_gauge=0;u.stun_remaining=1;verify(u.ultimate.gain(u,50)==0,"charge stun blocked")
	u.stun_remaining=0;verify(u.ultimate.gain(u,37)==37,"direct gain37")
	u.ultimate_gauge=0;u.ultimate.charge(u,10,true)
	verify(is_equal_approx(u.ultimate_gauge,10.0/145*65*1.3*.2),"assassin damage efficiency20%")
	u.taunted_until=b.clock.elapsed+8;u.ultimate_gauge=100
	verify(u.ultimate.gain(u,50)==0 and u.ultimate.request(u,b.units[1]),"taunt blocks charge, not existing ultimate use")
	b.free()
	b=fixture([0,1]);u=b.units[0]
	u.source_member_id="test_member";u.energy=3;u.ultimate_gauge=0;u.transcendence_gauge=0
	u.ultimate.charge(u,15,true)
	verify(is_equal_approx(u.ultimate_gauge,15.0/150*65*1.2*.86),"warrior damage65*1.2 fatigue86%")
	verify(is_equal_approx(u.transcendence_gauge,15.0/150*12*.86),"trans only damage12 fatigue")
	var old: float=u.transcendence_gauge;u.ultimate.advance(u,1)
	verify(u.transcendence_gauge==old,"no automatic transcendence charge")
	b.free()
func transcendence() -> void:
	groups+=1
	var b:=fixture([0,0,1],[0,1,1],[Vector2(300,400),Vector2(500,400),Vector2(680,700)])
	var u=b.units[0];u.source_member_id="manual";u.transcendence_gauge=100
	verify(b.transcendence.begin(u,Vector2(100,100)),"manual aim begins")
	var old: Array=[b.clock.elapsed,b.units[1].position,b.units[1].current_hp]
	b.simulate(1);verify(old==[b.clock.elapsed,b.units[1].position,b.units[1].current_hp],"aim freezes world")
	b.transcendence.update(Vector2(100,100));verify(not b.transcendence.release() and u.transcendence_gauge==100,"deadzone cancel free")
	b.clock.state=BattleClock.State.TURNING_PAUSED
	verify(b.transcendence.begin(u,Vector2(100,100)),"web allows transcendence during TP hold")
	b.transcendence.update(Vector2(160,100));verify(b.transcendence.release() and u.transcendence_gauge==0,"direction manual cast pays gauge")
	b.simulate(.38);verify(b.units[1].current_hp==10,"transcend hit140 skips parry crit")
	verify(b.clock.elapsed==old[0],"trans uses real clock, simulation frozen")
	verify(u.transcendence_gauge==0,"own transcendence cannot refill own gauge")
	b.simulate(.8);verify(b.clock.state==BattleClock.State.TURNING_PAUSED,"returns previous TP hold")
	b.free()
func mixed_performance() -> void:
	groups+=1
	for seed in [101,205,307]:
		var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
		var entries: Array[Dictionary]=[]
		var kinds: Array=[23,20,2,5,4,12,10,14,17,21,24,25]
		for team in range(2):
			for i in range(12):entries.append({"data":CharacterCatalog.all()[kinds[(i+team*3)%12]],"team":team,"position":Vector2(90+(i%3)*80 if team==0 else 550+(i%3)*80,90+(i/3)*170)})
		verify(b.start_battle(entries,seed),"12v12 starts")
		var begin: int=Time.get_ticks_msec();var peak_projectiles: int=0;var peak_strikes: int=0
		for frame in range(60*120):
			if b.finished:break
			b.simulate(1.0/60);peak_projectiles=maxi(peak_projectiles,b.projectiles.size());peak_strikes=maxi(peak_strikes,b.melee_strikes.size())
			if frame%60==0:
				for actor in b.units:
					verify(actor.position.is_finite() and actor.knockback_velocity.is_finite(),"mixed finite")
					verify(is_finite(actor.current_hp) and actor.current_hp>=0 and actor.current_hp<=actor.data.max_hp,"mixed HP bounds")
				verify(b.projectiles.size()<1000 and b.melee_strikes.size()<1000,"bounded physical objects")
		if not b.finished:b.finish_with_reason(BattleEndReason.Value.RETREAT,-1)
		verify(b.projectiles.is_empty() and b.melee_strikes.is_empty() and b.zones.entries.is_empty(),"end cleans physical objects")
		var final: Array=b.units.map(func(u):return [u.current_hp,u.position,u.ultimate_gauge,StrategyEffects.snapshot(u)])
		b.simulate(10);verify(final==b.units.map(func(u):return [u.current_hp,u.position,u.ultimate_gauge,StrategyEffects.snapshot(u)]),"mixed finished frozen")
		print("PHASE8 MIXED seed=",seed," simulation=",b.clock.elapsed," wall_ms=",Time.get_ticks_msec()-begin," peak_projectiles=",peak_projectiles," peak_strikes=",peak_strikes," reason=",b.result.end_reason)
		b.free()
func run(tree: SceneTree) -> void:
	host=tree
	catalog();characters();golden_damage();golden_states();golden_relationships();targets_and_charging();transcendence();projectile_goldens();room_persistence_and_cards();extra_interactions();persistence_whitelist();all_character_cards_and_plans();control_retry_golden();mixed_performance();projectile_stress()
	print("PHASE 8 RESULT: ",groups," groups; ",checks," checks; ",failures," failures")
func projectile_goldens() -> void:
	groups+=1
	var b:=fixture([1,0],[0,1],[Vector2(740,200),Vector2(500,700)])
	var u=b.units[0];u.combat.aim_angle=0;u.set_state("shotsFired",2);u.ability.release_basic(u)
	verify(b.projectiles.size()==3 and b.projectiles.all(func(p):return p.bounces==2 and p.lifetime==8),"third archer fan3 bounce2 life8")
	var arrow=b.projectiles[1];arrow.position=Vector2(780,200);arrow.velocity=Vector2(470,0)
	verify(ProjectileRules.boundary(arrow) and arrow.bounces==1 and arrow.velocity.x<0,"bounce keeps continuous ray")
	b.free()
	b=fixture([21,0],[0,1],[Vector2(740,200),Vector2(500,700)]);u=b.units[0];u.combat.aim_angle=0;u.ability.release_basic(u)
	arrow=b.projectiles[0];arrow.position=Vector2(780,200);arrow.velocity=Vector2(620,0);ProjectileRules.boundary(arrow)
	verify(is_equal_approx(arrow.damage,21.6) and arrow.bounces==3,"mirror bounce20%")
	b.free()
	b=fixture([7,0]);u=b.units[0];u.combat.aim_angle=0;u.ability.release_basic(u);u.ability.release_basic(u)
	verify(b.projectiles.size()==14 and u.state_value("ammo")==0 and u.state_value("reloadRemaining")==4,"shotgun 14 pellets then reload4")
	u.stance=CombatStance.RUSH;u.move_speed=112
	var gap: float=u.position.distance_to(b.units[1].position);u.brain.movement(u,b.units[1],.2)
	verify(u.position.distance_to(b.units[1].position)>gap,"rush shotgun still withdraws while reloading")
	u.ability.tick(u,4);verify(u.state_value("ammo")==2 and u.state_value("reloadRemaining")==0,"shotgun refill")
	b.free()
	b=fixture([6,0]);u=b.units[0];u.combat.force_start(u,b.units[1]);u.set_state("sniperBurstReady",true);u.ability.release_basic(u)
	u.combat_state=CombatController.State.ACTIVE;u.combat.phase_time=.16;u.ability.attack_tick(u,.16);u.combat.phase_time=.32;u.ability.attack_tick(u,.16)
	verify(b.projectiles.size()==3 and b.projectiles.all(func(p):return p.velocity.length()>4699 and p.piercing),"sniper triple4700 piercing")
	b.free()
	b=fixture([23,0]);u=b.units[0];u.combat.force_start(u,b.units[1]);u.ability.release_basic(u);u.combat_state=CombatController.State.ACTIVE;u.combat.phase_time=2.1;u.ability.attack_tick(u,2.1)
	verify(u.state_value("ammo")==0 and u.state_value("reloadRemaining")==4 and b.projectiles.size()==20,"machine gun20 rounds reload4")
	verify(b.projectiles.all(func(p):return absf(p.velocity.angle())<=.301),"machine gun weighted central spread bounds")
	verify(u.knockback_velocity.x<0,"machine recoil")
	u.combat_state=CombatController.State.ACTIVE;u.combat.attack_target=b.units[1];b.units[1].position+=Vector2(0,100);var old_angle: float=u.combat.aim_angle
	u.ability.attack_tick(u,.1);verify(u.combat.aim_angle>old_angle and u.combat.aim_angle<=old_angle+.400001,"machine active tracking max4rad/s")
	u.ability.tick(u,4);verify(u.state_value("ammo")==20,"machine refill")
	b.free()
	b=fixture([20,0,0,0],[0,1,1,1],[Vector2(300,400),Vector2(360,400),Vector2(440,400),Vector2(520,400)])
	u=b.units[0];u.combat.aim_angle=0;u.ability.release_basic(u)
	for i in range(240):
		if b.finished:break
		b.simulate(1.0/60)
	verify(b.units.slice(1).any(func(e):return e.state_value("shockStacks")>0 or e.stun_remaining>0),"chain lightning shock runtime")
	verify(u.state_value("shotsFired")>=2,"chain actually transferred")
	b.free()
	b=fixture([22,1,0],[0,0,1],[Vector2(300,300),Vector2(600,400),Vector2(550,450)])
	u=b.units[0];var archer=b.units[1];arrow=CharacterAbility.shoot(archer,0,15)
	var well=b.zones.add(u,"galaxy",Vector2(650,450),270,7,{"target":b.units[2].actor_id()})
	var velocity: Vector2=arrow.velocity;b.zones.advance(b,.1)
	verify(not arrow.velocity.is_equal_approx(velocity),"galaxy nearby allies projectiles steer")
	arrow.position=Vector2(40,40);velocity=arrow.velocity;b.zones.advance(b,.1);verify(arrow.velocity==velocity,"galaxy outside radius untouched")
	b.free()
func room_persistence_and_cards() -> void:
	groups+=1
	var guild:=GuildManager.new()
	var member: GuildMemberState=guild.create_member(14)
	var reserve: GuildMemberState=guild.create_member(24)
	var room:=RoomState.new("phase8_room");var enemy: EnemyRoomState=room.add_enemy("persistent_blade",guild.definition(14),Vector2(650,400))
	var plan:=DeploymentPlan.new(guild);verify(plan.place(member.member_id,Vector2(100,400))==DeploymentRules.Code.OK,"room full deployment")
	var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
	var session:=RoomBattleSession.new(guild,room);verify(session.start(plan,b,99),"full session starts")
	var u: BattleUnit=b.units[0];var e: BattleUnit=b.units[1]
	u.combat.cooldown=3.7;u.shield_hp=80;u.shield_remaining=6;u.stun_remaining=.9
	e.ultimate_gauge=100;e.target=u;verify(e.ultimate.request(e,u),"enemy cast starts")
	e.ultimate.cast.t=.4;e.set_state("shotsFired",7);e.current_hp=130
	b.clock.elapsed=20
	verify(session.request_retreat(),"retreat during ultimate cast")
	verify(member.character_specific_state.cooldown==3.7 and member.character_specific_state.shieldHp==80 and member.character_specific_state.stun==.9,"ally cooldown and actual common state saved")
	verify(enemy.persistent_state.ultCast.target=="member:"+member.member_id,"cast target stable member ID")
	verify(enemy.current_hp==130 and enemy.persistent_state.shotsFired==7,"enemy HP/stacks saved")
	verify(session.settlement.apply_room(b.result,guild,room)==BattleSettlement.Status.ALREADY_SETTLED,"full settlement idempotent")
	b.free()
	var second:=DeploymentPlan.new(guild);second.restore(guild.state.last_formation)
	b=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b);session=RoomBattleSession.new(guild,room)
	verify(session.start(second,b,100),"retry full room starts")
	u=b.units[0];e=b.units[1]
	verify(u.combat.cooldown==3.7 and u.shield_hp==80 and u.stun_remaining==.9,"ally runtime restoration")
	verify(e.ultimate.cast.target==u.actor_id() and e.ultimate.cast.t==.4 and e.current_hp==130,"enemy cast reconnects with new unit")
	b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2)
	verify(b.turning.is_paused(),"cards real TP hold")
	var charge: StrategyCardInstance=guild.state.give_strategy_card(&"charge")
	verify(StrategyCardExecutor.apply(b.turning,charge.card_id,member.member_id,"stunned").code==StrategyCardExecutor.Code.NO_EFFECT and charge.ready_floor==0,"charge rejects stun without record")
	u.stun_remaining=0;u.ultimate.cast.clear();u.ultimate_gauge=0
	verify(StrategyCardExecutor.apply(b.turning,charge.card_id,member.member_id,"charge").code==StrategyCardExecutor.Code.OK and u.ultimate_gauge==50,"charge actual gain50")
	var mango: StrategyCardInstance=guild.state.give_strategy_card(&"mango");u.current_hp=1;u.healing_power=1.1
	verify(StrategyCardExecutor.apply(b.turning,mango.card_id,member.member_id,"mango").code==StrategyCardExecutor.Code.OK and is_equal_approx(u.current_hp,1+u.data.max_hp*.3*1.1),"mango receiving healingPower")
	b.finish_with_reason(BattleEndReason.Value.RETREAT,-1);b.free()
	verify(reserve.is_alive(),"reserve unaffected")
func extra_interactions() -> void:
	groups+=1
	var b:=fixture([13,17,1],[1,0,0],[Vector2(360,400),Vector2(300,400),Vector2(420,400)])
	var bomber=b.units[0];var hero=b.units[1];var patient=b.units[2]
	patient.current_hp=1;bomber.current_hp=1;bomber.set_state("bomberRush",true);bomber.set_state("bomberFuse",0)
	bomber.ability.tick(bomber,.01)
	verify(not bomber.alive and hero.hero_rescue_used and patient.alive,"self destruct death then hero rescue AoE")
	b.check_outcome();verify(b.finished and b.result.end_reason==BattleEndReason.Value.VICTORY,"self destruct result once")
	b.free()
	b=fixture([15,0]);var satellite=b.units[0];var attacker=b.units[1]
	hit(b,attacker,satellite,10);verify(satellite.character_specific_state.satelliteBursts.size()==1,"satellite .16 queued burst")
	satellite.ability.tick(satellite,.16);verify(b.projectiles.size()==4 and b.projectiles.all(func(p):return is_equal_approx(p.damage,2.8)),"satellite actual four20% missiles")
	b.free()
	b=fixture([14,0],[0,1],[Vector2(300,400),Vector2(500,400)])
	var blade=b.units[0];blade.target=b.units[1];blade.ultimate_gauge=100;blade.ultimate.request(blade,blade.target)
	blade.ultimate.advance(blade,.65);verify(blade.ultimate.cast.get("dashing",false),"issen starts transit")
	var origin: Vector2=blade.position
	blade.ultimate.advance(blade,.05);verify(blade.position.x>origin.x+100,"issen fast actual2200 dash")
	for i in range(20):
		if blade.ultimate.cast.is_empty():break
		blade.ultimate.advance(blade,.05)
	verify(blade.ultimate.cast.is_empty() and b.melee_strikes.any(func(s):return s.shape==&"path" and s.path_width==95),"issen ends path slash independent")
	b.free()
	b=fixture([4,1],[0,1]);var guardian=b.units[0];guardian.invincible_remaining=10
	verify(hit(b,b.units[1],guardian,1000,{"transcendent":true}).hp_damage==0,"invincible still blocks transcend damage")
	b.free()
func persistence_whitelist() -> void:
	groups+=1
	var b:=fixture([0,1]);var u=b.units[0]
	u.source_member_id="persistent"
	u.vigor_totem_count=1;u.charge_totem_count=1;u.current_hp=50;u.ultimate_gauge=0
	u.set_state("totemClock",.1);u.set_state("chargeTotemClock",.1)
	CharacterLifecycle.advance(b,.1)
	verify(is_equal_approx(u.current_hp,53.6),"vigor recipient60% with exact6")
	verify(is_equal_approx(u.ultimate_gauge,2.4),"charge totem recipient60% exact4")
	u.set_state("test_counter",3);u.persistent_extra_fields.test_counter=3
	var saved: Dictionary=StrategyEffects.snapshot(u)
	verify(saved.totemClock==5 and saved.chargeTotemClock==4 and saved.test_counter==3,"item clocks whitelist + original custom state")
	for key in CharacterPersistence.FIELDS:
		verify(UnitStateCodec.is_pure_data(saved.get(key)),"whitelist pure "+key)
	b.free()
	b=fixture([9,0]);u=b.units[0];u.combat.force_start(u,b.units[1])
	verify(u.combat.attack_metadata.get("combo",0)==0,"combo starts0")
	var profile: AttackData=u.ability.next_profile(u,2)
	verify(profile.windup==.12,"UFC second/third windup .12")
	u.combat.cancel(u);u.parry_cooldown=0;u.defense_cooldown=0
	verify(u.parry.start(u,b.units[1]),"parry available against multihit")
	var before: float=b.units[1].current_hp
	hit(b,b.units[1],u,5,{"attack_token":"fist0"});hit(b,b.units[1],u,5,{"attack_token":"fist1"})
	verify(is_equal_approx(before-b.units[1].current_hp,10),"one reprisal per attacking source across distinct hits")
	b.free()
func all_character_cards_and_plans() -> void:
	groups+=1
	for kind in range(26):
		var b:=fixture([kind,kind]);var u=b.units[0];var e=b.units[1]
		var guild:=GuildManager.new();var member: GuildMemberState=guild.create_member(kind)
		u.source_member_id=member.member_id;e.source_enemy_id="enemy_%02d"%kind;b.room_id="cards"
		b.enable_turning_points(guild);b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2)
		verify(b.turning.is_paused(),"26 types TP hold %d"%kind)
		u.current_hp=u.data.max_hp*.5
		var mango: StrategyCardInstance=guild.state.give_strategy_card(&"mango")
		verify(StrategyCardExecutor.apply(b.turning,mango.card_id,member.member_id,"mango_%d"%kind).code==StrategyCardExecutor.Code.OK,"mango %d"%kind)
		verify(is_equal_approx(u.current_hp,u.data.max_hp*.8),"mango30%% %d"%kind)
		u.ultimate_gauge=0
		var charge: StrategyCardInstance=guild.state.give_strategy_card(&"charge")
		var out: Dictionary=StrategyCardExecutor.apply(b.turning,charge.card_id,member.member_id,"charge_%d"%kind)
		verify(out.code==(StrategyCardExecutor.Code.NO_EFFECT if kind==7 else StrategyCardExecutor.Code.OK),"charge supported ultimate %d"%kind)
		for card_kind in [&"shield",&"iron",&"evade",&"taunt"]:
			var card: StrategyCardInstance=guild.state.give_strategy_card(card_kind)
			verify(StrategyCardExecutor.apply(b.turning,card.card_id,member.member_id,str(card_kind)+str(kind)).code==StrategyCardExecutor.Code.OK,"card %s/type%d"%[card_kind,kind])
		verify(u.shield_hp==100 and u.shield_remaining==8 and u.iron_defense_remaining==15 and u.parry_cooldown==0,"shield/iron runtime %d"%kind)
		var plan:=EnemyTurningPlan.new();plan.source_enemy_id=e.source_enemy_id;plan.plan_type=EnemyTurningPlan.SPECIAL;plan.metadata=EnemyTurningPlan.special_metadata(kind)
		e.stun_remaining=1;var before: float=e.ultimate_gauge
		EnemyPlanExecutor.execute(plan,b)
		if kind==7:verify(e.state_value("ammo")==2 and e.state_value("reloadRemaining")==0 and e.strategy_special_until==20,"shotgun special exact8")
		else:verify(e.ultimate_gauge==before and e.character_specific_state.get("strategyUltimateReady",false),"special stun blocks gain but readiness kept %d"%kind)
		verify(b.turning.resolve(),"resolve cards/plans full %d"%kind)
		verify(u.command_retreat_until==18 and not u.strategy_dash.is_empty(),"pending escape real six seconds %d"%kind)
		verify(e.taunted_member_id==member.member_id and e.taunted_until==20,"pending taunt8 seconds %d"%kind)
		b.free()
func projectile_stress() -> void:
	groups+=1
	var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
	var entries: Array[Dictionary]=[]
	var kinds: Array=[23,23,23,23,23,23,20,20,20,2,2,5]
	for team in range(2):
		for i in range(12):entries.append({"data":CharacterCatalog.all()[kinds[i]],"team":team,"position":Vector2(120+(i%3)*75 if team==0 else 530+(i%3)*75,100+(i/3)*150)})
	verify(b.start_battle(entries,903),"projectile-heavy 12v12")
	for u in b.units:
		u.ultimate_gauge=100;u.set_state("ultReadyAge",5);u.ultimate.think=0
	var start: int=Time.get_ticks_msec();var peak_projectiles: int=0;var peak_zones: int=0;var emissions: int=0
	for frame in range(60*90):
		if b.finished:break
		b.simulate(1.0/60);peak_projectiles=maxi(peak_projectiles,b.projectiles.size());peak_zones=maxi(peak_zones,b.zones.entries.size())
		if frame%60==0:
			for p in b.projectiles:verify(p.position.is_finite() and p.velocity.is_finite(),"stress finite projectile")
			verify(b.projectiles.size()<1000 and b.get_children().filter(func(node):return not node.is_queued_for_deletion()).size()<=24+b.projectiles.size(),"stress no unbounded nodes")
	for u in b.units:emissions+=int(u.state_value("shotsFired"))
	verify(peak_zones>0,"actual ultimate zones exercised")
	verify(emissions>20,"actual gun/lightning many emissions")
	if not b.finished:b.finish_with_reason(BattleEndReason.Value.RETREAT,-1)
	verify(b.projectiles.is_empty() and b.zones.entries.is_empty(),"stress cleanup")
	print("PHASE8 PROJECTILE STRESS sim=",b.clock.elapsed," wall_ms=",Time.get_ticks_msec()-start," peak_projectiles=",peak_projectiles," peak_zones=",peak_zones," shots=",emissions)
	b.free()
func control_retry_golden() -> void:
	groups+=1
	var guild:=GuildManager.new();var m: GuildMemberState=guild.create_member(25)
	var room:=RoomState.new("control_room");var enemy: EnemyRoomState=room.add_enemy("controlled",guild.definition(0),Vector2(650,400))
	var plan:=DeploymentPlan.new(guild);plan.place(m.member_id,Vector2(100,400))
	var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
	var session:=RoomBattleSession.new(guild,room);verify(session.start(plan,b,19),"control retry starts")
	var u=b.units[0];var e=b.units[1]
	verify(CharacterLifecycle.control(e,u),"control enemy with stable owner")
	b.clock.elapsed=20;verify(session.request_retreat(),"controlled enemy remains original enemy for retreat")
	verify(enemy.persistent_state.puppetControl.owner=="member:"+m.member_id and enemy.persistent_state.puppetControl.team==0,"ownership/present team in persisted data")
	b.free()
	plan=DeploymentPlan.new(guild);plan.restore(guild.state.last_formation)
	b=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b);session=RoomBattleSession.new(guild,room)
	verify(session.start(plan,b,20),"control second attempt")
	u=b.units[0];e=b.units[1]
	verify(e.original_team==1 and e.team==0 and e.puppet_control.owner==u.actor_id(),"control restored after original-faction setup")
	verify(not b.finished and u.puppet_links.is_empty(),"original enemy not newly chosen as puppet sharing ally")
	b.finish_with_reason(BattleEndReason.Value.RETREAT,-1);b.free()
