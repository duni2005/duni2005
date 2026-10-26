class_name AreaEvaluator
extends RefCounted
## Deliberates over real hazards/support plus crowd risk; no synthetic abilities.
var initialized: bool = false
var safe_ref: String = ""
var last_risk: float = 0
var decision_counts: Dictionary = {"fight":0,"escape":0,"support":0}
var next_think: float = 0
var escape_until: float = 0
var goal: Vector2 = Vector2.ZERO
var supporting: bool = false
var in_support: bool = false
var phase: float = 0
var boldness: float = 1
var patience: float = 1
static func evaluate(unit, point: Vector2) -> Dictionary:
	var nearby: int = 0
	var pressure: float = 0
	var support: int = 0
	for other in unit.battle.units:
		if other==unit or not other.alive: continue
		var distance: float = point.distance_to(other.position)
		if other.team==unit.team:
			if distance<200: support+=1
		elif distance<210 and CombatPerception.can_perceive(unit,other):
			nearby+=1
			pressure+=clampf(CombatRules.attack(other)/maxf(1,CombatRules.attack(unit)),.5,1.7)*(1-distance/270)
	var crowd: float = maxf(0,pressure-support*.75-.65) if nearby>=3 else 0
	var protection: float = .1 if unit.invincible_remaining>1 else .7 if unit.shield_remaining>0 and unit.shield_hp>unit.max_hp*.2 else 1.0
	var hazard: float=unit.battle.zones.risk(unit,point) if unit.battle.full_characters_enabled else 0
	if unit.battle.full_characters_enabled and unit.state_value("shadowTime")>0:crowd=0
	return {"hazard":hazard*protection,"crowd":crowd*protection,"total":(crowd+hazard)*protection,"safe":[]}
func initialize(rng: RandomNumberGenerator) -> void:
	phase=rng.randf_range(0,TAU)
	boldness=rng.randf_range(.7,1.35)
	patience=rng.randf_range(.6,1.6)
	next_think=rng.randf_range(.12,.6)
func advance_minimal(unit, delta: float) -> bool:
	var now: float = unit.battle.clock.elapsed
	var risk: Dictionary = evaluate(unit,unit.position)
	if escape_until > now and risk.total < .15 and unit.position.distance_to(goal) < 70:
		escape_until=0
		next_think=now+unit.battle.rng.randf_range(.7,1.4)
	if now>=escape_until and now>=next_think:
		next_think=now+unit.battle.rng.randf_range(.45,.95)*patience
		if risk.total>.2 or (unit.battle.full_characters_enabled and unit.current_hp/unit.max_hp<.8 and not unit.battle.zones.safe_areas(unit).is_empty()):
			var best: Vector2 = unit.position
			var score: float = -INF
			for radius in [95,185,285]:
				for i in range(12):
					var point: Vector2 = (unit.position+Vector2.from_angle(phase+i*PI/6)*radius).clamp(Vector2(40,40),Vector2(760,760))
					var route: float = 0
					for step in range(1,5): route+=evaluate(unit,unit.position.lerp(point,step/4.0)).total/4
					var value: float = -risk.total*.1-evaluate(unit,point).total*3-route*.7-point.distance_to(unit.position)*.0025+(unit.battle.zones.support(unit,point) if unit.battle.full_characters_enabled else 0)
					if value>score: score=value;best=point
			var low: float = 1-unit.current_hp/unit.max_hp
			var alone: bool = not unit.battle.units.any(func(v): return v.alive and v!=unit and v.team==unit.team)
			var opening: bool = is_instance_valid(unit.target) and (unit.target.current_hp/unit.target.max_hp < .2 or unit.target.combat_state == CombatController.State.RECOVERY) and unit.position.distance_to(unit.target.position) < 150
			var fight: float = 1+boldness+(1.4 if opening else 0)+(1.4 if low<.35 else 0)+(1.4 if alone and risk.crowd > 0 else 0)+(StanceRules.RUSH_FIGHT if unit.stance==CombatStance.RUSH else 0)
			var support_gain: float=unit.battle.zones.support(unit,best) if unit.battle.full_characters_enabled else 0
			var escape: float = (.25+risk.total*(.7+low*1.6)+(StanceRules.CAUTIOUS_ESCAPE if unit.stance==CombatStance.CAUTIOUS else 0))*(StanceRules.RUSH_ESCAPE if unit.stance==CombatStance.RUSH else 1) if risk.total-evaluate(unit,best).total>.2 else 0
			if unit.battle.full_characters_enabled:
				fight+=(.8 if unit.battle.clock.elapsed<unit.brain.commit_until else 0)+(2 if unit.state_value("shadowTime")>0 else 0)
			var support_weight: float=support_gain*(.5+low*2)*(StanceRules.RUSH_SUPPORT if unit.stance==CombatStance.RUSH else 1) if support_gain>.65 else 0
			var roll: float=unit.battle.rng.randf()*(fight+escape+support_weight)
			if roll>=fight:
				supporting=roll>=fight+escape and support_weight>0
				goal=best
				escape_until=now+clampf(best.distance_to(unit.position)/maxf(1,unit.move_speed)+.5,1.6,4.5)+unit.battle.rng.randf_range(0,.5)
				next_think=escape_until
			else: next_think=now+unit.battle.rng.randf_range(.8,1.7)
	in_support=unit.battle.full_characters_enabled and supporting and unit.battle.zones.support(unit,unit.position)>.15
	if now>=escape_until or unit.taunted_until>now or unit.command_retreat_until>now: return false
	var before: Vector2 = unit.position
	var toward: Vector2 = goal-unit.position
	var direction: Vector2 = toward.normalized()*minf(1,toward.length()/35)
	var look: Vector2 = (unit.position+toward.normalized()*85).clamp(Vector2(35,35),Vector2(765,765))
	if evaluate(unit,look).total > risk.total+.45:
		var side: Vector2 = toward.normalized().orthogonal()
		if evaluate(unit,(unit.position+side*85).clamp(Vector2(35,35),Vector2(765,765))).total > evaluate(unit,(unit.position-side*85).clamp(Vector2(35,35),Vector2(765,765))).total: side *= -1
		direction=toward.normalized()*.2+side
	unit.position=MovementController.clamp_position(unit.position+direction.limit_length(1)*unit.move_speed*delta)
	unit.velocity=(unit.position-before)/delta
	return true

