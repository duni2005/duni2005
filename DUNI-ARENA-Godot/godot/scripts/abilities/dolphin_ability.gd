extends CharacterAbility
var wander_clock: float = 0
func movement_rate(u) -> float:return minf(2,1+u.state_value("dolphinStacks")*.04)
func on_damage(u,actual: float,_options: Dictionary) -> void:
	u.set_state("damageTakenTotal",u.state_value("damageTakenTotal")+actual);u.set_state("dolphinStacks",maxf(u.state_value("dolphinStacks"),floorf((u.state_value("damageTakenTotal")+1e-7)/(u.max_hp*.1))))
func modify_movement(u,t,dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE:return true
	wander_clock-=dt
	if u.position.distance_to(u.brain.goal)<45 or wander_clock<=0:
		wander_clock=u.battle.rng.randf_range(0.55,1.35)
		u.brain.goal=Vector2(u.battle.rng.randf_range(70,730),u.battle.rng.randf_range(70,730))
	var goal: Vector2=t.position+t.velocity*.2 if t!=null and (u.position.distance_to(t.position)<235 and u.combat.cooldown<.4 or u.battle.clock.elapsed<u.brain.commit_until) else u.brain.goal
	var direction: Vector2=(goal-u.position).normalized();direction-=direction.orthogonal()*sin(u.battle.clock.elapsed*5+u.brain.phase)*.3
	var incoming: Dictionary=u.threat_response.projectile_threat(u)
	if not incoming.is_empty():direction=direction*.5-incoming.arrow.velocity.normalized().orthogonal()*u.brain.side*.65
	u.brain.steer(u,direction,dt);return true
func release_basic(u) -> void:
	melee(u,CombatRules.attack(u)*(1.15 if u.combat.attack_metadata.get("ultimate",false) else 1),{"reach":64,"cone":.18,"headbutt":true})
	u.knockback_velocity=Vector2.ZERO
func attack_tick(u,dt: float) -> bool:
	if u.combat_state==CombatController.State.ACTIVE and not u.combat.attack_metadata.get("landed",false):
		var speed: float=(780 if u.combat.attack_metadata.get("ultimate",false) else 560)*movement_rate(u)
		dash_to(u,u.position+Vector2.from_angle(u.combat.aim_angle)*1000,speed,dt)
	return false
func melee_hit(u,attack,t,out) -> void:
	if out.hp_damage>0 and t.alive and t.invincible_remaining<=0:t.set_state("curseTime",6)
	attack.life=0;u.combat.attack_metadata.landed=true;u.combat_state=CombatController.State.RECOVERY;u.combat.phase_time=0
func can_ultimate(u,t) -> bool:return t!=null and (u.enemies().filter(func(e):return u.position.distance_to(e.position)<300*u.combat_scale()).size()>=2 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	if not a.has("targets"):a.targets=u.enemies().filter(func(e):return u.position.distance_to(e.position)<=300*u.combat_scale()).map(func(e):return e.actor_id());a.next=0
	if u.combat_state!=CombatController.State.IDLE:return false
	while int(a.next)<a.targets.size():
		var t=u.battle.find_actor(a.targets[a.next]);a.next+=1
		if t!=null and t.alive:
			u.combat.force_start(u,t);u.combat.attack_metadata.ultimate=true;u.combat.cooldown=.4;u.combat.active_profile.windup=.14;u.combat.active_profile.active=clampf(u.position.distance_to(t.position)/780+.12,.28,1.2);u.combat.active_profile.recovery=.12;return false
	return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:return observer.position.distance_to(u.position)<350
func attack_cooldown(u,rng: RandomNumberGenerator) -> float:return u.data.attack_interval+rng.randf_range(.15,.35)
func cast_area(u,a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":300*u.combat_scale()}
func debug_state(u) -> String:return " / ".join(["dolphinStacks", "curseTime"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
