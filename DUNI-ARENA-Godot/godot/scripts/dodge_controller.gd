class_name DodgeController
extends RefCounted
static func start(unit, source, kind: StringName = &"roll") -> bool:
	if unit.stun_remaining > 0 or not unit.alive: return false
	var angle: float = (unit.position - source.position).angle() + (-1 if unit.battle.rng.randf() < .5 else 1) * PI * .35
	var point: Vector2 = unit.position
	var angles: Array=[angle,angle+PI/2,angle-PI/2]
	if kind==&"healer":
		var offset: int=unit.battle.rng.randi_range(0,3)
		angles=[]
		for i in range(4):angles.append([0.0,PI,PI/2,-PI/2][(i+offset)%4])
	for a in angles:
		var candidate: Vector2 = MovementController.clamp_position(unit.position+Vector2.from_angle(a)*94)
		if candidate.distance_to(unit.position) >= 45:
			point = candidate
			break
	unit.dodge_state = {"direction": (point-unit.position)/.22, "elapsed": 0.0, "duration": .22}
	unit.evade_remaining = .24
	unit.combat.cancel(unit)
	unit.knockback_velocity = Vector2.ZERO
	unit.velocity = Vector2.ZERO
	unit.battle.emit_combat_event(&"dodge", unit.position, {"actor_id": unit.battle_id})
	return true
static func advance(unit, delta: float) -> bool:
	if unit.dodge_state.is_empty(): return false
	var step: float = minf(delta, maxf(0, .22 - unit.dodge_state.elapsed))
	var before: Vector2 = unit.position
	unit.position = MovementController.clamp_position(unit.position + unit.dodge_state.direction * step)
	unit.velocity = (unit.position - before) / delta
	unit.dodge_state.elapsed += step
	if unit.dodge_state.elapsed >= .22 - 1e-8: unit.dodge_state.clear()
	return true
