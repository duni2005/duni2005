extends CharacterAbility
func release_basic(u) -> void:
	melee(u,CombatRules.attack(u),{"bite":true,"max_targets":3,"execute_threshold":.13})
	u.combat.attack_metadata.bite_dash=48*minf(1.5,u.combat_scale())
func attack_tick(u,dt: float) -> bool:
	if u.combat_state==CombatController.State.ACTIVE and float(u.combat.attack_metadata.get("bite_dash",0))>0:
		var before: Vector2=u.position;var move: float=minf(float(u.combat.attack_metadata.bite_dash),400*minf(1.5,u.combat_scale())*dt)
		dash_to(u,u.position+Vector2.from_angle(u.combat.aim_angle)*move,400*minf(1.5,u.combat_scale()),dt)
		u.combat.attack_metadata.bite_dash=maxf(0,float(u.combat.attack_metadata.bite_dash)-u.position.distance_to(before))
	return false
func modify_movement(u,_t,_dt: float) -> bool:return u.combat_state==CombatController.State.ACTIVE and float(u.combat.attack_metadata.get("bite_dash",0))>0
func on_kill(u,_victim) -> void:
	if u.alive:u.set_state("predatorStacks",u.state_value("predatorStacks")+1);restore_hp(u,u.max_hp*.1,u)
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<175*u.combat_scale() and (u.enemies().filter(func(e):return u.position.distance_to(e.position)<200*u.combat_scale()).size()>=2 or t.current_hp/t.max_hp<.5 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	u.combat.aim_angle=a.angle;melee(u,CombatRules.attack(u)*1.8,{"reach":175,"active":.5,"cone":1.15,"impulse":350,"bite":true,"max_targets":3,"execute_threshold":.2,"independent":true});return true
func debug_state(u) -> String:return " / ".join(["predatorStacks"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
