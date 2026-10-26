class_name BattleBrain
extends RefCounted
## createBrain/initiative/spacing: transient deliberation, never snapshotted.
var mode: String = "observe"
var entry_plan: String
var think: float
var hold: float
var boldness: float
var caution: float
var reaction: float
var risk: float
var opportunism: float
var patience: float
var standoff: float
var side: float
var swerve: float
var phase: float
var tempo: float
var next_initiative_at: float
var commit_until: float = 0
var disengage_until: float = 0
var return_until: float = 0
var last_attack: float = 0
var punish_until: float = 0
var punish_actor: String = ""
var attack_decision: Dictionary = {}
var spacing: Dictionary = {}
var was_attacking: bool = false
var hesitations: int = 0
var rear_goal: Dictionary = {}
var rear_think_at: float = 0
var rear_target: String = ""
var last_danger: bool = false
var desired_direction: Vector2 = Vector2.ZERO
var steered_direction: Vector2 = Vector2.ZERO
var desired_distance: float = 0
var movement_override: String = ""
var ability_override: String = ""
var movement_style: String = ""
var goal: Vector2
var heading: Vector2 = Vector2.ZERO
var last_target: String = ""
var decisions: int = 0
## Cautious stance: where the unit last fought its target, and since when it has been waiting
## there for a target that ran out of reach.
var home: Vector2 = Vector2.ZERO
var home_set: bool = false
var home_since: float = -1
func initialize(r: RandomNumberGenerator) -> void:
	think=r.randf_range(.2,.65); hold=r.randf_range(.7,1.6)
	boldness=r.randf_range(.7,1.35); caution=r.randf_range(.8,1.4)
	reaction=r.randf_range(.14,.29); risk=r.randf_range(.65,1.45)
	opportunism=r.randf_range(.5,1.5); patience=r.randf_range(.6,1.6)
	standoff=r.randf_range(135,190); side=-1 if r.randf()<.5 else 1
	swerve=r.randf_range(.8,1.5); phase=r.randf_range(0,TAU); tempo=r.randf_range(.55,1.8)
	entry_plan=["observe","circle","feint","flank"][r.randi_range(0,3)]
	next_initiative_at=r.randf_range(.4,3.8)*tempo
	goal=Vector2(r.randf_range(100,700),r.randf_range(100,700))
func defensive(u) -> bool:
	return (u.stance==CombatStance.CAUTIOUS or u.data.tags.has("대치형") or u.mind.cautious(u)) and u.stance!=CombatStance.RUSH and u.state_value("shadowTime")<=0 and u.taunted_until<=u.battle.clock.elapsed
func turn_face(u,point: Vector2,dt: float) -> void:
	var turn: float=wrapf((point-u.position).angle()-u.facing,-PI,PI)
	u.facing+=clampf(turn,-.75*dt,.75*dt) if u.data.type_id==18 else turn*minf(1,dt*8)
func begin(u, enemy, duration: float=2.2, reason: String="initiative") -> void:
	var now: float=u.battle.clock.elapsed
	var closing: float=maxf(0,u.position.distance_to(enemy.position)-u.data.attack_profile.reach*.8)/maxf(1,u.move_speed*u.ability.movement_rate(u)*.85)
	duration=maxf(duration,minf(4.5,closing+1));hesitations=0
	commit_until=now+duration;disengage_until=0;return_until=0;mode="approach";hold=duration;last_target=enemy.actor_id()
	attack_decision={"actor":enemy.actor_id(),"at":now+intent_delay(u,reason),"reason":reason}
	next_initiative_at=commit_until+u.battle.rng.randf_range(.45,1.7)*tempo
func intent_delay(u,reason: String) -> float:
	if u.stance==CombatStance.RUSH:return u.battle.rng.randf_range(StanceRules.RUSH_INTENT_DELAY.x,StanceRules.RUSH_INTENT_DELAY.y)
	var delay: float=u.battle.rng.randf_range(.06,.42) if reason in ["counter","punish"] else u.battle.rng.randf_range(.06,.55) if reason=="pressure" else u.battle.rng.randf_range(.18,.95)
	return delay*tempo*StanceRules.pick(u,1,StanceRules.CAUTIOUS_INTENT,1)
