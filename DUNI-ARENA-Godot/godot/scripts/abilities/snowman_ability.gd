extends CharacterAbility
## 눈사람: clubs with an ice club (magic · ice · melee). Ultimate: gathers itself for CHARGE_TIME,
## then rolls a giant snowball forward. The ball rolls through enemies (magic · ice · area) and
## drags everyone it hits along its path; when it reaches a wall it bursts (magic · ice · area ·
## explosion) and puts BURST_FROST frost stacks on everyone caught in the blast.
const CHARGE_TIME: float = .8
const BALL_SPEED: float = 420
const BALL_RADIUS: float = 34
const BALL_GROWTH: float = 22
const BURST_RADIUS: float = 115
const BURST_FROST: int = 3
const MAX_ROLL: float = 3.5

func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<520*u.combat_scale()
func release_ultimate(u,a: Dictionary,dt: float) -> bool:
	if not a.has("charge"):
		a["charge"]=0.0
		u.battle.emit_combat_event(&"snow_charge",u.position,{"actor_id":u.battle_id,"time":CHARGE_TIME,"angle":float(a.angle)})
	a.charge=float(a.charge)+dt;u.velocity=Vector2.ZERO
	if float(a.charge)<CHARGE_TIME:return false
	var start: Vector2=u.position+Vector2.from_angle(float(a.angle))*44*u.combat_scale()
	u.character_specific_state["snowball"]={"x":start.x,"y":start.y,"sx":start.x,"sy":start.y,"angle":float(a.angle),"rolled":0.0,"hit":[],"t":0.0}
	return true
## The ball rolls on in tick; dragged enemies stay pressed against its front.
func tick(u,dt: float) -> void:
	var ball: Dictionary=u.character_specific_state.get("snowball",{})
	if ball.is_empty():return
	var dir: Vector2=Vector2.from_angle(float(ball.angle));var r: float=radius(u,ball)
	var at: Vector2=Vector2(float(ball.x),float(ball.y))+dir*BALL_SPEED*dt
	ball.t=float(ball.t)+dt;ball.rolled=float(ball.rolled)+BALL_SPEED*dt
	var wall: bool=at.x<20+r or at.x>ArenaMap.side-20-r or at.y<20+r or at.y>ArenaMap.side-20-r or float(ball.t)>MAX_ROLL
	at=at.clamp(Vector2(20+r,20+r),ArenaMap.hi(20+r));ball.x=at.x;ball.y=at.y
	for e in u.enemies(false):
		if e.unavailable() or not e.alive or e.battle_id in ball.hit or e.position.distance_to(at)>r+18*e.combat_scale():continue
		ball.hit.append(e.battle_id)
		u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":0,"angle":float(ball.angle),"attack_origin":at,"visible_hazard":true,"attack_token":"%s:ball%d:%d"%[u.actor_id(),u.ultimate.serial,e.battle_id]})
	# Everyone caught rides along in front of the ball.
	for id in ball.hit:
		var e=_unit(u,int(id))
		if e==null or not e.alive:continue
		e.position=MovementController.clamp_position(at+dir*(r*.7)+dir.orthogonal()*(fmod(int(id)*37.0,1.0)-.5)*r*.8)
		e.velocity=Vector2.ZERO;e.knockback_velocity=Vector2.ZERO;StatusController.stun(e,.2)
	if wall:burst(u,at,ball)
## Presentation only: frost chips where the ice club lands.
func melee_hit(u,_attack,t,_out) -> void:u.battle.emit_combat_event(&"snow_club",t.position,{"actor_id":u.battle_id,"angle":(t.position-u.position).angle()})
static func radius(u,ball: Dictionary) -> float:return (BALL_RADIUS+BALL_GROWTH*clampf(float(ball.get("rolled",0))/600.0,0,1))*u.combat_scale()
static func _unit(u,id: int):
	for v in u.battle.units:
		if v.battle_id==id:return v
	return null
func burst(u,at: Vector2,_ball: Dictionary) -> void:
	u.character_specific_state.erase("snowball")
	var r: float=BURST_RADIUS*u.combat_scale()
	u.battle.emit_combat_event(&"snowball_burst",at,{"actor_id":u.battle_id,"radius":r})
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(at)>r+22*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"burst"),{"dmg":&"burst","critical":true,"impulse":300,"angle":(e.position-at).angle(),"attack_origin":at,"visible_hazard":true,"attack_token":"%s:burst%d"%[u.actor_id(),u.ultimate.serial]})
		if e.alive and out.hp_damage+out.shield_absorbed>0:ElementEffects.add_frost(u,e,BURST_FROST)
func ultimate_danger(u,observer,a: Dictionary) -> bool:
	var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)));var offset: Vector2=observer.position-u.position
	return offset.dot(dir)>0 and absf(offset.cross(dir))<BALL_RADIUS+BALL_GROWTH+40
func cast_area(u,a: Dictionary) -> Dictionary:
	var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)))
	return {"shape":"path","from":CharacterPersistence.point(u.position),"to":CharacterPersistence.point(MovementController.clamp_position(u.position+dir*1200)),"radius":(BALL_RADIUS+BALL_GROWTH)*u.combat_scale()}
