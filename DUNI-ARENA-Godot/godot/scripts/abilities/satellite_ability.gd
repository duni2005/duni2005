extends CharacterAbility
var wander_clock: float = 0
func choose_target(u,enemies: Array):
	enemies=enemies.filter(func(e):return u.position.distance_to(e.position)<480*u.combat_scale() and CharacterLifecycle.cc_remaining(e)>0)
	enemies.sort_custom(func(a,b):return CharacterLifecycle.cc_remaining(a)>CharacterLifecycle.cc_remaining(b) if CharacterLifecycle.cc_remaining(a)!=CharacterLifecycle.cc_remaining(b) else u.position.distance_to(a.position)<u.position.distance_to(b.position))
	return enemies[0] if not enemies.is_empty() else null
func on_damage(u,_actual: float,_options) -> void:
	if u.alive:
		var bursts: Array=u.character_specific_state.get("satelliteBursts",[]);bursts.append({"remaining":.16,"damage":CombatRules.attack(u)*.2});u.set_state("satelliteBursts",bursts)
func tick(u,dt: float) -> void:
	var bursts: Array=u.character_specific_state.get("satelliteBursts",[])
	for s in bursts.duplicate():
		s.remaining=float(s.remaining)-dt
		if float(s.remaining)<=0:salvo(u,4,float(s.damage));bursts.erase(s)
func modify_movement(u,_t,dt: float) -> bool:
	wander_clock-=dt
	if u.position.distance_to(u.brain.goal)<45 or wander_clock<=0:
		wander_clock=u.battle.rng.randf_range(1.2,3)
		u.brain.goal=Vector2(u.battle.rng.randf_range(65,735),u.battle.rng.randf_range(65,735))
	var dir: Vector2=(u.brain.goal-u.position).normalized();u.brain.steer(u,dir-dir.orthogonal()*sin(u.battle.clock.elapsed*2.2+u.brain.phase)*.3,dt,.75 if u.combat_state==CombatController.State.WINDUP else 1)
	if u.combat_state==CombatController.State.IDLE:u.facing=u.brain.heading.angle()
	return true
func missile(u,t,damage: float,enhanced: bool=false,spread: float=0) -> void:
	var speed: float=500 if enhanced else 430;var point: Vector2=t.position+t.velocity*u.position.distance_to(t.position)/speed*.18
	shoot(u,(point-u.position).angle()+spread,damage,{"kind":"missile","enhanced":enhanced,"speed":speed,"life":2.6,"radius":24 if enhanced else 18,"offset":34,"impulse":280 if enhanced else 150,"target":t.actor_id(),"guide":.45})
	u.set_state("shotsFired",u.state_value("shotsFired")+1)
func salvo(u,count: int,damage: float,enhanced: bool=false) -> void:
	var targets: Array=u.enemies().filter(func(e):return e.position.distance_to(u.position)<(520 if enhanced else 480)*u.combat_scale())
	if targets.is_empty():return
	var offset: int=u.battle.rng.randi_range(0,targets.size()-1)
	for i in range(count):missile(u,targets[(i+offset)%targets.size()],damage,enhanced,(i-(count-1)/2.0)*minf(.12,.6/maxf(1,count-1)))
func release_basic(u) -> void:
	if u.combat.attack_target!=null:missile(u,u.combat.attack_target,CombatRules.attack(u)*(1+minf(3,CharacterLifecycle.cc_remaining(u.combat.attack_target))*.4))
func can_ultimate(u,_t) -> bool:return u.enemies().any(func(e):return e.position.distance_to(u.position)<520)
func release_ultimate(u,_a,_dt: float) -> bool:salvo(u,3+u.friends().size(),CombatRules.attack(u)*1.8,true);return true
func requires_initiative() -> bool:return false
func debug_state(u) -> String:return " / ".join(["satelliteBursts"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
