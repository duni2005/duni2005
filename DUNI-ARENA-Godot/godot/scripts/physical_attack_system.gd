class_name PhysicalAttackSystem
extends RefCounted
## Explicit time-ordered contacts. Rules emit debug events, never draw VFX.
const GRACE: float = .12
const ARC_WINDOW: float = .075
static func live(battle, attack: AttackInstance) -> bool:
	if attack.life <= 0: return false
	if attack.attack_type == &"projectile": return true
	var owner = battle.find_unit(attack.source_battle_id)
	return owner != null and owner.alive and owner.stun_remaining <= 0 and (attack.metadata.get("independent",false) or ((owner.combat.attack_serial == attack.source_attack_serial and owner.combat_state != CombatController.State.IDLE) or (attack.age >= attack.duration and owner.combat_state == CombatController.State.IDLE)))
static func point_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))
static func segments_touch(a: Vector2,b: Vector2,c: Vector2,d: Vector2,radius: float) -> bool:
	return Geometry2D.segment_intersects_segment(a,b,c,d) != null or minf(minf(point_distance(a,c,d),point_distance(b,c,d)),minf(point_distance(c,a,b),point_distance(d,a,b))) <= radius
static func contact_time(a: Vector2, va: Vector2, b: Vector2, vb: Vector2, radius: float, delta: float) -> float:
	var relative: Vector2 = a-b
	var speed: Vector2 = va-vb
	var c: float = relative.length_squared()-radius*radius
	if c <= 0: return 0
	var aa: float = speed.length_squared()
	if aa < 1e-8: return -1
	var bb: float = 2*relative.dot(speed)
	var disc: float = bb*bb-4*aa*c
	if disc < 0: return -1
	var time: float = (-bb-sqrt(disc))/(2*aa)
	return time if time >= 0 and time <= delta else -1
static func blade_contact(battle,a: AttackInstance,b: AttackInstance,delta: float) -> float:
	var owner_a = battle.find_unit(a.source_battle_id)
	var owner_b = battle.find_unit(b.source_battle_id)
	for sample in range(5):
		var t: float = delta*sample/4
		for offset_a in [-ARC_WINDOW,0,ARC_WINDOW*.5]:
			var blade_a: Array[Vector2] = a.blade(owner_a.position,t+offset_a)
			if b.attack_type == &"projectile":
				if point_distance(b.position+b.velocity*t,blade_a[0],blade_a[1]) <= b.clash_radius+(a.path_width if a.shape == &"path" else 14): return t
			else:
				for offset_b in [-ARC_WINDOW,0,ARC_WINDOW*.5]:
					var blade_b: Array[Vector2] = b.blade(owner_b.position,t+offset_b)
					if segments_touch(blade_a[0],blade_a[1],blade_b[0],blade_b[1],22+maxf(a.path_width,b.path_width)): return t
	return -1
static func melee_contact(battle,attack: AttackInstance,target,delta: float) -> float:
	var owner = battle.find_unit(attack.source_battle_id)
	for sample in range(5):
		var t: float = delta*sample/4
		if attack.age+t > attack.duration: break
		var blade: Array[Vector2] = attack.blade(owner.position,t)
		if attack.metadata.get("bite",false):
			if owner.position.distance_to(target.position)<=attack.reach+27*target.combat_scale() and absf(wrapf((target.position-owner.position).angle()-attack.angle,-PI,PI))<=attack.cone:return t
		elif point_distance(target.position,blade[0],blade[1]) <= 27*target.combat_scale()+attack.path_width:return t
	return -1
static func all_attacks(battle) -> Array[AttackInstance]:
	var result: Array[AttackInstance] = []
	result.append_array(battle.melee_strikes)
	for arrow in battle.projectiles:
		if arrow.live and arrow.attack_instance != null:
			var attack: AttackInstance = arrow.attack_instance
			if battle.full_characters_enabled:attack.team=arrow.source.team
			attack.position = arrow.position
			attack.velocity = arrow.velocity
			attack.life = arrow.lifetime
			attack.damage = arrow.damage
			attack.power = arrow.power
			result.append(attack)
	return result
static func destroy(battle, attack: AttackInstance, draw: bool) -> void:
	attack.life = 0
	if attack.attack_type == &"melee":
		var unit = battle.find_unit(attack.source_battle_id)
		if unit != null and unit.alive:
			if unit.combat.attack_serial == attack.source_attack_serial: unit.combat.cancel(unit)
			StatusController.stun(unit,.3 if draw else .25)
			unit.combat.cooldown = maxf(unit.combat.cooldown,.8 if draw else .7)
