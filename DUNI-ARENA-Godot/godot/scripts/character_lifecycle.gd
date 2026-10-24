class_name CharacterLifecycle
extends RefCounted
## Shared actor relationships/cargo lifecycle. No Scene references in state snapshots.
const TIMERS = ["heal","dash","revealTime","curseTime","guardRemaining","shadowTime","guardianUltTime","mirrorReflectTime","paladinBlessingTime"]
static func advance(battle,dt: float) -> void:
	for u in battle.units:
		if not u.alive:continue
		for key in TIMERS:
			if u.character_specific_state.has(key):u.set_state(key,maxf(0,u.state_value(key)-dt))
		EquipmentCombatEffects.advance(u,dt)
		u.ability.passive_tick(u,dt)
		if not u.puppet_control.is_empty():
			u.puppet_control.remaining=maxf(0,float(u.puppet_control.remaining)-dt)
			if float(u.puppet_control.remaining)<=1e-8:end_control(u)
		if not u.frog_action.is_empty():advance_frog(u,dt)
		if not u.duel.is_empty() and u.duel.master==u.actor_id():advance_duel(u,dt)
		if not u.hero_rescue.is_empty():advance_rescue(u,dt)
		if u.state_value("guardRemaining")>0:u.position=u.guard_anchor;u.knockback_velocity=Vector2.ZERO
static func cc_remaining(u) -> float:
	var remaining: float=maxf(u.stun_remaining,maxf(0,u.taunted_until-u.battle.clock.elapsed))
	if not u.duel.is_empty():remaining=maxf(remaining,2.2-float(u.duel.time))
	for z in u.battle.zones.entries:
		var source=u.battle.find_actor(z.source)
		if z.kind=="blackhole" and source!=null and source.team!=u.team and u.position.distance_to(CharacterPersistence.vector(z.point))<float(z.radius) and u.invincible_remaining<=0:remaining=maxf(remaining,float(z.life))
	for key in ["rootTime","bindTime","snareTime"]:remaining=maxf(remaining,u.state_value(key))
	remaining=maxf(remaining,u.state_value("rootedUntil")-u.battle.clock.elapsed)
	return remaining
static func protected(u) -> bool:
	var hero=u.battle.find_actor(u.hero_rescue_owner)
	return u.frog_rescue_guard or (not u.frog_carrier.is_empty() and u.battle.find_actor(u.frog_carrier)!=null and u.battle.find_actor(u.frog_carrier).frog_action.get("phase","")=="hold") or (hero!=null and hero.alive and hero.hero_rescue.get("target","")==u.actor_id() and hero.team==u.team)
static func intercept_lethal(u,hp_damage: float,executed: bool=false) -> bool:
	if not u.alive or u.unavailable() or (not executed and hp_damage<u.current_hp):return false
	if EquipmentCombatEffects.phoenix(u):return true
	var heroes: Array=u.battle.units.filter(func(v):return v!=u and v.alive and v.team==u.team and v.data.type_id==17 and not v.hero_rescue_used)
	heroes.sort_custom(func(a,b):return u.position.distance_to(a.position)<u.position.distance_to(b.position))
	if not heroes.is_empty():
		var hero=heroes[0]
		interrupt(hero);release_carried(hero);hero.stun_remaining=0;hero.stun_revision+=1;hero.hero_rescue_used=true
		hero.hero_rescue={"target":u.actor_id(),"time":0.0};u.hero_rescue_owner=hero.actor_id();hero.combat.cancel(hero);hero.ultimate.cast.clear();hero.parry_remaining=0;hero.knockback_velocity=Vector2.ZERO
		return true
	var frogs: Array=u.friends().filter(func(v):return v.data.type_id==24 and v.ultimate_gauge>=100 and v.stun_remaining<=0 and v.frog_action.is_empty() and not v.unavailable() and v.duel.is_empty() and v.strategy_dash.is_empty() and v.position.distance_to(u.position)<=1100*v.combat_scale())
	frogs.sort_custom(func(a,b):return u.position.distance_to(a.position)<u.position.distance_to(b.position))
	if not frogs.is_empty() and capture(frogs[0],u,true):
		var frog=frogs[0];frog.ultimate_gauge=0;frog.set_state("ultReadyAge",0);frog.set_state("ultUses",frog.state_value("ultUses")+1);return true
	return false
