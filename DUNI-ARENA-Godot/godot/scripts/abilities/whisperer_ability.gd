extends CharacterAbility
## 속삭이는 자: throws needles (physical · dark · projectile) that each add a whisper stack; at
## STACKS stacks they are spent and the target takes BURST of its max HP (magic · dark). Ultimate:
## a heart that flies through every enemy in its path (magic · dark · projectile) and charms each
## one it hurts for CHARM_TIME seconds — 매혹: the target walks slowly toward the caster and
## cannot attack or use its ultimate.
const STACKS: int = 3
const BURST: float = .05
const CHARM_TIME: float = 5
const HEART_SPEED: float = 520

func release_basic(u) -> void:
	shoot(u,u.combat.aim_angle,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"needle","speed":880,"radius":10,"life":.6,"impulse":20})
func dealt_damage(u,target,_actual: float,options: Dictionary) -> void:
	if options.get("dmg",&"")!=&"basic" or not target.alive:return
	var n: int=int(target.state_value("whisperStacks"))+1
	if n<STACKS:target.set_state("whisperStacks",n);return
	target.set_state("whisperStacks",0)
	u.battle.emit_combat_event(&"whisper_burst",target.position,{"actor_id":target.battle_id})
	u.battle.damage_resolver.resolve(u,target,target.max_hp*BURST,{"dmg":&"burst","critical":false,"status":&"whisper","impulse":0,"attack_origin":target.position})

func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<560*u.combat_scale()
func release_ultimate(u,a: Dictionary,_dt: float) -> bool:
	shoot(u,float(a.angle),UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","kind":"heart","speed":HEART_SPEED,"radius":38,"life":1.4,"impulse":0,"piercing":true,"ultimate":true})
	return true
func projectile_hit(u,p,t) -> bool:
	if p.kind!="heart":return false
	var out: DamageOutcome=u.battle.damage_resolver.resolve(u,t,p.damage,{"dmg":&"ult","critical":true,"impulse":0,"angle":p.velocity.angle(),"attack_origin":p.position,"visible_hazard":true,"attack_token":"%s:heart%d:%d"%[u.actor_id(),u.ultimate.serial,t.battle_id]})
	if t.alive and out.hp_damage+out.shield_absorbed>0:charm(u,t)
	return true
## 매혹: cancels what the target was doing and pulls it toward the caster.
static func charm(u,t) -> void:
	t.set_state("charmTime",CHARM_TIME);t.character_specific_state["charmBy"]=u.actor_id()
	if t.combat_state!=CombatController.State.IDLE:t.combat.cancel(t)
	t.ultimate.cast.clear()
	u.battle.emit_combat_event(&"charmed",t.position,{"actor_id":t.battle_id,"by":u.battle_id})
static func charmed(t) -> bool:return t.state_value("charmTime")>0
func ultimate_danger(u,observer,a: Dictionary) -> bool:
	var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)));var offset: Vector2=observer.position-u.position
	return offset.dot(dir)>0 and absf(offset.cross(dir))<80
func cast_area(u,a: Dictionary) -> Dictionary:
	var dir: Vector2=Vector2.from_angle(float(a.get("angle",0)))
	return {"shape":"path","from":CharacterPersistence.point(u.position),"to":CharacterPersistence.point(u.position+dir*HEART_SPEED*1.4),"radius":38*u.combat_scale()}
