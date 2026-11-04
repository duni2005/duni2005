extends CharacterAbility
## 산타 (전설): a low-damage shove that pushes enemies away (physical · melee). Ultimate: vanishes
## for AWAY_TIME while a reindeer sleigh's shadow sweeps over the field and drops a gift on every
## unit. Each gift is one random effect — enemies: medium or heavy ice damage, a 6 s stun, an
## emptied ultimate gauge, a 10 s root or 10 s of +50% damage taken; allies: 20% or 30% HP, a full
## or half ultimate gauge, or 10 s of +50% attack.
const AWAY_TIME: float = 3.2
const DROP_FROM: float = .5
const DROP_TO: float = 2.6
const ENEMY_GIFTS: Array[StringName] = [&"mid", &"high", &"stun", &"drain", &"root", &"weak"]
const ALLY_GIFTS: Array[StringName] = [&"heal20", &"heal30", &"ult_full", &"ult_half", &"power"]
const STUN_TIME: float = 6
const ROOT_TIME: float = 10
const WEAK_TIME: float = 10
const POWER_TIME: float = 10

func can_ultimate(_u,t) -> bool:return t!=null
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	var r: RandomNumberGenerator=u.battle.rng;var gifts: Array=[]
	for v in u.battle.units:
		if v==u or not v.alive or v.unavailable():continue
		var ally: bool=v.team==u.team
		var kinds: Array=ALLY_GIFTS if ally else ENEMY_GIFTS
		gifts.append({"to":v.battle_id,"at":r.randf_range(DROP_FROM,DROP_TO),"kind":kinds[r.randi_range(0,kinds.size()-1)],"ally":ally})
	u.character_specific_state["santaGifts"]=gifts
	u.set_state("santaAway",AWAY_TIME);u.set_state("santaClock",0.0)
	u.invincible_remaining=maxf(u.invincible_remaining,AWAY_TIME);u.combat.cancel(u)
	u.battle.emit_combat_event(&"santa_away",u.position,{"actor_id":u.battle_id,"time":AWAY_TIME,"gifts":gifts.duplicate(true)})
	return true
## Runs while Santa is away (unavailable units skip tick): counts down and hands out the gifts.
func passive_tick(u,dt: float) -> void:
	if u.state_value("santaAway")<=0:return
	var clock: float=u.state_value("santaClock")+dt;u.set_state("santaClock",clock)
	var left: Array=[]
	for g in u.character_specific_state.get("santaGifts",[]):
		if float(g.at)>clock:left.append(g);continue
		var v=_unit(u,int(g.to))
		if v!=null and v.alive:give(u,v,StringName(g.kind))
	u.character_specific_state["santaGifts"]=left
	u.set_state("santaAway",maxf(0,u.state_value("santaAway")-dt))
	if u.state_value("santaAway")<=0:
		u.character_specific_state.erase("santaGifts")
		u.battle.emit_combat_event(&"santa_back",u.position,{"actor_id":u.battle_id})
static func _unit(u,id: int):
	for v in u.battle.units:
		if v.battle_id==id:return v
	return null
func give(u,v,kind: StringName) -> void:
	u.battle.emit_combat_event(&"santa_gift",v.position,{"actor_id":v.battle_id,"kind":kind,"ally":v.team==u.team})
	match kind:
		&"mid",&"high":
			var key: StringName=&"gift_mid" if kind==&"mid" else &"gift_high"
			u.battle.damage_resolver.resolve(u,v,UnitStatTable.raw(u,key),{"dmg":key,"critical":false,"impulse":0,"attack_origin":v.position,"visible_hazard":true,"attack_token":"%s:gift%d:%d"%[u.actor_id(),u.ultimate.serial,v.battle_id]})
		&"stun":StatusController.stun(v,STUN_TIME)
		&"drain":v.ultimate_gauge=0.0
		&"root":v.set_state("rootedUntil",maxf(v.state_value("rootedUntil"),u.battle.clock.elapsed+ROOT_TIME))
		&"weak":v.set_state("giftWeakTime",WEAK_TIME)
		&"heal20":restore_hp(v,v.max_hp*.2,u)
		&"heal30":restore_hp(v,v.max_hp*.3,u)
		&"ult_full":v.ultimate.gain(v,100)
		&"ult_half":v.ultimate.gain(v,50)
		&"power":v.set_state("giftPowerTime",POWER_TIME)
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func cast_area(_u,_a: Dictionary) -> Dictionary:return {"point":{"x":400.0,"y":400.0},"radius":600.0}
