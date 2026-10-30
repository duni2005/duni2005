extends CharacterAbility
## 화염방사기: sprays flame that pierces every enemy in its path, a puff every PUFF_EVERY seconds,
## each burning one unit of oil. Oil refills slowly whenever it is not spraying, and a spray
## needs OIL_START to begin. Ultimate: lobs BOTTLES oil bottles across the target area; each
## shatters into a puddle of oil, then the unit sprays fire on the nearest puddle and the fire runs
## across the oil. Burning puddles hurt enemies standing in them every half second for
## PATCH_LIFE, and the tank is refilled.
const OIL_MAX: float = 30
const OIL_START: float = 6
const OIL_REGEN: float = 3.5
const PUFF_EVERY: float = .1
const PATCH_RADIUS: float = 140
const PATCH_LIFE: float = 6
const PATCH_REACH: float = 260
const BOTTLES: int = 5
const PUDDLE_RADIUS: float = 58
## Bottle i leaves at i * THROW_GAP and flies FLIGHT seconds; the fire is lit at IGNITE and runs
## across the oil at SPREAD pixels a second.
const THROW_GAP: float = .09
const FLIGHT: float = .55
const IGNITE: float = 1.15
const SPREAD: float = 420
func on_spawn(u) -> void:
	if not u.character_specific_state.has("oil"):u.set_state("oil",OIL_MAX)
func tick(u,dt: float) -> void:
	if u.combat_state!=CombatController.State.ACTIVE:u.set_state("oil",minf(OIL_MAX,u.state_value("oil")+OIL_REGEN*dt))
func can_attack(u,_t) -> bool:return u.state_value("oil")>=OIL_START
func release_basic(u) -> void:
	if u.state_value("oil")<1:return
	var r: RandomNumberGenerator=u.battle.rng
	shoot(u,u.combat.aim_angle+r.randf_range(-.08,.08),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"flame","speed":520,"radius":18,"offset":34,"life":.45,"piercing":true,"impulse":25})
	u.set_state("oil",u.state_value("oil")-1)
## Keeps spraying through the active phase, turning toward the target, until the oil runs out.
func attack_tick(u,dt: float) -> bool:
	if u.combat_state==CombatController.State.IDLE:return false
	var target=u.combat.attack_target
	if target==null or not target.alive or not CombatPerception.can_perceive(u,target):target=nearest(u,u.enemies())
	if target==null:u.combat.cancel(u);return true
	u.combat.attack_target=target
	u.combat.aim_angle+=clampf(wrapf(u.combat.aim_direction(u,target)-u.combat.aim_angle,-PI,PI),-2.5*dt,2.5*dt)
	u.facing=u.combat.aim_angle
	if u.combat_state==CombatController.State.ACTIVE:
		var next: float=float(u.combat.attack_metadata.get("next_puff",PUFF_EVERY))
		while u.state_value("oil")>=1 and u.combat.phase_time+1e-8>=next:release_basic(u);next+=PUFF_EVERY
		u.combat.attack_metadata.next_puff=next
		if u.state_value("oil")<1:u.combat_state=CombatController.State.RECOVERY;u.combat.phase_time=0
	return false
func release_ultimate(u,a: Dictionary,_dt: float) -> bool:
	var scale: float=u.combat_scale();var r: RandomNumberGenerator=u.battle.rng
	var center: Vector2=u.position+(CharacterPersistence.vector(a.get("point",{}),u.position)-u.position).limit_length(PATCH_REACH*scale)
	# One bottle on the centre, the rest scattered around it.
	var spots: Array=[center]
	for i in range(BOTTLES-1):
		spots.append(MovementController.clamp_position(center+Vector2.from_angle(i*TAU/(BOTTLES-1)+r.randf_range(-.4,.4))*r.randf_range(.45,.7)*PATCH_RADIUS*scale))
	# The fire starts on the puddle nearest the thrower and runs outward through the oil.
	var first: Vector2=spots[0]
	for spot in spots:
		if spot.distance_to(u.position)<first.distance_to(u.position):first=spot
	var puddles: Array=[]
	for i in range(spots.size()):
		var at: Vector2=spots[i]
		puddles.append({"x":at.x,"y":at.y,"r":PUDDLE_RADIUS*scale*r.randf_range(.85,1.1),"land":i*THROW_GAP+FLIGHT,"ignite":IGNITE+at.distance_to(first)/SPREAD})
	var life: float=IGNITE+PATCH_LIFE
	u.battle.zones.add(u,"oilFire",center,PATCH_RADIUS*scale+PUDDLE_RADIUS*scale,life,{"damage":UnitStatTable.raw(u,&"fire_zone"),"total":life,"puddles":puddles,"origin":CharacterPersistence.point(u.position),"first":CharacterPersistence.point(first)})
	u.set_state("oil",OIL_MAX)
	return true
func cast_area(u,a: Dictionary) -> Dictionary:
	var point: Vector2=u.position+(CharacterPersistence.vector(a.get("point",{}),u.position)-u.position).limit_length(PATCH_REACH*u.combat_scale())
	return {"shape":"circle","point":CharacterPersistence.point(point),"radius":PATCH_RADIUS*u.combat_scale()}
func debug_state(u) -> String:return "oil:%d" % int(u.state_value("oil"))
