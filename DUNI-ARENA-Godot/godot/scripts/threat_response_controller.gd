class_name ThreatResponseController
extends RefCounted
## Minimal port of windup/projectile perception and reaction, not createBrain AI.
var read_attacks: Dictionary = {}
var projectile_notices: Dictionary = {}
var response: Dictionary = {}
var reaction: float = .2
var side: float = 1
var counts: Dictionary = {}
func initialize(rng: RandomNumberGenerator) -> void:
	reaction = rng.randf_range(.14, .29)
	side = -1 if rng.randf() < .5 else 1
static func chances(unit) -> Dictionary:
	var low: float = 1-clampf(unit.current_hp/unit.max_hp, 0, 1)
	var ready: bool = ParryController.available(unit)
	var cautious: bool = unit.stance == CombatStance.CAUTIOUS
	var rush: bool = unit.stance == CombatStance.RUSH
	var p: float = clampf(.36+low*.32+(.09 if cautious else -.12 if rush else .05 if unit.stance==CombatStance.COVER else 0), .12, .66) if ready else 0
	var d: float = clampf((.12 if ready else .18)+low*(.12 if ready else .2)+(.05 if cautious else -.07 if rush else 0), .04, .26 if ready else .42)
	var c: float = minf(1-p-d, clampf((.42 if ready else .68)-low*.28+(.12 if rush else -.12 if cautious else 0), .05, .8))
	return {"parry": p, "dodge": d, "counter": c, "hold": maxf(0,1-p-d-c)}
static func windup_threat(unit):
	var nearby: Array = []
	for enemy in unit.battle.units:
		if enemy.team == unit.team or not enemy.alive:continue
		if unit.battle.full_characters_enabled and not enemy.ultimate.cast.is_empty():
			if CombatPerception.can_see_attack(unit,enemy,enemy.position,false) and enemy.ability.ultimate_danger(enemy,unit,enemy.ultimate.cast):nearby.append(enemy)
			continue
		if enemy.combat_state != CombatController.State.WINDUP or enemy.combat.attack_target!=null and enemy.combat.attack_target.team==enemy.team: continue
		if not CombatPerception.can_see_attack(unit, enemy, enemy.position, enemy.combat.hidden_launch): continue
		var profile: AttackData = enemy.combat.profile(enemy)
		var relative: Vector2 = unit.position-enemy.position
		if relative.length() < profile.reach*enemy.combat_scale()+90 and (enemy.combat.attack_target == unit or absf(wrapf(relative.angle()-enemy.combat.aim_angle,-PI,PI)) < profile.cone+.25): nearby.append(enemy)
	nearby.sort_custom(func(a,b): return unit.position.distance_squared_to(a.position)<unit.position.distance_squared_to(b.position))
	return nearby[0] if not nearby.is_empty() else null
static func impact_delay(unit, enemy) -> float:
	var profile: AttackData = enemy.combat.profile(enemy)
	if unit.battle.full_characters_enabled:
		return maxf(0,float(enemy.ultimate.cast.duration)-float(enemy.ultimate.cast.t))+enemy.ability.impact_delay_extra(enemy,unit,true) if not enemy.ultimate.cast.is_empty() else maxf(0,(profile.windup-enemy.combat.phase_time)/enemy.ability.attack_rate(enemy))+enemy.ability.impact_delay_extra(enemy,unit,false)
	return maxf(0, profile.windup-enemy.combat.phase_time) + (unit.position.distance_to(enemy.position)/470 if enemy.data.type_id==1 else 0)
static func timing(unit, delay: float) -> Dictionary:
	var rng: RandomNumberGenerator = unit.battle.rng
	var lead: float = rng.randf_range(.17,.31)
	var mistake: bool = rng.randf() < unit.mind.parry_mistake(unit,.15 if unit.stance==CombatStance.CAUTIOUS else .3)
	var mode: String = ("early" if delay > .6 and rng.randf()<.5 else "late") if mistake else "normal"
	var wait: float = delay-lead
	if mode=="early": wait-=rng.randf_range(.45,.95)
	elif mode=="late": wait+=rng.randf_range(.35,.75)
	var at: float = unit.battle.clock.elapsed+maxf(0,wait)
	return {"parry_at":at,"timing":mode,"until":maxf(unit.battle.clock.elapsed+delay+.5,at+.3)}
