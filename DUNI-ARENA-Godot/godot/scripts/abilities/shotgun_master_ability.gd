extends "res://scripts/abilities/shotgun_ability.gd"
## 강화된 샷건 마스터 (미니보스): the shotgun's boss. Basic attack: a deadly close-range fan of
## PELLETS pellets (fading with distance); two shots, then a RELOAD s reload. Ultimate 빠른 장전,
## only when it needs to reload: reloads at once, dashes at its target (DASH at most) and takes a
## shield of SHIELD of its max HP for SHIELD_TIME s. Its own special strategy is 폭발 슬러그 탄약
## (EnemyTurningPlan.SLUG), which it uses at every turning point as a boss.
const PELLETS: int = 9
const SPREAD: float = .115
const RELOAD: float = 3.5
const DASH: float = 220.0
const DASH_SPEED: float = 900.0
const SHIELD: float = .2
const SHIELD_TIME: float = 4.0

func tick(u,dt: float) -> void:
	var remaining: float=u.state_value("reloadRemaining")
	if remaining>0:
		remaining=maxf(0,remaining-dt);u.set_state("reloadRemaining",remaining)
		if remaining<=0:u.set_state("ammo",2);u.brain.disengage_until=0;u.brain.attack_decision.clear()
func release_basic(u) -> void:
	u.set_state("ammo",u.state_value("ammo")-1);u.set_state("shotsFired",u.state_value("shotsFired")+1)
	for i in range(PELLETS):shoot(u,u.combat.aim_angle+(i-(PELLETS-1)*.5)*SPREAD+u.battle.rng.randf_range(-.012,.012),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"pellet","speed":740,"life":.48,"radius":22,"offset":45,"impulse":140})
	u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*300
	if u.state_value("ammo")<=0:u.set_state("reloadRemaining",RELOAD)
## 빠른 장전: only while it has to reload.
func needs_reload(u) -> bool:return u.state_value("reloadRemaining")>0 or u.state_value("ammo")<=0
func can_ultimate(u,t) -> bool:return t!=null and needs_reload(u)
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	u.set_state("ammo",2);u.set_state("reloadRemaining",0.0);u.brain.disengage_until=0;u.brain.attack_decision.clear()
	var t=ultimate_target(u);var to: Vector2=Vector2.from_angle(u.facing)
	if t!=null:
		to=t.position-u.position;var reach: float=minf(DASH,maxf(0,to.length()-60*u.combat_scale()))
		if reach>8:u.strategy_dash={"direction":to.normalized(),"remaining":reach,"speed":DASH_SPEED}
	u.shield_hp=maxf(u.shield_hp if u.shield_remaining>0 else 0.0,u.max_hp*SHIELD);u.shield_remaining=maxf(u.shield_remaining,SHIELD_TIME)
	u.battle.emit_combat_event(&"master_reload",u.position,{"actor_id":u.battle_id,"angle":to.angle()})
	return true
func defensive_ultimate() -> bool:return true
