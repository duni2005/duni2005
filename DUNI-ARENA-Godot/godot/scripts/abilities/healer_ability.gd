extends CharacterAbility
func tick(u,_dt: float) -> void:
	if ParryController.perfect(u) or u.threat_response.response.get("mode",&"")==&"parry" or not u.dodge_state.is_empty() or u.state_value("heal")>0 or u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty() or u.stun_remaining>0 or u.evade_remaining>0 or u.command_retreat_until>u.battle.clock.elapsed:return
	var patients: Array=[u]+u.friends()
	patients=patients.filter(func(p):return p.current_hp<p.max_hp*.88 and u.position.distance_to(p.position)<245*u.combat_scale())
	patients.sort_custom(func(a,b):return a.current_hp/a.max_hp<b.current_hp/b.max_hp)
	if not patients.is_empty():u.combat.start_heal(u,patients[0]);u.set_state("heal",u.battle.rng.randf_range(3.8,4.8))
func support_anchor(u):
	var friends: Array=u.friends().filter(func(a):return not a.data.tags.has("의존형"))
	if friends.is_empty():
		var group: Array=[u]+u.friends();group.sort_custom(func(a,b):return a.battle_id<b.battle_id)
		return null if group[0]==u else group[0]
	friends.sort_custom(func(a,b):return a.data.attack_range<b.data.attack_range if (a.data.attack_range<100)!=(b.data.attack_range<100) else u.position.distance_to(a.position)<u.position.distance_to(b.position))
	return friends[0]
func can_ultimate(u,t) -> bool:return ([u]+u.friends()).any(func(p):return u.position.distance_to(p.position)<180 and p.current_hp/p.max_hp<.75) and (t!=null or u.state_value("ultReadyAge")>4)
func release_ultimate(u,_a,_dt: float) -> bool:u.battle.zones.add(u,"healing",u.position,175*u.combat_scale(),10);return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func defensive_ultimate() -> bool:return true
func debug_state(u) -> String:return " / ".join(["heal"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
