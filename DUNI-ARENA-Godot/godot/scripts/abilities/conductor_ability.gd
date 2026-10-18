extends CharacterAbility
## 기관사: never attacks; wanders while charging. Ultimate summons a locomotive at the map edge
## behind the conductor that charges toward the enemies and on across the whole map. Enemies on
## the track take heavy damage and are thrown aside; allies are knocked back and take a little damage.
const TRAIN_SPEED: float = 1400
const TRAIN_LENGTH: float = 270
const TRACK_HALF_WIDTH: float = 58
const ENEMY_DAMAGE: float = 85
const ALLY_DAMAGE: float = 6
func can_attack(_u,_t) -> bool:return false
func tick(u,dt: float) -> void:
	# No damage dealt means no damage-based charge; the crew stokes the boiler instead.
	u.ultimate.gain(u,3.5*dt)
func can_ultimate(u,t) -> bool:return t!=null
func ultimate_target(u):
	# Aim at the enemy whose line from the conductor runs through the most enemies.
	var best=null;var best_score: int=-1
	for e in u.enemies(false):
		if e.unavailable():continue
		var dir: Vector2=(e.position-u.position).normalized();var score: int=0
		for other in u.enemies(false):
			var offset: Vector2=other.position-u.position
			if offset.dot(dir)>0 and absf(offset.cross(dir))<TRACK_HALF_WIDTH+20:score+=1
		if score>best_score:best_score=score;best=e
	return best
## Track parameter range [from, to] where center + dir * s lies inside the 800x800 arena.
func track_span(center: Vector2,dir: Vector2) -> Vector2:
	var lo: float=-INF;var hi: float=INF
	for axis in [0,1]:
		if absf(dir[axis])<.0001:continue
		var a: float=-center[axis]/dir[axis];var b: float=(800-center[axis])/dir[axis]
		lo=maxf(lo,minf(a,b));hi=minf(hi,maxf(a,b))
	return Vector2(lo,hi)
func release_ultimate(u,a,dt: float) -> bool:
	if not a.has("track"):
		var angle: float=float(a.angle);var span: Vector2=track_span(u.position,Vector2.from_angle(angle))
		a["track"]={"x":u.position.x,"y":u.position.y,"angle":angle,"from":span.x,"to":span.y};a["s"]=span.x;a["hits"]={}
		u.set_state("trainFx",1)
	var track: Dictionary=a.track;var dir: Vector2=Vector2.from_angle(float(track.angle));var center: Vector2=Vector2(float(track.x),float(track.y))
	a.s=float(a.s)+TRAIN_SPEED*dt
	var head: Vector2=center+dir*float(a.s);var tail: Vector2=head-dir*TRAIN_LENGTH
	var hits: Dictionary=a.hits
	for v in u.battle.units:
		if not v.alive or v==u or v.unavailable() or hits.has(v.actor_id()):continue
		if PhysicalAttackSystem.point_distance(v.position,tail,head)>TRACK_HALF_WIDTH+20*v.combat_scale():continue
		hits[v.actor_id()]=true
		var side: Vector2=dir.orthogonal()*(1.0 if (v.position-center).cross(dir)<0 else -1.0)
		if v.team==u.team:
			u.battle.damage_resolver.resolve(u,v,ALLY_DAMAGE,{"collision":true,"impulse":0})
			KnockbackController.apply(v,side*520+dir*180,u)
		else:
			u.battle.damage_resolver.resolve(u,v,ENEMY_DAMAGE,{"impulse":0,"visible_hazard":true})
			KnockbackController.apply(v,side*760+dir*320,u)
	if float(a.s)<float(track.to)+TRAIN_LENGTH:return false
	u.set_state("trainFx",0);return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:
	var offset: Vector2=observer.position-u.position;var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)))
	return absf(offset.cross(dir))<TRACK_HALF_WIDTH+40
func defensive_ultimate() -> bool:return true
