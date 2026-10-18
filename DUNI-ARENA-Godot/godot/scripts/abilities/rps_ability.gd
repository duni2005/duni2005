extends CharacterAbility
func can_attack(_u,t) -> bool:return t!=null and t.invincible_remaining<=0 and t.duel.is_empty()
func on_attack_start(u) -> void:
	var choices: Array=u.enemies().filter(func(t):return t.duel.is_empty() and t.invincible_remaining<=0 and u.position.distance_to(t.position)<230*u.combat_scale())
	if not choices.is_empty():u.combat.attack_target=choices[u.battle.rng.randi_range(0,choices.size()-1)]
func release_basic(u) -> void:
	var target=u.combat.attack_target
	if target==null:return
	var strike: AttackInstance=melee(u,0,{"reach":58,"cone":.25,"active":1.25,"impulse":0,"grapple":target.actor_id(),"duel_ultimate":u.combat.attack_metadata.get("ultimate",false)})
	if strike!=null:strike.power=20
func attack_tick(u,dt: float) -> bool:
	if u.combat_state!=CombatController.State.ACTIVE:return false
	var target=u.combat.attack_target
	if target!=null and target.alive:
		u.combat.aim_angle=(target.position-u.position).angle()
		CharacterAbility.dash_to(u,target.position,320,dt,maxf(12,54*u.combat_scale()+27*(target.combat_scale()-1)))
		for s in u.battle.melee_strikes:
			if s.source_battle_id==u.battle_id:s.angle=u.combat.aim_angle
	return false
func can_ultimate(u,_t) -> bool:return u.enemies().any(func(e):return e.duel.is_empty() and e.invincible_remaining<=0 and u.position.distance_to(e.position)<230)
func release_ultimate(u,_a,_dt: float) -> bool:
	var t=nearest(u,u.enemies())
	if t!=null:u.combat.force_start(u,t);u.combat.attack_metadata.ultimate=true
	return true
func attack_cooldown(u,rng: RandomNumberGenerator) -> float:return 2.5
func debug_state(u) -> String:return " / ".join(["duelRounds"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