static func advance_rescue(hero,dt: float) -> void:
	var friend=hero.battle.find_actor(hero.hero_rescue.target)
	if friend==null or not friend.alive or friend.team!=hero.team:hero.hero_rescue.clear();return
	hero.hero_rescue.time=float(hero.hero_rescue.time)+dt
	if not CharacterAbility.dash_to(hero,friend.position,1050,dt,65*hero.combat_scale()):
		if float(hero.hero_rescue.time)>2:friend.hero_rescue_owner="";hero.hero_rescue.clear()
		return
	friend.shield_hp=maxf(friend.shield_hp,60);friend.shield_remaining=maxf(friend.shield_remaining,10)
	for enemy in hero.enemies(false):
		if enemy.position.distance_to(friend.position)>220*hero.combat_scale()+24*enemy.combat_scale():continue
		var out: DamageOutcome=hero.battle.damage_resolver.resolve(hero,enemy,CombatRules.attack(hero)*1.6,{"critical":true,"impulse":650,"attack_origin":friend.position,"visible_hazard":true,"attack_token":hero.actor_id()+":rescue"})
		if out.hp_damage>0 and enemy.alive:StatusController.stun(enemy,2)
	friend.hero_rescue_owner="";hero.hero_rescue.clear();hero.combat.cooldown=maxf(hero.combat.cooldown,.6);hero.brain.disengage_until=hero.battle.clock.elapsed+.7
	hero.battle.emit_combat_event(&"hero_rescue",friend.position,{"hero":hero.actor_id()})
static func begin_duel(master,target,ultimate: bool=false) -> bool:
	if not master.alive or not target.alive or master.team==target.team or master.stun_remaining>0 or target.stun_remaining>0 or not master.duel.is_empty() or not target.duel.is_empty() or protected(target) or not master.hero_rescue.is_empty():return false
	var d: Dictionary={"master":master.actor_id(),"target":target.actor_id(),"ultimate":ultimate,"time":0.0,"resolved":false}
	for u in [master,target]:
		u.duel=d;u.combat.cancel(u);u.ultimate.cast.clear();u.evade_remaining=0;u.knockback_velocity=Vector2.ZERO;u.velocity=Vector2.ZERO;u.set_state("revealTime",3)
	return true
static func cancel_duel(u) -> void:
	if u.duel.is_empty():return
	var d: Dictionary=u.duel.duplicate()
	for id in [d.master,d.target]:
		var actor=u.battle.find_actor(id)
		if actor!=null:actor.duel={};actor.combat.cooldown=maxf(actor.combat.cooldown,.8)
static func advance_duel(master,dt: float) -> void:
	var d: Dictionary=master.duel
	var target=master.battle.find_actor(d.target)
	if target==null or not target.alive or master.stun_remaining>0 or target.stun_remaining>0:cancel_duel(master);return
	d.time=float(d.time)+dt
	if not d.resolved and float(d.time)>=1.7:
		d.resolved=true;master.set_state("duelRounds",master.state_value("duelRounds")+1)
		if target.data.type_id==8:target.set_state("duelRounds",target.state_value("duelRounds")+1)
		var fm: bool=int(master.state_value("duelRounds"))%3==0
		var ft: bool=target.data.type_id==8 and int(target.state_value("duelRounds"))%3==0
		var ms: int=master.battle.rng.randi_range(0,2);var ts: int=master.battle.rng.randi_range(0,2)
		if fm and not ft:ms=(ts+1)%3
		if ft and not fm:ts=(ms+1)%3
		if fm and ft:CharacterAbility.restore_hp(master,master.max_hp*.05,master);CharacterAbility.restore_hp(target,target.max_hp*.05,target)
		elif ms!=ts:
			var winner=master if (ms-ts+3)%3==1 else target;var loser=target if winner==master else master
			CharacterAbility.restore_hp(winner,winner.max_hp*.05,winner)
			master.battle.damage_resolver.resolve(winner,loser,loser.max_hp*(.5 if d.ultimate else .35),{"duel_result":true,"critical":false,"impulse":0})
	if float(d.time)>=2.2:cancel_duel(master)
