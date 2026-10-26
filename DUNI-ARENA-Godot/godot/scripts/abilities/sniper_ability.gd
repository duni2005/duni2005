extends CharacterAbility
var corner_clock: float = 0
var corner_point: Vector2 = Vector2.ZERO
func can_attack(u,t) -> bool:
	return t!=null and (u.position.distance_to(corner(u))<65 or u.battle.clock.elapsed-u.brain.last_attack>9 and u.position.distance_to(t.position)>180)
func corner(u) -> Vector2:
	if corner_clock>0 and corner_point!=Vector2.ZERO:return corner_point
	var points: Array[Vector2]=[Vector2(65,65),Vector2(735,65),Vector2(65,735),Vector2(735,735)]
	var best: Vector2=points[0];var score: float=-INF
	for p in points:
		var value: float=450
		for e in u.enemies():value=minf(value,p.distance_to(e.position))
		value-=u.enemies().filter(func(e):return p.distance_to(e.position)<240).size()*180+u.position.distance_to(p)*.12+u.friends().filter(func(a):return p.distance_to(a.position)<65).size()*45
		if value>score:score=value;best=p
	corner_point=best;corner_clock=u.battle.rng.randf_range(.8,1.4);return best
func modify_movement(u,_t,dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE:u.velocity=Vector2.ZERO;u.brain.heading=Vector2.ZERO;return true
	corner_clock-=dt
	# In its corner the sniper keeps a slow sway rather than freezing between shots.
	var goal: Vector2=corner(u);var direction: Vector2=(goal-u.position).normalized() if goal.distance_to(u.position)>22 else Vector2.from_angle(u.battle.clock.elapsed*.9+u.brain.phase)*.3
	var close: bool=false
	for e in u.enemies():
		var d: float=u.position.distance_to(e.position)
		if d<180:direction+=(u.position-e.position).normalized()*.9;close=true
	u.brain.steer(u,direction,dt,1.12 if close else 1);return true
func round_fire(u,burst: bool=false) -> void:
	var spread: float=.018 if burst else PI/72
	var angle: float=u.combat.aim_angle+u.battle.rng.randf_range(-spread,spread)
	shoot(u,angle,UnitStatTable.raw(u,&"ult" if burst else &"basic"),{"dmg":&"ult" if burst else &"basic","kind":"sniper","speed":4700,"life":.45,"radius":25,"offset":43,"piercing":true,"impulse":350})
	u.knockback_velocity-=Vector2.from_angle(angle)*230
func release_basic(u) -> void:
	var burst: bool=u.character_specific_state.get("sniperBurstReady",false)
	round_fire(u,burst)
	if burst:u.set_state("sniperBurstReady",false);u.combat.attack_metadata={"burst":2,"next":.16};u.combat.active_profile.active=.5
func attack_tick(u,_dt: float) -> bool:
	if u.combat_state==CombatController.State.ACTIVE and u.combat.attack_metadata.get("burst",0)>0 and u.combat.phase_time>=float(u.combat.attack_metadata.next):
		round_fire(u,true);u.combat.attack_metadata.burst-=1;u.combat.attack_metadata.next+=.16
	return false
func can_ultimate(u,t) -> bool:return t!=null and not u.character_specific_state.get("sniperBurstReady",false)
func release_ultimate(u,_a,_dt: float) -> bool:u.set_state("sniperBurstReady",true);return true
func unique_defense(u,source,_amount: float,can_evade: bool,options: Dictionary) -> Dictionary:
	if can_evade and options.get("melee",false) and u.position.distance_to(source.position)<=125 and u.battle.rng.randf()<.3:
		KnockbackController.apply(source,(source.position-u.position).normalized()*980,u);StatusController.stun(source,.24);u.combat.cancel(u);u.combat.cooldown=minf(u.combat.cooldown,.6);return {"avoid":true}
	return {}
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func windup_track_fraction(_u) -> float:return .9
func debug_state(u) -> String:return " / ".join(["sniperBurstReady"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