static func owner_recoil(battle, attack: AttackInstance, other: AttackInstance, point: Vector2, high: float, winner: bool) -> void:
	var owner = battle.find_unit(attack.source_battle_id)
	var opponent = battle.find_unit(other.source_battle_id)
	if owner == null or not owner.alive: return
	var direction: Vector2 = (owner.position-opponent.position).normalized() if attack.attack_type == &"melee" else -attack.velocity.normalized()
	if direction.length_squared() < .01: direction = (owner.position-point).normalized()
	var force: float = clampf(510+high*2.1,550,820)*(1 if attack.attack_type == &"melee" else .85)*(.52 if winner else 1)
	KnockbackController.apply(owner,direction*force,opponent)
	owner.threat_response.response.clear()
	if battle.full_characters_enabled:owner.brain.reset_clash(owner,winner)
static func clash(battle, a: AttackInstance, b: AttackInstance, point: Vector2) -> Dictionary:
	if not live(battle,a) or not live(battle,b) or a.team == b.team: return {}
	var ap: float = effective_power(battle,a)
	var bp: float = effective_power(battle,b)
	var similar: bool = maxf(ap,bp) <= maxf(.01,minf(ap,bp))*ClashResolver.DRAW_RATIO
	var decision: Dictionary = compare_effective(a,b,ap,bp,1 if similar else battle.rng.randf())
	var a_wins: bool = decision.winner_id == a.attack_id
	var b_wins: bool = decision.winner_id == b.attack_id
	if decision.breakthrough:
		destroy(battle,b if a_wins else a,false)
		ClashResolver.weaken(a if a_wins else b)
	else:
		destroy(battle,a,true)
		destroy(battle,b,true)
	owner_recoil(battle,a,b,point,decision.high,a_wins)
	owner_recoil(battle,b,a,point,decision.high,b_wins)
	battle.spawn_combat_wave(&"clash",point,[a.source_battle_id,b.source_battle_id],decision.wave_radius,decision.wave_stun,decision.wave_force,[a.source_battle_id,b.source_battle_id])
	var owner_a = battle.find_unit(a.source_battle_id)
	var owner_b = battle.find_unit(b.source_battle_id)
	var damage_a: float = maxf(2,CombatRules.js_round(clampf(bp*.16,3,18)*(.55 if a_wins else 1)))
	var damage_b: float = maxf(2,CombatRules.js_round(clampf(ap*.16,3,18)*(.55 if b_wins else 1)))
	battle.damage_resolver.resolve(owner_b,owner_a,damage_a,{"clash_recoil":true,"critical":false,"impulse":0})
	battle.damage_resolver.resolve(owner_a,owner_b,damage_b,{"clash_recoil":true,"critical":false,"impulse":0})
	battle.emit_combat_event(&"clash",point,{"a":a.attack_id,"b":b.attack_id,"breakthrough":decision.breakthrough,"high":decision.high})
	return decision