func update_spacing(u,enemy) -> void:
	if enemy==null or not defensive(u):return
	var now: float=u.battle.clock.elapsed;var r: RandomNumberGenerator=u.battle.rng
	if spacing.get("actor","")!=enemy.actor_id():spacing={"actor":enemy.actor_id(),"distance":u.position.distance_to(enemy.position),"measured":now,"probe":next_initiative_at,"exit":0.0,"opening":0.0,"observed":null,"spent":null,"own":last_attack,"closing":0.0,"since":now}
	if now-float(spacing.measured)>=.08:
		spacing.closing=(float(spacing.distance)-u.position.distance_to(enemy.position))/(now-float(spacing.measured));spacing.distance=u.position.distance_to(enemy.position);spacing.measured=now
	var visible: bool=CombatPerception.can_see_attack(u,enemy,enemy.position,enemy.combat.hidden_launch)
	var attacking: bool=enemy.combat_state!=CombatController.State.IDLE or not enemy.ultimate.cast.is_empty()
	var serial: int=ThreatResponseController.reaction_serial(enemy)
	var healing: bool=enemy.combat.attack_target!=null and enemy.combat.attack_target.team==enemy.team
	if visible and attacking and not healing and (enemy.combat_state!=CombatController.State.RECOVERY or not enemy.ultimate.cast.is_empty()):spacing.observed=serial
	var spent: bool=spacing.observed!=null and (enemy.combat_state==CombatController.State.RECOVERY or not attacking or serial!=spacing.observed)
	if spent and spacing.spent!=spacing.observed and visible:
		spacing.spent=spacing.observed;spacing.opening=now+r.randf_range(1.25,1.9);spacing.probe=now+r.randf_range(.08,.6)*tempo
	if last_attack>float(spacing.own)+.000001:
		spacing.own=last_attack;spacing.exit=now+r.randf_range(1.1,1.7);spacing.opening=0;spacing.probe=float(spacing.exit)+r.randf_range(.65,1.35)
	spacing.threatening=ThreatResponseController.windup_threat(u)!=null
	spacing.mode="attack" if u.combat_state!=CombatController.State.IDLE else "withdraw" if now<float(spacing.exit) or now<disengage_until else "evade" if spacing.threatening else "counter" if now<float(spacing.opening) or now<punish_until or now<commit_until else "space"
func advance(u, enemy, _dt: float) -> void:
	update_spacing(u,enemy)
	# The source invokes threat response twice per tick (second invocation is read-idempotent).
	u.threat_response.advance(u)
	var now: float=u.battle.clock.elapsed;var r: RandomNumberGenerator=u.battle.rng
	if u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty():was_attacking=true;return
	if was_attacking:
		was_attacking=false;attack_decision.clear();next_initiative_at=maxf(now,disengage_until)+r.randf_range(.3,2.3)*tempo*StanceRules.pick(u,1,StanceRules.CAUTIOUS_INITIATIVE,1)
	if enemy==null or u.stun_remaining>0 or u.evade_remaining>0 or u.ability.locked(u) or not u.lost_sword.is_empty() or u.command_retreat_until>now:return
	if not attack_decision.is_empty():attack_decision.actor=enemy.actor_id()
	u.mind.pace(u,enemy)
	if not u.threat_response.response.is_empty() or u.combat.cooldown>0 or now<maxf(maxf(disengage_until,return_until),commit_until):return
	if defensive(u):
		if now<float(spacing.exit) or spacing.threatening or now<float(spacing.probe):return
		# Cautious stance: let the enemy swing first and answer its recovery (up to a wait limit).
		if u.stance==CombatStance.CAUTIOUS and spacing.spent==null and now-float(spacing.since)<StanceRules.CAUTIOUS_FIRST_WAIT:return
		if decide_initiative(u,enemy,r.randf_range(2.3,3.1)):spacing.probe=commit_until+r.randf_range(1,3);spacing.mode="counter"
		else:spacing.probe=next_initiative_at;spacing.mode="space"
	elif now>=next_initiative_at:decide_initiative(u,enemy,r.randf_range(1.7,2.8))
func decide_initiative(u,enemy,duration: float) -> bool:
	var now: float=u.battle.clock.elapsed;var r: RandomNumberGenerator=u.battle.rng
	var opening: bool=enemy.combat_state==CombatController.State.RECOVERY or enemy.combat.cooldown>.6
	if not opening and now-last_attack<=5.5 and hesitations<2 and r.randf()<clampf(.32*patience,.15,.48):
		hesitations+=1;entry_plan=["circle","feint","flank"][r.randi_range(0,2)];next_initiative_at=now+r.randf_range(.25,1.6)*tempo;commit_until=0;return false
	begin(u,enemy,duration);return true
func attack_ready(u, enemy) -> bool:
	if enemy==null:return false
	var now: float=u.battle.clock.elapsed
	if u.command_retreat_until>now:return false
	if u.stance==CombatStance.COVER and u.taunted_until<=now:
		var anchor=u.battle.find_actor(u.cover_actor_id)
		if anchor!=null and anchor.alive and anchor.position.distance_to(enemy.position)>240:return false
	if ParryController.perfect(u) or u.threat_response.response.get("mode",&"")==&"parry":return false
	if u.state_value("shadowTime")>0:return true
	var pressure: bool=u.stance==CombatStance.RUSH or u.taunted_until>now or u.mind.charging(u)
	if not pressure and (u.threat_response.response.get("mode",&"")==&"dodge" and now<float(u.threat_response.response.get("until",0)) or now>=commit_until and now>=punish_until or now<disengage_until or now<return_until):return false
	if attack_decision.is_empty():attack_decision={"actor":enemy.actor_id(),"at":now+intent_delay(u,"pressure" if pressure else "counter" if u.threat_response.response.get("mode",&"")==&"counter" else "punish" if now<punish_until else "initiative")}
	attack_decision.actor=enemy.actor_id()
	return now>=float(attack_decision.at)
