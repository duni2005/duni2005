extends CharacterAbility
## 석궁: a magazine of SHOTS bolts. Every bolt is its own basic attack (physical · wind ·
## projectile) — a short aim, the shot, and straight on to the next while bolts remain; once the
## magazine is empty it reloads for RELOAD seconds (faster with attack speed). Ultimate 목표지정:
## a marking shell that bursts where it hits or lands (physical · explosion · wind · projectile)
## and puts every enemy the blast strikes in the 목표 state for TARGET_TIME seconds
## (ElementEffects: damage taken +10%, wind damage taken +15%).
const SHOTS: int = 7
const RELOAD: float = 1.4
## Pause after one bolt's recovery before the next may start.
const SHOT_GAP: float = .04
const BURST_RADIUS: float = 95
const TARGET_TIME: float = 10
const SHELL_SPEED: float = 720

func on_spawn(u) -> void:
	if not u.character_specific_state.has("bolts"):u.set_state("bolts",SHOTS)
func tick(u,dt: float) -> void:
	if u.state_value("reloadRemaining")<=0:return
	u.set_state("reloadRemaining",maxf(0,u.state_value("reloadRemaining")-dt*EquipmentCombatEffects.attack_speed(u)))
	if u.state_value("reloadRemaining")==0:u.set_state("bolts",SHOTS)
func can_attack(u,_t) -> bool:return u.state_value("bolts")>0 and u.state_value("reloadRemaining")<=0
## A fresh magazine waits for the right moment; once the volley has begun the bolts keep coming.
func requires_initiative(u=null) -> bool:return u==null or int(u.state_value("bolts"))>=SHOTS
func attack_cooldown(u,_rng: RandomNumberGenerator) -> float:
	var p: AttackData=u.combat.profile(u)
	return p.windup+p.active+p.recovery+SHOT_GAP
func movement_rate(u) -> float:return .8 if u.state_value("reloadRemaining")>0 else 1
func release_basic(u) -> void:
	var r: RandomNumberGenerator=u.battle.rng
	shoot(u,u.combat.aim_angle+r.randf_range(-.04,.04),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"crossBolt","speed":980,"radius":13,"life":.75,"impulse":45})
	u.set_state("bolts",u.state_value("bolts")-1)
	if u.state_value("bolts")<=0:u.set_state("reloadRemaining",RELOAD)
func debug_state(u) -> String:return "bolts:%d reload:%.2f"%[int(u.state_value("bolts")),u.state_value("reloadRemaining")]

func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<520*u.combat_scale()
func release_ultimate(u,a: Dictionary,_dt: float) -> bool:
	var aim: Vector2=CharacterPersistence.vector(a.get("point",{}),u.position)
	shoot(u,float(a.angle),UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","kind":"markShell","speed":SHELL_SPEED,"radius":18,"life":clampf(u.position.distance_to(aim)/SHELL_SPEED,.15,1.2),"impulse":0,"ultimate":true})
	return true
func projectile_hit(u,p,_t) -> bool:
	if p.kind!="markShell":return false
	burst(u,p.position);p.live=false;return true
## A shell that reaches its mark without hitting anyone bursts there.
func projectile_tick(u,dt: float) -> void:
	for p in u.battle.projectiles:
		if p.source==u and p.live and p.kind=="markShell" and p.lifetime<=dt*1.5:burst(u,p.position);p.live=false
func burst(u,point: Vector2) -> void:
	var radius: float=BURST_RADIUS*u.combat_scale()
	u.battle.emit_combat_event(&"ult_impact",point,{"type":u.data.type_id,"radius":radius})
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(point)>radius+22*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":260,"angle":(e.position-point).angle(),"attack_origin":point,"visible_hazard":true,"attack_token":"%s:mark%d"%[u.actor_id(),u.ultimate.serial]})
		if e.alive and out.hp_damage+out.shield_absorbed>0:
			e.set_state("targetedTime",TARGET_TIME);u.battle.emit_combat_event(&"targeted",e.position,{"actor_id":e.battle_id})
func ultimate_danger(u,observer,a: Dictionary) -> bool:
	return observer.position.distance_to(CharacterPersistence.vector(a.get("point",{}),u.position))<BURST_RADIUS*u.combat_scale()+40
func cast_area(u,a: Dictionary) -> Dictionary:return {"point":a.get("point",CharacterPersistence.point(u.position)),"radius":BURST_RADIUS*u.combat_scale()}
