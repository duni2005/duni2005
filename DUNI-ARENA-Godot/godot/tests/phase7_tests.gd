class_name Phase7Tests
extends RefCounted
var checks: int = 0
var failures: int = 0
var groups: int = 0
var host: SceneTree
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PHASE 7 FAIL: "+label)
func fixture(types: Array = [0,0,1], positions: Array = [Vector2(300,400),Vector2(380,400),Vector2(420,450)]) -> BattleManager:
	var battle := phase7_manager()
	battle.auto_start = false
	battle.common_combat_enabled = true
	battle.set_physics_process(false)
	host.root.add_child(battle)
	var entries: Array[Dictionary] = []
	for i in range(types.size()): entries.append({"data":BattleManager.WARRIOR if types[i]==0 else BattleManager.ARCHER,"team":0 if i==0 else 1,"position":positions[i]})
	verify(battle.start_battle(entries,77),"common fixture starts")
	for unit in battle.units:
		unit.combat.cooldown = 1000
		unit.parry_cooldown = 1000
		unit.defense_cooldown = 1000
		unit.data = unit.data.duplicate()
		unit.data.critical_chance = 0
	return battle
func parry_rules() -> void:
	groups += 1
	var battle := fixture()
	var u: BattleUnit = battle.units[0]
	var enemy: BattleUnit = battle.units[1]
	u.parry_cooldown = 0
	verify(u.parry.start(u,enemy),"ready common parry starts")
	verify(u.parry_cooldown==12 and u.defense_cooldown==12 and u.parry_remaining==1.2,"basic12 / window1.2")
	verify(not u.parry.start(u,enemy),"cooldown rejects second start")
	verify(ParryController.perfect(u),"first .4 perfect")
	u.parry_remaining=.800001
	verify(ParryController.perfect(u),"perfect just above .8")
	u.parry_remaining=.8
	verify(not ParryController.perfect(u) and ParryController.factor(u)==.4,"exact .8 is reduction")
	u.parry_remaining=0
	verify(ParryController.factor(u)==1,"window expired")
	verify(ParryController.success_chance(u,26)==1,"power equal defense")
	verify(is_equal_approx(ParryController.success_chance(u,52),pow(.5,1.2)),"power twice defense formula")
	verify(ParryController.success_chance(u,10000)==.08,"chance lower clamp")
	u.stance=CombatStance.CAUTIOUS
	verify(is_equal_approx(ParryController.success_chance(u,52),pow(.5,1.2)*1.25),"cautious success multiplier")
	u.stance=CombatStance.NORMAL
	u.parry_remaining=1.2
	u.shield_hp=100; u.shield_remaining=8
	u.invincible_remaining=1
	var outcome: DamageOutcome = battle.damage_resolver.resolve(enemy,u,16,{"critical":false,"attack_token":"same"})
	verify(outcome.parried and outcome.hp_damage==0 and u.current_hp==150,"successful block prevents damage")
	verify(u.shield_hp==100,"parry before shield")
	verify(enemy.current_hp==138,"reprisal rounds .65*16+.1*16=12")
	verify(enemy.stun_remaining==1.3 and enemy.knockback_velocity.length()>600,"attacker1.3 stun /640 momentum")
	verify(u.combat.counter and u.parry_counter_used,"warrior counter queued once")
	verify(battle.combat_waves.size()==1,"reprisal creates wave")
	var hp: float = enemy.current_hp
	battle.damage_resolver.resolve(enemy,u,16,{"critical":false,"attack_token":"same"})
	verify(enemy.current_hp==hp and battle.combat_waves.size()==1,"same contact/source no duplicate reprisal")
	battle.combat_waves[0].advance(battle,.32)
	verify(is_equal_approx(battle.units[2].stun_remaining,.7),"surrounding enemy .7 stun")
	verify(battle.units[2].knockback_velocity.length()>0,"wave pushes neighboring enemy")
	u.invincible_remaining=0;u.parry_remaining=.7
	outcome=battle.damage_resolver.resolve(enemy,u,20,{"critical":false,"impulse":0})
	verify(outcome.resolved_damage==8 and outcome.shield_absorbed==8 and outcome.hp_damage==0,"reduction60percent then shield")
	u.parry_remaining=1.2;u.stun_remaining=.5
	verify(not ParryController.perfect(u) and not ParryController.available(u),"stun disables parry")
	u.stun_remaining=0;u.parry_remaining=0;u.parry_cooldown=0;u.iron_defense_remaining=15
	verify(u.parry.start(u,enemy) and u.parry_cooldown==3,"iron actual parry uses3 seconds")
	u.parry_remaining=0;u.parry_cooldown=0;u.iron_defense_remaining=0
	verify(u.parry.start(u,enemy) and u.parry_cooldown==12,"after iron restore12")
	battle.free()