func released(u) -> void:
	last_attack=u.battle.clock.elapsed;commit_until=0;attack_decision.clear();hold=u.battle.rng.randf_range(.7,1.4)
	disengage_until=0 if u.state_value("shadowTime")>0 else last_attack+u.battle.rng.randf_range(1.1,1.7) if defensive(u) else last_attack+u.battle.rng.randf_range(.6,1.3)
	mode="shadow" if u.state_value("shadowTime")>0 else "retreat"
	# Rush stance: no step back, straight on to the next attack.
	if u.stance==CombatStance.RUSH:disengage_until=0;mode="approach";return
	if u.data.tags.has("호위형"):return_until=last_attack+u.battle.rng.randf_range(.8,1.4)
func steer(u,direction: Vector2,dt: float,factor: float=1,style: String="archetype") -> void:
	desired_direction=direction;movement_style=style
	if style=="archetype" and u.ability.steer_override(u,direction,dt,factor):steered_direction=direction.limit_length(1);return
	var separation_radius: float=58 if style=="general" else 55 if style=="strategy" else 56
	var divisor: float=25 if style=="archetype" else 22
	for other in u.battle.units:
		if other==u or not other.alive or not CombatPerception.can_perceive(u,other):continue
		var d: float=u.position.distance_to(other.position)
		if d<separation_radius:
			var normal: Vector2=(u.position-other.position)/d if d>.01 else Vector2.RIGHT if u.battle_id<other.battle_id else Vector2.LEFT
			direction+=normal*(separation_radius-d)/divisor
	var p: Vector2=u.position;var wall: float=85 if style=="general" else 55
	for axis in range(2):
		if p[axis]<wall:direction[axis]+=(wall-p[axis])/(30 if style=="strategy" else wall)*(2 if style=="general" else 1)
		if p[axis]>800-wall:direction[axis]-=(p[axis]-800+wall)/(30 if style=="strategy" else wall)*(2 if style=="general" else 1)
	steered_direction=direction.limit_length(1)
	if not heading.is_finite():heading=Vector2.ZERO
	heading=heading.limit_length(1).lerp(steered_direction,1-exp(-dt*(9 if style=="strategy" else 8)))
	u.position=MovementController.clamp_position(p+heading*u.move_speed*u.ability.movement_rate(u)*factor*dt);u.velocity=(u.position-p)/dt
func move_precommit(u,enemy,dt: float) -> bool:
	var now: float=u.battle.clock.elapsed
	if enemy==null or u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty() or u.state_value("shadowTime")>0 or u.stance==CombatStance.RUSH or u.taunted_until>now or u.data.type_id in [6,11] or not u.friends().is_empty() and (u.data.tags.has("호위형") or u.data.type_id==5) or not u.lost_sword.is_empty() or u.command_retreat_until>now or u.threat_response.response.get("mode",&"")==&"counter" or now<commit_until or now<punish_until:return false
	var due: float=float(spacing.get("probe",next_initiative_at)) if defensive(u) else next_initiative_at
	if now>=due:return false
	var cautious: bool=u.stance==CombatStance.CAUTIOUS
	var d: float=u.position.distance_to(enemy.position);var f: Vector2=(enemy.position-u.position).normalized();var l: Vector2=-f.orthogonal()*(flank_side(u,enemy) if cautious else side)
	desired_distance=minf(u.data.attack_range*.9,310) if u.data.attack_range>100 else standoff
	var close: bool=d<desired_distance
	# Far from the fight, pre-engagement still closes in; it only lingers near its spacing ring.
	var far: bool=d>desired_distance+140 and u.stance!=CombatStance.CAUTIOUS
	var radial: float=clampf((d-desired_distance)/90,-1,0) if close else .85 if far else sin(now*2.5+phase)*.14 if entry_plan=="feint" else 0
	var direction: Vector2=f*radial+l*(StanceRules.CAUTIOUS_FLANK if cautious else .15 if entry_plan=="observe" else .8 if entry_plan=="flank" else .5)
	if cautious:direction+=formation_pull(u,enemy)
	var incoming: Dictionary=u.threat_response.projectile_threat(u)
	if not incoming.is_empty():direction+=-incoming.arrow.velocity.normalized().orthogonal()*side*.7
	movement_override="precommit_"+entry_plan;steer(u,direction,dt,1 if close or far else .5 if entry_plan=="observe" else .8);return true
