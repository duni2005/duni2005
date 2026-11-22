class_name BattleZones
extends RefCounted
## Real ability areas only. They are deliberately not part of room snapshots.
var entries: Array[Dictionary] = []
var area_serial: int = 0
func add(u,kind: String,point: Vector2,radius: float,life: float,extra: Dictionary={}) -> Dictionary:
	area_serial+=1
	var z: Dictionary={"area_id":area_serial,"source":u.actor_id(),"kind":kind,"point":CharacterPersistence.point(point),"radius":radius,"life":life,"tick":0.0,"contacts":{},"positions":{}}
	if u.battle.ultimate_actor==u:z["ultimate"]=true
	z.merge(extra,true);entries.append(z);return z
## Danger at `point` for `u`: enemy zones, bombs about to burst and enemy ultimates being cast.
## `hazards` (from risk_hazards) lets a caller that scores many points for the same unit in one
## frame gather them once; the result is the same either way.
func risk(u,point: Vector2,hazards=null) -> float:
	if hazards==null:hazards=risk_hazards(u)
	var result: float=0
	for h in hazards:
		match int(h[0]):
			RISK_RING:
				var diff: Vector2=point-h[1];var edge: float=maxf(absf(diff.x),absf(diff.y))
				result+=2.7 if absf(edge-float(h[2]))<float(h[3])+13 else .35 if edge<float(h[2]) else 0
			RISK_CIRCLE:
				var limit: float=h[2];var d: float=point.distance_to(h[1])
				if d<limit:result+=float(h[3])*(.65+.35*(1-d/limit))
			RISK_PATH:
				if PhysicalAttackSystem.point_distance(point,h[1],h[2])<float(h[3]):result+=3
	return result
const RISK_RING: int = 0
const RISK_CIRCLE: int = 1
const RISK_PATH: int = 2
## The hazards risk() weighs for `u`, in the order it adds them: [RISK_RING, center, radius, body],
## [RISK_CIRCLE, center, limit, weight] or [RISK_PATH, from, to, limit].
func risk_hazards(u) -> Array:
	var out: Array=[]
	var body: float=25*u.combat_scale()
	for z in entries:
		var source=u.battle.find_actor(z.source)
		if source==null or source.team==u.team or z.kind not in ["blackhole","tankFire","ring","oilFire","lava"]:continue
		var center: Vector2=CharacterPersistence.vector(z.point)
		var radius: float=z.radius
		if z.kind=="ring":out.append([RISK_RING,center,radius,body])
		else:out.append([RISK_CIRCLE,center,radius+body,3.0 if z.kind=="blackhole" else 2.5])
	for p in u.battle.projectiles:
		if not p.live or p.kind!="bomb" or float(p.metadata.get("fuse",2))>1.3 or p.source.team==u.team or p.hidden_launch or not CombatPerception.in_attack_view(u,p.position) or (p.source.alive and not CombatPerception.can_perceive(u,p.source)):continue
		var point_end: Vector2=p.position+p.velocity*float(p.metadata.get("flight",0))
		out.append([RISK_CIRCLE,point_end,float(p.metadata.blast_radius)+body,1.3+maxf(0,1-float(p.metadata.fuse))*2])
	for enemy in u.enemies():
		if enemy.ultimate.cast.is_empty() or not CombatPerception.can_see_attack(u,enemy,enemy.position,false):continue
		var cast: Dictionary=enemy.ultimate.cast
		var remaining: float=maxf(.05,float(cast.duration)-float(cast.t));var weight: float=1.8+maxf(0,1-remaining)*1.3
		var area: Dictionary=enemy.ability.cast_area(enemy,cast)
		if area.is_empty():continue
		if area.get("shape","")=="path":out.append([RISK_PATH,CharacterPersistence.vector(area.from),CharacterPersistence.vector(area.to),float(area.radius)+body])
		else:out.append([RISK_CIRCLE,CharacterPersistence.vector(area.point),float(area.radius)+body,weight])
	# 소행성 시련: a marked impact circle is danger for every side.
	for m in u.battle.trial_state.get("meteors",[]):out.append([RISK_CIRCLE,m.point,float(m.radius)+body,3.0])
	# 낙뢰 for everyone; 순교자 blasts for the player's side only; 화약통.
	for b in u.battle.trial_state.get("bolts",[]):out.append([RISK_CIRCLE,b.point,float(b.radius)+body,3.0])
	if u.original_team==0:
		for m in u.battle.trial_state.get("blasts",[]):out.append([RISK_CIRCLE,m.point,float(m.radius)+body,3.0])
	if not u.battle.field_objects.is_empty():FieldObjects.hazards(u.battle,body,out)
	return out
