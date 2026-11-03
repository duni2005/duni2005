extends CharacterAbility
## 앵무새: basic attack fans out FEATHERS feathers (physical · wind · projectile). Ultimate 흉내:
## takes MIMIC_DRAIN off the nearest enemy's ultimate gauge and casts that enemy's ultimate as its
## own. While copying, its damage specs other than the basic attack come from the copied unit
## (UnitStatTable.spec_type) and the copied ability's ongoing hooks run on the parrot for MIMIC_TIME.
const FEATHERS: int = 5
const SPREAD: float = .18
const MIMIC_DRAIN: float = 50
const MIMIC_TIME: float = 8
## Ultimates that mean nothing on a parrot, never copied: ones that only arm the owner's next
## basic attack (대구경 저격수, 탱크), reactive or absent ones (샷건, 개구리, 굴절, 배달부), and ones
## bound to the owner's family or saint (광신도, 슬라임) — and another parrot.
const UNCOPYABLE: Array[int] = [6, 7, 18, 19, 24, 28, 29, 35, 36]
var mimic: CharacterAbility = null

func release_basic(u) -> void:
	for i in range(FEATHERS):
		var off: float=(i-(FEATHERS-1)/2.0)*SPREAD
		shoot(u,u.combat.aim_angle+off,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"feather","speed":760,"radius":11,"life":.55,"impulse":25})

## The enemy whose ultimate is taken: the nearest one with a copyable ultimate.
func mimic_source(u):
	var best=null;var d: float=INF
	for e in u.enemies(false):
		if e.unavailable() or e.data.ultimate_windup<0 or e.data.type_id in UNCOPYABLE:continue
		var gap: float=u.position.distance_to(e.position)
		if gap<d:d=gap;best=e
	return best
func ultimate_target(u):return mimic_source(u)
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<560*u.combat_scale()
func release_ultimate(u,a: Dictionary,dt: float) -> bool:
	if not a.has("mimic"):
		var src=u.battle.find_actor(str(a.get("target","")))
		if src==null or not src.alive or src.data.type_id in UNCOPYABLE:src=mimic_source(u)
		if src==null:return true
		src.ultimate_gauge=maxf(0,src.ultimate_gauge-MIMIC_DRAIN)
		mimic=AbilityRegistry.create(src.data.type_id)
		u.set_state("mimicType",src.data.type_id);u.set_state("mimicTime",MIMIC_TIME)
		u.battle.emit_combat_event(&"parrot_mimic",u.position,{"actor_id":u.battle_id,"from":src.battle_id,"type":src.data.type_id})
		# Aim the copied ultimate the way its owner would.
		var t=mimic.ultimate_target(u)
		var point: Vector2=mimic.ultimate_point(u,t.position+t.velocity*.4 if t!=null else u.position)
		a.target=t.actor_id() if t!=null else "";a.angle=(point-u.position).angle();a.point=CharacterPersistence.point(point.clamp(Vector2(28,28),Vector2(772,772)))
		a["mimic"]=src.data.type_id
	return mimic==null or mimic.release_ultimate(u,a,dt)

func copying() -> bool:return mimic!=null
func tick(u,dt: float) -> void:
	if mimic==null:return
	mimic.tick(u,dt)
	u.set_state("mimicTime",maxf(0,u.state_value("mimicTime")-dt))
	if u.state_value("mimicTime")<=0 and u.ultimate.cast.is_empty():
		mimic=null;u.character_specific_state.erase("mimicType");u.character_specific_state.erase("mimicTime")
## Hooks some copied ultimates rely on while they last (a drifting storm, a reflect or guard window).
func advance_storm(u,dt: float) -> void:
	if mimic!=null and mimic.has_method("advance_storm"):mimic.advance_storm(u,dt)
	else:u.character_specific_state.erase("storm")
func unique_defense(u,source,amount: float,can_evade: bool,options: Dictionary) -> Dictionary:return mimic.unique_defense(u,source,amount,can_evade,options) if mimic!=null else {}
func incoming_factor(u,source,options) -> float:return mimic.incoming_factor(u,source,options) if mimic!=null else 1.0
func pre_damage(u,source,damage: float,options: Dictionary) -> Dictionary:return mimic.pre_damage(u,source,damage,options) if mimic!=null else {}
func after_damage(u,source,actual: float,options: Dictionary) -> void:
	if mimic!=null:mimic.after_damage(u,source,actual,options)
func incoming_reduction(u) -> float:return mimic.incoming_reduction(u) if mimic!=null else 1.0
func defense_factor(u) -> float:return mimic.defense_factor(u) if mimic!=null else 1.0
func passive_tick(u,dt: float) -> void:
	if mimic!=null:mimic.passive_tick(u,dt)
func locked(u) -> bool:return super(u) or mimic!=null and mimic.locked(u)
func projectile_hit(u,p,t) -> bool:return mimic!=null and mimic.projectile_hit(u,p,t)
func projectile_tick(u,dt: float) -> void:
	if mimic!=null:mimic.projectile_tick(u,dt)
func melee_hit(u,attack,t,outcome) -> void:
	if mimic!=null:mimic.melee_hit(u,attack,t,outcome)
func dealt_damage(u,t,actual: float,options: Dictionary) -> void:
	if mimic!=null and options.get("dmg",&"basic")!=&"basic":mimic.dealt_damage(u,t,actual,options)
func ultimate_danger(u,observer,a: Dictionary) -> bool:return mimic.ultimate_danger(u,observer,a) if mimic!=null else super(u,observer,a)
func cast_area(u,a: Dictionary) -> Dictionary:return mimic.cast_area(u,a) if mimic!=null else {}
func debug_state(u) -> String:return "mimic:%d" % int(u.state_value("mimicType")) if mimic!=null else ""