func damage_order() -> void:
	groups += 1
	var battle := fixture([1,1], [Vector2(300,400),Vector2(500,400)])
	var source: BattleUnit = battle.units[0]
	var target: BattleUnit = battle.units[1]
	var out: DamageOutcome = battle.damage_resolver.resolve(source,target,20,{"impulse":0})
	verify(out.hp_damage==20,"base18 does not reduce general damage")
	target.additional_defense=20
	out=battle.damage_resolver.resolve(source,target,20,{"impulse":0})
	verify(out.resolved_damage==17,"additional armor100/120")
	target.additional_defense=0;target.stance=CombatStance.COVER
	verify(is_equal_approx(CombatRules.armor(target),2.7) and is_equal_approx(CombatRules.defense(target),20.7),"cover15percent defense only extra armor")
	target.stance=CombatStance.RUSH
	out=battle.damage_resolver.resolve(source,target,10,{"impulse":0})
	verify(out.resolved_damage==12,"rush taken20percent")
	target.stance=CombatStance.NORMAL
	source.data.critical_chance=1
	out=battle.damage_resolver.resolve(source,target,15,{"impulse":0})
	verify(out.critical and out.attempted_damage==15 and out.resolved_damage==23,"crit1.5 JS round")
	source.data.critical_chance=0
	target.shield_hp=100;target.shield_remaining=8;target.invincible_remaining=2
	var hp: float = target.current_hp
	out=battle.damage_resolver.resolve(source,target,20)
	verify(out.invulnerable and out.hp_damage==0 and target.current_hp==hp and target.shield_hp==100 and target.knockback_velocity==Vector2.ZERO,"invincible before shield/momentum")
	target.invincible_remaining=0;target.current_hp=105
	out=battle.damage_resolver.resolve(source,target,120,{"impulse":0})
	verify(out.shield_absorbed==100 and out.hp_damage==20 and target.current_hp==85,"shield beforeHP")
	out=battle.damage_resolver.resolve(source,target,999,{"impulse":0})
	verify(out.hp_damage==85 and not target.alive,"actualHP capped death")
	verify(battle.damage_resolver.resolve(source,target,999).hp_damage==0,"dead cannot receive twice")
	battle.free()
	battle=fixture()
	source=battle.units[1];target=battle.units[0]
	target.parry_cooldown=0;target.defense_cooldown=0
	out=battle.damage_resolver.resolve(source,target,16,{"impulse":0})
	verify(out.resolved_damage in [0.0,8.0] and target.parry_cooldown==12,"warrior unique fallback separate basicparry")
	battle.free()
func stun_and_dodge() -> void:
	groups += 1
	var battle := fixture()
	var u: BattleUnit = battle.units[0]
	u.combat.cooldown=0;u.target=battle.units[1]
	verify(u.combat.start(u,u.target,battle.rng),"windup beforestun")
	StatusController.stun(u,.2)
	verify(u.combat_state==CombatController.State.IDLE and not u.combat.can_start(u,u.target),"stun cancels / blocks attacks")
	var position: Vector2=u.position
	battle.simulate(.1)
	verify(u.position==position and is_equal_approx(u.stun_remaining,.1),"stun prevents voluntarymove ticksSIM")
	battle.simulate(.1)
	verify(u.stun_remaining==0,"stun expiry")
	u.combat.cooldown=1000
	DodgeController.start(u,battle.units[1])
	position=u.position
	DodgeController.advance(u,.05)
	verify(u.position.distance_to(position)>0 and u.position.distance_to(position)<94,"dodge interpolates notteleports")
	DodgeController.advance(u,.17)
	verify(u.dodge_state.is_empty() and is_equal_approx(u.position.distance_to(position),94),"dodge94/.22 path")
	StatusController.stun(u,.5)
	KnockbackController.apply(u,Vector2(100,0),battle.units[1])
	position=u.position
	battle.simulate(.05)
	verify(u.position.x>position.x,"stun permits external momentum")
	battle.free()
func strike(battle: BattleManager,index: int,angle: float=0) -> AttackInstance:
	var unit: BattleUnit=battle.units[index]
	unit.combat_state=CombatController.State.ACTIVE
	unit.combat.attack_serial+=1
	unit.combat.aim_angle=angle
	return battle.spawn_melee_strike(unit,unit.data.attack_profile,CombatRules.attack(unit))
