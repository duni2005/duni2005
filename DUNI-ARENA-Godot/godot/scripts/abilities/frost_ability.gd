extends CharacterAbility
## 빙결술사: fires three ice crystals in quick succession, each adding a frost stack. Ultimate
## summons an ice storm that drifts slowly forward, hurting and frosting enemies inside it.
## Any enemy reaching FREEZE_STACKS frost stacks is frozen solid (stunned) for FREEZE_TIME.
const FREEZE_STACKS: int = 10
const FREEZE_TIME: float = 4
const STORM_RADIUS: float = 115
const STORM_SPEED: float = 75
const STORM_LIFE: float = 7
const STORM_TICK: float = .5
const STORM_STACKS: int = 2
func release_basic(u) -> void:
	# Three crystals leave together but at rising speeds, so they land one after another.
	for i in range(3):
		shoot(u,u.combat.aim_angle+(i-1)*.07,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"iceShard","speed":560+i*90,"radius":16,"impulse":70})
func dealt_damage(u,target,_actual: float,options: Dictionary) -> void:
	# Storm hits carry frost_stacks; the only projectile this unit fires is an ice crystal.
	var stacks: int=int(options.get("frost_stacks",1 if options.get("melee",true)==false else 0))
	if stacks>0:add_frost(u,target,stacks)
static func add_frost(_u,target,stacks: int) -> void:
	if not target.alive or target.state_value("frozenTime")>0:return
	var total: float=target.state_value("frostStacks")+stacks
	target.set_state("frostDecay",4)
	if total>=FREEZE_STACKS:
		target.set_state("frostStacks",0);target.set_state("frozenTime",FREEZE_TIME)
		StatusController.stun(target,FREEZE_TIME)
	else:target.set_state("frostStacks",total)
## Driven by BindingController so the storm keeps drifting while the caster is stunned.
func advance_storm(u,dt: float) -> void:
	var storm: Dictionary=u.character_specific_state.get("storm",{})
	if storm.is_empty():return
	var dir: Vector2=Vector2.from_angle(float(storm.angle))
	var at: Vector2=MovementController.clamp_position(CharacterPersistence.vector(storm)+dir*STORM_SPEED*dt)
	storm.x=at.x;storm.y=at.y;storm.life=float(storm.life)-dt;storm.tick=float(storm.tick)-dt
	if float(storm.tick)<=0:
		storm.tick=STORM_TICK
		area_damage(u,at,STORM_RADIUS*u.combat_scale(),UnitStatTable.raw(u,&"ult"),40,{"dmg":&"ult","critical":false,"frost_stacks":STORM_STACKS})
	if float(storm.life)<=0:u.character_specific_state.erase("storm")
func release_ultimate(u,a,_dt: float) -> bool:
	var angle: float=float(a.angle);var start: Vector2=u.position+Vector2.from_angle(angle)*70*u.combat_scale()
	u.character_specific_state["storm"]={"x":start.x,"y":start.y,"angle":angle,"life":STORM_LIFE,"tick":0.0}
	return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:
	var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)));var offset: Vector2=observer.position-u.position
	return offset.dot(dir)>0 and absf(offset.cross(dir))<STORM_RADIUS+30
func cast_area(u,a: Dictionary) -> Dictionary:
	var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)))
	return {"shape":"path","from":CharacterPersistence.point(u.position),"to":CharacterPersistence.point(u.position+dir*STORM_SPEED*STORM_LIFE),"radius":STORM_RADIUS*u.combat_scale()}
