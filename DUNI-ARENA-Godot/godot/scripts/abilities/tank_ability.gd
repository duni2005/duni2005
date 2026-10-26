extends CharacterAbility
func incoming_factor(u,source,options) -> float:
	if options.get("duel_result",false) or options.get("parry_recoil",false) or options.get("clash_recoil",false) or options.get("mirror_shard",false):return 1
	var origin: Vector2=options.get("attack_origin",source.position)
	return 1.75 if origin.distance_to(u.position)>.001 and cos((origin-u.position).angle()-u.facing)<-.5 else 1
func can_attack(u,t) -> bool:return t!=null and absf(wrapf(u.combat.aim_direction(u,t)-u.facing,-PI,PI))<=.16
func steer_override(u,move: Vector2,dt: float,factor: float) -> bool:
	var from: Vector2=u.position;var length: float=move.length()
	if length>.01:
		var heading: float=u.state_value("tankHeadingAngle",u.facing);heading+=clampf(wrapf(move.angle()-heading,-PI,PI),-.65*dt,.65*dt);u.set_state("tankHeadingAngle",heading)
		var alignment: float=maxf(0,cos(move.angle()-heading));u.brain.heading=Vector2.from_angle(heading)*minf(1,length)*alignment
		u.position=MovementController.clamp_position(from+u.brain.heading*u.move_speed*minf(1.15,factor)*dt)
	else:u.brain.heading=Vector2.ZERO
	u.velocity=(u.position-from)/dt;return true
func modify_movement(u,t,dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE:u.brain.heading=Vector2.ZERO;u.velocity=Vector2.ZERO;return true
	if t==null:
		if u.position.distance_to(u.brain.goal)<55:u.brain.goal=Vector2(u.battle.rng.randf_range(90,710),u.battle.rng.randf_range(90,710))
		return steer_override(u,(u.brain.goal-u.position).normalized(),dt,.6)
	var dir: Vector2=(t.position-u.position).normalized();var d: float=u.position.distance_to(t.position)
	var desired: float=220 if u.stance==CombatStance.RUSH else 390 if u.battle.clock.elapsed<u.brain.disengage_until else 330
	var move: Vector2=dir*clampf((d-desired)/110,-1,1)-dir.orthogonal()*u.brain.side*.4
	for other in u.enemies()+u.friends():
		if u.position.distance_to(other.position)<80:move+=(u.position-other.position).normalized()*.5
	if u.position.x<60:move.x+=1
	if u.position.x>740:move.x-=1
	if u.position.y<60:move.y+=1
	if u.position.y>740:move.y-=1
	return steer_override(u,move,dt,movement_rate(u))
func release_basic(u) -> void:
	var enhanced: bool=u.character_specific_state.get("tankFlameReady",false);u.set_state("tankFlameReady",false)
	shoot(u,u.facing,UnitStatTable.raw(u,&"enhanced" if enhanced else &"basic"),{"dmg":&"enhanced" if enhanced else &"basic","kind":"tankShell","speed":620,"life":2,"radius":25,"offset":64,"blast_radius":(160 if enhanced else 130)*u.combat_scale(),"impulse":560 if enhanced else 440,"enhanced":enhanced})
	KnockbackController.apply(u,-Vector2.from_angle(u.facing)*140,u);u.set_state("shotsFired",u.state_value("shotsFired")+1)
func projectile_hit(u,p,_t) -> bool:
	if p.kind!="tankShell":return false
	ProjectileRules.explode(p);return true
func can_ultimate(u,t) -> bool:return t!=null and not u.character_specific_state.get("tankFlameReady",false)
func release_ultimate(u,_a,_dt: float) -> bool:u.set_state("tankFlameReady",true);return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false

func windup_track_fraction(_u) -> float:return .75
func track_aim(u,desired: float,dt: float) -> float:
	u.facing+=clampf(wrapf(desired-u.facing,-PI,PI),-.75*dt,.75*dt)
	return u.facing
func can_cast(u) -> bool:return not u.character_specific_state.get("tankFlameReady",false)
func debug_state(u) -> String:return " / ".join(["tankFlameReady"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
