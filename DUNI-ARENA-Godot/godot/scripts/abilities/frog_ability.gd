extends CharacterAbility
func on_spawn(u) -> void:u.frog_hop_wait=u.battle.rng.randf_range(.4,1.6)
func choose_target(u,enemies: Array):
	enemies.sort_custom(func(a,b):return a.current_hp>b.current_hp if a.current_hp!=b.current_hp else u.position.distance_to(a.position)<u.position.distance_to(b.position));return enemies[0] if not enemies.is_empty() else null
func modify_movement(u,t,dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty() or not u.frog_action.is_empty() or ParryController.perfect(u) or u.threat_response.response.get("mode",&"")==&"parry":u.frog_hop.clear();u.velocity=Vector2.ZERO;return true
	if u.frog_hop.is_empty():
		u.velocity=Vector2.ZERO;u.frog_hop_wait-=dt
		if u.frog_hop_wait>0:return true
		var r: RandomNumberGenerator=u.battle.rng;var goal:=Vector2(r.randf_range(75,725),r.randf_range(75,725))
		var near=nearest(u,u.enemies())
		if near!=null and (u.position.distance_to(near.position)<130 or u.current_hp/u.max_hp<.35 and u.position.distance_to(near.position)<200):goal=u.position+Vector2.from_angle((u.position-near.position).angle()+r.randf_range(-.5,.5))*210
		elif t!=null and (u.position.distance_to(t.position)>u.data.attack_range*.9 or u.stance==CombatStance.RUSH):goal=u.position+Vector2.from_angle((t.position-u.position).angle()+r.randf_range(-.45,.45))*200
		var offset: Vector2=(goal-u.position).normalized()*minf(u.position.distance_to(goal),r.randf_range(85,155))
		var end: Vector2=(u.position+offset).clamp(Vector2(35,35),Vector2(765,765))
		u.frog_hop={"dx":end.x-u.position.x,"dy":end.y-u.position.y,"duration":clampf(.5*105/u.move_speed,.28,.65),"t":0.0}
	var h: Dictionary=u.frog_hop;var before: Vector2=u.position;var step: float=minf(dt,float(h.duration)-float(h.t));h.t=float(h.t)+step
	u.position=MovementController.clamp_position(u.position+Vector2(h.dx,h.dy)*step/float(h.duration));u.velocity=(u.position-before)/dt
	if float(h.t)>=float(h.duration)-1e-8:u.frog_hop.clear();u.frog_hop_wait=u.battle.rng.randf_range(.4,1.6);u.velocity=Vector2.ZERO
	return true
func release_basic(u) -> void:
	u.frog_hop.clear();shoot(u,u.combat.aim_angle,CombatRules.attack(u),{"kind":"frogTongue","speed":900,"radius":21,"offset":30,"life":u.data.attack_profile.reach*u.combat_scale()/900})
func projectile_hit(u,p,t) -> bool:
	if p.kind=="frogTongue":
		p.live=false
		if u.alive and u.stun_remaining<=0 and u.frog_action.is_empty() and not t.unavailable() and t.invincible_remaining<=0 and t.duel.is_empty() and CombatPerception.can_perceive(u,t):
			var reflected: Dictionary=t.ability.pre_damage(t,u,p.power,p.attack_instance.options(p.position))
			if reflected.is_empty() and not t.parry.try_block(t,u,p.power,p.projectile_id) and not (t.evade_remaining>0 and CombatPerception.can_see_attack(t,u,p.position,p.hidden_launch)):CharacterLifecycle.capture(u,t)
		return true
	if p.kind=="frogBody":
		if not p.metadata.get("rescue",false):u.battle.damage_resolver.resolve(u,t,p.damage,{"critical":true,"impulse":390,"attack_origin":p.position,"visible_hazard":true});CharacterLifecycle.finish_body(p)
		return true
	return false
func can_ultimate(_u,_t) -> bool:return false # Reactive lethal rescue, never automatic at gauge100.
func debug_state(u) -> String:return "Cargo %s" % u.frog_action.get("phase","none")
func reactive_ultimate() -> bool:return true
