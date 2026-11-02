extends CharacterAbility
## 석궁: reloads during the windup, then fires SHOTS bolts in quick succession (physical · wind ·
## projectile). Ultimate 목표지정: a marking shell that bursts where it hits or lands (physical ·
## explosion · wind · projectile) and puts every enemy the blast strikes in the 목표 state for
## TARGET_TIME seconds (ElementEffects: damage taken +10%, wind damage taken +15%).
const SHOTS: int = 7
const SHOT_GAP: float = .08
const BURST_RADIUS: float = 95
const TARGET_TIME: float = 10
const SHELL_SPEED: float = 720

func release_basic(u) -> void:
	u.combat.attack_metadata["fired"]=0;_fire(u)
func _fire(u) -> void:
	var r: RandomNumberGenerator=u.battle.rng
	shoot(u,u.combat.aim_angle+r.randf_range(-.05,.05),UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"crossBolt","speed":980,"radius":13,"life":.75,"impulse":45})
	u.combat.attack_metadata["fired"]=int(u.combat.attack_metadata.get("fired",0))+1
## The rest of the volley, one bolt every SHOT_GAP, turning toward the target.
func attack_tick(u,dt: float) -> bool:
	if u.combat_state!=CombatController.State.ACTIVE or not u.combat.attack_metadata.has("fired"):return false
	var t=u.combat.attack_target
	if t!=null and is_instance_valid(t) and t.alive:
		u.combat.aim_angle+=clampf(wrapf(u.combat.aim_direction(u,t)-u.combat.aim_angle,-PI,PI),-4*dt,4*dt);u.facing=u.combat.aim_angle
	var fired: int=int(u.combat.attack_metadata.fired)
	while fired<SHOTS and u.combat.phase_time+1e-8>=fired*SHOT_GAP:_fire(u);fired+=1
	return false

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
