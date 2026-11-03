extends CharacterAbility
## 역병: pokes with its staff (physical); each hit adds STACK_BONUS of the poke per poison stack
## on the target (up to STACK_CAP stacks). Ultimate: slams the staff and covers the whole map in
## plague fog for FOG_TIME seconds, hurting every enemy anywhere every FOG_TICK seconds
## (magic · dark · poison · area · over time).
const STACK_BONUS: float = .08
const STACK_CAP: int = 15
const FOG_TIME: float = 5
const FOG_TICK: float = .5

func dealt_damage(u,target,actual: float,options: Dictionary) -> void:
	if options.get("dmg",&"")!=&"basic" or not target.alive:return
	var stacks: int=mini(int(target.state_value("poisonStacks")),STACK_CAP)
	if stacks<=0:return
	u.battle.damage_resolver.resolve(u,target,UnitStatTable.raw(u,&"basic")*STACK_BONUS*stacks,{"dmg":&"plague","critical":false,"status":&"plague","impulse":0,"attack_origin":target.position})
	u.battle.emit_combat_event(&"plague_bonus",target.position,{"actor_id":target.battle_id,"stacks":stacks})

func can_ultimate(u,t) -> bool:return t!=null and u.state_value("fogTime")<=0
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	u.set_state("fogTime",FOG_TIME);u.set_state("fogTick",0.0)
	u.battle.emit_combat_event(&"plague_fog",u.position,{"actor_id":u.battle_id,"time":FOG_TIME,"team":u.team})
	return true
func tick(u,dt: float) -> void:
	if u.state_value("fogTime")<=0:return
	u.set_state("fogTime",maxf(0,u.state_value("fogTime")-dt));u.set_state("fogTick",u.state_value("fogTick")-dt)
	if u.state_value("fogTick")>0:return
	u.set_state("fogTick",FOG_TICK)
	for e in u.enemies(false):
		if e.unavailable():continue
		u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":false,"impulse":0,"attack_origin":e.position,"attack_token":"%s:fog%d:%d"%[u.actor_id(),u.ultimate.serial,int(u.state_value("fogTime")*10)]})
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return true
func cast_area(_u,_a: Dictionary) -> Dictionary:return {"point":{"x":400.0,"y":400.0},"radius":600.0}
