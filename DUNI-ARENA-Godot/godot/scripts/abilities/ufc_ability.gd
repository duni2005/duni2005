extends ComboAbility
func target_priority(_u,e,_seen: Array) -> float:return 0 if e.data.type_id in [0,3,4,8,9,10,11,12,14,16,17,19] else 1
func release_basic(u) -> void:
	var last: bool=int(u.combat.attack_metadata.get("combo",0))==2
	melee(u,UnitStatTable.raw(u,&"basic_last" if last else &"basic"),{"dmg":&"basic_last" if last else &"basic","impulse":570 if last else 95,"punch":true})
	u.knockback_velocity+=Vector2.from_angle(u.combat.aim_angle)*(140 if last else 70)
func can_ultimate(u,t) -> bool:return t!=null and (u.enemies().filter(func(e):return e.position.distance_to(t.position)<240).size()>=2 or u.position.distance_to(t.position)<380 or u.state_value("ultReadyAge")>4)
func ultimate_target(u):
	var choices: Array=u.enemies();choices.sort_custom(func(a,b):return u.enemies().filter(func(e):return e.position.distance_to(a.position)<240).size()>u.enemies().filter(func(e):return e.position.distance_to(b.position)<240).size());return choices[0] if not choices.is_empty() else null
func release_ultimate(u,a,dt: float) -> bool:
	var point: Vector2=CharacterPersistence.vector(a.point).clamp(Vector2(175,175),Vector2(625,625))
	var from: Vector2=u.position
	var arrived: bool=dash_to(u,point,680,dt)
	a.dashing=true;a["rush_time"]=float(a.get("rush_time",0))+dt
	var hits: Dictionary=a.get("hits",{});a.hits=hits
	for enemy in u.enemies(false):
		if enemy.unavailable() or enemy.invincible_remaining>0:continue
		if not hits.has(enemy.actor_id()) and PhysicalAttackSystem.point_distance(enemy.position,from,u.position)<105:
			hits[enemy.actor_id()]=true;u.battle.damage_resolver.resolve(u,enemy,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":false,"impulse":0})
			KnockbackController.apply(enemy,(u.position-enemy.position).normalized()*400,u)
		var d: float=u.position.distance_to(enemy.position)
		if d<230 and not ParryController.perfect(enemy):enemy.position=MovementController.clamp_position(enemy.position+(u.position-enemy.position).normalized()*170*(1-d/230)*dt)
	if not arrived and float(a.rush_time)<1.6:return false
	u.battle.zones.add(u,"ring",u.position,150*u.combat_scale(),10);return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:return observer.position.distance_to(CharacterPersistence.vector(a.point))<240 or PhysicalAttackSystem.point_distance(observer.position,u.position,CharacterPersistence.vector(a.point))<120
func attack_cooldown(u,rng: RandomNumberGenerator) -> float:return 1.2+u.data.attack_interval*rng.randf_range(.3,.55)
func cast_area(u,a: Dictionary) -> Dictionary:return {"point":a.point,"radius":180*u.combat_scale()}
func ultimate_point(_u,point: Vector2) -> Vector2:return point.clamp(Vector2(175,175),Vector2(625,625))
func debug_state(u) -> String:return "Combo %d" % int(u.combat.attack_metadata.get("combo",0))
