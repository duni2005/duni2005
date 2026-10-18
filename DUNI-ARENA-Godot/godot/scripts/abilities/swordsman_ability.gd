extends ComboAbility
func attack_factor(u) -> float:return 1.3 if not u.friends().any(func(a):return a.position.distance_to(u.position)<180) else 1
func target_priority(_u,t,seen: Array) -> float:return 1 if seen.any(func(e):return e!=t and e.position.distance_to(t.position)<=180) else 0
func next_profile(u,index: int) -> AttackData:
	var p: AttackData=u.data.attack_profile.duplicate();p.windup=.36 if index==2 else .2;p.active=.24 if index==2 else .22;p.reach=205 if index==2 else 122;p.cone=PI if index==2 else 1.4;p.impulse=450 if index==2 else 110;return p
func release_basic(u) -> void:
	var index: int=int(u.combat.attack_metadata.get("combo",0));melee(u,CombatRules.attack(u)*(3 if index==2 else 1.1 if index==1 else 1),{"sword_combo":true})
func attack_tick(u,dt: float) -> bool:
	if u.combat_state==CombatController.State.ACTIVE:dash_to(u,u.position+Vector2.from_angle(u.combat.aim_angle)*1000,100 if int(u.combat.attack_metadata.get("combo",0))==2 else 210,dt)
	return false
func modify_movement(u,_t,_dt: float) -> bool:return u.combat_state!=CombatController.State.IDLE
func on_damage(u,_actual: float,_options) -> void:
	if u.combat_state!=CombatController.State.IDLE:
		u.combat.cancel(u)
		for s in u.battle.melee_strikes:
			if s.source_battle_id==u.battle_id and not s.metadata.get("independent",false):s.life=0
		u.combat.cooldown=maxf(u.combat.cooldown,.65);u.brain.disengage_until=u.battle.clock.elapsed+u.battle.rng.randf_range(.35,.8)
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<560
func release_ultimate(u,a,dt: float) -> bool:
	if not a.get("dashing",false):
		var t=u.battle.find_actor(a.target);var goal: Vector2=t.position if t!=null and t.alive else CharacterPersistence.vector(a.point)
		a.angle=(goal-u.position).angle();var dir: Vector2=Vector2.from_angle(a.angle);var length: float=maxf(300,u.position.distance_to(goal)+150)
		for enemy in u.enemies():
			var diff: Vector2=enemy.position-u.position;var along: float=diff.dot(dir)
			if along>0 and along<620 and absf(diff.cross(dir))<95*u.combat_scale()+27*enemy.combat_scale():length=maxf(length,along+27*enemy.combat_scale()+100)
		var wall_x: float=INF if absf(dir.x)<1e-8 else ((772 if dir.x>0 else 28)-u.position.x)/dir.x
		var wall_y: float=INF if absf(dir.y)<1e-8 else ((772 if dir.y>0 else 28)-u.position.y)/dir.y
		a.remaining=maxf(0,minf(minf(650,length),minf(wall_x,wall_y)));a.origin=CharacterPersistence.point(u.position);a.dashing=true
	var step: float=dt if a.get("advanced",false) else minf(dt,maxf(0,float(a.t)-float(a.duration)));a.advanced=true
	var before: Vector2=u.position;dash_to(u,u.position+Vector2.from_angle(a.angle)*float(a.remaining),2200,step)
	a.remaining=maxf(0,float(a.remaining)-before.distance_to(u.position))
	if float(a.remaining)>.001:return false
	u.combat.aim_angle=a.angle
	var strike: AttackInstance=melee(u,CombatRules.attack(u)*3.6,{"reach":115,"cone":0,"active":.1,"impulse":540,"independent":true})
	if strike!=null:strike.shape=&"path";strike.path_width=95*u.combat_scale();strike.start_position=CharacterPersistence.vector(a.origin);strike.end_position=u.position;strike.metadata.dash_hits=a.get("dashHits",[])
	return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:return PhysicalAttackSystem.point_distance(observer.position,CharacterPersistence.vector(a.get("origin",CharacterPersistence.point(u.position))),CharacterPersistence.vector(a.get("dashEnd",a.point)))<120 and observer.position.distance_to(u.position)<750
func attack_cooldown(u,rng: RandomNumberGenerator) -> float:return 2.1+u.data.attack_interval*rng.randf_range(.35,.65)
func cast_area(u,a: Dictionary) -> Dictionary:return {"shape":"path","from":a.get("origin",CharacterPersistence.point(u.position)),"to":a.get("dashEnd",a.point),"radius":95*u.combat_scale()}
func debug_state(u) -> String:return "Combo %d / dash %s" % [int(u.combat.attack_metadata.get("combo",0)),u.is_dashing()]
