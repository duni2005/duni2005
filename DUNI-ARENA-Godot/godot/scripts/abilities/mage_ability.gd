extends CharacterAbility
func attack_rate(u) -> float:return 1.3 if u.current_hp/u.max_hp<=.5 else 1
func movement_rate(u) -> float:return 1.35 if u.current_hp/u.max_hp<=.5 else 1
func projectile_hit(u,p,t) -> bool:
	if p.kind!="":return false
	u.battle.damage_resolver.resolve(u,t,p.damage,p.attack_instance.options(t.position-p.velocity*.08))
	for enemy in u.enemies(false):
		if enemy!=t and p.position.distance_to(enemy.position)<110*float(p.metadata.get("scale",1)):u.battle.damage_resolver.resolve(u,enemy,UnitStatTable.raw(u,&"splash"),{"dmg":&"splash","critical":false,"impulse":260,"attack_origin":p.position,"hidden_launch":p.hidden_launch})
	p.live=false;return true
func can_ultimate(u,t) -> bool:return t!=null and (u.enemies().filter(func(e):return e.position.distance_to(t.position)<210).size()>=2 or u.current_hp/u.max_hp<.55 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	u.battle.zones.add(u,"blackhole",CharacterPersistence.vector(a.point).clamp(Vector2(70,70),Vector2(730,730)),195*u.combat_scale(),6);return true
func unique_defense(u,source,amount: float,can_evade: bool,options: Dictionary) -> Dictionary:
	if can_evade and not u.character_specific_state.get("transferUsed",false) and maxf(0,amount-u.shield_hp)>=u.current_hp:
		u.set_state("transferUsed",true)
		for enemy in u.enemies(false):
			if enemy.position.distance_to(u.position)<170:StatusController.stun(enemy,1.2)
		u.position=CharacterLifecycle.safest(u);u.knockback_velocity=Vector2.ZERO;u.combat.cancel(u);u.evade_remaining=.4
		return {"avoid":true}
	return {}
func ultimate_danger(u,observer,a: Dictionary) -> bool:return observer.position.distance_to(CharacterPersistence.vector(a.point))<250
func cast_area(u,a: Dictionary) -> Dictionary:return {"point":a.point,"radius":195*u.combat_scale()}
func debug_state(u) -> String:return " / ".join(["transferUsed"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