func melee_and_projectile() -> void:
	groups += 1
	var battle:=fixture([0,1],[Vector2(300,400),Vector2(380,400)])
	var attack: AttackInstance=strike(battle,0)
	attack.age=attack.duration*.5
	battle.advance_attacks(.001)
	verify(battle.units[1].current_hp==89 and attack.hit_ids.has(2),"blade hits normal target")
	var hp: float=battle.units[1].current_hp
	battle.advance_attacks(.02)
	verify(battle.units[1].current_hp==hp,"single strike dedup target")
	battle.free()
	battle=fixture([0,1],[Vector2(300,400),Vector2(600,400)])
	attack=strike(battle,0);attack.age=attack.duration*.5
	battle.advance_attacks(.01)
	verify(battle.units[1].current_hp==105,"outofreach blade misses")
	attack.shape=&"path";attack.start_position=Vector2(300,400);attack.end_position=Vector2(700,400);attack.path_width=20
	battle.advance_attacks(.01)
	verify(battle.units[1].current_hp==89,"path segment hit common shape")
	battle.free()
	battle=fixture([1,0],[Vector2(100,400),Vector2(300,400)])
	battle.spawn_projectile(battle.units[0],0)
	var arrow: BattleProjectile=battle.projectiles[0]
	arrow.velocity=Vector2(9000,0)
	battle.advance_attacks(.05)
	verify(battle.units[1].current_hp==135 and battle.projectiles.is_empty(),"fast swept body hit exactlyonce")
	battle.free()
	battle=fixture([1,0],[Vector2(100,400),Vector2(600,700)])
	battle.spawn_projectile(battle.units[0],0)
	battle.projectiles[0].lifetime=.01
	battle.advance_attacks(.02)
	verify(battle.projectiles.is_empty(),"projectile lifetime end")
	battle.spawn_projectile(battle.units[0],PI)
	battle.advance_attacks(.3)
	verify(battle.projectiles.is_empty(),"projectile boundary20 removal")
	battle.free()
func clashes() -> void:
	groups += 1
	var a:=AttackInstance.new();var b:=AttackInstance.new()
	a.attack_id=1;b.attack_id=2;a.power=13;b.power=10;a.damage=100
	verify(not ClashResolver.compare(a,b,0).breakthrough,"ratio1.3 inclusive draw")
	a.power=100
	verify(ClashResolver.compare(a,b,0).winner_id==1,"high power probabilistic breakthrough")
	verify(not ClashResolver.compare(a,b,.999).breakthrough,"higherpower can stilldraw")
	ClashResolver.weaken(a)
	verify(a.power==70 and a.damage==45,"power70 damage45 independently")
	verify(ClashResolver.win_chance(100,1)==.95,"win chance upper95percent")
	var battle:=fixture([0,0,1],[Vector2(300,400),Vector2(420,400),Vector2(360,500)])
	var m: AttackInstance=strike(battle,0,0);var n: AttackInstance=strike(battle,1,PI)
	m.age=m.duration*.5;n.age=n.duration*.5
	battle.advance_attacks(.001)
	verify(battle.combat_event_counts.get(&"clash",0)==1 and battle.melee_strikes.is_empty(),"melee-melee clash cancels both")
	verify(battle.units[0].stun_remaining==.3 and battle.units[1].stun_remaining==.3,"draw cancels and stuns owners")
	verify(battle.units[0].current_hp==147 and battle.units[1].current_hp==147,"clash reciprocal3HP")
	verify(battle.units[0].knockback_velocity.length()>0 and battle.units[1].knockback_velocity.length()>0,"clash recoil bothowners")
	battle.combat_waves[0].advance(battle,.32)
	verify(battle.units[2].stun_remaining>0 and battle.units[2].knockback_velocity.length()>0,"clash wave surrounding stun/force")
	battle.free()
	battle=fixture([1,1],[Vector2(300,400),Vector2(500,400)])
	battle.spawn_projectile(battle.units[0],0);battle.spawn_projectile(battle.units[1],PI)
	battle.projectiles[0].velocity=Vector2(9000,0);battle.projectiles[1].velocity=Vector2(-9000,0)
	battle.advance_attacks(.01)
	verify(battle.projectiles.is_empty() and battle.combat_event_counts.get(&"clash",0)==1,"relative sweep projectile-projectile")
	battle.free()
	battle=fixture([0,1],[Vector2(300,400),Vector2(450,400)])
	m=strike(battle,0);m.age=m.duration*.5
	battle.spawn_projectile(battle.units[1],PI)
	battle.projectiles[0].position=Vector2(370,400)
	battle.advance_attacks(.001)
	verify(battle.projectiles.is_empty() and battle.melee_strikes.is_empty(),"melee-projectile clash")
	battle.free()