func advance(unit) -> void:
	var battle = unit.battle
	var now: float = battle.clock.elapsed
	if unit.stun_remaining>0:
		response.clear()
		return
	if not response.is_empty():
		var source = battle.find_unit(response.source_id)
		var matching: bool = is_instance_valid(source) and source.alive and reaction_serial(source)==response.serial and (source.combat_state!=CombatController.State.IDLE or not source.ultimate.cast.is_empty())
		if matching and (source.combat.fired or not source.ultimate.cast.is_empty() and float(source.ultimate.cast.t)>=float(source.ultimate.cast.duration)): response.fired=true
		if response.mode==&"parry":
			if response.started:
				if not ParryController.perfect(unit): response.clear()
			elif not matching and not response.fired or not is_instance_valid(source) or not source.alive or now>=response.until or not CombatPerception.can_see_attack(unit,source,source.position,response.hidden):
				response.clear()
			elif now>=response.parry_at:
				if unit.parry.start(unit,source): response.started=true
				elif now>response.parry_at+.2: response.clear()
		elif not matching or source.combat_state in [CombatController.State.RECOVERY,CombatController.State.IDLE] or now>=response.until:
			if unit.battle.full_characters_enabled and response.mode==&"dodge" and is_instance_valid(source) and source.alive and unit.last_damage_time<float(response.get("observed_at",0)):unit.brain.punish_actor=source.actor_id();unit.brain.punish_until=now+1.6;unit.brain.begin(unit,source,1.9,"punish")
			response.clear()
	if not response.is_empty() or ParryController.perfect(unit) or not unit.alive or unit.evade_remaining>0 or not unit.dodge_state.is_empty() or not unit.strategy_dash.is_empty() or not unit.ultimate.cast.is_empty() or unit.battle.full_characters_enabled and unit.ability.locked(unit) or unit.combat_state in [CombatController.State.ACTIVE,CombatController.State.RECOVERY]: return
	var source = windup_threat(unit)
	if source==null: return
	var key: String = "%d:%d"%[source.battle_id,reaction_serial(source)]
	if not read_attacks.has(key):
		var factor: float = .72 if unit.stance==CombatStance.CAUTIOUS else 1.45 if unit.stance==CombatStance.RUSH else 1.0
		read_attacks[key]={"at":now+battle.rng.randf_range(.09,.26)*factor,"roll":battle.rng.randf(),"done":false}
	var read: Dictionary = read_attacks[key]
	if read.done or now<read.at: return
	read.done=true
	var probabilities: Dictionary = unit.mind.adjust_reaction(unit,chances(unit),source)
	var mode: StringName = &"parry" if read.roll<probabilities.parry else &"dodge" if read.roll<probabilities.parry+probabilities.dodge else &"counter" if read.roll<probabilities.parry+probabilities.dodge+probabilities.counter else &"hold"
	var delay: float = impact_delay(unit,source)
	response={"mode":mode,"observed_at":now+.00001,"source_id":source.battle_id,"serial":reaction_serial(source),"fired":false,"hidden":source.combat.hidden_launch,"started":false,"side":-1 if battle.rng.randf()<.5 else 1,"until":now+minf(1.05,delay+.4)}
	counts[mode]=counts.get(mode,0)+1
	if mode==&"parry": response.merge(timing(unit,delay),true);response.advance=unit.mind.advance_while_parrying(unit,source)
	if unit.battle.full_characters_enabled and mode==&"counter":unit.brain.begin(unit,source,1.5,"counter")
	if unit.battle.full_characters_enabled and mode==&"hold":unit.brain.mode="circle";unit.brain.hold=battle.rng.randf_range(.15,.4)
	if mode in [&"parry",&"dodge"]:
		if unit.battle.full_characters_enabled:unit.brain.commit_until=0;unit.brain.mode="retreat"
		if unit.combat_state==CombatController.State.WINDUP: unit.combat.cancel(unit)
		if mode==&"parry" and now>=response.parry_at: response.started=unit.parry.start(unit,source)
	# Old reads are ID-only and bounded. Current response retains its own record.
	if read_attacks.size()>128:
		for old in read_attacks.keys().slice(0,64): read_attacks.erase(old)
