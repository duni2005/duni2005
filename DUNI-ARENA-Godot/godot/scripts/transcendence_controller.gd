class_name TranscendenceController
extends RefCounted
## Manual player intervention; presentation clock advances while simulation is frozen.
var battle
var previous_clock_state: BattleClock.State
var aim: Dictionary = {}
var cast: Dictionary = {}
func _init(owner):battle=owner
func ready(u) -> bool:
	return u!=null and not u.source_member_id.is_empty() and u.team==0 and u.alive and u.transcendence_gauge>=100 and not StatusController.skill_charge_blocked(u) and u.ultimate.cast.is_empty() and u.frog_action.is_empty() and u.hero_rescue.is_empty() and u.state_value("guardRemaining")<=0 and battle.started and not battle.finished
func begin(u,origin: Vector2) -> bool:
	if not aim.is_empty() or not cast.is_empty() or not ready(u):return false
	previous_clock_state=battle.clock.state;battle.clock.state=BattleClock.State.TRANSCENDENCE_AIM
	aim={"actor":u.actor_id(),"origin":CharacterPersistence.point(origin),"angle":u.facing,"outside":false};return true
func update(point: Vector2) -> void:
	if aim.is_empty():return
	var diff: Vector2=point-CharacterPersistence.vector(aim.origin);aim.outside=diff.length()>=32; battle.queue_redraw()
	if aim.outside:aim.angle=diff.angle()
func release(cancel: bool=false) -> bool:
	if aim.is_empty():return false
	var u=battle.find_actor(aim.actor)
	if cancel or not aim.outside or not ready(u):reset();return false
	u.transcendence_gauge=0;u.combat.cancel(u);u.dodge_state.clear();u.strategy_dash.clear();u.evade_remaining=0;u.knockback_velocity=Vector2.ZERO;u.facing=aim.angle;u.set_state("revealTime",3)
	for a in battle.melee_strikes:
		if a.source_battle_id==u.battle_id:a.life=0
	cast={"actor":aim.actor,"angle":aim.angle,"time":0.0,"released":false};aim.clear();battle.clock.state=BattleClock.State.TRANSCENDENCE_CAST;return true
func advance(dt: float) -> bool:
	if aim.is_empty() and cast.is_empty():return false
	if battle.finished:reset();return true
	if cast.is_empty():return true
	var u=battle.find_actor(cast.actor)
	if u==null or not u.alive:reset();return true
	var old: float=cast.time;cast.time=float(cast.time)+maxf(0,dt)
	var step: float=(clampf((float(cast.time)-.38)/.2,0,1)-clampf((old-.38)/.2,0,1))*34
	u.position=MovementController.clamp_position(u.position+Vector2.from_angle(cast.angle)*step)
	if not cast.released and float(cast.time)>=.38:
		cast.released=true
		for enemy in u.enemies(false):
			var d: Vector2=enemy.position-u.position
			if enemy.unavailable() or d.length()>310*u.combat_scale()+27*enemy.combat_scale() or absf(wrapf(d.angle()-float(cast.angle),-PI,PI))>1.08:continue
			battle.damage_resolver.resolve(u,enemy,CombatRules.attack(u)*5+60,{"transcendent":true,"critical":false,"impulse":380,"angle":cast.angle,"attack_origin":u.position})
	if float(cast.time)>=1.15:reset();battle.check_outcome()
	u.queue_redraw();battle.queue_redraw();return true
func reset() -> void:
	if not aim.is_empty() or not cast.is_empty():
		if not battle.finished:battle.clock.state=previous_clock_state
	aim.clear();cast.clear()