func move_defensive(u,enemy,dt: float) -> bool:
	if enemy==null or not defensive(u) or u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty() or spacing.is_empty() or not u.lost_sword.is_empty() or u.command_retreat_until>u.battle.clock.elapsed:return false
	var cautious: bool=u.stance==CombatStance.CAUTIOUS
	var counter: bool=spacing.get("mode","")=="counter" and u.combat.cooldown<=.15 and not spacing.get("threatening",false)
	var f: Vector2=(enemy.position-u.position).normalized();var l: Vector2=-f.orthogonal()*(flank_side(u,enemy) if cautious and counter else side);var d: float=u.position.distance_to(enemy.position)
	var closing: bool=float(spacing.get("closing",0))>22
	desired_distance=u.data.attack_profile.reach*.65 if counter and u.data.attack_range<100 else minf(u.data.attack_range*.78,230) if counter else 320 if u.data.type_id==7 and u.state_value("reloadRemaining")>0 else 180 if u.data.attack_range<100 else clampf(u.data.attack_range*.94,190,310)
	var direction: Vector2=f*clampf((d-desired_distance-(45 if closing and not counter else 0))/65,-1.2,.9)+l*((StanceRules.CAUTIOUS_COUNTER_FLANK if cautious else .22) if counter else .4)
	if cautious and not counter and spacing.get("mode","")!="withdraw":direction+=formation_pull(u,enemy)
	# Cautious hit-and-run: right after its own attack it steps straight back.
	if cautious and not counter and u.battle.clock.elapsed<disengage_until:direction-=f*StanceRules.CAUTIOUS_SHOT_STEP
	var nearest=CharacterAbility.nearest(u,u.enemies());var near: float=u.position.distance_to(nearest.position) if nearest!=null else d
	if not counter and nearest!=null and nearest!=enemy and near<190:direction+=(u.position-nearest.position).normalized()*1.3
	var incoming: Dictionary=u.threat_response.projectile_threat(u)
	if not incoming.is_empty() and incoming.time<reaction*StanceRules.pick(u,1,StanceRules.CAUTIOUS_DEFENSIVE_SIDESTEP,1) and not counter:direction=direction*.45-incoming.arrow.velocity.normalized().orthogonal()*side
	if u.position.x<65 and direction.x<0 or u.position.x>735 and direction.x>0 or u.position.y<65 and direction.y<0 or u.position.y>735 and direction.y>0:
		var options: Array[Vector2]=[-f.orthogonal(),f.orthogonal()]
		options.sort_custom(func(a,b):return wall_clearance(u.position+a*100)>wall_clearance(u.position+b*100));direction=options[0]
	if u.data.type_id==5 and not u.friends().is_empty() and not counter and near>155:
		var friend=u.ability.support_anchor(u)
		if friend!=null and u.position.distance_to(friend.position)>130:direction+=(friend.position-u.position).normalized()*.7
	movement_override="defensive_"+String(spacing.get("mode","space"));var withdraw: bool=spacing.get("mode","")=="withdraw"
	steer(u,direction,dt,1.45 if counter else StanceRules.CAUTIOUS_BACKPEDAL if cautious and withdraw and not closing else 1.12 if closing or withdraw else 1);return true
static func wall_clearance(p: Vector2) -> float:return minf(minf(p.x,800-p.x),minf(p.y,800-p.y))
func rear_station(u,enemy) -> Dictionary:
	var friend=u.ability.support_anchor(u) if u.data.tags.has("의존형") else null
	var preferred: float=u.data.attack_range*StanceRules.pick(u,StanceRules.REAR_RANGE,StanceRules.CAUTIOUS_REAR_RANGE,StanceRules.REAR_RANGE)
	var options: Array[Vector2]=[u.position];var support_angle: float=0
	if friend!=null:
		var threat=CharacterAbility.nearest(friend,u.enemies());if threat==null:threat=enemy
		support_angle=(friend.position-threat.position).angle() if threat!=null else friend.facing+PI
		for off in [-.4,0,.4]:
			for distance in [110,155]:options.append((friend.position+Vector2.from_angle(support_angle+off)*distance).clamp(Vector2(55,55),Vector2(745,745)))
	if enemy!=null:
		for i in range(-4,5):options.append((enemy.position+Vector2.from_angle((u.position-enemy.position).angle()+i*.28)*preferred).clamp(Vector2(55,55),Vector2(745,745)))
	for i in range(8):options.append((u.position+Vector2.from_angle(i*PI/4)*100).clamp(Vector2(55,55),Vector2(745,745)))
	var best: Vector2=u.position;var best_score: float=-INF
	for point in options:
		var near: float=400 if u.enemies().is_empty() else INF
		for foe in u.enemies():near=minf(near,point.distance_to(foe.position))
		var gap: float=point.distance_to(enemy.position) if enemy!=null else preferred
		var occupied: int=u.friends().filter(func(a):return a.position.distance_to(point)<65).size()
		var score: float=-maxf(0,225-near)*2.8-absf(gap-preferred)*.2-maxf(0,gap-u.data.attack_range*.96)*2-point.distance_to(u.position)*.055-occupied*40-AreaEvaluator.evaluate(u,point).total*100
		if friend!=null:
			var behind: float=(point-friend.position).dot(Vector2.from_angle(support_angle))
			score-=maxf(0,90-behind)*1.5+absf(point.distance_to(friend.position)-125)*.7+maxf(0,point.distance_to(friend.position)-210)*2
		# Cautious back line keeps formation: stations far from every ally score lower.
		if u.stance==CombatStance.CAUTIOUS and not u.friends().is_empty():
			var mate: float=INF
			for a in u.friends():mate=minf(mate,point.distance_to(a.position))
			score-=maxf(0,mate-StanceRules.CAUTIOUS_COHESION)*StanceRules.CAUTIOUS_REAR_COHESION
		if score>best_score:best_score=score;best=point
	return {"point":best,"friend":friend.actor_id() if friend!=null else ""}
