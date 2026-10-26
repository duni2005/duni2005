extends CharacterAbility
func on_spawn(u) -> void:
	if not u.character_specific_state.has("ammo"):u.set_state("ammo",2)
func tick(u,dt: float) -> void:
	var remaining: float=u.state_value("reloadRemaining")
	if remaining>0:
		remaining=maxf(0,remaining-dt);u.set_state("reloadRemaining",remaining)
		if remaining<=0:u.set_state("ammo",2);u.brain.disengage_until=0;u.brain.attack_decision.clear()
func can_attack(u,t) -> bool:return t!=null and u.state_value("ammo")>0 and u.state_value("reloadRemaining")<=0 and (u.position.distance_to(t.position)<=140 or u.battle.clock.elapsed-u.brain.last_attack>=8)
func modify_movement(u,t,dt: float) -> bool:
	if t==null:return false
	var d: float=u.position.distance_to(t.position);var dir: Vector2=(t.position-u.position).normalized()
	var radial: float=(-1 if d<300 else .1) if u.state_value("reloadRemaining")>0 else 1 if d>75 else -.25 if d<48 else .2
	u.brain.steer(u,dir*radial-dir.orthogonal()*(u.brain.side*.45+sin(u.battle.clock.elapsed*2.3+u.brain.phase)*.4),dt,.45 if u.combat_state!=CombatController.State.IDLE else 1);return true
func release_basic(u) -> void:
	u.set_state("ammo",u.state_value("ammo")-1);u.set_state("shotsFired",u.state_value("shotsFired")+1)
	for i in range(7):shoot(u,u.combat.aim_angle+(i-3)*.125+u.battle.rng.randf_range(-.012,.012),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"pellet","speed":720,"life":.46,"radius":22,"offset":43,"impulse":115})
	u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*340
	if u.state_value("ammo")==0:u.set_state("reloadRemaining",4)
func projectile_hit(u,p,t) -> bool:
	if p.kind!="pellet":return false
	var damage: float=p.damage*clampf(1-p.position.distance_to(p.attack_instance.start_position)/340,.25,1)
	u.battle.damage_resolver.resolve(u,t,damage,p.attack_instance.options(t.position-p.velocity*.008));p.live=false;return true
func debug_state(u) -> String:return " / ".join(["ammo", "reloadRemaining"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
