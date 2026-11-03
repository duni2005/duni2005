extends CharacterAbility
## 앵무새: basic attack fans out FEATHERS feathers (physical · wind · projectile). Ultimate 흉내:
## takes MIMIC_DRAIN off the nearest enemy's ultimate gauge and casts that enemy's ultimate as its
## own. While copying, its damage specs other than the basic attack come from the copied unit
## (UnitStatTable.spec_type) and the copied ability's ongoing hooks run on the parrot for MIMIC_TIME.
const FEATHERS: int = 5
const SPREAD: float = .18
const MIMIC_DRAIN: float = 50
const MIMIC_TIME: float = 8
## Every unit can be copied; some ultimates are adapted to a parrot:
## - NEXT_BASIC (대구경 저격수, 탱크) arm the parrot's next basic attack, which becomes that unit's
##   empowered basic attack;
## - NO_ULTIMATE (샷건, 굴절) have none, so the parrot fires that unit's basic attack at once;
## - SWOOP (close-range ultimates) first fly the parrot to the target;
## - 광신도 charges an ally's gauge, 개구리 swallows and spits the target, 배달부 hands an ally a
##   parcel, 슬라임 leaps by itself; another 앵무새 passes on what it copied last.
const NEXT_BASIC: Array[int] = [6, 18]
const NO_ULTIMATE: Array[int] = [7, 28]
const SWOOP: Array[int] = [0, 9, 10, 12, 14, 26, 39]
const SWOOP_SPEED: float = 900
var mimic: CharacterAbility = null

func release_basic(u) -> void:
	if u.character_specific_state.has("mimicBasic") and mimic!=null:
		mimic.release_basic(u);u.set_state("mimicBasicUsed",1.0);return
	for i in range(FEATHERS):
		var off: float=(i-(FEATHERS-1)/2.0)*SPREAD
		shoot(u,u.combat.aim_angle+off,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"feather","speed":760,"radius":11,"life":.55,"impulse":25})
func attack_tick(u,dt: float) -> bool:return mimic!=null and u.character_specific_state.has("mimicBasic") and mimic.attack_tick(u,dt)
func after_recovery(u) -> void:
	if u.state_value("mimicBasicUsed")>0:
		for k in ["mimicBasic","mimicBasicUsed","sniperBurstReady","tankFlameReady"]:u.character_specific_state.erase(k)

## The enemy whose ultimate is taken: the nearest one (a parrot that never copied is passed over).
func mimic_source(u):
	var best=null;var d: float=INF
	for e in u.enemies(false):
		if e.unavailable() or e.data.type_id==36 and not e.character_specific_state.has("mimicLast"):continue
		var gap: float=u.position.distance_to(e.position)
		if gap<d:d=gap;best=e
	return best
func ultimate_target(u):return mimic_source(u)
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<560*u.combat_scale()
func release_ultimate(u,a: Dictionary,dt: float) -> bool:
	if not a.has("mimic"):
		var src=u.battle.find_actor(str(a.get("target","")))
		if src==null or not src.alive or src.data.type_id==36 and not src.character_specific_state.has("mimicLast"):src=mimic_source(u)
		if src==null:return true
		var type: int=int(src.character_specific_state.mimicLast) if src.data.type_id==36 else src.data.type_id
		src.ultimate_gauge=maxf(0,src.ultimate_gauge-MIMIC_DRAIN)
		mimic=AbilityRegistry.create(type)
		u.set_state("mimicType",type);u.set_state("mimicTime",MIMIC_TIME);u.set_state("mimicLast",type)
		u.battle.emit_combat_event(&"parrot_mimic",u.position,{"actor_id":u.battle_id,"from":src.battle_id,"type":type})
		a["mimic"]=type;a["from"]=src.actor_id()
		var t=mimic.ultimate_target(u) if type not in [19,24,29,35] else src
		if t==null or t.team==u.team and type in SWOOP:t=src
		var point: Vector2=mimic.ultimate_point(u,t.position+t.velocity*.4 if t!=null else u.position)
		a.target=t.actor_id() if t!=null else "";a.angle=(point-u.position).angle();a.point=CharacterPersistence.point(point.clamp(Vector2(28,28),Vector2(772,772)))
		a["phase"]="swoop" if type in SWOOP else "cast"
	var type: int=int(a.mimic)
	if a.get("phase","")=="swoop":
		var t=u.battle.find_actor(str(a.target))
		a["swoop"]=float(a.get("swoop",0))+dt
		if t!=null and t.alive and float(a.swoop)<.6 and not dash_to(u,t.position,SWOOP_SPEED,dt,60*u.combat_scale()):
			u.facing=(t.position-u.position).angle();return false
		if t!=null:a.angle=(t.position-u.position).angle();a.point=CharacterPersistence.point(t.position)
		a.phase="cast"
	if type in NEXT_BASIC:
		mimic.release_ultimate(u,a,dt);u.set_state("mimicBasic",type);return true
	if type in NO_ULTIMATE:
		u.set_state("mimicBasic",type);u.combat.aim_angle=float(a.angle);mimic.release_basic(u)
		u.character_specific_state.erase("mimicBasic");return true
	match type:
		19:# 광신도: the nearest ally whose ultimate is not full gains 20.
			var best=null;var d: float=INF
			for f in u.friends():
				if f.data.ultimate_windup<0 or f.ultimate_gauge>=100:continue
				if u.position.distance_to(f.position)<d:d=u.position.distance_to(f.position);best=f
			if best!=null:best.ultimate.gain(best,20)
			return true
		24:# 개구리: swallows the target and spits it out.
			var t=u.battle.find_actor(str(a.target))
			if t!=null and t.alive:CharacterLifecycle.capture(u,t)
			return true
		29:# 배달부: a random parcel to the nearest ally (or itself).
			var to=nearest(u,u.friends());if to==null:to=u
			mimic._deliver(u,to);u.character_specific_state.erase("parcelRespawn");return true
		35:# 슬라임: the parrot leaps alone at the target.
			var t=u.battle.find_actor(str(a.target))
			if t!=null:u.character_specific_state["slimeLeap"]={"t":0.0,"from":CharacterPersistence.point(u.position),"to":CharacterPersistence.point(t.position)}
			return true
	return mimic.release_ultimate(u,a,dt)

func copying() -> bool:return mimic!=null
func tick(u,dt: float) -> void:
	if mimic==null:return
	mimic.tick(u,dt)
	u.set_state("mimicTime",maxf(0,u.state_value("mimicTime")-dt))
	if u.state_value("mimicTime")<=0 and u.ultimate.cast.is_empty() and not u.character_specific_state.has("mimicBasic"):
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
func attack_factor(u) -> float:return mimic.attack_factor(u) if mimic!=null else 1.0
func critical_bonus(u,t) -> float:return mimic.critical_bonus(u,t) if mimic!=null else 0.0
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
