extends CharacterAbility
## 슬라임: when a blow would kill it, it splits instead — itself and a new slime, each with
## SPLIT_HP of its HP, SPLIT_FACTOR of its damage and a smaller body (twice at most: 1 → 2 → 4). Slimes of the
## last split can no longer use the ultimate. Basic attack: hops at the target and
## body-slams around its landing spot (physical · poison), knocking enemies back and slowing them
## for SLOW_TIME. Ultimate: every slime of its family leaps high at once and slams down on the
## nearest enemy (physical · area · poison).
const MAX_SPLITS: int = 2
const SPLIT_FACTOR: float = .3
## Share of HP each split keeps (lower than the damage share since 0.76.0).
const SPLIT_HP: float = .25
const SPLIT_SCALE: float = .8
const HOP: float = 160
const HOP_SPEED: float = 760
const SLAM_RADIUS: float = 58
const SLOW_TIME: float = 2.0
const LEAP_TIME: float = .7
const LAND_RADIUS: float = 92

func on_spawn(u) -> void:
	if not u.character_specific_state.has("slimeFamily"):u.set_state("slimeFamily",u.actor_id())
func locked(u) -> bool:return super(u) or u.character_specific_state.has("slimeLeap")

## The hop is the windup: toward the target until HOP is spent or it is on top of the target.
func attack_tick(u,dt: float) -> bool:
	if u.combat_state!=CombatController.State.WINDUP:return false
	var t=u.combat.attack_target
	if t==null or not is_instance_valid(t) or not t.alive:return false
	var moved: float=float(u.combat.attack_metadata.get("hopped",0))
	if moved<HOP*u.combat_scale():
		var before: Vector2=u.position
		dash_to(u,t.position,HOP_SPEED,dt,34*u.combat_scale())
		u.combat.attack_metadata["hopped"]=moved+u.position.distance_to(before)
	u.combat.aim_angle=(t.position-u.position).angle();u.facing=u.combat.aim_angle
	return false
func release_basic(u) -> void:
	slam(u,u.position,SLAM_RADIUS*u.combat_scale(),&"basic",420,true)
	u.battle.emit_combat_event(&"slime_slam",u.position,{"radius":SLAM_RADIUS*u.combat_scale(),"actor_id":u.battle_id})
## Hits every enemy around `point`; with `slow` the ones it hurts are slowed.
func slam(u,point: Vector2,radius: float,key: StringName,impulse: float,slow: bool) -> void:
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(point)>radius+24*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,key),{"dmg":key,"critical":true,"impulse":impulse,"angle":(e.position-point).angle(),"attack_origin":point,"attack_token":"%s:%s%d"%[u.actor_id(),key,u.combat.attack_serial]})
		if slow and e.alive and out.hp_damage>0:e.set_state("slowTime",SLOW_TIME)

## Called instead of dying (CharacterLifecycle.intercept_lethal). Returns false once the slime has
## split MAX_SPLITS times.
static func split(u) -> bool:
	var done: int=int(u.state_value("slimeSplits"))
	if done>=MAX_SPLITS:return false
	# Units placed without stats (전투 예측) split from their table stats.
	if u.combat_stats==null:u.combat_stats=UnitCombatStats.from_table(u.data)
	var stats: UnitCombatStats=halved(u.combat_stats)
	u.combat_stats=stats;u.current_hp=stats.max_hp
	u.set_state("slimeSplits",done+1)
	u.invincible_remaining=maxf(u.invincible_remaining,.35)
	var away: Vector2=Vector2.from_angle(u.battle.rng.randf_range(0,TAU))
	u.knockback_velocity=away*260
	var state: Dictionary=u.character_specific_state.duplicate(true)
	for key in ["slimeLeap","leapHeight","burnStacks","poisonStacks","darkMark","lightMark"]:state.erase(key)
	u.battle.queue_spawn(u,u.position-away*30,halved(u.combat_stats,1.0),state,-away*260)
	u.battle.emit_combat_event(&"slime_split",u.position,{"actor_id":u.battle_id,"split":done+1})
	return true
## A copy of `stats` with HP scaled by SPLIT_HP and damage by SPLIT_FACTOR (factor 1: an exact copy).
static func halved(stats: UnitCombatStats,factor: float=SPLIT_FACTOR) -> UnitCombatStats:
	var copy:=UnitCombatStats.new()
	for p in stats.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v=stats.get(p.name)
			copy.set(p.name,v.duplicate(true) if v is Dictionary or v is Array else v)
	copy.max_hp*=SPLIT_HP if factor<1 else factor;copy.physical_damage*=factor;copy.magic_damage*=factor
	if factor<1:copy.scale*=SPLIT_SCALE
	return copy

## The last split is too small to leap: no ultimate.
static func last_split(u) -> bool:return int(u.state_value("slimeSplits"))>=MAX_SPLITS
func can_cast(u) -> bool:return not last_split(u)
func can_ultimate(u,t) -> bool:return not last_split(u) and t!=null and u.position.distance_to(t.position)<420*u.combat_scale()
## Every slime of the family leaps at the enemy nearest to it (not those of the last split).
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	var family: String=str(u.character_specific_state.get("slimeFamily",u.actor_id()))
	for s in u.battle.units:
		if not s.alive or s.data.type_id!=35 or s.team!=u.team or str(s.character_specific_state.get("slimeFamily",""))!=family or s.unavailable() or last_split(s):continue
		var target=nearest(s,s.enemies(false))
		if target==null:continue
		s.combat.cancel(s);s.velocity=Vector2.ZERO;s.knockback_velocity=Vector2.ZERO
		s.character_specific_state["slimeLeap"]={"t":0.0,"from":CharacterPersistence.point(s.position),"to":CharacterPersistence.point(target.position)}
	u.battle.emit_combat_event(&"slime_leap",u.position,{"actor_id":u.battle_id})
	return true
func tick(u,dt: float) -> void:
	var leap: Dictionary=u.character_specific_state.get("slimeLeap",{})
	if leap.is_empty():return
	leap.t=float(leap.t)+dt
	var k: float=clampf(float(leap.t)/LEAP_TIME,0,1)
	u.position=MovementController.clamp_position(CharacterPersistence.vector(leap.from).lerp(CharacterPersistence.vector(leap.to),k*k*(3-2*k)))
	u.set_state("leapHeight",sin(k*PI)*.7);u.invincible_remaining=maxf(u.invincible_remaining,.05)
	if k>=1:
		u.character_specific_state.erase("slimeLeap");u.set_state("leapHeight",0.0)
		slam(u,u.position,LAND_RADIUS*u.combat_scale(),&"ult",520,false)
		u.battle.emit_combat_event(&"slime_land",u.position,{"radius":LAND_RADIUS*u.combat_scale(),"actor_id":u.battle_id})
func ultimate_danger(u,observer,_a: Dictionary) -> bool:return observer.position.distance_to(u.position)<420*u.combat_scale()
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":LAND_RADIUS*u.combat_scale()}
func debug_state(u) -> String:return "split:%d" % int(u.state_value("slimeSplits"))