func move_rear(u,enemy,dt: float) -> bool:
	var now: float=u.battle.clock.elapsed
	if not u.data.tags.has("후열") and not (u.data.type_id==5 and u.data.tags.has("의존형")) or u.stance in [CombatStance.RUSH,CombatStance.COVER] or u.taunted_until>now or u.command_retreat_until>now or not u.ultimate.cast.is_empty() or u.character_specific_state.get("bomberRush",false):return false
	var nearest=CharacterAbility.nearest(u,u.enemies());var close: bool=nearest!=null and u.position.distance_to(nearest.position)<210
	var target_id: String=enemy.actor_id() if enemy!=null else ""
	var friend=u.battle.find_actor(rear_goal.get("friend",""))
	if rear_goal.is_empty() or now>=rear_think_at or rear_target!=target_id or not rear_goal.get("friend","").is_empty() and (friend==null or not friend.alive or friend.team!=u.team):
		rear_goal=rear_station(u,enemy);rear_target=target_id;rear_think_at=now+u.battle.rng.randf_range(.18,.4) if close else now+u.battle.rng.randf_range(.5,1)
	var goal_point: Vector2=rear_goal.point;var d: float=u.position.distance_to(goal_point)
	var direction: Vector2=(goal_point-u.position).normalized()*minf(1,d/35)
	# Settled at the station: a slow side-to-side sway instead of standing frozen.
	if d<30 and enemy!=null:direction+=(enemy.position-u.position).normalized().orthogonal()*sin(now*1.3+phase)*.35
	if close:direction+=(u.position-nearest.position).normalized()*clampf((210-u.position.distance_to(nearest.position))/85,0,1.4)
	# Cautious back line: shoot, step back, shoot again.
	if u.stance==CombatStance.CAUTIOUS and enemy!=null and now<disengage_until:direction+=(u.position-enemy.position).normalized()*StanceRules.CAUTIOUS_SHOT_STEP
	var incoming: Dictionary=u.threat_response.projectile_threat(u)
	if not incoming.is_empty() and incoming.time<reaction*StanceRules.pick(u,1,StanceRules.CAUTIOUS_DEFENSIVE_SIDESTEP,1) and u.combat_state==CombatController.State.IDLE:direction=direction*.4-incoming.arrow.velocity.normalized().orthogonal()*side
	desired_distance=u.data.attack_range*StanceRules.pick(u,StanceRules.REAR_RANGE,StanceRules.CAUTIOUS_REAR_RANGE,StanceRules.REAR_RANGE);movement_override="rear_station"
	steer(u,direction,dt,.3 if u.combat_state==CombatController.State.WINDUP else .55 if u.combat_state!=CombatController.State.IDLE else 1.1 if close else 1);return true
func cover_position(u,enemy) -> Vector2:
	var friends: Array=u.friends();var friend=u.battle.find_actor(u.cover_actor_id)
	if friend==null or not friend.alive or friend.team!=u.team:
		friends.sort_custom(func(a,b):return u.deployment_position.distance_to(a.deployment_position)<u.deployment_position.distance_to(b.deployment_position));friend=friends[0] if not friends.is_empty() else null;u.cover_actor_id=friend.actor_id() if friend!=null else ""
	var anchor=friend if friend!=null else u;var best: Vector2=anchor.position;var hit_time: float=INF
	for p in u.battle.projectiles:
		if not p.live or p.source.team==u.team or not CombatPerception.can_see_attack(u,p.source,p.position,p.hidden_launch):continue
		var speed: float=maxf(1,p.velocity.length());var time: float=(anchor.position-p.position).dot(p.velocity)/(speed*speed)
		if time<0 or time>1.2 or (p.position+p.velocity*time).distance_to(anchor.position)>p.hit_radius+28*anchor.combat_scale():continue
		if time<hit_time:hit_time=time;best=(anchor.position-p.velocity/speed*58).clamp(Vector2(35,35),Vector2(765,765))
	if hit_time<INF:return best
	var threats: Array=u.enemies().filter(func(e):return e.position.distance_to(anchor.position)<320);var threat=CharacterAbility.nearest(anchor,threats)
	if threat!=null:return (anchor.position+(threat.position-anchor.position).normalized()*minf(60,anchor.position.distance_to(threat.position)*.45)).clamp(Vector2(35,35),Vector2(765,765))
	if enemy!=null and not friends.is_empty() and friends.all(func(a):return a.stance==CombatStance.COVER) and u.battle.clock.elapsed<commit_until:return (anchor.position+(enemy.position-anchor.position).normalized()*65).clamp(Vector2(35,35),Vector2(765,765))
	return best
## Cautious stance: the side that curves the approach toward the target's flank (away from the
## direction it faces); beside or behind it, the unit keeps its own side.
func flank_side(u,enemy) -> float:
	var ahead: Vector2=Vector2.from_angle(enemy.facing)
	if (u.position-enemy.position).dot(ahead)<=0:return side
	var tangent: Vector2=-(enemy.position-u.position).normalized().orthogonal()
	return -1.0 if tangent.dot(ahead)>0 else 1.0
## Cautious stance: drift back toward the nearest ally beyond formation distance, and away from
## other enemies when two or more cover the spot. No bodyblocking (that is cover's job).
func formation_pull(u,enemy) -> Vector2:
	var pull: Vector2=Vector2.ZERO
	var friend=CharacterAbility.nearest(u,u.friends())
	if friend!=null:
		var gap: float=u.position.distance_to(friend.position)
		if gap>StanceRules.CAUTIOUS_COHESION:pull+=(friend.position-u.position).normalized()*minf(1,(gap-StanceRules.CAUTIOUS_COHESION)/100)*StanceRules.CAUTIOUS_COHESION_PULL
	if enemy!=null and enemy.position.distance_to(u.position)<StanceRules.CAUTIOUS_EXPOSURE:
		for e in u.enemies():
			if e!=enemy and e.position.distance_to(u.position)<StanceRules.CAUTIOUS_EXPOSURE:pull+=(u.position-e.position).normalized()*StanceRules.CAUTIOUS_EXPOSURE_PUSH
	return pull