func projectile_threat(unit) -> Dictionary:
	var worst: Dictionary = {}
	var alive_ids: Dictionary = {}
	for arrow in unit.battle.projectiles:
		if not arrow.live: continue
		alive_ids[arrow.projectile_id]=true
		# Bomb awareness shares this cache; retain its one-time perception roll.
		if arrow.kind=="bomb": continue
		if arrow.source.team==unit.team or not CombatPerception.can_see_attack(unit,arrow.source,arrow.position,arrow.hidden_launch): continue
		var relative: Vector2 = arrow.position-unit.position
		var speed: Vector2 = arrow.velocity-unit.velocity
		if speed.length_squared()<1: continue
		var time: float = -relative.dot(speed)/speed.length_squared()
		if time<0 or time>.65 or time>arrow.lifetime: continue
		if not projectile_notices.has(arrow.projectile_id): projectile_notices[arrow.projectile_id]=unit.battle.rng.randf()
		var chance: float = .93 if unit.stance==CombatStance.CAUTIOUS else .50 if unit.stance==CombatStance.RUSH else .84
		var horizon: float = .56 if unit.stance==CombatStance.CAUTIOUS else .28 if unit.stance==CombatStance.RUSH else .46
		if projectile_notices[arrow.projectile_id]>chance or time>horizon: continue
		var miss: float = (relative+speed*time).length()
		if miss>arrow.hit_radius: continue
		var danger: float = (48-miss)/(time+.12)
		if worst.is_empty() or danger>worst.danger: worst={"arrow":arrow,"time":time,"danger":danger}
	for id in projectile_notices.keys():
		if not alive_ids.has(id): projectile_notices.erase(id)
	return worst
func movement(unit, delta: float) -> bool:
	if response.is_empty(): return false
	var source = unit.battle.find_unit(response.source_id)
	if source==null or not source.alive: return false
	var direction: Vector2 = Vector2.ZERO
	if response.mode == &"hold":
		if unit.battle.full_characters_enabled:return false
		unit.velocity=Vector2.ZERO
		return true
	if response.mode==&"dodge" and unit.battle.full_characters_enabled and (unit.state_value("shadowTime")>0 or unit.command_retreat_until>unit.battle.clock.elapsed or not unit.lost_sword.is_empty()):return false
	if response.mode==&"parry" and not response.started:
		# Keep moving normally until the blow is close; then plant and face it. A healthy unit
		# parrying a shot aimed at it steps towards the shooter instead.
		var stepping: bool=response.get("advance",false)
		if unit.battle.full_characters_enabled and unit.battle.clock.elapsed<float(response.get("parry_at",0))-.3 and not stepping:return false
		unit.facing=lerp_angle(unit.facing,(source.position-unit.position).angle(),minf(1,delta*8))
		direction=(source.position-unit.position).normalized()*.4 if stepping else (unit.position-source.position).normalized()*.15*.5
	elif response.mode==&"dodge" and unit.combat_state==CombatController.State.IDLE:
		var away: Vector2 = (unit.position-source.position).normalized()
		direction=Vector2.from_angle(source.combat.aim_angle+PI/2)*response.side if source.data.attack_range>100 else away*.8-away.orthogonal()*response.side
		direction=direction.limit_length(1)*(1.1 if unit.stance==CombatStance.CAUTIOUS else 1.0)
	else: return false
	if unit.battle.full_characters_enabled:
		unit.brain.movement_override="reaction_"+String(response.mode)
		unit.brain.steer(unit,direction*2 if response.mode==&"parry" else direction,delta,.5 if response.mode==&"parry" else 1)
		return true
	var before: Vector2 = unit.position
	unit.position=MovementController.clamp_position(unit.position+direction*unit.move_speed*delta)
	unit.velocity=(unit.position-before)/delta
	return true

static func reaction_serial(u) -> int:
	return -u.ultimate.serial-1 if u.battle.full_characters_enabled and not u.ultimate.cast.is_empty() else u.combat.attack_serial

static func melee_threat(u):
	for e in u.enemies():
		if e.combat_state!=CombatController.State.WINDUP or e.combat.attack_target!=null and e.combat.attack_target.team==e.team:continue
		var p: AttackData=e.combat.profile(e)
		if CombatPerception.can_see_attack(u,e,e.position,e.combat.hidden_launch) and e.combat.phase_time/p.windup>.35 and u.position.distance_to(e.position)<p.reach+60 and absf(wrapf((u.position-e.position).angle()-e.combat.aim_angle,-PI,PI))<p.cone+.2:return e
	return null
