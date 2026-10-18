extends CharacterAbility
func choose_target(u,enemies: Array):
	var friend=support_anchor(u)
	return nearest(friend if friend!=null else u,enemies)
func defense_aura(u,target) -> float:return 22 if u!=target and u.team==target.team and u.position.distance_to(target.position)<=165*u.combat_scale() else 0
func ultimate_target(u):return support_anchor(u) if support_anchor(u)!=null else u
func can_ultimate(u,t) -> bool:return t!=null and t.invincible_remaining<=0 and (t.current_hp/t.max_hp<.65 or u.enemies().any(func(e):return e.position.distance_to(t.position)<170) or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	u.set_state("guardianUltTime",10)
	var t=u.battle.find_actor(a.target)
	if t==null or not t.alive or t.team!=u.team:t=ultimate_target(u)
	t.invincible_remaining=10;return true
func incoming_reduction(_u) -> float:return .8
func unique_defense(u,_source,amount: float,_can_evade: bool,options: Dictionary) -> Dictionary:
	if u.defense_cooldown<=0 and not options.get("transcendent",false):u.defense_cooldown=5;return {"amount":ceilf(amount*.45),"impulse_factor":.15}
	return {}
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func defensive_ultimate() -> bool:return true
func debug_state(u) -> String:return " / ".join(["guardianUltTime"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
