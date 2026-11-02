extends CharacterAbility
## 히어로 궁극기: rushes the enemy that dealt the most damage, grabs it (held at arm's length and
## stunned), draws the fist back for CHARGE seconds, then punches it with a shockwave.
const GRAB: float = .14
const CHARGE: float = .5
const HOLD_GAP: float = 58
func target_priority(_u,t,seen: Array) -> float:return -seen.filter(func(e):return e!=t and e.position.distance_to(t.position)<=180).size()
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<720
func ultimate_target(u):
	var enemies: Array=u.enemies();enemies.sort_custom(func(a,b):return a.damage_dealt>b.damage_dealt if a.damage_dealt!=b.damage_dealt else u.position.distance_to(a.position)<u.position.distance_to(b.position));return enemies[0] if not enemies.is_empty() else null
func release_ultimate(u,a,dt: float) -> bool:
	var t=u.battle.find_actor(a.target)
	if t==null or not t.alive or not CombatPerception.can_perceive(u,t):return true
	if a.get("phase","")!="punch":
		a.dashing=true;a["rush_time"]=float(a.get("rush_time",0))+dt
		if not dash_to(u,t.position,900,dt,75*u.combat_scale()) and float(a.rush_time)<2:return false
		a.dashing=false;a.phase="punch";a.punch_time=0.0;return false
	a.punch_time=float(a.punch_time)+dt
	if float(a.punch_time)<GRAB:a.angle=(t.position-u.position).angle()
	if float(a.punch_time)<GRAB+CHARGE:
		# Grab: the enemy is held in front of the hero while the fist is drawn back.
		if not t.unavailable() and not CharacterLifecycle.protected(t):
			if not a.get("grabbed",false):
				a.grabbed=true;StatusController.stun(t,GRAB+CHARGE+.05)
				u.battle.emit_combat_event(&"hero_grab",t.position,{"actor":u.actor_id(),"target":t.actor_id()})
			t.position=MovementController.clamp_position(u.position+Vector2.from_angle(float(a.angle))*HOLD_GAP*u.combat_scale());t.velocity=Vector2.ZERO;t.knockback_velocity=Vector2.ZERO
		u.facing=float(a.angle);return false
	u.combat.aim_angle=a.angle;melee(u,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","reach":155,"cone":.25,"active":.2,"impulse":720,"independent":true,"punch":true})
	u.battle.emit_combat_event(&"hero_punch",u.position+Vector2.from_angle(float(a.angle))*HOLD_GAP*u.combat_scale(),{"angle":float(a.angle),"actor":u.actor_id()})
	return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:return observer.position.distance_to(u.position)<170 or PhysicalAttackSystem.point_distance(observer.position,u.position,CharacterPersistence.vector(a.point))<100
func debug_state(u) -> String:return "Rescue %s" % u.hero_rescue_used
