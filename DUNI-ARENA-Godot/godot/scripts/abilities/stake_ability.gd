extends CharacterAbility
## 말뚝: opens by driving a stake into the nearest enemy (damage + tether), swings a hammer,
## ultimate leaps onto the nearest enemy with a heavy stake (damage + 3s stun).
const TETHER_TIME: float = 8
const ULT_STUN: float = 3
func tick(u,_dt: float) -> void:
	if u.state_value("stakeOpened") > 0 or not u.battle.started:return
	u.set_state("stakeOpened",1)
	var target=nearest(u,u.enemies(false).filter(func(e):return not e.unavailable()))
	if target==null:return
	u.battle.damage_resolver.resolve(u,target,UnitStatTable.raw(u,&"open"),{"dmg":&"open","critical":false,"impulse":0,"visible_hazard":true})
	BindingController.tether(target,target.position,TETHER_TIME)
func release_basic(u) -> void:
	# Heavy hammer: wider swing and a stronger shove than a sword.
	melee(u,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","impulse":340})
	u.knockback_velocity+=Vector2.from_angle(u.combat.aim_angle)*80
func ultimate_target(u):return nearest(u,u.enemies().filter(func(e):return not e.unavailable()))
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<460
func release_ultimate(u,a,dt: float) -> bool:
	var target=u.battle.find_actor(a.get("target",""))
	if target==null or not target.alive:return true
	a["leap"]=float(a.get("leap",0))+dt;a.dashing=true
	var arrived: bool=dash_to(u,target.position,950,dt,34*target.combat_scale())
	if not arrived and float(a.leap)<1.0:return false
	u.battle.damage_resolver.resolve(u,target,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","impulse":0,"visible_hazard":true})
	u.battle.emit_combat_event(&"ult_impact",target.position,{"actor":u.actor_id(),"type":u.data.type_id,"radius":120})
	if target.alive:StatusController.stun(target,ULT_STUN);BindingController.tether(target,target.position,ULT_STUN,40)
	return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:return a.get("target","")==observer.actor_id()
