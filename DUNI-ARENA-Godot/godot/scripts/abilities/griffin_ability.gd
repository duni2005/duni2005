extends CharacterAbility
## 그리핀 (고정): never walks — it only moves by dashing. Basic attack: dashes at the target (at most
## DASH) during the windup, then raises a storm around itself for STORM_LIFE seconds that strikes
## enemies inside every half second (magic · wind · area · over time). Ultimate: dashes at the target,
## then throws a gust in a cone ahead (magic · wind · area) that knocks enemies far back; one that
## hits a wall or another unit while flying is stunned for GUST_STUN seconds.
const DASH: float = 220
const DASH_SPEED: float = 950
const STORM_RADIUS: float = 105
const STORM_LIFE: float = 2.0
const GUST_RANGE: float = 270
const GUST_CONE: float = .62
const GUST_STUN: float = 2.0
const GUST_IMPULSE: float = 900

## The windup is the dash: toward the target until DASH is spent or it is within reach.
func attack_tick(u,dt: float) -> bool:
	if u.combat_state!=CombatController.State.WINDUP:return false
	var t=u.combat.attack_target
	if t==null or not is_instance_valid(t) or not t.alive:return false
	var moved: float=float(u.combat.attack_metadata.get("dashed",0))
	if moved<DASH*u.combat_scale():
		var before: Vector2=u.position
		dash_to(u,t.position,DASH_SPEED,dt,52*u.combat_scale())
		u.combat.attack_metadata["dashed"]=moved+u.position.distance_to(before)
	u.combat.aim_angle=(t.position-u.position).angle();u.facing=u.combat.aim_angle
	return false
func release_basic(u) -> void:
	u.battle.zones.add(u,"griffinStorm",u.position,STORM_RADIUS*u.combat_scale(),STORM_LIFE,{"damage":UnitStatTable.raw(u,&"basic")})
	u.battle.emit_combat_event(&"griffin_storm",u.position,{"radius":STORM_RADIUS*u.combat_scale()})

func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<(DASH+GUST_RANGE*.8)*u.combat_scale()
func release_ultimate(u,a: Dictionary,dt: float) -> bool:
	var t=u.battle.find_actor(str(a.get("target","")))
	if a.get("phase","")!="gust":
		if t!=null and t.alive:
			a.dashing=true;a["rush"]=float(a.get("rush",0))+dt
			var before: Vector2=u.position
			var reached: bool=dash_to(u,t.position,DASH_SPEED,dt,70*u.combat_scale())
			a["moved"]=float(a.get("moved",0))+u.position.distance_to(before)
			a.angle=(t.position-u.position).angle();u.facing=float(a.angle)
			if not reached and float(a.moved)<DASH*u.combat_scale() and float(a.rush)<.6:return false
		a.dashing=false;a.phase="gust"
	gust(u,float(a.get("angle",u.facing)))
	return true
## The cone of wind: damage, a big knockback along the gust, and a stun on any collision in flight.
func gust(u,angle: float) -> void:
	var reach: float=GUST_RANGE*u.combat_scale()
	u.battle.emit_combat_event(&"griffin_gust",u.position,{"angle":angle,"radius":reach,"cone":GUST_CONE})
	for e in u.enemies(false):
		if e.unavailable():continue
		var off: Vector2=e.position-u.position
		var along: float=off.angle() if off.length()>4 else angle
		if off.length()>reach+20*e.combat_scale() or absf(wrapf(along-angle,-PI,PI))>GUST_CONE:continue
		u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":GUST_IMPULSE,"angle":along,"attack_origin":u.position,"visible_hazard":true,"collision_stun":GUST_STUN,"attack_token":"%s:gust%d"%[u.actor_id(),u.ultimate.serial]})
func ultimate_danger(u,observer,_a: Dictionary) -> bool:return observer.position.distance_to(u.position)<(DASH+GUST_RANGE)*u.combat_scale()
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":(DASH+GUST_RANGE)*u.combat_scale()}
