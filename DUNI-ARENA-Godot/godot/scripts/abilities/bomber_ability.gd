extends CharacterAbility
func on_damage(u,_actual: float,_options) -> void:
	if u.alive and u.current_hp<=u.max_hp*.2:u.set_state("bomberRush",true)
func can_attack(u,_t) -> bool:return not u.character_specific_state.get("bomberRush",false)
func tick(u,dt: float) -> void:
	if u.current_hp<=u.max_hp*.2:u.set_state("bomberRush",true)
	if not u.character_specific_state.get("bomberRush",false):return
	u.combat.cancel(u);u.ultimate.cast.clear();u.dodge_state.clear();u.evade_remaining=0;u.set_state("bomberRushTime",u.state_value("bomberRushTime")+dt)
	var t=nearest(u,u.enemies())
	if u.character_specific_state.get("bomberFuse")==null:
		if (t!=null and u.position.distance_to(t.position)<=78*u.combat_scale()) or u.state_value("bomberRushTime")>=3.5:u.set_state("bomberFuse",.6)
		elif t!=null:u.brain.steer(u,(t.position-u.position).normalized(),dt,1.8)
	else:
		u.knockback_velocity=Vector2.ZERO;u.velocity=Vector2.ZERO;u.set_state("bomberFuse",u.state_value("bomberFuse")-dt)
		if u.state_value("bomberFuse")<=0:
			u.current_hp=0;u.alive=false;u.announce_death(u.battle.find_actor(u.last_damage_actor))
			area_damage(u,u.position,165*u.combat_scale(),CombatRules.attack(u)*2.5,520,{"critical":true})
func modify_movement(u,_t,_dt: float) -> bool:return u.character_specific_state.get("bomberRush",false)
func throw(u,angle: float,point: Vector2,ultimate: bool) -> void:
	var distance: float=clampf(u.position.distance_to(point),90,480 if ultimate else 430)*u.combat_scale()
	angle+=u.battle.rng.randf_range(-.04,.04)
	var goal: Vector2=(u.position+Vector2.from_angle(angle)*distance).clamp(Vector2(25,25),Vector2(775,775))
	var flight: float=.7 if ultimate else .55
	var p=shoot(u,angle,CombatRules.attack(u)*(2.6 if ultimate else 1),{"kind":"bomb","large":ultimate,"radius":24 if ultimate else 13,"offset":32,"life":2.52 if ultimate else 2.02,"flight":flight,"fuse":2.5 if ultimate else 2,"blast_radius":(210 if ultimate else 120)*u.combat_scale(),"impulse":480 if ultimate else 290})
	p.velocity=(goal-p.position)/flight;u.knockback_velocity-=Vector2.from_angle(angle)*45
func release_basic(u) -> void:
	var t=u.combat.attack_target;throw(u,u.combat.aim_angle,t.position if t!=null else u.position+Vector2.from_angle(u.combat.aim_angle)*280,false)
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<420 and (u.enemies().filter(func(e):return e.position.distance_to(t.position)<210).size()>=2 or u.current_hp/u.max_hp<.5 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:throw(u,a.angle,CharacterPersistence.vector(a.point),true);return true
func debug_state(u) -> String:return " / ".join(["bomberRush", "bomberFuse"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