## Cautious stance: a target that runs beyond reach + leash is not chased. The unit walks back
## to where it last fought and waits there; after a while it closes in again.
func move_home(u,enemy,dt: float) -> bool:
	var now: float=u.battle.clock.elapsed
	if enemy==null or u.taunted_until>now or u.command_retreat_until>now or u.combat_state!=CombatController.State.IDLE:return false
	var d: float=u.position.distance_to(enemy.position);var reach: float=u.data.attack_range+30*u.combat_scale()
	if d<=reach:home=u.position;home_set=true;home_since=-1;return false
	if not home_set or d<=reach+StanceRules.CAUTIOUS_LEASH:return false
	if home_since<0:home_since=now;commit_until=0;attack_decision.clear()
	if now-home_since>StanceRules.CAUTIOUS_HOME_TIME:home_set=false;home_since=-1;return false
	var gap: float=u.position.distance_to(home)
	var direction: Vector2=(home-u.position).normalized()*minf(1,gap/40) if gap>12 else Vector2.ZERO
	movement_override="cautious_return";steer(u,direction,dt,StanceRules.CAUTIOUS_BACKPEDAL,"strategy");return true
func move_stance(u,enemy,dt: float) -> bool:
	var now: float=u.battle.clock.elapsed
	if u.stance==CombatStance.CAUTIOUS and (move_home(u,enemy,dt) or move_rear(u,enemy,dt) or move_precommit(u,enemy,dt) or move_defensive(u,enemy,dt)):return true
	var taunting: bool=u.taunted_until>now and enemy!=null and enemy.source_member_id==u.taunted_member_id
	if u.stance==CombatStance.NORMAL and not taunting:return false
	if not u.lost_sword.is_empty() or u.data.type_id==6 and u.combat_state!=CombatController.State.IDLE:return false
	if u.stance==CombatStance.COVER and u.friends().is_empty() and not taunting:
		if move_precommit(u,enemy,dt):return true
		if u.data.type_id in [6,7,8,11]:return u.ability.modify_movement(u,enemy,dt)
		move_general(u,enemy,dt);return true
	var direction: Vector2;var factor: float=1
	if u.stance==CombatStance.COVER:
		var point: Vector2=cover_position(u,enemy);direction=(point-u.position).normalized()*(1 if u.position.distance_to(point)>18 else .12);movement_override="cover_intercept"
	elif enemy!=null:
		var f: Vector2=(enemy.position-u.position).normalized();var l: Vector2=-f.orthogonal();var d: float=u.position.distance_to(enemy.position);var reloading: bool=u.data.type_id==7 and u.state_value("reloadRemaining")>0
		if (u.stance==CombatStance.RUSH or taunting) and not reloading:
			desired_distance=minf(StanceRules.RUSH_RANGED_DISTANCE,u.data.attack_range*.5) if u.data.attack_range>100 else u.data.attack_range*.65
			# Straight at the target: only a faint sway (taunted units keep their weave).
			var sway: Vector2=l*(side*StanceRules.RUSH_SIDE+sin(now*3+u.movement_phase)*StanceRules.RUSH_SWAY) if u.stance==CombatStance.RUSH else l*(side*.25+sin(now*3+u.movement_phase)*.35)
			direction=f*(1 if d>desired_distance else .12)+sway;disengage_until=0;return_until=0;mode="approach";factor=StanceRules.RUSH_SPEED;movement_override="rush"
		else:
			var opening: bool=u.combat.cooldown<=0 and (now<commit_until or now<punish_until)
			desired_distance=330 if reloading else u.data.attack_range*.75 if opening else maxf(155,u.data.attack_range*.98);direction=f*clampf((d-desired_distance)/95,-1,1)+l*side*.6;movement_override="stance_spacing"
	else:direction=(goal-u.position).normalized()*.45
	if u.stance!=CombatStance.COVER:
		var incoming: Dictionary=u.threat_response.projectile_threat(u)
		if not incoming.is_empty() and u.combat_state==CombatController.State.IDLE and incoming.time<reaction*StanceRules.pick(u,1,StanceRules.CAUTIOUS_SIDESTEP,StanceRules.RUSH_SIDESTEP):
			var normal: Vector2=-incoming.arrow.velocity.normalized().orthogonal();var escape_side: float=signf((u.position-incoming.arrow.position).dot(normal));if escape_side==0:escape_side=side
			direction=direction*.2+normal*escape_side;factor=1.12
	if u.combat_state!=CombatController.State.IDLE:factor*=.25 if u.combat_state==CombatController.State.WINDUP else .5
	steer(u,direction,dt,factor,"strategy");return true
