extends CharacterAbility
## 바운티 헌터 (4 tokens). Passive 현상금: when the battle starts it puts a bounty on up to
## BOUNTIES random enemies; they take BOUNTY_TAKEN more damage (ElementEffects.taken), and each
## one that falls pays BOUNTY_GOLD gold (credited to the guild after the battle when the hunter
## is a guild member). Basic: a six-round Desert Eagle — every round is its own basic attack with
## heavy recoil and wide spread but high damage; then it reloads. Ultimate 현상금 집행: an instant
## shot at every enemy with its bounty (or one random enemy if none is left), rooting each for
## ROOT_TIME seconds.
const BOUNTIES: int = 2
const BOUNTY_TAKEN: float = 1.05
const BOUNTY_GOLD: int = 100
const SHOTS: int = 6
const RELOAD: float = 1.9
const SHOT_GAP: float = .06
const SPREAD: float = .2
const RECOIL: float = 190
const ROOT_TIME: float = 5

func on_spawn(u) -> void:
	if not u.character_specific_state.has("rounds"):u.set_state("rounds",SHOTS)
	if u.character_specific_state.has("bounties"):return
	var pool: Array=u.enemies(false).filter(func(e):return e.alive and not e.character_specific_state.has("bountyBy"))
	var picked: Array=[]
	for i in range(mini(BOUNTIES,pool.size())):
		var e=pool.pop_at(u.battle.rng.randi_range(0,pool.size()-1))
		e.character_specific_state["bountyBy"]=u.actor_id();picked.append(e.battle_id)
		u.battle.emit_combat_event(&"bounty_marked",e.position,{"actor_id":e.battle_id})
	u.character_specific_state["bounties"]=picked
## Pays out for every bounty that has fallen (checked even while the hunter is busy).
func passive_tick(u,_dt: float) -> void:
	var open: Array=[]
	for id in u.character_specific_state.get("bounties",[]):
		var e=_unit(u,int(id))
		if e==null or e.alive:open.append(id);continue
		u.set_state("bountyGold",u.state_value("bountyGold")+BOUNTY_GOLD)
		u.battle.emit_combat_event(&"bounty_paid",e.position,{"actor_id":u.battle_id,"gold":BOUNTY_GOLD})
	u.character_specific_state["bounties"]=open
static func _unit(u,id: int):
	for v in u.battle.units:
		if v.battle_id==id:return v
	return null
func tick(u,dt: float) -> void:
	if u.state_value("reloadRemaining")<=0:return
	u.set_state("reloadRemaining",maxf(0,u.state_value("reloadRemaining")-dt*EquipmentCombatEffects.attack_speed(u)))
	if u.state_value("reloadRemaining")==0:u.set_state("rounds",SHOTS)
func can_attack(u,_t) -> bool:return u.state_value("rounds")>0 and u.state_value("reloadRemaining")<=0
func requires_initiative(u=null) -> bool:return u==null or int(u.state_value("rounds"))>=SHOTS
func attack_cooldown(u,_rng: RandomNumberGenerator) -> float:
	var p: AttackData=u.combat.profile(u)
	return p.windup+p.active+p.recovery+SHOT_GAP
func movement_rate(u) -> float:return .8 if u.state_value("reloadRemaining")>0 else 1
func release_basic(u) -> void:
	var angle: float=u.combat.aim_angle+u.battle.rng.randf_range(-SPREAD,SPREAD)
	shoot(u,angle,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"deagle","speed":1150,"radius":12,"life":.5,"impulse":160})
	# Heavy recoil shoves the hunter back and kicks the aim upward for the next round.
	u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*RECOIL
	u.battle.emit_combat_event(&"deagle_shot",u.position+Vector2.from_angle(angle)*40*u.combat_scale(),{"actor_id":u.battle_id,"angle":angle})
	u.set_state("rounds",u.state_value("rounds")-1)
	if u.state_value("rounds")<=0:u.set_state("reloadRemaining",RELOAD);u.battle.emit_combat_event(&"deagle_reload",u.position,{"actor_id":u.battle_id})
func debug_state(u) -> String:return "rounds:%d reload:%.2f bounties:%s"%[int(u.state_value("rounds")),u.state_value("reloadRemaining"),str(u.character_specific_state.get("bounties",[]))]

## Enemies currently carrying this hunter's bounty.
func marked(u) -> Array:
	return u.enemies(false).filter(func(e):return e.alive and not e.unavailable() and str(e.character_specific_state.get("bountyBy",""))==u.actor_id())
func can_ultimate(u,t) -> bool:return t!=null
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	var targets: Array=marked(u)
	if targets.is_empty():
		var pool: Array=u.enemies(false).filter(func(e):return e.alive and not e.unavailable())
		if pool.is_empty():return true
		targets=[pool[u.battle.rng.randi_range(0,pool.size()-1)]]
	for e in targets:
		u.battle.emit_combat_event(&"bounty_shot",u.position,{"actor_id":u.battle_id,"to":CharacterPersistence.point(e.position),"target":e.battle_id})
		u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":0,"angle":(e.position-u.position).angle(),"attack_origin":u.position,"visible_hazard":true,"attack_token":"%s:bounty%d:%d"%[u.actor_id(),u.ultimate.serial,e.battle_id]})
		if e.alive:e.set_state("rootedUntil",maxf(e.state_value("rootedUntil"),u.battle.clock.elapsed+ROOT_TIME))
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":60*u.combat_scale()}