func offense_blocked(unit) -> bool:
	if escape_until<=unit.battle.clock.elapsed or unit.command_retreat_until>unit.battle.clock.elapsed or unit.taunted_until>unit.battle.clock.elapsed:return false
	return not (unit.battle.full_characters_enabled and supporting and in_support)
func support_value(u,area: Dictionary,point: Vector2) -> float:
	var center: Vector2=CharacterPersistence.vector(area.point);var radius: float=area.radius;var deficit: float=1-u.current_hp/u.max_hp
	if point.distance_to(center)>radius*.82:return 0
	var travel: float=maxf(0,u.position.distance_to(center)-radius*.65)/maxf(1,u.move_speed*u.ability.movement_rate(u))
	if travel+.25>=float(area.life):return 0
	match area.kind:
		"healing":return deficit*4.5
		"healer":return deficit*2.3
		"totem":return deficit*1.6
		"blessingReady":return deficit*3.5+(0 if u.state_value("paladinBlessingTime")>0 else .8)
		"armor":return (.25+deficit*.9)*(1 if u.enemies().any(func(e):return e.position.distance_to(point)<280) else .4)
		"pressure":return .35+deficit*.6 if u.enemies().any(func(e):return e.position.distance_to(center)<radius+80) else 0
	return deficit*.35+u.friends().filter(func(a):return a.position.distance_to(point)<160).size()*.15
func route_cost(u,point: Vector2) -> float:
	var value: float=0
	for i in range(1,5):value+=evaluate(u,u.position.lerp(point,i/4.0)).total/4
	return value
func goals(u) -> Dictionary:
	var options: Array[Dictionary]=[];var safe: Array[Dictionary]=u.battle.zones.safe_areas(u)
	for radius in [95,185,285]:
		for i in range(12):options.append({"point":(u.position+Vector2.from_angle(u.brain.phase+i*PI/6)*radius).clamp(Vector2(40,40),Vector2(760,760))})
	for area in safe:
		var center: Vector2=CharacterPersistence.vector(area.point);options.append({"point":(center+(u.position-center).normalized()*float(area.radius)*.45).clamp(Vector2(40,40),Vector2(760,760)),"safe":area})
	var escape: Dictionary={};var refuge: Dictionary={};var benefit: float=0;var best_score: float=-INF;var current: float=evaluate(u,u.position).total
	for option in options:
		var point: Vector2=option.point;var risk: float=evaluate(u,point).total;var route: float=route_cost(u,point);var support: float=0
		for area in safe:support=maxf(support,support_value(u,area,point))
		var score: float=-current*.1-risk*3-route*.7+support-point.distance_to(u.position)*.0025
		if score>best_score:escape=option;best_score=score
		if option.has("safe"):
			var value: float=support_value(u,option.safe,point)-risk*1.5-route*.3-point.distance_to(u.position)*.002
			if value>benefit:benefit=value;refuge=option
	return {"escape":escape,"refuge":refuge,"benefit":benefit,"improvement":current-evaluate(u,escape.point).total}
func reset_plan(u,wait: float=-1) -> void:
	escape_until=0;supporting=false;in_support=false;safe_ref="";goal=Vector2.ZERO
	next_think=u.battle.clock.elapsed+(u.battle.rng.randf_range(.7,1.4) if wait<0 else wait)