static func capture(frog,v,rescue: bool=false) -> bool:
	if not frog.alive or not v.alive or not frog.frog_action.is_empty() or v.unavailable() or protected(v) or not v.hero_rescue.is_empty() or (not v.duel.is_empty() and not rescue):return false
	interrupt(v);v.combat.cancel(v);v.ultimate.cast.clear();v.frog_carrier=frog.actor_id();v.frog_rescue_guard=rescue;v.knockback_velocity=Vector2.ZERO
	frog.combat.cancel(frog);frog.ultimate.cast.clear();frog.parry_remaining=0;frog.dodge_state.clear();frog.frog_hop.clear();frog.knockback_velocity=Vector2.ZERO
	frog.frog_action={"target":v.actor_id(),"rescue":rescue,"phase":"prepare" if rescue else "pull","time":0.0,"pull":0.0,"hold":0.0};return true
static func clear_cargo(v) -> void:
	v.frog_carrier="";v.frog_flight=0;v.frog_rescue_guard=false;v.knockback_velocity=Vector2.ZERO;v.velocity=Vector2.ZERO
static func release_carried(u,heal: bool=false) -> void:
	if not u.frog_carrier.is_empty():
		var carrier=u.battle.find_actor(u.frog_carrier)
		if carrier!=null:release_action(carrier,heal)
	if u.frog_flight!=0:
		for p in u.battle.projectiles:
			if p.projectile_id==u.frog_flight:finish_body(p,false)
static func release_action(frog,heal: bool=false) -> void:
	if frog.frog_action.is_empty():return
	var a: Dictionary=frog.frog_action;var victim=frog.battle.find_actor(a.target);frog.frog_action={}
	if victim!=null and victim.frog_carrier==frog.actor_id():
		if a.phase=="hold":victim.position=MovementController.clamp_position(frog.position+Vector2.from_angle(frog.facing)*42)
		clear_cargo(victim)
		if a.rescue:
			victim.invincible_remaining=maxf(victim.invincible_remaining,.4)
			if heal:CharacterAbility.restore_hp(victim,victim.max_hp*.1,frog)
static func advance_frog(frog,dt: float) -> void:
	var a: Dictionary=frog.frog_action;var victim=frog.battle.find_actor(a.target)
	if victim==null or not victim.alive or frog.stun_remaining>0 or victim.frog_carrier!=frog.actor_id():release_action(frog,true);return
	a.time=float(a.time)+dt;frog.velocity=Vector2.ZERO;victim.velocity=Vector2.ZERO;frog.knockback_velocity=Vector2.ZERO;victim.knockback_velocity=Vector2.ZERO
	if a.phase=="prepare":
		if float(a.time)>=.2:a.phase="pull"
		return
	if a.phase=="pull":
		a.pull=float(a.pull)+dt
		CharacterAbility.dash_to(victim,frog.position,760,dt)
		if victim.position.distance_to(frog.position)<8:a.phase="hold";a.hold=0.0
		elif float(a.pull)>1.5:release_action(frog,true)
	else:
		victim.position=frog.position;a.hold=float(a.hold)+dt
		if float(a.hold)>=(.35 if a.rescue else .65):spit(frog,victim,a.rescue)
static func safest(u) -> Vector2:
	var best: Vector2=u.position;var score: float=-INF
	for x in range(75,726,65):
		for y in range(75,726,65):
			var p:=Vector2(x,y);var near: float=400
			for enemy in u.enemies(false):near=minf(near,p.distance_to(enemy.position))
			var value: float=near-u.battle.zones.risk(u,p)*500-u.position.distance_to(p)*.06
			for friend in u.friends():
				if p.distance_to(friend.position)<60:value-=100
			if value>score:score=value;best=p
	return best
