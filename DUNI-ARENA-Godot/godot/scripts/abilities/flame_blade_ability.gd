extends CharacterAbility
## 불의 검사: slashes ahead with a burning sword (physical · fire · melee) and sets BASIC_BURN
## burn stacks on each enemy hit. Ultimate: dashes forward, gathers power for CHARGE_TIME, then
## cuts a full circle around itself (physical · fire · area · melee); every enemy it hurts has its
## burn stacks spent at once for extra damage per stack (magic · fire, &"ignite").
const BASIC_BURN: int = 5
const DASH: float = 200
const DASH_SPEED: float = 1000
const CHARGE_TIME: float = .5
const WHIRL_RADIUS: float = 135

func dealt_damage(u,target,_actual: float,options: Dictionary) -> void:
	if options.get("dmg",&"")==&"basic" and target.alive:ElementEffects.add_burn(u,target,BASIC_BURN)
## Its own slash sets burn itself, so the shared 50% fire roll is skipped.
func own_element(rule: StringName,_options: Dictionary) -> bool:return rule==&"fire"
func release_basic(u) -> void:
	super(u)
	u.battle.emit_combat_event(&"flame_slash",u.position+Vector2.from_angle(u.combat.aim_angle)*50*u.combat_scale(),{"actor_id":u.battle_id,"angle":u.combat.aim_angle})

func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<(DASH+WHIRL_RADIUS)*u.combat_scale()
func release_ultimate(u,a: Dictionary,dt: float) -> bool:
	match str(a.get("phase","dash")):
		"dash":
			var t=u.battle.find_actor(str(a.get("target","")))
			a["moved"]=float(a.get("moved",0));var before: Vector2=u.position
			var goal: Vector2=t.position if t!=null and t.alive else u.position+Vector2.from_angle(float(a.angle))*DASH
			var reached: bool=dash_to(u,goal,DASH_SPEED,dt,40*u.combat_scale())
			a.moved=float(a.moved)+u.position.distance_to(before);u.facing=(goal-u.position).angle()
			if not reached and float(a.moved)<DASH*u.combat_scale():return false
			a.phase="charge";a["charge"]=0.0
			u.battle.emit_combat_event(&"flame_charge",u.position,{"actor_id":u.battle_id,"time":CHARGE_TIME})
			return false
		"charge":
			a.charge=float(a.charge)+dt;u.velocity=Vector2.ZERO
			if float(a.charge)<CHARGE_TIME:return false
	whirl(u)
	return true
## The circular cut: damage, then every hurt enemy's burn stacks ignite at once.
func whirl(u) -> void:
	var r: float=WHIRL_RADIUS*u.combat_scale()
	u.battle.emit_combat_event(&"flame_whirl",u.position,{"actor_id":u.battle_id,"radius":r})
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(u.position)>r+24*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":320,"angle":(e.position-u.position).angle(),"attack_origin":u.position,"visible_hazard":true,"attack_token":"%s:whirl%d"%[u.actor_id(),u.ultimate.serial]})
		var stacks: int=int(e.state_value("burnStacks"))
		if not e.alive or out.hp_damage+out.shield_absorbed<=0 or stacks<=0:continue
		e.set_state("burnStacks",0)
		u.battle.emit_combat_event(&"ignite",e.position,{"actor_id":e.battle_id,"stacks":stacks})
		u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ignite")*stacks,{"dmg":&"ignite","critical":false,"status":&"ignite","impulse":0,"attack_origin":e.position})
func ultimate_danger(u,observer,_a: Dictionary) -> bool:return observer.position.distance_to(u.position)<(DASH+WHIRL_RADIUS)*u.combat_scale()
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":(DASH+WHIRL_RADIUS)*u.combat_scale()}
