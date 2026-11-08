extends CharacterAbility
## 금단의 연구원. Basic 증폭/억제 약물 (slow attacks), alternating:
##  · 증폭 약물: a vial to the ally (itself included) with the lowest HP share — heals it and gives a
##    shield for BOOST_TIME seconds.
##  · 억제 약물: a vial at the nearest enemy — damage (magic · projectile), and for SUPPRESS_TIME
##    seconds slower attacks (ElementEffects.SUPPRESS_ATTACK_SPEED) and slower movement (slowTime).
## Ultimate 인지 각성 약물: a drug bomb lobbed where the enemies crowd bursts the moment it lands
## (magic · explosion · area) and drives everyone hit into 광란 for FRENZY_TIME seconds
## (ElementEffects.start_frenzy).
const BOOST_TIME: float = 2
const SUPPRESS_TIME: float = 2
const FRENZY_TIME: float = 6
const BURST_RADIUS: float = 150
const BOMB_REACH: float = 420
const VIAL_SPEED: float = 520

func can_attack(u,t) -> bool:return t!=null
## Heal and shield amounts for one 증폭 약물.
static func boost_heal(u) -> float:return 6+UnitStatTable.damage_stat(u,&"magic")*.5
static func boost_shield(u) -> float:return 8+UnitStatTable.damage_stat(u,&"magic")*.5
func release_basic(u) -> void:
	var boost: bool=int(u.state_value("drugTurn"))%2==0
	u.set_state("drugTurn",u.state_value("drugTurn")+1)
	if boost:
		var pool: Array=u.friends().filter(func(a):return a.position.distance_to(u.position)<380*u.combat_scale())
		pool.append(u)
		pool.sort_custom(func(a,b):return a.current_hp/a.max_hp<b.current_hp/b.max_hp)
		var ally=pool[0]
		if ally==u:apply_boost(u,u);return
		var gap: Vector2=ally.position-u.position
		shoot(u,gap.angle(),0,{"dmg":&"basic","kind":"boostVial","speed":VIAL_SPEED,"radius":14,"offset":26,"life":gap.length()/VIAL_SPEED,"impulse":0,"ally":ally.actor_id()})
		return
	var foe=nearest(u,u.enemies().filter(func(e):return not e.unavailable()))
	if foe==null:return
	var aim: float=(foe.position+foe.velocity*.2-u.position).angle()
	shoot(u,aim,UnitStatTable.raw(u,&"basic"),{"dmg":&"basic","kind":"suppressVial","speed":VIAL_SPEED,"radius":16,"offset":26,"life":1.0,"impulse":60})
func apply_boost(u,ally) -> void:
	restore_hp(ally,boost_heal(u),u)
	ally.shield_hp=maxf(ally.shield_hp,boost_shield(u));ally.shield_remaining=maxf(ally.shield_remaining,BOOST_TIME)
	u.battle.emit_combat_event(&"boost_drug",ally.position,{"actor_id":ally.battle_id})
func dealt_damage(u,t,_actual: float,options: Dictionary) -> void:
	if options.get("dmg",&"")!=&"basic" or not t.alive:return
	t.set_state("suppressTime",SUPPRESS_TIME);t.set_state("slowTime",maxf(t.state_value("slowTime"),SUPPRESS_TIME))
	u.battle.emit_combat_event(&"suppress_drug",t.position,{"actor_id":t.battle_id})
## Vials for allies and the drug bomb fly over everyone; they act where they land.
func projectile_hit(_u,p,_t) -> bool:return p.kind in ["boostVial","drugBomb"]
func projectile_tick(u,dt: float) -> void:
	for p in u.battle.projectiles:
		if p.source!=u or not p.live:continue
		if p.kind=="boostVial":
			var ally=u.battle.find_actor(str(p.metadata.get("ally","")))
			if ally==null or not ally.alive:p.live=false;continue
			if p.position.distance_to(ally.position)<28*ally.combat_scale() or p.lifetime<=dt*1.5:apply_boost(u,ally);p.live=false
		elif p.kind=="drugBomb" and p.lifetime<=dt*1.5:p.live=false;burst(u,p.position)
func burst(u,at: Vector2) -> void:
	var r: float=BURST_RADIUS*u.combat_scale()
	u.battle.emit_combat_event(&"drug_bomb_burst",at,{"actor_id":u.battle_id,"radius":r})
	for e in u.enemies(false):
		if e.unavailable() or e.position.distance_to(at)>r+22*e.combat_scale():continue
		var out: DamageOutcome=u.battle.damage_resolver.resolve(u,e,UnitStatTable.raw(u,&"ult"),{"dmg":&"ult","critical":true,"impulse":280,"angle":(e.position-at).angle(),"attack_origin":at,"visible_hazard":true,"attack_token":"%s:drug%d:%d"%[u.actor_id(),u.ultimate.serial,e.battle_id]})
		if e.alive and out.hp_damage+out.shield_absorbed>0 and ElementEffects.start_frenzy(e,FRENZY_TIME):
			u.battle.emit_combat_event(&"frenzied",e.position,{"actor_id":e.battle_id})
func can_ultimate(u,t) -> bool:return t!=null and u.enemies(false).any(func(e):return e.alive and u.position.distance_to(e.position)<(BOMB_REACH+BURST_RADIUS*.5)*u.combat_scale())
## Thrown where the enemies crowd: the spot within reach that covers the most of them.
func ultimate_point(u,point: Vector2) -> Vector2:
	var reach: float=BOMB_REACH*u.combat_scale();var radius: float=BURST_RADIUS*u.combat_scale()
	var foes: Array=u.enemies(false).filter(func(e):return e.alive and not e.unavailable() and u.position.distance_to(e.position)<reach+radius*.5)
	var best: Vector2=point;var most: int=-1
	for e in foes:
		var near: Array=foes.filter(func(o):return o.position.distance_to(e.position)<radius)
		if near.size()>most:
			most=near.size();best=Vector2.ZERO
			for o in near:best+=o.position
			best/=near.size()
	return (u.position+(best-u.position).limit_length(reach)).clamp(Vector2(28,28),ArenaMap.hi(28))
func release_ultimate(u,a: Dictionary,_dt: float) -> bool:
	var aim: Vector2=CharacterPersistence.vector(a.get("point",{}),u.position)
	shoot(u,(aim-u.position).angle(),0,{"dmg":&"ult","kind":"drugBomb","speed":560,"radius":18,"offset":24,"life":clampf(u.position.distance_to(aim)/560,.1,1.2),"impulse":0,"ultimate":true})
	return true
func ultimate_danger(u,observer,a: Dictionary) -> bool:
	return observer.position.distance_to(CharacterPersistence.vector(a.get("point",{}),u.position))<BURST_RADIUS*u.combat_scale()+30
func cast_area(u,a: Dictionary) -> Dictionary:return {"point":a.get("point",CharacterPersistence.point(u.position)),"radius":BURST_RADIUS*u.combat_scale()}
func debug_state(u) -> String:return "turn:%d"%int(u.state_value("drugTurn"))
