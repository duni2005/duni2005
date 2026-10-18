extends CharacterAbility
func on_spawn(u) -> void:
	var saint=nearest(u,u.friends());u.saint_actor=saint.actor_id() if saint!=null else "";u.set_state("saintFallen",false)
func saint(u):
	var t=u.battle.find_actor(u.saint_actor)
	return t if t!=null and t.alive and t.team==u.team and not u.character_specific_state.get("saintFallen",false) else null
func tick(u,_dt: float) -> void:
	if not u.saint_actor.is_empty() and saint(u)==null and not u.character_specific_state.get("saintFallen",false):u.set_state("saintFallen",true);u.brain.commit_until=u.battle.clock.elapsed+2.5;u.brain.disengage_until=0
func attack_factor(u) -> float:return 1.3 if u.character_specific_state.get("saintFallen",false) else 1
func attack_rate(u) -> float:return attack_factor(u)
func choose_target(u,enemies: Array):return nearest(saint(u) if saint(u)!=null else u,enemies)
func modify_movement(u,t,dt: float) -> bool:
	var s=saint(u)
	if s==null:
		if t==null:u.brain.move_general(u,t,dt);return true
		var d: float=u.position.distance_to(t.position);var dir: Vector2=(t.position-u.position).normalized()
		u.brain.steer(u,dir*(1.2 if d>58 else -.3 if d<40 else .15)-dir.orthogonal()*u.brain.side*.18,dt,.35 if u.combat_state==CombatController.State.WINDUP else .6 if u.combat_state==CombatController.State.ACTIVE else 1.12);return true
	var angle: float=(t.position-s.position).angle() if t!=null else s.facing
	var dir: Vector2=Vector2.from_angle(angle);var point: Vector2=(s.position-dir*70-dir.orthogonal()*u.brain.side*58).clamp(Vector2(45,45),Vector2(755,755))
	var move: Vector2=(point-u.position).normalized()*minf(1,u.position.distance_to(point)/50)
	if t!=null and u.position.distance_to(s.position)<120 and s.position.distance_to(t.position)<170 and u.battle.clock.elapsed<u.brain.commit_until:move=move*.25+(t.position-u.position).normalized()*.8
	if u.position.distance_to(s.position)>145:move=(s.position-u.position).normalized()
	u.brain.steer(u,move,dt,.3 if u.combat_state==CombatController.State.WINDUP else .6 if u.combat_state==CombatController.State.ACTIVE else 1);return true
func ultimate_target(u):return saint(u)
func can_ultimate(_u,t) -> bool:return t!=null and t.data.ultimate_windup>=0 and t.ultimate_gauge<100 and t.ultimate.cast.is_empty()
func release_ultimate(u,a,_dt: float) -> bool:
	var t=saint(u)
	if t!=null and t.actor_id()==a.target:t.ultimate.gain(t,20*(1-clampi(5-t.energy,0,5)*.07 if not t.source_member_id.is_empty() else 1))
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func defensive_ultimate() -> bool:return true
func can_cast(u) -> bool:return can_ultimate(u,saint(u))
func debug_state(u) -> String:return " / ".join(["saintFallen"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