func movement(u,enemy,dt: float) -> void:
	movement_override="";ability_override=""
	if u.mind.active(u) and TacticalMind.role(u.data)==TacticalMind.FIXED:
		u.velocity=Vector2.ZERO;heading=Vector2.ZERO;movement_override="fixed"
		if enemy!=null:turn_face(u,enemy.position,dt)
		return
	if move_stance(u,enemy,dt):return
	if u.data.type_id==16 and u.ability.modify_movement(u,enemy,dt):ability_override="paladin_rally";return
	if u.data.type_id==14 and u.combat_state!=CombatController.State.IDLE:heading=Vector2.ZERO;u.velocity=Vector2.ZERO;ability_override="slash_combo";return
	if u.data.type_id in [19,18,15,23,29] and u.ability.modify_movement(u,enemy,dt):ability_override=u.data.display_name;return
	if move_rear(u,enemy,dt) or move_precommit(u,enemy,dt) or move_defensive(u,enemy,dt):return
	if u.data.type_id in [6,7,8,11] or u.data.type_id==10 and not u.lost_sword.is_empty():
		if u.ability.modify_movement(u,enemy,dt):ability_override=u.data.display_name;return
	move_general(u,enemy,dt)
func move_general(u,enemy,dt: float) -> void:
	var now: float=u.battle.clock.elapsed;var r: RandomNumberGenerator=u.battle.rng
	if u.state_value("shadowTime")<=0 and mode=="shadow":mode="approach";hold=0;think=0
	think-=dt;hold-=dt;var direction: Vector2;var rate: float=1
	if enemy==null:
		if u.position.distance_to(goal)<45 or hold<=0:goal=Vector2(r.randf_range(85,715),r.randf_range(85,715));hold=r.randf_range(1.5,3)
		direction=(goal-u.position).normalized()*.8
	else:
		var d: float=u.position.distance_to(enemy.position);var f: Vector2=(enemy.position-u.position).normalized();var l: Vector2=-f.orthogonal()*side
		var danger: bool=not enemy.ultimate.cast.is_empty() or u.enemies().filter(func(e):return e.position.distance_to(u.position)<145).size()>=3
		if danger and not last_danger:hold=0;think=0
		last_danger=danger
		if u.combat_state==CombatController.State.IDLE and think<=0 and now>=commit_until and (hold<=0 or last_target!=enemy.actor_id()):decide_mode(u,enemy)
		if u.state_value("shadowTime")>0:
			mode="shadow";disengage_until=0;return_until=0;direction=f*(1 if d>78 else -.55 if d<44 else .12)+l*.72
			if hold<=0:side*=-1;hold=r.randf_range(.35,.8)
		elif now<disengage_until:mode="retreat"
		desired_distance=u.data.attack_range*.88 if u.data.attack_range>100 else standoff
		match mode:
			"shadow":pass
			"approach":
				var committed: bool=now<commit_until;direction=f*(1.3 if committed else .95)+(-f.orthogonal())*(side*.16 if committed else side*.42+sin(now*(2.1+swerve)+phase)*.6)
				if u.data.attack_range>100 and d<u.data.attack_range*.8 and not committed:direction=f*.1+l
				if u.data.attack_range<100 and not committed and u.stance!=CombatStance.RUSH and u.taunted_until<=now:direction=f*clampf((d-standoff)/100,-.7,.8)+l*.5
			"retreat":direction=f*(-1 if d<desired_distance else .65 if d>desired_distance+90 else 0)+l*.6
			"feint":direction=f*(.7 if hold>.65 else -.8)+l*.55
			"flank":direction=((enemy.position-f*140+l*150).clamp(Vector2(70,70),Vector2(730,730))-u.position).normalized()
			"circle":direction=f*clampf((d-(u.data.attack_range*.76 if u.data.attack_range>100 else standoff))/120,-.65,.7)+l
			_:direction=f*clampf((d-desired_distance)/110,-.7,.5)+l*.35;rate=.65
		if u.data.type_id==5 and not u.friends().is_empty():
			var friend=u.ability.support_anchor(u)
			if friend!=null:
				var point: Vector2=(friend.position+(friend.position-enemy.position).normalized()*95).clamp(Vector2(55,55),Vector2(745,745))
				if u.position.distance_to(point)>45:direction=direction*.25+(point-u.position).normalized()*1.05
		if u.data.tags.has("호위형"):
			var friend=u.ability.support_anchor(u)
			if friend!=null:
				var anchor: Vector2=(friend.position+(enemy.position-friend.position).normalized()*65).clamp(Vector2(55,55),Vector2(745,745))
				var group: bool=u.friends().all(func(a):return a.data.tags.has("호위형"));var leader: int=u.battle_id
				for a in u.friends():leader=mini(leader,a.battle_id)
				if now>=commit_until and (now<return_until or u.position.distance_to(friend.position)>145 or not group and friend.position.distance_to(enemy.position)>250 and d<135):direction=direction*.15+(anchor-u.position).normalized()*1.2;rate=1.05;mode="guard"
				elif group and leader!=u.battle_id and u.position.distance_to(friend.position)>110:direction=direction*.5+(anchor-u.position).normalized()*.8
				elif mode=="guard":mode="approach";hold=.7
		var incoming: Dictionary=u.threat_response.projectile_threat(u)
		if not incoming.is_empty() and u.combat_state==CombatController.State.IDLE and incoming.time<reaction:
			var normal: Vector2=-incoming.arrow.velocity.normalized().orthogonal();var line_side: float=(u.position-incoming.arrow.position).dot(normal);var ex: Vector2=normal*(signf(line_side) if absf(line_side)>4 else side)
			var candidate: Vector2=u.position+ex*90
			if candidate.x<45 or candidate.x>755 or candidate.y<45 or candidate.y>755:ex=-ex
			direction=direction*.3+ex*.85;rate=1.04
		if u.combat_state!=CombatController.State.IDLE:rate*=.3 if u.combat_state==CombatController.State.WINDUP else .55
	movement_override="general_"+mode;steer(u,direction,dt,rate,"general")