static func slice(battle,delta: float) -> void:
	var attacks: Array[AttackInstance] = all_attacks(battle).filter(func(a): return live(battle,a))
	var events: Array[Dictionary] = []
	for i in range(attacks.size()):
		var a: AttackInstance = attacks[i]
		for j in range(i+1,attacks.size()):
			var b: AttackInstance = attacks[j]
			if a.team == b.team or a.metadata.get("rescue",false) or b.metadata.get("rescue",false): continue
			var t: float
			if a.attack_type == &"projectile" and b.attack_type == &"projectile": t = contact_time(a.position,a.velocity,b.position,b.velocity,a.clash_radius+b.clash_radius+8,delta)
			else: t = blade_contact(battle,b,a,delta) if a.attack_type == &"projectile" else blade_contact(battle,a,b,delta)
			if t >= 0:
				var point: Vector2 = a.position+a.velocity*t if a.attack_type == &"projectile" else b.position+b.velocity*t if b.attack_type == &"projectile" else (battle.find_unit(a.source_battle_id).position+battle.find_unit(b.source_battle_id).position)*.5
				events.append({"time":t,"kind":&"clash","a":a,"b":b,"point":point})
		if a.attack_type == &"melee" and a.age >= a.duration: continue
		for target in battle.units:
			if not target.alive or target.unavailable() or target.team == a.team or a.hit_ids.has(target.battle_id): continue
			if a.metadata.get("kind","")=="bomb" or a.metadata.get("rescue",false):continue
			if a.metadata.get("grapple",target.actor_id())!=target.actor_id():continue
			if a.metadata.get("kind","")=="lightning" and a.metadata.get("chain",{}).get("recent",[]).has(target.actor_id()):continue
			var source = battle.find_unit(a.source_battle_id)
			if a.attack_type == &"projectile" and target.evade_remaining > 0 and CombatPerception.can_see_attack(target,source,a.position,a.hidden_launch): continue
			var t: float = contact_time(a.position,a.velocity,target.position,Vector2.ZERO,maxf(2,a.radius+27*(target.combat_scale()-1)),delta) if a.attack_type == &"projectile" else melee_contact(battle,a,target,delta)
			if t >= 0: events.append({"time":t,"kind":&"hit","a":a,"target":target})
	events.sort_custom(func(a,b): return a.time < b.time if a.time != b.time else a.kind == &"clash" and b.kind != &"clash")
	for event in events:
		var attack: AttackInstance = event.a
		if not live(battle,attack): continue
		if event.kind == &"clash":
			clash(battle,attack,event.b,event.point)
			continue
		var target = event.target
		if not target.alive or attack.hit_ids.has(target.battle_id) or attack.hit_ids.size()>=int(attack.metadata.get("max_targets",2147483647)): continue
		attack.hit_ids[target.battle_id] = true
		var source = battle.find_unit(attack.source_battle_id)
		var origin: Vector2 = source.position if attack.attack_type == &"melee" else target.position-attack.velocity*.08
		var options: Dictionary = attack.options(origin)
		options.angle = (target.position-source.position).angle() if attack.attack_type == &"melee" and attack.shape != &"path" else attack.velocity.angle() if attack.attack_type == &"projectile" else attack.angle
		if battle.full_characters_enabled:
			options.merge(attack.metadata,true);options.melee=attack.attack_type==&"melee"
			if attack.attack_type==&"projectile":
				var projectile: BattleProjectile=ProjectileRules.find(battle,attack.attack_id)
				if projectile!=null:
					var previous: Vector2=projectile.position;projectile.position=attack.position+attack.velocity*float(event.time)
					ProjectileRules.hit(projectile,target);projectile.position=previous
			elif attack.metadata.has("grapple"):
				if target.invincible_remaining<=0 and target.duel.is_empty() and target.ability.pre_damage(target,source,attack.power,options).is_empty() and not target.parry.try_block(target,source,attack.power,attack.attack_id):CharacterLifecycle.begin_duel(source,target,attack.metadata.get("duel_ultimate",false))
			else:
				var out: DamageOutcome=battle.damage_resolver.resolve(source,target,attack.damage,options)
				source.ability.melee_hit(source,attack,target,out)
		else:
			battle.damage_resolver.resolve(source,target,attack.damage,options)
			if attack.attack_type == &"projectile": attack.life = 0
	for attack in attacks:
		attack.age += delta
		attack.life -= delta
	for arrow in battle.projectiles:
		var attack: AttackInstance = arrow.attack_instance
		if attack == null: continue
		arrow.damage = attack.damage
		arrow.power = attack.power
		if attack.life <= 0: arrow.live = false
		if battle.full_characters_enabled and not arrow.live:ProjectileRules.finish(arrow)
		if arrow.live: arrow.advance(delta)
	for i in range(battle.projectiles.size()-1,-1,-1):
		if not battle.projectiles[i].live:
			battle.projectiles[i].queue_free()
			battle.projectiles.remove_at(i)
	for i in range(battle.melee_strikes.size()-1,-1,-1):
		if not live(battle,battle.melee_strikes[i]): battle.melee_strikes.remove_at(i)
static func advance(battle,delta: float) -> void:
	if battle.finished or battle.clock.is_turning_paused() or not is_finite(delta) or delta <= 0: return
	if battle.full_characters_enabled:
		for u in battle.units:u.ability.projectile_tick(u,delta)
	var remaining: float = delta
	while remaining > 1e-8:
		var step: float = minf(remaining,1.0/120)
		for arrow in battle.projectiles:
			var edge: float = arrow.boundary_time()
			if edge > 1e-8: step = minf(step,edge)
			else:
				if battle.full_characters_enabled:ProjectileRules.boundary(arrow)
				else:arrow.live=false;arrow.attack_instance.life=0
			step = minf(step,maxf(1e-8,arrow.lifetime))
		slice(battle,step)
		remaining -= step

static func effective_power(battle,a: AttackInstance) -> float:
	var owner=battle.find_unit(a.source_battle_id)
	return a.power*(CharacterCombat.champion_factor(owner)*(1.3 if owner.state_value("paladinBlessingTime")>0 else 1) if battle.full_characters_enabled and a.metadata.get("kind","")!="mirrorReflection" else 1)
static func compare_effective(a,b,ap: float,bp: float,roll: float) -> Dictionary:
	var aa:=AttackInstance.new();aa.attack_id=a.attack_id;aa.power=ap
	var bb:=AttackInstance.new();bb.attack_id=b.attack_id;bb.power=bp
	return ClashResolver.compare(aa,bb,roll)
