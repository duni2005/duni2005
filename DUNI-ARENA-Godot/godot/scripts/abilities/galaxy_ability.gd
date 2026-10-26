extends CharacterAbility
func on_spawn(u) -> void:
	var enemies: Array=u.enemies(false);enemies.sort_custom(func(a,b):return u.position.distance_to(a.position)>u.position.distance_to(b.position))
	if not enemies.is_empty():enemies[0].cosmic_marked=true
func release_basic(u) -> void:
	for i in range(5):shoot(u,u.combat.aim_angle+(i-2)*1.35/4+u.battle.rng.randf_range(-.018,.018),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"star","speed":240,"radius":18,"offset":38,"life":3.6,"impulse":155})
	u.set_state("shotsFired",u.state_value("shotsFired")+1)
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<450
func ultimate_target(u):return nearest(u,u.enemies())
func release_ultimate(u,a,_dt: float) -> bool:
	var t=u.battle.find_actor(a.target)
	if t!=null and t.alive:u.battle.zones.add(u,"galaxy",t.position,270*u.combat_scale(),7,{"target":t.actor_id()})
	return true
func debug_state(u) -> String:return "Cosmic %s" % u.cosmic_marked