static func spit(frog,v,rescue: bool) -> void:
	var enemy=CharacterAbility.nearest(frog,frog.enemies().filter(func(e):return e!=v and not e.unavailable()))
	var goal: Vector2=safest(v) if rescue else enemy.position if enemy!=null else Vector2(400,400)
	var angle: float=(goal-frog.position).angle();var speed: float=850 if rescue else 650
	var travel: float=maxf(1,frog.position.distance_to(goal)) if rescue else maxf(150,frog.position.distance_to(goal)+100 if enemy!=null else 230)
	var p: BattleProjectile=CharacterAbility.shoot(frog,angle,CombatRules.attack(frog)*(1+floorf(v.max_hp/60)*.1),{"kind":"frogBody","offset":0,"speed":speed,"radius":36*v.combat_scale()/frog.combat_scale(),"life":minf(1.3 if rescue else 1.15,travel/speed),"cargo":v.actor_id(),"rescue":rescue,"visual_scale":v.combat_scale(),"impulse":390})
	v.frog_carrier="";v.frog_flight=p.projectile_id;v.frog_rescue_guard=rescue;frog.frog_action={}
	if rescue:CharacterAbility.restore_hp(v,v.max_hp*.1,frog)
	frog.combat.cooldown=maxf(frog.combat.cooldown,frog.data.attack_interval)
static func finish_body(p,damage: bool=true) -> void:
	if p.metadata.get("resolved",false):return
	p.metadata.resolved=true;p.live=false;p.attack_instance.life=0
	var v=p.source.battle.find_actor(p.metadata.get("cargo",""))
	if v==null or v.frog_flight!=p.projectile_id:return
	v.position=MovementController.clamp_position(p.position);clear_cargo(v)
	if p.metadata.get("rescue",false):v.invincible_remaining=maxf(v.invincible_remaining,.4)
	elif damage and v.alive:p.source.battle.damage_resolver.resolve(p.source,v,p.damage*.7,{"critical":true,"impulse":150,"attack_origin":p.position,"visible_hazard":true})
	v.combat.cooldown=maxf(v.combat.cooldown,.4)
static func release_cargo(battle) -> void:
	for u in battle.units:release_action(u)
	for p in battle.projectiles:
		if p.kind=="frogBody":finish_body(p,false)
	for u in battle.units:
		if u.unavailable():clear_cargo(u)
static func control(u,source,duration: float=7) -> bool:
	if not u.alive or u.team==source.team or u.unavailable() or u.invincible_remaining>0 or u.frog_rescue_guard:return false
	var original: int=u.puppet_control.get("original_team",u.team)
	u.puppet_control={"owner":source.actor_id(),"remaining":duration,"original_team":original,"team":source.team}
	u.team=source.team;reset_intent(u);u.combat.cooldown=maxf(u.combat.cooldown,.25);return true
static func reset_intent(u) -> void:
	release_action(u,true);cancel_duel(u);u.combat.cancel(u);u.ultimate.cast.clear();u.hero_rescue.clear();u.machine_dash.clear();u.dodge_state.clear();u.strategy_dash.clear();u.frog_hop.clear();u.parry_remaining=0;u.evade_remaining=0;u.target=null;u.brain=BattleBrain.new();u.brain.initialize(u.battle.rng);u.brain.next_initiative_at=u.battle.clock.elapsed+u.battle.rng.randf_range(.15,.65);u.knockback_velocity=Vector2.ZERO
	u.taunted_member_id="";u.taunted_until=0;u.focus_member_id="";u.focus_until=0;u.command_retreat_until=0;u.set_state("strategyUltimateReady",false)
static func end_control(u) -> void:
	if u.puppet_control.is_empty():return
	u.team=int(u.puppet_control.original_team);u.puppet_control.clear();reset_intent(u)
static func interrupt(u) -> void:
	u.frog_hop.clear();release_action(u,true);cancel_duel(u);u.machine_dash.clear()
	if u.ultimate.cast.get("dashing",false) and u.data.type_id in [14,17]:u.ultimate.cast.clear()
static func on_death(u) -> void:
	release_action(u,true);release_carried(u);cancel_duel(u);u.hero_rescue.clear();u.ultimate.cast.clear();u.set_state("mirrorReflectTime",0);end_control(u)

static func bind_cover(u) -> void:
	var friends: Array=u.friends()
	friends.sort_custom(func(a,b):return u.deployment_position.distance_to(a.deployment_position)<u.deployment_position.distance_to(b.deployment_position))
	u.cover_actor_id=friends[0].actor_id() if not friends.is_empty() else ""
