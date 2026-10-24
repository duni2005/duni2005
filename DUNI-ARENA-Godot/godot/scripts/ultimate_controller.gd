class_name UltimateController
extends RefCounted
## Gauge gain, AI thinking and casts. Character effects live in Ability hooks.
var cast: Dictionary = {}
var serial: int = 0
var think: float = .5
func blocked(u) -> bool:
	return StatusController.skill_charge_blocked(u) or not cast.is_empty()
func efficiency(u) -> float:
	return EquipmentCombatEffects.ultimate_power(u)*(.2 if (u.data.type_id==3 and u.state_value("shadowTime")>0 or u.data.type_id==4 and u.state_value("guardianUltTime")>0) else 1)
func gain(u,amount: float) -> float:
	if blocked(u) or u.data.ultimate_windup<0 or amount<=0:return 0
	var before: float=u.ultimate_gauge;u.ultimate_gauge=clampf(before+amount,0,100);return u.ultimate_gauge-before
func charge(u,damage: float,dealt: bool) -> void:
	if StatusController.skill_charge_blocked(u) or damage<=0:return
	if (u.battle.get("custom_mode")==true or not u.source_member_id.is_empty() and u.team==0) and u.puppet_control.is_empty() and (u.battle.transcendence==null or u.battle.transcendence.cast.get("actor","")!=u.actor_id()):
		u.transcendence_gauge=clampf(u.transcendence_gauge+damage/u.max_hp*(12 if dealt else 16),0,100)
	gain(u,damage/u.max_hp*(65 if dealt else 90)*(1.3 if u.data.type_id==3 else 1.2 if u.data.type_id==0 else 1)*efficiency(u))
func advance(u,dt: float) -> void:
	advance_charge(u,dt);advance_action(u,dt)
func advance_charge(u,dt: float) -> void:
	if not u.frog_action.is_empty() or u.unavailable():return
	gain(u,1.5*dt*efficiency(u));think-=dt
	u.set_state("ultReadyAge",u.state_value("ultReadyAge")+dt if u.ultimate_gauge>=100 else 0)
func advance_action(u,dt: float) -> void:
	if not u.frog_action.is_empty() or u.unavailable():return
	if not cast.is_empty():
		if not u.alive:cast.clear();return
		if u.stun_remaining>0:return
		cast.t=float(cast.t)+dt
		if u.data.type_id!=18:u.facing=float(cast.angle)
		if float(cast.t)<float(cast.duration):return
		u.battle.ultimate_actor=u;var done: bool=u.ability.release_ultimate(u,cast,dt);u.battle.ultimate_actor=null
		if done:
			cast.clear();EquipmentCombatEffects.after_ultimate(u);u.combat.cooldown=maxf(u.combat.cooldown,.6);u.brain.disengage_until=u.battle.clock.elapsed+u.battle.rng.randf_range(.45,.95)
		return
	if not u.ability.can_cast(u) or (u.area_evaluator.offense_blocked(u) and not u.character_specific_state.get("strategyUltimateReady",false) and not u.ability.defensive_ultimate()):return
	if u.ultimate_gauge<100 or think>0 or u.combat_state!=CombatController.State.IDLE or u.ability.locked(u) or u.stun_remaining>0 or u.evade_remaining>0 or ParryController.perfect(u) or u.command_retreat_until>u.battle.clock.elapsed:return
	think=u.battle.rng.randf_range(.35,.95)
	var target=u.ability.ultimate_target(u)
	var ready: bool=u.ability.can_ultimate(u,target)
	if u.character_specific_state.get("strategyUltimateReady",false) and (target!=null or u.data.type_id in [4,5]) and u.data.type_id!=24:ready=true
	if not ready:return
	request(u,target)
func request(u,target) -> bool:
	if u.data.ultimate_windup<0 or u.ability.reactive_ultimate() or not u.alive or u.stun_remaining>0 or u.ability.locked(u) or not cast.is_empty() or u.ultimate_gauge<100:return false
	var point: Vector2=u.ability.ultimate_point(u,target.position+target.velocity*.4 if target!=null else u.position)
	serial+=1
	cast={"t":0.0,"duration":u.data.ultimate_windup,"target":target.actor_id() if target!=null else "","angle":(point-u.position).angle(),"point":CharacterPersistence.point(point.clamp(Vector2(28,28),Vector2(772,772)))}
	u.ultimate_gauge=0;u.set_state("ultReadyAge",0);u.set_state("ultUses",u.state_value("ultUses")+1);u.set_state("strategyUltimateReady",false)
	u.velocity=Vector2.ZERO;u.knockback_velocity*=.2
	u.battle.emit_combat_event(&"ultimate",u.position,{"actor":u.actor_id(),"type":u.data.type_id})
	return true
