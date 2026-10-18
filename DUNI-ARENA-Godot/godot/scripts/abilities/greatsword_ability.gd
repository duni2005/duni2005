extends CharacterAbility
func can_attack(u,_t) -> bool:return u.lost_sword.is_empty()
func profile(u) -> AttackData:
	var p: AttackData=super.profile(u);var boost: float=1+u.state_value("guardStacks")*.06;p.reach*=boost;return p
func on_attack_start(u) -> void:u.combat.attack_metadata.boost=1+u.state_value("guardStacks")*.06;u.set_state("guardStacks",0)
func movement_rate(u) -> float:return 1+u.state_value("guardStacks")*.15
func on_damage(u,_actual: float,options: Dictionary) -> void:
	if not u.alive or u.stun_remaining>0 or options.get("parry_recoil",false) or options.get("clash_recoil",false) or options.get("mirror_shard",false):return
	if u.state_value("guardRemaining")>0:u.set_state("guardStacks",u.state_value("guardStacks")+1)
	elif u.character_specific_state.get("guardReady",true):
		u.set_state("guardRemaining",4);u.set_state("guardReady",false);u.set_state("guardStacks",u.state_value("guardStacks")+1);u.guard_anchor=u.position;u.combat.cancel(u);u.ultimate.cast.clear();u.knockback_velocity=Vector2.ZERO
func passive_tick(u,dt: float) -> void:
	if u.lost_sword.is_empty():return
	var s: Dictionary=u.lost_sword
	if float(s.flight)>0:
		s.point=CharacterPersistence.point((CharacterPersistence.vector(s.point)+Vector2(s.vx,s.vy)*minf(dt,float(s.flight))).clamp(Vector2(35,35),Vector2(765,765)));s.flight=maxf(0,float(s.flight)-dt);s.rotation+=dt*13
	if float(s.flight)<=0 and u.stun_remaining<=0 and u.state_value("guardRemaining")<=0 and u.position.distance_to(CharacterPersistence.vector(s.point))<34:
		u.set_state("pickupTime",u.state_value("pickupTime")+dt)
		if u.state_value("pickupTime")>=.25:u.lost_sword.clear();u.set_state("pickupTime",0);u.combat.cooldown=minf(u.combat.cooldown,.3)
	else:u.set_state("pickupTime",0)
func modify_movement(u,_target,dt: float) -> bool:
	if u.lost_sword.is_empty():return false
	var point: Vector2=CharacterPersistence.vector(u.lost_sword.point);var direction: Vector2=(point-u.position).normalized();var incoming: Dictionary=u.threat_response.projectile_threat(u)
	if not incoming.is_empty() and u.position.distance_to(point)>85:direction-=incoming.arrow.velocity.normalized().orthogonal()*u.brain.side*.4
	u.brain.steer(u,direction,dt);return true
func release_basic(u) -> void:
	u.set_state("guardReady",true)
	if u.battle.rng.randf()<.15:
		var angle: float=u.battle.rng.randf_range(-PI,PI);var dir: Vector2=Vector2.from_angle(angle)*480
		u.lost_sword={"point":CharacterPersistence.point(u.position),"vx":dir.x,"vy":dir.y,"flight":.6,"rotation":angle,"sizeBoost":u.combat.attack_metadata.get("boost",1),"scale":u.combat_scale()};return
	melee(u,CombatRules.attack(u)*float(u.combat.attack_metadata.get("boost",1)));u.knockback_velocity+=Vector2.from_angle(u.combat.aim_angle)*140
func can_ultimate(u,t) -> bool:return t!=null and u.lost_sword.is_empty() and (u.position.distance_to(t.position)<430 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	u.combat.aim_angle=a.angle;melee(u,CombatRules.attack(u)*1.5,{"reach":190,"cone":.7,"active":.25,"impulse":500,"independent":true})
	shoot(u,a.angle,CombatRules.attack(u)*2.7,{"kind":"greatImpact","speed":640,"radius":48,"life":1.5,"offset":48,"piercing":true,"ultimate":true,"impulse":540});return true
func can_cast(u) -> bool:return u.lost_sword.is_empty()
func debug_state(u) -> String:return " / ".join(["guardStacks", "guardRemaining"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
