extends CharacterAbility
## 화염방사기: sprays flame that pierces every enemy in its path, a puff every PUFF_EVERY seconds,
## each burning one unit of oil. Oil refills slowly whenever it is not spraying, and a spray
## needs OIL_START to begin. Ultimate scatters oil on the ground and sets it alight: a burning
## patch that hurts enemies inside every half second, and the tank is refilled.
const OIL_MAX: float = 30
const OIL_START: float = 6
const OIL_REGEN: float = 3.5
const PUFF_EVERY: float = .1
const PATCH_RADIUS: float = 140
const PATCH_LIFE: float = 6
const PATCH_REACH: float = 260
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
	var point: Vector2=u.position+(CharacterPersistence.vector(a.get("point",{}),u.position)-u.position).limit_length(PATCH_REACH*u.combat_scale())
	u.battle.zones.add(u,"tankFire",point,PATCH_RADIUS*u.combat_scale(),PATCH_LIFE,{"damage":UnitStatTable.raw(u,&"fire_zone"),"oil":true})
	u.set_state("oil",OIL_MAX)
	u.battle.emit_combat_event(&"ult_impact",point,{"actor":u.actor_id(),"type":u.data.type_id,"radius":PATCH_RADIUS*u.combat_scale()})
	return true
func cast_area(u,a: Dictionary) -> Dictionary:
	var point: Vector2=u.position+(CharacterPersistence.vector(a.get("point",{}),u.position)-u.position).limit_length(PATCH_REACH*u.combat_scale())
	return {"shape":"circle","point":CharacterPersistence.point(point),"radius":PATCH_RADIUS*u.combat_scale()}
func debug_state(u) -> String:return "oil:%d" % int(u.state_value("oil"))
