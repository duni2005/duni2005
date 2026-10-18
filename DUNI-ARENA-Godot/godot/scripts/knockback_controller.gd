class_name KnockbackController
extends RefCounted
const MAX_SPEED: float = 1080
static func mass(unit) -> float:
	return INF if unit.battle.full_characters_enabled and (not unit.duel.is_empty() or unit.state_value("guardRemaining")>0) else clampf(sqrt(unit.max_hp / 160), .8, 1.6)*maxf(.7,unit.combat_scale())
static func attack_force(damage: float, impulse: float, source, target) -> float:
	if impulse == 0: return 0
	var weight: float = clampf(sqrt(target.max_hp / 160), .85, 1.5)
	return minf(980, impulse * 2.1 * clampf(sqrt(maxf(0, damage) / maxf(1, CombatRules.attack(source))), .5, 2) / weight)
static func apply(unit, force: Vector2, source = null, chain: int = 0) -> void:
	if unit.battle.finished or unit.battle.clock.is_turning_paused() or not unit.alive or not force.is_finite() or force.length() < .01: return
	if unit.unavailable() or unit.state_value("guardRemaining")>0 or not unit.duel.is_empty():return
	unit.knockback_velocity = (unit.knockback_velocity + force).limit_length(MAX_SPEED)
	if is_instance_valid(source): unit.knockback_source_id = source.battle_id
	if chain == 0:
		unit.battle.knockback_serial += 1
		chain = unit.battle.knockback_serial
	unit.knockback_chain = chain
	unit.dodge_state.clear()
	unit.evade_remaining = 0
	unit.strategy_dash.clear()
static func collision_damage(unit, force: float, source) -> float:
	if not unit.alive or unit.invincible_remaining > 0 or force < 160: return 0
	var amount: float = maxf(1, CombatRules.js_round((force - 100) * .055 * CombatRules.fatigue(source, &"damage")))
	var hp: float=unit.battle.damage_resolver.resolve(source, unit, amount, {"collision": true, "critical": false, "impulse": 0}).hp_damage
	if hp>0 and unit.alive and unit.knockback_collision_stun>0 and source!=null and source.team!=unit.team and source.data.type_id==16:StatusController.stun(unit,unit.knockback_collision_stun)
	return hp
static func collision(a, b) -> void:
	var separation: Vector2 = b.position - a.position
	var distance: float = separation.length()
	if a.unavailable() or b.unavailable() or a.is_dashing() or b.is_dashing():return
	if distance >= 24*(a.combat_scale()+b.combat_scale())+.5: return
	var normal: Vector2 = separation / distance if distance > .01 else Vector2.from_angle(a.facing)
	var closing: float = (a.knockback_velocity - b.knockback_velocity).dot(normal)
	if closing < 65: return
	var key: String = "%d:%d" % [mini(a.battle_id, b.battle_id), maxi(a.battle_id, b.battle_id)]
	var previous: float = a.battle.collision_pairs.get(key, -INF)
	if a.battle.clock.elapsed - previous < .2: return
	a.battle.collision_pairs[key] = a.battle.clock.elapsed
	var carrier = a if a.knockback_velocity.length() >= b.knockback_velocity.length() else b
	var source = a.battle.find_unit(carrier.knockback_source_id)
	var inv_a: float = 1 / mass(a)
	var inv_b: float = 1 / mass(b)
	if inv_a+inv_b<=0:return
	var impulse: float = closing * 1.12 / (inv_a + inv_b)
	var chain: int = carrier.knockback_chain
	apply(a, -normal * impulse * inv_a, source, chain)
	apply(b, normal * impulse * inv_b, source, chain)
	if closing >= 160:
		collision_damage(a, closing * .65, source)
		collision_damage(b, closing, source)
		a.battle.emit_combat_event(&"body_collision", (a.position+b.position)*.5, {"force": closing})
static func advance(unit, delta: float) -> void:
	if unit.battle.finished or unit.battle.clock.is_turning_paused() or not unit.alive: return
	if unit.unavailable() or unit.state_value("guardRemaining")>0 or not unit.duel.is_empty() or unit.is_dashing():return
	var before: Vector2 = unit.position
	var remaining: float = delta
	while remaining > 1e-8 and unit.alive:
		var step: float = minf(remaining, 1.0/120)
		unit.knockback_velocity = unit.knockback_velocity.limit_length(MAX_SPEED)
		var speed: float = unit.knockback_velocity.length()
		var point: Vector2 = unit.position + unit.knockback_velocity * step
		var wall: float = 0
		if point.x < 28 or point.x > 772:
			wall = maxf(wall, absf(unit.knockback_velocity.x))
			unit.knockback_velocity.x *= -.24
		if point.y < 28 or point.y > 772:
			wall = maxf(wall, absf(unit.knockback_velocity.y))
			unit.knockback_velocity.y *= -.24
		unit.position = MovementController.clamp_position(point)
		if wall >= 160:
			collision_damage(unit, wall, unit.battle.find_unit(unit.knockback_source_id))
			unit.battle.emit_combat_event(&"wall_collision", unit.position, {"force": wall})
		if speed > 65:
			for other in unit.battle.units:
				if other != unit and other.alive: collision(unit, other)
		unit.knockback_velocity *= exp(-step * 4.6)
		remaining -= step
	if delta > 0: unit.velocity += (unit.position - before) / delta
