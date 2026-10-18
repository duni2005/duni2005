extends CharacterAbility
## 자석: fires small current orbs. Ultimate shocks the two farthest enemies, marks them N and S,
## and they snap together at speed (hurting enemies in the way), then stay stuck for 10 seconds,
## each also taking 10% of the damage its partner takes.
const ULT_DAMAGE: float = 18
const LINK_TIME: float = 10
func release_basic(u) -> void:
	shoot(u,u.combat.aim_angle,CombatRules.attack(u),{"kind":"magic","speed":420,"radius":18,"impulse":150})
func free_enemies(u) -> Array:
	return u.enemies(false).filter(func(e):return not e.unavailable() and e.state_value("magnetTime")<=0)
func can_ultimate(u,_t) -> bool:return free_enemies(u).size()>=2
func release_ultimate(u,_a,_dt: float) -> bool:
	var pool: Array=free_enemies(u)
	if pool.size()<2:return true
	# The two enemies farthest from the magnet are dragged across the field toward each other.
	pool.sort_custom(func(a,b):return a.position.distance_squared_to(u.position)>b.position.distance_squared_to(u.position))
	var first=pool[0];var second=pool[1]
	for e in [first,second]:
		u.battle.damage_resolver.resolve(u,e,ULT_DAMAGE,{"critical":false,"impulse":0,"visible_hazard":true})
		e.set_state("magnetShockFx",.6)
	if first.alive and second.alive:BindingController.link(u,first,second,LINK_TIME)
	u.set_state("magnetCastFx",.5)
	u.character_specific_state["magnetTargets"]=[first.actor_id(),second.actor_id()]
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
