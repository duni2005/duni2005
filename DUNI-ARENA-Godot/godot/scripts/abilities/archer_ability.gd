extends CharacterAbility
func release_basic(u) -> void:
	u.set_state("shotsFired",u.state_value("shotsFired")+1)
	var fan: bool=int(u.state_value("shotsFired"))%3==0
	for off in ([-.3,0,.3] if fan else [0]):
		shoot(u,u.combat.aim_angle+off+u.battle.rng.randf_range(-.025,.025),CombatRules.attack(u),{"life":8 if fan else 2.4,"bounces":2 if fan else 0})
	u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*60
func can_ultimate(u,t) -> bool:return t!=null and (u.position.distance_to(t.position)>120 or u.current_hp/u.max_hp<.3 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	shoot(u,float(a.angle),CombatRules.attack(u)*7,{"kind":"giantArrow","speed":590,"radius":64,"offset":42,"life":3,"piercing":true,"ultimate":true,"impulse":460});return true
func debug_state(u) -> String:return " / ".join(["shotsFired"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
