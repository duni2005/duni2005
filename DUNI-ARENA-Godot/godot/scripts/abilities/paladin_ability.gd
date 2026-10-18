extends CharacterAbility
var rally_actor: String = ""
func aura(u) -> float:return 1+.05*u.friends().filter(func(a):return a.position.distance_to(u.position)<200).size()
func attack_factor(u) -> float:return aura(u)
func defense_factor(u) -> float:return aura(u)
func choose_target(u,enemies: Array):return nearest(support_anchor(u) if support_anchor(u)!=null else u,enemies)
func rally(u):
	var friends: Array=u.friends();var seen: Array=friends.duplicate();friends.sort_custom(func(a,b):return rally_score(u,a,seen)>rally_score(u,b,seen))
	if friends.is_empty():return null
	var previous=u.battle.find_actor(rally_actor)
	var target=previous if previous!=null and previous.alive and previous.team==u.team and rally_score(u,previous,seen)>=rally_score(u,friends[0],seen)-.7 else friends[0]
	rally_actor=target.actor_id();return target
func rally_score(u,t,friends: Array) -> float:return friends.filter(func(a):return a.position.distance_to(t.position)<220).size()*1.4+(1-t.current_hp/t.max_hp)*3.5-u.position.distance_to(t.position)*.003
func needs_rally(u) -> bool:
	var friend=rally(u)
	return friend!=null and u.ultimate_gauge>=100 and u.current_hp/u.max_hp>.25 and u.state_value("ultReadyAge")<6 and u.taunted_until<=u.battle.clock.elapsed and u.position.distance_to(friend.position)>140*u.combat_scale()
func modify_movement(u,_t,dt: float) -> bool:
	if u.combat_state!=CombatController.State.IDLE or not u.ultimate.cast.is_empty() or not needs_rally(u):return false
	var target=rally(u);var direction: Vector2=(target.position-u.position).normalized()
	for actor in u.battle.units:
		if actor==u or actor==target or not CombatPerception.can_perceive(u,actor):continue
		if u.position.distance_to(actor.position)<110 and PhysicalAttackSystem.point_distance(actor.position,u.position,target.position)<56 and (actor.position-u.position).dot(direction)>0:direction=direction*.35-direction.orthogonal()*u.brain.side*1.3;break
	u.brain.steer(u,direction,dt);return true
func can_attack(u,_t) -> bool:return not needs_rally(u)
func profile(u) -> AttackData:
	var p: AttackData=super.profile(u)
	if int(u.state_value("paladinSwings"))%2!=0:p.windup=.4;p.impulse=220;p.cone=1.5
	return p
func release_basic(u) -> void:
	var bash: bool=int(u.state_value("paladinSwings"))%2==0;u.set_state("paladinSwings",u.state_value("paladinSwings")+1)
	melee(u,CombatRules.attack(u)*(.65 if bash else 1.25),{"shield_bash":bash,"collision_stun":1 if bash else 0})
func can_ultimate(u,_t) -> bool:return not needs_rally(u) and (([u]+u.friends()).any(func(a):return u.position.distance_to(a.position)<280*u.combat_scale() and (a.current_hp/a.max_hp<.8 or u.enemies().any(func(e):return e.position.distance_to(a.position)<200))) or u.state_value("ultReadyAge")>4)
func release_ultimate(u,_a,_dt: float) -> bool:
	u.battle.zones.add(u,"holy",u.position,280*u.combat_scale(),10)
	for ally in [u]+u.friends():
		if u.position.distance_to(ally.position)<280*u.combat_scale():restore_hp(ally,ally.max_hp*.2,u);ally.set_state("paladinBlessingTime",10)
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func defensive_ultimate() -> bool:return true
func can_cast(u) -> bool:return not needs_rally(u)
func debug_state(u) -> String:return " / ".join(["paladinSwings", "paladinBlessingTime"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
