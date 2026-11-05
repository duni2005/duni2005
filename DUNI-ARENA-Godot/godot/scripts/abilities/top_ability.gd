extends CharacterAbility
## 팽이: never stops. It spins forward without end and bounces off every unit and wall it touches,
## changing direction each time; every enemy it touches takes a hit (physical · melee · damage
## over time · wind), at most once per HIT_GAP each. Passive 회전 가속: attack speed turns into
## move speed instead (it has no attack swings). Ultimate 폭주 회전: for BOOST_TIME seconds it
## spins BOOST_SPEED times faster and hits harder (the ultimate damage key).
const HIT_GAP: float = .4
const BOOST_TIME: float = 5
const BOOST_SPEED: float = 1.6
## Pull toward the nearest enemy (radians per second) once it is farther than HOMING_RANGE, so it
## comes back into the fight instead of wandering off (close in it runs straight and bounces).
const HOMING: float = 1.8
const HOMING_RANGE: float = 200
const TOUCH: float = 40

func on_spawn(u) -> void:
	if not u.character_specific_state.has("topAngle"):u.set_state("topAngle",u.battle.rng.randf_range(-PI,PI))
func can_attack(_u,_t) -> bool:return false
func requires_initiative(_u=null) -> bool:return false
## 회전 가속: attack speed (items, wind stacks…) speeds up the spin instead.
func movement_rate(u) -> float:return EquipmentCombatEffects.attack_speed(u)*(BOOST_SPEED if u.state_value("topBoost")>0 else 1.0)
func tick(u,dt: float) -> void:
	if u.state_value("topBoost")>0:u.set_state("topBoost",maxf(0,u.state_value("topBoost")-dt))
## Called from MovementController instead of the brain: straight on, bouncing off walls and units.
func modify_movement(u,_target,dt: float) -> bool:
	var angle: float=u.state_value("topAngle");var dir: Vector2=Vector2.from_angle(angle)
	var near=nearest(u,u.enemies(false).filter(func(e):return not e.unavailable()))
	if near!=null and u.position.distance_to(near.position)>HOMING_RANGE*u.combat_scale():
		var want: float=(near.position-u.position).angle()
		angle=angle+clampf(wrapf(want-angle,-PI,PI),-HOMING*dt,HOMING*dt);dir=Vector2.from_angle(angle)
	var speed: float=u.move_speed*movement_rate(u)
	var before: Vector2=u.position;var at: Vector2=before+dir*speed*dt
	# Walls: reflect the matching axis.
	var low: float=MovementController.MIN_POSITION;var high: float=MovementController.MAX_POSITION
	if at.x<=low or at.x>=high:dir.x=-dir.x;u.battle.emit_combat_event(&"top_bounce",MovementController.clamp_position(at),{"actor_id":u.battle_id})
	if at.y<=low or at.y>=high:dir.y=-dir.y;u.battle.emit_combat_event(&"top_bounce",MovementController.clamp_position(at),{"actor_id":u.battle_id})
	at=MovementController.clamp_position(at)
	# Units: bounce off the first one touched (reflect about the contact normal); enemies get hit.
	var reach: float=TOUCH*u.combat_scale()
	for other in u.battle.units:
		if other==u or not other.alive or other.unavailable():continue
		var gap: Vector2=at-other.position
		if gap.length()>reach+18*other.combat_scale():continue
		var normal: Vector2=gap.normalized() if gap.length()>.01 else -dir
		if dir.dot(normal)<0:dir=dir.bounce(normal);u.battle.emit_combat_event(&"top_bounce",other.position+normal*18*other.combat_scale(),{"actor_id":u.battle_id})
		if other.team!=u.team:_hit(u,other)
		break
	u.set_state("topAngle",dir.angle());u.position=at;u.velocity=(at-before)/maxf(dt,.0001);u.facing=dir.angle()
	return true
func _hit(u,e) -> void:
	var key: String="topHit%d"%e.battle_id
	if u.battle.clock.elapsed<u.state_value(key):return
	u.set_state(key,u.battle.clock.elapsed+HIT_GAP)
	var boosted: bool=u.state_value("topBoost")>0;var dmg: StringName=&"ult" if boosted else &"basic"
	u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,dmg),{"dmg":dmg,"critical":true,"impulse":260 if boosted else 180,"angle":(e.position-u.position).angle(),"attack_origin":u.position,"attack_token":"%s:top%d:%d"%[u.actor_id(),e.battle_id,int(u.battle.clock.elapsed*10)]})
	u.battle.emit_combat_event(&"top_hit",e.position,{"actor_id":u.battle_id,"boost":boosted,"angle":(e.position-u.position).angle()})
func can_ultimate(u,t) -> bool:return t!=null and u.state_value("topBoost")<=0
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	u.set_state("topBoost",BOOST_TIME)
	u.battle.emit_combat_event(&"top_boost",u.position,{"actor_id":u.battle_id,"time":BOOST_TIME})
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":TOUCH*2*u.combat_scale()}
func debug_state(u) -> String:return "angle:%.2f boost:%.2f"%[u.state_value("topAngle"),u.state_value("topBoost")]
