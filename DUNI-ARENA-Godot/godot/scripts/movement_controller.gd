class_name MovementController
extends RefCounted
## Explicit logical coordinates, not rigid-body simulation.
## Full mode adds BattleBrain and character movement policies; comparison mode remains.
## KnockbackController owns external momentum independently of voluntary movement.

const MIN_POSITION: float = 28.0
const MAX_POSITION: float = 772.0

func advance(unit, delta: float) -> void:
	if unit.battle.finished or unit.battle.clock.is_turning_paused():
		return
	if unit.battle.common_combat_enabled:
		advance_common(unit, delta)
		return
	if unit.alive and delta > 0 and is_finite(delta) and StrategyMovementController.advance(unit, delta):
		return
	unit.velocity = Vector2.ZERO
	if unit.battle.finished or delta <= 0.0 or not is_finite(delta) or not unit.alive or unit.combat_state != CombatController.State.IDLE or not is_instance_valid(unit.target):
		return
	if not unit.target.alive or unit.target.team == unit.team:
		return
	var displacement: Vector2 = unit.target.position - unit.position
	var distance: float = displacement.length()
	var stop_distance: float = unit.data.attack_profile.start_distance()
	# Web canStartAttack is strict '<'. Stop just inside that threshold.
	if distance < stop_distance or distance <= 0.00001:
		return
	var travel: float = minf(unit.move_speed * delta, maxf(0.0, distance - stop_distance + 0.001))
	var before: Vector2 = unit.position
	unit.position = clamp_position(before + displacement / distance * travel)
	unit.velocity = (unit.position - before) / delta

static func clamp_position(point: Vector2) -> Vector2:
	return point.clamp(Vector2(MIN_POSITION, MIN_POSITION), Vector2(MAX_POSITION, MAX_POSITION))

func advance_common(unit, delta: float) -> void:
	if not unit.battle.full_characters_enabled:unit.velocity = Vector2.ZERO
	if not unit.alive or unit.stun_remaining > 0 or delta <= 0:unit.velocity=Vector2.ZERO;return
	if unit.battle.full_characters_enabled:
		if unit.unavailable() or unit.ability.locked(unit) or not unit.ultimate.cast.is_empty():return
		if unit.character_specific_state.get("bomberRush",false):return
		if unit.evade_remaining>0 and unit.dodge_state.is_empty() and unit.strategy_dash.is_empty():unit.velocity=Vector2.ZERO;unit.brain.heading=Vector2.ZERO;return
		if unit.strategy_dash.is_empty() and not unit.dodge_state.is_empty():DodgeController.advance(unit,delta);return
		if not unit.strategy_dash.is_empty():StrategyMovementController.advance(unit,delta);return
		if unit.combat.counter:return
		if unit.brain.move_bomb_escape(unit,delta):return
		if unit.data.type_id==24:unit.ability.modify_movement(unit,unit.target,delta);return
		if ParryController.perfect(unit):unit.brain.heading=Vector2.ZERO;unit.velocity=Vector2.ZERO;return
		if unit.data.type_id==12 and unit.ability.modify_movement(unit,unit.target,delta):unit.brain.heading=Vector2.ZERO;return
		if unit.threat_response.movement(unit,delta):return
		if unit.area_evaluator.advance(unit,delta):return
		if unit.command_retreat_until>unit.battle.clock.elapsed:StrategyMovementController.advance(unit,delta);return
		unit.brain.movement(unit,unit.target,delta)
		return
	if DodgeController.advance(unit,delta):return
	if StrategyMovementController.advance(unit,delta):return
	if unit.threat_response.movement(unit,delta):return
	if unit.combat_state != CombatController.State.IDLE: return
	if unit.area_evaluator.advance(unit, delta): return
	var threat: Dictionary = unit.threat_response.projectile_threat(unit)
	var direction: Vector2 = Vector2.ZERO
	if not threat.is_empty() and threat.time < unit.threat_response.reaction:
		direction = threat.arrow.velocity.normalized().orthogonal()*unit.threat_response.side
		if not (unit.position+direction*65).is_equal_approx(clamp_position(unit.position+direction*65)): direction *= -1
	elif is_instance_valid(unit.target):
		var distance: float = unit.position.distance_to(unit.target.position)
		if distance >= unit.data.attack_profile.start_distance(): direction = (unit.target.position-unit.position).normalized()
		unit.facing = lerp_angle(unit.facing, (unit.target.position-unit.position).angle(), minf(1,delta*8))
	for other in unit.battle.units:
		if other == unit or not other.alive: continue
		var separation: Vector2 = unit.position-other.position
		var distance: float = separation.length()
		if distance < 58 and distance > .01: direction += separation/distance*(58-distance)/22
	var before: Vector2 = unit.position
	unit.position = clamp_position(unit.position+direction.limit_length(1)*unit.move_speed*delta)
	unit.velocity = (unit.position-before)/delta