func knockback_rules() -> void:
	groups += 1
	var battle:=fixture([0,0,1],[Vector2(300,400),Vector2(345,400),Vector2(700,700)])
	var u: BattleUnit=battle.units[0];var v: BattleUnit=battle.units[1]
	KnockbackController.apply(u,Vector2(300,0),v)
	verify(u.knockback_velocity==Vector2(300,0),"velocity accumulated")
	KnockbackController.collision(u,v)
	verify(v.knockback_velocity.x>0 and v.current_hp<150,"chaincollision transfers momentum andHP")
	var hp: float=v.current_hp
	KnockbackController.collision(u,v)
	verify(v.current_hp==hp,"paircooldown avoids duplicate collision")
	u.position=Vector2(300,300);v.position=Vector2(700,700)
	u.knockback_velocity=Vector2(100,0)
	KnockbackController.advance(u,.1)
	verify(is_equal_approx(u.knockback_velocity.x,100*exp(-.46)),"exponential4.6 damping")
	u.position=Vector2(770,100);u.knockback_velocity=Vector2(800,0)
	KnockbackController.advance(u,.01)
	verify(u.position.x<=772 and u.knockback_velocity.x<0,"wall boundary bounce-.24")
	verify(u.current_hp<150,"wall collision damage")
	KnockbackController.apply(u,Vector2(99999,99999))
	verify(u.knockback_velocity.length()<=1080.001 and u.position.is_finite(),"maximum1080 finite")
	verify(is_equal_approx(KnockbackController.attack_force(16,245,battle.units[0],battle.units[1]),245*2.1/sqrt(150.0/160)),"attack force formula")
	battle.free()
func perception() -> void:
	groups += 1
	var battle:=fixture([0,0,1],[Vector2(300,400),Vector2(380,400),Vector2(220,400)])
	var u: BattleUnit=battle.units[0];var v: BattleUnit=battle.units[1]
	u.facing=0
	verify(CombatPerception.in_attack_view(u,v.position),"front view")
	verify(not CombatPerception.in_attack_view(u,battle.units[2].position),"rear outside240")
	verify(CombatPerception.in_attack_view(u,u.position+Vector2.from_angle(TAU/3)*100),"120degree boundary")
	verify(CombatPerception.can_perceive(u,battle.units[2]),"canPerceive independent of facing")
	verify(not CombatPerception.can_see_attack(u,v,v.position,true),"hiddenlaunch notevadable")
	v.combat.cooldown=0;v.target=u
	v.parry_cooldown=1000
	verify(v.combat.start(v,u,battle.rng),"threatwindup starts")
	verify(ThreatResponseController.windup_threat(u)==v,"detect targetedwindup")
	u.facing=PI
	verify(ThreatResponseController.windup_threat(u)==null,"rearwindup unreadable")
	u.facing=0;u.parry_cooldown=0
	var chances: Dictionary=ThreatResponseController.chances(u)
	verify(is_equal_approx(chances.parry,.36) and is_equal_approx(chances.dodge,.12),"healthy probabilities")
	u.current_hp=15
	verify(ThreatResponseController.chances(u).parry>chances.parry,"lowHP prefers parry")
	u.current_hp=150
	u.threat_response.read_attacks["2:1"]={"at":0.0,"roll":0.0,"done":false}
	u.threat_response.advance(u)
	verify(u.threat_response.response.get("mode")==&"parry","windup selects parry reaction")
	u.threat_response.response.clear();u.parry_remaining=0;u.parry_cooldown=1000
	u.threat_response.read_attacks["2:1"]={"at":0.0,"roll":0.0,"done":false}
	u.threat_response.advance(u)
	verify(u.threat_response.response.get("mode")==&"dodge","unreadyparry chooses steering dodge")
	var pos: Vector2=u.position
	u.threat_response.movement(u,.05)
	verify(u.position!=pos,"response dodge steers")
	u.taunted_member_id="target3";u.taunted_until=10
	battle.units[2].source_member_id="target3"
	verify(u.target_selector.select_target(u,battle.units)==battle.units[2],"taunt above nearest")
	battle.free()
func persistence_fixture() -> Dictionary:
	var guild:=GuildManager.new()
	for type in [0,1,0,1]: guild.create_member(type)
	var room:=RoomState.new()
	room.add_enemy("persist_w",BattleManager.WARRIOR,Vector2(650,250))
	room.add_enemy("persist_a",BattleManager.ARCHER,Vector2(700,600))
	var plan:=DeploymentPlan.new(guild)
	plan.place(guild.all_members()[0].member_id,Vector2(100,250))
	plan.place(guild.all_members()[1].member_id,Vector2(100,600))
	var battle:=phase7_manager()
	battle.auto_start=false;battle.common_combat_enabled=true
	host.root.add_child(battle);battle.set_physics_process(false)
	var session:=RoomBattleSession.new(guild,room)
	verify(session.start(plan,battle,101),"common room session starts")
	for unit in battle.units: unit.combat.cooldown=10000;unit.defense_cooldown=1000
	return {"guild":guild,"room":room,"plan":plan,"battle":battle,"session":session,"tp":battle.turning}