## 화염방사기 oil fire: whether `point` is on a puddle that has caught fire (one hit per tick
## however many puddles overlap there).
static func burning(z: Dictionary,point: Vector2,margin: float=0) -> bool:
	var age: float=float(z.total)-float(z.life)
	for puddle in z.puddles:
		if age>=float(puddle.ignite) and point.distance_to(CharacterPersistence.vector(puddle))<=float(puddle.r)+margin:return true
	return false
func safe_areas(u) -> Array[Dictionary]:
	var safe: Array[Dictionary]=[]
	for z in entries:
		var source=u.battle.find_actor(z.source)
		if source!=null and source.team==u.team and z.kind in ["healing","holy","tankFire","blackhole","ring"]:
			safe.append({"ref":"zone:%d"%z.get("area_id",0),"point":z.point,"radius":z.radius,"life":z.life,"kind":z.kind if z.kind in ["healing","holy"] else "pressure"})
	for friend in u.friends():
		if friend.data.type_id==5:safe.append({"ref":friend.actor_id()+":healer","point":CharacterPersistence.point(friend.position),"radius":225*friend.combat_scale(),"life":INF,"kind":"healer"})
		if friend.data.type_id==4:safe.append({"ref":friend.actor_id()+":armor","point":CharacterPersistence.point(friend.position),"radius":150*friend.combat_scale(),"life":INF,"kind":"armor"})
		if friend.vigor_totem_count>0:safe.append({"ref":friend.actor_id()+":totem","point":CharacterPersistence.point(friend.position),"radius":165*friend.combat_scale(),"life":INF,"kind":"totem"})
		if friend.data.type_id==16 and not friend.ultimate.cast.is_empty():safe.append({"ref":friend.actor_id()+":blessing","point":CharacterPersistence.point(friend.position),"radius":280*friend.combat_scale(),"life":maxf(0,float(friend.ultimate.cast.duration)-float(friend.ultimate.cast.t)),"kind":"blessingReady"})
	# 온기의 동상 warms every side alike.
	if not u.battle.field_objects.is_empty():FieldObjects.refuges(u.battle,safe)
	return safe
func support(u,point: Vector2) -> float:
	var best: float=0
	var deficit: float=1-u.current_hp/u.max_hp
	for area in safe_areas(u):
		var center: Vector2=CharacterPersistence.vector(area.point)
		if point.distance_to(center)>float(area.radius)*.82:continue
		var travel: float=maxf(0,u.position.distance_to(center)-float(area.radius)*.65)/maxf(1,u.move_speed*u.ability.movement_rate(u))
		if travel+.25>=float(area.life):continue
		var value: float=deficit*.35+u.friends().filter(func(a):return a.position.distance_to(point)<160).size()*.15
		match area.kind:
			"healing":value=deficit*4.5
			"healer":value=deficit*2.3
			"totem":value=deficit*1.6
			"blessingReady":value=deficit*3.5+(0 if u.state_value("paladinBlessingTime")>0 else .8)
			"armor":value=(.25+deficit*.9)*(1 if u.enemies().any(func(e):return e.position.distance_to(point)<280) else .4)
			"pressure":value=.35+deficit*.6 if u.enemies().any(func(e):return e.position.distance_to(center)<float(area.radius)+80) else 0
		best=maxf(best,value)
	return best
