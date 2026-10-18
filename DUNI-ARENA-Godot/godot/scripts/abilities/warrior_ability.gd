extends CharacterAbility
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<(480 if u.state_value("ultReadyAge")>4 else 200)
func release_ultimate(u,a,_dt: float) -> bool:
	u.combat.aim_angle=float(a.angle)
	melee(u,CombatRules.attack(u)*2.8,{"reach":215,"cone":1.5,"active":.3,"impulse":480,"independent":true})
	shoot(u,float(a.angle),CombatRules.attack(u)*2.3,{"kind":"swordWave","speed":390,"radius":48,"offset":42,"life":3,"piercing":true,"ultimate":true,"impulse":460})
	return true
func debug_state(u) -> String:return "Counter %s" % u.combat.counter