func all_state(unit: BattleUnit) -> Array:
	return [unit.position,unit.velocity,unit.knockback_velocity,unit.current_hp,unit.stun_remaining,unit.invincible_remaining,unit.shield_remaining,unit.iron_defense_remaining,unit.parry_remaining,unit.parry_cooldown,unit.combat_state,unit.combat.phase_time,unit.combat.cooldown,unit.strategy_dash.duplicate(true)]
func clock_and_persistence() -> void:
	groups+=1
	var f:=persistence_fixture()
	f.battle.clock.elapsed=12
	f.battle.simulate(2)
	verify(f.tp.is_paused(),"common TP enters hold")
	var u: BattleUnit=f.battle.units[0];var enemy: BattleUnit=f.battle.units[2]
	u.stun_remaining=.7;u.invincible_remaining=2;u.shield_hp=100;u.shield_remaining=8;u.iron_defense_remaining=15;u.parry_cooldown=3;u.parry_remaining=.6
	u.knockback_velocity=Vector2(400,0)
	u.combat_state=CombatController.State.WINDUP;u.combat.phase_time=.13
	# A projectile already in flight is also frozen during hold.
	f.battle.clock.resume()
	f.battle.spawn_projectile(f.battle.units[1],0)
	var held_strike:AttackInstance=strike(f.battle,2,0)
	var held_wave:CombatWave=f.battle.spawn_combat_wave(&"parry",enemy.position,[enemy.battle_id],220,.7,470,[enemy.battle_id])
	f.battle.clock.state=BattleClock.State.TURNING_PAUSED
	var attack_state:Array=[held_strike.age,held_strike.life,held_wave.age,held_wave.life]
	var before:Array=all_state(u)
	var arrow:BattleProjectile=f.battle.projectiles[0]
	var arrow_state:Array=[arrow.position,arrow.lifetime,arrow.attack_instance.age]
	var simtime:float=f.battle.clock.elapsed
	f.battle.simulate(10)
	verify(all_state(u)==before,"hold freezes all unit timers/momentum/windup")
	verify([arrow.position,arrow.lifetime,arrow.attack_instance.age]==arrow_state,"hold freezes projectile")
	verify([held_strike.age,held_strike.life,held_wave.age,held_wave.life]==attack_state,"hold freezes active strike andwave")
	verify(f.battle.clock.elapsed==simtime and f.tp.current.remaining_real_time==30,"hold freezes simulation but advancesreal")
	verify(f.battle.damage_resolver.resolve(enemy,u,20).hp_damage==0,"hold rejects damage")
	var charge:StrategyCardInstance=f.guild.state.give_strategy_card(&"charge")
	verify(StrategyCardExecutor.apply(f.tp,charge.card_id,u.source_member_id,"stuncharge").code==StrategyCardExecutor.Code.NO_EFFECT and charge.ready_floor==0,"stun blocks charge without consuming")
	f.tp.current.enemy_plans.clear()
	verify(f.tp.resolve(),"manual resume common")
	f.battle.simulate(.1)
	verify(u.stun_remaining<.7 and u.shield_remaining<8 and u.parry_cooldown<3,"resume decreasesSIM timers")
	verify(u.combat_state==CombatController.State.IDLE,"stun removes preexisting windup onresume")
	# Set whitelist state at a real retreat boundary and verify detached snapshots.
	f.battle.clock.elapsed=20
	u.current_hp=91;u.stun_remaining=.6;u.invincible_remaining=1.5;u.parry_remaining=.2;u.parry_counter_used=true;u.parry_pulse_used=true
	u.character_specific_state={"test_counter":3}
	enemy.position=Vector2(580,270);enemy.current_hp=73;enemy.shield_hp=55;enemy.shield_remaining=4;enemy.iron_defense_remaining=6;enemy.parry_cooldown=2;enemy.parry_remaining=.7;enemy.parry_counter_used=true;enemy.parry_pulse_used=true;enemy.stun_remaining=.9;enemy.invincible_remaining=3;enemy.facing=-2.1
	enemy.character_specific_state={"test_counter":7}
	verify(f.session.request_retreat(),"20seconds retreat with common states")
	var member:GuildMemberState=f.guild.all_members()[0]
	verify(member.current_hp==91,"retreat memberHP preserve")
	verify(member.character_specific_state.stun==.6 and member.character_specific_state.invincible==1.5,"ally whitelist state stored")
	var saved:EnemyRoomState=f.room.enemy_state["persist_w"]
	verify(saved.current_hp==73 and saved.position==Vector2(580,270),"enemyHP position stored")
	verify(saved.persistent_state.parryCounterUsed and saved.persistent_state.parryPulseUsed and saved.persistent_state.test_counter==7,"boolean/opaque states copied")
	verify(saved.persistent_state.shieldHp==55 and saved.persistent_state.stun==.9 and saved.persistent_state.face==-2.1,"shield/stun/facing persisted")
	verify(not saved.persistent_state.has("target") and not saved.persistent_state.has("knockback_velocity") and not saved.persistent_state.has("attack"),"no frameexecution state persisted")
	verify(UnitStateCodec.is_pure_data(saved.persistent_state),"pure persisted data")
	verify(f.session.settlement.apply_room(f.battle.result,f.guild,f.room)==BattleSettlement.Status.ALREADY_SETTLED,"settlement still once")
	var frozen:Array=all_state(u)
	f.battle.simulate(10)
	verify(all_state(u)==frozen,"result freezes newstates")
	f.battle.free()
	var next:=phase7_manager();next.auto_start=false;next.common_combat_enabled=true
	host.root.add_child(next);next.set_physics_process(false)
	var plan:=DeploymentPlan.new(f.guild)
	plan.place(member.member_id,Vector2(200,250))
	var session:=RoomBattleSession.new(f.guild,f.room)
	verify(session.start(plan,next,105),"same room retry common")
	var restored:BattleUnit=EnemyPlanExecutor.find_enemy(next,"persist_w")
	verify(restored.current_hp==73 and restored.position==Vector2(580,270),"retry enemyHP/position")
	verify(restored.shield_hp==55 and restored.shield_remaining==4 and restored.iron_defense_remaining==6 and restored.parry_cooldown==2 and restored.parry_remaining==.7,"retry defensive timers")
	verify(restored.stun_remaining==.9 and restored.invincible_remaining==3 and restored.parry_counter_used and restored.parry_pulse_used and restored.facing==-2.1,"retry stun/invincible/flags/negativeface")
	verify(next.units[0].current_hp==91 and next.units[0].position==Vector2(200,250),"retryallyHP/newdeployment")
	verify(restored.knockback_velocity==Vector2.ZERO and next.melee_strikes.is_empty() and next.projectiles.is_empty(),"retry resets transient physics")
	verify(next.turning.next_at==12 and next.turning.current==null,"retry resetsTP12")
	next.finish_with_reason(BattleEndReason.Value.RETREAT,-1)
	next.free()