func advance(battle,dt: float) -> void:
	for z in entries.duplicate():
		var u=battle.find_actor(z.source)
		if u==null:entries.erase(z);continue
		z.life=float(z.life)-dt;z.tick=float(z.tick)+dt
		var point: Vector2=CharacterPersistence.vector(z.point)
		if z.kind=="galaxy":
			var target=battle.find_actor(z.get("target",""))
			if target==null or not target.alive:z.life=0
			else:
				point=target.position;z.point=CharacterPersistence.point(point)
				for p in battle.projectiles:
					if not p.live or p.source.team!=u.team or p.position.distance_to(point)>float(z.radius):continue
					var dir: Vector2=(point-p.position).normalized();var d: float=p.position.distance_to(point)
					var inward: float=2.2 if d<35 else 1.5+.7*d/float(z.radius)
					var desired: Vector2=dir*inward+dir.orthogonal()*(.1 if d<35 else .7)
					var turn: float=clampf(wrapf(desired.angle()-p.velocity.angle(),-PI,PI),-18*dt,18*dt)
					p.velocity=p.velocity.rotated(turn)
		elif z.kind=="blackhole":
			for enemy in u.enemies(false):
				var d: float=point.distance_to(enemy.position)
				if d<float(z.radius) and enemy.invincible_remaining<=0 and enemy.state_value("mirrorReflectTime")<=0 and enemy.evade_remaining<=0 and not ParryController.perfect(enemy) and not enemy.unavailable() and not enemy.is_dashing() and not ItemEffects.immovable(enemy):enemy.position=MovementController.clamp_position(enemy.position+(point-enemy.position).normalized()*(1-d/float(z.radius))*145*dt)
		elif z.kind=="discharge":
			z.age=float(z.age)+dt
			var radius: float=float(z.radius)*clampf(float(z.age)/.22,0,1)
			for enemy in u.enemies(false):
				if enemy.unavailable() or z.hits.has(enemy.actor_id()) or point.distance_to(enemy.position)>radius+24*enemy.combat_scale():continue
				z.hits[enemy.actor_id()]=true
				battle.damage_resolver.resolve(u,enemy,z.damage,{"dmg":&"ult","critical":true,"impulse":320,"attack_origin":point,"visible_hazard":true,"shock_stacks":2,"attack_token":z.source+"discharge"})
		elif z.kind=="ring":
			for enemy in u.enemies(false):
				if enemy.unavailable():continue
				var diff: Vector2=enemy.position-point;var edge: float=maxf(absf(diff.x),absf(diff.y))
				var old: float=z.positions.get(enemy.actor_id(),edge);z.positions[enemy.actor_id()]=edge
				var contact: bool=absf(edge-float(z.radius))<27 or (old-float(z.radius))*(edge-float(z.radius))<0
				var next: float=z.contacts.get(enemy.actor_id(),-INF)
				if contact and battle.clock.elapsed>=next and enemy.invincible_remaining<=0:
					z.contacts[enemy.actor_id()]=battle.clock.elapsed+.6
					var out: DamageOutcome=battle.damage_resolver.resolve(u,enemy,UnitStatTable.raw(u,&"ring"),{"dmg":&"ring","critical":false,"impulse":650,"angle":(-diff).angle(),"attack_origin":enemy.position-diff.normalized()*35})
					if out.hp_damage>0 and enemy.alive:KnockbackController.apply(enemy,-diff.normalized()*760,u)
		if z.kind=="bomb" and float(z.life)<=0:
			CharacterAbility.area_damage(u,point,float(z.radius),float(z.damage),float(z.impulse),{"critical":true,"attack_token":z.get("token","bomb")})
		if float(z.tick)>=.5:
			z.tick=float(z.tick)-.5
			for actor in battle.units:
				if not actor.alive or point.distance_to(actor.position)>float(z.radius):continue
				if z.kind=="healing" and actor.team==u.team:CharacterAbility.restore_hp(actor,1.75 if actor==u else 2.5,u)
				elif z.kind=="griffinStorm" and actor.team!=u.team:
					battle.damage_resolver.resolve(u,actor,float(z.damage),{"dmg":&"basic","critical":false,"impulse":0,"attack_origin":point,"visible_hazard":true,"attack_token":"%s%s%d"%[z.source,z.kind,int(z.area_id)]})
				elif z.kind=="galaxy" and actor.actor_id()==str(z.get("target","")):
					# 은하수: the marked enemy takes dark damage over time while the stars are drawn in.
					battle.damage_resolver.resolve(u,actor,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":false,"impulse":0,"attack_origin":point,"visible_hazard":true,"attack_token":z.source+z.kind})
				elif z.kind=="oilFire" and actor.team!=u.team and burning(z,actor.position,24*actor.combat_scale()):
					battle.damage_resolver.resolve(u,actor,float(z.damage),{"dmg":&"fire_zone","critical":false,"impulse":0,"attack_origin":actor.position,"visible_hazard":true,"attack_token":z.source+z.kind})
				elif z.kind=="lava" and actor.team!=u.team and actor.invincible_remaining<=0:
					# 용암 붓기 (enemy special strategy): damage over time and a burn stack per tick.
					battle.damage_resolver.resolve(u,actor,float(z.damage),{"dmg":&"strategy_lava","critical":false,"impulse":0,"attack_origin":actor.position,"visible_hazard":true,"attack_token":"%s%s%d"%[z.source,z.kind,int(z.area_id)]})
					if actor.alive:ElementEffects.add_burn(u,actor,1)
				elif z.kind in ["blackhole","tankFire"] and actor.team!=u.team:
					battle.damage_resolver.resolve(u,actor,UnitStatTable.raw(u,&"ult") if z.kind=="blackhole" else float(z.get("damage",0)),{"dmg":&"ult" if z.kind=="blackhole" else &"fire_zone","critical":false,"impulse":0,"attack_origin":point,"visible_hazard":true,"attack_token":z.source+z.kind})
		if float(z.life)<=0:entries.erase(z)
