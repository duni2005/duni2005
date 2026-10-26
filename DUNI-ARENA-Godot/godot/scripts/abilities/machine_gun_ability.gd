extends CharacterAbility
func on_spawn(u) -> void:
	if not u.character_specific_state.has("ammo"):u.set_state("ammo",20)
func movement_rate(u) -> float:return .4 if u.state_value("reloadRemaining")>0 else 1
func tick(u,dt: float) -> void:
	if not u.machine_dash.is_empty():
		var goal: Vector2=CharacterPersistence.vector(u.machine_dash.goal)
		if dash_to(u,goal,850,dt):u.machine_dash.clear()
	if u.state_value("reloadRemaining")>0:
		u.set_state("reloadRemaining",maxf(0,u.state_value("reloadRemaining")-dt))
		if u.state_value("reloadRemaining")==0:refill(u)
func refill(u) -> void:u.set_state("ammo",20);u.set_state("reloadRemaining",0);u.combat.cooldown=0;u.brain.disengage_until=0;u.brain.attack_decision.clear();u.brain.next_initiative_at=u.battle.clock.elapsed+u.battle.rng.randf_range(.15,.65)
func can_attack(u,_t) -> bool:return u.state_value("ammo")>0 and u.state_value("reloadRemaining")<=0
func release_basic(u) -> void:
	if u.state_value("ammo")<=0:return
	var r: RandomNumberGenerator=u.battle.rng
	shoot(u,u.combat.aim_angle+.3*(r.randf_range(-1,1)*.75+r.randf_range(-1,1)*.25),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"machineBullet","speed":4200,"radius":14,"offset":55,"life":.35,"impulse":115})
	u.set_state("ammo",u.state_value("ammo")-1);u.set_state("shotsFired",u.state_value("shotsFired")+1);u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*30
	if u.state_value("ammo")==0:u.set_state("reloadRemaining",4)
func attack_tick(u,_dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE:
		var target=u.combat.attack_target
		if target==null or not target.alive or not CombatPerception.can_perceive(u,target):target=nearest(u,u.enemies())
		if target==null:u.combat.cancel(u);return true
		u.combat.attack_target=target
		u.combat.aim_angle+=clampf(wrapf(u.combat.aim_direction(u,target)-u.combat.aim_angle,-PI,PI),-4*_dt,4*_dt)
		u.facing=u.combat.aim_angle
	if u.combat_state==CombatController.State.ACTIVE:
		var next: float=float(u.combat.attack_metadata.get("next_round",.105))
		while u.state_value("ammo")>0 and u.combat.phase_time+1e-8>=next:release_basic(u);next+=.105
		u.combat.attack_metadata.next_round=next
		if u.state_value("ammo")<=0:u.combat_state=CombatController.State.RECOVERY;u.combat.phase_time=0
	return false
func modify_movement(u,t,dt: float) -> bool:
	if t==null:return false
	var d: float=u.position.distance_to(t.position);var dir: Vector2=(t.position-u.position).normalized()
	var movement: Vector2=dir*clampf((d-(440 if u.state_value("reloadRemaining")>0 else 365))/85,-1.15,.9)-dir.orthogonal()*u.brain.side*(.05 if u.combat_state==CombatController.State.ACTIVE else .3)
	var near=nearest(u,u.enemies());var gap: float=u.position.distance_to(near.position) if near!=null else INF
	if gap<220:movement+=(u.position-near.position).normalized()*(220-gap)/80
	u.brain.steer(u,movement,dt,.35 if u.combat_state==CombatController.State.WINDUP else .55 if u.combat_state==CombatController.State.ACTIVE else 1);return true
func can_ultimate(u,_t) -> bool:return u.state_value("ammo")<=0 and u.state_value("reloadRemaining")>.4
func release_ultimate(u,_a,_dt: float) -> bool:
	var goal: Vector2=u.position;var best: float=-INF
	for i in range(24):
		var point: Vector2=(u.position+Vector2.from_angle(i*PI/12)*260).clamp(Vector2(38,38),Vector2(762,762))
		if point.distance_to(u.position)<85:continue
		var near: float=300;var crowd: int=0;var crossings: int=0
		for e in u.enemies():
			near=minf(near,point.distance_to(e.position))
			if point.distance_to(e.position)<190:crowd+=1
			if PhysicalAttackSystem.point_distance(e.position,u.position,point)<50*e.combat_scale():crossings+=1
		var score: float=near-crowd*170-crossings*100-u.battle.zones.risk(u,point)*130+u.battle.rng.randf_range(-10,10)
		if score>best:goal=point;best=score
	refill(u);u.machine_dash={"goal":CharacterPersistence.point(goal)};u.threat_response.response.clear();u.dodge_state.clear();u.evade_remaining=0;u.knockback_velocity=Vector2.ZERO;return true
func defensive_ultimate() -> bool:return true
func can_cast(u) -> bool:return u.state_value("ammo")<=0 and u.state_value("reloadRemaining")>.4
func debug_state(u) -> String:return " / ".join(["ammo", "reloadRemaining"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
func track_aim(u,_desired: float,_dt: float) -> float:return u.combat.aim_angle