func failed_parry_and_rear() -> void:
	groups+=1
	var battle:=fixture([1,1],[Vector2(300,400),Vector2(380,400)])
	var u:BattleUnit=battle.units[0];var enemy:BattleUnit=battle.units[1]
	u.parry_remaining=1.2;u.shield_hp=100;u.shield_remaining=8
	u.parry.rolls["failed"]=false
	var out:DamageOutcome=battle.damage_resolver.resolve(enemy,u,20,{"attack_token":"failed","critical":false,"impulse":0})
	verify(not out.parried and out.resolved_damage==8 and u.shield_hp==92 and u.parry_remaining==.8,"failed perfect transitions reduction then shield")
	u.parry_remaining=0;u.facing=PI;u.evade_remaining=.24;u.defense_cooldown=0
	out=battle.damage_resolver.resolve(enemy,u,10,{"critical":false,"impulse":0})
	verify(not out.avoided and u.shield_hp==82,"rear attack ignores evade window")
	u.facing=0
	out=battle.damage_resolver.resolve(enemy,u,10,{"critical":false,"impulse":0,"hidden_launch":true})
	verify(not out.avoided and u.shield_hp==72,"hidden launch ignores evade")
	u.parry_remaining=1.2;u.parry.rolls["rear"]=true;u.facing=PI
	out=battle.damage_resolver.resolve(enemy,u,10,{"attack_token":"rear","critical":false,"impulse":0})
	verify(out.parried and u.shield_hp==72,"alreadyactive parry blocksrear asweb")
	battle.free()
