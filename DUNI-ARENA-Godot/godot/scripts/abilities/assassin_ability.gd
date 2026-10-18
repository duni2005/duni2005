extends CharacterAbility
func critical_bonus(u,t) -> float:return (.1 if t.current_hp>=t.max_hp else 0)+(.15 if u.state_value("shadowTime")>0 else 0)
func attack_factor(u) -> float:return .8 if u.state_value("shadowTime")>0 else 1
func attack_rate(u) -> float:return .75 if u.state_value("shadowTime")>0 else 1
func choose_target(u,enemies: Array):
	var seen: Array=enemies.duplicate()
	enemies.sort_custom(func(a,b):return a.current_hp<b.current_hp if a.current_hp!=b.current_hp else rear(u,a,seen)>rear(u,b,seen) if rear(u,a,seen)!=rear(u,b,seen) else u.position.distance_to(a.position)<u.position.distance_to(b.position))
	return enemies[0] if not enemies.is_empty() else null
func rear(u,t,seen: Array) -> bool:
	if t.data.tags.has("후열"):return true
	var dx: Vector2=t.position-u.position;var d: float=maxf(1,dx.length())
	return seen.any(func(e):return e!=t and dx.dot(t.position-e.position)/d>80 and absf(dx.cross(t.position-e.position))/d<170)
func tick(u,_dt: float) -> void:
	if u.combat_state!=CombatController.State.IDLE or u.enemies(false).any(func(e):return u.position.distance_to(e.position)<=160):u.set_state("revealTime",3)
	u.hidden_from_enemies=u.state_value("shadowTime")>0 or (u.state_value("revealTime")<=0 and u.combat_state==CombatController.State.IDLE)
func can_ultimate(u,t) -> bool:return t!=null and (u.position.distance_to(t.position)<280 or u.current_hp/u.max_hp<.6 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,_a,_dt: float) -> bool:u.set_state("shadowTime",10);return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func debug_state(u) -> String:return " / ".join(["shadowTime", "revealTime"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
