extends CharacterAbility
var transfers: Array[Dictionary] = []
func release_basic(u) -> void:bolt(u,u.position+Vector2.from_angle(u.combat.aim_angle)*38*u.combat_scale(),u.combat.aim_angle,UnitStatTable.raw(u,&"basic"),{"remaining":5,"recent":[],"history":[]})
func bolt(u,point: Vector2,angle: float,damage: float,chain: Dictionary) -> void:
	var p=shoot(u,angle,damage,{"dmg":&"basic","kind":"lightning","speed":760,"life":1.15,"radius":24,"offset":0,"impulse":140,"chain":chain});p.position=point;u.set_state("shotsFired",u.state_value("shotsFired")+1)
func projectile_hit(u,p,t) -> bool:
	if p.kind!="lightning":return false
	var out: DamageOutcome=u.battle.damage_resolver.resolve(u,t,p.damage,p.attack_instance.options(t.position-p.velocity*.04));p.live=false
	if out.resolved_damage>0 or out.shield_absorbed>0:
		var chain: Dictionary=p.metadata.chain
		chain.history.append(t.actor_id());chain.recent.append(t.actor_id())
		if chain.recent.size()>2:chain.recent.pop_front()
		if int(chain.remaining)>0:transfers.append({"point":CharacterPersistence.point(t.position),"chain":chain,"damage":p.damage*.9,"wait":.08})
	return true
func projectile_tick(u,dt: float) -> void:
	for transfer in transfers.duplicate():
		transfer.wait=float(transfer.wait)-dt
		if float(transfer.wait)>1e-8:continue
		transfers.erase(transfer)
		var point: Vector2=CharacterPersistence.vector(transfer.point)
		var candidates: Array=u.enemies().filter(func(e):return not transfer.chain.recent.has(e.actor_id()) and point.distance_to(e.position)<=230*u.combat_scale())
		candidates.sort_custom(func(a,b):return point.distance_to(a.position)<point.distance_to(b.position))
		if candidates.is_empty() or int(transfer.chain.remaining)<=0:continue
		var t=candidates[0];transfer.chain.remaining-=1;var angle: float=(t.position-point).angle()
		bolt(u,point+Vector2.from_angle(angle)*12,angle,transfer.damage,transfer.chain)
func can_ultimate(u,_t) -> bool:return u.enemies().any(func(e):return u.position.distance_to(e.position)<250*u.combat_scale()) and (u.enemies().filter(func(e):return u.position.distance_to(e.position)<280*u.combat_scale()).size()>=2 or u.current_hp/u.max_hp<.6 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,_a,_dt: float) -> bool:
	u.battle.zones.add(u,"discharge",u.position,280*u.combat_scale(),.22,{"age":0.0,"hits":{},"damage":UnitStatTable.raw(u,&"ult")});return true
func dealt_damage(_u,target,_actual: float,options: Dictionary) -> void:
	if not target.alive:return
	target.set_state("shockStacks",target.state_value("shockStacks")+float(options.get("shock_stacks",1)))
	if target.state_value("shockStacks")>=4:target.set_state("shockStacks",int(target.state_value("shockStacks"))%4);StatusController.stun(target,2.5)
func ultimate_danger(u,observer,a: Dictionary) -> bool:return observer.position.distance_to(u.position)<310*u.combat_scale()
func cast_area(u,a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":280*u.combat_scale()}
func debug_state(u) -> String:return " / ".join(["shockStacks"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