func natural_common_battles() -> void:
	groups+=1
	for seed_value in [3,29,101]:
		for types in [[0,0],[0,1],[1,1],[0,0,1,0,0,1]]:
			var battle:=phase7_manager();battle.auto_start=false;battle.common_combat_enabled=true
			host.root.add_child(battle);battle.set_physics_process(false)
			var entries:Array[Dictionary]=[]
			entries.assign(BattleManager.default_placements() if types.size()==6 else [{"data":BattleManager.WARRIOR if types[0]==0 else BattleManager.ARCHER,"team":0,"position":Vector2(180,400)},{"data":BattleManager.WARRIOR if types[1]==0 else BattleManager.ARCHER,"team":1,"position":Vector2(620,400)}])
			var counts:Dictionary={"finished":0,"deaths":{}}
			battle.battle_finished.connect(func(_r): counts.finished+=1)
			battle.unit_died.connect(func(u,_s): counts.deaths[u.battle_id]=counts.deaths.get(u.battle_id,0)+1)
			verify(battle.start_battle(entries,seed_value),"natural common starts")
			for frame in range(180*60):
				if battle.finished: break
				battle.simulate(1.0/60)
				if frame%60==0:
					for unit in battle.units:
						verify(unit.position.is_finite() and unit.velocity.is_finite() and unit.knockback_velocity.is_finite(),"natural finite runtime")
						verify(unit.position.x>=28 and unit.position.x<=772 and unit.position.y>=28 and unit.position.y<=772,"natural bounds")
						verify(unit.current_hp>=0 and unit.current_hp<=unit.data.max_hp and unit.alive==(unit.current_hp>0),"naturalHP/death")
						if not unit.alive: verify(unit.combat_state==CombatController.State.IDLE,"natural deadattack canceled")
			verify(battle.finished and counts.finished==1,"natural common battle finishesonce")
			for count in counts.deaths.values(): verify(count==1,"natural unique death")
			var before:Array=[]
			for unit in battle.units: before.append(all_state(unit))
			battle.simulate(5)
			var after:Array=[]
			for unit in battle.units: after.append(all_state(unit))
			verify(before==after and battle.melee_strikes.is_empty() and battle.projectiles.is_empty(),"commonpostresult freeze")
			print("PASS common battle ",types," seed=",seed_value," sim=",snappedf(battle.clock.elapsed,.01)," events=",battle.combat_event_counts)
			battle.free()

