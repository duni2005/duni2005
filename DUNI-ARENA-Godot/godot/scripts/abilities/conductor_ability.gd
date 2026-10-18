extends CharacterAbility
## 기관사: never attacks; wanders while charging. Ultimate runs a locomotive straight across the
## whole map along the line through the most enemies. Enemies take heavy damage and are thrown
## aside; allies on the track are also knocked back and take a little damage.
const TRAIN_SPEED: float = 1500
const TRAIN_LENGTH: float = 170
const TRACK_HALF_WIDTH: float = 46
const ENEMY_DAMAGE: float = 85
const ALLY_DAMAGE: float = 6
const ANGLES: Array = [0.0, PI * .5, PI * .25, PI * .75]
func can_attack(_u,_t) -> bool:return false
func tick(u,dt: float) -> void:
	# No damage dealt means no damage-based charge; the crew stokes the boiler instead.
	u.ultimate.gain(u,3.5*dt)
func can_ultimate(u,_t) -> bool:return not u.enemies(false).is_empty()
func ultimate_target(u):return nearest(u,u.enemies(false))
func ultimate_point(u,_point: Vector2) -> Vector2:
	# Pick the track (through an enemy, at one of four headings) that covers the most enemies.
	var best_score: int=-1;var best: Vector2=u.position;var best_angle: float=0
	for e in u.enemies(false):
		for angle in ANGLES:
			var dir: Vector2=Vector2.from_angle(angle);var score: int=0
			for other in u.enemies(false):
				if absf((other.position-e.position).cross(dir))<TRACK_HALF_WIDTH+20:score+=1
			if score>best_score:best_score=score;best=e.position;best_angle=angle
	u.set_state("trainAngle",best_angle)
	return best
func release_ultimate(u,a,dt: float) -> bool:
	if not a.has("track"):
		var angle: float=u.state_value("trainAngle");var dir: Vector2=Vector2.from_angle(angle)
		var through: Vector2=CharacterPersistence.vector(a.point)
		# Enter from the map edge behind the line's midpoint, cross to the far edge.
		a["track"]={"x":through.x,"y":through.y,"angle":angle};a["s"]=-620.0;a["hits"]={}
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
	if float(a.s)<620+TRAIN_LENGTH:return false
	u.set_state("trainFx",0);return true
func ultimate_danger(_u,observer,a: Dictionary) -> bool:
	var point: Vector2=CharacterPersistence.vector(a.get("point",{}),observer.position)
	return absf((observer.position-point).cross(Vector2.from_angle(float(a.get("angle",0)))))<TRACK_HALF_WIDTH+40
func defensive_ultimate() -> bool:return true