func advance(u,delta: float) -> bool:
	if not u.battle.full_characters_enabled:return advance_minimal(u,delta)
	var now: float=u.battle.clock.elapsed
	if u.unavailable() or u.stun_remaining>0 or u.evade_remaining>0 or not u.dodge_state.is_empty() or not u.ultimate.cast.is_empty() or u.ability.locked(u) or u.character_specific_state.get("bomberRush",false) or u.command_retreat_until>now or u.taunted_until>now or not u.lost_sword.is_empty():return false
	if u.combat_state!=CombatController.State.IDLE and (u.data.type_id in [6,18,9,11,8,14] or u.combat.counter):return false
	if not initialized:initialized=true;next_think=now+u.battle.rng.randf_range(.12,.6)
	var risk: Dictionary=evaluate(u,u.position);last_risk=risk.total
	if escape_until>0 and (now>=escape_until or supporting and u.current_hp/u.max_hp>=.8):reset_plan(u)
	if not supporting and escape_until>now and risk.total<.15 and u.position.distance_to(goal)<70:reset_plan(u)
	if supporting:
		var area: Dictionary={}
		for candidate in u.battle.zones.safe_areas(u):
			if candidate.ref==safe_ref:area=candidate;break
		if area.is_empty() or support_value(u,area,goal)<=.15:reset_plan(u,.25);return false
		var center: Vector2=CharacterPersistence.vector(area.point);goal=(center+(u.position-center).normalized()*float(area.radius)*.4).clamp(Vector2(40,40),Vector2(760,760));in_support=u.position.distance_to(center)<float(area.radius)*.76
	if now>=next_think:
		next_think=now+u.battle.rng.randf_range(.45,.95)*u.brain.patience
		var ahead: float=evaluate(u,(u.position+u.brain.heading*80).clamp(Vector2(35,35),Vector2(765,765))).total
		var useful: bool=u.battle.zones.safe_areas(u).any(func(a):return support_value(u,a,CharacterPersistence.vector(a.point))>.65)
		if risk.total>.2 or ahead>.75 or useful:
			var choices: Dictionary=goals(u);var low: float=1-u.current_hp/u.max_hp;var target=u.target;var opening: bool=target!=null and (target.current_hp/target.max_hp<.2 or target.combat_state==CombatController.State.RECOVERY) and u.position.distance_to(target.position)<150
			var fight: float=1+u.brain.boldness+(1.4 if low<.35 else 0)+(1.4 if u.friends().is_empty() and risk.crowd>0 else 0)+(1.4 if opening else 0)+(.8 if now<u.brain.commit_until else 0)+(StanceRules.RUSH_FIGHT if u.stance==CombatStance.RUSH else 0)+(2 if u.state_value("shadowTime")>0 else 0)
			var escape: float=(.25+maxf(risk.total,ahead)*(.7+low*1.6)+(StanceRules.CAUTIOUS_ESCAPE if u.stance==CombatStance.CAUTIOUS else 0))*(StanceRules.RUSH_ESCAPE if u.stance==CombatStance.RUSH else 1) if choices.improvement>.2 or ahead>risk.total+.6 else 0
			var support: float=choices.benefit*(.5+low*2)*(StanceRules.RUSH_SUPPORT if u.stance==CombatStance.RUSH else 1) if not choices.refuge.is_empty() and choices.benefit>.65 else 0
			var roll: float=u.battle.rng.randf()*(fight+escape+support)
			if roll<fight:reset_plan(u,u.battle.rng.randf_range(.8,1.7));decision_counts.fight+=1
			else:
				supporting=roll>=fight+escape and support>0;in_support=false;var selected: Dictionary=choices.refuge if supporting else choices.escape
				goal=selected.point;safe_ref=selected.safe.ref if supporting else "";var travel: float=u.position.distance_to(goal)/maxf(1,u.move_speed*u.ability.movement_rate(u))
				escape_until=now+(clampf(travel+2.4,2.4,6) if supporting else clampf(travel+.5,1.6,4.5)+u.battle.rng.randf_range(0,.5));next_think=escape_until
				u.brain.commit_until=0;u.brain.attack_decision.clear();decision_counts.support+=int(supporting);decision_counts.escape+=int(not supporting)
	if escape_until<=now:return false
	var forward: Vector2=(goal-u.position).normalized();var direction: Vector2=forward*minf(1,u.position.distance_to(goal)/35)
	if evaluate(u,(u.position+forward*85).clamp(Vector2(35,35),Vector2(765,765))).total>risk.total+.45:
		var options: Array[Vector2]=[forward.orthogonal(),-forward.orthogonal()];options.sort_custom(func(a,b):return evaluate(u,(u.position+a*85).clamp(Vector2(35,35),Vector2(765,765))).total<evaluate(u,(u.position+b*85).clamp(Vector2(35,35),Vector2(765,765))).total);direction=forward*.2+options[0]
	if supporting and in_support:direction-=forward.orthogonal()*u.brain.side*.2
	u.brain.movement_override="area_support" if supporting else "area_escape"
	u.brain.steer(u,direction,delta,.3 if u.combat_state==CombatController.State.WINDUP else .55 if u.combat_state!=CombatController.State.IDLE else 1);return true