func advanced_physical_and_cards() -> void:
	groups+=1
	var battle:=fixture([0,1,1],[Vector2(300,400),Vector2(650,650),Vector2(350,400)])
	battle.units[2].team=0
	var melee:AttackInstance=strike(battle,0)
	melee.age=melee.duration*.5
	battle.spawn_projectile(battle.units[1],PI)
	var arrow:BattleProjectile=battle.projectiles[0]
	arrow.position=Vector2(350,400)
	battle.advance_attacks(.001)
	verify(battle.combat_event_counts.get(&"clash",0)==1 and battle.units[2].current_hp==105,"clash wins exacttime tie before bodyhit")
	battle.free()
	battle=fixture([0,1],[Vector2(300,400),Vector2(650,650)])
	melee=strike(battle,0)
	battle.spawn_projectile(battle.units[1],PI)
	var projectile:AttackInstance=battle.projectiles[0].attack_instance
	projectile.power=100;projectile.damage=100
	# Fixed seeded stochastic branch; compare result against original roll law.
	battle.rng.seed=1
	var decision:Dictionary=PhysicalAttackSystem.clash(battle,melee,projectile,Vector2(360,400))
	verify(decision.breakthrough and decision.winner_id==projectile.attack_id,"actualphysical highpower breaks through")
	verify(projectile.life>0 and projectile.power==70 and projectile.damage==45 and melee.life==0,"actual survivor separatelyweakened")
	verify(battle.units[0].stun_remaining==.25 and battle.units[1].stun_remaining==0,"weak melee only getsloss stun")
	battle.free()
	battle=fixture()
	var u:BattleUnit=battle.units[0]
	u.parry_remaining=1.2;u.shield_hp=100;u.shield_remaining=8
	var hp:float=u.current_hp
	verify(KnockbackController.collision_damage(u,300,battle.units[1])==0 and u.shield_hp==100,"perfect collision factor zero before shield")
	u.parry_remaining=.5
	verify(KnockbackController.collision_damage(u,300,battle.units[1])==0 and u.shield_hp==96 and u.current_hp==hp,"latecollision factor .4 then shield")
	u.parry_remaining=0;u.invincible_remaining=2
	verify(KnockbackController.collision_damage(u,500,battle.units[1])==0 and u.shield_hp==96,"invincible collision shield untouched")
	verify(u.parry!=battle.units[1].parry,"runtime controllers independent")
	u.parry.rolls["independent"]=false
	verify(not battle.units[1].parry.rolls.has("independent"),"contact cache notshared")
	battle.free()
	battle=fixture([0,0,0,0],[Vector2(300,400),Vector2(380,400),Vector2(350,480),Vector2(320,330)])
	u=battle.units[0]
	var risk:Dictionary=AreaEvaluator.evaluate(u,u.position)
	verify(risk.crowd>0 and risk.hazard==0 and risk.safe.is_empty(),"real crowd risk nofake abilityzones")
	u.shield_hp=100;u.shield_remaining=8
	verify(is_equal_approx(AreaEvaluator.evaluate(u,u.position).crowd,risk.crowd*.7),"shield reduces perceivedcrowd pressure")
	u.invincible_remaining=2
	verify(is_equal_approx(AreaEvaluator.evaluate(u,u.position).crowd,risk.crowd*.1),"invincibility reducespressure")
	u.stance=CombatStance.RUSH
	verify(CombatRules.attack(u)==20,"rush+25percentATK")
	u.stance=CombatStance.CAUTIOUS
	verify(is_equal_approx(CombatRules.attack(u),12.8),"cautious-20percentATK")
	u.stance=CombatStance.COVER
	verify(is_equal_approx(CombatRules.attack(u),13.6),"cover-15percentATK")
	battle.free()
	battle=fixture([0,1],[Vector2(300,400),Vector2(600,400)])
	u=battle.units[0]
	u.facing=0
	battle.spawn_projectile(battle.units[1],PI)
	arrow=battle.projectiles[0]
	arrow.position=Vector2(450,400);arrow.velocity=Vector2(-470,0)
	u.threat_response.projectile_notices[arrow.projectile_id]=0.0
	verify(not u.threat_response.projectile_threat(u).is_empty(),"visible inbound projectile prediction")
	u.stance=CombatStance.RUSH
	verify(u.threat_response.projectile_threat(u).is_empty(),"rush shorter .28 warninghorizon")
	u.stance=CombatStance.CAUTIOUS
	verify(not u.threat_response.projectile_threat(u).is_empty(),"cautious .56 warninghorizon")
	arrow.position=Vector2(150,400);arrow.velocity=Vector2(470,0)
	verify(u.threat_response.projectile_threat(u).is_empty(),"rear projectile givesnowarning")
	battle.free()
	battle=fixture([1,1],[Vector2(300,400),Vector2(500,400)])
	battle.clock.elapsed=130
	verify(battle.damage_resolver.resolve(battle.units[0],battle.units[1],10,{"impulse":0}).resolved_damage==20,"post60seconds escalation130 doublesdamage")
	battle.clock.elapsed=0
	battle.units[0].source_member_id="member_source";battle.units[1].source_member_id="member_target"
	verify(battle.damage_resolver.resolve(battle.units[0],battle.units[1],20,{"impulse":0}).resolved_damage==20,"no energy fatigue on member damage")
	battle.free()
	var f:=persistence_fixture()
	f.battle.clock.elapsed=12;f.battle.simulate(2)
	f.tp.current.enemy_plans.clear()
	u=f.battle.units[0]
	var iron:StrategyCardInstance=f.guild.state.give_strategy_card(&"iron")
	var evade:StrategyCardInstance=f.guild.state.give_strategy_card(&"evade")
	verify(StrategyCardExecutor.apply(f.tp,iron.card_id,u.source_member_id,"commoniron").code==StrategyCardExecutor.Code.OK,"real ironcard applies")
	var runner:BattleUnit=f.battle.units[1]
	var at:Vector2=runner.position
	verify(StrategyCardExecutor.apply(f.tp,evade.card_id,runner.source_member_id,"commonevade").code==StrategyCardExecutor.Code.OK,"real pendingevade applies")
	f.tp.current.remaining_real_time=.1
	f.battle.simulate(.1)
	verify(not f.tp.is_paused() and runner.position!=at and runner.command_retreat_until>f.battle.clock.elapsed,"automaticresolve executes evade then simulation")
	verify(u.parry.start(u,f.battle.units[2]) and u.parry_cooldown==3,"card to actual ironparry3")
	StrategyEffects.advance(u,15)
	verify(u.parry.start(u,f.battle.units[2]) and u.parry_cooldown==12,"expiredcard restoresactual cooldown")
	var stunned_enemy:BattleUnit=f.battle.units[2]
	stunned_enemy.stun_remaining=.6;stunned_enemy.ultimate_gauge=37
	var special:=EnemyTurningPlan.new()
	special.plan_id="stunned_special";special.source_enemy_id=stunned_enemy.source_enemy_id;special.plan_type=EnemyTurningPlan.OVERCHARGE
	special.metadata=EnemyTurningPlan.special_metadata(stunned_enemy.data.type_id)
	var readiness:Dictionary=EnemyPlanExecutor.execute(special,f.battle)
	verify(stunned_enemy.ultimate_gauge==37 and stunned_enemy.character_specific_state.strategyUltimateReady,"stun denies forecastcharge but keeps webreadiness")
	verify(not readiness.is_empty() and StatusController.skill_charge_blocked(stunned_enemy),"futureability hook must defer stunnedactor")
	f.battle.finish_with_reason(BattleEndReason.Value.RETREAT,-1)
	f.battle.free()

func run(tree: SceneTree) -> void:
	host=tree
	parry_rules()
	damage_order()
	stun_and_dodge()
	melee_and_projectile()
	clashes()
	knockback_rules()
	perception()
	failed_parry_and_rear()
	clock_and_persistence()
	advanced_physical_and_cards()
	natural_common_battles()
	print("PHASE 7 RESULT: ",groups," groups; ",checks," checks; ",failures," failures")

func phase7_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.full_characters_enabled = false
	return manager
