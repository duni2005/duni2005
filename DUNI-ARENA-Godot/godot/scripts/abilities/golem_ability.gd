extends CharacterAbility
## 빙하 골렘: always breathes cold — every AURA_TICK seconds enemies within AURA_RADIUS take damage
## (magic · ice · area) and one sure frost stack. Basic attack: slams the ground in front
## (physical · ice · area) and slows those hit for SLOW_TIME. Ultimate: draws in vapour for
## CHARGE_TIME seconds, then bursts (physical · ice · area · explosion) and freezes every enemy in
## BLAST_RADIUS at once.
const AURA_RADIUS: float = 120
const AURA_TICK: float = 1
const SLAM_RADIUS: float = 80
const SLOW_TIME: float = 2
const CHARGE_TIME: float = 4
const BLAST_RADIUS: float = 170

func passive_tick(u,dt: float) -> void:
	if u.unavailable():return
	u.set_state("auraTick",u.state_value("auraTick")-dt)
	if u.state_value("auraTick")>0:return
	u.set_state("auraTick",AURA_TICK)
	var r: float=AURA_RADIUS*u.combat_scale();var hit: bool=false
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(u.position)>r+20*e.combat_scale():continue
		hit=true
		u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"aura"),{"dmg":&"aura","critical":false,"status":&"aura","impulse":0,"attack_origin":u.position})
		ElementEffects.add_frost(u,e,1)
	if hit:u.battle.emit_combat_event(&"golem_aura",u.position,{"actor_id":u.battle_id,"radius":r})
func own_element(rule: StringName,_options: Dictionary) -> bool:return rule==&"ice"
func release_basic(u) -> void:
	var point: Vector2=u.position+Vector2.from_angle(u.combat.aim_angle)*55*u.combat_scale()
	var r: float=SLAM_RADIUS*u.combat_scale()
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(point)>r+22*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","critical":true,"impulse":140,"angle":(e.position-point).angle(),"attack_origin":point,"attack_token":"%s:slam%d"%[u.actor_id(),u.combat.attack_serial]})
		if e.alive and out.hp_damage>0:e.set_state("slowTime",SLOW_TIME)
	u.battle.emit_combat_event(&"golem_slam",point,{"actor_id":u.battle_id,"radius":r})

func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<220*u.combat_scale()
## The burst comes after CHARGE_TIME of charging (the cast keeps the golem in place).
func release_ultimate(u,a: Dictionary,dt: float) -> bool:
	a["charge"]=float(a.get("charge",0))+dt;u.velocity=Vector2.ZERO
	u.set_state("golemCharge",clampf(float(a.charge)/CHARGE_TIME,0,1))
	if float(a.charge)<CHARGE_TIME:return false
	u.set_state("golemCharge",0.0)
	var r: float=BLAST_RADIUS*u.combat_scale()
	u.battle.emit_combat_event(&"golem_blast",u.position,{"actor_id":u.battle_id,"radius":r})
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(u.position)>r+24*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":380,"angle":(e.position-u.position).angle(),"attack_origin":u.position,"visible_hazard":true,"attack_token":"%s:blast%d"%[u.actor_id(),u.ultimate.serial]})
		if e.alive and out.hp_damage+out.shield_absorbed>0:ElementEffects.freeze(e)
	return true
func ultimate_danger(u,observer,_a: Dictionary) -> bool:return observer.position.distance_to(u.position)<BLAST_RADIUS*u.combat_scale()+40
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":BLAST_RADIUS*u.combat_scale()}