func decide_mode(u,enemy) -> void:
	var now: float=u.battle.clock.elapsed;var d: float=u.position.distance_to(enemy.position);var far: bool=d>(u.data.attack_range*.95 if u.data.attack_range>100 else 220)
	var ready: bool=u.combat.cooldown<=.2;var close: int=u.enemies().filter(func(e):return e.position.distance_to(u.position)<160).size();var opening: bool=enemy.combat_state==CombatController.State.RECOVERY or enemy.combat.cooldown>.5
	var threat: bool=ThreatResponseController.melee_threat(u)!=null;var weights: Array[float]=[.25 if far else 1.1*caution,4 if far else (3 if opening else 1.5)*boldness if ready else .5,1.3+(.8 if close>1 else 0),(1.7 if close>1 else .7)+(2.5 if not enemy.ultimate.cast.is_empty() else 0),.6*opportunism if ready and not far else .1,(2.8 if u.current_hp/u.max_hp<.35 else 0)+(2 if threat else 0)+(1.5 if not ready and d<130 else .1)]
	if now>=next_initiative_at and u.combat.cooldown<=0:weights[1]+=3;weights[0]*=.4
	if u.data.attack_range>100 and d<u.data.attack_range*.68:weights[5]+=2
	var roll: float=u.battle.rng.randf()*float(weights.reduce(func(a,b):return a+b,0.0))
	for i in range(6):
		roll-=weights[i]
		if roll<=0:mode=["observe","approach","circle","flank","feint","retreat"][i];break
	hold=u.battle.rng.randf_range(.45,1.9)*patience
	if u.battle.rng.randf()<.28:side*=-1
	think=u.battle.rng.randf_range(.25,.6)*reaction*2;decisions+=1;last_target=enemy.actor_id()
func debug_snapshot(u) -> Dictionary:
	return {"target":u.target.actor_id() if u.target!=null else "","plan":mode,"entry":entry_plan,"intent":attack_decision.duplicate(true),"desired_distance":desired_distance,"desired_direction":CharacterPersistence.point(desired_direction),"steered_direction":CharacterPersistence.point(steered_direction),"heading":CharacterPersistence.point(heading),"danger":AreaEvaluator.evaluate(u,u.position).total,"safe":u.battle.zones.support(u,u.position),"reaction":u.threat_response.response.get("mode",&""),"stance":u.stance,"movement_override":movement_override,"ability_override":ability_override,"think":think,"hold":hold,"initiative":next_initiative_at,"commit":commit_until,"disengage":disengage_until}

func reset_clash(u,winner: bool) -> void:
	var wait: float=u.battle.rng.randf_range(.25,.8) if winner else u.battle.rng.randf_range(.65,2.1)
	attack_decision.clear();commit_until=0;punish_until=0;u.threat_response.response.clear();disengage_until=u.battle.clock.elapsed+wait*tempo;next_initiative_at=disengage_until+u.battle.rng.randf_range(.12,.7)
	if not spacing.is_empty():spacing.exit=disengage_until;spacing.probe=next_initiative_at;spacing.opening=0

func stance_changed(u) -> void:
	home_set=false;home_since=-1;hold=0;think=0;disengage_until=0;return_until=0;commit_until=0;punish_until=0;attack_decision.clear();u.threat_response.response.clear();next_initiative_at=u.battle.clock.elapsed+u.battle.rng.randf_range(.2,1.1)

func move_bomb_escape(u,dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty() or u.state_value("shadowTime")>0 or u.stance==CombatStance.COVER:return false
	var threats: Array=u.battle.projectiles.filter(func(p):return p.live and p.kind=="bomb" and p.source.team!=u.team and not p.hidden_launch and CombatPerception.in_attack_view(u,p.position) and float(p.metadata.get("fuse",2))<.8 and u.position.distance_to(p.position)<float(p.metadata.get("blast_radius",120))+30)
	threats.sort_custom(func(a,b):return float(a.metadata.fuse)<float(b.metadata.fuse))
	if threats.is_empty():return false
	var bomb=threats[0]
	if not u.threat_response.projectile_notices.has(bomb.projectile_id):u.threat_response.projectile_notices[bomb.projectile_id]=u.battle.rng.randf()
	if u.threat_response.projectile_notices[bomb.projectile_id]>StanceRules.pick(u,StanceRules.BOMB_NOTICE,StanceRules.CAUTIOUS_BOMB_NOTICE,StanceRules.RUSH_BOMB_NOTICE):return false
	var direction: Vector2=Vector2.from_angle(u.facing+PI) if u.position.distance_to(bomb.position)<1 else (u.position-bomb.position).normalized()
	movement_override="bomb_escape";steer(u,direction,dt);return true
